import QtQuick
import qs.DankCommon.Common

// P5 标签：一块歪斜的小板 + 粗体压缩字，用于标题、标注、数值牌。
// 尺寸由文字决定；tilt 是整体旋转角度。
Item {
    id: root

    property string text: ""
    property real pixelSize: 13
    property string family: P5.labelFont
    property bool italic: true
    property int weight: Font.Bold
    property color fillColor: P5.ink
    property color textColor: P5.paper
    property color borderColor: "transparent"
    property real borderWidth: 0
    property color slabColor: "transparent"
    property point slabOffset: Qt.point(3, 3)
    property real padX: pixelSize * 0.7
    property real padY: pixelSize * 0.18
    property real tilt: 0
    property int seed: P5.nextSeed()
    property real jitter: 1.5
    property real letterSpacing: 0.5
    property alias label: txt

    implicitWidth: Math.ceil(txt.implicitWidth + padX * 2)
    implicitHeight: Math.ceil(txt.implicitHeight + padY * 2)
    width: implicitWidth
    height: implicitHeight
    rotation: tilt

    P5Plate {
        anchors.fill: parent
        seed: root.seed
        jitter: root.jitter
        skew: P5.slant(height) * 0.7
        fillColor: root.fillColor
        borderColor: root.borderColor
        borderWidth: root.borderWidth
        slabColor: root.slabColor
        slabOffset: root.slabOffset
        slabRotation: P5.rand(root.seed, 3) * 3
    }

    Text {
        id: txt
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.italic: root.italic
        font.weight: root.weight
        font.letterSpacing: root.letterSpacing
    }
}
