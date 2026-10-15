pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Widgets

// 一条 P5 手机短信（造型照 p5-reference/sms）：左边是歪斜四边形的头像（通知的图标/图片裁进四边形），
// 右边是带锯齿尾巴的斜切气泡——外框右侧更宽、底边微斜。颜色走本地色系：淡紫粗框 + 墨紫底 + 白字，
// 紧急通知换成血红框。没有按钮：左键 = 激活 / 查看（activated），右键 = 删掉（dismissRequested），
// 悬停时外框变粉。通知中心的聊天记录和岛下的新通知共用它。
Item {
    id: root

    property string app: ""
    property string summary: ""
    property string body: ""
    property string when: ""
    property string avatar: ""
    property string fallback: "material:notifications"
    property bool critical: false
    property int seed: 1
    // 气泡（不含外框）最宽多少；单行短消息会收窄
    property real maxCenterWidth: 330
    property int bodyLines: 5
    // 整体放大倍数（悬停展开时的大号短信）：几何与字号一起放大，文字保持清晰
    property real zoom: 1

    readonly property bool hovered: clickArea.containsMouse

    signal activated
    signal dismissRequested

    // ---- 几何（对应原 pen 的 messageBox，放大约 1.2 倍）----
    readonly property real avatarW: 86 * zoom
    readonly property real ox: 118 * zoom          // 气泡左上角
    readonly property real oy: 9 * zoom
    readonly property real leftWidth: 10 * zoom    // 左下角往外探
    readonly property real rightWidth: 22 * zoom   // 右上角往外探
    readonly property real slantHeight: 6 * zoom   // 底边右端下沉
    readonly property real bNormal: 5 * zoom
    readonly property real bLeft: 17 * zoom
    readonly property real bRight: 40 * zoom
    readonly property real padX: 16 * zoom
    readonly property real padY: 9 * zoom

    readonly property color frameColor: critical ? P5.blood : (hovered ? P5.pink : P5.violet)
    readonly property color fillColor: P5.mix(P5.night, P5.ink, 0.35)

    readonly property real naturalText: Math.max(metaRow.implicitWidth, summaryMetrics.advanceWidth, bodyMetrics.advanceWidth)
    readonly property real cw: Math.max(150 * zoom, Math.min(maxCenterWidth, Math.ceil(naturalText) + padX * 2))
    readonly property real ch: textCol.implicitHeight + padY * 2 + 4
    readonly property real midY: oy + ch / 2

    implicitWidth: ox + cw + bRight + 6
    implicitHeight: Math.max(oy + ch + slantHeight + bNormal + 10 * zoom, midY + 44 * zoom)

    function pts(list) {
        return list.map(p => [p[0], p[1]]);
    }

    // 进场：头像从左边砸进来，气泡从尾巴处弹开
    function play() {
        if (!P5.motionEnabled)
            return;
        enter.restart();
    }
    ParallelAnimation {
        id: enter
        NumberAnimation {
            target: face
            property: "scale"
            from: 0.4
            to: 1
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 2
        }
        NumberAnimation {
            target: face
            property: "opacity"
            from: 0
            to: 1
            duration: 120
        }
        SequentialAnimation {
            PropertyAction {
                target: bubble
                property: "scale"
                value: 0.2
            }
            PauseAnimation {
                duration: 90
            }
            NumberAnimation {
                target: bubble
                property: "scale"
                to: 1
                duration: 300
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }
    }

    TextMetrics {
        id: summaryMetrics
        font: summaryText.font
        text: root.summary
    }
    TextMetrics {
        id: bodyMetrics
        font: bodyText.font
        text: root.body.split("\n")[0]
    }

    // ---- 头像（照 p5-reference/sms 的 Buddy Avatar）：左、上、下露出粗黑边的歪框 + 白卡，照片铺满白卡、
    // 只在左边和下边留一道白边；彩色应用图标画得更大，顶部探出框外（原作里角色的头顶出框）。
    // 墨色的 material 图标 / 首字母探出去会融进深色底，所以留在卡里。黑框后垫一块主题色错位板，深色底上才看得见轮廓。
    Item {
        id: face

        readonly property bool hasPhoto: photo.status === Image.Ready
        readonly property bool popOut: !hasPhoto && !root.fallback.startsWith("material:") && !root.fallback.startsWith("unicode:")

        x: 2 * root.zoom
        y: root.midY - 40 * root.zoom
        width: 92
        height: 80
        rotation: P5.rand(root.seed, 1) * 4
        transformOrigin: Item.Right
        transform: Scale {
            xScale: root.zoom
            yScale: root.zoom
        }

        P5Poly {
            anchors.fill: parent
            points: [[-1, 2.5], [78, 13.5], [87, 68.5], [15.5, 77]]
            fillColor: P5.ink
            slabColor: root.frameColor
            slabOffset: Qt.point(4, 5)
        }
        P5Poly {
            anchors.fill: parent
            points: [[10, 8], [76, 19], [87, 63], [21, 74]]
            fillColor: P5.paper
        }

        // 图标层（离屏），用遮罩裁出来
        Item {
            id: pic
            anchors.fill: parent
            visible: false
            layer.enabled: true

            Image {
                id: photo
                x: 8
                y: 4
                width: 80
                height: 72
                source: root.avatar
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
                sourceSize.width: 160
                sourceSize.height: 160
            }
            AppIconRenderer {
                x: face.popOut ? 19 : 26
                y: face.popOut ? 0 : 21
                width: iconSize
                height: iconSize
                visible: !face.hasPhoto
                iconValue: root.fallback
                iconSize: face.popOut ? 58 : 44
                iconColor: P5.ink
                materialIconSizeAdjustment: 0
                fallbackText: root.app.charAt(0).toUpperCase()
                fallbackBackgroundColor: "transparent"
                fallbackTextColor: P5.ink
            }
        }
        Shape {
            id: picMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: "white"
                PathPolyline {
                    // 照片：贴着白卡的上、右边，左、下各让出一道白边；探出的图标：上沿抬到框外
                    path: face.popOut ? [Qt.point(12, 0), Qt.point(80, 0), Qt.point(86, 60), Qt.point(21.5, 71), Qt.point(12, 0)] : [Qt.point(13.5, 8.6), Qt.point(76, 19), Qt.point(85.5, 60.5), Qt.point(23, 70.5), Qt.point(13.5, 8.6)]
                }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: pic
            maskEnabled: true
            maskSource: picMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    // ---- 气泡 ----
    Item {
        id: bubble
        width: root.width
        height: root.height
        // 从尾巴一侧弹开
        transformOrigin: Item.Left

        // 外框
        P5Poly {
            anchors.fill: parent
            points: [[root.ox - root.bNormal, root.oy - root.bNormal], [root.ox + root.cw + root.bRight, root.oy - root.bNormal], [root.ox + root.cw + root.bNormal, root.oy + root.ch + root.bNormal + root.slantHeight], [root.ox - root.bLeft, root.oy + root.ch + root.bNormal]]
            fillColor: root.frameColor
            slabColor: P5.alpha(P5.ink, 0.55)
            slabOffset: Qt.point(6 * root.zoom, 6 * root.zoom)
        }
        // 尾巴外框
        P5Poly {
            anchors.fill: parent
            readonly property real m: root.midY
            readonly property real o: root.ox
            readonly property real k: root.zoom
            points: [[o - 46 * k, m + 14 * k], [o - 18 * k, m - 19 * k], [o - 14 * k, m - 12 * k], [o, m - 18 * k], [o, m + 12 * k], [o - 24 * k, m + 18 * k], [o - 28 * k, m + 12 * k]]
            fillColor: root.frameColor
        }
        // 尾巴
        P5Poly {
            anchors.fill: parent
            readonly property real m: root.midY
            readonly property real o: root.ox
            readonly property real k: root.zoom
            points: [[o - 38 * k, m + 10 * k], [o - 20 * k, m - 12 * k], [o - 14 * k, m - 5 * k], [o + 2 * k, m - 12 * k], [o + 2 * k, m + 6 * k], [o - 21 * k, m + 12 * k], [o - 26 * k, m + 6 * k]]
            fillColor: root.fillColor
        }
        // 气泡本体
        P5Poly {
            anchors.fill: parent
            points: [[root.ox, root.oy], [root.ox + root.cw + root.rightWidth, root.oy], [root.ox + root.cw, root.oy + root.ch + root.slantHeight], [root.ox - root.leftWidth, root.oy + root.ch]]
            fillColor: root.fillColor
        }

        Column {
            id: textCol
            x: root.ox + root.padX - 4
            y: root.oy + root.padY
            width: root.cw - root.padX * 2 + 6
            spacing: 2

            Row {
                id: metaRow
                spacing: 7
                Text {
                    text: root.app.toUpperCase()
                    color: root.frameColor
                    font.family: P5.labelFont
                    font.pixelSize: Math.round(13 * root.zoom)
                    font.weight: Font.Black
                    font.italic: true
                }
                Text {
                    anchors.baseline: parent.children[0].baseline
                    text: root.when
                    visible: text.length > 0
                    color: P5.alpha(P5.lilac, 0.7)
                    font.family: P5.labelFont
                    font.pixelSize: Math.round(12 * root.zoom)
                    font.weight: Font.Bold
                    font.italic: true
                }
            }
            Text {
                id: summaryText
                width: parent.width
                text: root.summary
                visible: text.length > 0
                color: P5.paper
                font.pixelSize: Math.round(15 * root.zoom)
                font.weight: Font.Black
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                id: bodyText
                width: parent.width
                text: root.body
                visible: text.length > 0
                color: P5.alpha(P5.paper, 0.86)
                font.pixelSize: Math.round(13 * root.zoom)
                font.weight: Font.DemiBold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
                lineHeight: 1.12
            }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.RightButton ? root.dismissRequested() : root.activated()
    }
}
