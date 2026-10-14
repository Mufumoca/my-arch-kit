import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects

// 音乐卡片：普通 xdg 窗口，交给 niri 管理（聚焦 / 移动 / 浮动 / 关闭都走 niri）
ShellRoot {
    id: root

    property bool help: false

    function show() {
        win.visible = true;
    }
    function hide() {
        win.visible = false;
    }
    // 未显示 -> 显示；已显示但没聚焦 -> 聚焦；已聚焦 -> 隐藏
    function toggle() {
        if (!win.visible) show();
        else if (keys.Window.active) hide();
        else focusProc.running = true;
    }

    Process {
        id: focusProc
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text).find(x => x.title === win.title && x.pid === Quickshell.processId);
                    if (w) Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(w.id)]);
                } catch (e) {}
            }
        }
    }

    IpcHandler {
        target: "music"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
        function playPause(): void { Backend.toggle(); }
        function next(): void { Backend.next(); }
        function prev(): void { Backend.prev(); }
        function search(): void {
            root.show();
            card.openSearch();
        }
        // 直接搜索：qs ipc -c music call music find 歌名 [song|artist]
        function find(q: string, type: string): void {
            root.show();
            card.openSearch();
            searchView.input.text = q;
            Backend.search(q, type === "artist" ? "artist" : "song");
        }
        // 固定显示某个浮层：playlists / toolbar / search / help / none
        function panel(name: string): void {
            root.show();
            card.closeOverlays();
            if (name === "playlists") left.pinned = true;
            else if (name === "toolbar") bottom.pinned = true;
            else if (name === "search") card.openSearch();
            else if (name === "help") root.help = true;
        }
    }

    FloatingWindow {
        id: win

        title: "Music Card"
        visible: false
        color: "transparent"
        implicitWidth: 717
        implicitHeight: 330
        minimumSize: Qt.size(600, 260)
        // niri 关闭窗口（Mod+Q）只是隐藏卡片，后端照常播放
        onClosed: visible = false

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.alpha(Theme.surface, 0.5)

            function openSearch() {
                search.pinned = true;
                searchView.focusInput();
            }
            function closeOverlays() {
                if (root.help) return root.help = false;
                if (toolbar.menuOpen) return toolbar.menuOpen = false;
                search.pinned = false;
                bottom.pinned = false;
                left.pinned = false;
                keys.forceActiveFocus();
            }

            // ---- 鼠标贴边浮现 ----
            readonly property int edge: 36
            property string zone: ""
            HoverHandler {
                id: hover
                onPointChanged: card.updateZone()
                onHoveredChanged: card.updateZone()
            }
            function updateZone() {
                if (!hover.hovered) {
                    zone = "";
                    return;
                }
                const p = hover.point.position;
                zone = p.x < edge ? "left" : p.x > width - edge ? "right" : p.y > height - edge ? "bottom" : "";
            }

            // 点空白处收起键盘焦点（让搜索栏可以自动收回）
            MouseArea {
                anchors.fill: parent
                onClicked: card.closeOverlays()
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: e => {
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    const shift = e.modifiers & Qt.ShiftModifier;
                    const k = e.key;
                    if (toolbar.menuOpen && k >= Qt.Key_1 && k <= Qt.Key_9) {
                        toolbar.collectTo(k - Qt.Key_1);
                        bottom.pinned = false;
                    } else if (k === Qt.Key_Space) {
                        Backend.toggle();
                    } else if (k === Qt.Key_Left) {
                        Backend.seek(Math.max(0, Backend.pos - (shift ? 15 : 5)));
                    } else if (k === Qt.Key_Right) {
                        Backend.seek(Math.min(Backend.duration - 1, Backend.pos + (shift ? 15 : 5)));
                    } else if (k === Qt.Key_N || k === Qt.Key_Period) {
                        Backend.next();
                    } else if (k === Qt.Key_P || k === Qt.Key_Comma) {
                        Backend.prev();
                    } else if (k >= Qt.Key_1 && k <= Qt.Key_3) {
                        const pl = Backend.playlists[k - Qt.Key_1];
                        if (pl) Backend.playSource(pl.key);
                    } else if (k === Qt.Key_F) {
                        if (Backend.song) Backend.like(Backend.song.id, !Backend.isLiked);
                    } else if (k === Qt.Key_S) {
                        bottom.pinned = true;
                        toolbar.openCollect();
                    } else if (k === Qt.Key_R) {
                        Backend.send({ cmd: "mode", mode: Backend.mode === "one" ? "list" : "one" });
                    } else if (k === Qt.Key_Slash || (ctrl && k === Qt.Key_F)) {
                        card.openSearch();
                    } else if (k === Qt.Key_L) {
                        left.pinned = !left.pinned;
                    } else if (k === Qt.Key_B) {
                        bottom.pinned = !bottom.pinned;
                    } else if (k === Qt.Key_Question) {
                        root.help = !root.help;
                    } else if (k === Qt.Key_Escape) {
                        card.closeOverlays();
                    } else {
                        return;
                    }
                    e.accepted = true;
                }
            }

            // ---- 主体：唱片 + 歌名 + 歌词 ----
            // 浮层所在区域从主体里挖掉，只显示浮层里的模糊版本（毛玻璃）
            Item {
                id: mainWrap
                anchors.fill: parent

                Item {
                    id: main
                    anchors.fill: parent

                    Disc {
                        id: disc
                        active: win.visible
                        width: Math.min(card.height - 20, card.width * 0.42)
                        height: width
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        id: right
                        anchors.left: disc.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 28
                        anchors.top: parent.top
                        anchors.topMargin: 22
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18

                        Column {
                            id: titleCol
                            width: parent.width
                            spacing: 3
                            Text {
                                width: parent.width
                                text: Backend.song ? Backend.song.name : "Music Card"
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                            }
                            Row {
                                width: parent.width
                                spacing: 6
                                Text {
                                    width: Math.min(implicitWidth, parent.width - srcTag.width - 6)
                                    text: Backend.song ? Backend.song.artist : (Backend.online ? Backend.nickname : "播放服务未连接")
                                    elide: Text.ElideRight
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                }
                                Rectangle {
                                    id: srcTag
                                    visible: Backend.source !== "" || Backend.mode === "one"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: srcRow.implicitWidth + 12
                                    height: 18
                                    radius: 9
                                    color: Theme.alpha(Theme.primary, 0.14)
                                    Row {
                                        id: srcRow
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Icon {
                                            visible: Backend.mode === "one"
                                            name: "repeat_one"
                                            size: 12
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: Backend.mode === "one" ? "单曲循环" : Backend.source
                                            color: Theme.primary
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }

                        Lyrics {
                            anchors.top: titleCol.bottom
                            anchors.topMargin: 8
                            anchors.bottom: parent.bottom
                            width: parent.width
                        }
                    }
                }
            }
            Item {
                id: panelMask
                anchors.fill: parent
                Repeater {
                    model: [left, search, bottom]
                    Rectangle {
                        required property var modelData
                        x: modelData.x
                        y: modelData.y
                        width: modelData.width
                        height: modelData.height
                        radius: Theme.radius
                        visible: modelData.visible
                        opacity: modelData.opacity
                    }
                }
            }
            // 用 hideSource 取纹理：原物不直接显示，由下面的 MultiEffect 带遮罩画出
            ShaderEffectSource {
                id: mainSrc
                anchors.fill: parent
                sourceItem: mainWrap
                hideSource: true
                opacity: 0
            }
            ShaderEffectSource {
                id: maskSrc
                anchors.fill: parent
                sourceItem: panelMask
                hideSource: true
                opacity: 0
            }
            MultiEffect {
                anchors.fill: parent
                source: mainSrc
                maskEnabled: true
                maskInverted: true
                maskSource: maskSrc
                maskThresholdMin: 0.5
            }

            // ---- 浮层 ----
            Panel {
                id: left
                backdrop: main
                edge: "left"
                width: 210
                trigger: card.zone === "left"
                Sidebar {
                    anchors.fill: parent
                    anchors.margins: 8
                    focusIndex: left.pinned ? 0 : -1
                    onPicked: left.pinned = false
                }
            }

            Panel {
                id: search
                backdrop: main
                edge: "right"
                width: Math.min(400, card.width * 0.52)
                trigger: card.zone === "right"
                keep: searchView.input.activeFocus
                onOpenChanged: if (!open && searchView.input.activeFocus) keys.forceActiveFocus()
                SearchPanel {
                    id: searchView
                    anchors.fill: parent
                    onCloseRequested: {
                        search.pinned = false;
                        keys.forceActiveFocus();
                    }
                }
            }

            Panel {
                id: bottom
                backdrop: main
                edge: "bottom"
                width: card.width - 16
                implicitHeight: 52
                trigger: card.zone === "bottom"
                keep: toolbar.menuOpen
                Toolbar {
                    id: toolbar
                    anchors.fill: parent
                    onMenuOpenChanged: if (!menuOpen) bottom.pinned = false
                }
            }

            // ---- 提示 ----
            Rectangle {
                id: toast
                property string text: ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: toastText.implicitWidth + 28
                height: 30
                radius: 15
                color: Theme.alpha(Theme.cardHigh, 0.8)
                border.width: 1
                border.color: Theme.alpha(Theme.primary, 0.3)
                opacity: toastTimer.running ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Text {
                    id: toastText
                    anchors.centerIn: parent
                    text: toast.text
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Timer {
                    id: toastTimer
                    interval: 2200
                }
                Connections {
                    target: Backend
                    function onToast(t) {
                        toast.text = t;
                        toastTimer.restart();
                    }
                }
            }

            HelpOverlay {
                anchors.fill: parent
                visible: root.help
                onClicked: root.help = false
            }
        }
    }
}
