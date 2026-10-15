pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import "../../Common/htmlElide.js" as HtmlElide

// 通知中心 = P5 手机聊天界面：顶上是群聊标题 + NEW/LOG 开关，下面每条通知是一条 P5 短信（P5SmsBubble：
// 左边是通知图标做的歪斜头像，右边是斜切气泡）。左键：有动作就执行默认动作并收起面板，没有动作就展开 / 收起全文；
// 右键删掉这条。最新的消息在最下面，像聊天记录一样往上翻。底板是岛的面板，这里切到通知中心时画静态星星。
Item {
    id: root

    property real maxContentHeight: 640
    signal closeRequested
    signal settingsRequested

    property string tab: "now"   // now | log
    readonly property var current: NotificationService.notifications
    readonly property var history: NotificationService.historyList
    readonly property var rows: {
        if (tab === "log")
            return history.map(h => ({
                        "wrapper": null,
                        "hist": h
                    }));
        // 最新的在前（列表自下而上排，所以最新的落在最底下）
        const out = [];
        for (let i = current.length - 1; i >= 0; i--)
            out.push({
                "wrapper": current[i],
                "hist": null
            });
        return out;
    }

    readonly property real headerHeight: 76
    readonly property real targetImplicitHeight: Math.min(maxContentHeight, headerHeight + Math.max(170, list.contentHeight + 24))

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested();
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.tab = root.tab === "now" ? "log" : "now";
            return true;
        case Qt.Key_Delete:
            root.dismissAll();
            return true;
        case Qt.Key_Up:
        case Qt.Key_K:
            list.flick(0, 900);
            return true;
        case Qt.Key_Down:
        case Qt.Key_J:
            list.flick(0, -900);
            return true;
        }
        return false;
    }
    function dismissAll() {
        if (tab === "log")
            NotificationService.clearHistory();
        else
            NotificationService.clearAllNotifications();
    }
    function stamp(ms) {
        const d = new Date(ms);
        const now = new Date();
        const hm = d.toLocaleTimeString(Qt.locale(), SettingsData.use24HourClock ? "HH:mm" : "h:mm AP");
        return d.toDateString() === now.toDateString() ? hm : d.toLocaleDateString(Qt.locale(), "M/d") + " " + hm;
    }

    // ---- 标题 ----
    Item {
        id: titleRow
        x: 14
        y: 18
        width: parent.width - 28
        height: 52

        // 标题：散乱的漫画大字，不要底板
        P5Scrawl {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            rotation: -5
            text: root.tab === "log" ? "CHAT LOG" : "MESSAGES"
            seed: root.tab === "log" ? 4 : 2
            pixelSize: 33
        }

        // NEW / LOG 开关
        P5Switch {
            anchors.right: parent.right
            anchors.rightMargin: 34
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            scale: 0.85
            checked: root.tab === "log"
            offText: "NEW"
            onText: "LOG"
            onToggled: checked => root.tab = checked ? "log" : "now"
        }
    }

    // ---- 聊天记录 ----
    ListView {
        id: list
        x: 8
        y: root.headerHeight
        width: parent.width - 16
        height: parent.height - y - 6
        clip: true
        spacing: 4
        topMargin: 8
        bottomMargin: 12
        verticalLayoutDirection: ListView.BottomToTop
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.rows
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "x"
                    from: -60
                    duration: 260
                    easing.type: Easing.OutBack
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    duration: 160
                }
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        delegate: Item {
            id: msg
            required property var modelData
            required property int index

            readonly property var w: modelData.wrapper
            readonly property var h: modelData.hist

            // 没有动作的消息左键展开全文
            property bool open: false

            width: list.width
            height: sms.implicitHeight

            P5SmsBubble {
                id: sms
                width: implicitWidth
                height: implicitHeight
                seed: msg.index * 13 + 5
                maxCenterWidth: msg.width - 172
                bodyLines: msg.open ? 40 : 5
                app: msg.w ? msg.w.appName : (msg.h?.appName || "app")
                summary: HtmlElide.plainText(msg.w ? msg.w.summary : (msg.h?.summary || ""))
                body: HtmlElide.plainText(msg.w ? msg.w.body : (msg.h?.body || ""))
                when: msg.w ? msg.w.timeStr : root.stamp(msg.h?.timestamp || 0)
                critical: (msg.w ? msg.w.urgency : (msg.h?.urgency ?? 1)) === 2
                avatar: msg.w ? msg.w.displayImage : NotificationService.notificationImageSource(msg.h?.image || "", msg.h?.appIcon || "")
                fallback: msg.w ? msg.w.fallbackIconName : NotificationService.notificationFallbackIcon(msg.h?.image || "", msg.h?.appIcon || "")
                onActivated: {
                    const actions = msg.w ? (msg.w.actions || []) : [];
                    if (actions.length === 0) {
                        msg.open = !msg.open;
                        return;
                    }
                    actions[0].invoke();
                    if (!msg.w.notification?.resident)
                        NotificationService.dismissNotification(msg.w);
                    root.closeRequested();
                }
                onDismissRequested: {
                    if (msg.w)
                        NotificationService.dismissNotification(msg.w);
                    else if (msg.h)
                        NotificationService.removeFromHistory(msg.h.id);
                }
            }
        }
    }

    // 没有消息：只留一行散乱的大字，斜着压在星空上
    P5Scrawl {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -6
        y: root.headerHeight + Math.max(0, (170 - height) / 2)
        visible: root.rows.length === 0
        rotation: -7
        text: root.tab === "log" ? "NO LOGS" : "ALL CLEAR"
        seed: root.tab === "log" ? 9 : 5
        pixelSize: 70
        outline: 3.5
        shadowOffset: Qt.point(6, 6)
        firstScale: 1.3
        tilt: 14
        bounce: 0.24
    }
}
