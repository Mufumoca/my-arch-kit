import QtQuick
import Quickshell

// 预览：qs -p ~/.config/quickshell/p5lock/demo.qml
// 不会真的锁屏；输入 "fail" 回车演示失败，其他任意内容回车演示解锁，空密码时 Esc 退出
// P5LOCK_SHOT=<dir> 时按脚本自动输入并截图（开发用）；P5LOCK_SHOT_SET=power 改为截电源菜单
// 电源菜单在预览里只打日志，不会真的关机
ShellRoot {
    id: root

    property string password: ""
    property bool busy: false
    property int failTick: 0
    property int scatterTick: 0
    property bool unlocking: false
    property real wipe: 0
    readonly property string shotDir: Quickshell.env("P5LOCK_SHOT") || ""
    readonly property var size: (Quickshell.env("P5LOCK_SIZE") || "1600x900").split("x").map(Number)

    function clear(scatter) {
        if (scatter)
            scatterTick++;
        password = "";
    }
    function submit() {
        if (!password || busy || unlocking)
            return;
        busy = true;
        fakeAuth.restart();
    }
    function relock() {
        wipe = 0;
        unlocking = false;
        password = "";
        scene.intro();
    }

    Timer {
        id: fakeAuth
        interval: 900
        onTriggered: {
            root.busy = false;
            if (root.password === "fail") {
                root.failTick++;
                root.clear(true);
            } else {
                root.unlocking = true;
            }
        }
    }

    SequentialAnimation {
        id: wipeAnim
        NumberAnimation { target: root; property: "wipe"; from: 0; to: 1; duration: 1000 }
        PauseAnimation { duration: 1200 }
        ScriptAction { script: if (!root.shotDir) root.relock() }
    }

    FloatingWindow {
        id: win
        implicitWidth: root.size[0]
        implicitHeight: root.size[1]
        title: "p5lock demo"
        color: "black"

        Item {
            id: stage
            anchors.fill: parent

            // “桌面”：未处理的壁纸
            Image {
                anchors.fill: parent
                source: {
                    const p = Theme.wallpaperFor(scene.screenName);
                    return p && !p.startsWith("#") ? "file://" + p.split("/").map(encodeURIComponent).join("/") : "";
                }
                fillMode: Image.PreserveAspectCrop
            }

            LockScene {
                id: scene
                anchors.fill: parent
                focus: true
                visible: !(root.unlocking && root.wipe > 0)
                screenName: Quickshell.env("P5LOCK_SCREEN") || "HDMI-A-1"
                password: root.password
                busy: root.busy
                failTick: root.failTick
                scatterTick: root.scatterTick
                unlocking: root.unlocking
                onTyped: t => {
                    if (!root.busy && !root.unlocking)
                        root.password += t;
                }
                onBackspace: {
                    const a = Array.from(root.password);
                    a.pop();
                    root.password = a.join("");
                }
                onClearAll: {
                    if (!root.password && !root.shotDir)
                        Qt.quit();
                    root.clear(true);
                }
                onSubmit: root.submit()
                onExpanded: wipeAnim.restart()
                onPowerAction: name => console.log("p5lock demo: power action", name)
                Component.onCompleted: intro()
            }

            StripeCover {
                anchors.fill: parent
                visible: root.unlocking && root.wipe > 0
                spread: 1
                wipe: root.wipe
            }
        }

        // 截图脚本：[延时ms, 动作]
        Timer {
            id: script
            property int step: 0
            property var steps: Quickshell.env("P5LOCK_SHOT_SET") === "power" ? powerSteps : unlockSteps
            readonly property var powerSteps: [
                [1200, "shot:p00-idle"], [0, "power:open"], [120, "shot:p01-open-a"], [180, "shot:p02-open-b"], [220, "shot:p03-open-c"],
                [500, "shot:p04-open"], [0, "power:key:1"], [300, "shot:p05-sel"], [0, "power:enter"], [250, "shot:p06-armed"],
                [0, "power:key:1"], [0, "power:key:1"], [300, "shot:p07-sel3"], [0, "power:enter"], [150, "shot:p08-closing"], [400, "shot:p09-closed"], [100, "quit"]
            ]
            readonly property var unlockSteps: [
                [120, "shot:00a-intro"], [180, "shot:00b-intro"], [300, "shot:00c-intro"], [800, "shot:01-idle"],
                [0, "type:h"], [40, "shot:02-smear-1"], [300, "type:u"], [300, "type:n"], [300, "type:t"], [60, "shot:03-smear-2"],
                [400, "type:e"], [300, "type:r"], [500, "shot:04-typed"],
                [200, "back"], [45, "shot:05-delete"], [500, "submit"], [300, "shot:06-busy"], [700, "shot:07-unlock-a"],
                [160, "shot:08-unlock-b"], [140, "shot:09-unlock-c"], [300, "shot:10-wipe-a"], [200, "shot:11-wipe-b"], [200, "shot:12-wipe-c"], [200, "shot:12d-wipe-d"],
                [600, "relock"], [1200, "type:f"], [100, "type:a"], [100, "type:i"], [100, "type:l"], [300, "submit"], [1000, "shot:13-fail-a"],
                [180, "shot:14-fail-b"], [600, "shot:15-fail-c"], [300, "quit"]
            ]
            running: root.shotDir !== ""
            interval: steps[0][0]
            onTriggered: {
                const a = steps[step][1];
                if (a.startsWith("shot:")) {
                    const name = a.slice(5);
                    stage.grabToImage(r => r.saveToFile(root.shotDir + "/" + name + ".png"));
                } else if (a.startsWith("type:")) {
                    root.password += a.slice(5);
                } else if (a === "back") {
                    scene.backspace();
                } else if (a === "submit") {
                    root.submit();
                } else if (a === "power:open") {
                    scene.togglePower();
                } else if (a.startsWith("power:key:")) {
                    scene.powerKey(a.endsWith("1") ? Qt.Key_Right : Qt.Key_Left);
                } else if (a === "power:enter") {
                    scene.powerKey(Qt.Key_Return);
                } else if (a === "relock") {
                    root.relock();
                } else if (a === "quit") {
                    Qt.quit();
                    return;
                }
                step++;
                if (step < steps.length) {
                    interval = Math.max(1, steps[step][0]);
                    restart();
                }
            }
        }
    }
}
