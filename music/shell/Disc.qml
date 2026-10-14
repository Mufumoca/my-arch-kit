import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// 左侧唱片：内圈封面随播放旋转，外圈一圈竖线随 cava 频谱跳动
Item {
    id: disc

    property bool active: true      // 窗口可见时才跑 cava（暂停时也保持运行，避免 autosens 重新爬升）
    readonly property int bars: 96   // cava 输出 48 段，左右镜像成一圈
    readonly property real coverR: width * 0.33
    readonly property real ringR: width * 0.37
    readonly property real maxLen: width * 0.12
    property var levels: []

    Process {
        running: disc.active
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";");
                v.pop();
                disc.levels = v;
            }
        }
        onRunningChanged: if (!running) disc.levels = []
    }

    // 外圈竖线
    Repeater {
        model: disc.bars
        delegate: Item {
            required property int index
            readonly property int half: disc.bars / 2
            // 0 点在正上方，左右对称：低频在顶部，高频在底部
            readonly property int band: index < half ? index : disc.bars - 1 - index
            readonly property real level: Backend.playing ? (disc.levels[band] || 0) / 100 : 0
            x: disc.width / 2
            y: disc.height / 2
            rotation: index * 360 / disc.bars

            Rectangle {
                width: 2.5
                height: 3 + level * disc.maxLen
                radius: 1.25
                x: -width / 2
                y: -disc.ringR - height
                antialiasing: true
                color: Theme.primary
                opacity: 0.35 + level * 0.65
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }

    // 唱片本体
    Item {
        id: vinyl
        width: disc.coverR * 2
        height: width
        anchors.centerIn: parent

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.alpha(Theme.surface, 0.6)
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.08)
        }
        // 唱片纹路
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: vinyl.width * (0.94 - index * 0.06)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.05)
            }
        }
        ClippingRectangle {
            anchors.centerIn: parent
            width: vinyl.width * 0.76
            height: width
            radius: width / 2
            color: Theme.card
            Image {
                anchors.fill: parent
                source: Backend.song ? Backend.song.cover : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
            Icon {
                anchors.centerIn: parent
                visible: !Backend.song
                name: "music_note"
                size: parent.width * 0.35
                color: Theme.alpha(Theme.textDim, 0.4)
            }
        }
        // 中心孔
        Rectangle {
            anchors.centerIn: parent
            width: vinyl.width * 0.06
            height: width
            radius: width / 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 24000
            loops: Animation.Infinite
            running: true
            paused: !Backend.playing
        }
    }
}
