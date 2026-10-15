import QtQuick
import qs.DankCommon.Common

// 漫画大字（p5-reference/toggle-switch 的写法）：Luckiest Guy 墨色字 + 一圈粗描边，可选一层错位的彩色投影。
// 描边用 8 个方向的偏移副本叠出来（Text.Outline 只有 1px，太细）。中文没有该字形，会回落到系统字体，同样描边。
Item {
    id: root

    property string text: ""
    property real pixelSize: 32
    property string family: P5.comicFont
    property color fillColor: P5.ink
    property color outlineColor: P5.paper
    property real outline: 2.5
    property color shadowColor: "transparent"
    property point shadowOffset: Qt.point(4, 4)
    property real letterSpacing: 1

    implicitWidth: Math.ceil(face.implicitWidth + outline * 2)
    implicitHeight: Math.ceil(face.implicitHeight + outline * 2)
    width: implicitWidth
    height: implicitHeight

    component Glyphs: Text {
        text: root.text
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: Font.Black
        font.letterSpacing: root.letterSpacing
    }

    // 投影：整块描边形状平移
    Item {
        x: root.shadowOffset.x
        y: root.shadowOffset.y
        visible: root.shadowColor.a > 0
        Repeater {
            model: 8
            Glyphs {
                required property int index
                readonly property real a: index * Math.PI / 4
                x: root.outline + Math.round(Math.cos(a) * root.outline)
                y: root.outline + Math.round(Math.sin(a) * root.outline)
                color: root.shadowColor
            }
        }
    }
    Repeater {
        model: 8
        Glyphs {
            required property int index
            readonly property real a: index * Math.PI / 4
            x: root.outline + Math.cos(a) * root.outline
            y: root.outline + Math.sin(a) * root.outline
            color: root.outlineColor
        }
    }
    Glyphs {
        id: face
        x: root.outline
        y: root.outline
        color: root.fillColor
    }
}
