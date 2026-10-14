"""网易云音乐 API（复用 netease-cloud-music-gtk4 的登录 cookie）"""
import base64
import json
import os
import secrets
import subprocess

import requests

COOKIE_FILE = os.path.expanduser("~/.local/share/netease-cloud-music-gtk4/cookies.json")
BASE = "https://music.163.com"
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

# weapi 加密参数（网页端公开常量）
PRESET_KEY = b"0CoJUm6Qyw8W8jud"
IV = b"0102030405060708"
MODULUS = int(
    "00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7",
    16,
)
PUB_EXP = 0x010001


def _aes_cbc_b64(data: bytes, key: bytes) -> bytes:
    # 不依赖 pycryptodome，借用 openssl 做 AES-128-CBC
    out = subprocess.run(
        ["openssl", "enc", "-aes-128-cbc", "-K", key.hex(), "-iv", IV.hex(), "-base64", "-A"],
        input=data, capture_output=True, check=True,
    ).stdout
    return out.strip()


def _weapi(params: dict) -> dict:
    sec = secrets.token_hex(8).encode()
    text = json.dumps(params).encode()
    enc = _aes_cbc_b64(_aes_cbc_b64(text, PRESET_KEY), sec)
    rsa = pow(int(sec[::-1].hex(), 16), PUB_EXP, MODULUS)
    return {"params": enc.decode(), "encSecKey": format(rsa, "x").zfill(256)}


def _device_id():
    path = os.path.expanduser("~/.cache/music-card/device-id")
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        did = secrets.token_hex(16).upper()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(did)
        return did


def pic(url, size=300):
    if not url:
        return ""
    return url.replace("http://", "https://") + f"?param={size}y{size}"


def song_of(s: dict) -> dict:
    """统一歌曲结构"""
    ar = s.get("ar") or s.get("artists") or []
    al = s.get("al") or s.get("album") or {}
    return {
        "id": s["id"],
        "name": s.get("name", ""),
        "artist": " / ".join(a.get("name") or "" for a in ar),
        "artists": [{"id": a.get("id"), "name": a.get("name")} for a in ar],
        "album": al.get("name", ""),
        "cover": pic(al.get("picUrl")),
        "duration": s.get("dt") or s.get("duration") or 0,
    }


