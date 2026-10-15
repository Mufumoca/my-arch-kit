pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 音乐页：左边是歪着的封面（白框 + 两层错位板），背后一颗随播放旋转的淡紫爆炸星；
// 右边是曲名白板 / 歌手淡紫板 / 锯齿进度条 / 斜切的控制键，播放键是一颗星。
Item {
    id: root

    property bool live: false

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property real length: MprisController.activePlayerStableLength
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
    readonly property real pos: player ? Math.max(0, player.position || 0) : 0
    readonly property real ratio: length > 0 ? Math.max(0, Math.min(1, (pos % Math.max(1, length)) / length)) : 0
    readonly property string title: player ? (MprisController.displayTrackTitle(player) || player.identity || "") : ""
    readonly property string artist: player?.trackArtist || ""
    readonly property string album: player?.trackAlbum || ""
    readonly property var players: MprisController.availablePlayers
    readonly property bool usePlayerVolume: !!player && player.volumeSupported && !(player.identity || "").toLowerCase().includes("chrom")
    readonly property real volume: usePlayerVolume ? player.volume : (AudioService.sink?.audio?.volume ?? 0)

    implicitWidth: 780
    implicitHeight: 330

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (usePlayerVolume)
            player.volume = v;
        else if (AudioService.sink?.audio)
            AudioService.sink.audio.volume = v;
    }
    function cyclePlayer() {
        if (!players || players.length < 2)
            return;
        const i = players.indexOf(player);
        MprisController.switchActivePlayer(players[(i + 1) % players.length]);
    }
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0)
            return "--:--";
        sec = Math.floor(sec);
        const m = Math.floor(sec / 60), s = sec % 60;
        return m + ":" + String(s).padStart(2, "0");
    }
    function handleKeyEvent(event) {
        switch (event.key) {
        case Qt.Key_Space:
            player?.togglePlaying();
            return true;
        case Qt.Key_Left:
            MprisController.previousOrRewind();
            return true;
        case Qt.Key_Right:
            player?.next();
            return true;
        case Qt.Key_Up:
            setVolume(volume + 0.05);
            return true;
        case Qt.Key_Down:
            setVolume(volume - 0.05);
            return true;
        }
        return false;
    }

    // MPRIS 的 position 不会自己刷新
    Timer {
        interval: 500
        repeat: true
        running: root.live && root.playing
        onTriggered: root.player?.positionChanged()
    }

    // 背景大字
    Text {
        x: root.width - 330
        y: root.height - 128
        text: "ON AIR"
        color: P5.alpha(P5.violet, 0.07)
        font.family: P5.displayFont
        font.pixelSize: 110
        rotation: -8
    }

    // ---- 封面 ----
    Item {
        id: artBox
        x: 38
        y: 44
        width: 240
        height: 240

        P5Burst {
            anchors.centerIn: parent
            width: 310
            height: 310
            spikes: 16
            depth: 0.3
            seed: 21
            fillColor: P5.alpha(P5.violet, 0.9)
            slabColor: P5.alpha(P5.pink, 0.6)
            slabOffset: Qt.point(10, 8)
            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 24000
                loops: Animation.Infinite
                running: root.live && root.playing && P5.motionEnabled
            }
        }

        Item {
            anchors.fill: parent
            rotation: -6

            P5Plate {
                anchors.fill: parent
                anchors.margins: -8
                seed: 22
                jitter: 3
                fillColor: P5.paper
                slabColor: P5.ink
                slabOffset: Qt.point(10, 10)
                slabRotation: 3
            }
            Rectangle {
                anchors.fill: parent
                color: P5.ink
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.player?.trackArtUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(480, 480)
                    smooth: true
                    mipmap: true
                }
                DankIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    name: "album"
                    size: 120
                    color: P5.plum
                }
            }
        }

        // 播放器标签：点一下换播放器
        P5Tag {
            x: -10
            y: parent.height - 6
            text: (root.player?.identity || "NO PLAYER").toUpperCase() + (root.players.length > 1 ? "  ⇄" : "")
            pixelSize: 12
            fillColor: P5.ink
            textColor: P5.violet
            borderWidth: 1.5
            borderColor: P5.violet
            tilt: -4
            MouseArea {
                anchors.fill: parent
                enabled: root.players.length > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cyclePlayer()
            }
        }
    }

    // ---- 右侧 ----
    Item {
        id: info
        x: artBox.x + artBox.width + 56
        y: 22
        width: root.width - x - 26
        height: root.height - 40

        P5Tag {
            id: nowTag
            text: root.playing ? "NOW PLAYING" : "PAUSED"
            family: P5.displayFont
            italic: false
            weight: Font.Normal
            pixelSize: 16
            fillColor: root.playing ? P5.pink : P5.ink
            textColor: root.playing ? P5.ink : P5.lilac
            borderWidth: root.playing ? 0 : 1.5
            borderColor: P5.lilac
            tilt: -4
        }

        // 曲名
        Item {
            id: titleBox
            y: nowTag.height + 10
            width: parent.width
            height: titleText.implicitHeight + 18

            P5Plate {
                width: Math.min(parent.width, titleText.implicitWidth + 46)
                height: parent.height
                rotation: -1.5
                seed: 23
                jitter: 3
                skew: 18
                fillColor: P5.paper
                slabColor: P5.violet
                slabOffset: Qt.point(6, 6)
            }
            Text {
                id: titleText
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40
                text: root.title || "NO SIGNAL"
                color: P5.ink
                rotation: -1.5
                font.pixelSize: 26
                font.weight: Font.Black
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Row {
            id: artistRow
            y: titleBox.y + titleBox.height + 10
            x: 14
            spacing: 10
            P5Tag {
                visible: root.artist.length > 0
                text: root.artist
                family: P5.bodyFont
                italic: false
                weight: Font.Black
                pixelSize: 15
                fillColor: P5.violet
                textColor: P5.ink
                tilt: 2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.album.length > 0
                width: Math.min(implicitWidth, info.width - 200)
                elide: Text.ElideRight
                text: "— " + root.album
                color: P5.lilac
                font.pixelSize: 13
                font.italic: true
                font.weight: Font.Bold
            }
        }

        // 进度
        Item {
            id: seek
            y: info.height - 112
            width: parent.width
            height: 40

            Text {
                id: posText
                anchors.verticalCenter: bar.verticalCenter
                text: root.fmt(root.length > 0 ? root.pos % Math.max(1, root.length) : root.pos)
                color: P5.paper
                font.family: P5.displayFont
                font.pixelSize: 20
            }
            P5Meter {
                id: bar
                anchors.left: posText.right
                anchors.leftMargin: 12
                anchors.right: lenText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                value: seekArea.pressed ? seekArea.dragRatio : root.ratio
                ticks: 16
                fillColor: P5.violet

                // 拨片
                P5Plate {
                    x: Math.max(0, Math.min(parent.width - width, (parent.width - 6) * parent.value - width / 2 + 3))
                    y: -7
                    width: 16
                    height: parent.height + 14
                    skew: 8
                    rotation: 6
                    fillColor: P5.paper
                    borderWidth: 2
                    borderColor: P5.ink
                }
                MouseArea {
                    id: seekArea
                    property real dragRatio: 0
                    anchors.fill: parent
                    anchors.margins: -8
                    enabled: !!root.player?.canSeek && root.length > 0
                    cursorShape: Qt.PointingHandCursor
                    function at(x) {
                        return Math.max(0, Math.min(1, (x - 8) / (width - 16)));
                    }
                    onPressed: mouse => dragRatio = at(mouse.x)
                    onPositionChanged: mouse => dragRatio = at(mouse.x)
                    onReleased: mouse => {
                        if (root.player)
                            root.player.position = at(mouse.x) * root.length;
                    }
                }
            }
            Text {
                id: lenText
                anchors.right: parent.right
                anchors.verticalCenter: bar.verticalCenter
                text: root.fmt(root.length)
                color: P5.lilac
                font.family: P5.displayFont
                font.pixelSize: 20
            }
        }

        // 控制
        Row {
            id: transport
            y: info.height - 64
            x: 8
            spacing: 14

            component Key: Item {
                id: key
                property string icon: ""
                property bool on: false
                property bool small: false
                signal hit
                width: small ? 42 : 58
                height: small ? 32 : 44
                anchors.verticalCenter: parent.verticalCenter
                P5Plate {
                    anchors.fill: parent
                    skew: 12
                    jitter: 1.5
                    seed: key.icon.length * 7
                    fillColor: keyArea.pressed ? P5.blood : (keyArea.containsMouse || key.on ? P5.violet : P5.ink)
                    borderWidth: 2
                    borderColor: P5.paper
                    slabColor: keyArea.containsMouse ? P5.pink : "transparent"
                    slabOffset: Qt.point(4, 4)
                }
                DankIcon {
                    anchors.centerIn: parent
                    name: key.icon
                    size: key.small ? 18 : 26
                    color: keyArea.containsMouse || key.on ? P5.ink : P5.paper
                }
                MouseArea {
                    id: keyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: key.hit()
                }
            }

            Key {
                small: true
                icon: "shuffle"
                visible: !!root.player?.shuffleSupported
                on: !!root.player?.shuffle
                onHit: if (root.player?.canControl) root.player.shuffle = !root.player.shuffle
            }
            Key {
                icon: "skip_previous"
                onHit: MprisController.previousOrRewind()
            }
            // 播放键：一颗星
            Item {
                width: 74
                height: 74
                anchors.verticalCenter: parent.verticalCenter
                P5Burst {
                    anchors.fill: parent
                    spikes: 9
                    depth: 0.32
                    seed: 31
                    rotation: playArea.containsMouse ? 12 : 0
                    fillColor: playArea.pressed ? P5.blood : (root.playing ? P5.pink : P5.violet)
                    strokeColor: P5.paper
                    strokeWidth: 3
                    slabColor: P5.ink
                    slabOffset: Qt.point(5, 5)
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                        }
                    }
                }
                DankIcon {
                    anchors.centerIn: parent
                    name: root.playing ? "pause" : "play_arrow"
                    size: 34
                    color: P5.ink
                }
                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.togglePlaying()
                }
            }
            Key {
                icon: "skip_next"
                onHit: root.player?.next()
            }
            Key {
                small: true
                visible: !!root.player?.loopSupported
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                on: !!root.player && root.player.loopState !== MprisLoopState.None
                onHit: {
                    if (!root.player?.canControl)
                        return;
                    const s = root.player.loopState;
                    root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist : (s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                }
            }
        }

        // 音量：小拉力条，滚轮调（和 NOW PLAYING 同一行，靠右）
        Item {
            anchors.right: parent.right
            y: nowTag.y + (nowTag.height - height) / 2
            width: 170
            height: 30

            DankIcon {
                id: volIcon
                anchors.verticalCenter: parent.verticalCenter
                name: root.volume <= 0.001 ? "volume_off" : (root.volume < 0.5 ? "volume_down" : "volume_up")
                size: 18
                color: P5.lilac
            }
            P5Meter {
                anchors.left: volIcon.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 14
                ticks: 5
                value: root.volume
                fillColor: P5.paper
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.setVolume((mouse.x - 24) / (width - 24))
                onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
    }
}
