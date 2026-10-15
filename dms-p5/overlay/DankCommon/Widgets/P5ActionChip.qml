import QtQuick
import qs.DankCommon.Common

// 小号斜切图标钮：通知气泡 / 通知纸条右下角的动作。悬停时上方冒出动作名。
Item {
    id: root

    property string icon: "touch_app"
    property string hint: ""
    property bool dark: false
    signal activated

    width: 30
    height: 26

    P5Plate {
        anchors.fill: parent
        skew: 8
        fillColor: area.pressed ? P5.blood : (area.containsMouse ? P5.violet : (root.dark ? P5.ink : P5.violet))
        borderWidth: 1.5
        borderColor: P5.ink
        slabColor: area.containsMouse ? P5.ink : "transparent"
        slabOffset: Qt.point(2, 3)
    }
    DankIcon {
        anchors.centerIn: parent
        name: root.icon
        size: 16
        color: area.containsMouse || !root.dark ? P5.ink : P5.paper
    }
    P5Tag {
        visible: area.containsMouse && root.hint.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 5
        z: 10
        text: root.hint
        family: P5.bodyFont
        italic: false
        pixelSize: 11
        fillColor: P5.ink
        textColor: P5.paper
        tilt: -3
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
