import QtQuick

// 歌词列表：当前行居中、最大、亮色，向两侧逐渐变小变暗
ListView {
    id: lv

    model: Backend.lyrics
    currentIndex: Math.max(0, Backend.lyricIndex)
    interactive: false
    clip: true
    spacing: 2
    highlightRangeMode: ListView.StrictlyEnforceRange
    preferredHighlightBegin: height / 2 - 22
    preferredHighlightEnd: height / 2 + 22
    highlightMoveDuration: 450
    highlightMoveVelocity: -1

    delegate: Item {
        id: line
        required property int index
        required property var modelData
        readonly property int dist: Math.abs(index - Backend.lyricIndex)
        readonly property bool cur: index === Backend.lyricIndex

        width: lv.width
        height: col.implicitHeight + 8

        Column {
            id: col
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            transformOrigin: Item.Left
            scale: line.cur ? 1 : Math.max(0.74, 0.86 - (line.dist - 1) * 0.06)
            opacity: line.cur ? 1 : Math.max(0.12, 0.62 - (line.dist - 1) * 0.17)
            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 380 } }

            Text {
                width: parent.width
                text: line.modelData.text
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                color: line.cur ? Theme.primary : Theme.text
                Behavior on color { ColorAnimation { duration: 300 } }
                font.family: Theme.font
                font.pixelSize: 19
                font.weight: line.cur ? Font.DemiBold : Font.Normal
            }
            Text {
                width: parent.width
                visible: line.modelData.trans !== "" && line.dist <= 1
                text: line.modelData.trans
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: lv.count === 0
        text: Backend.song ? "纯音乐，请欣赏" : "从左侧选择歌单，或在右侧搜索"
        color: Theme.alpha(Theme.textDim, 0.6)
        font.family: Theme.font
        font.pixelSize: 15
    }
}
