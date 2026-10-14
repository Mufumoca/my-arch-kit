#!/usr/bin/env python3
"""音乐卡片后端：网易云 API + mpv 播放 + MPRIS + Unix socket（给 Quickshell 卡片用）

socket 协议：每行一个 JSON。
  卡片 -> 后端 {"cmd": "...", ...}
  后端 -> 卡片 {"ev": "...", ...}
"""
import json
import os
import random
import re
import signal
import socket
import subprocess
import sys
import threading
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from netease import Api  # noqa: E402

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCK = os.path.join(RUNTIME, "music-card.sock")
MPV_SOCK = os.path.join(RUNTIME, "music-card-mpv.sock")
STATE_FILE = os.path.expanduser("~/.cache/music-card/state.json")
CONFIG_FILE = os.path.expanduser("~/.config/music-card/config.json")


def playlist_names():
    """侧栏要显示的自建歌单名（按顺序，最后追加「每日推荐」）
    读 CONFIG_FILE 的 {"playlists": ["歌单A", "歌单B"]}；未配置时显示全部自建歌单"""
    try:
        with open(CONFIG_FILE) as f:
            return list(json.load(f).get("playlists") or [])
    except (OSError, ValueError, AttributeError):
        return []


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def bg(fn, done=None, fail=None):
    """在线程里跑阻塞调用，结果回到 GLib 主循环"""
    def run():
        try:
            r = fn()
        except Exception as e:  # noqa: BLE001
            err = e
            log("bg error:", repr(err))
            if fail:
                GLib.idle_add(lambda: fail(err) and False)
            return
        if done:
            GLib.idle_add(lambda: done(r) and False)
    threading.Thread(target=run, daemon=True).start()


def parse_lrc(text):
    out = {}
    tag = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
    for line in (text or "").splitlines():
        stamps = tag.findall(line)
        if not stamps:
            continue
        body = tag.sub("", line).strip()
        for m, s in stamps:
            out[round(int(m) * 60 + float(s), 2)] = body
    return out


def merge_lyric(lrc, tlrc):
    main = parse_lrc(lrc)
    trans = parse_lrc(tlrc)
    lines = []
    for t in sorted(main):
        if not main[t]:
            continue
        tr = trans.get(t, "")
        if not tr:  # 翻译时间戳偶尔有几十毫秒偏差
            near = [k for k in trans if abs(k - t) < 0.1]
            tr = trans[near[0]] if near else ""
        lines.append({"t": t, "text": main[t], "trans": tr})
    return lines


# ---------------------------------------------------------------- mpv
class Mpv:
    def __init__(self, on_event):
        self.on_event = on_event
        self.sock = None
        self.buf = b""
        self.proc = None
        self.start()

    def start(self):
        try:
            os.unlink(MPV_SOCK)
        except OSError:
            pass
        self.proc = subprocess.Popen([
            "mpv", "--no-config", "--idle=yes", "--no-video", "--no-terminal",
            "--audio-display=no", "--audio-client-name=music-card",
            "--cache=yes", "--demuxer-max-bytes=64MiB",
            f"--input-ipc-server={MPV_SOCK}",
        ])
        GLib.timeout_add(100, self._connect)

    def _connect(self):
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(MPV_SOCK)
        except OSError:
            return True  # 继续重试
        self.sock = s
        GLib.io_add_watch(s.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self._read)
        for i, p in enumerate(["pause", "time-pos", "idle-active"]):
            self.cmd("observe_property", i + 1, p)
        self.on_event({"event": "ready"})
        return False

    def _read(self, fd, cond):
        try:
            data = self.sock.recv(65536)
        except OSError:
            data = b""
        if not data:
            log("mpv 断开，重启")
            self.sock.close()
            self.sock = None
            self.proc.kill()
            self.start()
            return False
        self.buf += data
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            try:
                self.on_event(json.loads(line))
            except ValueError:
                pass
        return True

    def cmd(self, *args):
        if not self.sock:
            return
        try:
            self.sock.sendall(json.dumps({"command": list(args)}).encode() + b"\n")
        except OSError as e:
            log("mpv write:", e)

    def set(self, prop, value):
        self.cmd("set_property", prop, value)


