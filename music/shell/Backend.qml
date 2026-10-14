pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 与 backend/musicd.py 通信（$XDG_RUNTIME_DIR/music-card.sock，每行一个 JSON）
Singleton {
    id: be

    property bool online: sock.connected
    property var song: null
    property int index: -1
    property int total: 0
    property string source: ""
    property string mode: "list"
    property bool playing: false
    property real pos: 0
    readonly property real duration: song ? song.duration / 1000 : 0
    property var lyrics: []
    property int lyricIndex: -1
    property string nickname: ""
    property var playlists: []
    property var liked: ({})
    property var collected: ({})
    property real volume: 100
    readonly property bool isLiked: song ? liked[song.id] === true : false
    readonly property bool isCollected: song ? collected[song.id] === true : false

    property var searchItems: []
    property string searchType: "song"
    property bool searching: false
    property int searchSeq: 0
    property var artistInfo: null
    property var artistSongs: []

    signal toast(string text)

    // 本地插值播放进度，后端每 0.5s 校准一次
    property real basePos: 0
    property real baseTime: 0
    function setPos(p) {
        basePos = p;
        baseTime = Date.now();
        pos = p;
        updateLyric();
    }
    Timer {
        interval: 50
        repeat: true
        running: be.playing
        onTriggered: {
            be.pos = Math.min(be.basePos + (Date.now() - be.baseTime) / 1000, be.duration || 1e9);
            be.updateLyric();
        }
    }
    function updateLyric() {
        const t = pos + 0.2;
        let lo = 0, hi = lyrics.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lyrics[mid].t <= t) {
                ans = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        if (ans !== lyricIndex) lyricIndex = ans;
    }

    function send(obj) {
        if (!sock.connected) {
            toast("播放服务未运行：systemctl --user start music-card");
            return;
        }
        sock.write(JSON.stringify(obj) + "\n");
        sock.flush();
    }
    function toggle() { send({ cmd: "toggle" }); }
    function next() { send({ cmd: "next" }); }
    function prev() { send({ cmd: "prev" }); }
    function seek(t) {
        setPos(t);
        send({ cmd: "seek", t: t });
    }
    function playSource(key) { send({ cmd: "playSource", key: key }); }
    function playPlaylist(id, name) { send({ cmd: "playPlaylist", id: id, name: name }); }
    function addPlaylist(pl) { send({ cmd: "addPlaylist", playlist: pl }); }
    function removePlaylist(key) { send({ cmd: "removePlaylist", key: key }); }
    function isPlaylistAdded(id) {
        for (const p of playlists) if (String(p.key) === String(id)) return true;
        return false;
    }
    function setMode(mode) { send({ cmd: "mode", mode: mode }); }
    function setVolume(v) {
        volume = Math.max(0, Math.min(100, v));
        send({ cmd: "volume", v: volume });
    }
    function playSong(s) { send({ cmd: "playSong", song: s }); }
    function enqueue(s) { send({ cmd: "enqueue", song: s }); }
    function playNow(s) { send({ cmd: "playNow", song: s }); }
    function playAll(songs, name) { send({ cmd: "playAll", songs: songs, source: name }); }
    function like(id, v) { send({ cmd: "like", id: id, like: v }); }
    function collect(s, pid) { send({ cmd: "collect", song: s, pid: pid }); }
    function search(q, type) {
        q = q.trim();
        searchType = type;
        artistInfo = null;
        if (!q) {
            searchItems = [];
            return;
        }
        searching = true;
        send({ cmd: "search", q: q, type: type, seq: ++searchSeq });
    }
    function openArtist(id) {
        artistInfo = { id: id, name: "", avatar: "", desc: "" };
        artistSongs = [];
        send({ cmd: "artist", id: id });
    }

    function handle(m) {
        switch (m.ev) {
        case "snapshot":
            nickname = m.nickname;
            playlists = m.playlists;
            setLiked(m.liked);
            setCollected(m.collected);
            if (m.volume !== undefined) volume = m.volume;
            applyTrack(m);
            playing = m.playing;
            lyrics = m.lyric.lines;
            setPos(m.pos);
            break;
        case "account":
            nickname = m.nickname;
            playlists = m.playlists;
            setLiked(m.liked);
            break;
        case "track":
            applyTrack(m);
            break;
        case "status":
            playing = m.playing;
            setPos(m.pos);
            break;
        case "pos":
            setPos(m.pos);
            break;
        case "lyric":
            if (song && m.id === song.id) {
                lyrics = m.lines;
                lyricIndex = -1;
                updateLyric();
            }
            break;
        case "liked": {
            const l = Object.assign({}, liked);
            if (m.liked) l[m.id] = true;
            else delete l[m.id];
            liked = l;
            break;
        }
        case "collected":
            setCollected(m.ids);
            break;
        case "volume":
            volume = m.volume;
            break;
        case "search":
            if (m.seq !== searchSeq) return;
            searching = false;
            searchItems = m.items;
            if (m.error) toast("搜索失败");
            break;
        case "artist":
            if (artistInfo && artistInfo.id === m.info.id) {
                artistInfo = m.info;
                artistSongs = m.songs;
            }
            break;
        case "toast":
            toast(m.text);
            break;
        }
    }
    function applyTrack(m) {
        if (!song || !m.song || song.id !== m.song.id) {
            lyrics = [];
            lyricIndex = -1;
        }
        song = m.song;
        index = m.index;
        total = m.total;
        source = m.source;
        mode = m.mode;
    }
    function setLiked(ids) {
        const l = {};
        for (const id of ids) l[id] = true;
        liked = l;
    }
    function setCollected(ids) {
        const l = {};
        for (const id of (ids || [])) l[id] = true;
        collected = l;
    }

    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/music-card.sock"
        connected: true
        parser: SplitParser {
            onRead: line => {
                try {
                    be.handle(JSON.parse(line));
                } catch (e) {
                    console.warn("music-card: bad message", e);
                }
            }
        }
    }
    // 后端重启后自动重连
    Timer {
        interval: 1500
        repeat: true
        running: !sock.connected
        onTriggered: sock.connected = true
    }
}
