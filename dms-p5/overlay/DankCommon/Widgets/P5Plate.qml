import QtQuick
import qs.DankCommon.Common

// P5 板：不规则四边形 / 切角 / 内框线 / 两层错位板（可旋转）/ 静态星星 / 流动条纹，见 Shaders/frag/p5_plate.frag。
// 本元素的尺寸就是板的外接矩形；斜切、抖动、错位板、阴影都画在外扩的 pad 区域里，不影响布局。
Item {
    id: root

    property real skew: 0               // 斜切总量 px：顶边右移 skew/2，底边左移 skew/2
    property real jitter: 0             // 四个角随机偏移的幅度 px（P5 菜单那种歪歪扭扭的块）
    property int seed: 0
    property real cutTopLeft: 0
    property real cutBottomRight: 0
    property real borderWidth: 0

    property color fillColor: P5.ink
    property color borderColor: "transparent"
    property color rimColor: "transparent"
    property real rimInset: 4
    property real rimWidth: 1.5

    property color slabColor: "transparent"
    property point slabOffset: Qt.point(P5.slab, P5.slab)
    property real slabRotation: 0       // 度
    property real slabGrow: 0
    property color slab2Color: "transparent"
    property point slab2Offset: Qt.point(P5.slab * 2, P5.slab * 2)
    property real slab2Rotation: 0
    property real slab2Grow: 0

    property color shadowColor: "transparent"
    property real shadowBlur: 0
    property real shadowSpread: 0
    property point shadowOffset: Qt.point(0, 0)

    property color accentColor: P5.lilac
    property real stars: 0              // 静态星星底纹的强度（0 关闭），颜色在底色与 accentColor 之间
    property real stripes: 0
    property real sheen: 0
    property real accentBar: 0

    readonly property bool flowing: (stripes > 0 || sheen > 0) && visible && opacity > 0 && width > 0 && height > 0 && P5.motionEnabled

    function _j(i) {
        return jitter > 0 ? P5.rand(seed, i) * jitter : 0;
    }
    readonly property vector4d quadA: Qt.vector4d(skew / 2 + _j(0), _j(1), skew / 2 + _j(2), _j(3))
    readonly property vector4d quadB: Qt.vector4d(-skew / 2 + _j(4), _j(5), -skew / 2 + _j(6), _j(7))

    function _slabReach(off, rotDeg, grow, col) {
        if (col.a <= 0)
            return 0;
        const halfDiag = Math.sqrt(width * width + height * height) / 2;
        return Math.max(Math.abs(off.x), Math.abs(off.y)) + Math.abs(rotDeg) * Math.PI / 180 * halfDiag + grow;
    }
    readonly property real pad: Math.ceil(Math.max(Math.abs(skew) / 2 + jitter, _slabReach(slabOffset, slabRotation, slabGrow, slabColor) + jitter, _slabReach(slab2Offset, slab2Rotation, slab2Grow, slab2Color) + jitter, shadowColor.a > 0 ? shadowBlur + shadowSpread + Math.max(Math.abs(shadowOffset.x), Math.abs(shadowOffset.y)) : 0) + 2)

    // 只有正在显示且需要流动的板才让全局 P5.flow 走动
    property bool _flowRegistered: false
    function _syncFlow() {
        if (flowing === _flowRegistered)
            return;
        P5.flowUsers += flowing ? 1 : -1;
        _flowRegistered = flowing;
    }
    onFlowingChanged: _syncFlow()
    Component.onCompleted: _syncFlow()
    Component.onDestruction: if (_flowRegistered) P5.flowUsers -= 1

    ShaderEffect {
        anchors.fill: parent
        anchors.margins: -root.pad
        fragmentShader: Qt.resolvedUrl("../Shaders/qsb/p5_plate.frag.qsb")

        property real widthPx: width
        property real heightPx: height
        property real phase: root.flowing ? P5.flow : 0
        property vector4d rectPx: Qt.vector4d(root.pad, root.pad, root.width, root.height)
        property vector4d quadA: root.quadA
        property vector4d quadB: root.quadB
        property vector4d shape: Qt.vector4d(root.cutTopLeft, root.cutBottomRight, root.borderWidth, 0)
        property vector4d fillColor: P5.vec(root.fillColor)
        property vector4d borderColor: P5.vec(root.borderColor)
        property vector4d rimColor: P5.vec(root.rimColor)
        property vector4d rimParam: Qt.vector4d(root.rimInset, root.rimWidth, 0, 0)
        property vector4d slabColor: P5.vec(root.slabColor)
        property vector4d slabParam: Qt.vector4d(root.slabOffset.x, root.slabOffset.y, root.slabRotation * Math.PI / 180, root.slabGrow)
        property vector4d slab2Color: P5.vec(root.slab2Color)
        property vector4d slab2Param: Qt.vector4d(root.slab2Offset.x, root.slab2Offset.y, root.slab2Rotation * Math.PI / 180, root.slab2Grow)
        property vector4d shadowColor: P5.vec(root.shadowColor)
        property vector4d shadowParam: Qt.vector4d(root.shadowBlur, root.shadowSpread, root.shadowOffset.x, root.shadowOffset.y)
        property vector4d accentColor: P5.vec(root.accentColor)
        property vector4d fx: Qt.vector4d(root.stars, root.stripes, root.sheen, root.accentBar)
    }
}