# ---------------------------------------------------------------- MPRIS
MPRIS = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
PROPS = "org.freedesktop.DBus.Properties"


class Mpris(dbus.service.Object):
    def __init__(self, player):
        self.p = player
        bus = dbus.SessionBus()
        self.name = dbus.service.BusName("org.mpris.MediaPlayer2.music_card", bus)
        super().__init__(bus, "/org/mpris/MediaPlayer2")

    def metadata(self):
        s = self.p.current()
        if not s:
            return dbus.Dictionary({"mpris:trackid": dbus.ObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack")}, signature="sv")
        return dbus.Dictionary({
            "mpris:trackid": dbus.ObjectPath(f"/music_card/track/{s['id']}"),
            "mpris:length": dbus.Int64(int(s["duration"]) * 1000),
            "mpris:artUrl": s["cover"],
            "xesam:title": s["name"],
            "xesam:artist": dbus.Array([a["name"] or "" for a in s["artists"]] or [""], signature="s"),
            "xesam:album": s["album"],
            "xesam:url": f"https://music.163.com/song?id={s['id']}",
        }, signature="sv")

    def props(self, iface):
        if iface == MPRIS:
            return {
                "CanQuit": False, "CanRaise": True, "HasTrackList": False,
                "Identity": "Music Card", "DesktopEntry": "music-card",
                "SupportedUriSchemes": dbus.Array([], signature="s"),
                "SupportedMimeTypes": dbus.Array([], signature="s"),
            }
        p = self.p
        return {
            "PlaybackStatus": "Playing" if p.playing else ("Paused" if p.current() else "Stopped"),
            "LoopStatus": "Track" if p.mode == "one" else "Playlist",
            "Shuffle": p.shuffle,
            "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0,
            "Metadata": self.metadata(),
            "Volume": dbus.Double(p.volume / 100),
            "Position": dbus.Int64(int(p.pos * 1e6)),
            "CanGoNext": True, "CanGoPrevious": True, "CanPlay": True,
            "CanPause": True, "CanSeek": True, "CanControl": True,
        }

    def changed(self, *keys):
        d = self.props(PLAYER)
        self.PropertiesChanged(PLAYER, {k: d[k] for k in keys}, [])

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, iface, prop):
        return self.props(iface)[prop]

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, iface):
        return self.props(iface)

    @dbus.service.method(PROPS, in_signature="ssv")
    def Set(self, iface, prop, value):
        if prop == "Volume":
            self.p.set_volume(float(value) * 100)
        elif prop == "LoopStatus":
            self.p.mode = "one" if value == "Track" else "list"
            self.p.emit_track()

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass

    @dbus.service.signal(PLAYER, signature="x")
    def Seeked(self, pos):
        pass

    @dbus.service.method(MPRIS)
    def Raise(self):
        subprocess.Popen(["qs", "ipc", "-c", "music", "call", "music", "open"])

    @dbus.service.method(MPRIS)
    def Quit(self):
        pass

    @dbus.service.method(PLAYER)
    def Next(self):
        self.p.next()

    @dbus.service.method(PLAYER)
    def Previous(self):
        self.p.prev()

    @dbus.service.method(PLAYER)
    def Pause(self):
        self.p.set_paused(True)

    @dbus.service.method(PLAYER)
    def Play(self):
        self.p.set_paused(False)

    @dbus.service.method(PLAYER)
    def PlayPause(self):
        self.p.toggle()

    @dbus.service.method(PLAYER)
    def Stop(self):
        self.p.set_paused(True)

    @dbus.service.method(PLAYER, in_signature="x")
    def Seek(self, offset):
        self.p.seek(self.p.pos + offset / 1e6)

    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track, pos):
        self.p.seek(pos / 1e6)

    @dbus.service.method(PLAYER, in_signature="s")
    def OpenUri(self, uri):
        pass


