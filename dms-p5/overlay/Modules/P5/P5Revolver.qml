pragma ComponentBehavior: Bound

import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Modals.DankLauncherV2
import qs.Services
import qs.Widgets

// 左轮应用菜单：整体是一块向右收尖的拉长五边形，左边半露一个转轮弹巢；
// 应用是一根根长条不规则块，沿着以弹巢为轴的圆弧排开——选中的那根水平朝右、最大、淡紫色，
// 越往两侧越小、越斜、越淡。滚轮 / ↑↓ 转动弹巢，回车或点选中项“开火”。
// 开始打字时，最顶上出现一条搜索横幅。
Item {
    id: root

    property bool open: false
    signal closeRequested

    readonly property alias controller: ctl
    readonly property alias searchField: input

    // 只取非分组标题的条目
    readonly property var entries: {
        const out = [];
        const fm = ctl.flatModel || [];
        for (let i = 0; i < fm.length; i++) {
            if (!fm[i].isHeader && fm[i].item)
                out.push({
                    "flat": i,
                    "item": fm[i].item
                });
        }
        return out;
    }
    readonly property int selected: {
        const idx = entries.findIndex(e => e.flat === ctl.selectedFlatIndex);
        return idx < 0 ? 0 : idx;
    }
    // 弹巢是循环的：cursor 是不取模的位置，spin 追着它转；条目到选中项的距离按环形取最近
    readonly property int count: entries.length
    property int cursor: 0
    property real spin: cursor
    Behavior on spin {
        enabled: P5.motionEnabled
        NumberAnimation {
            duration: 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: P5.punchCurve
        }
    }
    function wrap(x) {
        return count > 0 ? x - count * Math.round(x / count) : x;
    }
    function modc(x) {
        return count > 0 ? ((x % count) + count) % count : 0;
    }
    // 选中项被外部改动（搜索重置等）时，cursor 走最短的一圈对上
    onSelectedChanged: {
        if (modc(cursor) !== selected)
            cursor += wrap(selected - modc(cursor));
    }
    readonly property bool searching: input.text.length > 0

    function selectEntry(i) {
        if (i < 0 || i >= entries.length)
            return;
        ctl.selectIndex(entries[i].flat);
    }
    function step(d) {
        if (count === 0)
            return;
        cursor += d;
        selectEntry(modc(cursor));
    }
    function fire(i) {
        const e = entries[i === undefined ? selected : i];
        if (e)
            ctl.executeItem(e.item, true);
    }
    function iconValueOf(item) {
        if (!item)
            return "";
        switch (item.iconType) {
        case "material":
        case "nerd":
            return "material:" + (item.icon || "apps");
        case "unicode":
            return "unicode:" + (item.icon || "");
        case "composite":
            return item.iconFull || "";
        }
        return item.icon || "";
    }

    Controller {
        id: ctl
        active: root.open
        viewModeContext: "appDrawer"
        forceLinearNavigation: true
        onItemExecuted: root.closeRequested()
    }

    // ---- 造型尺寸 ----
    readonly property real tipW: 74
    property real cy: height / 2 + (searching ? 26 : 0)
    // 圆弧：圆心在面板左外侧，选中项落在 x = arcX0
    readonly property real arcR: 340
    readonly property real arcX0: 132
    readonly property real stepDeg: 11.5

    Behavior on cy {
        enabled: P5.motionEnabled
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // 拉长的五边形底板（右侧收尖），带白边、淡紫与粉色错位板
    P5Poly {
        id: hull
        anchors.fill: parent
        readonly property real w: width
        readonly property real h: height
        points: [[6, 0], [w - root.tipW - 10, 8], [w - 4, h * 0.52], [w - root.tipW + 6, h - 2], [0, h - 14]]
        fillColor: P5.alpha(P5.night, 0.96)
        strokeColor: P5.paper
        strokeWidth: 4
        slabColor: P5.violet
        slabOffset: Qt.point(12, 12)
    }
    P5Poly {
        anchors.fill: parent
        z: -1
        readonly property real w: width
        readonly property real h: height
        points: [[-10, 18], [w - root.tipW - 30, -6], [w - 30, h * 0.47], [w - root.tipW - 20, h + 6], [-4, h + 4]]
        fillColor: P5.pink
    }

    // 内部装饰：大号斜体水印 + 斜线
    Item {
        anchors.fill: parent
        clip: true

        Text {
            x: 40
            y: root.height - 150
            text: "TAKE YOUR\nPICK"
            lineHeight: 0.8
            color: P5.alpha(P5.violet, 0.07)
            font.family: P5.displayFont
            font.pixelSize: 92
            rotation: -12
        }
        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: 200 + index * 120
                y: -40
                width: 2
                height: root.height + 80
                rotation: 18
                color: P5.alpha(P5.paper, 0.05)
            }
        }
    }

    // ---- 弹巢：半露在左侧，随转动旋转 ----
    Item {
        id: drum
        x: -86
        y: root.cy - 110
        width: 220
        height: 220
        rotation: root.spin * 60

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: P5.ink
            border.width: 5
            border.color: P5.paper
        }
        Repeater {
            model: 6
            Rectangle {
                required property int index
                readonly property real a: index * Math.PI / 3
                width: 50
                height: 50
                radius: 25
                x: drum.width / 2 + Math.cos(a) * 66 - 25
                y: drum.height / 2 + Math.sin(a) * 66 - 25
                color: index === 0 ? P5.violet : P5.plum
                border.width: 3
                border.color: P5.paper
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 34
            height: 34
            radius: 17
            color: P5.paper
            border.width: 4
            border.color: P5.ink
        }
    }

    // ---- 条目 ----
    Item {
        id: wheel
        anchors.fill: parent
        clip: true

        Repeater {
            model: root.entries

            Item {
                id: bar
                required property var modelData
                required property int index

                readonly property real k: root.wrap(index - root.spin)
                readonly property real ak: Math.abs(k)
                readonly property bool isSel: index === root.selected
                readonly property real theta: k * root.stepDeg * Math.PI / 180
                readonly property real sc: Math.max(0.55, 1 - ak * 0.075)
                readonly property int seed: 1000 + index * 7

                visible: ak < 6.6
                z: 100 - ak * 10
                opacity: Math.max(0, 1 - ak * 0.16)
                width: 440
                height: 60
                // 沿圆弧摆位：越远越往左缩、越斜
                x: root.arcX0 - root.arcR * (1 - Math.cos(theta)) + (isSel ? 6 : 0)
                y: root.cy + root.arcR * Math.sin(theta) - height / 2
                rotation: theta * 180 / Math.PI * 0.55 + (isSel ? -1.5 : 0)
                scale: sc * (isSel ? 1.08 : 1)
                transformOrigin: Item.Left

                Behavior on x {
                    enabled: P5.motionEnabled
                    NumberAnimation {
                        duration: 120
                    }
                }

                // 长条不规则块：右端斜切，四角随机歪斜
                P5Poly {
                    anchors.fill: parent
                    readonly property real j: 5
                    readonly property real w: width
                    readonly property real h: height
                    points: [[P5.rand(bar.seed, 1) * j, P5.rand(bar.seed, 2) * j + 2], [w - 22 + P5.rand(bar.seed, 3) * j, P5.rand(bar.seed, 4) * j], [w + P5.rand(bar.seed, 5) * j, h * 0.55], [w - 34 + P5.rand(bar.seed, 6) * j, h + P5.rand(bar.seed, 7) * j - 2], [8 + P5.rand(bar.seed, 8) * j, h - 4 + P5.rand(bar.seed, 9) * j]]
                    fillColor: bar.isSel ? P5.violet : (barArea.containsMouse ? P5.plumRaised : P5.ink)
                    strokeColor: P5.paper
                    strokeWidth: bar.isSel ? 4 : 2
                    slabColor: bar.isSel ? P5.ink : "transparent"
                    slabOffset: Qt.point(8, 7)
                }
                // 选中项后面再垫一块粉色碎片
                P5Poly {
                    visible: bar.isSel
                    z: -1
                    anchors.fill: parent
                    readonly property real w: width
                    readonly property real h: height
                    points: [[-14, -10], [w * 0.55, -14], [w * 0.5, h + 6], [-6, h + 12]]
                    fillColor: P5.pink
                }

                AppIconRenderer {
                    id: icon
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    iconSize: 36
                    iconValue: root.iconValueOf(bar.modelData.item)
                    fallbackText: (bar.modelData.item?.name || "?").charAt(0).toUpperCase()
                    materialIconSizeAdjustment: 10
                    iconColor: bar.isSel ? P5.ink : P5.paper
                    rotation: bar.isSel ? -6 : 0
                }
                Text {
                    anchors.left: icon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1
                    text: bar.modelData.item?.name ?? ""
                    elide: Text.ElideRight
                    color: bar.isSel ? P5.ink : P5.paper
                    font.family: P5.labelFont
                    font.pixelSize: bar.isSel ? 26 : 21
                    font.weight: Font.Black
                    font.italic: true
                }

                MouseArea {
                    id: barArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (bar.isSel)
                            root.fire(bar.index);
                        else
                            root.step(Math.round(bar.k));
                    }
                }
            }
        }
    }

    // 选中项右侧：编号 + 准星
    Item {
        x: root.width - root.tipW - 60
        y: root.cy - 66
        width: 120
        height: 40
        visible: root.entries.length > 0
        z: 200

        P5Tag {
            text: "No." + String(root.selected + 1).padStart(2, "0") + " / " + root.entries.length
            pixelSize: 12
            fillColor: P5.paper
            textColor: P5.ink
            tilt: 6
        }
    }

    // 空结果
    Column {
        anchors.centerIn: parent
        visible: root.entries.length === 0
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NO TARGET"
            color: P5.paper
            font.family: P5.displayFont
            font.pixelSize: 48
            rotation: -5
        }
        P5Tag {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "没有找到匹配的应用"
            family: P5.bodyFont
            italic: false
            pixelSize: 13
            fillColor: P5.violet
            textColor: P5.ink
        }
    }

    // ---- 顶部搜索横幅（打字时出现）----
    Item {
        id: searchBanner
        x: 18
        width: root.width - root.tipW - 40
        height: 54
        y: root.searching ? 20 : -height - 20
        opacity: root.searching ? 1 : 0
        z: 300

        Behavior on y {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: P5.punchCurve
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        P5Plate {
            anchors.fill: parent
            rotation: -1.5
            seed: 909
            jitter: 3
            skew: 22
            fillColor: P5.paper
            slabColor: P5.ink
            slabOffset: Qt.point(6, 6)
        }
        P5Tag {
            id: seekTag
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "SEARCH"
            family: P5.displayFont
            italic: false
            weight: Font.Normal
            pixelSize: 18
            fillColor: P5.ink
            textColor: P5.violet
            tilt: -4
        }
        Text {
            anchors.left: seekTag.right
            anchors.leftMargin: 14
            anchors.right: countText.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: input.text + (cursorBlink.on ? "▍" : " ")
            elide: Text.ElideLeft
            color: P5.ink
            font.family: P5.labelFont
            font.pixelSize: 26
            font.weight: Font.Black
            font.italic: true
        }
        Text {
            id: countText
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.entries.length + " HIT"
            color: P5.plum
            font.family: P5.displayFont
            font.pixelSize: 18
        }
        Timer {
            id: cursorBlink
            property bool on: true
            interval: 530
            repeat: true
            running: root.searching && root.open
            onTriggered: on = !on
        }
    }

    // 底部按键提示
    Row {
        x: 120
        y: root.height - 34
        spacing: 10
        z: 300
        opacity: 0.85
        Repeater {
            model: [["↑↓ / 滚轮", "转动"], ["⏎", "开火"], ["键入", "搜索"]]
            Row {
                required property var modelData
                spacing: 4
                P5Tag {
                    text: parent.modelData[0]
                    pixelSize: 11
                    family: P5.bodyFont
                    italic: false
                    fillColor: P5.paper
                    textColor: P5.ink
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData[1]
                    color: P5.lilac
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: wheel => {
            acc += wheel.angleDelta.y;
            while (Math.abs(acc) >= 60) {
                root.step(acc > 0 ? -1 : 1);
                acc -= acc > 0 ? 120 : -120;
                if (Math.abs(acc) < 60)
                    acc = 0;
            }
        }
    }

    // 隐形输入框：接收键入与方向键
    TextInput {
        id: input
        width: 1
        height: 1
        opacity: 0
        focus: true
        onTextChanged: ctl.setSearchQuery(text)

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                root.step(-1);
                break;
            case Qt.Key_Down:
            case Qt.Key_Tab:
                root.step(1);
                break;
            case Qt.Key_PageUp:
                root.step(-5);
                break;
            case Qt.Key_PageDown:
                root.step(5);
                break;
            case Qt.Key_Home:
                root.selectEntry(0);
                break;
            case Qt.Key_End:
                root.selectEntry(root.entries.length - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.fire();
                break;
            case Qt.Key_Escape:
                if (input.text.length > 0) {
                    input.text = "";
                    break;
                }
                root.closeRequested();
                break;
            case Qt.Key_N:
            case Qt.Key_J:
                if (event.modifiers & Qt.ControlModifier) {
                    root.step(1);
                    break;
                }
                return;
            case Qt.Key_P:
            case Qt.Key_K:
                if (event.modifiers & Qt.ControlModifier) {
                    root.step(-1);
                    break;
                }
                return;
            default:
                return;
            }
            event.accepted = true;
        }
    }
}
