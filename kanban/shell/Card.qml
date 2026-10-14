import QtQuick

Item {
    id: card

    required property var modelData
    readonly property var task: modelData
    readonly property bool done: task.status === "done"
    property bool editing: false

    function beginEdit() {
        eTitle.text = task.title;
        eDesc.text = task.desc || "";
        editing = true;
        Qt.callLater(eTitle.focusIn);
    }
    function commit() {
        const t = eTitle.text.trim();
        if (t.length) Store.updateTask(task.id, t, eDesc.text.trim());
        editing = false;
    }

    width: parent ? parent.width : 0
    height: (editing ? editor.implicitHeight : view.implicitHeight) + 20
    opacity: Store.dragId === task.id ? 0.3 : 1
    Behavior on opacity { NumberAnimation { duration: 120 } }

    HoverHandler { id: hover }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.alpha(Theme.card, hover.hovered || card.editing ? 0.7 : 0.45)
        border.width: 1
        border.color: Theme.alpha(Theme.text, hover.hovered ? 0.12 : 0.06)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: !card.editing
        preventStealing: true
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        property point start
        property bool dragging: false

        onPressed: m => {
            start = Qt.point(m.x, m.y);
            dragging = false;
        }
        onPositionChanged: m => {
            if (!pressed) return;
            const p = mapToItem(null, m.x, m.y);
            if (!dragging && Math.hypot(m.x - start.x, m.y - start.y) > 6) {
                dragging = true;
                Store.dragStart(card.task, p.x, p.y, start.x, start.y, card.width);
            }
            if (dragging) Store.dragMove(p.x, p.y);
        }
        onReleased: {
            if (dragging) Store.dragEnd(true);
            dragging = false;
        }
        onCanceled: {
            if (dragging) Store.dragEnd(false);
            dragging = false;
        }
        onDoubleClicked: card.beginEdit()
    }

    // 展示
    Column {
        id: view
        visible: !card.editing
        x: 12
        y: 10
        width: card.width - 24
        spacing: 4

        Text {
            width: parent.width - (hover.hovered ? 48 : 0)
            text: (card.task.daily ? "↻  " : "") + card.task.title
            wrapMode: Text.Wrap
            color: card.done ? Theme.alpha(Theme.text, 0.45) : Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Medium
            font.strikeout: card.done
        }
        Text {
            visible: text.length > 0
            width: parent.width
            text: card.task.desc || ""
            wrapMode: Text.Wrap
            color: Theme.alpha(Theme.textDim, card.done ? 0.4 : 0.75)
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.15
        }
    }

    Row {
        visible: hover.hovered && !card.editing && Store.dragId === ""
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        IconButton {
            icon: "✎"
            onClicked: card.beginEdit()
        }
        IconButton {
            icon: "✕"
            tint: Theme.error
            onClicked: Store.removeTask(card.task.id)
        }
    }

    // 编辑
    Column {
        id: editor
        visible: card.editing
        x: 10
        y: 10
        width: card.width - 20
        spacing: 6
        Field {
            id: eTitle
            width: parent.width
            pixelSize: 14
            placeholder: "任务名"
            onAccepted: eDesc.focusIn()
            onCancelled: card.editing = false
        }
        Field {
            id: eDesc
            width: parent.width
            multiline: true
            pixelSize: 12
            placeholder: "描述（Shift+Enter 换行）"
            onAccepted: card.commit()
            onCancelled: card.editing = false
        }
    }
}
