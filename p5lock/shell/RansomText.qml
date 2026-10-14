import QtQuick

// 勒索信式拼贴字：每个字母独立的底块、字体、倾角与大小（P5 招牌排版）
Item {
    id: root

    property string text: ""
    property real size: 100
    property int seed: 7
    property real spacing: -size * 0.05

    implicitWidth: row.implicitWidth
    implicitHeight: size * 1.25

    // 确定性伪随机，同一个名字每次锁屏排版一致
    function rnd(i, k) {
        const x = Math.sin(seed * 3.17 + i * 12.9898 + k * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    readonly property var styles: [
        { bg: Theme.paper, fg: Theme.ink, family: Theme.display, weight: Font.Black, italic: true, outline: false },
        { bg: Theme.ink, fg: Theme.paper, family: Theme.serif, weight: Font.Bold, italic: false, outline: false },
        { bg: Theme.primary, fg: Theme.ink, family: Theme.narrow, weight: Font.Bold, italic: false, outline: false },
        { bg: "transparent", fg: Theme.paper, family: Theme.serif2, weight: Font.Bold, italic: true, outline: true },
        { bg: Theme.deep, fg: Theme.paper, family: Theme.display, weight: Font.Black, italic: false, outline: false }
    ]

    // 相邻字母不重复样式
    readonly property var plan: {
        const out = [];
        let prev = -1;
        const chars = Array.from(text);
        for (let i = 0; i < chars.length; i++) {
            let s = Math.floor(rnd(i, 0) * styles.length);
            if (s === prev)
                s = (s + 1 + Math.floor(rnd(i, 5) * (styles.length - 1))) % styles.length;
            prev = s;
            out.push({
                ch: chars[i],
                style: s,
                rot: (rnd(i, 1) - 0.5) * 18,
                scale: 0.86 + rnd(i, 2) * 0.26,
                dy: (rnd(i, 3) - 0.5) * 0.14
            });
        }
        return out;
    }

    function play() {
        for (let i = 0; i < rep.count; i++)
            rep.itemAt(i).play();
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            id: rep
            model: root.plan

            Item {
                id: letter

                required property var modelData
                required property int index
                readonly property var st: root.styles[modelData.style]
                readonly property real s: root.size * modelData.scale
                property real pop: 1

                function play() {
                    popAnim.restart();
                }

                width: box.width
                height: root.size * 1.25

                SequentialAnimation {
                    id: popAnim
                    PropertyAction { target: letter; property: "pop"; value: 0 }
                    PauseAnimation { duration: 140 + letter.index * 55 }
                    NumberAnimation { target: letter; property: "pop"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }

                Item {
                    id: box

                    width: label.implicitWidth + letter.s * 0.16
                    height: letter.s * 1.02
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: letter.modelData.dy * root.size
                    rotation: letter.modelData.rot + (1 - letter.pop) * 50
                    scale: 0.2 + letter.pop * 0.8
                    opacity: Math.min(1, letter.pop * 2)

                    // 硬投影
                    Rectangle {
                        visible: letter.st.bg !== "transparent"
                        x: letter.s * 0.07
                        y: letter.s * 0.07
                        width: parent.width
                        height: parent.height
                        color: "#000000"
                        antialiasing: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: letter.st.bg
                        antialiasing: true
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: letter.s * 0.03
                        text: letter.modelData.ch
                        color: letter.st.fg
                        style: letter.st.outline ? Text.Outline : Text.Normal
                        styleColor: Theme.ink
                        font.family: letter.st.family
                        font.weight: letter.st.weight
                        font.italic: letter.st.italic
                        font.pixelSize: letter.s
                    }
                }
            }
        }
    }
}
