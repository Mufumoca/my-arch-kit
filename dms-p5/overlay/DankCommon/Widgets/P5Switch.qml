import QtQuick
import qs.DankCommon.Common

// P5 开关（照 p5-reference/toggle-switch）：关时是白框墨底 + 左边一块白色楔形，字压在右边往左歪；
// 开时框和斜块换成主色，字甩到左边往右歪，整体抖一下。offText / onText 是两种状态的字。
Item {
    id: root

    property bool checked: false
    property string offText: "OFF"
    property string onText: "ON"
    property color accent: P5.violet
    signal toggled(bool checked)

    implicitWidth: 90
    implicitHeight: 40

    // 抖一下（打开时）
    SequentialAnimation {
        id: shake
        NumberAnimation {
            target: body
            property: "rotation"
            to: 5
            duration: 50
        }
        NumberAnimation {
            target: body
            property: "rotation"
            to: -5
            duration: 50
        }
        NumberAnimation {
            target: body
            property: "rotation"
            to: 0
            duration: 50
        }
    }
    onCheckedChanged: if (checked && P5.motionEnabled) shake.restart()

    Item {
        id: body
        width: 90
        height: 40

        // 框
        Rectangle {
            anchors.fill: parent
            color: P5.ink
            border.width: 3
            border.color: root.checked ? root.accent : P5.paper
        }
        // 关：白色楔形
        P5Poly {
            anchors.fill: parent
            visible: !root.checked
            points: [[6, 37], [26, 3], [50, 14], [86, 37]]
            fillColor: P5.paper
        }
        // 开：主色斜块 + 错位
        P5Poly {
            anchors.fill: parent
            visible: root.checked
            points: [[8, 3], [70, 13], [60, 41], [-3, 30]]
            fillColor: root.accent
            slabColor: root.accent
            slabOffset: Qt.point(-6, 3)
        }

        P5Comic {
            id: label
            x: root.checked ? -24 : 40
            y: -6
            rotation: root.checked ? 10 : -10
            text: root.checked ? root.onText : root.offText
            pixelSize: 36
            outline: 2
            outlineColor: root.checked ? root.accent : P5.paper
            Behavior on x {
                enabled: P5.motionEnabled
                NumberAnimation {
                    duration: 100
                }
            }
            Behavior on rotation {
                enabled: P5.motionEnabled
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
