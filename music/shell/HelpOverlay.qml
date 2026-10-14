import QtQuick

// 按 ? 显示的快捷键说明
Rectangle {
    id: h
    signal clicked

    radius: Theme.radius
    color: Theme.alpha(Theme.surface, 0.9)

    readonly property var keys: [
        ["Space", "播放 / 暂停"], ["N  P", "下一首 / 上一首"],
        ["← →", "快退 / 快进 5 秒（Shift 15 秒）"], ["1 2 3", "播放歌单栏第 1 / 2 / 3 项"],
        ["F", "喜欢"], ["S  然后 1-9", "收藏到对应歌单"],
        ["R", "切换单曲循环"], ["/  Ctrl+F", "搜索（Tab 切换歌曲 / 歌手）"],
        ["↑ ↓  Enter", "选择 · 插队播放"], ["Ctrl+Enter", "加入播放列表"],
        ["Shift+Enter", "歌手页：播放全部"], ["L  B", "固定歌单栏 / 工具栏"],
        ["Esc", "收起浮层 / 返回"], ["Mod+M", "显示 · 聚焦 · 隐藏卡片"]
    ]

    MouseArea {
        anchors.fill: parent
        onClicked: h.clicked()
    }
    Grid {
        anchors.centerIn: parent
        columns: 4
        columnSpacing: 14
        rowSpacing: 8
        Repeater {
            model: h.keys.length * 2
            delegate: Text {
                required property int index
                readonly property var item: h.keys[Math.floor(index / 2)]
                text: index % 2 === 0 ? item[0] : item[1]
                color: index % 2 === 0 ? Theme.primary : Theme.textDim
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: index % 2 === 0 ? Font.DemiBold : Font.Normal
            }
        }
    }
}
