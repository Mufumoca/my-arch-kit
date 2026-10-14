import QtQuick
import Quickshell.Widgets

// 搜索结果 / 歌手热门歌曲的一行：加入播放列表 · 直接播放（单曲循环）
Rectangle {
    id: row

    required property var song
    property int number: 0
    property bool selected: false
    readonly property bool playingNow: Backend.song && Backend.song.id === song.id
    readonly property bool hot: hh.hovered || selected

    height: 44
    radius: 6
    color: hot ? Theme.alpha(Theme.text, 0.08) : "transparent"

    ClippingRectangle {
        id: cover
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        radius: 5
        color: Theme.alpha(Theme.primary, 0.18)
        Image {
            anchors.fill: parent
            source: row.song.cover || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            visible: row.playingNow
            color: Theme.alpha("#000000", 0.45)
        }
        Icon {
            anchors.centerIn: parent
            visible: row.playingNow
            name: "graphic_eq"
            size: 16
            color: Theme.primary
        }
    }
    Column {
        anchors.left: cover.right
        anchors.leftMargin: 8
        anchors.right: btns.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        Text {
            width: parent.width
            text: row.song.name
            elide: Text.ElideRight
            color: row.playingNow ? Theme.primary : Theme.text
            font.family: Theme.font
            font.pixelSize: 13
        }
        Text {
            width: parent.width
            text: row.song.artist + (row.song.album ? " · " + row.song.album : "")
            elide: Text.ElideRight
            color: Theme.alpha(Theme.textDim, 0.7)
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
    // HoverHandler 不会被按钮的 MouseArea 抢走悬停状态
    HoverHandler {
        id: hh
    }
    // 单击：插到当前曲目之后并立即播放（继续按队列往下放）
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Backend.playNow(row.song)
    }
    Row {
        id: btns
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        opacity: row.hot ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        IconButton {
            icon: "playlist_add"
            size: 28
            iconSize: 18
            onClicked: Backend.enqueue(row.song)
        }
        IconButton {
            icon: "repeat_one"
            size: 28
            iconSize: 18
            tint: Theme.primary
            onClicked: Backend.playSong(row.song)
        }
    }
}
