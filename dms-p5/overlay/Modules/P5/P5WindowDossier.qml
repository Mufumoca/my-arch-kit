pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 当前窗口档案：一组大斜块从左上往右下斜着排开，每块包一项信息、互相隔开——
// 目标（图标 + 应用名）/ 标题 / App ID / 状态（PID、工作区、布局、尺寸）/ 动作（加窗口规则、终结进程）。
// 点信息块复制对应的值。
Item {
    id: root

    required property var popout   // FocusedWindowContextMenu

    readonly property string appId: popout.appId
    readonly property string appName: popout.appName
    readonly property string title: popout.windowTitle
    readonly property int pid: popout.pid
    readonly property var niriWin: CompositorService.isNiri && pid > 0 ? NiriService.windows.find(w => w.pid === pid) ?? null : null
    readonly property var niriWs: niriWin ? NiriService.allWorkspaces.find(ws => ws.id === niriWin.workspace_id) ?? null : null
    readonly property var winSize: niriWin?.layout?.window_size ?? null

    implicitWidth: 540
    implicitHeight: col.y + col.height + 26

    focus: true
    Keys.onEscapePressed: event => {
        root.popout.close();
        event.accepted = true;
    }

    // 一个斜块：index 决定往右错开多少、歪多少
    component Slab: Item {
        id: slab
        property int index: 0
        property color fill: P5.ink
        property color edge: P5.paper
        property color slabTint: P5.violet
        property bool clickable: false
        property bool danger: false
        default property alias inner: holder.data
        signal clicked

        readonly property bool hot: area.containsMouse
        x: index * 16
        width: root.width - 64 - x
        height: holder.childrenRect.height + 26
        rotation: index % 2 === 0 ? -2.4 : -1.2

        P5Plate {
            anchors.fill: parent
            seed: 700 + slab.index
            jitter: 4
            skew: P5.slant(Math.min(slab.height, 60)) * 0.9
            cutBottomRight: 10
            fillColor: area.pressed ? P5.blood : (slab.hot && slab.clickable ? (slab.danger ? P5.blood : P5.plumRaised) : slab.fill)
            borderWidth: 3
            borderColor: slab.edge
            slabColor: slab.slabTint
            slabOffset: slab.hot && slab.clickable ? Qt.point(10, 8) : Qt.point(6, 6)
            slabRotation: P5.rand(slab.index + 3, 4) * 3
        }
        Item {
            id: holder
            x: 22 + P5.slant(Math.min(slab.height, 60)) * 0.45
            y: 13
            width: slab.width - x - 30
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: slab.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slab.clicked()
        }

        Behavior on x {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }
    }

    // 竖着的大字：TARGET
    Text {
        x: root.width - 2
        y: 22
        text: "TARGET"
        rotation: 90
        transformOrigin: Item.TopLeft
        color: P5.alpha(P5.paper, 0.9)
        font.family: P5.displayFont
        font.pixelSize: 44
        style: Text.Outline
        styleColor: P5.ink
    }

    Column {
        id: col
        x: 16
        y: 14
        width: root.width - 16
        spacing: 12

        // 1. 目标
        Slab {
            index: 0
            fill: P5.violet
            edge: P5.paper
            slabTint: P5.ink

            Item {
                width: parent.width
                height: 72

                Item {
                    id: iconBox
                    width: 68
                    height: 68
                    rotation: -6
                    P5Plate {
                        anchors.fill: parent
                        seed: 77
                        jitter: 3
                        fillColor: P5.ink
                        borderWidth: 2.5
                        borderColor: P5.paper
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 48
                        source: Paths.getAppIcon(root.appId, DesktopEntries.heuristicLookup(root.appId))
                        asynchronous: true
                        mipmap: true
                    }
                }
                P5Tag {
                    x: iconBox.width + 16
                    y: 0
                    text: "WINDOW FILE"
                    pixelSize: 11
                    fillColor: P5.ink
                    textColor: P5.violet
                    tilt: -2
                }
                Text {
                    x: iconBox.width + 16
                    y: 20
                    width: parent.width - x
                    text: root.appName
                    elide: Text.ElideRight
                    color: P5.ink
                    font.family: P5.displayFont
                    font.pixelSize: 40
                }
            }
        }

        // 2. 标题
        Slab {
            index: 1
            clickable: root.title.length > 0
            onClicked: root.popout.copyValue(root.title)

            Column {
                width: parent.width
                spacing: 4
                Row {
                    spacing: 8
                    P5Tag {
                        text: "TITLE"
                        pixelSize: 12
                        fillColor: P5.paper
                        textColor: P5.ink
                    }
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "content_copy"
                        size: 14
                        color: P5.lilac
                    }
                }
                Text {
                    width: parent.width
                    text: root.title || "—"
                    color: P5.paper
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
        }

        // 3. App ID
        Slab {
            index: 2
            fill: P5.plum
            clickable: root.appId.length > 0
            onClicked: root.popout.copyValue(root.appId)

            Row {
                spacing: 10
                P5Tag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "APP ID"
                    pixelSize: 12
                    fillColor: P5.ink
                    textColor: P5.violet
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.appId || "—"
                    color: P5.paper
                    font.family: P5.labelFont
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    font.italic: true
                }
            }
        }

        // 4. 状态
        Slab {
            index: 3
            fill: P5.paper
            edge: P5.ink
            slabTint: P5.pink

            Row {
                spacing: 18
                Repeater {
                    model: [["PID", root.pid > 0 ? String(root.pid) : "—", true], ["WS", root.niriWs ? String(root.niriWs.idx) + (root.niriWs.name ? " " + root.niriWs.name : "") : "—", false], ["MODE", root.niriWin ? (root.niriWin.is_floating ? "FLOAT" : "TILE") : "—", false], ["SIZE", root.winSize ? root.winSize[0] + "×" + root.winSize[1] : "—", false]]

                    Column {
                        id: stat
                        required property var modelData
                        spacing: 0
                        Text {
                            text: stat.modelData[0]
                            color: P5.plum
                            font.family: P5.labelFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.italic: true
                        }
                        Text {
                            text: stat.modelData[1]
                            color: P5.ink
                            font.family: P5.displayFont
                            font.pixelSize: 24
                            MouseArea {
                                anchors.fill: parent
                                enabled: stat.modelData[2] && root.pid > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.popout.copyValue(root.pid)
                            }
                        }
                    }
                }
            }
        }

        // 5. 动作：两块并排的斜按钮
        Item {
            width: parent.width
            height: 58
            x: 4 * 16

            Repeater {
                model: [["rule", "add_task", "ADD RULE", "加窗口规则"], ["kill", "skull", "TAKE DOWN", "结束进程"]]

                Item {
                    id: act
                    required property var modelData
                    required property int index
                    readonly property bool danger: modelData[0] === "kill"
                    x: index * 200
                    width: 188
                    height: 52
                    rotation: index === 0 ? -3 : 2
                    visible: act.danger ? root.pid > 0 : true

                    P5Plate {
                        anchors.fill: parent
                        seed: 760 + act.index
                        jitter: 3
                        skew: 20
                        fillColor: actArea.pressed ? P5.blood : (actArea.containsMouse ? (act.danger ? P5.blood : P5.violet) : P5.ink)
                        borderWidth: 3
                        borderColor: P5.paper
                        slabColor: act.danger ? P5.pink : P5.violet
                        slabOffset: actArea.containsMouse ? Qt.point(8, 7) : Qt.point(5, 5)
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: act.modelData[1]
                            size: 22
                            color: actArea.containsMouse && !act.danger ? P5.ink : P5.paper
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: act.modelData[2]
                                color: actArea.containsMouse && !act.danger ? P5.ink : P5.paper
                                font.family: P5.displayFont
                                font.pixelSize: 19
                            }
                            Text {
                                text: act.modelData[3]
                                color: actArea.containsMouse && !act.danger ? P5.ink : P5.lilac
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }
                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: act.danger ? root.popout.killWindow() : root.popout.addWindowRule()
                    }
                }
            }
        }
    }
}
