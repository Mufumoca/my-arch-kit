import QtQuick
import Quickshell.Widgets

// 右侧搜索：歌曲 / 歌手，歌手进入个人页（热门歌曲）
Item {
    id: sp

    property alias input: field
    property int sel: -1
    readonly property bool artistPage: Backend.artistInfo !== null
    readonly property var rows: artistPage ? Backend.artistSongs : Backend.searchItems
    signal closeRequested

    function focusInput() {
        field.forceActiveFocus();
        field.selectAll();
    }
    function setType(t) {
        if (Backend.searchType === t && !artistPage) return;
        Backend.searchType = t;
        Backend.search(field.text, t);
        sel = -1;
    }
    function activate(enqueue) {
        if (debounce.running) {
            debounce.stop();
            Backend.search(field.text, Backend.searchType);
            return;
        }
        const i = Math.max(0, sel);
        if (i >= rows.length) return;
        const it = rows[i];
        if (!artistPage && Backend.searchType === "artist") {
            Backend.openArtist(it.id);
            sel = -1;
        } else if (!artistPage && Backend.searchType === "playlist") {
            Backend.playPlaylist(it.id, it.name);
        } else if (enqueue) {
            Backend.enqueue(it);
        } else {
            Backend.playNow(it);
        }
    }
    function back() {
        Backend.artistInfo = null;
        sel = -1;
    }

    Timer {
        id: debounce
        interval: 450
        onTriggered: Backend.search(field.text, Backend.searchType)
    }

    // 搜索框
    Rectangle {
        id: box
        x: 10
        y: 10
        width: parent.width - 20
        height: 34
        radius: 17
        color: Theme.alpha(Theme.text, 0.06)
        border.width: 1
        border.color: field.activeFocus ? Theme.alpha(Theme.primary, 0.6) : Theme.alpha(Theme.text, 0.08)

        Icon {
            id: sicon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 18
        }
        TextInput {
            id: field
            anchors.left: sicon.right
            anchors.leftMargin: 6
            anchors.right: tabs.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.text
            selectionColor: Theme.alpha(Theme.primary, 0.4)
            font.family: Theme.font
            font.pixelSize: 13
            onTextEdited: {
                sp.sel = -1;
                Backend.artistInfo = null;
                debounce.restart();
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !field.text
                text: Backend.searchType === "song" ? "搜索歌曲"
                    : Backend.searchType === "artist" ? "搜索歌手" : "搜索歌单"
                color: Theme.alpha(Theme.textDim, 0.5)
                font: field.font
            }
            Keys.onPressed: e => {
                const ctrl = e.modifiers & Qt.ControlModifier;
                if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)) {
                    sp.sel = Math.min(sp.rows.length - 1, sp.sel + 1);
                } else if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_K)) {
                    sp.sel = Math.max(sp.artistPage ? -1 : 0, sp.sel - 1);
                } else if (e.key === Qt.Key_Tab) {
                    const order = ["song", "artist", "playlist"];
                    sp.setType(order[(order.indexOf(Backend.searchType) + 1) % order.length]);
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    if (sp.artistPage && (e.modifiers & Qt.ShiftModifier || sp.sel < 0))
                        Backend.playAll(Backend.artistSongs, Backend.artistInfo.name);
                    else
                        sp.activate(ctrl);
                } else if (e.key === Qt.Key_Escape) {
                    if (sp.artistPage) sp.back();
                    else sp.closeRequested();
                } else if (e.key === Qt.Key_Backspace && sp.artistPage && field.text === "") {
                    sp.back();
                } else {
                    return;
                }
                e.accepted = true;
            }
        }
        Row {
            id: tabs
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [{ k: "song", l: "歌曲" }, { k: "artist", l: "歌手" }, { k: "playlist", l: "歌单" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: Backend.searchType === modelData.k
                    width: 40
                    height: 26
                    radius: 13
                    color: on ? Theme.alpha(Theme.primary, 0.2) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.l
                        color: parent.on ? Theme.primary : Theme.textDim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sp.setType(parent.modelData.k)
                    }
                }
            }
        }
    }

    // 歌手个人页头部
    Item {
        id: head
        visible: sp.artistPage
        anchors.top: box.bottom
        anchors.topMargin: 8
        x: 10
        width: parent.width - 20
        height: visible ? 56 : 0

        IconButton {
            id: backBtn
            anchors.verticalCenter: parent.verticalCenter
            icon: "arrow_back"
            size: 28
            iconSize: 18
            onClicked: sp.back()
        }
        ClippingRectangle {
            id: avatar
            anchors.left: backBtn.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 48
            radius: 24
            color: Theme.alpha(Theme.primary, 0.15)
            Image {
                anchors.fill: parent
                source: sp.artistPage ? Backend.artistInfo.avatar : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            anchors.left: avatar.right
            anchors.leftMargin: 10
            anchors.right: playAll.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: sp.artistPage ? Backend.artistInfo.name : ""
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: Backend.artistSongs.length ? "热门 " + Backend.artistSongs.length + " 首" : "加载中…"
                color: Theme.alpha(Theme.textDim, 0.7)
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
        Rectangle {
            id: playAll
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: pal.implicitWidth + 40
            height: 30
            radius: 15
            color: pama.containsMouse || sp.sel < 0 ? Theme.primary : Theme.alpha(Theme.primary, 0.85)
            Row {
                id: pal
                anchors.centerIn: parent
                spacing: 2
                Icon {
                    name: "play_arrow"
                    filled: true
                    size: 18
                    color: Theme.pick("on_primary", "#381e72")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "播放全部"
                    color: Theme.pick("on_primary", "#381e72")
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
            MouseArea {
                id: pama
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Backend.playAll(Backend.artistSongs, Backend.artistInfo.name)
            }
        }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        x: 6
        width: parent.width - 12
        clip: true
        spacing: 2
        model: sp.rows
        currentIndex: sp.sel
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 120
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Loader {
            id: ld
            required property var modelData
            required property int index
            width: list.width
            sourceComponent: sp.artistPage ? songRow
                : Backend.searchType === "artist" ? artistRow
                : Backend.searchType === "playlist" ? playlistRow : songRow

            Component {
                id: songRow
                SongRow {
                    song: ld.modelData
                    number: ld.index + 1
                    selected: sp.sel === ld.index
                }
            }
            Component {
                id: artistRow
                Rectangle {
                    height: 52
                    radius: 6
                    color: ama.containsMouse || sp.sel === ld.index ? Theme.alpha(Theme.text, 0.08) : "transparent"
                    ClippingRectangle {
                        id: av
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: Theme.alpha(Theme.primary, 0.15)
                        Image {
                            anchors.fill: parent
                            source: ld.modelData.avatar || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Column {
                        anchors.left: av.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: ld.modelData.name || ""
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            text: ld.modelData.desc || ""
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.textDim, 0.7)
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: ama
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sp.sel = -1;
                            Backend.openArtist(ld.modelData.id);
                        }
                    }
                }
            }
            Component {
                id: playlistRow
                Rectangle {
                    height: 52
                    radius: 6
                    color: plma.containsMouse || sp.sel === ld.index ? Theme.alpha(Theme.text, 0.08) : "transparent"
                    ClippingRectangle {
                        id: pcover
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 6
                        color: Theme.alpha(Theme.primary, 0.15)
                        Image {
                            anchors.fill: parent
                            source: ld.modelData.cover || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Column {
                        anchors.left: pcover.right
                        anchors.leftMargin: 10
                        anchors.right: padd.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            text: ld.modelData.name || ""
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            text: (ld.modelData.creator ? ld.modelData.creator + " · " : "") + (ld.modelData.count || 0) + " 首"
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.textDim, 0.7)
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: plma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sp.sel = -1;
                            Backend.playPlaylist(ld.modelData.id, ld.modelData.name);
                        }
                    }
                    IconButton {
                        id: padd
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Backend.isPlaylistAdded(ld.modelData.id) ? "check" : "playlist_add"
                        tint: Backend.isPlaylistAdded(ld.modelData.id) ? Theme.primary : Theme.textDim
                        size: 28
                        iconSize: 18
                        onClicked: Backend.addPlaylist(ld.modelData)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0 && (Backend.searching || field.text !== "")
            text: Backend.searching ? "搜索中…" : "没有结果"
            color: Theme.alpha(Theme.textDim, 0.5)
            font.family: Theme.font
            font.pixelSize: 12
        }
    }
}
