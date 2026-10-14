pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 跟随 DankMaterialShell 的 matugen 色板与壁纸；同步加载，锁屏第一帧就是正确配色
Singleton {
    id: theme

    property var c: ({})
    property var session: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                theme.c = d.colors[d.mode] || d.colors.dark;
            } catch (e) {}
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/DankMaterialShell/session.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                theme.session = JSON.parse(text());
            } catch (e) {}
        }
    }

    function pick(name, fallback) {
        return c[name] !== undefined ? c[name] : fallback;
    }
    function alpha(col, a) {
        const k = Qt.darker(col, 1.0);
        return Qt.rgba(k.r, k.g, k.b, a);
    }
    function mix(a, b, t) {
        const x = Qt.darker(a, 1.0), y = Qt.darker(b, 1.0);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
    }
    // 斜块厚度（垂直于斜线方向），锁屏与解锁 overlay 共用
    function bandFor(w, h) {
        return Math.min(w, h) * 0.17;
    }
    // 壁纸路径；DMS 纯色壁纸以 "#" 开头
    function wallpaperFor(screenName) {
        const s = session;
        if (s.perMonitorWallpaper && s.monitorWallpapers && s.monitorWallpapers[screenName])
            return s.monitorWallpapers[screenName];
        return s.wallpaperPath || "";
    }

    readonly property color primary: pick("primary", "#d0bcff")
    readonly property color deep: pick("primary_container", "#4f378b")
    readonly property color onPrimary: pick("on_primary", "#381e72")
    readonly property color surface: pick("surface", "#141218")
    readonly property color text: pick("on_surface", "#e6e0e9")
    readonly property color error: pick("error", "#f2b8b5")
    // 墨色：比 surface 更深、带一点主色倾向，用于斜块描边 / 字块
    readonly property color ink: mix(pick("surface_container_lowest", "#100e14"), deep, 0.18)
    readonly property color paper: "#faf8ff"
    readonly property color danger: "#ff4f6d"

    readonly property string display: "Adwaita Sans"
    readonly property string narrow: "Nimbus Sans Narrow"
    readonly property string serif: "Nimbus Roman"
    readonly property string serif2: "C059"
    readonly property string cjk: "Source Han Sans CN"
}
