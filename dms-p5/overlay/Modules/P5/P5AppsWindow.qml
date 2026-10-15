import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modals.DankLauncherV2

// P5AppCarousel 的全屏宿主：开在当前聚焦的屏幕上，数据与启动走启动器的 Controller（应用模式，搜索逻辑不变）。
PanelWindow {
    id: win

    property bool shouldShow: false

    visible: false
    color: "transparent"

    WlrLayershell.namespace: "dms:p5-apps"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    // 收起动画期间就交还键盘，刚启动的应用能立刻拿到焦点
    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function open(query) {
        const scr = CompositorService.getFocusedScreen() ?? Quickshell.screens[0];
        if (scr && screen !== scr)
            screen = scr;
        shouldShow = true;
        visible = true;
        ctl.explicitQuerySession = !!query;
        ctl.searchMode = "apps";
        ctl.pluginFilter = "";
        ctl.searchQuery = "";
        carousel.opened = true;
        carousel.setQuery(query || "");
        if (!query)
            ctl.performSearch();
        carousel.forceActiveFocus();
    }
    function close() {
        shouldShow = false;
        carousel.opened = false;
    }
    function toggle() {
        if (shouldShow)
            close();
        else
            open("");
    }

    function iconValueOf(item) {
        switch (item.iconType) {
        case "material":
        case "nerd":
            return "material:" + (item.icon || "apps");
        case "unicode":
            return "unicode:" + (item.icon || "");
        case "composite":
            return item.iconFull || "";
        }
        return item.icon || "";
    }

    Controller {
        id: ctl
        active: win.visible
        viewModeContext: "appDrawer"
        forceLinearNavigation: true
        onItemExecuted: win.close()
    }

    readonly property var items: {
        const out = [];
        const fm = ctl.flatModel || [];
        for (let i = 0; i < fm.length; i++) {
            if (!fm[i].isHeader && fm[i].item)
                out.push(fm[i].item);
        }
        return out;
    }

    P5AppCarousel {
        id: carousel
        anchors.fill: parent
        focus: true
        entries: win.items.map(it => ({
                    "name": it.name || "",
                    "desc": it.subtitle || "",
                    "icon": win.iconValueOf(it)
                }))
        onQueryEdited: text => {
            if (text !== ctl.searchQuery)
                ctl.setSearchQuery(text);
        }
        onLaunchRequested: index => {
            const it = win.items[index];
            if (it)
                ctl.executeItem(it, true);
        }
        onCloseRequested: win.close()
        onFolded: win.visible = false
    }
}
