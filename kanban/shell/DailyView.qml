import QtQuick

// 每日任务模板：到设定时间点自动在 Todo 中刷新
Item {
    id: view

    function submit() {
        const t = dTitle.text.trim();
        if (!t.length) {
            dTitle.focusIn();
            return;
        }
        Store.addDaily(t, dDesc.text.trim(), dTimes.text);
        dTitle.text = "";
        dDesc.text = "";
        dTimes.text = "";
        dTitle.focusIn();
    }

    Text {
        id: hint
        width: parent.width
        text: "到达每个刷新时间点时，任务会重置回 Todo 顶部。多个时间用空格分隔，例如 08:00 14:00 20:00"
        wrapMode: Text.Wrap
        color: Theme.alpha(Theme.textDim, 0.6)
        font.family: Theme.font
        font.pixelSize: 12
    }

    Flickable {
        id: flick
        anchors.top: hint.bottom
        anchors.topMargin: 12
        anchors.bottom: form.top
        anchors.bottomMargin: 12
        width: parent.width
        contentHeight: rows.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: rows
            width: flick.width
            spacing: 8

            Repeater {
                model: Store.dailies
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: rows.width
                    height: Math.max(info.implicitHeight, 24) + 20
                    radius: 10
                    color: Theme.alpha(Theme.card, rh.hovered ? 0.7 : 0.45)
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.06)
                    HoverHandler { id: rh }

                    Column {
                        id: info
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - times.width - 70
                        spacing: 3
                        Text {
                            width: parent.width
                            text: "↻  " + row.modelData.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        Text {
                            visible: text.length > 0
                            width: parent.width
                            text: row.modelData.desc || ""
                            elide: Text.ElideRight
                            color: Theme.alpha(Theme.textDim, 0.75)
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }

                    Row {
                        id: times
                        anchors.right: del.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: row.modelData.times
                            delegate: Rectangle {
                                required property string modelData
                                width: tt.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: Theme.alpha(Theme.primary, 0.14)
                                Text {
                                    id: tt
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: Theme.primary
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }

                    IconButton {
                        id: del
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "✕"
                        tint: Theme.error
                        opacity: rh.hovered ? 1 : 0.35
                        onClicked: Store.removeDaily(row.modelData.id)
                    }
                }
            }
        }
    }

    Text {
        visible: Store.dailies.length === 0
        anchors.centerIn: flick
        text: "还没有每日任务"
        color: Theme.alpha(Theme.textDim, 0.3)
        font.family: Theme.font
        font.pixelSize: 13
    }

    Row {
        id: form
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 8

        Field {
            id: dTitle
            width: parent.width * 0.26
            pixelSize: 13
            placeholder: "任务名"
            onAccepted: dDesc.focusIn()
        }
        Field {
            id: dDesc
            width: parent.width - dTitle.width - dTimes.width - addBtn.width - 24
            pixelSize: 13
            placeholder: "描述（可选）"
            onAccepted: dTimes.focusIn()
        }
        Field {
            id: dTimes
            width: 170
            pixelSize: 13
            placeholder: "刷新时间 08:00 20:00"
            onAccepted: view.submit()
        }
        Rectangle {
            id: addBtn
            width: 64
            height: dTitle.height
            radius: 8
            color: Theme.alpha(Theme.primary, am.containsMouse ? 0.3 : 0.18)
            Text {
                anchors.centerIn: parent
                text: "添加"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 13
            }
            MouseArea {
                id: am
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.submit()
            }
        }
    }
}
