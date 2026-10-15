import QtQuick
import Quickshell
import Quickshell.Wayland

// 截取某个输出（不碰剪贴板、不切焦点）。由 scripts/grab.sh 调用。
//   P5_SCREEN=<输出名>  P5_OUT=<png>
ShellRoot {
    PanelWindow {
        id: win
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "p5-grab"
        exclusiveZone: -1
        anchors.top: true
        anchors.left: true
        mask: Region {}
        ScreencopyView {
            id: view
            captureSource: Quickshell.screens.find(s => s.name === Quickshell.env("P5_SCREEN")) ?? Quickshell.screens[0]
            width: sourceSize.width
            height: sourceSize.height
            live: false
            opacity: 0.001
            onHasContentChanged: if (hasContent) Qt.callLater(() => view.grabToImage(r => {
                r.saveToFile(Quickshell.env("P5_OUT") || "/tmp/p5shots/grab.png");
                Qt.quit();
            }))
        }
    }
}
