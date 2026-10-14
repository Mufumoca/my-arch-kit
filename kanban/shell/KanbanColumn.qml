import QtQuick

Rectangle {
    id: col

    required property string key
    required property string label
    property color accent: Theme.textDim
    property bool adding: false
    readonly property var items: Store.tasks.filter(t => t.status === key)
    readonly property bool hot: Store.dragId !== "" && Store.dropCol === key

    // y 为本列坐标，返回插入位置（不计正在拖拽的卡片）
    function indexAt(y) {
        let i = 0;
        for (let k = 0; k < rep.count; k++) {
            const it = rep.itemAt(k);
            if (!it || it.task.id === Store.dragId) continue;
            if (y > it.mapToItem(col, 0, it.height / 2).y) i++;
        }
        return i;
    }
    function indicatorY(index) {
        const vis = [];
        for (let k = 0; k < rep.count; k++) {
            const it = rep.itemAt(k);
            if (it && it.task.id !== Store.dragId) vis.push(it);
        }
        if (vis.length === 0) return body.y + 2;
        if (index < vis.length) return vis[index].mapToItem(col, 0, 0).y - 5;
        const last = vis[vis.length - 1];
        return last.mapToItem(col, 0, last.height).y + 3;
    }
    function startAdding() {
        adding = true;
        Qt.callLater(nTitle.focusIn);
    }
    function submit() {
        const t = nTitle.text.trim();
        if (t.length) Store.addTask(t, nDesc.text.trim(), key);
        nTitle.text = "";
        nDesc.text = "";
        nTitle.focusIn();
    }

    radius: 14
    color: Theme.alpha(Theme.surface, hot ? 0.4 : 0.22)
    border.width: 1
    border.color: hot ? Theme.alpha(accent, 0.45) : Theme.alpha(Theme.text, 0.05)
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    // 列头
    Item {
        id: header
        x: 14
        width: col.width - 22
        height: 44

        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 4
            color: col.accent
        }
        Text {
            anchors.left: dot.right
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: col.label
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }
        Text {
            anchors.right: actions.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: col.items.length
            color: Theme.alpha(Theme.textDim, 0.6)
            font.family: Theme.font
            font.pixelSize: 12
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            IconButton {
                visible: col.key === "done" && col.items.length > 0
                icon: "清空"
                onClicked: Store.clearDone()
            }
            IconButton {
                icon: "+"
                onClicked: col.adding ? (col.adding = false) : col.startAdding()
            }
        }
    }

    Flickable {
        id: body
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        anchors.topMargin: 0
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: list
            width: body.width
            spacing: 8

            // 新建卡片
            Rectangle {
                visible: col.adding
                width: parent.width
                height: composer.implicitHeight + 20
                radius: 10
                color: Theme.alpha(Theme.card, 0.7)
                border.width: 1
                border.color: Theme.alpha(col.accent, 0.35)

                Column {
                    id: composer
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 6
                    Field {
                        id: nTitle
                        width: parent.width
                        pixelSize: 14
                        placeholder: "任务名，Enter 继续"
                        onAccepted: nDesc.focusIn()
                        onCancelled: col.adding = false
                    }
                    Field {
                        id: nDesc
                        width: parent.width
                        multiline: true
                        pixelSize: 12
                        placeholder: "描述（可选），Enter 添加"
                        onAccepted: col.submit()
                        onCancelled: col.adding = false
                    }
                }
            }

            Repeater {
                id: rep
                model: col.items
                delegate: Card {}
            }
        }
    }

    Text {
        visible: col.items.length === 0 && !col.adding
        anchors.centerIn: body
        text: "—"
        color: Theme.alpha(Theme.textDim, 0.25)
        font.pixelSize: 18
    }

    // 拖拽插入指示线
    Rectangle {
        visible: col.hot
        x: 14
        width: col.width - 28
        height: 2
        radius: 1
        color: col.accent
        y: col.hot ? col.indicatorY(Store.dropIndex) : 0
    }
}
