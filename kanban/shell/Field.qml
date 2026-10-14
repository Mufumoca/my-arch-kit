import QtQuick

// 极简输入框：Enter 提交，Esc 取消，多行模式下 Shift+Enter 换行
Rectangle {
    id: f

    property alias text: edit.text
    property string placeholder
    property bool multiline: false
    property int pixelSize: 13
    signal accepted
    signal cancelled

    function focusIn() {
        edit.forceActiveFocus();
        edit.cursorPosition = edit.length;
    }

    implicitHeight: edit.implicitHeight + 12
    radius: 8
    color: Theme.alpha(Theme.surface, 0.35)
    border.width: 1
    border.color: edit.activeFocus ? Theme.alpha(Theme.primary, 0.55) : Theme.alpha(Theme.text, 0.08)
    Behavior on border.color { ColorAnimation { duration: 120 } }

    TextEdit {
        id: edit
        x: 9
        y: 6
        width: f.width - 18
        wrapMode: TextEdit.Wrap
        color: Theme.text
        selectionColor: Theme.alpha(Theme.primary, 0.4)
        selectedTextColor: Theme.text
        font.family: Theme.font
        font.pixelSize: f.pixelSize
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (f.multiline && (e.modifiers & Qt.ShiftModifier)) return;
                e.accepted = true;
                f.accepted();
            } else if (e.key === Qt.Key_Escape) {
                e.accepted = true;
                f.cancelled();
            }
        }

        Text {
            visible: edit.text.length === 0 && edit.preeditText.length === 0
            text: f.placeholder
            color: Theme.alpha(Theme.textDim, 0.5)
            font: edit.font
        }
    }
}
