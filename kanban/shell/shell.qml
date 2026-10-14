import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool open: false
    property real progress: 0
    property bool kbReady: false
    property string page: "board"
    property var targetScreen: Quickshell.screens[0]

    function show() {
        if (open) return;
        outputProc.running = true;
    }
    function hide() {
        open = false;
    }

    // 在当前聚焦的显示器上打开
    Process {
        id: outputProc
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const name = JSON.parse(text).name;
                    const s = Quickshell.screens.find(x => x.name === name);
                    if (s && !win.visible) root.targetScreen = s;
                } catch (e) {}
                Store.refreshDailies();
                root.open = true;
            }
        }
    }

    IpcHandler {
        target: "kanban"
        function toggle(): void {
            root.open ? root.hide() : root.show();
        }
        function open(): void {
            root.show();
        }
        function close(): void {
            root.hide();
        }
    }

    onOpenChanged: {
        anim.stop();
        anim.to = open ? 1 : 0;
        anim.duration = open ? 420 : 240;
        anim.easing.type = open ? Easing.OutBack : Easing.InCubic;
        anim.start();
        // 和 DMS 一致：窗口映射后再申请独占键盘焦点，否则 niri 不会给焦点
        kbReady = false;
        if (open) kbTimer.restart();
    }
    Timer {
        id: kbTimer
        interval: 40
        onTriggered: {
            root.kbReady = root.open;
            keys.forceActiveFocus();
        }
    }
    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        easing.overshoot: 0.7
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.open || root.progress > 0
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "kanban"
        WlrLayershell.keyboardFocus: root.open && root.kbReady ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        BackgroundEffect.blurRegion: Region {
            item: board
            radius: Theme.radius
        }

        // 打开时暂停 niri 快捷键，让 Mod+Q 等按键交给看板处理
        ShortcutInhibitor {
            window: win
            enabled: root.kbReady
        }
        Shortcut {
            sequences: ["Meta+Q"]
            context: Qt.WindowShortcut
            onActivated: root.hide()
        }

        // 点击面板外部关闭
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.hide()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Tab) {
                    root.page = root.page === "board" ? "daily" : "board";
                    e.accepted = true;
                }
            }
        }

        Rectangle {
            id: board

            width: Math.min(1240, parent.width * 0.74)
            height: Math.min(680, parent.height * 0.64)
            anchors.horizontalCenter: parent.horizontalCenter
            // 从屏幕上方滑到中央
            y: -height - 24 + root.progress * (height + 24 + (parent.height - height) / 2)
            radius: Theme.radius
            color: Theme.alpha(Theme.surface, 0.55)
            // 与 niri focus-ring 一致的紫色外圈
            border.width: 2
            border.color: Theme.primary

            MouseArea {
                anchors.fill: parent
                onClicked: keys.forceActiveFocus()
            }

            // 标题栏
            Item {
                id: top
                x: 22
                y: 14
                width: board.width - 44
                height: 34

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        text: "Kanban"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Text {
                        id: dateText
                        anchors.baseline: parent.children[0].baseline
                        text: new Date().toLocaleDateString(Qt.locale("zh_CN"), "M月d日 dddd")
                        color: Theme.alpha(Theme.textDim, 0.6)
                        font.family: Theme.font
                        font.pixelSize: 12
                        Connections {
                            target: root
                            function onOpenChanged() {
                                dateText.text = new Date().toLocaleDateString(Qt.locale("zh_CN"), "M月d日 dddd");
                            }
                        }
                    }
                }

                // 页面切换
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabs.implicitWidth + 6
                    height: 30
                    radius: 15
                    color: Theme.alpha(Theme.surface, 0.4)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.06)

                    Row {
                        id: tabs
                        anchors.centerIn: parent
                        Repeater {
                            model: [
                                { key: "board", label: "看板" },
                                { key: "daily", label: "每日 · " + Store.dailies.length }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: root.page === modelData.key
                                width: tl.implicitWidth + 24
                                height: 24
                                radius: 12
                                color: active ? Theme.alpha(Theme.primary, 0.2) : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text {
                                    id: tl
                                    anchors.centerIn: parent
                                    text: parent.modelData.label
                                    color: parent.active ? Theme.primary : Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.page = parent.modelData.key
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: content
                x: 16
                anchors.top: top.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: board.width - 32

                Row {
                    id: columns
                    anchors.fill: parent
                    spacing: 12
                    visible: root.page === "board"

                    KanbanColumn {
                        id: colTodo
                        key: "todo"
                        label: "TODO"
                        accent: Theme.outline
                        width: (columns.width - 24) / 3
                        height: columns.height
                    }
                    KanbanColumn {
                        id: colDoing
                        key: "doing"
                        label: "DOING"
                        accent: Theme.primary
                        width: (columns.width - 24) / 3
                        height: columns.height
                    }
                    KanbanColumn {
                        id: colDone
                        key: "done"
                        label: "DONE"
                        accent: Theme.tertiary
                        width: (columns.width - 24) / 3
                        height: columns.height
                    }
                }

                DailyView {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root.page === "daily"
                }
            }
        }

        // 拖拽命中检测
        Connections {
            target: Store
            function onDragXChanged() { win.updateDrop(); }
            function onDragYChanged() { win.updateDrop(); }
        }
        function updateDrop() {
            if (Store.dragId === "") return;
            for (const c of [colTodo, colDoing, colDone]) {
                const p = c.mapFromItem(null, Store.dragX, Store.dragY);
                if (p.x >= 0 && p.x <= c.width && p.y >= 0 && p.y <= c.height) {
                    Store.dropCol = c.key;
                    Store.dropIndex = c.indexAt(p.y);
                    return;
                }
            }
            Store.dropCol = "";
            Store.dropIndex = -1;
        }

        // 拖拽中的卡片
        Rectangle {
            visible: Store.dragId !== ""
            x: Store.dragX - Store.grabX
            y: Store.dragY - Store.grabY
            width: Store.dragW
            height: ghostText.implicitHeight + 24
            rotation: 1.5
            radius: 10
            color: Theme.alpha(Theme.card, 0.92)
            border.width: 1
            border.color: Theme.alpha(Theme.primary, 0.5)
            Text {
                id: ghostText
                x: 12
                y: 12
                width: parent.width - 24
                text: Store.dragTask ? Store.dragTask.title : ""
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }
}
