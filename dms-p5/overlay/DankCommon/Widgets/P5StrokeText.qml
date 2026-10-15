import QtQuick
import QtQuick.Shapes
import qs.DankCommon.Common

// 粗描边字（CSS 的 -webkit-text-stroke + paint-order: stroke fill）：描边只露在字形外侧，可再包一圈 halo。
// 用 PathText 画真正的轮廓描边，比 P5Comic 的 8 向偏移更适合十几像素的粗边。
// 尺寸取墨迹（含描边）的包围盒，(0,0) 就是墨迹左上角，排版时按墨迹对齐。
Item {
    id: root

    property string text: ""
    property string family: "Noto Sans"
    property real pixelSize: 32
    property int weight: Font.Black
    property bool italic: false
    property real letterSpacing: 0
    property color color: P5.paper
    property color strokeColor: P5.ink
    // 描边总宽，外露一半
    property real stroke: 0
    property color haloColor: "transparent"
    // halo 在描边之外再扩出的宽度
    property real halo: 0

    readonly property real _out: stroke / 2 + (haloColor.a > 0 ? halo : 0)

    implicitWidth: Math.ceil(shape.boundingRect.width + _out * 2)
    implicitHeight: Math.ceil(shape.boundingRect.height + _out * 2)

    component Glyphs: PathText {
        text: root.text
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.italic: root.italic
        font.letterSpacing: root.letterSpacing
    }

    Shape {
        id: shape
        x: root._out - boundingRect.x
        y: root._out - boundingRect.y
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.haloColor
            strokeWidth: root.haloColor.a > 0 && root.halo > 0 ? root.stroke + root.halo * 2 : -1
            fillColor: root.haloColor.a > 0 && root.halo > 0 ? root.haloColor : "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            Glyphs {}
        }
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: root.stroke > 0 ? root.stroke : -1
            fillColor: root.stroke > 0 ? root.strokeColor : "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            Glyphs {}
        }
        ShapePath {
            strokeWidth: -1
            fillColor: root.color
            Glyphs {}
        }
    }
}