# ---------------------------------------------------------------- 播放器
class Player:
    def __init__(self):
        self.api = Api()
        self.clients = {}
        self.queue = []
        self.idx = -1
        self.mode = "list"      # list: 顺序播放; one: 单曲循环; shuffle: 随机播放
        self.source = ""
        self.playing = False
        self.pos = 0.0
        self.volume = 100.0
        self.loaded = None      # mpv 里当前加载的歌曲 id
        self.next_slot = 0      # 「加入播放列表」的插入位置
        self.fails = 0
        self.lyric = {"id": None, "lines": []}
        self.playlists = []
        self.base_playlists = []
        self.added_playlists = []
        self.removed_playlists = []
        self.collected = set()
        self.liked = set()
        self.profile = {}
        self.account_loading = False
        self.account_retry_announced = False
        self.last_pos_sent = -10
        self.restore()
        self.mpv = Mpv(self.on_mpv)
        self.mpris = Mpris(self)
        self.serve()
        self.reload_account()
        GLib.timeout_add_seconds(10, self.periodic_save)

    @property
    def shuffle(self):
        return self.mode == "shuffle"

    # ---- 持久化 ----
    def restore(self):
        try:
            with open(STATE_FILE) as f:
                d = json.load(f)
            self.queue = d.get("queue", [])
            self.idx = d.get("idx", -1)
            self.pos = d.get("pos", 0.0)
            mode = d.get("mode", "list")
            if mode not in ("list", "one", "shuffle"):
                mode = "list"
            if d.get("shuffle") and mode != "shuffle":  # 兼容旧状态
                mode = "shuffle"
            self.mode = mode
            self.source = d.get("source", "")
            self.volume = d.get("volume", 100.0)
            self.added_playlists = d.get("added_playlists", [])
            self.removed_playlists = d.get("removed_playlists", [])
            self.next_slot = self.idx + 1
            if self.current():
                bg(lambda: self.api.lyric(self.current()["id"]), self._lyric_cb(self.current()["id"]))
        except (OSError, ValueError):
            pass

    def save(self):
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump({"queue": self.queue, "idx": self.idx, "pos": self.pos, "mode": self.mode,
                       "source": self.source, "volume": self.volume,
                       "added_playlists": self.added_playlists,
                       "removed_playlists": self.removed_playlists}, f, ensure_ascii=False)
        os.replace(tmp, STATE_FILE)

    def periodic_save(self):
        if self.playing:
            self.save()
        return True

    # ---- 账号 ----
    def load_account(self):
        profile = self.api.account()
        if not profile:
            raise RuntimeError("cookie 失效，请在 netease-cloud-music-gtk4 里重新登录")
        own = [p for p in self.api.user_playlists() if p["creator"]["userId"] == self.api.uid]
        pls = {p["name"]: p for p in own}
        out = []
        for n in playlist_names() or [p["name"] for p in own]:
            if n in pls:
                p = pls[n]
                out.append({"key": str(p["id"]), "name": n, "cover": p.get("coverImgUrl", "").replace("http://", "https://") + "?param=120y120", "count": p["trackCount"]})
        out.append({"key": "daily", "name": "每日推荐", "cover": "", "count": 0})
        return profile, out, self.api.liked_ids()

    def reload_account(self):
        """账号 / 歌单 / 我喜欢只在启动时拉一次；
        失败（例如开机瞬间 DNS 还没就绪）时定时重试，否则侧栏会永远停在「加载中」"""
        if self.account_loading:
            return
        self.account_loading = True
        bg(self.load_account, self.on_account, self.on_account_fail)

    def on_account(self, r):
        self.account_loading = False
        self.account_retry_announced = False
        self.profile, self.base_playlists, liked = r
        self.playlists = self.build_playlists()
        self.liked = set(liked)
        self.broadcast_account()
        self.refresh_collected()

    def build_playlists(self):
        """账号歌单 + 自己收藏添加的歌单，去掉已从列表移除的"""
        out = [p for p in self.base_playlists if str(p["key"]) not in self.removed_playlists]
        keys = {str(p["key"]) for p in out}
        for p in self.added_playlists:
            k = str(p["key"])
            if k not in self.removed_playlists and k not in keys:
                out.append(p)
                keys.add(k)
        return out

    def broadcast_account(self):
        self.broadcast({"ev": "account", "nickname": self.profile.get("nickname", ""),
                        "playlists": self.playlists, "liked": list(self.liked)})

    def refresh_collected(self):
        """任一收藏歌单里包含的歌曲 id（星标点亮用）"""
        keys = [str(p["key"]) for p in self.playlists if p["key"] != "daily"]

        def work():
            ids = set()
            for k in keys:
                try:
                    ids.update(self.api.playlist_track_ids(int(k)))
                except Exception as e:  # noqa: BLE001
                    log("collected playlist", k, repr(e))
            return ids
        bg(work, self.on_collected, lambda e: None)

    def on_collected(self, ids):
        self.collected = set(ids)
        self.broadcast({"ev": "collected", "ids": list(self.collected)})

    def add_playlist(self, pl):
        key = str(pl.get("key") or pl.get("id"))
        if any(str(p["key"]) == key for p in self.playlists):
            self.toast("歌单已在列表中")
            return
        self.removed_playlists = [k for k in self.removed_playlists if k != key]
        item = {"key": key, "name": pl.get("name", ""), "cover": pl.get("cover", ""), "count": pl.get("count", 0)}
        self.added_playlists.append(item)
        self.playlists = self.build_playlists()
        self.broadcast_account()
        self.refresh_collected()
        self.save()
        self.toast(f"已收藏歌单：{item['name']}")

    def remove_playlist(self, key):
        key = str(key)
        name = next((p["name"] for p in self.playlists if str(p["key"]) == key), "")
        self.added_playlists = [p for p in self.added_playlists if str(p["key"]) != key]
        if key not in self.removed_playlists:
            self.removed_playlists.append(key)
        self.playlists = self.build_playlists()
        self.broadcast_account()
        self.refresh_collected()
        self.save()
        self.toast(f"已从列表移除：{name}")

    def on_account_fail(self, e):
        self.account_loading = False
        log("账号/歌单加载失败：", repr(e))
        if self.playlists:
            return
        if not self.account_retry_announced:
            self.account_retry_announced = True
            self.toast("歌单加载失败，正在自动重试")
        GLib.timeout_add_seconds(8, self._retry_account)

    def _retry_account(self):
        if self.playlists:
            return False
        self.reload_account()
        return False

    # ---- socket ----
    def serve(self):
        try:
            os.unlink(SOCK)
        except OSError:
            pass
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(SOCK)
        self.server.listen(8)
        GLib.io_add_watch(self.server.fileno(), GLib.IO_IN, self.accept)

    def accept(self, fd, cond):
        c, _ = self.server.accept()
        c.settimeout(2)
        self.clients[c.fileno()] = [c, b""]
        GLib.io_add_watch(c.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.on_client)
        self.send(c, self.snapshot())
        return True

    def on_client(self, fd, cond):
        ent = self.clients.get(fd)
        if not ent:
            return False
        try:
            data = ent[0].recv(65536)
        except OSError:
            data = b""
        if not data:
            self.drop(fd)
            return False
        ent[1] += data
        while b"\n" in ent[1]:
            line, ent[1] = ent[1].split(b"\n", 1)
            try:
                self.handle(json.loads(line), ent[0])
            except Exception as e:  # noqa: BLE001
                log("cmd error:", line[:200], repr(e))
        return True

    def drop(self, fd):
        ent = self.clients.pop(fd, None)
        if ent:
            ent[0].close()

    def send(self, c, msg):
        try:
            c.sendall(json.dumps(msg, ensure_ascii=False).encode() + b"\n")
        except OSError:
            self.drop(c.fileno())

    def broadcast(self, msg):
        for c, _ in list(self.clients.values()):
            self.send(c, msg)

    def toast(self, text):
        log("toast:", text)
        self.broadcast({"ev": "toast", "text": text})
        return False

    def snapshot(self):
        return {
            "ev": "snapshot", "song": self.current(), "index": self.idx, "total": len(self.queue),
            "source": self.source, "mode": self.mode, "playing": self.playing, "pos": self.pos,
            "lyric": self.lyric, "nickname": self.profile.get("nickname", ""),
            "playlists": self.playlists, "liked": list(self.liked),
            "volume": self.volume, "collected": list(self.collected),
        }

    # ---- 命令 ----
    def handle(self, m, client):
        c = m.get("cmd")
        if c == "toggle":
            self.toggle()
        elif c == "next":
            self.next()
        elif c == "prev":
            self.prev()
        elif c == "seek":
            self.seek(float(m["t"]))
        elif c == "volume":
            self.set_volume(float(m["v"]))
        elif c == "playSource":
            self.play_source(m["key"])
        elif c == "playPlaylist":
            self.play_playlist(int(m["id"]), m.get("name", "歌单"))
        elif c == "addPlaylist":
            self.add_playlist(m["playlist"])
        elif c == "removePlaylist":
            self.remove_playlist(m["key"])
        elif c == "playSong":
            self.play_song(m["song"])
        elif c == "enqueue":
            self.enqueue(m["song"])
        elif c == "playNow":
            self.play_now(m["song"])
        elif c == "playAll":
            self.play_list(m["songs"], m.get("source", ""), shuffle=False)
        elif c == "like":
            self.like(int(m["id"]), bool(m["like"]))
        elif c == "collect":
            self.collect(m["song"], m["pid"])
        elif c == "search":
            q, typ, seq = m["q"], m.get("type", "song"), m.get("seq", 0)
            fn = {"song": self.api.search_songs, "artist": self.api.search_artists,
                  "playlist": self.api.search_playlists}.get(typ, self.api.search_songs)
            bg(lambda: fn(q), lambda r: self.send(client, {"ev": "search", "type": typ, "seq": seq, "items": r}),
               lambda e: self.send(client, {"ev": "search", "type": typ, "seq": seq, "items": [], "error": str(e)}))
        elif c == "artist":
            aid = int(m["id"])
            bg(lambda: self.api.artist(aid),
               lambda r: self.send(client, {"ev": "artist", "info": r[0], "songs": r[1]}),
               lambda e: self.toast("歌手加载失败"))
        elif c == "mode":
            self.set_mode(m["mode"])
        elif c == "snapshot":
            self.send(client, self.snapshot())

    def set_mode(self, mode):
        if mode in ("list", "one", "shuffle"):
            self.mode = mode
            self.emit_track()

    def current(self):
        if 0 <= self.idx < len(self.queue):
            return self.queue[self.idx]
        return None

    def emit_track(self):
        self.broadcast({"ev": "track", "song": self.current(), "index": self.idx, "total": len(self.queue),
                        "source": self.source, "mode": self.mode})
        self.mpris.changed("Metadata", "PlaybackStatus", "LoopStatus", "Shuffle")

    def emit_status(self):
        self.broadcast({"ev": "status", "playing": self.playing, "pos": self.pos})
        self.mpris.changed("PlaybackStatus")

    def play_index(self, i, start=0.0):
        if not self.queue:
            return
        self.idx = i % len(self.queue)
        self.next_slot = self.idx + 1
        song = self.current()
        self.pos = start
        self.loaded = None
        self.lyric = {"id": song["id"], "lines": []}
        self.emit_track()
        self.broadcast({"ev": "lyric", **self.lyric})
        self.broadcast({"ev": "status", "playing": self.playing, "pos": self.pos})
        sid = song["id"]
        bg(lambda: self.api.song_url(sid), lambda url: self._load(sid, url, start),
           lambda e: self._load(sid, None, start))
        bg(lambda: self.api.lyric(sid), self._lyric_cb(sid))
        self.save()

    def _lyric_cb(self, sid):
        def cb(r):
            if self.current() and self.current()["id"] == sid:
                self.lyric = {"id": sid, "lines": merge_lyric(*r)}
                self.broadcast({"ev": "lyric", **self.lyric})
        return cb

    def _load(self, sid, url, start):
        song = self.current()
        if not song or song["id"] != sid:
            return
        if not url:
            self.fails += 1
            self.toast(f"无法播放：{song['name']}")
            if self.fails < 5 and len(self.queue) > 1:
                GLib.timeout_add(600, lambda: self.next(auto=True) and False)
            else:
                self.playing = False
                self.emit_status()
            return
        self.fails = 0
        self.loaded = sid
        opts = f"start={start:.2f}" if start > 0 else ""
        self.mpv.cmd("loadfile", url, "replace", -1, opts)
        self.mpv.set("pause", False)

    def set_paused(self, paused):
        if not paused and self.loaded is None:
            if self.current():
                self.playing = True
                self.play_index(self.idx, self.pos)
            return
        self.mpv.set("pause", paused)

    def toggle(self):
        self.set_paused(self.playing)

    def next(self, auto=False):
        if not self.queue:
            return
        if self.mode == "shuffle":
            self.play_index(self._random_index())
        else:
            self.play_index(self.idx + 1)

    def prev(self):
        if not self.queue:
            return
        if self.pos > 3:
            self.seek(0)
        elif self.mode == "shuffle":
            self.play_index(self._random_index())
        else:
            self.play_index(self.idx - 1)

    def _random_index(self):
        n = len(self.queue)
        if n <= 1:
            return max(0, self.idx)
        i = self.idx
        while i == self.idx:
            i = random.randrange(n)
        return i

    def seek(self, t):
        t = max(0.0, t)
        self.pos = t
        if self.loaded is not None:
            self.mpv.cmd("seek", t, "absolute")
        self.broadcast({"ev": "status", "playing": self.playing, "pos": self.pos})
        self.mpris.Seeked(dbus.Int64(int(t * 1e6)))

    def set_volume(self, v):
        self.volume = max(0.0, min(100.0, v))
        self.mpv.set("volume", self.volume)
        self.broadcast({"ev": "volume", "volume": self.volume})
        self.mpris.changed("Volume")

    def play_list(self, songs, source, shuffle):
        if not songs:
            self.toast("列表为空")
            return
        songs = list(songs)
        if shuffle:
            random.shuffle(songs)
        self.queue = songs
        self.source = source
        self.mode = "shuffle" if shuffle else "list"
        self.playing = True
        self.play_index(0)

    def play_source(self, key):
        pl = next((p for p in self.playlists if p["key"] == key), None)
        name = pl["name"] if pl else key
        if key == "daily":
            bg(self.api.daily_songs, lambda s: self.play_list(s, name, shuffle=False),
               lambda e: self.toast("每日推荐加载失败"))
        else:
            bg(lambda: self.api.playlist_songs(int(key)), lambda s: self.play_list(s, name, shuffle=True),
               lambda e: self.toast(f"{name} 加载失败"))

    def play_playlist(self, pid, name):
        """搜索到的歌单：直接顺序播放"""
        bg(lambda: self.api.playlist_songs(pid), lambda s: self.play_list(s, name, shuffle=False),
           lambda e: self.toast(f"{name} 加载失败"))

    def play_song(self, song):
        """直接播放：插到当前曲目之后并单曲循环"""
        if not self.queue:
            self.queue, self.idx = [song], 0
        else:
            self.queue.insert(self.idx + 1, song)
            self.idx += 1
        self.mode = "one"
        self.playing = True
        self.play_index(self.idx)

    def play_now(self, song):
        """单击搜索结果：插到当前曲目之后立即播放，之后继续原队列"""
        if not self.queue:
            self.queue, self.idx, self.source = [song], 0, "搜索"
        else:
            self.queue.insert(self.idx + 1, song)
            self.idx += 1
        self.mode = "list"
        self.playing = True
        self.play_index(self.idx)

    def enqueue(self, song):
        """加入播放列表：排在当前曲目之后（多次添加按添加顺序）"""
        if not self.queue:
            self.queue, self.source = [song], "搜索"
            self.playing = True
            self.play_index(0)
        else:
            slot = max(self.idx + 1, min(self.next_slot, len(self.queue)))
            self.queue.insert(slot, song)
            self.next_slot = slot + 1
            self.broadcast({"ev": "track", "song": self.current(), "index": self.idx, "total": len(self.queue),
                            "source": self.source, "mode": self.mode})
            self.save()
        self.toast(f"已加入播放列表：{song['name']}")

    def like(self, sid, like):
        def done(r):
            if r.get("code") == 200:
                (self.liked.add if like else self.liked.discard)(sid)
                self.broadcast({"ev": "liked", "id": sid, "liked": like})
                self.toast("已添加到我喜欢的音乐" if like else "已取消喜欢")
            else:
                self.toast("操作失败：" + str(r.get("message") or r.get("code")))
        bg(lambda: self.api.like(sid, like), done, lambda e: self.toast("网络错误"))

    def collect(self, song, pid):
        name = next((p["name"] for p in self.playlists if p["key"] == str(pid)), "歌单")

        def done(r):
            code = r.get("code")
            if code == 200:
                self.collected.add(song["id"])
                self.broadcast({"ev": "collected", "ids": list(self.collected)})
                self.toast(f"已收藏到 {name}")
            elif code == 502:
                self.toast(f"{name} 里已经有这首歌了")
            else:
                self.toast("收藏失败：" + str(r.get("message") or code))
        bg(lambda: self.api.collect(song["id"], pid), done, lambda e: self.toast("网络错误"))

    # ---- mpv 事件 ----
    def on_mpv(self, e):
        ev = e.get("event")
        if ev == "ready":
            self.mpv.set("volume", self.volume)
        elif ev == "property-change":
            name, data = e.get("name"), e.get("data")
            if name == "pause" and data is not None:
                playing = not data and self.loaded is not None
                if playing != self.playing:
                    self.playing = playing
                    self.emit_status()
            elif name == "time-pos" and data is not None and self.loaded is not None:
                self.pos = data
                if abs(data - self.last_pos_sent) >= 0.5:
                    self.last_pos_sent = data
                    self.broadcast({"ev": "pos", "pos": data})
        elif ev == "end-file":
            reason = e.get("reason")
            if reason in ("eof", "error") and self.loaded is not None:
                if reason == "error":
                    self.toast("播放出错，跳到下一首")
                self.loaded = None
                if self.mode == "one":
                    self.play_index(self.idx)
                elif self.mode == "shuffle":
                    self.play_index(self._random_index())
                else:
                    self.next(auto=True)


def main():
    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    player = Player()

    def quit_(*_):
        player.save()
        player.mpv.proc.terminate()
        loop.quit()
    try:
        from gi.repository import GLibUnix
        add = lambda sig: GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, sig, quit_)  # noqa: E731
    except ImportError:
        add = lambda sig: GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, quit_)  # noqa: E731
    add(signal.SIGTERM)
    add(signal.SIGINT)
    loop.run()


if __name__ == "__main__":
    main()
