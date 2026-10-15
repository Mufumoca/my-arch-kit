pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// PHANTOM VIOLET — P5 的锐利造型 + P3 的流动动效。
// 颜色全部从 Style（即 Theme）派生：换主题/色板后仍保持一致，只是把对比度和饱和度推到 P5 的强度。
Singleton {
    id: root

    // ---- 色彩 -------------------------------------------------------------
    // 主色就是主题原本的淡紫（偏粉，和 niri 边框同色），跟着主题走；黑、白、红、橙是固定的 P5 色。
    // 墨：带紫调的黑，所有面板与栏的底色
    readonly property color ink: "#0E0A12"
    readonly property color inkRaised: "#1D1624"
    // 纸：反白、描边、主要文字
    readonly property color paper: "#FFFFFF"
    // 怪盗紫：主色——错位板、选中块、当前项。它是浅色，上面的字用 onViolet（墨色）
    readonly property color violet: Style.primary
    readonly property color onViolet: ink
    // 粉：往粉色再推一点的主色，用于第二层错位板与高光
    readonly property color pink: mix(Style.primary, "#FF9ED8", 0.45)
    // 梅紫：栏上组件的底色——主色同色相、压暗，比纯黑更“紫”，白字与淡紫图标都看得清
    readonly property color plum: Qt.hsla(hue(Style.primary), 0.48, 0.3, 1)
    readonly property color plumRaised: Qt.hsla(hue(Style.primary), 0.5, 0.38, 1)
    // 夜紫：面板底色——极深的主色，而不是纯黑
    readonly property color night: Qt.hsla(hue(Style.primary), 0.42, 0.1, 1)
    // 深紫：暗部
    readonly property color velvet: mix(Style.primary, ink, 0.6)
    // 丁香：细线、次要文字
    readonly property color lilac: mix(Style.primary, paper, 0.35)
    // 血红：只用于动效瞬间（按下闪红）与紧急状态，不做常驻底色
    readonly property color blood: "#FF1F45"
    // 橙：次强调
    readonly property color amber: "#FF7A1A"

    // ---- 造型 -------------------------------------------------------------
    // 平行四边形的倾斜：水平偏移 = 高度 × skew（约 11°）
    readonly property real skew: 0.2
    // 面板切角（左上、右下）
    readonly property real cut: 14
    // 错位硬阴影偏移
    readonly property real slab: 7
    readonly property real strokeWidth: 1.5
    // 高度为 h 的平行四边形的斜切总量
    function slant(h) {
        return Math.round(h * skew * 2);
    }

    // ---- 字体 -------------------------------------------------------------
    readonly property string bodyFont: barlow.name || "Barlow"
    readonly property string labelFont: barlowCondensed.name || "Barlow Condensed"
    readonly property string displayFont: anton.name || "Anton"
    // 漫画粗体（p5-reference/toggle-switch 的 Luckiest Guy）：黑字粗白描边的大标题，用 P5Comic 画
    readonly property string comicFont: luckiest.name || "Luckiest Guy"

    // ---- 动效 -------------------------------------------------------------
    // 果断的减速：快速冲出、利落停住
    readonly property list<real> snapCurve: [0.12, 0.9, 0.22, 1.0, 1, 1]
    // 带一点过冲的弹出（P5 菜单字块）
    readonly property list<real> punchCurve: [0.3, 1.45, 0.4, 1.0, 1, 1]
    // 加速离场
    readonly property list<real> exitCurve: [0.55, 0.0, 0.9, 0.4, 1, 1]
    readonly property bool motionEnabled: Style.currentAnimationSpeed !== Style.AnimationSpeed.None
    function dur(ms) {
        return motionEnabled ? ms : 0;
    }

    // 全局流动相位（0→1 循环，约 9 秒一圈），供面板条纹等环境动效共用，避免每个面板各起一个动画
    property real flow: 0
    NumberAnimation on flow {
        from: 0
        to: 1
        duration: 9000
        loops: Animation.Infinite
        running: root.motionEnabled && root.flowUsers > 0
    }
    property int flowUsers: 0

    // ---- 工具 -------------------------------------------------------------
    function mix(a, b, t) {
        const x = Qt.darker(a, 1.0), y = Qt.darker(b, 1.0);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, x.a + (y.a - x.a) * t);
    }
    function alpha(c, a) {
        const k = Qt.darker(c, 1.0);
        return Qt.rgba(k.r, k.g, k.b, a);
    }
    function hue(c) {
        const k = Qt.darker(c, 1.0);
        return k.hslHue < 0 ? 0.75 : k.hslHue;
    }
    // 确定性伪随机：同一 seed 每次得到同样的“歪斜”，返回 [-1, 1]
    function rand(seed, i) {
        const x = Math.sin(seed * 127.1 + i * 311.7) * 43758.5453;
        return (x - Math.floor(x)) * 2 - 1;
    }
    // 给每个组件实例分一个种子，让相邻元素歪得各不相同
    // 计数器放在 var 里改字段：不触发通知，可以安全地在绑定里调用
    readonly property var _seedBox: ({
            "n": 0
        })
    function nextSeed() {
        _seedBox.n += 1;
        return _seedBox.n;
    }
    // 两个颜色色相接近（且都不是灰色）：用来避免“紫板配紫色错位板”
    function isSameHue(a, b) {
        const x = Qt.darker(a, 1.0), y = Qt.darker(b, 1.0);
        if (x.hslSaturation < 0.25 || y.hslSaturation < 0.25)
            return false;
        const d = Math.abs(x.hslHue - y.hslHue);
        return Math.min(d, 1 - d) < 0.06;
    }

    function vec(c) {
        return Qt.vector4d(c.r, c.g, c.b, c.a);
    }

    FontLoader {
        id: barlow
        source: Qt.resolvedUrl("../assets/fonts/p5/Barlow-Medium.ttf")
    }
    FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/p5/Barlow-Regular.ttf")
    }
    FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/p5/Barlow-SemiBold.ttf")
    }
    FontLoader {
        id: barlowCondensed
        source: Qt.resolvedUrl("../assets/fonts/p5/BarlowCondensed-Bold.ttf")
    }
    FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/p5/BarlowCondensed-SemiBold.ttf")
    }
    FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/p5/BarlowCondensed-BoldItalic.ttf")
    }
    FontLoader {
        source: Qt.resolvedUrl("../assets/fonts/p5/BarlowCondensed-ExtraBoldItalic.ttf")
    }
    FontLoader {
        id: anton
        source: Qt.resolvedUrl("../assets/fonts/p5/Anton-Regular.ttf")
    }
    FontLoader {
        id: luckiest
        source: Qt.resolvedUrl("../assets/fonts/p5/LuckiestGuy-Regular.ttf")
    }
}