class Api:
    def __init__(self):
        self.s = requests.Session()
        self.s.headers.update({"Referer": BASE, "User-Agent": UA})
        self.uid = None
        self.load_cookies()

    def load_cookies(self):
        self.s.cookies.clear()
        with open(COOKIE_FILE) as f:
            for c in json.load(f):
                k, _, v = c["raw_cookie"].split(";")[0].partition("=")
                self.s.cookies.set(k, v, domain=".music.163.com")
        # 缺少设备类 cookie 时写操作（喜欢/收藏）会被风控拦截 (-460)
        dev = {
            "os": "pc",
            "appver": "3.0.18.203152",
            "osver": "Microsoft-Windows-10",
            "channel": "netease",
            "deviceId": _device_id(),
        }
        for k, v in dev.items():
            self.s.cookies.set(k, v, domain=".music.163.com")
        try:
            self.s.get(BASE + "/discover", timeout=10)  # 领取 NMTID
        except requests.RequestException:
            pass
        self.csrf = self.s.cookies.get("__csrf", "")

    def get(self, path, **params):
        r = self.s.get(BASE + path, params=params, timeout=10)
        return r.json()

    def post(self, path, **data):
        r = self.s.post(BASE + path, data=data, timeout=10)
        return r.json()

    def weapi(self, path, **params):
        params["csrf_token"] = self.csrf
        r = self.s.post(f"{BASE}/weapi{path}?csrf_token={self.csrf}", data=_weapi(params), timeout=10)
        return r.json()

    # ---- 账号 ----
    def account(self):
        p = self.get("/api/nuser/account/get").get("profile") or {}
        self.uid = p.get("userId")
        return p

    def user_playlists(self):
        d = self.get("/api/user/playlist", uid=self.uid, limit=1000)
        return d.get("playlist", [])

    def liked_ids(self):
        return self.get("/api/song/like/get", uid=self.uid).get("ids", [])

    # ---- 歌曲 ----
    def song_details(self, ids):
        out = []
        for i in range(0, len(ids), 500):
            c = json.dumps([{"id": x} for x in ids[i:i + 500]])
            out += self.post("/api/v3/song/detail", c=c).get("songs", [])
        return [song_of(s) for s in out]

    def playlist_songs(self, pid):
        d = self.get("/api/v6/playlist/detail", id=pid, n=100000)
        ids = [t["id"] for t in d["playlist"]["trackIds"]]
        return self.song_details(ids)

    def playlist_track_ids(self, pid):
        """只取歌单里的歌曲 id（不拉取歌曲详情）"""
        d = self.get("/api/v6/playlist/detail", id=pid, n=100000)
        return [t["id"] for t in (d.get("playlist") or {}).get("trackIds", [])]

    def daily_songs(self):
        d = self.get("/api/v3/discovery/recommend/songs")
        return [song_of(s) for s in (d.get("data") or {}).get("dailySongs", [])]

    def song_url(self, sid):
        d = self.get("/api/song/enhance/player/url/v1", ids=f"[{sid}]", level="exhigh", encodeType="flac")
        data = (d.get("data") or [{}])[0]
        return data.get("url")

    def lyric(self, sid):
        d = self.get("/api/song/lyric", id=sid, lv=-1, tv=-1)
        return (d.get("lrc") or {}).get("lyric", ""), (d.get("tlyric") or {}).get("lyric", "")

    # ---- 搜索 / 歌手 ----
    def search_songs(self, q, limit=10):
        d = self.get("/api/cloudsearch/pc", s=q, type=1, limit=limit)
        return [song_of(s) for s in (d.get("result") or {}).get("songs", [])]

    def search_artists(self, q, limit=10):
        d = self.get("/api/cloudsearch/pc", s=q, type=100, limit=limit)
        out = []
        for a in (d.get("result") or {}).get("artists", []):
            alias = a.get("alias") or a.get("trans") and [a["trans"]] or []
            out.append({
                "id": a["id"],
                "name": a["name"],
                "avatar": pic(a.get("img1v1Url") or a.get("picUrl"), 120),
                "desc": " / ".join(alias) if alias else f"{a.get('musicSize', 0)} 首歌曲 · {a.get('albumSize', 0)} 张专辑",
            })
        return out

    def search_playlists(self, q, limit=10):
        d = self.get("/api/cloudsearch/pc", s=q, type=1000, limit=limit)
        out = []
        for p in (d.get("result") or {}).get("playlists", []):
            cover = (p.get("coverImgUrl") or "").split("?")[0]
            out.append({
                "id": p["id"],
                "name": p.get("name", ""),
                "cover": pic(cover, 120),
                "count": p.get("trackCount", 0),
                "creator": (p.get("creator") or {}).get("nickname", ""),
            })
        return out

    def artist(self, aid):
        info = (self.get("/api/artist/head/info/get", id=aid).get("data") or {}).get("artist") or {}
        songs = self.get("/api/artist/top/song", id=aid).get("songs", [])
        return {
            "id": aid,
            "name": info.get("name", ""),
            "avatar": pic(info.get("avatar") or info.get("cover"), 200),
            "desc": info.get("briefDesc", ""),
        }, [song_of(s) for s in songs]

    # ---- 写操作 ----
    def like(self, sid, like=True):
        return self.weapi("/radio/like", alg="itembased", trackId=str(sid), like=like, time="3")

    def collect(self, sid, pid):
        return self.weapi("/playlist/manipulate/tracks", op="add", pid=str(pid), trackIds=json.dumps([sid]), imme="true")
