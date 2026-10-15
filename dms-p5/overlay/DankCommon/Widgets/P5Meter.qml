import QtQuick
import qs.DankCommon.Common

// P5 拉力条：平行四边形的槽 + 从左往右冲出去的填充，槽上有刻度，填充末端是一刀斜切。
// value 取 0..1；level 0/1/2 = 正常/偏高/危险（危险时填充闪成血红）。
Item {
    id: root

    property real value: 0
    property int level: 0
    property color fillColor: level >= 2 ? P5.blood : (level === 1 ? P5.pink : P5.violet)
    property color trackColor: P5.ink
    property color borderColor: P5.paper
    property int ticks: 10
    property int seed: P5.nextSeed()

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real slantPx: P5.slant(height) * 0.9

    implicitHeight: 16

    P5Plate {
        id: track
        anchors.fill: parent
        seed: root.seed
        jitter: 1
        skew: root.slantPx
        fillColor: root.trackColor
        borderWidth: 2
        borderColor: root.borderColor
    }

    // 填充：同样的斜切，左端对齐槽的左端
    Item {
        id: fillClip
        x: 3
        y: 3
        height: parent.height - 6
        width: Math.max(0, (parent.width - 6) * root.clamped)
        visible: root.clamped > 0.002

        Behavior on width {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: 520
                easing.type: Easing.BezierSpline
                easing.bezierCurve: P5.snapCurve
            }
        }

        P5Plate {
            anchors.fill: parent
            skew: P5.slant(height) * 0.9
            fillColor: root.fillColor
            accentColor: P5.paper
            stripes: 0.18
        }
    }

    // 刻度：细的斜线，压在槽上
    Repeater {
        model: Math.max(0, root.ticks - 1)

        Rectangle {
            required property int index
            x: (root.width - root.slantPx) * (index + 1) / root.ticks + root.slantPx / 2 - 1
            y: 3
            width: 1.5
            height: root.height - 6
            color: P5.alpha(P5.ink, 0.55)
            transform: Shear {
                xFactor: -root.slantPx / Math.max(1, root.height)
                origin.y: (root.height - 6) / 2
            }
        }
    }
}
