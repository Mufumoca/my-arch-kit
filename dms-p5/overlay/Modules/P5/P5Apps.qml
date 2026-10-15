pragma Singleton

import QtQuick
import Quickshell

// P5 应用列表（存档界面式）的入口：spotlight 的 IPC（Mod+Z）改走这里。第一次打开时才创建窗口。
Singleton {
    id: root

    readonly property bool isOpen: loader.item?.shouldShow ?? false
    // 窗口还没建好时先记下要做的事，建好后补上
    property var _pending: null

    function _run(fn) {
        if (loader.item) {
            fn(loader.item);
            return;
        }
        _pending = fn;
        loader.active = true;
    }

    function open(query) {
        _run(w => w.open(query || ""));
    }
    function close() {
        loader.item?.close();
    }
    function toggle() {
        _run(w => w.toggle());
    }

    LazyLoader {
        id: loader
        active: false

        onItemChanged: {
            if (item && root._pending) {
                const fn = root._pending;
                root._pending = null;
                Qt.callLater(() => fn(item));
            }
        }

        P5AppsWindow {}
    }
}
