import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets

// 组件总览：栏组件（与 Modules/Plugins/BasePill.qml 同参数）、工作区、岛、标签、开关、滑条、按钮、选中行、面板
Item {
    id: scene

    // 与 BasePill 的背景保持同一套参数
    component Pill: Item {
        id: pill
        property alias contentItem: holder.data
        property bool hovered: false
        property bool pressed: false
        property int seed: P5.nextSeed()
        readonly property real tilt: P5.rand(seed, 11) * 1.6
        width: holder.childrenRect.width + 24
        height: 30
        Item {
            anchors.fill: parent
            rotation: pill.hovered ? -pill.tilt * 0.5 : pill.tilt
            scale: pill.pressed ? 0.96 : (pill.hovered ? 1.07 : 1)
            P5Plate {
                anchors.fill: parent
                seed: pill.seed
                jitter: 2
                skew: P5.slant(height) * 0.8
                cutBottomRight: 5
                fillColor: pill.pressed ? P5.blood : (pill.hovered ? P5.plumRaised : P5.plum)
                borderWidth: 3
                borderColor: P5.paper
                rimColor: P5.ink
                rimInset: 3
                rimWidth: 1.5
                slabColor: P5.violet
                slabOffset: pill.hovered ? Qt.point(6, 5) : Qt.point(4, 4)
                slabRotation: P5.rand(pill.seed, 12) * 4
                slab2Color: pill.hovered ? P5.pink : "transparent"
                slab2Offset: Qt.point(-5, 6)
                slab2Rotation: -P5.rand(pill.seed, 12) * 5
            }
        }
        Row {
            id: holder
            anchors.centerIn: parent
            spacing: 6
        }
    }
    component Label: StyledText {
        color: Style.surfaceText
        font.pixelSize: 13
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    Row {
        x: 30; y: 24
        spacing: 10
        Pill { contentItem: [DankIcon { name: "apps"; size: 18; color: Style.surfaceText }] }
        Item {
            width: 120; height: 30
            P5Plate {
                anchors.fill: parent
                seed: 7; jitter: 2; rotation: -0.8
                skew: P5.slant(height) * 0.8; cutBottomRight: 5
                fillColor: P5.plum
                borderWidth: 3; borderColor: P5.paper
                rimColor: P5.ink; rimInset: 3; rimWidth: 1.5
                slabColor: P5.violet; slabOffset: Qt.point(3, 3); slabRotation: 1.2
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                P5Plate {
                    width: 30; height: 15; anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0
                    seed: 31; jitter: 1.5; skew: P5.slant(height); rotation: -4
                    fillColor: P5.paper
                    slabColor: P5.violet; slabOffset: Qt.point(3, 3); slabRotation: 5
                    slab2Color: P5.pink; slab2Offset: Qt.point(-3, 4); slab2Rotation: -6
                }
                P5Plate { width: 20; height: 12; anchors.verticalCenter: parent.verticalCenter; seed: 32; jitter: 1; skew: P5.slant(height); fillColor: P5.alpha(P5.violet, 0.8) }
                P5Plate { width: 20; height: 12; anchors.verticalCenter: parent.verticalCenter; seed: 33; jitter: 1; skew: P5.slant(height); fillColor: P5.alpha(P5.paper, 0.25) }
            }
        }
        Pill { contentItem: [DankIcon { name: "terminal"; size: 16; color: Style.surfaceText }, Label { text: "kitty · 女神异闻录" }] }
        Pill { hovered: true; contentItem: [DankIcon { name: "memory"; size: 16; color: Style.surfaceText }, Label { text: "3%" }] }
        Pill { pressed: true; contentItem: [DankIcon { name: "notifications"; size: 16; color: Style.surfaceText }] }
        Pill { contentItem: [DankIcon { name: "battery_full"; size: 16; color: Style.primary }, Label { text: "99%" }] }
        Pill { contentItem: [DankIcon { name: "lan"; size: 16; color: Style.primary }, DankIcon { name: "bluetooth"; size: 16; color: Style.primary }, DankIcon { name: "volume_up"; size: 16; color: Style.surfaceText }] }
    }

    // 收起的岛
    Item {
        x: 330; y: 80; width: 260; height: 34
        P5Plate {
            anchors.fill: parent
            seed: 3; jitter: 2
            skew: P5.slant(Math.min(height, 40)) * 0.8
            cutBottomRight: 6
            fillColor: P5.plum
            borderWidth: 3; borderColor: P5.paper
            rimColor: P5.ink; rimInset: 3; rimWidth: 1.5
            slabColor: P5.violet; slabOffset: Qt.point(4, 4); slabRotation: 2.5
            slab2Color: P5.pink; slab2Offset: Qt.point(-5, 5); slab2Rotation: -3
        }
        Row {
            anchors.centerIn: parent; spacing: 8
            P5Ransom { text: "23:24"; pixelSize: 18 }
            Label { text: "周三 10月 14"; opacity: 0.8 }
        }
    }

    // 面板
    ElevationShadow {
        x: 40; y: 150; width: 470; height: 500
        targetColor: Style.surfaceContainer
        Column {
            x: 26; y: 24; width: parent.width - 52
            spacing: 14
            DankTabBar {
                width: parent.width
                tabHeight: 56
                currentIndex: 1
                model: [{ "text": "概览", "icon": "dashboard" }, { "text": "媒体", "icon": "music_note" }, { "text": "天气", "icon": "cloud" }]
            }
            Item { width: 1; height: 10 }
            Repeater {
                model: ["Clash Verge", "网易云音乐", "飞书", "Termius"]
                Item {
                    width: parent.width; height: 48
                    P5Select { selected: index === 1; hovered: index === 2 }
                    Row {
                        x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        DankIcon { name: "apps"; size: 22; color: index === 1 ? P5.ink : Style.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: modelData; font.pixelSize: 15; color: index === 1 ? P5.ink : Style.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            Row {
                spacing: 18
                DankToggle { checked: true }
                DankToggle { checked: false }
                DankButton { text: "确定" }
                DankButton { text: "取消"; backgroundColor: Style.surfaceContainerHigh; textColor: Style.surfaceText }
            }
            DankSlider { width: parent.width; value: 62; leftIcon: "volume_up" }
        }
    }
}
