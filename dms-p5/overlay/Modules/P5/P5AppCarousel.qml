pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.DankCommon.Common
import qs.DankCommon.Widgets
import "P5Vim.js" as Vim

// P5R 存档界面式的应用列表（p5-reference/save-carousel 的 QML 移植）：
// 条幅挂在屏幕右侧外的一根竖直「转轴」上，按「相对选中项的偏移 d」查关键帧 [锚点 y, 角度, 长度] 连续插值；
// 选中的条幅向左弹出一块带齿孔的淡紫底片。左上角是勒索信式的 APPS 标题。
//
// 键位是单行 vim：普通模式 j/k 选、Enter 启动；i/a/I/A// 进插入模式，标题位置拉出一根同款长条当搜索框；
// Esc 回普通模式后长条保留，可用 h/l/w/b/e/0/$、x/X/s/S/D/C/d{动作}/c{动作}/y/p/r/~/u 编辑；再按 Esc 关闭。
//
// 只依赖 DankCommon：数据（entries）和启动由外层窗口 P5AppsWindow 接到启动器的 Controller 上。
FocusScope {
    id: root

    // [{ name, desc, icon }]，icon 是 AppIconRenderer 的 iconValue
    property var entries: []
    property bool opened: false

    signal queryEdited(string text)
    signal launchRequested(int index)
    signal closeRequested
    // 关闭时收起动画走完
    signal folded
    signal punched(int strip)

    // 测试 / 外部读取搜索条
    function seekText() {
        return input.text;
    }
    function seekCursor() {
        return input.cursorPosition;
    }

    function setQuery(q) {
        input.text = q;
        input.cursorPosition = Vim.clampNormal(q, q.length - 1);
    }

    // ---- 舞台：按 1920×1080 设计；高度铺满屏幕，扇面贴右边，标题与提示贴左边 ----
    readonly property real stageW: 1920
    readonly property real stageH: 1080
    readonly property real s: Math.min(height / stageH, width / 1600)
    readonly property real stageY: (height - stageH * s) / 2

    // ---- 颜色：P5R 的红换成主题淡紫，其余黑白不变 ----
    readonly property color accent: P5.violet
    readonly property color accentDeep: P5.paper
    // 标题的碎纸底：比焦点底片深一档，两者叠在左上角时分得开
    readonly property color titleBack: Qt.hsla(P5.hue(P5.violet), 0.4, 0.64, 1)
    readonly property color onAccent: Qt.hsla(P5.hue(P5.violet), 0.55, 0.13, 1)
    readonly property string noto: "Noto Sans"

    // ---- 几何（与 save-carousel/app.js 相同）----
    readonly property real axisX: 2000
    readonly property real hN: 176
    readonly property real hF: 322
    readonly property real ext: 392
    readonly property real longLen: 3200
    // 焦点下方 3 条正常条幅之后的折叠条幅数上限
    readonly property int maxFolded: 5
    readonly property real foldEnd: 4 + maxFolded
    // d: [锚点 y（x = axisX 处的上沿）, 角度°（向下为正）, 左端到转轴的长度]
    readonly property var keys: [[-7, -4, -2.6, 1500], [-6, 4, -1.6, 1500], [-5, 13, -0.6, 1500], [-4, 22, 0.5, 1495], [-3, 30, 1.6, 1490], [-2, 40, 3.0, 1480], [-1, 99, 5.5, 1416], [0, 127, 10.8, 1416], [1, 261, 18.0, 1420], [2, 365, 19.4, 1365], [3, 467, 21.8, 1250], [4, 556, 24.0, 1140], [5, 574, 24.4, 1100], [6, 591, 24.8, 1065], [7, 607, 25.2, 1035], [8, 622, 25.5, 1010]]

    // Catmull-Rom 插值，两端线性外推
    function keyAt(d) {
        const K = keys, k0 = K[0][0], kn = K[K.length - 1][0];
        if (d <= k0 || d >= kn) {
            const a = d <= k0 ? K[0] : K[K.length - 2], b = d <= k0 ? K[1] : K[K.length - 1];
            const base = d <= k0 ? a : b, t = d - base[0];
            return [base[1] + (b[1] - a[1]) * t, base[2] + (b[2] - a[2]) * t, base[3] + (b[3] - a[3]) * t];
        }
        const i = Math.floor(d) - k0, t = d - Math.floor(d);
        const p0 = K[Math.max(i - 1, 0)], p1 = K[i], p2 = K[Math.min(i + 1, K.length - 1)], p3 = K[Math.min(i + 2, K.length - 1)];
        const t2 = t * t, t3 = t2 * t;
        const out = [];
        for (let c = 1; c <= 3; c++)
            out.push(0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3));
        return out;
    }

    function clamp(x, a, b) {
        return Math.min(b === undefined ? 1 : b, Math.max(a === undefined ? 0 : a, x));
    }
    function lerp(a, b, t) {
        return a + (b - a) * t;
    }
    function smoothstep(t) {
        t = clamp(t);
        return t * t * (3 - 2 * t);
    }
    function easeOutBack(t, s) {
        t = clamp(t) - 1;
        return 1 + t * t * ((s + 1) * t + s);
    }
    function easeOutCubic(t) {
        return 1 - Math.pow(1 - clamp(t), 3);
    }
    // mulberry32：同一条幅每次歪得一样
    function rng(seed) {
        return () => {
            seed |= 0;
            seed = seed + 0x6D2B79F5 | 0;
            let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
            t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
            return ((t ^ t >>> 14) >>> 0) / 4294967296;
        };
    }

    // 条幅的全部多边形（普通形态 + 焦点底片），随机抖动按条幅序号播种
    function stripGeometry(i) {
        const r = rng(i * 7919 + 17);
        const j = a => (r() * 2 - 1) * (a === undefined ? 4 : a);
        const L = longLen, H = hN, HF = hF, E = ext;
        if (i === 0)
            return {
                "ink": []
            };
        const g = {};
        g.ink = [[-26 + j(), -14], [L, -14], [L, H + 12], [70 + j(6), H + 12], [58 + j(4), H + 22], [-6 + j(), H + 18], [-14 + j(), H * 0.62], [-30 + j(), H * 0.34], [-18 + j(), 8]];
        g.face = [[2 + j(3), 0], [L, 0], [L, H], [16 + j(3), H], [6 + j(3), H * 0.55]];
        // 左端的胶片齿孔：上沿一个缺口 + 白框里一个方孔
        g.notch = [[22 + j(2), -2], [70 + j(3), -2], [66 + j(3), 34 + j(3)], [26, 40 + j(3)]];
        g.hole = [[-2, 92 + j(4)], [30 + j(3), 88 + j(3)], [34 + j(3), 150 + j(4)], [-2, 154]];
        g.fInk = [[-22 + j(), -214], [126, -220], [E + 24, -228], [E + 34, -16], [L, -16], [L, HF + 16], [E + 52, HF + 16], [E + 32, HF + 32], [112, HF + 48], [58, HF + 40], [26 + j(), HF * 0.5], [-14 + j(), 40]];
        g.panel = [[-6 + j(), -198], [128, -205], [136, -190 + j()], [212, -194], [222, -208], [E + 10, -210], [E + 18, 0], [L, 0], [L, HF], [E + 38, HF], [E + 22, HF + 14], [108, HF + 30], [92, HF + 14], [62, HF + 20], [40 + j(), HF * 0.52], [4 + j(), 44]];
        // 焦点底片的齿孔沿左缘一列，再加上沿两处黑色缺口
        g.fHoles = [];
        for (let k = 0; k < 5; k++) {
            const y = -176 + k * 106 + j(4);
            const x = 16 + (y + 200) * 0.11 + j(3);
            const w = 30 + j(3), h = 64 + j(5);
            g.fHoles.push([[x, y], [x + w, y + j(2)], [x + w + 3, y + h], [x + 2, y + h + j(2)]]);
        }
        g.fHoles.push([[128, -206], [150, -206], [146, -176], [132, -180]]);
        g.fHoles.push([[E - 30, -212], [E + 12, -212], [E + 14, -186], [E - 18, -190]]);
        return g;
    }

    // 斜切擦除：只保留斜线左侧（w 为擦除进度 0→1），Sutherland–Hodgman 裁多边形
    function wipe(pts, w) {
        if (!pts || w > 0.999)
            return pts;
        const xt = w * 2700 - 40;
        const side = p => p[0] - (xt - 0.22 * (p[1] + 400));
        const out = [];
        for (let i = 0; i < pts.length; i++) {
            const cur = pts[i], prev = pts[(i + pts.length - 1) % pts.length];
            const gc = side(cur), gp = side(prev);
            if ((gc <= 0) !== (gp <= 0)) {
                const t = gp / (gp - gc);
                out.push([prev[0] + (cur[0] - prev[0]) * t, prev[1] + (cur[1] - prev[1]) * t]);
            }
            if (gc <= 0)
                out.push(cur);
        }
        return out;
    }

    function toPath(pts) {
        const out = [];
        if (!pts || pts.length < 3)
            return out;
        for (let i = 0; i < pts.length; i++)
            out.push(Qt.point(pts[i][0], pts[i][1]));
        out.push(Qt.point(pts[0][0], pts[0][1]));
        return out;
    }

    // 勒索信字母：轮换字体/字号/倾斜
    readonly property var ransomFonts: [P5.displayFont, P5.comicFont, noto, P5.labelFont]
    function ransom(text, seed, base, nFonts) {
        const r = rng(seed);
        const out = [];
        for (const ch of text) {
            const f = ransomFonts[Math.floor(r() * (nFonts || 3))];
            out.push({
                "ch": ch,
                "family": f,
                "size": base * (0.82 + r() * 0.36) * (f === P5.displayFont ? 1.12 : 1),
                "rot": (r() - 0.5) * 12,
                "dy": (r() - 0.5) * 8,
                "italic": f === P5.labelFont
            });
        }
        return out;
    }

    // ---- 状态 ----
    readonly property int count: entries ? entries.length : 0
    // 条幅 0 是顶上的占位条（不画，只给展开 / 收起当锚点），应用从 1 开始
    property int sel: 1
    property real pos: 1
    property real vel: 0
    property int hover: -1

    readonly property real unfoldDur: 0.62
    readonly property real unfoldStagger: 0.05
    readonly property int unfoldRanks: 9
    readonly property real unfoldTotal: unfoldDur + unfoldStagger * unfoldRanks
    property real foldT: 0
    property int foldTarget: 0
    readonly property real tAbs: foldT * unfoldTotal
    // 收起时全部叠到提示条的位置
    readonly property var foldKey: keyAt(-2)
    readonly property real fade: clamp(foldT * 4)

    onOpenedChanged: {
        if (opened) {
            insert = false;
            resetCmd();
            undoStack = [];
            redoStack = [];
            hover = -1;
            sel = 1;
            pos = 1;
            vel = 0;
            foldT = P5.motionEnabled ? 0 : 1;
            foldTarget = 1;
            keyCatcher.forceActiveFocus();
        } else {
            foldTarget = 0;
            insert = false;
            if (!P5.motionEnabled || foldT === 0) {
                foldT = 0;
                folded();
            }
        }
    }
    // 结果换了（搜索词变化）：回到第一项，不做长距离轮转
    onEntriesChanged: {
        sel = 1;
        pos = 1;
        vel = 0;
    }

    function select(i) {
        if (count === 0)
            return;
        sel = clamp(i, 1, count);
    }
    function move(delta) {
        if (foldTarget === 1)
            select(sel + delta);
    }
    function launch() {
        if (count === 0 || foldTarget !== 1)
            return;
        punched(sel);
        launchRequested(sel - 1);
    }

    function tick(dt) {
        if (!P5.motionEnabled) {
            pos = sel;
            vel = 0;
        } else if (pos !== sel || vel !== 0) {
            // 欠阻尼弹簧：切换时带一点过冲，P5 的「甩」感（比原版软一档，连按时不至于甩得太急）
            const ks = 140, cs = 2 * Math.sqrt(ks) * 0.72;
            vel += (ks * (sel - pos) - cs * vel) * dt;
            let p = pos + vel * dt;
            if (Math.abs(sel - p) < 1e-4 && Math.abs(vel) < 1e-4) {
                p = sel;
                vel = 0;
            }
            pos = p;
        }
        const ft = clamp(foldT + (foldTarget ? 1 : -1.6) * dt / unfoldTotal);
        if (ft !== foldT) {
            foldT = ft;
            if (ft === 0 && !opened)
                folded();
        }
    }

    FrameAnimation {
        running: root.opened || root.foldT > 0
        onTriggered: root.tick(Math.min(0.05, frameTime))
    }

    // ---- vim ----
    property bool insert: false
    property int cnt: 0
    // 待定的操作符：d c y g r，或文本对象前缀 di da ci ca yi ya
    property string op: ""
    property var undoStack: []
    property var redoStack: []
    property string reg: ""
    readonly property bool seekShown: insert || input.text.length > 0

    function resetCmd() {
        cnt = 0;
        op = "";
    }
    function setText(t, c) {
        input.text = t;
        input.cursorPosition = clamp(c, 0, t.length);
    }
    function snap() {
        undoStack.push({
            "t": input.text,
            "c": input.cursorPosition
        });
        redoStack = [];
    }
    function enterInsert(c, noSnap) {
        if (!noSnap)
            snap();
        insert = true;
        input.forceActiveFocus();
        input.cursorPosition = clamp(c, 0, input.text.length);
    }
    function leaveInsert() {
        const top = undoStack[undoStack.length - 1];
        if (top && top.t === input.text)
            undoStack.pop();
        insert = false;
        keyCatcher.forceActiveFocus();
        input.cursorPosition = Vim.clampNormal(input.text, input.cursorPosition - 1);
    }
    // 对 [a, b) 执行操作符
    function applyOp(o, a, b) {
        const t = input.text;
        if (o === "y") {
            reg = t.slice(a, b);
            input.cursorPosition = Vim.clampNormal(t, a);
            return;
        }
        snap();
        if (b > a)
            reg = t.slice(a, b);
        const nt = t.slice(0, a) + t.slice(b);
        if (o === "c") {
            setText(nt, a);
            enterInsert(a, true);
        } else {
            setText(nt, Vim.clampNormal(nt, a));
        }
    }
    function paste(after, n) {
        if (!reg)
            return;
        snap();
        const t = input.text, cur = Vim.clampNormal(t, input.cursorPosition);
        const at = t.length === 0 ? 0 : (after ? cur + 1 : cur);
        const ins = reg.repeat(n);
        setText(t.slice(0, at) + ins + t.slice(at), at + ins.length - 1);
    }
    function undo() {
        const s = undoStack.pop();
        if (!s)
            return;
        redoStack.push({
            "t": input.text,
            "c": input.cursorPosition
        });
        setText(s.t, Vim.clampNormal(s.t, s.c));
    }
    function redo() {
        const s = redoStack.pop();
        if (!s)
            return;
        undoStack.push({
            "t": input.text,
            "c": input.cursorPosition
        });
        setText(s.t, Vim.clampNormal(s.t, s.c));
    }

    function normalKey(ev) {
        const t = input.text, cur = Vim.clampNormal(t, input.cursorPosition);
        const n = Math.max(1, cnt);
        ev.accepted = true;

        if (ev.key === Qt.Key_Escape) {
            if (op || cnt)
                resetCmd();
            else
                closeRequested();
            return;
        }
        if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
            resetCmd();
            launch();
            return;
        }
        if (ev.modifiers & Qt.ControlModifier) {
            switch (ev.key) {
            case Qt.Key_D:
                move(5 * n);
                break;
            case Qt.Key_U:
                move(-5 * n);
                break;
            case Qt.Key_F:
                move(10 * n);
                break;
            case Qt.Key_B:
                move(-10 * n);
                break;
            case Qt.Key_N:
            case Qt.Key_J:
                move(n);
                break;
            case Qt.Key_P:
            case Qt.Key_K:
                move(-n);
                break;
            case Qt.Key_R:
                redo();
                break;
            case Qt.Key_BracketLeft:
            case Qt.Key_C:
                if (op || cnt)
                    resetCmd();
                else
                    closeRequested();
                return;
            default:
                ev.accepted = false;
            }
            resetCmd();
            return;
        }

        let c = ev.text;
        switch (ev.key) {
        case Qt.Key_Down:
            move(n);
            resetCmd();
            return;
        case Qt.Key_Up:
            move(-n);
            resetCmd();
            return;
        case Qt.Key_PageDown:
            move(5 * n);
            resetCmd();
            return;
        case Qt.Key_PageUp:
            move(-5 * n);
            resetCmd();
            return;
        case Qt.Key_Home:
            select(1);
            resetCmd();
            return;
        case Qt.Key_End:
            select(count);
            resetCmd();
            return;
        case Qt.Key_Left:
        case Qt.Key_Backspace:
            c = "h";
            break;
        case Qt.Key_Right:
            c = "l";
            break;
        case Qt.Key_Delete:
            c = "x";
            break;
        }
        if (!c) {
            ev.accepted = false;
            return;
        }

        if (op === "r") {
            if (t.length && cur + n <= t.length) {
                snap();
                setText(t.slice(0, cur) + c.repeat(n) + t.slice(cur + n), cur + n - 1);
            }
            resetCmd();
            return;
        }
        if (op === "g") {
            if (c === "g")
                select(cnt > 0 ? cnt : 1);
            resetCmd();
            return;
        }
        if (op.length === 2) {
            if (c === "w" || c === "W") {
                const r = Vim.wordObject(t, cur, op[1] === "a");
                applyOp(op[0], r[0], r[1]);
            }
            resetCmd();
            return;
        }
        const digit = /[1-9]/.test(c) || (c === "0" && cnt > 0);
        if (op) {
            if (digit) {
                cnt = cnt * 10 + Number(c);
                return;
            }
            if (c === op) {
                applyOp(op, 0, t.length);
            } else if (c === "i" || c === "a") {
                op += c;
                return;
            } else {
                // cw 在词上时等同 ce（vim 的特例）
                const cw = op === "c" && (c === "w" || c === "W") && t.length && Vim.cls(t[cur], c === "W") !== 0;
                const m = Vim.motion(t, cur, cw ? (c === "w" ? "e" : "E") : c, n);
                if (m) {
                    const a = Math.min(cur, m.pos);
                    const b = Math.max(cur, m.pos) + (m.inclusive && m.pos >= cur ? 1 : 0);
                    applyOp(op, a, Math.min(b, t.length));
                }
            }
            resetCmd();
            return;
        }
        if (digit) {
            cnt = cnt * 10 + Number(c);
            return;
        }

        switch (c) {
        case "j":
            move(n);
            break;
        case "k":
            move(-n);
            break;
        case "G":
            select(cnt > 0 ? cnt : count);
            break;
        case "g":
        case "d":
        case "c":
        case "y":
        case "r":
            op = c;
            return;
        case "h":
        case "l":
        case "w":
        case "b":
        case "e":
        case "W":
        case "B":
        case "E":
        case "0":
        case "^":
        case "$":
            {
                const m = Vim.motion(t, cur, c, n);
                input.cursorPosition = Vim.clampNormal(t, m.pos);
            }
            break;
        case "i":
            enterInsert(cur);
            break;
        case "a":
            enterInsert(t.length ? cur + 1 : 0);
            break;
        case "I":
            enterInsert(Vim.firstNonBlank(t));
            break;
        case "A":
            enterInsert(t.length);
            break;
        case "/":
        case "S":
            applyOp("c", 0, t.length);
            break;
        case "s":
            applyOp("c", cur, Math.min(t.length, cur + n));
            break;
        case "x":
            if (t.length)
                applyOp("d", cur, Math.min(t.length, cur + n));
            break;
        case "X":
            if (cur > 0)
                applyOp("d", Math.max(0, cur - n), cur);
            break;
        case "D":
            applyOp("d", cur, t.length);
            break;
        case "C":
            applyOp("c", cur, t.length);
            break;
        case "p":
            paste(true, n);
            break;
        case "P":
            paste(false, n);
            break;
        case "u":
            undo();
            break;
        case "~":
            if (t.length) {
                snap();
                let mid = "";
                for (const ch of t.slice(cur, cur + n))
                    mid += Vim.toggleCase(ch);
                setText(t.slice(0, cur) + mid + t.slice(cur + mid.length), Vim.clampNormal(t, cur + mid.length));
            }
            break;
        case "q":
            closeRequested();
            break;
        }
        resetCmd();
    }

    function insertKey(ev) {
        const ctrl = (ev.modifiers & Qt.ControlModifier) !== 0;
        const t = input.text, c = input.cursorPosition;
        switch (ev.key) {
        case Qt.Key_Escape:
            leaveInsert();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            launch();
            break;
        case Qt.Key_Down:
        case Qt.Key_Tab:
            move(1);
            break;
        case Qt.Key_Up:
        case Qt.Key_Backtab:
            move(-1);
            break;
        case Qt.Key_PageDown:
            move(5);
            break;
        case Qt.Key_PageUp:
            move(-5);
            break;
        case Qt.Key_J:
        case Qt.Key_N:
            if (!ctrl)
                return;
            move(1);
            break;
        case Qt.Key_K:
        case Qt.Key_P:
            if (!ctrl)
                return;
            move(-1);
            break;
        case Qt.Key_BracketLeft:
            if (!ctrl)
                return;
            leaveInsert();
            break;
        case Qt.Key_W:
            if (!ctrl)
                return;
            {
                const b = Vim.wordBack(t, c);
                setText(t.slice(0, b) + t.slice(c), b);
            }
            break;
        case Qt.Key_U:
            if (!ctrl)
                return;
            setText(t.slice(c), 0);
            break;
        case Qt.Key_H:
            if (!ctrl)
                return;
            if (c > 0)
                setText(t.slice(0, c - 1) + t.slice(c), c - 1);
            break;
        default:
            return;
        }
        ev.accepted = true;
    }

    // 普通模式的按键接收者（插入模式时焦点在 input 上）
    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: ev => root.normalKey(ev)
    }

    // ---- 背景：p5-reference/star-background 的静止一帧（同心五角星），黑白换成偏深灰的淡紫 ----
    readonly property color starDark: Qt.hsla(P5.hue(P5.violet), 0.12, 0.15, 1)
    readonly property color starLight: Qt.hsla(P5.hue(P5.violet), 0.2, 0.3, 1)
    readonly property color starMid: Qt.hsla(P5.hue(P5.violet), 0.15, 0.22, 1)

    Canvas {
        id: stars
        anchors.fill: parent
        opacity: root.fade
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onStarDarkChanged() {
                stars.requestPaint();
            }
        }

        // 原版：600×350 的容器里撒 50 个 250px 的星团，每个是逐层缩小、黑白相间的同心星
        readonly property var star: [[493.9, 0], [646.5, 309.2], [987.8, 358.8], [740.8, 599.5], [799.1, 939.4], [493.9, 779], [188.6, 939.4], [246.9, 599.5], [0, 358.8], [341.3, 309.2]]
        onPaint: {
            const ctx = getContext("2d");
            const W = width, H = height;
            ctx.reset();
            ctx.fillStyle = root.starLight;
            ctx.fillRect(0, 0, W, H);
            if (W <= 0 || H <= 0)
                return;
            // 虚拟容器宽 700，按屏幕比例取高，星团数按面积折算
            const u = W / 700, vh = H / u;
            const n = Math.round(50 * 700 * vh / (600 * 350));
            const r = root.rng(20240611);
            const rings = 10;
            for (let i = 0; i < n; i++) {
                const rot = Math.floor(r() * 200) * Math.PI / 180;
                const sc = r() * 10 >= 8 ? 0.7 : 1;
                const cx = (Math.floor(r() * 820) - 125 + 125) * u;
                const cy = (Math.floor(r() * (vh + 70)) - 125 + 125) * u;
                const dark = i % 5 === 4 ? root.starMid : root.starDark;
                ctx.save();
                ctx.translate(cx, cy);
                ctx.rotate(rot);
                ctx.scale(sc, sc);
                for (let k = rings; k >= 1; k--) {
                    // 星形按 987.8×950 等比塞进 250×(k/rings) 的方框
                    const box = 250 * u * (k - 0.5) / rings;
                    const f = box / 987.8;
                    ctx.beginPath();
                    for (let p = 0; p < star.length; p++) {
                        const x = (star[p][0] - 493.9) * f, y = (star[p][1] - 475) * f;
                        if (p === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.closePath();
                    ctx.fillStyle = k % 2 ? dark : root.starLight;
                    ctx.fill();
                }
                ctx.restore();
            }
        }
    }

    // ---- 扇面：贴右边 ----
    Item {
        id: fan
        width: root.stageW
        height: root.stageH
        scale: root.s
        transformOrigin: Item.TopLeft
        x: root.width - root.stageW * root.s
        y: root.stageY

        Repeater {
            model: root.count + 1

            Item {
                id: slot
                required property int index
                readonly property real d: index - root.pos
                z: 10 + index

                // 下方折叠区最多露出 maxFolded 条，末尾一条淡入淡出
                opacity: root.clamp(root.foldEnd - slot.d)

                Loader {
                    active: slot.d > -9.5 && slot.d < root.foldEnd
                    sourceComponent: Strip {
                        i: slot.index
                        d: slot.d
                    }
                }
            }
        }

        // 没有匹配
        Item {
            z: 500
            x: 760
            y: 360
            visible: root.count === 0 && root.foldTarget === 1
            rotation: -8
            Text {
                x: 8
                y: 8
                text: "NO DATA"
                color: root.accent
                font.family: P5.displayFont
                font.pixelSize: 170
                font.letterSpacing: 14
            }
            Text {
                text: "NO DATA"
                color: P5.paper
                font.family: P5.displayFont
                font.pixelSize: 170
                font.letterSpacing: 14
            }
        }
    }

    // 一个条幅（应用 / 顶上的提示条）
    component Poly: ShapePath {
        id: poly
        property var pts: []
        strokeWidth: -1
        PathPolyline {
            path: root.toPath(poly.pts)
        }
    }

    component Strip: Item {
        id: st

        property int i: 0
        property real d: 0
        readonly property bool isHeader: i === 0
        readonly property var entry: isHeader ? null : (root.entries[i - 1] ?? null)
        readonly property var geo: root.stripGeometry(i)

        readonly property var kf: root.keyAt(d)
        // 展开动画：自上而下依次从提示条下方甩出
        readonly property real rank: root.clamp(d + 2, 0, root.unfoldRanks)
        readonly property real k: root.clamp((root.tAbs - rank * root.unfoldStagger) / root.unfoldDur)
        readonly property real e: root.easeOutBack(k, 1.15)
        readonly property real retract: (1 - root.easeOutCubic(k)) * 1500

        // 焦点高亮跟随离散的 sel 切换，条幅本身按弹簧连续轮转。
        // 进：斜切擦除展开底片 + 向左弹出；出：底片保持原形淡出、条幅平滑缩回——不倒放擦除，免得像底片被「收回去」。
        // 三个进度各自从当前值续播，快速来回切换也不会跳帧；revealT 只在淡出走完后才归零
        readonly property bool wantFocus: !isHeader && i === root.sel && root.foldTarget === 1
        property real revealT: 0
        property real extT: 0
        property real fadeT: 0
        Component.onCompleted: revealT = extT = fadeT = wantFocus ? 1 : 0
        onWantFocusChanged: {
            focusIn.stop();
            focusOut.stop();
            if (!P5.motionEnabled) {
                revealT = extT = fadeT = wantFocus ? 1 : 0;
                return;
            }
            if (wantFocus) {
                // 擦除匀速续播：中途被切回来时只走剩下的那段
                revealIn.duration = 300 * (1 - revealT);
                focusIn.start();
            } else
                focusOut.start();
        }
        ParallelAnimation {
            id: focusIn
            NumberAnimation {
                id: revealIn
                target: st
                property: "revealT"
                to: 1
            }
            NumberAnimation {
                target: st
                property: "extT"
                to: 1
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
            NumberAnimation {
                target: st
                property: "fadeT"
                to: 1
                duration: 90
            }
        }
        SequentialAnimation {
            id: focusOut
            ParallelAnimation {
                NumberAnimation {
                    target: st
                    property: "extT"
                    to: 0
                    duration: 300
                    easing.type: Easing.InOutCubic
                }
                NumberAnimation {
                    target: st
                    property: "fadeT"
                    to: 0
                    duration: 220
                    easing.type: Easing.OutQuad
                }
            }
            PropertyAction {
                target: st
                property: "revealT"
                value: 0
            }
        }
        readonly property real gate: root.smoothstep((k - 0.35) / 0.65)
        // 展开程度（擦除与焦点文字）；vis 再乘上淡出，给普通形态的显隐用
        readonly property real f: isHeader ? 0 : root.smoothstep(revealT) * gate
        readonly property real vis: f * fadeT

        // 悬停：非焦点条幅微微探出
        property real hoverAmt: root.hover === i && Math.abs(d) > 0.5 ? 1 : 0
        Behavior on hoverAmt {
            enabled: P5.motionEnabled
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        // 压缩区（焦点上 2 条以外 / 下 3 条以外）：转到「背面」，scaleY 模拟透视缩短，并逐渐变灰。
        // 下方压得快一些：折叠只留 maxFolded 条，第一条折叠条幅要足够扁，才能被后面几条盖住下沿
        readonly property real comp: Math.max(root.smoothstep((d - 3.3) / 1.2), root.smoothstep((-d - 2.1) / 2.2)) * e
        readonly property real grey: (255 - comp * 85) / 255
        readonly property real nAlpha: (1 - root.smoothstep(vis / 0.55)) * Math.pow(1 - comp, 1.6)

        x: root.axisX
        y: root.lerp(root.foldKey[0], kf[0], e)
        // 先 scaleY（透视缩短）再旋转：Item 自带的 rotation 会排在 transform 列表之后，所以两个都放进列表
        transform: [
            Scale {
                yScale: root.lerp(1, 0.3, st.comp)
            },
            Rotation {
                angle: -root.lerp(root.foldKey[1], st.kf[1], st.e)
            }
        ]

        Item {
            id: slide
            x: -st.kf[2] - root.ext * root.easeOutBack(st.gate, 0.9) * st.extT - st.hoverAmt * 22 + st.retract

            // 普通形态
            Shape {
                preferredRendererType: Shape.CurveRenderer
                Poly {
                    pts: st.geo.ink
                    fillColor: P5.ink
                }
                Poly {
                    pts: st.geo.face ?? []
                    fillColor: Qt.rgba(st.grey, st.grey, st.grey, 1)
                }
                Poly {
                    pts: st.geo.notch ?? []
                    fillColor: P5.ink
                }
                Poly {
                    pts: st.geo.hole ?? []
                    fillColor: P5.ink
                }
            }

            // 普通条幅上的信息：图标 + 名字 + 简介
            Item {
                visible: !st.isHeader && opacity > 0.002
                opacity: st.nAlpha

                AppIconRenderer {
                    x: 58
                    y: 22
                    width: 92
                    height: 92
                    iconSize: 92
                    iconValue: st.entry?.icon ?? ""
                    fallbackText: (st.entry?.name ?? "?").charAt(0).toUpperCase()
                    materialIconSizeAdjustment: 0
                    iconColor: P5.ink
                    rotation: -4
                }
                Text {
                    id: nName
                    x: 178
                    y: 86 - baselineOffset
                    width: Math.min(implicitWidth, 720)
                    text: st.entry?.name ?? ""
                    elide: Text.ElideRight
                    color: P5.ink
                    font.family: root.noto
                    font.weight: Font.Black
                    font.pixelSize: 62
                    rotation: -1

                    // 淡紫错位投影
                    Text {
                        z: -1
                        x: 6
                        y: 5
                        width: parent.width
                        text: parent.text
                        elide: Text.ElideRight
                        color: root.accent
                        font: parent.font
                    }
                }
                Text {
                    x: nName.x + nName.width + 40
                    y: 80 - baselineOffset
                    width: Math.max(0, Math.min(implicitWidth, 1400 - x))
                    text: st.entry?.desc ?? ""
                    elide: Text.ElideRight
                    color: "#111111"
                    font.family: root.noto
                    font.weight: Font.Bold
                    font.pixelSize: 30
                    font.letterSpacing: 0.5
                    rotation: 1
                }
            }

            // 焦点形态：淡紫底片 + 齿孔，斜切擦除显隐
            Loader {
                active: !st.isHeader && st.vis > 0.002
                sourceComponent: Item {
                    id: focusWrap
                    opacity: st.fadeT
                    readonly property real w: root.easeOutCubic(st.f)
                    readonly property real ti: root.smoothstep((st.f - 0.45) / 0.55)
                    property real flash: 0

                    Connections {
                        target: root
                        function onPunched(idx) {
                            if (idx === st.i && P5.motionEnabled)
                                punchAnim.restart();
                        }
                    }

                    // 确认：冲击 + 闪白
                    SequentialAnimation {
                        id: punchAnim
                        NumberAnimation {
                            target: focusWrap
                            property: "flash"
                            to: 0.95
                            duration: 0
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: focusWrap
                                property: "flash"
                                to: 0
                                duration: 480
                                easing.type: Easing.OutQuad
                            }
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: punch
                                        property: "x"
                                        to: -46
                                        duration: 86
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "y"
                                        to: -6
                                        duration: 86
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "rotation"
                                        to: -1.2
                                        duration: 86
                                    }
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: punch
                                        property: "x"
                                        to: 14
                                        duration: 115
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "y"
                                        to: 2
                                        duration: 115
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "rotation"
                                        to: 0.4
                                        duration: 115
                                    }
                                }
                                ParallelAnimation {
                                    NumberAnimation {
                                        target: punch
                                        property: "x"
                                        to: -6
                                        duration: 135
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "y"
                                        to: 0
                                        duration: 135
                                    }
                                    NumberAnimation {
                                        target: punch
                                        property: "rotation"
                                        to: 0
                                        duration: 135
                                    }
                                }
                                NumberAnimation {
                                    target: punch
                                    property: "x"
                                    to: 0
                                    duration: 144
                                }
                            }
                        }
                    }

                    Item {
                        id: punch
                        transformOrigin: Item.TopLeft

                        Shape {
                            preferredRendererType: Shape.CurveRenderer
                            Poly {
                                pts: root.wipe(st.geo.fInk, focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.panel, focusWrap.w)
                                fillColor: root.accent
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[0], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[1], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[2], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[3], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[4], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[5], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: root.wipe(st.geo.fHoles[6], focusWrap.w)
                                fillColor: P5.ink
                            }
                            Poly {
                                pts: focusWrap.flash > 0 ? st.geo.panel : []
                                fillColor: Qt.rgba(1, 1, 1, focusWrap.flash)
                            }
                        }

                        // 焦点条幅上的信息：大图标 + 大名字 + 简介标签
                        Item {
                            opacity: focusWrap.ti
                            x: (1 - focusWrap.ti) * -60

                            AppIconRenderer {
                                x: 94
                                y: -136
                                width: 196
                                height: 196
                                iconSize: 196
                                iconValue: st.entry?.icon ?? ""
                                fallbackText: (st.entry?.name ?? "?").charAt(0).toUpperCase()
                                materialIconSizeAdjustment: 0
                                iconColor: root.onAccent
                                rotation: -6
                            }

                            TextMetrics {
                                id: fm
                                font.family: root.noto
                                font.weight: Font.Black
                                font.pixelSize: 150
                                text: st.entry?.name ?? ""
                            }
                            Item {
                                id: fNameBox
                                // 名字太长就缩小，最小 72px
                                readonly property real size: Math.max(72, Math.min(150, 150 * 1080 / Math.max(1, fm.advanceWidth * 0.9)))
                                x: 312
                                y: 22 + size * 0.714
                                rotation: 3
                                transform: Scale {
                                    xScale: 0.9
                                }

                                Text {
                                    x: 7
                                    y: 7 - baselineOffset
                                    width: 1200
                                    text: st.entry?.name ?? ""
                                    elide: Text.ElideRight
                                    color: root.accentDeep
                                    font.family: root.noto
                                    font.weight: Font.Black
                                    font.pixelSize: fNameBox.size
                                    font.letterSpacing: -fNameBox.size * 0.03
                                }
                                Text {
                                    y: -baselineOffset
                                    width: 1200
                                    text: st.entry?.name ?? ""
                                    elide: Text.ElideRight
                                    color: root.onAccent
                                    font.family: root.noto
                                    font.weight: Font.Black
                                    font.pixelSize: fNameBox.size
                                    font.letterSpacing: -fNameBox.size * 0.03
                                }
                            }

                            // 简介：黑色斜标签
                            Item {
                                x: 336
                                y: 200
                                rotation: -6
                                visible: descText.text.length > 0
                                width: descText.width + 40
                                height: 58

                                P5Poly {
                                    anchors.fill: parent
                                    points: [[width * 0.03, 0], [width, height * 0.06], [width * 0.97, height], [0, height * 0.92]]
                                    fillColor: P5.ink
                                }
                                Text {
                                    id: descText
                                    x: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 860)
                                    text: st.entry?.desc ?? ""
                                    elide: Text.ElideRight
                                    color: root.accent
                                    font.family: root.noto
                                    font.weight: Font.Black
                                    font.pixelSize: 32
                                }
                            }
                        }
                    }

                    // 底片向上探出的那块也能点
                    MouseArea {
                        x: 0
                        y: -210
                        width: root.ext + 20
                        height: 210
                        onClicked: root.launch()
                    }
                }
            }

            MouseArea {
                visible: !st.isHeader
                width: root.longLen
                height: st.vis > 0.5 ? root.hF : root.hN
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse)
                        root.hover = st.i;
                    else if (root.hover === st.i)
                        root.hover = -1;
                }
                onClicked: {
                    if (st.i === root.sel)
                        root.launch();
                    else
                        root.select(st.i);
                }
            }
        }
    }

    // ---- HUD：贴左边 ----
    Item {
        id: hud
        width: root.stageW
        height: root.stageH
        scale: root.s
        transformOrigin: Item.TopLeft
        y: root.stageY
        z: 100
        opacity: root.fade

        // 左侧斜滚动条
        Rectangle {
            x: 156
            y: 536
            width: 28
            height: 334
            radius: 14
            color: "transparent"
            border.width: 6
            border.color: P5.paper
            rotation: -30
            transformOrigin: Item.Top

            Rectangle {
                x: 9
                y: 10 + root.clamp((root.pos - 1) / Math.max(1, root.count - 1), -0.05, 1.05) * 290
                width: 10
                height: 24
                radius: 3
                color: P5.paper
            }
        }

        // 标题 ApPS：淡紫 + 黑两层碎纸底，勒索信式大字（搜索条拉出时让位）
        Item {
            id: title
            x: 128 + (root.seekShown ? -260 : 0)
            y: 6
            width: 560
            height: 360
            opacity: root.seekShown ? 0 : 1
            transform: Rotation {
                origin.x: 168
                origin.y: 180
                angle: -7
            }
            Behavior on x {
                enabled: P5.motionEnabled
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                enabled: P5.motionEnabled
                NumberAnimation {
                    duration: 160
                }
            }

            P5Poly {
                anchors.fill: parent
                points: [[70, 62], [172, 52], [180, 66], [340, 56], [356, 44], [492, 48], [510, 136], [478, 144], [492, 340], [160, 358], [136, 290], [80, 296], [70, 190], [48, 188]]
                fillColor: root.titleBack
            }
            P5Poly {
                anchors.fill: parent
                points: [[14, 98], [100, 78], [112, 92], [276, 70], [290, 84], [460, 68], [476, 80], [510, 76], [518, 180], [488, 206], [496, 238], [340, 254], [326, 272], [160, 286], [144, 272], [34, 280], [38, 240], [10, 230]]
                fillColor: P5.ink
            }

            P5StrokeText {
                x: 4
                y: 66
                rotation: -4
                text: "A"
                family: root.noto
                pixelSize: 222
                stroke: 12
            }
            P5StrokeText {
                x: 152
                y: 118
                rotation: 3
                text: "p"
                family: root.noto
                pixelSize: 150
                stroke: 12
            }
            P5StrokeText {
                x: 256
                y: 100
                rotation: -2
                text: "P"
                family: P5.displayFont
                weight: Font.Normal
                pixelSize: 178
                color: root.accent
                stroke: 12
                transform: Scale {
                    xScale: 1.25
                }
            }
            P5StrokeText {
                x: 384
                y: 88
                rotation: 2
                text: "S"
                family: P5.displayFont
                weight: Font.Normal
                pixelSize: 186
                stroke: 12
                transform: Scale {
                    xScale: 1.3
                }
            }
        }

        // 搜索条：从标题的位置拉出的同款长条。插入模式是淡紫底片，普通模式是白条
        Item {
            id: seek
            readonly property real w: 1180
            readonly property real h: 150
            x: root.seekShown ? -30 : -1500
            y: 160
            rotation: -5
            transformOrigin: Item.TopLeft
            visible: x > -1490

            Behavior on x {
                enabled: P5.motionEnabled
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            Shape {
                preferredRendererType: Shape.CurveRenderer
                Poly {
                    pts: [[-60, -14], [seek.w + 26, -20], [seek.w + 8, seek.h * 0.45], [seek.w + 34, seek.h + 14], [-60, seek.h + 18]]
                    fillColor: P5.ink
                }
                Poly {
                    pts: [[-60, 0], [seek.w, 0], [seek.w - 16, seek.h * 0.52], [seek.w + 10, seek.h], [-60, seek.h]]
                    fillColor: root.insert ? root.accent : P5.paper
                }
                // 自由端的胶片齿孔
                Poly {
                    pts: [[seek.w - 70, -2], [seek.w - 24, -2], [seek.w - 28, 32], [seek.w - 66, 38]]
                    fillColor: P5.ink
                }
                Poly {
                    pts: [[seek.w - 6, 90], [seek.w + 30, 86], [seek.w + 30, seek.h + 2], [seek.w - 2, seek.h - 4]]
                    fillColor: P5.ink
                }
            }

            // 模式：勒索信式黑标签
            Item {
                x: 28
                y: -20
                width: modeRow.width + 40
                height: 66
                rotation: -6

                P5Poly {
                    anchors.fill: parent
                    points: [[width * 0.03, 0], [width, height * 0.06], [width * 0.97, height], [0, height * 0.92]]
                    fillColor: P5.ink
                }
                Row {
                    id: modeRow
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: root.ransom(root.insert ? "INSeRT" : "NoRMaL", root.insert ? 19 : 23, 40, 2)
                        Text {
                            required property var modelData
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            anchors.verticalCenterOffset: modelData.dy
                            text: modelData.ch
                            rotation: modelData.rot
                            color: root.accent
                            font.family: modelData.family
                            font.pixelSize: modelData.size
                        }
                    }
                }
            }

            TextInput {
                id: input
                x: 40
                y: 104 - baselineOffset
                width: seek.w - 330
                clip: true
                readOnly: !root.insert
                selectByMouse: false
                cursorVisible: false
                cursorDelegate: Item {}
                color: P5.ink
                font.family: root.noto
                font.weight: Font.Black
                font.pixelSize: 78
                onTextChanged: {
                    if (!root.insert)
                        cursorPosition = Vim.clampNormal(text, cursorPosition);
                    root.queryEdited(text);
                }
                Keys.onPressed: ev => root.insertKey(ev)

                // 普通模式：淡紫块光标；插入模式：墨色竖线
                readonly property rect cur: {
                    text;
                    cursorPosition;
                    contentWidth;
                    return positionToRectangle(cursorPosition);
                }
                readonly property real curW: {
                    text;
                    cursorPosition;
                    contentWidth;
                    if (cursorPosition >= text.length)
                        return font.pixelSize * 0.5;
                    return Math.max(8, positionToRectangle(cursorPosition + 1).x - cur.x);
                }
                Rectangle {
                    z: -1
                    visible: !root.insert
                    x: input.cur.x
                    y: input.cur.y + input.cur.height * 0.12
                    width: input.curW
                    height: input.cur.height * 0.8
                    color: root.accent
                }
                Rectangle {
                    visible: root.insert && blink.on
                    x: input.cur.x - 2
                    y: input.cur.y + input.cur.height * 0.12
                    width: 8
                    height: input.cur.height * 0.8
                    color: P5.ink
                }
                Timer {
                    id: blink
                    property bool on: true
                    interval: 530
                    repeat: true
                    running: root.insert && root.opened
                    onRunningChanged: on = true
                    onTriggered: on = !on
                }
                Connections {
                    target: input
                    function onCursorPositionChanged() {
                        blink.on = true;
                        blink.restart();
                    }
                }
            }

            // 命中数 + 待定命令（vim 的 showcmd）
            Row {
                x: seek.w - 270
                y: 34
                spacing: 8
                rotation: -3

                Text {
                    anchors.bottom: parent.bottom
                    text: (root.cnt > 0 ? root.cnt : "") + root.op
                    color: P5.ink
                    font.family: P5.labelFont
                    font.weight: Font.Bold
                    font.pixelSize: 34
                }
                Rectangle {
                    width: hitNum.implicitWidth + 16
                    height: 70
                    color: root.insert ? P5.ink : root.accent
                    Text {
                        id: hitNum
                        anchors.centerIn: parent
                        text: root.count
                        color: root.insert ? root.accent : P5.ink
                        font.family: P5.displayFont
                        font.pixelSize: 60
                    }
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: "HIT"
                    color: P5.ink
                    font.family: P5.labelFont
                    font.weight: Font.ExtraBold
                    font.italic: true
                    font.pixelSize: 36
                }
            }
        }
    }

    // 滚轮切换
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: wheel => {
            acc += wheel.angleDelta.y;
            while (Math.abs(acc) >= 100) {
                root.move(acc > 0 ? -1 : 1);
                acc -= acc > 0 ? 100 : -100;
            }
        }
    }
}
