import QtQuick
import qs.DankCommon.Common

// 飞刀：刀尖在本元素左侧中点（插进去的那一点），刀身朝右上翘起。
// 放置时把 x / y 对准刀尖要扎的位置即可（元素高度 30，刀尖在 y = 15）。throwIn() 播放旋转飞入并扎住。
Item {
    id: root

    property real angle: -38          // 静止时刀身的朝向（度），负数朝右上
    property color bladeColor: P5.paper
    property color edgeColor: P5.violet
    property color gripColor: P5.ink
    property color wrapColor: P5.violet

    width: 124
    height: 30
    transformOrigin: Item.Left

    function throwIn() {
        flight.restart();
    }

    rotation: angle
    transform: Translate {
        id: fly
    }

    SequentialAnimation {
        id: flight
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "rotation"
                from: root.angle + 400
                to: root.angle
                duration: 190
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: fly
                property: "x"
                from: 140
                to: 0
                duration: 190
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: fly
                property: "y"
                from: -120
                to: 0
                duration: 190
                easing.type: Easing.OutQuad
            }
        }
        // 扎住后的颤动
        NumberAnimation {
            target: root
            property: "rotation"
            to: root.angle - 5
            duration: 50
        }
        NumberAnimation {
            target: root
            property: "rotation"
            to: root.angle + 2.5
            duration: 60
        }
        NumberAnimation {
            target: root
            property: "rotation"
            to: root.angle
            duration: 80
        }
    }

    // 扎进去的刀口
    P5Poly {
        x: -6
        y: 8
        width: 20
        height: 14
        rotation: -root.angle * 0.4
        points: [[0, 7], [8, 2], [20, 6], [9, 12]]
        fillColor: P5.ink
    }

    // 刀身（刀尖埋在纸里，只露出一截）
    P5Poly {
        anchors.fill: parent
        points: [[4, 15], [16, 7], [62, 5], [66, 9], [66, 21], [62, 25], [16, 22]]
        fillColor: root.bladeColor
        strokeColor: P5.ink
        strokeWidth: 2.5
        slabColor: P5.alpha(P5.ink, 0.5)
        slabOffset: Qt.point(3, 4)
    }
    // 刃口的淡紫高光
    P5Poly {
        anchors.fill: parent
        points: [[10, 15], [20, 10], [60, 9], [60, 13], [20, 14]]
        fillColor: root.edgeColor
    }
    // 护手
    P5Poly {
        anchors.fill: parent
        points: [[64, 1], [72, 0], [73, 30], [65, 29]]
        fillColor: root.gripColor
        strokeColor: P5.paper
        strokeWidth: 1.5
    }
    // 握柄 + 缠绳
    Rectangle {
        x: 72
        y: 9
        width: 38
        height: 12
        color: root.gripColor
        border.width: 1.5
        border.color: P5.paper
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: 5 + index * 9
                y: 1.5
                width: 4
                height: 9
                rotation: 25
                color: root.wrapColor
            }
        }
    }
    // 柄尾的环
    Rectangle {
        x: 108
        y: 7
        width: 16
        height: 16
        radius: 8
        color: "transparent"
        border.width: 3.5
        border.color: root.gripColor
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1.5
            radius: width / 2
            color: "transparent"
            border.width: 1.2
            border.color: P5.paper
        }
    }
}
