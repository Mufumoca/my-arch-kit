import QtQuick
import QtQuick.Shapes
import qs.DankCommon.Common

// 任意多边形（像素坐标，相对本元素）：用于五边形条、通缉令、飞刀、对话气泡尾巴等 P5Plate 画不了的形状。
// points: [[x, y], ...]；可选的错位板 slabPoints 默认是同形状平移 slabOffset。
Item {
    id: root

    property var points: []
    property color fillColor: P5.ink
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property color slabColor: "transparent"
    property point slabOffset: Qt.point(6, 6)
    property var slabPoints: null
    property int joinStyle: ShapePath.MiterJoin

    function _path(pts, dx, dy) {
        if (!pts || pts.length < 2)
            return [];
        const out = [];
        for (let i = 0; i < pts.length; i++)
            out.push(Qt.point(pts[i][0] + dx, pts[i][1] + dy));
        out.push(Qt.point(pts[0][0] + dx, pts[0][1] + dy));
        return out;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.slabColor.a > 0

        ShapePath {
            readonly property var pts: root.slabPoints ?? root.points
            readonly property real dx: root.slabPoints ? 0 : root.slabOffset.x
            readonly property real dy: root.slabPoints ? 0 : root.slabOffset.y
            strokeWidth: -1
            fillColor: root.slabColor
            PathPolyline {
                path: root._path(parent.pts, parent.dx, parent.dy)
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.strokeWidth > 0 ? root.strokeWidth : -1
            strokeColor: root.strokeColor
            fillColor: root.fillColor
            joinStyle: root.joinStyle
            PathPolyline {
                path: root._path(root.points, 0, 0)
            }
        }
    }
}
