import QtQuick
import QtQuick.Shapes

// 右下角电源菜单：箭头方块 → 向左拉出的“予告信”信封 → 翻盖打开 → 三张卡片依次弹出
// 坐标系为屏幕坐标，父级铺满整屏即可。关机 / 重启需再点一次确认，挂起直接执行
Item {
    id: root

    property real u: 1
    property real reveal: 1
    property real fadeOut: 0
    property bool disabled: false

    property bool open: false
    // 0→1 驱动整套开合：拉伸信封 → 翻盖 → 卡片弹出；关闭时倒放
    property real t: 0
    property int sel: -1
    property int armed: -1

    signal action(string name)

    readonly property var items: [
        { name: "poweroff", label: "SHUT DOWN", icon: "\uf011", confirm: true },
        { name: "reboot", label: "REBOOT", icon: "\uf2f9", confirm: true },
        { name: "suspend", label: "SUSPEND", icon: "\uf186", confirm: false }
    ]

    function clamp01(x) {
        return Math.max(0, Math.min(1, x));
    }
    function outExpo(x) {
        return x >= 1 ? 1 : 1 - Math.pow(2, -10 * x);
    }
    function outBack(x) {
        const c = 2.6;
        return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2);
    }
    function inOut(p) {
        return p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
    }
    function pop(i) {
        return outBack(clamp01((t - 0.52 - i * 0.1) / 0.28));
    }

    readonly property real stretch: outExpo(clamp01(t / 0.4))
    readonly property real flap: inOut(clamp01((t - 0.28) / 0.26))

    function toggle() {
        open ? close() : show();
    }
    function show() {
        if (disabled || open)
            return;
        open = true;
        sel = -1;
        armed = -1;
        closeAnim.stop();
        openAnim.restart();
    }
    function close() {
        if (!open)
            return;
        open = false;
        armed = -1;
        sel = -1;
        openAnim.stop();
        closeAnim.restart();
    }
    function reset() {
        openAnim.stop();
        closeAnim.stop();
        open = false;
        armed = -1;
        sel = -1;
        t = 0;
    }
    function move(d) {
        sel = sel < 0 ? (d > 0 ? 0 : items.length - 1) : (sel + d + items.length) % items.length;
        if (armed !== sel)
            armed = -1;
    }
    function trigger(i) {
        const it = items[i];
        if (it.confirm && armed !== i) {
            armed = i;
            sel = i;
            disarm.restart();
            return;
        }
        armed = -1;
        close();
        action(it.name);
    }

    onDisabledChanged: if (disabled) close()

    NumberAnimation { id: openAnim; target: root; property: "t"; to: 1; duration: 900 }
    NumberAnimation { id: closeAnim; target: root; property: "t"; to: 0; duration: 380; easing.type: Easing.InQuad }

    Timer {
        id: disarm
        interval: 2600
        onTriggered: root.armed = -1
    }

    // 点信封外任意处收起
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.close()
    }

    // ── 信封 ──
    Item {
        id: env

        readonly property real tile: 150 * root.u
        readonly property real gap: 30 * root.u
        readonly property real pad: 36 * root.u

        width: pad * 2 + tile * root.items.length + gap * (root.items.length - 1)
        height: pad * 2 + tile
        x: button.x - 34 * root.u - width
        y: button.y + button.height - height + 10 * root.u
        rotation: -5
        visible: root.t > 0
        opacity: 1 - root.fadeOut
        transform: Scale { origin.x: env.width; origin.y: env.height / 2; xScale: root.stretch }

        // 吞掉信封内的点击，避免穿透到收起层
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            x: 16 * root.u
            y: 14 * root.u
            width: parent.width
            height: parent.height
            rotation: 1.6
            color: Theme.deep
            antialiasing: true
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.ink
            border.color: Theme.primary
            border.width: 6 * root.u
            antialiasing: true
        }

        // 信封下半的两道折痕
        Shape {
            anchors.fill: parent
            opacity: 0.3
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.primary
                strokeWidth: 3 * root.u
                PathPolyline {
                    path: [Qt.point(0, env.height), Qt.point(env.width * 0.5, env.height * 0.42), Qt.point(env.width, env.height)]
                }
            }
        }

        // 翻盖：合上时是指向下方的主色三角，翻开后变成立在信封上沿的深紫三角
        Item {
            id: flapItem
            width: env.width
            height: env.height * 0.56
            transform: Scale { yScale: 1 - 2 * root.flap }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.flap < 0.5 ? Theme.primary : Theme.deep
                    strokeColor: Theme.ink
                    strokeWidth: 4 * root.u
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline {
                        path: [Qt.point(0, 0), Qt.point(flapItem.width, 0), Qt.point(flapItem.width / 2, flapItem.height), Qt.point(0, 0)]
                    }
                }
            }

            // 封口的星形火漆
            Shape {
                readonly property real s: 58 * root.u
                x: flapItem.width / 2 - s / 2
                y: flapItem.height - s * 0.78
                width: s
                height: s
                rotation: 12
                visible: root.flap < 0.5
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Theme.paper
                    strokeColor: Theme.ink
                    strokeWidth: 4 * root.u
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline {
                        path: {
                            const s = 58 * root.u, pts = [];
                            for (let i = 0; i <= 10; i++) {
                                const r = (i % 2 === 0 ? 0.5 : 0.22) * s;
                                const a = -Math.PI / 2 + i * Math.PI / 5;
                                pts.push(Qt.point(s / 2 + r * Math.cos(a), s / 2 + r * Math.sin(a)));
                            }
                            return pts;
                        }
                    }
                }
            }
        }

        // 左上角标签
        Rectangle {
            x: -14 * root.u
            y: -height - 6 * root.u
            width: tagText.implicitWidth + 24 * root.u
            height: tagText.implicitHeight + 4 * root.u
            color: Theme.ink
            rotation: -4
            antialiasing: true
            opacity: root.flap

            Text {
                id: tagText
                anchors.centerIn: parent
                text: "◆ TAKE YOUR LEAVE"
                color: Theme.primary
                font.family: Theme.narrow
                font.bold: true
                font.pixelSize: 26 * root.u
                font.letterSpacing: 3 * root.u
            }
        }

        Repeater {
            model: root.items

            Item {
                id: card

                required property var modelData
                required property int index

                readonly property real p: root.pop(index)
                readonly property bool hot: root.sel === index
                readonly property bool armedNow: root.armed === index
                readonly property var base: [
                    { bg: Theme.primary, fg: Theme.ink, edge: Theme.ink },
                    { bg: Theme.deep, fg: Theme.paper, edge: Theme.ink },
                    { bg: Theme.ink, fg: Theme.primary, edge: Theme.primary }
                ][index % 3]
                readonly property color bg: armedNow ? Theme.danger : hot ? Theme.paper : base.bg
                readonly property color fg: armedNow ? Theme.paper : hot ? Theme.ink : base.fg
                property real lift: hot || armedNow ? 1 : 0
                property real wob: 0

                Behavior on lift { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 3 } }

                x: env.pad + index * (env.tile + env.gap)
                y: env.pad - lift * 14 * root.u
                z: hot ? 2 : 1
                width: env.tile
                height: env.tile
                visible: p > 0.001
                scale: p * (1 + lift * 0.1)
                rotation: [-4, 3, -2][index % 3] * (1 - lift) + (1 - p) * -70 + wob * 5

                SequentialAnimation on wob {
                    running: card.armedNow
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 50 }
                    NumberAnimation { to: -1; duration: 90 }
                    NumberAnimation { to: 0.5; duration: 70 }
                    NumberAnimation { to: 0; duration: 60 }
                    PauseAnimation { duration: 520 }
                    onStopped: card.wob = 0
                }

                Rectangle {
                    x: (8 + card.lift * 8) * root.u
                    y: (8 + card.lift * 8) * root.u
                    width: parent.width
                    height: parent.height
                    color: card.hot || card.armedNow ? Theme.primary : Theme.ink
                    antialiasing: true
                }
                Rectangle {
                    anchors.fill: parent
                    color: card.bg
                    border.color: card.hot || card.armedNow ? Theme.ink : card.base.edge
                    border.width: 4 * root.u
                    antialiasing: true
                }

                Text {
                    x: 12 * root.u
                    y: 6 * root.u
                    text: "0" + (card.index + 1)
                    color: card.fg
                    opacity: 0.55
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 24 * root.u
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.18
                    text: card.modelData.icon
                    color: card.fg
                    font.family: "Font Awesome 7 Free"
                    font.weight: Font.Black
                    font.pixelSize: env.tile * 0.36
                    height: env.tile * 0.44
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.7
                    text: card.armedNow ? "SURE?" : card.modelData.label
                    color: card.fg
                    font.family: card.armedNow ? Theme.display : Theme.narrow
                    font.weight: card.armedNow ? Font.Black : Font.Bold
                    font.italic: card.armedNow
                    font.pixelSize: (card.armedNow ? 30 : 22) * root.u
                    font.letterSpacing: (card.armedNow ? 1 : 2) * root.u
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.open
                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.sel = card.index;
                        else if (root.sel === card.index && root.armed !== card.index)
                            root.sel = -1;
                    }
                    onClicked: root.trigger(card.index)
                }
            }
        }
    }

    // ── 箭头方块 ──
    Item {
        id: button

        readonly property real s: 92 * root.u
        readonly property bool hot: area.containsMouse || root.open

        width: s
        height: s
        x: root.width - s - 56 * root.u + (1 - root.reveal) * 220 * root.u + root.fadeOut * 220 * root.u
        y: root.height - s - 52 * root.u
        opacity: root.reveal * (1 - root.fadeOut)
        rotation: -6
        scale: area.pressed ? 0.9 : area.containsMouse ? 1.08 : 1

        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 3 } }

        Rectangle {
            x: 10 * root.u
            y: 10 * root.u
            width: parent.width
            height: parent.height
            color: Theme.deep
            antialiasing: true
        }
        Rectangle {
            anchors.fill: parent
            color: button.hot ? Theme.primary : Theme.ink
            border.color: button.hot ? Theme.ink : Theme.primary
            border.width: 4 * root.u
            antialiasing: true
        }

        // 粗折线箭头；展开时翻转成向左（收回）
        Shape {
            readonly property real w: button.s * 0.42
            readonly property real h: button.s * 0.5
            x: (button.s - w) / 2 + w * 0.06
            y: (button.s - h) / 2
            width: w
            height: h
            rotation: root.open ? 180 : 0
            preferredRendererType: Shape.CurveRenderer

            Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 } }

            ShapePath {
                fillColor: button.hot ? Theme.ink : Theme.primary
                strokeColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                PathPolyline {
                    path: {
                        const w = button.s * 0.42, h = button.s * 0.5;
                        return [Qt.point(0, 0), Qt.point(w * 0.46, 0), Qt.point(w, h / 2), Qt.point(w * 0.46, h), Qt.point(0, h), Qt.point(w * 0.54, h / 2), Qt.point(0, 0)];
                    }
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.disabled
            onClicked: root.toggle()
        }
    }
}
