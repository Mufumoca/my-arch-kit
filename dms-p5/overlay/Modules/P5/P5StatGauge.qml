pragma ComponentBehavior: Bound

import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Widgets

// 栏上的性能读数：图标 + Anton 大数字 + 一排歪斜的历史小柱（最新一根用当前等级色，越旧越淡）。
// 等级：0 淡紫，1 粉，2 血红（紧急状态才用红）。
Item {
    id: root

    property string icon: "memory"
    property real value: 0              // 0..100
    property string text: ""            // 为空时显示 value%
    property string reserveText: "100%"
    property var history: []
    property real warn: 60
    property real danger: 85
    property real iconSize: 18
    property real fontSize: 15
    property int bars: 7

    readonly property int level: value >= danger ? 2 : (value >= warn ? 1 : 0)
    readonly property color levelColor: level === 2 ? P5.blood : (level === 1 ? P5.pink : P5.violet)
    readonly property var samples: {
        root.value;
        const h = root.history || [];
        const out = h.slice(-root.bars);
        while (out.length < root.bars)
            out.unshift(0);
        return out;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(iconSize, fontSize * 1.3)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: root.iconSize
            color: root.level > 0 ? root.levelColor : Theme.widgetIconColor
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(num.implicitWidth, reserve.implicitWidth)
            height: num.implicitHeight

            Text {
                id: reserve
                visible: false
                text: root.reserveText
                font: num.font
            }
            Text {
                id: num
                anchors.right: parent.right
                text: root.text || ((root.value > 0 ? Math.round(root.value) : "--") + "%")
                color: root.level === 2 ? P5.blood : Theme.widgetTextColor
                font.family: P5.displayFont
                font.pixelSize: root.fontSize
                font.letterSpacing: 0.5
            }
        }

        // 历史小柱：斜切的细条，从底部长上来
        Item {
            id: spark
            anchors.verticalCenter: parent.verticalCenter
            width: root.bars * 4 + 4
            height: root.iconSize

            Repeater {
                model: root.bars
                Rectangle {
                    id: bar
                    required property int index
                    readonly property real v: Math.max(0, Math.min(100, root.samples[index] || 0)) / 100
                    readonly property bool last: index === root.bars - 1
                    x: index * 4 + 2
                    width: 2.5
                    height: 3 + (spark.height - 3) * Math.sqrt(v)
                    y: spark.height - height
                    color: last ? root.levelColor : P5.alpha(P5.lilac, 0.25 + 0.6 * index / root.bars)
                    antialiasing: true
                    transform: Shear {
                        xFactor: -0.25
                        origin.y: bar.height
                    }
                    Behavior on height {
                        enabled: P5.motionEnabled
                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
