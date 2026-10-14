import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// P5 风格锁屏：qs -n -c p5lock（由 DMS 的 customPowerActionLock 拉起，见 p5lock.sh）
// 一次性进程：启动即上锁，解锁动画播完即退出
//   1. PAM 成功 → 各屏锁屏表面把斜块铺开成满屏斜条
//   2. 同时建好 overlay 图层（上锁期间不可见），画面与铺满时完全一致
//   3. 解除 session lock → overlay 上斜条交错滑出，露出实时桌面 → 退出
ShellRoot {
    id: root

    property string password: ""
    property int failTick: 0
    property int scatterTick: 0
    property string message: ""
    property bool unlocking: false
    property bool released: false
    property real wipe: 0
    property bool capsLock: false
    readonly property bool busy: pam.active
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/p5lock.secure"

    function clear(scatter) {
        if (scatter && password)
            scatterTick++;
        password = "";
    }

    function submit() {
        if (!password || busy || unlocking)
            return;
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "p5lock"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocking = true;
                return;
            }
            // PAM 的提示语（如“密码：”）也走 message，这里只按结果给固定文案
            root.message = result === PamResult.MaxTries ? "TOO MANY TRIES" : result === PamResult.Error ? "AUTH ERROR" : "";
            root.failTick++;
            root.clear(true);
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        onSecureChanged: {
            if (secure)
                Quickshell.execDetached(["touch", root.marker]);
        }
        // 被合成器拒绝（例如已有别的锁屏）时直接退出
        onLockedChanged: {
            if (!locked && !root.released)
                Qt.quit();
        }

        WlSessionLockSurface {
            id: surface
            color: Theme.ink

            LockScene {
                id: scene
                anchors.fill: parent
                focus: true
                screenName: surface.screen?.name ?? ""
                password: root.password
                busy: root.busy
                capsLock: root.capsLock
                message: root.message
                failTick: root.failTick
                scatterTick: root.scatterTick
                unlocking: root.unlocking
                onTyped: t => {
                    if (!root.busy && !root.unlocking)
                        root.password += t;
                }
                onBackspace: {
                    if (root.busy)
                        return;
                    const a = Array.from(root.password);
                    a.pop();
                    root.password = a.join("");
                }
                onClearAll: {
                    if (!root.busy)
                        root.clear(true);
                }
                onSubmit: root.submit()
                onExpanded: root.release()
                onPowerAction: name => Quickshell.execDetached(["systemctl", name])
                Component.onCompleted: {
                    forceActiveFocus();
                    intro();
                }
            }
        }
    }

    // 多块屏幕各自播放铺开动画，以先播完的为准
    function release() {
        if (released)
            return;
        released = true;
        lock.locked = false;
        Quickshell.execDetached(["rm", "-f", root.marker]);
        wipeAnim.start();
    }

    SequentialAnimation {
        id: wipeAnim
        PauseAnimation { duration: 60 }
        NumberAnimation { target: root; property: "wipe"; from: 0; to: 1; duration: 1000 }
        ScriptAction { script: Qt.quit() }
    }

    // 兜底：铺开动画因故没回调时也要解锁
    Timer {
        running: root.unlocking && !root.released
        interval: 1500
        onTriggered: root.release()
    }

    Variants {
        model: root.unlocking ? Quickshell.screens : []

        PanelWindow {
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "p5lock-reveal"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            StripeCover {
                anchors.fill: parent
                spread: 1
                wipe: root.wipe
            }
        }
    }

    // Caps Lock：轮询 /sys/class/leds 下各键盘的指示灯
    Process {
        id: capsList
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*::capslock 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: capsFiles.model = text.split("\n").filter(l => l.length > 0)
        }
    }

    Instantiator {
        id: capsFiles
        model: []

        FileView {
            required property string modelData
            path: modelData + "/brightness"
            blockLoading: true
            printErrors: false
        }
    }

    Timer {
        running: capsFiles.count > 0 && !root.unlocking
        interval: 300
        repeat: true
        onTriggered: {
            let on = false;
            for (let i = 0; i < capsFiles.count; i++) {
                const f = capsFiles.objectAt(i);
                f.reload();
                if (f.text().trim() !== "0")
                    on = true;
            }
            root.capsLock = on;
        }
    }
}
