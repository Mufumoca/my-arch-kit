import QtQuick
import Quickshell.Widgets

// 左侧歌单栏：封面 + 歌单名；右键可从列表移除
Item {
    id: side

    property int focusIndex: -1  // 键盘高亮
    property string ctxKey: ""   // 右键菜单目标歌单
    property real ctxY: 0
    signal picked

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 4

        Text {
            x: 6
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: "歌单"
            color: Theme.textDim
            font.family: Theme.font
            font.pixelSize: 12
        }

        Repeater {
            model: Backend.playlists
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: Backend.source === modelData.name
                readonly property bool hot: ma.containsMouse || side.focusIndex === index

                width: side.width
                height: 48
                radius: Theme.radius
                color: hot ? Theme.alpha(Theme.text, 0.08) : current ? Theme.alpha(Theme.primary, 0.14) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                ClippingRectangle {
                    id: cover
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 6
                    color: Theme.alpha(Theme.primary, 0.18)
                    Image {
                        anchors.fill: parent
                        visible: row.modelData.cover !== ""
                        source: row.modelData.cover
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: row.modelData.key === "daily"
                        text: new Date().getDate()
                        color: Theme.primary
                        font.family: Theme.font
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                }
                Text {
                    anchors.left: cover.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    elide: Text.ElideRight
                    color: row.current ? Theme.primary : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 14
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            side.ctxKey = String(row.modelData.key);
                            side.ctxY = row.y + mouse.y;
                        } else {
                            Backend.playSource(row.modelData.key);
                            side.picked();
                        }
                    }
                }
            }
        }

        Text {
            visible: Backend.playlists.length === 0
            x: 6
            text: Backend.online ? "加载中…" : "播放服务未连接"
            color: Theme.alpha(Theme.textDim, 0.6)
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // 点击其它地方关闭右键菜单
    MouseArea {
        anchors.fill: parent
        visible: side.ctxKey !== ""
        onClicked: side.ctxKey = ""
    }

    // 右键菜单
    Rectangle {
        id: ctx
        visible: side.ctxKey !== ""
        width: 116
        height: 34
        radius: 6
        x: 4
        y: Math.min(side.ctxY, side.height - height - 4)
        color: Theme.alpha(Theme.cardHigh, 0.95)
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.12)
        Text {
            anchors.centerIn: parent
            text: "从列表移除"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Backend.removePlaylist(side.ctxKey);
                side.ctxKey = "";
            }
        }
    }
}
