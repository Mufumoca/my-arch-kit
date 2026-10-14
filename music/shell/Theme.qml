pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 跟随 DankMaterialShell 的 matugen 色板，换壁纸后自动更新
Singleton {
    id: theme

    property var c: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.cache/DankMaterialShell/dms-colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                theme.c = d.colors[d.mode] || d.colors.dark;
            } catch (e) {}
        }
    }

    FontLoader {
        id: icons
        source: Qt.resolvedUrl("fonts/MaterialSymbolsRounded.ttf")
    }

    function pick(name, fallback) {
        return c[name] !== undefined ? c[name] : fallback;
    }
    function alpha(col, a) {
        const k = Qt.darker(col, 1.0);
        return Qt.rgba(k.r, k.g, k.b, a);
    }
    function time(sec) {
        sec = Math.max(0, Math.floor(sec));
        const s = sec % 60;
        return Math.floor(sec / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property color surface: pick("surface", "#141218")
    readonly property color card: pick("surface_container_high", "#2b2930")
    readonly property color cardHigh: pick("surface_container_highest", "#36343b")
    readonly property color text: pick("on_surface", "#e6e0e9")
    readonly property color textDim: pick("on_surface_variant", "#cac4d0")
    readonly property color primary: pick("primary", "#d0bcff")
    readonly property color tertiary: pick("tertiary", "#efb8c8")
    readonly property color outline: pick("outline", "#948f99")
    readonly property color error: pick("error", "#f2b8b5")

    readonly property string font: "Noto Sans CJK SC"
    readonly property string iconFont: icons.name
    // 与 niri 窗口规则 geometry-corner-radius 一致
    readonly property int radius: 8
}
