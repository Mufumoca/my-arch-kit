pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 性能面板（点栏上的 CPU / 内存）：顶部两张大情报卡（巨大的 Anton 百分比 + 锯齿历史曲线），
// 下面是“通缉排行”式的进程榜：编号块 + 名字 + 斜切 CPU 条 + 内存，选中行是淡紫块。
Item {
    id: root

    property bool open: false
    property var contextMenu: null
    signal closeRequested

    implicitWidth: 780
    implicitHeight: 690

    property string searchText: ""
    property string processFilter: "all"
    property int selectedIndex: -1
    property bool keyboardNavigationActive: false

    readonly property alias searchField: search

    // ---- 数据 ----
    readonly property var dgopModules: ["processes", "cpu", "memory", "system"]
    property bool dgopHeld: false
    function syncDgop(wanted) {
        if (wanted === dgopHeld)
            return;
        dgopHeld = wanted;
        if (wanted)
            DgopService.addRef(dgopModules);
        else
            DgopService.removeRef(dgopModules);
    }
    onOpenChanged: {
        syncDgop(open);
        if (!open)
            reset();
    }
    Component.onCompleted: syncDgop(open)
    Component.onDestruction: syncDgop(false)

    readonly property bool paused: contextMenu?.visible ?? false
    property var shown: []
    onFilteredChanged: if (!paused) shown = filtered
    onPausedChanged: if (!paused) shown = filtered

    readonly property var filtered: {
        let procs = (DgopService.allProcesses || []).slice();
        if (processFilter === "user")
            procs = procs.filter(p => p.username === UserInfoService.username);
        else if (processFilter === "system")
            procs = procs.filter(p => p.username !== UserInfoService.username);
        if (searchText.length > 0) {
            const q = searchText.toLowerCase();
            procs = procs.filter(p => (p.command || "").toLowerCase().includes(q) || (p.fullCommand || "").toLowerCase().includes(q) || String(p.pid).includes(q));
        }
        const asc = DgopService.sortAscending;
        procs.sort((a, b) => {
            let r = 0;
            switch (DgopService.currentSort) {
            case "cpu":
                r = (b.cpu || 0) - (a.cpu || 0);
                break;
            case "memory":
                r = (b.memoryKB || 0) - (a.memoryKB || 0);
                break;
            case "name":
                r = (a.command || "").toLowerCase().localeCompare((b.command || "").toLowerCase());
                break;
            case "pid":
                r = (a.pid || 0) - (b.pid || 0);
                break;
            }
            return asc ? -r : r;
        });
        return procs;
    }

    function mem(kb) {
        kb = kb || 0;
        if (kb === 0)
            return "0";
        if (kb < 1024)
            return kb.toFixed(0) + "K";
        if (kb < 1024 * 1024)
            return (kb / 1024).toFixed(kb < 100 * 1024 ? 1 : 0) + "M";
        return (kb / (1024 * 1024)).toFixed(1) + "G";
    }

    function reset() {
        selectedIndex = -1;
        keyboardNavigationActive = false;
        searchText = "";
        search.text = "";
        processFilter = "all";
    }
    function select(i) {
        if (shown.length === 0)
            return;
        keyboardNavigationActive = true;
        selectedIndex = Math.max(0, Math.min(shown.length - 1, i));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function openMenuFor(index, item, x, y, fromKeyboard) {
        const p = shown[index];
        if (!p || !contextMenu || !item)
            return;
        contextMenu.processData = p;
        contextMenu.parentFocusItem = search;
        const pos = item.mapToItem(contextMenu.parent, x, y);
        contextMenu.show(pos.x, pos.y, fromKeyboard);
    }
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        switch (event.key) {
        case Qt.Key_Escape:
            if (search.text.length > 0)
                search.text = "";
            else if (keyboardNavigationActive) {
                selectedIndex = -1;
                keyboardNavigationActive = false;
            } else
                root.closeRequested();
            break;
        case Qt.Key_Down:
            select(selectedIndex + 1);
            break;
        case Qt.Key_Up:
            if (selectedIndex <= 0) {
                selectedIndex = -1;
                keyboardNavigationActive = false;
            } else {
                select(selectedIndex - 1);
            }
            break;
        case Qt.Key_PageDown:
            select(selectedIndex + 8);
            break;
        case Qt.Key_PageUp:
            select(selectedIndex - 8);
            break;
        case Qt.Key_J:
            if (!ctrl)
                return false;
            select(selectedIndex + 1);
            break;
        case Qt.Key_K:
            if (!ctrl)
                return false;
            select(selectedIndex - 1);
            break;
        case Qt.Key_Tab:
            processFilter = processFilter === "all" ? "user" : (processFilter === "user" ? "system" : "all");
            break;
        case Qt.Key_Menu:
        case Qt.Key_F10:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (selectedIndex < 0)
                return false;
            openMenuFor(selectedIndex, list.itemAtIndex(selectedIndex), 220, 20, true);
            break;
        default:
            return false;
        }
        return true;
    }

    // ---- 背景 ----
    P5Plate {
        anchors.fill: parent
        anchors.margins: 6
        seed: 612
        jitter: 4
        cutTopLeft: 22
        cutBottomRight: 22
        fillColor: P5.alpha(P5.night, 0.97)
        borderWidth: 4
        borderColor: P5.paper
        rimColor: P5.alpha(P5.paper, 0.18)
        rimInset: 8
        rimWidth: 1
        slabColor: P5.violet
        slabOffset: Qt.point(10, 10)
        slabRotation: 0.8
        slab2Color: P5.pink
        slab2Offset: Qt.point(-8, 14)
        slab2Rotation: -1.2
        accentColor: P5.violet
        stripes: 0.03
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: "INTEL"
        color: P5.alpha(P5.violet, 0.07)
        font.family: P5.displayFont
        font.pixelSize: 150
        rotation: -8
    }

    // ---- 标题 ----
    Item {
        id: header
        x: 30
        y: 24
        width: root.width - 60
        height: 50

        P5Tag {
            id: titleTag
            text: "SYSTEM INTEL"
            family: P5.displayFont
            italic: false
            weight: Font.Normal
            pixelSize: 30
            fillColor: P5.paper
            textColor: P5.ink
            slabColor: P5.violet
            slabOffset: Qt.point(6, 5)
            tilt: -3
        }
        Column {
            anchors.left: titleTag.right
            anchors.leftMargin: 18
            anchors.verticalCenter: titleTag.verticalCenter
            spacing: 0
            Text {
                text: "@" + (DgopService.hostname || "localhost") + "  //  " + (DgopService.distribution || "Linux")
                color: P5.paper
                font.family: P5.labelFont
                font.pixelSize: 15
                font.italic: true
                font.weight: Font.Bold
            }
            Text {
                text: (DgopService.shortUptime || "--").toUpperCase() + "   " + DgopService.processCount + " PROCS   LOAD " + (DgopService.loadAverage || "--")
                color: P5.lilac
                font.family: P5.labelFont
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
        }
        // 关闭
        Item {
            anchors.right: parent.right
            anchors.verticalCenter: titleTag.verticalCenter
            width: 34
            height: 30
            P5Plate {
                anchors.fill: parent
                skew: 10
                fillColor: closeArea.pressed ? P5.blood : (closeArea.containsMouse ? P5.violet : P5.ink)
                borderWidth: 2
                borderColor: P5.paper
            }
            DankIcon {
                anchors.centerIn: parent
                name: "close"
                size: 18
                color: closeArea.containsMouse ? P5.ink : P5.paper
            }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }

    // ---- 情报卡 ----
    component StatCard: Item {
        id: card
        property string label
        property string icon
        property real value: 0       // 0..100
        property string big
        property string sub
        property string sub2
        property var history: []
        property real warn: 60
        property real danger: 85
        property int seed: 0
        property bool flip: false
        readonly property int level: value >= danger ? 2 : (value >= warn ? 1 : 0)
        readonly property color levelColor: level === 2 ? P5.blood : (level === 1 ? P5.pink : P5.violet)
        height: 150
        rotation: flip ? 1.2 : -1.2

        P5Plate {
            anchors.fill: parent
            skew: 22
            jitter: 3
            seed: card.seed
            fillColor: P5.ink
            borderWidth: 3
            borderColor: P5.paper
            slabColor: card.levelColor
            slabOffset: Qt.point(7, 7)
        }
        // 历史曲线：锯齿折线 + 填充
        P5Poly {
            id: chart
            x: 18
            y: 52
            width: parent.width - 36
            height: parent.height - 66
            opacity: 0.9
            readonly property var h: {
                card.value;
                const src = (card.history || []).slice(-40);
                return src.length > 1 ? src : [0, 0];
            }
            // 自动缩放：低负载时也看得出起伏
            readonly property real ceil: Math.min(100, Math.max(20, Math.max(...h) * 1.3))
            points: {
                const n = h.length, out = [[0, height]];
                for (let i = 0; i < n; i++)
                    out.push([i / (n - 1) * width, height - Math.max(0, Math.min(ceil, h[i])) / ceil * height]);
                out.push([width, height]);
                return out;
            }
            fillColor: P5.alpha(card.levelColor, 0.28)
            strokeColor: card.levelColor
            strokeWidth: 2
        }
        P5Tag {
            x: 22
            y: -10
            text: card.label
            family: P5.displayFont
            italic: false
            weight: Font.Normal
            pixelSize: 15
            fillColor: card.levelColor
            textColor: P5.ink
            tilt: -4
        }
        DankIcon {
            x: 26
            y: 26
            name: card.icon
            size: 22
            color: P5.lilac
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 26
            y: 4
            text: card.big
            color: P5.paper
            style: Text.Outline
            styleColor: P5.ink
            font.family: P5.displayFont
            font.pixelSize: 62
        }
        Column {
            x: 56
            y: 20
            spacing: 0
            Text {
                text: card.sub
                color: P5.paper
                font.family: P5.labelFont
                font.pixelSize: 14
                font.italic: true
                font.weight: Font.Bold
            }
            Text {
                text: card.sub2
                color: P5.lilac
                font.family: P5.labelFont
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }
    }

    Row {
        id: cards
        x: 34
        y: header.y + header.height + 22
        spacing: 26

        StatCard {
            width: (root.width - 68 - 26) / 2
            seed: 620
            label: "CPU"
            icon: "memory"
            value: DgopService.cpuUsage
            big: Math.round(DgopService.cpuUsage) + "%"
            sub: (DgopService.cpuTemperature > 0 ? DgopService.cpuTemperature.toFixed(0) + "°C   " : "") + (DgopService.cpuFrequency > 0 ? (DgopService.cpuFrequency / 1000).toFixed(1) + " GHz" : "")
            sub2: DgopService.cpuCores + " CORES"
            history: DgopService.cpuHistory
        }
        StatCard {
            width: (root.width - 68 - 26) / 2
            seed: 621
            flip: true
            label: "MEMORY"
            icon: "developer_board"
            value: DgopService.memoryUsage
            warn: 75
            danger: 90
            big: Math.round(DgopService.memoryUsage) + "%"
            sub: root.mem(DgopService.usedMemoryKB) + " / " + root.mem(DgopService.totalMemoryKB)
            sub2: DgopService.totalSwapKB > 0 ? "SWAP " + root.mem(DgopService.usedSwapKB) + " / " + root.mem(DgopService.totalSwapKB) : ""
            history: DgopService.memoryHistory
        }
    }

    // ---- 筛选 / 排序 / 搜索 ----
    Item {
        id: controls
        x: 30
        y: cards.y + 150 + 24
        width: root.width - 60
        height: 34

        Row {
            id: filters
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [["all", "ALL"], ["user", "USER"], ["system", "SYSTEM"]]
                P5Tag {
                    id: ft
                    required property var modelData
                    readonly property bool on: root.processFilter === modelData[0]
                    text: modelData[1]
                    family: P5.displayFont
                    italic: false
                    weight: Font.Normal
                    pixelSize: 14
                    fillColor: on ? P5.violet : P5.ink
                    textColor: on ? P5.ink : P5.lilac
                    borderWidth: on ? 0 : 1.5
                    borderColor: P5.lilac
                    tilt: -4
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.processFilter = ft.modelData[0]
                    }
                }
            }
        }

        // 搜索条
        Item {
            id: searchBox
            anchors.left: filters.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 32

            P5Plate {
                anchors.fill: parent
                seed: 630
                jitter: 2
                skew: 14
                fillColor: P5.paper
                slabColor: P5.violet
                slabOffset: Qt.point(4, 4)
            }
            DankIcon {
                id: sIcon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 18
                color: P5.ink
            }
            TextInput {
                id: search
                anchors.left: sIcon.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: P5.ink
                font.family: P5.bodyFont
                font.pixelSize: 15
                font.weight: Font.Bold
                selectionColor: P5.violet
                clip: true
                onTextChanged: {
                    root.searchText = text;
                    root.selectedIndex = -1;
                    root.keyboardNavigationActive = false;
                }
                Keys.onPressed: event => event.accepted = root.handleKey(event)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text
                    text: "SEARCH TARGET…"
                    color: P5.alpha(P5.ink, 0.45)
                    font.family: P5.labelFont
                    font.pixelSize: 14
                    font.italic: true
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ---- 列头 ----
    readonly property real colCpu: 150
    readonly property real colMem: 74
    readonly property real colPid: 70
    Item {
        id: colHead
        x: 34
        y: controls.y + controls.height + 14
        width: root.width - 68
        height: 22

        component Head: Text {
            id: hd
            property string key
            readonly property bool on: DgopService.currentSort === key
            text: (on ? (DgopService.sortAscending ? "▲ " : "▼ ") : "") + hdText
            property string hdText
            color: on ? P5.violet : P5.lilac
            font.family: P5.displayFont
            font.pixelSize: 13
            font.letterSpacing: 1
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: DgopService.toggleSort(hd.key)
            }
        }
        Head {
            x: 74
            key: "name"
            hdText: "TARGET"
        }
        Head {
            x: parent.width - root.colPid - root.colMem - root.colCpu - 30
            key: "cpu"
            hdText: "CPU"
        }
        Head {
            x: parent.width - root.colPid - root.colMem - 10
            key: "memory"
            hdText: "MEM"
        }
        Head {
            x: parent.width - root.colPid + 6
            key: "pid"
            hdText: "PID"
        }
    }

    // ---- 进程榜 ----
    ListView {
        id: list
        x: 26
        y: colHead.y + colHead.height + 4
        width: root.width - 52
        height: root.height - y - 44
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.shown
            objectProp: "pid"
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool sel: root.keyboardNavigationActive && root.selectedIndex === index
            readonly property bool hot: rowArea.containsMouse
            readonly property real cpu: modelData?.cpu || 0
            width: list.width
            height: 40

            P5Plate {
                x: (row.index % 2) * 6 + 4
                width: parent.width - 14
                height: parent.height - 2
                y: 1
                skew: 16
                jitter: 1.5
                seed: 700 + (row.modelData?.pid || 0) % 97
                fillColor: row.sel ? P5.violet : (row.hot ? P5.plum : (row.index % 2 ? P5.alpha(P5.inkRaised, 0.85) : P5.alpha(P5.ink, 0.85)))
                borderWidth: row.sel ? 0 : 1
                borderColor: P5.alpha(P5.lilac, 0.35)
                slabColor: row.sel ? P5.pink : "transparent"
                slabOffset: Qt.point(5, 4)
            }
            // 编号块
            Item {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 28
                P5Plate {
                    anchors.fill: parent
                    skew: 10
                    fillColor: row.sel ? P5.ink : (row.index < 3 ? P5.violet : P5.paper)
                }
                Text {
                    anchors.centerIn: parent
                    text: String(row.index + 1).padStart(2, "0")
                    color: row.sel ? P5.violet : P5.ink
                    font.family: P5.displayFont
                    font.pixelSize: 17
                }
            }
            Text {
                x: 70
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - root.colCpu - root.colMem - root.colPid - 30
                text: row.modelData?.command || "?"
                elide: Text.ElideRight
                color: row.sel ? P5.ink : P5.paper
                font.family: P5.bodyFont
                font.pixelSize: 15
                font.weight: Font.Black
            }
            // CPU：斜切条 + 数字
            Item {
                x: parent.width - root.colPid - root.colMem - root.colCpu - 20
                anchors.verticalCenter: parent.verticalCenter
                width: root.colCpu
                height: 16
                P5Meter {
                    width: 90
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    ticks: 0
                    value: Math.min(1, row.cpu / 100)
                    level: row.cpu >= 80 ? 2 : (row.cpu >= 40 ? 1 : 0)
                    trackColor: row.sel ? P5.alpha(P5.ink, 0.3) : P5.ink
                    borderColor: row.sel ? P5.ink : P5.alpha(P5.paper, 0.6)
                }
                Text {
                    x: 98
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.cpu.toFixed(1)
                    color: row.sel ? P5.ink : P5.paper
                    font.family: P5.displayFont
                    font.pixelSize: 15
                }
            }
            Text {
                x: parent.width - root.colPid - root.colMem - 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.mem(row.modelData?.memoryKB)
                color: row.sel ? P5.ink : P5.lilac
                font.family: P5.displayFont
                font.pixelSize: 15
            }
            Text {
                x: parent.width - root.colPid + 6
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData?.pid ?? ""
                color: row.sel ? P5.velvet : P5.alpha(P5.lilac, 0.7)
                font.family: P5.labelFont
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    root.keyboardNavigationActive = true;
                    root.selectedIndex = row.index;
                    if (mouse.button === Qt.RightButton)
                        root.openMenuFor(row.index, row, mouse.x, mouse.y, false);
                }
            }
        }

        // 空状态
        P5Tag {
            anchors.centerIn: parent
            visible: root.shown.length === 0
            text: root.searchText.length > 0 ? "NO TARGET FOUND" : "SCANNING…"
            family: P5.displayFont
            italic: false
            weight: Font.Normal
            pixelSize: 22
            fillColor: P5.paper
            textColor: P5.ink
            slabColor: P5.violet
            tilt: -3
        }
    }

    // ---- 提示 ----
    Text {
        x: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        text: "↑↓ SELECT   ⏎ / RMB  ACTIONS   TAB  FILTER   ESC  CLOSE"
        color: P5.alpha(P5.lilac, 0.75)
        font.family: P5.labelFont
        font.pixelSize: 12
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }
}
