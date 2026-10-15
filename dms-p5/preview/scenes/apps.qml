import QtQuick
import Quickshell

// P5 应用列表（存档界面式）：假数据。P5_APPS=insert|query|empty 切换状态，P5_SEL=n 选中第 n 项
Item {
    Loader {
        anchors.fill: parent
        focus: true
        source: Qt.resolvedUrl("../Modules/P5/P5AppCarousel.qml")
        onLoaded: {
            const c = item;
            c.entries = [
            { name: "Firefox", desc: "浏览万维网", icon: "firefox" },
            { name: "kitty", desc: "Fast, feature-rich, GPU based terminal", icon: "kitty" },
            { name: "Visual Studio Code", desc: "Code Editing. Redefined.", icon: "visual-studio-code" },
            { name: "文件", desc: "访问和整理文件", icon: "org.gnome.Nautilus" },
            { name: "Telegram Desktop", desc: "Official desktop version of Telegram messaging app", icon: "telegram" },
            { name: "Steam", desc: "Application for managing and playing games on Steam", icon: "steam" },
            { name: "GIMP", desc: "Create images and edit photographs", icon: "gimp" },
            { name: "Blender", desc: "3D modeling, animation, rendering and post-production", icon: "blender" },
            { name: "mpv", desc: "Play movies and songs", icon: "mpv" },
            { name: "设置", desc: "", icon: "material:settings" },
            { name: "Obsidian", desc: "Obsidian", icon: "obsidian" },
            { name: "htop", desc: "Show System Processes", icon: "htop" },
            { name: "Thunderbird", desc: "Read and write e-mails", icon: "thunderbird" },
            { name: "LibreOffice Writer", desc: "Create and edit text and graphics in letters, reports", icon: "libreoffice-writer" }
            ].filter(() => Quickshell.env("P5_APPS") !== "empty");
            c.opened = true;
            const m = Quickshell.env("P5_APPS") || "";
            if (m === "insert" || m === "query" || m === "empty")
                c.setQuery(m === "empty" ? "zzz" : "code");
            if (m === "insert")
                c.enterInsert(4, true);
            c.sel = Number(Quickshell.env("P5_SEL") || 1);
            c.pos = c.sel;
        }
    }
}
