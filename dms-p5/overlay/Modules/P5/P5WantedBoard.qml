pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Modals.Clipboard
import qs.Services
import qs.Widgets

// 剪贴板 = 通缉榜：每条记录是一张通缉令（顶上黑色通缉条 + 中间“画像” + 底下赏金），钉在墙上、各自歪一点。
// 焦点所在的那张，通缉条上插着一把飞刀；换焦点时飞刀重新掷出去。
// 接口与原 ClipboardContent 一致，可直接替换（弹出面板与 Mod+Alt+V 模态框共用）。
Item {
    id: root

    required property var modal
    property var transientSurfaceTracker: null

    property alias searchField: search
    readonly property bool contextMenuActive: contextMenu.renderActive

    readonly property var entries: modal.activeTab === "saved" ? modal.pinnedEntries : modal.unpinnedEntries
    readonly property int columns: Math.max(2, Math.floor((width - 24) / 216))
    readonly property var filterValues: ["all", "text", "long_text", "image"]
    readonly property var filterLabels: ["ALL", "TEXT", "LONG", "IMAGE"]

    // 图片缩略图缓存：id → base64
    property var imageCache: ({})

    function closeFilterMenu() {
    }
    function closeContextMenu() {
        contextMenu.hide();
    }
    function showContextMenu(entry, sceneX, sceneY) {
        const p = mapFromItem(null, sceneX, sceneY);
        contextMenu.show(p.x, p.y, entry);
    }
    function contextEntryAtScreen(screenX, screenY) {
        const host = modal.surfaceHost ?? null;
        const hostX = host?.alignedX;
        const hostY = host?.renderedAlignedY ?? host?.alignedY;
        if (isNaN(hostX) || isNaN(hostY))
            return null;
        const lx = screenX - hostX, ly = screenY - hostY;
        const gp = mapToItem(grid, lx, ly);
        const i = grid.indexAt(gp.x + grid.contentX, gp.y + grid.contentY);
        if (i < 0 || i >= entries.length)
            return null;
        return {
            "entry": entries[i],
            "x": lx,
            "y": ly
        };
    }

    function select(i) {
        if (entries.length === 0)
            return;
        ClipboardService.keyboardNavigationActive = true;
        ClipboardService.selectedIndex = Math.max(0, Math.min(entries.length - 1, i));
    }
    function relTime(ts) {
        const t = Date.parse(ts);
        if (isNaN(t))
            return "";
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60)
            return "刚刚";
        if (s < 3600)
            return Math.floor(s / 60) + " 分钟前";
        if (s < 86400)
            return Math.floor(s / 3600) + " 小时前";
        return Math.floor(s / 86400) + " 天前";
    }

    ClipboardContextMenu {
        id: contextMenu
        modal: root.modal
        parentHandler: root
        transientSurfaceTracker: root.transientSurfaceTracker
    }

    // ---- 墙面 ----
    P5Plate {
        anchors.fill: parent
        anchors.margins: 6
        seed: 512
        jitter: 4
        cutTopLeft: 20
        cutBottomRight: 20
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
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        text: "WANTED"
        color: P5.alpha(P5.violet, 0.07)
        font.family: P5.displayFont
        font.pixelSize: 120
        rotation: -8
    }

    // ---- 头部：标题 / 标签页 / 操作 ----
    Item {
        id: header
        x: 22
        y: 18
        width: parent.width - 44
        height: 40

        P5Ransom {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            text: "WANTED"
            pixelSize: 22
            seed: 9
        }

        Row {
            anchors.left: title.right
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: [["recents", "RECENT", root.modal.unpinnedEntries.length], ["saved", "SAVED", root.modal.pinnedEntries.length]]

                Item {
                    id: tab
                    required property var modelData
                    readonly property bool on: root.modal.activeTab === modelData[0]
                    width: tabTag.width
                    height: tabTag.height

                    P5Tag {
                        id: tabTag
                        text: tab.modelData[1] + "  " + tab.modelData[2]
                        pixelSize: 14
                        fillColor: tab.on ? P5.violet : (tabArea.containsMouse ? P5.plumRaised : P5.ink)
                        textColor: tab.on ? P5.ink : P5.paper
                        borderWidth: tab.on ? 0 : 1.5
                        borderColor: P5.paper
                        slabColor: tab.on ? P5.paper : "transparent"
                        tilt: tab.on ? -3 : 0
                    }
                    MouseArea {
                        id: tabArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.modal.activeTab = tab.modelData[0]
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 类型筛选：点一下换下一种
            Item {
                width: filterTag.width
                height: filterTag.height
                anchors.verticalCenter: parent.verticalCenter
                P5Tag {
                    id: filterTag
                    readonly property int fi: Math.max(0, root.filterValues.indexOf(root.modal.activeFilter))
                    text: "TYPE · " + root.filterLabels[fi]
                    pixelSize: 12
                    fillColor: fi > 0 ? P5.pink : P5.ink
                    textColor: fi > 0 ? P5.ink : P5.lilac
                    borderWidth: 1.5
                    borderColor: fi > 0 ? P5.paper : P5.lilac
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modal.activeFilter = root.filterValues[(filterTag.fi + 1) % root.filterValues.length]
                }
            }

            Repeater {
                model: [["delete_sweep", "clear"], ["close", "close"]]

                Item {
                    id: act
                    required property var modelData
                    width: 34
                    height: 28
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    P5Plate {
                        anchors.fill: parent
                        skew: 9
                        fillColor: actArea.pressed ? P5.blood : (actArea.containsMouse ? P5.violet : P5.ink)
                        borderWidth: 1.5
                        borderColor: P5.paper
                    }
                    DankIcon {
                        anchors.centerIn: parent
                        name: act.modelData[0]
                        size: 17
                        color: actArea.containsMouse ? P5.ink : P5.paper
                    }
                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: act.modelData[1] === "clear" ? root.modal.confirmClearAll() : root.modal.hide()
                    }
                }
            }
        }
    }

    // ---- 搜索条 ----
    Item {
        id: searchStrip
        x: 22
        y: header.y + header.height + 10
        width: parent.width - 44
        height: 38

        P5Plate {
            anchors.fill: parent
            seed: 513
            jitter: 2
            skew: 16
            fillColor: P5.paper
            slabColor: P5.ink
            slabOffset: Qt.point(4, 4)
        }
        DankIcon {
            id: searchIcon
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 20
            color: P5.ink
        }
        Item {
            id: search

            property alias text: input.text
            function setFocus(on) {
                input.focus = on;
            }
            function forceActiveFocus() {
                input.forceActiveFocus();
            }

            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: countLabel.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 26

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: "搜索通缉对象…"
                color: P5.alpha(P5.ink, 0.45)
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: P5.ink
                selectionColor: P5.violet
                selectedTextColor: P5.ink
                font.pixelSize: 16
                font.weight: Font.Bold
                font.family: P5.bodyFont
                focus: true
                clip: true

                onTextChanged: {
                    root.modal.searchText = text;
                    root.modal.updateFilteredModel();
                    ClipboardService.selectedIndex = 0;
                    ClipboardService.keyboardNavigationActive = true;
                    Qt.callLater(() => grid.positionViewAtBeginning());
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    switch (event.key) {
                    case Qt.Key_Left:
                        if (input.text.length > 0 && !ctrl)
                            return;
                        root.select(ClipboardService.selectedIndex - 1);
                        event.accepted = true;
                        return;
                    case Qt.Key_Right:
                        if (input.text.length > 0 && !ctrl)
                            return;
                        root.select(ClipboardService.selectedIndex + 1);
                        event.accepted = true;
                        return;
                    case Qt.Key_Up:
                        root.select(ClipboardService.selectedIndex - root.columns);
                        event.accepted = true;
                        return;
                    case Qt.Key_Down:
                        root.select(ClipboardService.selectedIndex + root.columns);
                        event.accepted = true;
                        return;
                    case Qt.Key_Delete:
                        if (input.text.length > 0 && !(event.modifiers & Qt.ShiftModifier))
                            return;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Escape:
                    case Qt.Key_Tab:
                    case Qt.Key_Backtab:
                    case Qt.Key_F10:
                        break;
                    default:
                        if (!ctrl)
                            return;
                    }
                    root.modal.keyboardController.handleKey(event);
                }
            }
        }
        Text {
            id: countLabel
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: root.entries.length + " TARGETS"
            color: P5.plum
            font.family: P5.displayFont
            font.pixelSize: 16
        }
    }

    // ---- 通缉令 ----
    GridView {
        id: grid
        x: 16
        // 往上多留一截：飞刀的刀柄会翘出第一排通缉令
        y: searchStrip.y + searchStrip.height - 30
        topMargin: 36
        width: parent.width - 32
        height: parent.height - y - 16
        clip: true
        cellWidth: Math.floor(width / root.columns)
        cellHeight: 278
        cacheBuffer: 300
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.entries
            objectProp: "id"
        }
        currentIndex: ClipboardService.selectedIndex
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

        delegate: Item {
            id: poster
            required property var modelData
            required property int index

            readonly property var entry: modelData
            readonly property bool isSel: ClipboardService.keyboardNavigationActive && index === ClipboardService.selectedIndex
            readonly property bool isImage: entry.isImage === true || entry.isImage === "true"
            readonly property bool pinned: entry.pinned === true || (!entry.pinned && ClipboardService.getPinnedEntryByHash(entry.hash) !== null)
            readonly property int seed: Number(entry.id) || index
            readonly property real tilt: P5.rand(seed, 1) * 3.2
            property string imageData: ""

            width: grid.cellWidth
            height: grid.cellHeight
            z: isSel ? 10 : (hover.hovered ? 5 : 1)

            function loadImage() {
                if (!isImage || imageData)
                    return;
                const cached = root.imageCache[entry.id];
                if (cached) {
                    imageData = cached;
                    return;
                }
                const id = entry.id;
                DMSService.sendRequest("clipboard.getEntry", {
                    "id": id
                }, response => {
                    const data = response?.result?.data;
                    if (!data)
                        return;
                    root.imageCache[id] = data;
                    if (poster.entry && poster.entry.id === id)
                        poster.imageData = data;
                });
            }
            Component.onCompleted: loadImage()
            onEntryChanged: {
                imageData = "";
                loadImage();
            }

            HoverHandler {
                id: hover
            }

            Item {
                id: sheet
                anchors.fill: parent
                anchors.margins: 12
                anchors.topMargin: 18
                rotation: poster.isSel ? -poster.tilt * 0.3 : poster.tilt
                scale: poster.isSel ? 1.05 : (hover.hovered ? 1.02 : 1)

                Behavior on rotation {
                    enabled: P5.motionEnabled
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: P5.punchCurve
                    }
                }
                Behavior on scale {
                    enabled: P5.motionEnabled
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: P5.punchCurve
                    }
                }

                // 被飞刀击中时抖一下
                transform: Translate {
                    id: shake
                }
                SequentialAnimation {
                    id: thunk
                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: -5
                        duration: 40
                    }
                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: 3
                        duration: 50
                    }
                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: 0
                        duration: 80
                    }
                }

                // 纸
                P5Plate {
                    anchors.fill: parent
                    seed: poster.seed
                    jitter: 3
                    fillColor: "#F7F3EC"
                    borderWidth: 2
                    borderColor: P5.ink
                    slabColor: poster.isSel ? P5.violet : P5.alpha(P5.ink, 0.85)
                    slabOffset: poster.isSel ? Qt.point(8, 8) : Qt.point(5, 6)
                    slabRotation: P5.rand(poster.seed, 2) * 2
                    slab2Color: poster.isSel ? P5.pink : "transparent"
                    slab2Offset: Qt.point(-7, 9)
                    slab2Rotation: -2
                }

                // 图钉
                Rectangle {
                    x: parent.width / 2 - 6
                    y: -4
                    width: 12
                    height: 12
                    radius: 6
                    color: poster.isSel ? P5.violet : P5.plum
                    border.width: 2
                    border.color: P5.ink
                }

                // 通缉条
                Item {
                    id: banner
                    x: -6
                    y: 12
                    width: parent.width + 12
                    height: 40
                    rotation: -2.5

                    P5Plate {
                        anchors.fill: parent
                        seed: poster.seed + 3
                        jitter: 2
                        skew: 14
                        fillColor: P5.ink
                        borderWidth: poster.isSel ? 2.5 : 0
                        borderColor: P5.violet
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "WANTED"
                        color: P5.paper
                        font.family: P5.displayFont
                        font.pixelSize: 28
                        font.letterSpacing: 3
                    }
                }

                Text {
                    x: 10
                    y: banner.y + banner.height + 4
                    text: "No." + (poster.index + 1)
                    color: P5.alpha(P5.ink, 0.6)
                    font.family: P5.labelFont
                    font.pixelSize: 11
                    font.italic: true
                    font.weight: Font.Bold
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: banner.y + banner.height + 4
                    text: poster.isImage ? "IMAGE" : (poster.entry.size > 200 ? "LONG TEXT" : "TEXT")
                    color: P5.alpha(P5.ink, 0.6)
                    font.family: P5.labelFont
                    font.pixelSize: 11
                    font.italic: true
                    font.weight: Font.Bold
                }

                // 画像
                Rectangle {
                    id: mug
                    x: 12
                    y: banner.y + banner.height + 20
                    width: parent.width - 24
                    height: parent.height - y - 52
                    color: poster.isImage ? P5.ink : "#ECE6DB"
                    border.width: 2
                    border.color: P5.ink
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        visible: poster.isImage
                        source: poster.imageData ? "data:image/png;base64," + poster.imageData : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 300
                    }
                    DankIcon {
                        anchors.centerIn: parent
                        visible: poster.isImage && !poster.imageData
                        name: "image"
                        size: 34
                        color: P5.lilac
                    }
                    Text {
                        x: 4
                        y: -16
                        visible: !poster.isImage
                        text: "“"
                        color: P5.alpha(P5.violet, 0.5)
                        font.family: P5.displayFont
                        font.pixelSize: 72
                    }
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.topMargin: 10
                        visible: !poster.isImage
                        text: (poster.entry.preview || "").replace(/\s+/g, " ").trim()
                        color: P5.ink
                        wrapMode: Text.WrapAnywhere
                        elide: Text.ElideRight
                        maximumLineCount: Math.max(1, Math.floor((mug.height - 18) / 18))
                        lineHeight: 1.05
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                }

                // 赏金
                Row {
                    x: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    spacing: 6

                    P5Tag {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REWARD"
                        pixelSize: 10
                        fillColor: P5.ink
                        textColor: P5.paper
                        jitter: 1
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "¥" + Number(poster.entry.size || 0).toLocaleString(Qt.locale("en_US"), "f", 0)
                        color: P5.ink
                        font.family: P5.displayFont
                        font.pixelSize: 19
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 17
                    text: root.relTime(poster.entry.timestamp)
                    color: P5.alpha(P5.ink, 0.65)
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    visible: !hover.hovered
                }

                // 已收藏：淡紫印章
                Item {
                    visible: poster.pinned
                    x: parent.width - 86
                    y: mug.y + mug.height - 30
                    width: 78
                    height: 30
                    rotation: -14

                    Rectangle {
                        anchors.fill: parent
                        color: P5.alpha(P5.violet, 0.85)
                        border.width: 2.5
                        border.color: P5.ink
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "SAVED"
                        color: P5.ink
                        font.family: P5.displayFont
                        font.pixelSize: 17
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            const p = mapToItem(null, mouse.x, mouse.y);
                            root.showContextMenu(poster.entry, p.x, p.y);
                            return;
                        }
                        root.select(poster.index);
                        if (mouse.modifiers & Qt.ShiftModifier)
                            root.modal.pasteEntry(poster.entry);
                        else
                            root.modal.copyEntry(poster.entry);
                    }
                }

                // 悬停：右下角的小操作钮
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    spacing: 4
                    visible: hover.hovered

                    Repeater {
                        model: {
                            const out = [[poster.pinned ? "keep_off" : "push_pin", "pin"]];
                            if (ClipboardService.canEditEntry(poster.entry))
                                out.push(["edit", "edit"]);
                            out.push(["delete", "delete"]);
                            return out;
                        }

                        Item {
                            id: mini
                            required property var modelData
                            width: 26
                            height: 24

                            P5Plate {
                                anchors.fill: parent
                                skew: 6
                                fillColor: miniArea.pressed ? P5.blood : (miniArea.containsMouse ? P5.violet : P5.ink)
                            }
                            DankIcon {
                                anchors.centerIn: parent
                                name: mini.modelData[0]
                                size: 15
                                color: miniArea.containsMouse ? P5.ink : P5.paper
                            }
                            MouseArea {
                                id: miniArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const e = poster.entry;
                                    switch (mini.modelData[1]) {
                                    case "pin":
                                        if (e.pinned)
                                            root.modal.unpinEntry(e);
                                        else if (poster.pinned)
                                            root.modal.unpinEntry(ClipboardService.getPinnedEntryByHash(e.hash));
                                        else
                                            root.modal.pinEntry(e);
                                        break;
                                    case "edit":
                                        root.modal.editEntry(e);
                                        break;
                                    case "delete":
                                        if (root.modal.activeTab === "saved")
                                            root.modal.deletePinnedEntry(e);
                                        else
                                            root.modal.deleteEntry(e);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }

                // 飞刀：插在通缉条右上方，刀柄朝右上翘出纸外
                P5Knife {
                    id: knife
                    visible: poster.isSel
                    x: parent.width - 58
                    y: banner.y + 8
                    angle: -48
                    scale: 1.35
                }
            }

            onIsSelChanged: {
                if (isSel && P5.motionEnabled) {
                    knife.throwIn();
                    thunk.restart();
                }
            }
        }
    }

    // 空墙
    Column {
        anchors.centerIn: grid
        visible: root.entries.length === 0
        spacing: 10
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NO TARGETS"
            color: P5.paper
            font.family: P5.displayFont
            font.pixelSize: 46
            rotation: -4
        }
        P5Tag {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.modal.clipboardAvailable ? "通缉榜上空空如也" : "正在连接剪贴板服务…"
            family: P5.bodyFont
            italic: false
            pixelSize: 13
            fillColor: P5.violet
            textColor: P5.ink
        }
    }
}
