import QtQuick
import Quickshell
import Quickshell.Io

// 单块屏幕上的锁屏画面。所有前景元素放在沿“左下→右上”对角线旋转的坐标系 axis 中，
// 因此天然与斜块平行：axis 的 y<0 是左上半区（用户名），y>0 是右下半区（时间）
FocusScope {
    id: root

    property string screenName: ""
    property string password: ""
    property bool busy: false
    property bool capsLock: false
    property string message: ""
    property int failTick: 0
    property int scatterTick: 0
    property bool unlocking: false

    signal typed(string text)
    signal backspace
    signal clearAll
    signal submit
    signal expanded
    signal powerAction(string name)

    readonly property real diag: Math.hypot(width, height)
    readonly property real angle: Math.atan2(height, width) * 180 / Math.PI
    readonly property real alt: width * height / Math.max(1, diag)
    // 非对角线两角在 axis 上的横坐标绝对值
    readonly property real cornerX: (width * width - height * height) / (2 * Math.max(1, diag))
    readonly property real u: Math.min(width, height) / 1000
    readonly property real bandH: Theme.bandFor(width, height)
    readonly property real len: diag + 400 * u

    property real introBand: 0
    property real introShadow: 0
    property real introSide: 0
    property real kick: 0
    property real shake: 0
    property real flash: 0
    property real stamp: 0
    property real fadeOut: 0

    function intro() {
        unlockAnim.stop();
        fadeOut = 0;
        cover.spread = 0;
        power.reset();
        introAnim.restart();
        uname.play();
    }

    // 截图脚本用
    function togglePower() {
        power.toggle();
    }
    function powerKey(key) {
        if (key === Qt.Key_Return)
            power.trigger(power.sel);
        else
            power.move(key === Qt.Key_Left ? -1 : 1);
    }

    onFailTickChanged: failAnim.restart()
    onScatterTickChanged: row.scatter = true
    onUnlockingChanged: if (unlocking) unlockAnim.restart()

    property int lastLen: 0
    onPasswordChanged: {
        const n = Array.from(password).length;
        if (n !== lastLen && n > 0) {
            kickAnim.stop();
            kick = (n > lastLen ? 1 : -1) * 10 * u;
            kickAnim.start();
        }
        lastLen = n;
    }

    Keys.onPressed: event => {
        if (root.unlocking) {
            event.accepted = true;
            return;
        }
        if (power.open) {
            if (event.key === Qt.Key_Escape) {
                power.close();
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                power.move(event.key === Qt.Key_Left ? -1 : 1);
                event.accepted = true;
                return;
            }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && power.sel >= 0) {
                power.trigger(power.sel);
                event.accepted = true;
                return;
            }
        }
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.submit();
        } else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_U) || (ctrl && event.key === Qt.Key_Backspace)) {
            root.clearAll();
        } else if (event.key === Qt.Key_Backspace) {
            root.backspace();
        } else if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.typed(event.text);
        } else {
            return;
        }
        event.accepted = true;
    }

    SequentialAnimation {
        id: introAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "introBand"; from: 0; to: 1; duration: 520; easing.type: Easing.OutExpo }
            SequentialAnimation {
                PauseAnimation { duration: 70 }
                NumberAnimation { target: root; property: "introShadow"; from: 0; to: 1; duration: 560; easing.type: Easing.OutExpo }
            }
            SequentialAnimation {
                PauseAnimation { duration: 260 }
                NumberAnimation { target: root; property: "introSide"; from: 0; to: 1; duration: 620; easing.type: Easing.OutQuart }
            }
        }
    }

    SequentialAnimation {
        id: kickAnim
        NumberAnimation { target: root; property: "kick"; to: 0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }

    SequentialAnimation {
        id: failAnim
        ScriptAction { script: { root.flash = 1; root.stamp = 0; } }
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "shake"; to: 26 * root.u; duration: 45 }
                NumberAnimation { target: root; property: "shake"; to: -22 * root.u; duration: 70 }
                NumberAnimation { target: root; property: "shake"; to: 14 * root.u; duration: 70 }
                NumberAnimation { target: root; property: "shake"; to: -7 * root.u; duration: 70 }
                NumberAnimation { target: root; property: "shake"; to: 0; duration: 90 }
            }
            NumberAnimation { target: root; property: "stamp"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            NumberAnimation { target: root; property: "flash"; from: 1; to: 0; duration: 900; easing.type: Easing.InQuad }
        }
        PauseAnimation { duration: 1400 }
        NumberAnimation { target: root; property: "stamp"; to: 0; duration: 220; easing.type: Easing.InQuad }
    }

    SequentialAnimation {
        id: unlockAnim
        NumberAnimation { target: root; property: "fadeOut"; from: 0; to: 1; duration: 170; easing.type: Easing.InQuad }
        NumberAnimation { target: cover; property: "spread"; from: 0; to: 1; duration: 480; easing.type: Easing.OutQuart }
        PauseAnimation { duration: 40 }
        ScriptAction { script: root.expanded() }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
    }

    function period(h) {
        if (h < 5) return "LATE NIGHT";
        if (h < 8) return "EARLY MORNING";
        if (h < 12) return "MORNING";
        if (h < 14) return "LUNCHTIME";
        if (h < 17) return "AFTERNOON";
        if (h < 19) return "AFTER SCHOOL";
        if (h < 23) return "EVENING";
        return "LATE NIGHT";
    }

    // ───────────── 背景 ─────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.ink
    }

    // 低分辨率解码再放大 = 廉价且稳定的模糊；再叠墨色与深紫压暗
    Image {
        id: wall
        readonly property string path: Theme.wallpaperFor(root.screenName)
        anchors.fill: parent
        source: path && !path.startsWith("#") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 160
        smooth: true
        asynchronous: false
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.ink, 0.8)
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.deep, 0.22)
    }

    // ───────────── 旋转坐标系 ─────────────
    Item {
        id: axis
        x: root.width / 2 + root.shake * Math.cos(root.angle * Math.PI / 180)
        y: root.height / 2 - root.shake * Math.sin(root.angle * Math.PI / 180)
        rotation: -root.angle

        // 远景滚动的描边大字
        Repeater {
            model: [
                { y: -root.alt * 0.78, txt: "TAKE YOUR TIME ◆ ", dir: -1 },
                { y: root.alt * 0.62, txt: "LOCKED ◆ STAY HIDDEN ◆ ", dir: 1 }
            ]

            Item {
                id: lane
                required property var modelData
                y: modelData.y
                x: -root.len / 2
                opacity: 0.045 * root.introSide * (1 - root.fadeOut)

                Text {
                    id: marquee
                    property real off: 0
                    x: lane.modelData.dir < 0 ? -off : off - width / 2
                    y: -height / 2
                    text: lane.modelData.txt.repeat(Math.ceil(root.len * 2 / Math.max(1, 210 * root.u * lane.modelData.txt.length * 0.6)) + 2)
                    color: "transparent"
                    style: Text.Outline
                    styleColor: Theme.primary
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 210 * root.u

                    NumberAnimation on off {
                        from: 0
                        to: marquee.width / 2
                        duration: 160000
                        loops: Animation.Infinite
                    }
                }
            }
        }

        // 斜块两侧的半调网点
        Repeater {
            model: [-1, 1]

            Canvas {
                id: dots
                required property int modelData
                readonly property real h: 300 * root.u
                x: -root.len / 2
                y: modelData < 0 ? -root.bandH / 2 - 30 * root.u - h : root.bandH / 2 + 30 * root.u
                width: root.len
                height: h
                opacity: 0.32 * root.introSide * (1 - root.fadeOut)
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.primary;
                    const sp = 13 * root.u;
                    const maxR = sp * 0.48;
                    for (let y = sp / 2; y < height; y += sp) {
                        // 离斜块越远点越小
                        const d = modelData < 0 ? (height - y) / height : y / height;
                        const fall = Math.pow(1 - d, 1.6);
                        const row = Math.round(y / sp);
                        for (let x = (row % 2) * sp / 2; x < width; x += sp) {
                            const patch = 0.5 + 0.5 * Math.sin(x * 0.0021 / root.u + modelData * 1.7) * Math.cos(x * 0.0007 / root.u);
                            const r = maxR * fall * patch;
                            if (r < 0.6)
                                continue;
                            ctx.beginPath();
                            ctx.arc(x, y, r, 0, Math.PI * 2);
                            ctx.fill();
                        }
                    }
                }
            }
        }

        // ── 斜块：墨色底块 / 深紫细条 / 白线 / 主块 ──
        Rectangle {
            x: -root.len / 2
            y: -root.bandH / 2 - 18 * root.u
            width: root.len
            height: root.bandH + 50 * root.u
            rotation: 1.3
            color: Theme.ink
            antialiasing: true
            transform: Scale { xScale: root.introShadow }
        }
        Rectangle {
            x: -root.len / 2
            y: -root.bandH / 2 - 46 * root.u
            width: root.len
            height: 15 * root.u
            rotation: -0.9
            color: Theme.deep
            antialiasing: true
            transform: Scale { xScale: root.introShadow }
        }
        Rectangle {
            x: -root.len / 2
            y: root.bandH / 2 + 38 * root.u
            width: root.len
            height: 5 * root.u
            rotation: 0.55
            color: Theme.paper
            antialiasing: true
            transform: Scale { origin.x: root.len; xScale: root.introShadow }
        }

        Item {
            id: band
            x: root.kick
            transform: Scale { origin.x: -root.len / 2; xScale: root.introBand }

            Rectangle {
                x: -root.len / 2
                y: -root.bandH / 2
                width: root.len
                height: root.bandH
                antialiasing: true
                color: Theme.mix(Theme.primary, Theme.danger, root.flash * 0.85)
            }
            // 斜块内底部的细墨线
            Rectangle {
                x: -root.len / 2
                y: root.bandH / 2 - 16 * root.u
                width: root.len
                height: 3 * root.u
                color: Theme.ink
                opacity: 0.35
            }

            // 左侧标签
            Row {
                x: -root.diag * 0.27
                y: -root.bandH / 2 + 14 * root.u
                spacing: 10 * root.u
                opacity: 1 - root.fadeOut

                Rectangle {
                    width: 14 * root.u
                    height: 22 * root.u
                    color: Theme.ink
                    antialiasing: true
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                }
                Text {
                    text: "PASSWORD"
                    color: Theme.ink
                    font.family: Theme.narrow
                    font.bold: true
                    font.pixelSize: 24 * root.u
                    font.letterSpacing: 5 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 右侧状态：平时不显示，只在验证 / 失败 / 大写锁定时出现
            Rectangle {
                readonly property string label: root.busy ? "VERIFYING" : root.flash > 0.02 || root.stamp > 0 ? "DENIED" : root.capsLock ? "CAPS LOCK" : ""
                readonly property bool loud: root.capsLock || label === "DENIED"
                x: root.diag * 0.27 - width
                y: root.bandH / 2 - 26 * root.u - height
                width: statusText.implicitWidth + 24 * root.u
                height: statusText.implicitHeight + 6 * root.u
                color: loud ? Theme.ink : "transparent"
                visible: label !== ""
                opacity: 1 - root.fadeOut
                antialiasing: true
                rotation: loud ? -3 : 0

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: parent.label
                    color: parent.loud ? (parent.label === "DENIED" ? Theme.danger : Theme.paper) : Theme.ink
                    font.family: Theme.narrow
                    font.bold: true
                    font.pixelSize: 24 * root.u
                    font.letterSpacing: 5 * root.u
                }
            }

            PasswordRow {
                id: row
                length: Array.from(root.password).length
                busy: root.busy
                unit: root.bandH * 0.5
                opacity: 1 - root.fadeOut
                scale: 1 + root.fadeOut * 0.25
            }
        }

        // ── 左上：用户名 ──
        Item {
            id: userBlock
            readonly property real baseX: -root.cornerX * 0.62 - width / 2
            x: baseX - (1 - root.introSide) * 120 * root.u - root.fadeOut * 200 * root.u
            y: -root.bandH / 2 - 150 * root.u - height
            width: uname.implicitWidth
            height: uname.implicitHeight + tag.height + 14 * root.u
            opacity: 1 - root.fadeOut

            Row {
                id: tag
                spacing: 12 * root.u
                opacity: root.introSide

                Rectangle {
                    width: hostText.implicitWidth + 22 * root.u
                    height: hostText.implicitHeight + 4 * root.u
                    color: Theme.deep
                    rotation: -4
                    antialiasing: true

                    Text {
                        id: hostText
                        anchors.centerIn: parent
                        text: "◆ " + (hostFile.text().trim() || "localhost").toUpperCase()
                        color: Theme.primary
                        font.family: Theme.narrow
                        font.bold: true
                        font.pixelSize: 26 * root.u
                        font.letterSpacing: 3 * root.u
                    }
                }
                Text {
                    text: "WELCOME BACK,"
                    color: Theme.paper
                    style: Text.Outline
                    styleColor: Theme.ink
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 30 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            RansomText {
                id: uname
                y: tag.height + 14 * root.u
                text: (Quickshell.env("USER") || "user").toUpperCase()
                size: 150 * root.u
                seed: 11
            }
        }

        // ── 右下：时间与日期 ──
        Item {
            id: clockBlock
            readonly property real baseX: root.cornerX * 0.62 - width / 2
            x: baseX + (1 - root.introSide) * 160 * root.u + root.fadeOut * 200 * root.u
            y: root.bandH / 2 + 110 * root.u
            width: Math.max(timeText.implicitWidth, dateRow.x + dateRow.width)
            height: dateRow.y + dateRow.height
            // 电源信封拉出时让位
            opacity: root.introSide * (1 - root.fadeOut) * (1 - power.stretch * 0.82)

            readonly property string hm: Qt.formatTime(clock.date, "HH:mm")

            Text {
                x: 16 * root.u
                y: 14 * root.u
                text: clockBlock.hm
                color: Theme.deep
                font: timeText.font
            }
            Text {
                x: 7 * root.u
                y: 7 * root.u
                text: clockBlock.hm
                color: Theme.ink
                font: timeText.font
            }
            Text {
                id: timeText
                text: clockBlock.hm
                color: Theme.paper
                font.family: Theme.display
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 190 * root.u
                lineHeight: 0.82
            }

            Row {
                id: dateRow
                x: timeText.implicitWidth * 0.22
                y: timeText.height + 6 * root.u
                spacing: 14 * root.u

                Text {
                    id: dateText
                    text: Qt.formatDate(clock.date, "MM/dd")
                    color: Theme.paper
                    style: Text.Outline
                    styleColor: Theme.ink
                    font.family: Theme.narrow
                    font.bold: true
                    font.italic: true
                    font.pixelSize: 84 * root.u
                }
                Rectangle {
                    anchors.verticalCenter: dateText.verticalCenter
                    width: dayText.implicitWidth + 24 * root.u
                    height: dayText.implicitHeight + 2 * root.u
                    color: Theme.paper
                    rotation: -8
                    antialiasing: true

                    Text {
                        id: dayText
                        anchors.centerIn: parent
                        text: Qt.locale("en_US").dayName(clock.date.getDay(), Locale.ShortFormat).toUpperCase()
                        color: Theme.ink
                        font.family: Theme.display
                        font.weight: Font.Black
                        font.pixelSize: 50 * root.u
                    }
                }
                Rectangle {
                    anchors.verticalCenter: dateText.verticalCenter
                    anchors.verticalCenterOffset: 16 * root.u
                    width: periodText.implicitWidth + 20 * root.u
                    height: periodText.implicitHeight + 4 * root.u
                    color: Theme.primary
                    rotation: 3
                    antialiasing: true

                    Text {
                        id: periodText
                        anchors.centerIn: parent
                        text: root.period(clock.date.getHours())
                        color: Theme.ink
                        font.family: Theme.narrow
                        font.bold: true
                        font.pixelSize: 30 * root.u
                        font.letterSpacing: 3 * root.u
                    }
                }
            }
        }

        // ── 密码错误印章 ──
        Item {
            x: -width / 2
            y: root.bandH / 2 + 4 * root.u
            width: stampBox.width
            height: stampBox.height
            visible: root.stamp > 0
            opacity: Math.min(1, root.stamp * 1.5)
            scale: 1.8 - root.stamp * 0.8
            rotation: -5

            Rectangle {
                x: 8 * root.u
                y: 8 * root.u
                width: stampBox.width
                height: stampBox.height
                color: Theme.ink
                antialiasing: true
            }
            Rectangle {
                id: stampBox
                width: stampText.implicitWidth + 40 * root.u
                height: stampText.implicitHeight + 10 * root.u
                color: Theme.danger
                antialiasing: true

                Text {
                    id: stampText
                    anchors.centerIn: parent
                    text: root.message || "WRONG PASSWORD"
                    color: Theme.paper
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 40 * root.u
                }
            }
        }
    }

    PowerMenu {
        id: power
        anchors.fill: parent
        u: root.u
        reveal: root.introSide
        fadeOut: root.fadeOut
        disabled: root.unlocking
        onAction: name => root.powerAction(name)
    }

    // 解锁铺开
    StripeCover {
        id: cover
        anchors.fill: parent
        visible: root.unlocking
    }
}
