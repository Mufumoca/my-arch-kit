pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 数据 + 持久化 + 每日任务刷新 + 拖拽状态
Singleton {
    id: store

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/kanban"
    property var tasks: []      // { id, title, desc, status: todo|doing|done, daily?: templateId }
    property var dailies: []    // { id, title, desc, times: ["HH:MM"], last: ms }
    property bool ready: false

    // 拖拽状态（窗口坐标）
    property string dragId: ""
    property var dragTask: null
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    property real dragW: 0
    property string dropCol: ""
    property int dropIndex: -1

    function uid() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }

    // ---------- 任务 ----------
    function addTask(title, desc, status) {
        const t = { id: uid(), title: title, desc: desc, status: status };
        const ts = tasks.slice();
        const first = ts.findIndex(x => x.status === status);
        ts.splice(first < 0 ? ts.length : first, 0, t);
        tasks = ts;
        save();
    }

    function updateTask(id, title, desc) {
        tasks = tasks.map(t => t.id === id ? Object.assign({}, t, { title: title, desc: desc }) : t);
        save();
    }

    function removeTask(id) {
        tasks = tasks.filter(t => t.id !== id);
        save();
    }

    function clearDone() {
        tasks = tasks.filter(t => t.status !== "done");
        save();
    }

    // 把任务移动到 status 列的第 index 位
    function move(id, status, index) {
        const t = tasks.find(x => x.id === id);
        if (!t) return;
        const rest = tasks.filter(x => x.id !== id);
        const col = rest.filter(x => x.status === status);
        let pos;
        if (index < col.length) pos = rest.indexOf(col[index]);
        else pos = col.length ? rest.indexOf(col[col.length - 1]) + 1 : rest.length;
        rest.splice(pos, 0, Object.assign({}, t, { status: status }));
        tasks = rest;
        save();
    }

    // ---------- 每日任务 ----------
    // "8 12:30 20.15" -> ["08:00", "12:30", "20:15"]
    function parseTimes(s) {
        const out = [];
        for (const part of s.split(/[\s,，;；]+/)) {
            const m = part.match(/^(\d{1,2})(?:[:：.](\d{1,2}))?$/);
            if (!m) continue;
            const h = Number(m[1]), mi = Number(m[2] || 0);
            if (h > 23 || mi > 59) continue;
            const v = String(h).padStart(2, "0") + ":" + String(mi).padStart(2, "0");
            if (out.indexOf(v) < 0) out.push(v);
        }
        return out.sort();
    }

    function addDaily(title, desc, timesStr) {
        let times = parseTimes(timesStr);
        if (times.length === 0) times = ["00:00"];
        dailies = dailies.concat([{ id: uid(), title: title, desc: desc, times: times, last: 0 }]);
        refreshDailies();
        save();
    }

    function removeDaily(id) {
        dailies = dailies.filter(d => d.id !== id);
        tasks = tasks.filter(t => t.daily !== id);
        save();
    }

    // 最近一个已经过去的刷新时间点
    function latestSlot(times, now) {
        let best = -1;
        for (const tm of times) {
            const hm = tm.split(":");
            const d = new Date(now);
            d.setHours(Number(hm[0]), Number(hm[1]), 0, 0);
            if (d.getTime() > now) d.setDate(d.getDate() - 1);
            best = Math.max(best, d.getTime());
        }
        return best;
    }

    // 到点后：该每日任务的实例重置回 Todo 顶部（没有则新建）
    function refreshDailies() {
        if (!ready) return;
        const now = Date.now();
        let ts = tasks.slice();
        let changed = false;
        const ds = dailies.map(d => {
            const slot = latestSlot(d.times, now);
            if (slot < 0 || (d.last || 0) >= slot) return d;
            changed = true;
            const old = ts.find(t => t.daily === d.id);
            ts = ts.filter(t => t.daily !== d.id);
            ts.unshift({ id: old ? old.id : uid(), title: d.title, desc: d.desc, status: "todo", daily: d.id });
            return Object.assign({}, d, { last: now });
        });
        if (changed) {
            tasks = ts;
            dailies = ds;
            save();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: store.refreshDailies()
    }

    // ---------- 拖拽 ----------
    function dragStart(task, x, y, gx, gy, w) {
        dragTask = task;
        grabX = gx;
        grabY = gy;
        dragW = w;
        dragX = x;
        dragY = y;
        dragId = task.id;
    }
    function dragMove(x, y) {
        dragX = x;
        dragY = y;
    }
    function dragEnd(drop) {
        if (drop && dropCol !== "" && dropIndex >= 0) move(dragId, dropCol, dropIndex);
        dragId = "";
        dragTask = null;
        dropCol = "";
        dropIndex = -1;
    }

    // ---------- 持久化 ----------
    function save() {
        if (!ready) return;
        file.setText(JSON.stringify({ version: 1, tasks: tasks, dailies: dailies }, null, 2));
    }

    Process {
        running: true
        command: ["mkdir", "-p", store.dir]
    }

    FileView {
        id: file
        path: store.dir + "/board.json"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                store.tasks = d.tasks || [];
                store.dailies = d.dailies || [];
            } catch (e) {}
            store.ready = true;
            store.refreshDailies();
        }
        onLoadFailed: {
            store.ready = true;
            store.refreshDailies();
        }
    }
}
