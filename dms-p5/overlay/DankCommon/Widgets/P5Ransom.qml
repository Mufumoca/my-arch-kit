import QtQuick
import qs.DankCommon.Common

// P5 勒索信字：每个字符剪成一块歪斜的小纸片，白底黑字 / 黑底白字 / 淡紫底黑字轮换，
// 字体、字号、角度各不相同。同一位置同一字符的样子固定，字符变化时（比如分钟跳动）换一张“剪报”。
Row {
    id: root

    property string text: ""
    property real pixelSize: 16
    property int seed: 0

    spacing: 1

    Repeater {
        model: root.text.split("")

        Item {
            id: glyphBox

            required property string modelData
            required property int index

            readonly property bool blank: modelData === " "
            readonly property bool punct: /[:.,·\-\/]/.test(modelData)
            readonly property int key: root.seed * 131 + index * 17 + modelData.charCodeAt(0)
            // 相邻字符尽量换样式：位置决定基调，再随机偏一档
            readonly property int look: (index + (P5.rand(key, 1) > 0.2 ? 1 : 0)) % 3
            readonly property real size: root.pixelSize * (punct ? 1 : 0.9 + 0.3 * (P5.rand(key, 2) + 1) / 2)

            width: blank ? root.pixelSize * 0.35 : (punct ? glyph.implicitWidth + 1 : glyph.implicitWidth + root.pixelSize * 0.45)
            height: root.pixelSize * 1.35
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            P5Plate {
                anchors.fill: parent
                anchors.topMargin: root.pixelSize * 0.05 * (P5.rand(glyphBox.key, 3) + 1)
                anchors.bottomMargin: root.pixelSize * 0.05 * (P5.rand(glyphBox.key, 4) + 1)
                visible: !glyphBox.blank && !glyphBox.punct
                seed: glyphBox.key
                jitter: root.pixelSize * 0.1
                rotation: P5.rand(glyphBox.key, 5) * 11
                fillColor: glyphBox.look === 0 ? P5.paper : (glyphBox.look === 1 ? P5.ink : P5.violet)
                borderWidth: glyphBox.look === 1 ? 1.5 : 0
                borderColor: P5.paper
            }

            Text {
                id: glyph
                anchors.centerIn: parent
                anchors.verticalCenterOffset: glyphBox.punct ? 0 : P5.rand(glyphBox.key, 6) * root.pixelSize * 0.06
                text: glyphBox.modelData
                rotation: glyphBox.punct ? 0 : P5.rand(glyphBox.key, 7) * 9
                color: glyphBox.punct ? P5.paper : (glyphBox.look === 1 ? P5.paper : P5.ink)
                font.family: glyphBox.look === 1 ? P5.displayFont : P5.labelFont
                font.italic: glyphBox.look === 2
                font.weight: Font.Bold
                font.pixelSize: glyphBox.size
            }
        }
    }
}
