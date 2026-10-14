import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// 从卡片边缘滑入的浮层（left / right / bottom）
Rectangle {
    id: p

    property string edge: "left"
    property bool trigger: false   // 鼠标进入对应边缘
    property bool pinned: false    // 键盘打开，直到 Esc
    property bool keep: false      // 其他需要保持打开的情况
    property bool open: false
    property Item backdrop: null   // 毛玻璃要模糊的底层内容（卡片主体）
    readonly property bool wanted: trigger || pinned || keep || hovered
    property real progress: open ? 1 : 0

    onWantedChanged: {
        if (wanted) {
            closeTimer.stop();
            open = true;
        } else {
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: 260
        onTriggered: if (!p.wanted) p.open = false
    }
    readonly property bool hovered: hh.hovered
    default property alias content: inner.data

    Behavior on progress { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    visible: progress > 0
    opacity: Math.min(1, progress * 1.4)
    x: edge === "left" ? -width * (1 - progress) + 8 * progress
       : edge === "right" ? parent.width - width * progress - 8 * progress
       : (parent.width - width) / 2
    y: edge === "bottom" ? parent.height - height * progress - 8 * progress : 8
    height: edge === "bottom" ? implicitHeight : parent.height - 16
    radius: Theme.radius
    color: "transparent"

    // 毛玻璃：把底下的唱片 / 歌词截下来模糊，再盖一层半透明底色
    ClippingRectangle {
        anchors.fill: parent
        radius: p.radius
        color: "transparent"
        ShaderEffectSource {
            id: backSrc
            anchors.fill: parent
            sourceItem: p.backdrop
            sourceRect: Qt.rect(p.x, p.y, p.width, p.height)
            live: p.visible
            opacity: 0
        }
        MultiEffect {
            anchors.fill: parent
            visible: p.backdrop !== null
            source: backSrc
            blurEnabled: true
            blur: 0.6
            blurMax: 28
            saturation: 0.15
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.card, 0.25)
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: p.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.12)
    }

    HoverHandler {
        id: hh
    }
    // 吞掉面板上的点击，避免穿透到下层
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: w => w.accepted = true
    }
    Item {
        id: inner
        anchors.fill: parent
    }
}
