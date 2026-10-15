pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 岛展开后的主页：左上角色卡（头像 / 用户名 / 设备名），左下状态条（从左到右的拉力条），右侧大日期 + 月历。
Item {
    id: root

    property bool live: false
    signal closeDash

    implicitWidth: 940
    implicitHeight: 452

    // ---- 数据 ----
    property bool dgopRefHeld: false
    function syncDgopRef(wanted) {
        if (wanted === dgopRefHeld)
            return;
        dgopRefHeld = wanted;
        if (wanted)
            DgopService.addRef(["cpu", "memory", "system", "diskmounts"]);
        else
            DgopService.removeRef(["cpu", "memory", "system", "diskmounts"]);
    }
    onLiveChanged: {
        syncDgopRef(live);
        if (!live)
            monthOffset = 0;
    }
    Component.onCompleted: syncDgopRef(live)
    Component.onDestruction: syncDgopRef(false)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date now: clock.date
    readonly property var locale: I18n.locale()
    readonly property real rootDiskPercent: {
        const m = (DgopService.diskMounts || []).find(d => d.mount === "/");
        return m && m.percent ? (parseFloat(String(m.percent).replace("%", "")) || 0) : 0;
    }
    readonly property real swapPercent: DgopService.totalSwapKB > 0 ? DgopService.usedSwapKB / DgopService.totalSwapKB * 100 : 0
    readonly property string hostName: UserInfoService.hostname || DgopService.hostname || "localhost"
    readonly property string userName: UserInfoService.username || "user"

    // 月历显示的月份（相对当前月的偏移）
    property int monthOffset: 0
    readonly property date shownMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    function handleKeyEvent(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            monthOffset -= 1;
            return true;
        }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            monthOffset += 1;
            return true;
        }
        if (event.key === Qt.Key_Home || event.key === Qt.Key_T) {
            monthOffset = 0;
            return true;
        }
        return false;
    }

    // ---- 左列 ----
    Item {
        id: leftCol
        x: 10
        y: 6
        width: 430
        height: parent.height - 12

        // 背后的大字水印
        Text {
            x: -6
            y: 132
            text: "PHANTOM"
            color: P5.alpha(P5.violet, 0.07)
            font.family: P5.displayFont
            font.pixelSize: 96
            rotation: -8
        }

        // -- 角色卡 --
        Item {
            id: profile
            width: parent.width
            height: 170

            // 头像：歪着的方形照片 + 白框 + 淡紫错位板
            Item {
                id: avatarBox
                x: 14
                y: 18
                width: 128
                height: 128
                rotation: -6

                P5Plate {
                    anchors.fill: parent
                    anchors.margins: -6
                    seed: 41
                    jitter: 3
                    fillColor: P5.paper
                    slabColor: P5.violet
                    slabOffset: Qt.point(9, 8)
                    slabRotation: 4
                    slab2Color: P5.ink
                    slab2Offset: Qt.point(-7, 10)
                    slab2Rotation: -3
                }
                Rectangle {
                    anchors.fill: parent
                    color: P5.plum
                    clip: true

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(256, 256)
                        source: {
                            const p = PortalService.profileImage;
                            if (!p)
                                return "";
                            return p.startsWith("/") ? "file://" + p : p;
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: avatarImg.status !== Image.Ready
                        text: root.userName.charAt(0).toUpperCase()
                        color: P5.paper
                        font.family: P5.displayFont
                        font.pixelSize: 84
                    }
                }
            }

            P5Tag {
                x: 168
                y: 16
                text: "CODE NAME"
                pixelSize: 12
                fillColor: P5.violet
                textColor: P5.ink
                tilt: -3
            }

            // 用户名：大号 Anton，后面压一条斜的黑带
            Item {
                id: nameBlock
                x: 160
                y: 38
                width: parent.width - x
                height: 72

                P5Plate {
                    x: -8
                    y: 14
                    width: Math.min(parent.width + 4, nameText.implicitWidth + 40)
                    height: 50
                    rotation: -2.5
                    seed: 42
                    jitter: 3
                    skew: 24
                    fillColor: P5.ink
                    borderWidth: 2.5
                    borderColor: P5.paper
                }
                Text {
                    id: nameShadow
                    x: nameText.x + 4
                    y: nameText.y + 4
                    text: nameText.text
                    font: nameText.font
                    color: P5.pink
                    rotation: nameText.rotation
                }
                Text {
                    id: nameText
                    x: 10
                    y: 0
                    width: parent.width - 10
                    elide: Text.ElideRight
                    text: root.userName.toUpperCase()
                    color: P5.paper
                    font.family: P5.displayFont
                    font.pixelSize: 58
                    rotation: -2.5
                }
            }

            Row {
                x: 166
                y: 122
                spacing: 8

                P5Tag {
                    text: "@ " + root.hostName
                    pixelSize: 15
                    fillColor: P5.paper
                    textColor: P5.ink
                    slabColor: P5.violet
                    tilt: 2
                }
                P5Tag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: DgopService.shortUptime ? "UP " + DgopService.shortUptime.replace(/^up\s*/i, "").toUpperCase() : "UP --"
                    pixelSize: 12
                    fillColor: P5.ink
                    textColor: P5.violet
                    borderWidth: 1.5
                    borderColor: P5.violet
                    tilt: -2
                }
            }
        }

        // -- 状态条 --
        Item {
            id: stats
            y: profile.height + 22
            width: parent.width
            height: parent.height - y

            P5Tag {
                id: statsHead
                x: 4
                text: "STATUS"
                family: P5.displayFont
                italic: false
                weight: Font.Normal
                pixelSize: 20
                fillColor: P5.paper
                textColor: P5.ink
                slabColor: P5.pink
                tilt: -4
            }
            Text {
                anchors.left: statsHead.right
                anchors.leftMargin: 14
                anchors.verticalCenter: statsHead.verticalCenter
                text: (DgopService.cpuModel || "").replace(/\s+\d+-Core.*$/, "").replace(/\(R\)|\(TM\)/g, "")
                color: P5.lilac
                font.family: P5.labelFont
                font.pixelSize: 12
                font.italic: true
                width: parent.width - x
                elide: Text.ElideRight
            }

            Column {
                y: statsHead.height + 14
                width: parent.width
                spacing: 9

                Repeater {
                    model: [
                        {
                            key: "CPU",
                            value: DgopService.cpuUsage,
                            text: Math.round(DgopService.cpuUsage) + "%",
                            warn: 60,
                            crit: 85
                        },
                        {
                            key: "RAM",
                            value: DgopService.memoryUsage,
                            text: Math.round(DgopService.memoryUsage) + "%",
                            warn: 75,
                            crit: 90
                        },
                        {
                            key: "TEMP",
                            value: DgopService.cpuTemperature,
                            text: Math.round(DgopService.cpuTemperature) + "°",
                            warn: 70,
                            crit: 85
                        },
                        {
                            key: "DISK",
                            value: root.rootDiskPercent,
                            text: Math.round(root.rootDiskPercent) + "%",
                            warn: 80,
                            crit: 92
                        },
                        {
                            key: "SWAP",
                            value: root.swapPercent,
                            text: Math.round(root.swapPercent) + "%",
                            warn: 50,
                            crit: 80
                        }
                    ]

                    Item {
                        id: statRow
                        required property var modelData
                        required property int index
                        width: stats.width
                        height: 30
                        x: index * -5   // 整列往左下斜着排

                        P5Tag {
                            id: key
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            width: 62
                            text: statRow.modelData.key
                            pixelSize: 14
                            fillColor: statRow.index % 2 === 0 ? P5.ink : P5.paper
                            textColor: statRow.index % 2 === 0 ? P5.paper : P5.ink
                            borderWidth: statRow.index % 2 === 0 ? 1.5 : 0
                            borderColor: P5.paper
                            tilt: P5.rand(statRow.index + 7, 1) * 3
                        }
                        P5Meter {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: key.right
                            anchors.leftMargin: 8
                            anchors.right: num.left
                            anchors.rightMargin: 10
                            height: 18
                            value: statRow.modelData.value / 100
                            level: statRow.modelData.value >= statRow.modelData.crit ? 2 : (statRow.modelData.value >= statRow.modelData.warn ? 1 : 0)
                        }
                        Text {
                            id: num
                            anchors.right: parent.right
                            anchors.rightMargin: 4 - statRow.x
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54
                            horizontalAlignment: Text.AlignRight
                            text: statRow.modelData.text
                            color: statRow.modelData.value >= statRow.modelData.crit ? P5.blood : P5.paper
                            font.family: P5.displayFont
                            font.pixelSize: 22
                        }
                    }
                }
            }
        }
    }

    // 中间一刀斜线把两列切开
    P5Poly {
        x: leftCol.x + leftCol.width + 6
        y: 0
        width: 40
        height: parent.height
        points: [[22, -4], [30, -4], [10, height + 4], [2, height + 4]]
        fillColor: P5.paper
        slabColor: P5.violet
        slabOffset: Qt.point(7, 0)
    }

    // ---- 右列：日期 ----
    Item {
        id: rightCol
        x: leftCol.x + leftCol.width + 52
        y: 0
        width: parent.width - x - 6
        height: parent.height

        // 大日期块
        Item {
            id: bigDate
            width: parent.width
            height: 172

            Text {
                id: dayShadow
                x: dayNum.x + 7
                y: dayNum.y + 6
                text: dayNum.text
                font: dayNum.font
                color: P5.violet
                rotation: dayNum.rotation
            }
            Text {
                id: dayNum
                x: 4
                y: -18
                text: String(root.now.getDate()).padStart(2, "0")
                color: P5.paper
                font.family: P5.displayFont
                font.pixelSize: 150
                rotation: -4
                style: Text.Outline
                styleColor: P5.ink
            }

            Column {
                anchors.left: dayNum.right
                anchors.leftMargin: 18
                y: 14
                spacing: 6

                P5Tag {
                    text: root.now.toLocaleDateString(Qt.locale("en_US"), "dddd").toUpperCase()
                    family: P5.displayFont
                    italic: false
                    weight: Font.Normal
                    pixelSize: 26
                    fillColor: P5.violet
                    textColor: P5.ink
                    slabColor: P5.paper
                    slabOffset: Qt.point(4, 4)
                    tilt: -3
                }
                Row {
                    spacing: 8
                    leftPadding: 10
                    Text {
                        text: root.now.toLocaleDateString(Qt.locale("en_US"), "MMM").toUpperCase()
                        color: P5.paper
                        font.family: P5.displayFont
                        font.pixelSize: 40
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: root.now.getFullYear()
                        color: P5.lilac
                        font.family: P5.labelFont
                        font.pixelSize: 20
                        font.italic: true
                        font.weight: Font.Bold
                    }
                }
                P5Tag {
                    text: root.now.toLocaleDateString(root.locale, "M月d日 dddd")
                    family: P5.bodyFont
                    italic: false
                    pixelSize: 13
                    fillColor: P5.ink
                    textColor: P5.paper
                    borderWidth: 1.5
                    borderColor: P5.paper
                    tilt: 2
                }
            }
        }

        // 月历
        Item {
            id: cal
            y: bigDate.height
            width: parent.width
            height: parent.height - y - 4

            readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
            readonly property var cells: {
                const first = root.shownMonth;
                const lead = (first.getDay() - firstDow + 7) % 7;
                const out = [];
                for (let i = 0; i < 42; i++)
                    out.push(new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
                return out;
            }
            readonly property real cellW: width / 7

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => root.monthOffset += wheel.angleDelta.y > 0 ? -1 : 1
            }

            Item {
                id: head
                width: parent.width
                height: 28

                P5Tag {
                    id: monthTag
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.shownMonth.toLocaleDateString(Qt.locale("en_US"), "MMMM yyyy").toUpperCase()
                    pixelSize: 14
                    fillColor: root.monthOffset === 0 ? P5.paper : P5.pink
                    textColor: P5.ink
                    tilt: -2
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: ["chevron_left", "today", "chevron_right"]

                        Item {
                            id: navBtn
                            required property string modelData
                            required property int index
                            width: 34
                            height: 24

                            P5Plate {
                                anchors.fill: parent
                                skew: 8
                                fillColor: navArea.pressed ? P5.blood : (navArea.containsMouse ? P5.violet : P5.ink)
                                borderWidth: 1.5
                                borderColor: P5.paper
                            }
                            DankIcon {
                                anchors.centerIn: parent
                                name: navBtn.modelData
                                size: 16
                                color: navArea.containsMouse ? P5.ink : P5.paper
                            }
                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.monthOffset = navBtn.index === 1 ? 0 : root.monthOffset + (navBtn.index === 0 ? -1 : 1)
                            }
                        }
                    }
                }
            }

            // 星期表头 + 日期格
            Grid {
                y: head.height + 6
                columns: 7

                Repeater {
                    model: 7

                    Item {
                        required property int index
                        readonly property int dow: (cal.firstDow + index) % 7
                        width: cal.cellW
                        height: 20

                        Text {
                            anchors.centerIn: parent
                            text: Qt.locale("en_US").dayName(parent.dow, Locale.ShortFormat).toUpperCase()
                            color: parent.dow === 0 || parent.dow === 6 ? P5.pink : P5.lilac
                            font.family: P5.labelFont
                            font.pixelSize: 12
                            font.italic: true
                            font.weight: Font.Bold
                        }
                    }
                }

                Repeater {
                    model: cal.cells

                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool inMonth: modelData.getMonth() === root.shownMonth.getMonth()
                        readonly property bool today: modelData.toDateString() === root.now.toDateString()
                        readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6
                        width: cal.cellW
                        height: (cal.height - head.height - 6 - 20) / 6

                        P5Plate {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 6, 46)
                            height: parent.height - 4
                            visible: cell.today
                            rotation: -5
                            seed: 77
                            jitter: 2
                            skew: 8
                            fillColor: P5.violet
                            borderWidth: 2
                            borderColor: P5.paper
                            slabColor: P5.ink
                            slabOffset: Qt.point(4, 4)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            rotation: cell.today ? -5 : 0
                            color: cell.today ? P5.ink : (!cell.inMonth ? P5.alpha(P5.lilac, 0.28) : (cell.weekend ? P5.pink : P5.paper))
                            font.family: cell.today ? P5.displayFont : P5.labelFont
                            font.pixelSize: cell.today ? 22 : 17
                            font.weight: Font.Bold
                            font.italic: !cell.today
                        }
                    }
                }
            }
        }
    }
}
