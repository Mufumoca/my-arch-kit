import QtQuick

// 解锁转场：斜块拆成若干条平行斜条
//   spread 0→1：从斜块厚度铺开到覆盖整屏（锁屏表面上播放）
//   wipe   0→1：从中间那条开始向两侧依次沿斜线方向交错滑出，露出桌面（解锁后的 overlay 上播放）
// 两处用同一组件、同一几何，交接时画面完全一致
Item {
    id: root

    property real spread: 0
    property real wipe: 0

    readonly property real diag: Math.hypot(width, height)
    readonly property real angle: Math.atan2(height, width) * 180 / Math.PI
    readonly property real alt: width * height / Math.max(1, diag)
    readonly property real u: Math.min(width, height) / 1000
    readonly property real bandH: Theme.bandFor(width, height)
    readonly property int k: 9
    readonly property real len: diag + 400 * u
    readonly property real cover: 2 * alt + 80 * u

    function inOut(p) {
        return p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
    }

    Item {
        x: root.width / 2
        y: root.height / 2
        rotation: -root.angle

        Repeater {
            model: root.k

            Item {
                id: stripe

                required property int index
                readonly property real th: (root.bandH + (root.cover - root.bandH) * root.spread) / root.k
                readonly property real lag: 0.1
                readonly property real mid: (root.k - 1) / 2
                // 离中线越远越晚出发，上下对称
                readonly property real p: Math.max(0, Math.min(1, (root.wipe - Math.abs(index - mid) * lag) / (1 - mid * lag)))
                readonly property int dir: index % 2 === 0 ? 1 : -1

                x: -root.len / 2 + dir * (root.len + 200 * root.u) * root.inOut(p)
                y: (index - (root.k - 1) / 2) * th - th / 2
                width: root.len
                height: th + 1.5

                Rectangle {
                    anchors.fill: parent
                    antialiasing: true
                    color: stripe.index % 4 === 3 ? Theme.deep : stripe.index % 2 === 1 ? Theme.mix(Theme.primary, Theme.paper, 0.28) : Theme.primary
                }
                // 漫画分格似的墨线
                Rectangle {
                    width: parent.width
                    height: Math.max(2, 4 * root.u)
                    color: Theme.ink
                    antialiasing: true
                }
                // 滑出时的拖尾边：运动方向的后缘加一道粗墨条
                Rectangle {
                    x: stripe.dir > 0 ? 0 : parent.width - width
                    width: 26 * root.u
                    height: parent.height
                    color: Theme.ink
                    visible: stripe.p > 0
                }
            }
        }
    }
}
