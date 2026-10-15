import QtQuick
import qs.DankCommon.Common

// P5 列表选中态：歪斜的淡紫块 + 白色错位板 + 一角粉色碎片，选中时从左侧带过冲地冲出；
// 悬停时只显示一块淡紫底和白描边。放在列表项的第一个子元素位置（在内容下面），列表项自身背景设为透明。
P5Plate {
    id: root

    property bool selected: false
    property bool hovered: false

    anchors.fill: parent
    anchors.leftMargin: Math.ceil(skew / 2) + 4
    anchors.rightMargin: Math.ceil(skew / 2) + 10
    anchors.topMargin: 3
    anchors.bottomMargin: 5

    seed: P5.nextSeed()
    jitter: 2.5
    skew: P5.slant(Math.min(height, 48)) * 0.6
    cutBottomRight: 6
    rotation: selected ? -0.8 : 0
    fillColor: selected ? P5.violet : P5.alpha(P5.violet, hovered ? 0.18 : 0)
    borderWidth: selected ? 3 : (hovered ? 1.5 : 0)
    borderColor: selected ? P5.paper : P5.alpha(P5.paper, 0.4)
    slabColor: selected ? P5.paper : "transparent"
    slabOffset: Qt.point(6, 4)
    slabRotation: 1.2
    slab2Color: selected ? P5.pink : "transparent"
    slab2Offset: Qt.point(-6, 3)
    slab2Rotation: -2
    accentColor: P5.paper
    stripes: selected ? 0.08 : 0

    transform: Scale {
        origin.x: 0
        origin.y: root.height / 2
        xScale: root.selected ? 1 : 0.9

        Behavior on xScale {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: P5.punchCurve
            }
        }
    }

    Behavior on fillColor {
        enabled: P5.motionEnabled
        ColorAnimation {
            duration: 90
        }
    }
}
