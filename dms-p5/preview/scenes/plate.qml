import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets

Item {
    P5Plate {
        x: 60; y: 50; width: 420; height: 300
        cutTopLeft: P5.cut; cutBottomRight: P5.cut
        borderWidth: P5.strokeWidth
        borderColor: P5.alpha(P5.lilac, 0.45)
        slabColor: P5.violet
        slab2Color: P5.alpha(P5.paper, 0.9)
        slabOffset: Qt.point(8, 8)
        slab2Offset: Qt.point(-5, -5)
        stripes: 0.05; sheen: 0.12
        shadowColor: Qt.rgba(0,0,0,0.4); shadowBlur: 18; shadowOffset: Qt.point(0, 6)
    }
    P5Plate {
        x: 560; y: 60; width: 220; height: 34
        skew: 34 * P5.skew * 2
        fillColor: P5.ink
        slabColor: P5.violet
        slabOffset: Qt.point(4, 3)
    }
    P5Plate {
        x: 560; y: 120; width: 220; height: 34
        skew: 34 * P5.skew * 2
        fillColor: P5.paper
        slabColor: P5.violet
        slabOffset: Qt.point(-4, 3)
        accentBar: 6; borderColor: P5.violet
    }
    Text {
        x: 90; y: 80
        text: "PHANTOM VIOLET"
        font.family: P5.displayFont; font.pixelSize: 44
        color: P5.paper
    }
    Text {
        x: 90; y: 140
        text: "Take Your Heart · 怪盗団 · 22:36"
        font.family: P5.labelFont; font.pixelSize: 22; font.italic: true; font.weight: Font.Bold
        color: P5.lilac
    }
    Text {
        x: 90; y: 180
        text: "Body text in Barlow — 正文中文回落到思源黑体"
        font.family: P5.bodyFont; font.pixelSize: 15
        color: P5.paper
    }
}
