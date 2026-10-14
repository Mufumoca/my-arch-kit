import QtQuick

Rectangle {
    id: b

    property string icon
    property color tint: Theme.textDim
    property int size: 22
    signal clicked

    width: label.implicitWidth > size - 8 ? label.implicitWidth + 12 : size
    height: size
    radius: size / 2
    color: ma.containsMouse ? Theme.alpha(Theme.text, 0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: label
        anchors.centerIn: parent
        text: b.icon
        color: ma.containsMouse ? Theme.text : b.tint
        font.family: Theme.font
        font.pixelSize: 13
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
