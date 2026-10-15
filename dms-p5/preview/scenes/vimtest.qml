import QtQuick
import Quickshell

// 用合成按键测一遍 P5AppCarousel 的 vim 逻辑，结果打到日志里（VIM ok/FAIL）
Item {
    Loader {
        id: l
        anchors.fill: parent
        source: Qt.resolvedUrl("../Modules/P5/P5AppCarousel.qml")
        onLoaded: {
            const c = item;
            c.entries = Array.from({ length: 30 }, (_, i) => ({ name: "app" + i, desc: "", icon: "" }));
            c.opened = true;
            const K = { Escape: Qt.Key_Escape, Enter: Qt.Key_Return };
            function key(s) {
                const ev = { key: K[s] ?? 0, text: K[s] ? "" : s, modifiers: 0, accepted: false };
                if (c.insert) {
                    c.insertKey(ev);
                    // 没被拦下的字符由 TextInput 自己插入，这里模拟
                    if (!ev.accepted && s.length === 1 && !K[s]) {
                        const t = c.seekText(), p = c.seekCursor();
                        c.setText(t.slice(0, p) + s + t.slice(p), p + 1);
                    }
                } else c.normalKey(ev);
            }
            function seq(str) { for (const s of str.match(/<\w+>|./g)) key(s.startsWith("<") ? s.slice(1, -1) : s); }
            let launched = -1, closed = false;
            c.launchRequested.connect(i => launched = i);
            c.closeRequested.connect(() => closed = true);
            function check(name, cond) { console.log("VIM", cond ? "ok  " : "FAIL", name, JSON.stringify([c.seekText(), c.seekCursor(), c.sel, c.insert])); }

            seq("jjj"); check("jjj -> sel 4", c.sel === 4);
            seq("5j"); check("5j -> sel 9", c.sel === 9);
            seq("gg"); check("gg -> sel 1", c.sel === 1);
            seq("G"); check("G -> last", c.sel === 30);
            seq("k<Enter>"); check("Enter launches sel-1", launched === 28);
            seq("ifoo bar baz"); check("insert text", c.seekText() === "foo bar baz" && c.insert);
            seq("<Escape>"); check("Esc -> normal, cursor on last", !c.insert && c.seekCursor() === 10);
            seq("j"); check("j in normal moves list, not text", c.sel === 30 && c.seekText() === "foo bar baz");
            seq("0dw"); check("0dw", c.seekText() === "bar baz" && c.seekCursor() === 0);
            seq("u"); check("u undo", c.seekText() === "foo bar baz");
            seq("wcwqux<Escape>"); check("cw", c.seekText() === "foo qux baz");
            seq("$x"); check("$x", c.seekText() === "foo qux ba");
            seq("bD"); check("bD", c.seekText() === "foo qux ");
            seq("0ciwzz<Escape>"); check("ciw", c.seekText() === "zz qux ");
            seq("A!<Escape>"); check("A append", c.seekText() === "zz qux !");
            seq("0yeP"); check("ye + P", c.seekText() === "zzzz qux !");
            seq("~"); check("~ toggle case (P 后光标在粘贴末尾)", c.seekText() === "zZzz qux !");
            seq("Sx<Escape>"); check("S replaces line", c.seekText() === "x");
            seq("<Escape>"); check("Esc in normal closes", closed);
        }
    }
}
