pragma ComponentBehavior: Bound

import QtQuick
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets

// 新通知：从岛的下沿掉出一条 P5 短信（P5SmsBubble：左边是通知图标做的头像，右边是斜切气泡），
// 落下后轻轻晃一下；通知结束时被抽回岛里。左键激活，右键删掉。本元素是一个裁剪框，顶边贴着岛的下沿。
Item {
    id: root

    required property var notificationModel
    property bool showing: false
    readonly property bool hovered: msgHover.hovered

    // 裁剪框高度 = 纸条完全送出时的可见范围（另加一点晃动余量）
    height: paper.height + 18
    clip: true

    // 内容在纸条收回之后才清空，避免抽回途中文字消失
    property string app: ""
    property string summary: ""
    property string body: ""
    property string when: ""
    property string avatar: ""
    property string fallback: "material:notifications"
    property bool critical: false
    function latch() {
        app = notificationModel.appName;
        summary = notificationModel.summary;
        body = notificationModel.body;
        when = notificationModel.timeText;
        avatar = notificationModel.imageSource;
        fallback = notificationModel.fallbackIcon;
        critical = notificationModel.critical;
    }
    onShowingChanged: if (showing) latch()
    Connections {
        target: root.notificationModel
        function onSummaryChanged() {
            if (root.showing)
                root.latch();
        }
        function onBodyChanged() {
            if (root.showing)
                root.latch();
        }
    }

    Item {
        id: paper
        x: Math.round((root.width - width) / 2)
        width: sms.implicitWidth
        height: sms.implicitHeight + 10
        y: root.showing ? 6 : -height - 30
        transformOrigin: Item.Top

        Behavior on y {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: root.showing ? 420 : 200
                easing.type: root.showing ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.1
            }
        }

        // 落下后晃一下
        SequentialAnimation {
            id: swing
            PauseAnimation {
                duration: 260
            }
            NumberAnimation {
                target: paper
                property: "rotation"
                to: 2.2
                duration: 140
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: paper
                property: "rotation"
                to: -1.2
                duration: 220
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: paper
                property: "rotation"
                to: 0
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
        Connections {
            target: root
            function onShowingChanged() {
                if (!root.showing)
                    return;
                sms.play();
                if (P5.motionEnabled)
                    swing.restart();
            }
        }

        HoverHandler {
            id: msgHover
        }

        P5SmsBubble {
            id: sms
            width: implicitWidth
            height: implicitHeight
            seed: 7
            maxCenterWidth: root.width - 166
            bodyLines: 3
            app: root.app
            summary: root.summary
            body: root.body
            when: root.when
            avatar: root.avatar
            fallback: root.fallback
            critical: root.critical
            onActivated: root.notificationModel.activate()
            onDismissRequested: root.notificationModel.dismiss()
        }
    }
}
