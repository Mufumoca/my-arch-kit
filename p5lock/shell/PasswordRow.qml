import QtQuick
import QtQuick.Shapes

// 斜块中的密码行：字块弹入 / 弹出 + nvim smear 风格的拖影光标
// 坐标原点即行中心（父级把它放在斜块中线上）
Item {
    id: root

    property int length: 0
    property bool busy: false
    property real unit: 80
    // 父级在清空前置 true：下一批删除的字块炸散飞出，而不是收缩
    property bool scatter: false

    readonly property real pitch: unit * 0.78
    readonly property real cw: unit * 0.46
    readonly property real ch: unit * 1.12
    readonly property int count: glyphs.count

    property real curL: pitch * 0.14
    property real curR: curL + cw
    property real ghostL: curL
    property real ghostR: curR
    property real wavePhase: 0
    property real waveAmp: busy ? 1 : 0
    property bool typing: false

    Behavior on waveAmp { NumberAnimation { duration: 220 } }

    width: 0
    height: 0

    onLengthChanged: sync()

    function sync() {
        while (glyphs.count < length)
            glyphs.append({ seed: Math.random(), shape: Math.floor(Math.random() * 3), light: Math.random() < 0.18 });
        while (glyphs.count > length)
            glyphs.remove(glyphs.count - 1);
        if (glyphs.count === 0)
            scatterReset.restart();
        retarget();
        typing = true;
        idle.restart();
    }

    // 前沿快、后沿慢：右移时右边先到、左边拖着追上，左移反之
    function retarget() {
        const t = glyphs.count * pitch + pitch * 0.14;
        const forward = t >= curL;
        for (const a of [aL, aR, gL, gR])
            a.stop();
        aL.to = t;
        aR.to = t + cw;
        aL.duration = forward ? 240 : 75;
        aR.duration = forward ? 75 : 240;
        gL.to = t;
        gR.to = t + cw;
        aL.start();
        aR.start();
        gL.start();
        gR.start();
    }

    NumberAnimation { id: aL; target: root; property: "curL"; easing.type: Easing.OutCubic }
    NumberAnimation { id: aR; target: root; property: "curR"; easing.type: Easing.OutCubic }
    NumberAnimation { id: gL; target: root; property: "ghostL"; duration: 420; easing.type: Easing.OutQuart }
    NumberAnimation { id: gR; target: root; property: "ghostR"; duration: 420; easing.type: Easing.OutQuart }

    Timer {
        id: idle
        interval: 650
        onTriggered: root.typing = false
    }
    Timer {
        id: scatterReset
        interval: 30
        onTriggered: root.scatter = false
    }

    NumberAnimation on wavePhase {
        running: root.waveAmp > 0
        from: 0
        to: 1
        duration: 700
        loops: Animation.Infinite
    }

    ListModel {
        id: glyphs
    }

    // 整行始终以（字块 + 光标位）居中，新增一个字整行被往左“拽”半格
    Item {
        id: strip

        x: -(glyphs.count + 1) * root.pitch / 2
        Behavior on x { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

        // 拖影
        Rectangle {
            x: root.ghostL
            width: Math.max(root.cw * 0.3, root.ghostR - root.ghostL)
            height: root.ch * 0.62
            y: -height / 2
            color: Theme.deep
            opacity: Math.min(0.55, Math.abs((root.ghostR - root.ghostL) - root.cw) / root.pitch)
            antialiasing: true
        }

        Rectangle {
            id: cursor

            readonly property real stretch: Math.max(root.cw, root.curR - root.curL)
            x: root.curL
            width: stretch
            height: root.ch * Math.pow(root.cw / stretch, 0.45)
            y: -height / 2
            color: Theme.ink
            antialiasing: true
            opacity: root.busy ? 0.35 + 0.65 * Math.abs(Math.sin(root.wavePhase * Math.PI)) : (root.typing || blink.on ? 1 : 0.12)
        }

        Timer {
            id: blink
            property bool on: true
            interval: 530
            repeat: true
            running: !root.typing && !root.busy
            onRunningChanged: on = true
            onTriggered: on = !on
        }

        ListView {
            id: view

            x: 0
            y: -height / 2
            width: root.pitch * 96
            height: root.unit * 1.6
            orientation: ListView.Horizontal
            interactive: false
            model: glyphs

            delegate: Item {
                id: g

                required property real seed
                required property int shape
                required property bool light
                required property int index

                property real pop: 0
                property real out: 0
                property bool flying: false
                property real vx: 0
                property real vy: 0
                property real spin: 0

                readonly property real s: root.unit * (0.56 + g.seed * 0.16)
                readonly property real wave: Math.sin((root.wavePhase - g.index * 0.09) * Math.PI * 2) * root.unit * 0.14 * root.waveAmp

                width: root.pitch
                height: ListView.view.height

                Component.onCompleted: popIn.start()

                NumberAnimation {
                    id: popIn
                    target: g
                    property: "pop"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 3
                }

                // delayRemove 必须在信号里同步置位，ListView 才会等动画播完再销毁
                ListView.onRemove: {
                    g.ListView.delayRemove = true;
                    g.flying = root.scatter;
                    g.vx = (Math.random() - 0.3) * root.unit * 4;
                    g.vy = -(0.6 + Math.random()) * root.unit * 2.2;
                    g.spin = (Math.random() - 0.5) * 540;
                    removeAnim.start();
                }

                SequentialAnimation {
                    id: removeAnim
                    NumberAnimation { target: g; property: "out"; to: 1; duration: g.flying ? 560 : 130; easing.type: g.flying ? Easing.Linear : Easing.InQuad }
                    PropertyAction { target: g; property: "ListView.delayRemove"; value: false }
                }

                Item {
                    id: body

                    width: g.s
                    height: g.s
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: g.flying ? g.vx * g.out : 0
                    anchors.verticalCenterOffset: g.wave + (g.flying ? g.vy * g.out + root.unit * 6 * g.out * g.out : 0)
                    scale: g.flying ? 1 : g.pop * (1 - g.out)
                    rotation: (g.seed - 0.5) * 30 + (1 - g.pop) * 140 + (g.flying ? g.spin * g.out : -70 * g.out)
                    opacity: g.flying ? 1 - g.out * g.out : 1

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: g.light ? Theme.paper : Theme.ink
                            strokeColor: Theme.ink
                            strokeWidth: g.light ? Math.max(2, g.s * 0.08) : 0
                            joinStyle: ShapePath.MiterJoin

                            PathPolyline {
                                path: {
                                    const w = g.s, h = g.s;
                                    if (g.shape === 0) // 菱形
                                        return [Qt.point(w / 2, 0), Qt.point(w, h / 2), Qt.point(w / 2, h), Qt.point(0, h / 2), Qt.point(w / 2, 0)];
                                    if (g.shape === 1) // 平行四边形
                                        return [Qt.point(w * 0.3, h * 0.08), Qt.point(w, h * 0.08), Qt.point(w * 0.7, h * 0.92), Qt.point(0, h * 0.92), Qt.point(w * 0.3, h * 0.08)];
                                    const pts = []; // 五角星
                                    for (let i = 0; i <= 10; i++) {
                                        const r = (i % 2 === 0 ? 0.5 : 0.22) * w;
                                        const a = -Math.PI / 2 + i * Math.PI / 5;
                                        pts.push(Qt.point(w / 2 + r * Math.cos(a), h / 2 + r * Math.sin(a)));
                                    }
                                    return pts;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
