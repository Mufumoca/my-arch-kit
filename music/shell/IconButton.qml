import QtQuick

Rectangle {
    id: b

    property string icon
    property bool filled: false
    property color tint: Theme.textDim
    property int size: 30
    property int iconSize: 20
    property string tip: ""
    signal clicked

    width: size
    height: size
    radius: size / 2
    color: ma.containsMouse ? Theme.alpha(Theme.text, 0.1) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Icon {
        anchors.centerIn: parent
        name: b.icon
        filled: b.filled
        size: b.iconSize
        color: ma.containsMouse ? Qt.lighter(b.tint, 1.15) : b.tint
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
