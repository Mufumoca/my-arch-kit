import QtQuick

// Material Symbols 图标（与 DMS 的 DankIcon 同样的字体与渲染参数）
Text {
    property string name
    property bool filled: false
    property int size: 20

    text: name
    color: Theme.textDim
    font.family: Theme.iconFont
    font.pixelSize: size
    font.weight: filled ? 500 : 400
    font.hintingPreference: Font.PreferNoHinting
    renderType: Text.NativeRendering
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "GRAD": -25, "opsz": 24, "wght": filled ? 500 : 400 })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
