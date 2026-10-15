import QtQuick
import qs.DankCommon.Common

// 散乱的漫画大字：把 P5Comic 拆成单个字母，各自歪一点、上下错开、大小不一，挤在一起互相压住；
// 首字母放大，偶尔有字母反色（白字黑描边）。比整行 P5Comic 更随手，用作标题和空状态。
// 同一 seed + 同一文字的样子固定。
Row {
    id: root

    property string text: ""
    property real pixelSize: 32
    property int seed: 0
    property real outline: 2.5
    property color shadowColor: P5.violet
    property point shadowOffset: Qt.point(4, 4)
    property real firstScale: 1.35      // 首字母放大倍数
    property real tilt: 12              // 单个字母最大歪斜角度
    property real bounce: 0.2           // 上下错开的幅度（相对字号）

    spacing: -root.pixelSize * 0.07

    Repeater {
        model: root.text.split("")

        Item {
            id: cell

            required property string modelData
            required property int index

            readonly property bool blank: modelData === " "
            readonly property int key: root.seed * 97 + index * 31 + modelData.charCodeAt(0)
            readonly property real size: root.pixelSize * (index === 0 ? root.firstScale : 0.8 + 0.17 * (P5.rand(key, 1) + 1))
            readonly property bool flip: index > 0 && P5.rand(key, 2) > 0.3

            width: blank ? root.pixelSize * 0.3 : glyph.width * 0.92
            height: root.pixelSize * root.firstScale * 1.15

            P5Comic {
                id: glyph
                visible: !cell.blank
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.pixelSize * root.bounce * (P5.rand(cell.key, 3) + 1) / 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: cell.modelData
                pixelSize: cell.size
                outline: root.outline
                fillColor: cell.flip ? P5.paper : P5.ink
                outlineColor: cell.flip ? P5.ink : P5.paper
                shadowColor: root.shadowColor
                shadowOffset: root.shadowOffset
                rotation: P5.rand(cell.key, 4) * root.tilt
            }
        }
    }
}
