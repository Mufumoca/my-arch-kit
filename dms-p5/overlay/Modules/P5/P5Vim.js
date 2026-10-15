.pragma library

// 单行 vim：只管文本与光标的纯函数，按键分派在 P5AppCarousel.qml。
// 普通模式光标落在字符上：[0, len-1]；插入模式光标在字符之间：[0, len]。

// 字符类别：0 空白，1 单词字符，2 标点。big（W/B/E）时非空白都算一类。
function cls(c, big) {
    if (c === undefined || c === "")
        return -1;
    if (/\s/.test(c))
        return 0;
    if (big)
        return 1;
    return /[A-Za-z0-9_\u00C0-\uFFFF]/.test(c) ? 1 : 2;
}

function clampNormal(t, i) {
    return Math.max(0, Math.min(i, t.length - 1));
}

// w：下一个词首；没有下一个词时停在行尾（len）
function wordFwd(t, i, big) {
    const n = t.length;
    if (i >= n)
        return n;
    const k = cls(t[i], big);
    let j = i;
    if (k !== 0)
        while (j < n && cls(t[j], big) === k)
            j++;
    while (j < n && cls(t[j], big) === 0)
        j++;
    return j;
}

// e：当前/下一个词尾
function wordEnd(t, i, big) {
    const n = t.length;
    let j = i + 1;
    while (j < n && cls(t[j], big) === 0)
        j++;
    if (j >= n)
        return Math.max(0, n - 1);
    const k = cls(t[j], big);
    while (j + 1 < n && cls(t[j + 1], big) === k)
        j++;
    return j;
}

// b：当前/上一个词首
function wordBack(t, i, big) {
    let j = i - 1;
    while (j > 0 && cls(t[j], big) === 0)
        j--;
    if (j <= 0)
        return 0;
    const k = cls(t[j], big);
    while (j > 0 && cls(t[j - 1], big) === k)
        j--;
    return j;
}

function firstNonBlank(t) {
    const m = /\S/.exec(t);
    return m ? m.index : 0;
}

// 光标移动：返回新位置；inclusive 表示作为 d/c 的范围时包含目标字符（e、$ 这类）
function motion(t, i, key, count) {
    let p = i;
    let inclusive = false;
    for (let c = 0; c < count; c++) {
        switch (key) {
        case "h":
            p = Math.max(0, p - 1);
            break;
        case "l":
            p = Math.min(t.length, p + 1);
            break;
        case "w":
        case "W":
            p = wordFwd(t, p, key === "W");
            break;
        case "e":
        case "E":
            p = wordEnd(t, p, key === "E");
            inclusive = true;
            break;
        case "b":
        case "B":
            p = wordBack(t, p, key === "B");
            break;
        case "0":
            p = 0;
            break;
        case "^":
            p = firstNonBlank(t);
            break;
        case "$":
            p = Math.max(0, t.length - 1);
            inclusive = true;
            break;
        default:
            return null;
        }
    }
    return {
        "pos": p,
        "inclusive": inclusive
    };
}

// iw / aw 文本对象：返回 [start, end)
function wordObject(t, i, around) {
    const n = t.length;
    if (n === 0)
        return [0, 0];
    i = clampNormal(t, i);
    const k = cls(t[i], false);
    let s = i, e = i + 1;
    while (s > 0 && cls(t[s - 1], false) === k)
        s--;
    while (e < n && cls(t[e], false) === k)
        e++;
    if (around) {
        if (e < n && cls(t[e], false) === 0) {
            while (e < n && cls(t[e], false) === 0)
                e++;
        } else {
            while (s > 0 && cls(t[s - 1], false) === 0)
                s--;
        }
    }
    return [s, e];
}

function toggleCase(c) {
    const u = c.toUpperCase();
    return u === c ? c.toLowerCase() : u;
}
