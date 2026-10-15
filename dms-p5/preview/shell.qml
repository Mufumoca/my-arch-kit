//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.DankCommon.Common
import qs.DankCommon.Widgets

// 预览：在背景层渲染一次 → 存 PNG → 退出，不打扰前台窗口。由 scripts/preview.sh 调用。
//   P5_PREVIEW=<场景名>  P5_OUT=<png>  P5_BG=<背景图>  P5_SCREEN=<输出名>  P5_W / P5_H  P5_DELAY
ShellRoot {
    PanelWindow {
        id: win
        screen: Quickshell.screens.find(s => s.name === Quickshell.env("P5_SCREEN")) ?? Quickshell.screens[0]
        implicitWidth: Number(Quickshell.env("P5_W") || 1100)
        implicitHeight: Number(Quickshell.env("P5_H") || 700)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "p5-preview"
        exclusiveZone: -1
        anchors.top: true
        anchors.left: true

        Rectangle {
            id: stage
            anchors.fill: parent
            color: "#7d8fa8"
            Image {
                anchors.fill: parent
                source: Quickshell.env("P5_BG") || ""
                fillMode: Image.PreserveAspectCrop
            }
            Loader {
                anchors.fill: parent
                source: Qt.resolvedUrl("scenes/" + (Quickshell.env("P5_PREVIEW") || "plate") + ".qml")
            }
        }
        Timer {
            interval: Number(Quickshell.env("P5_DELAY") || 900)
            running: true
            onTriggered: stage.grabToImage(r => {
                r.saveToFile(Quickshell.env("P5_OUT") || "/tmp/p5shots/preview.png");
                Qt.quit();
            })
        }
    }
}
