/* P5R 存档界面 — 轮转条幅复刻
 *
 * 几何来自对原图的逐列取样：条幅并不共用一个圆心，而是各自挂在屏幕右侧外的一根竖直「转轴」(x = AX) 上，
 * 越靠下角度越陡。焦点之上的条幅向右急剧收拢，焦点之下的条幅近乎平行、逐渐变窄，再往下压成一叠灰色细条。
 * 所以这里不用固定圆心旋转，而是给每个「相对焦点的偏移 d」定义一组关键帧 [锚点 y, 角度, 长度]，
 * 连续插值。滚动时 d 连续变化，条幅就沿着这组关键帧轮转。
 */
(() => {
  "use strict";

  // ---------- 舞台 ----------
  const STAGE_W = 1920, STAGE_H = 1080;
  const stage = document.getElementById("stage");
  function fit() {
    const s = Math.min(innerWidth / STAGE_W, innerHeight / STAGE_H);
    stage.style.transform = `translate(${(innerWidth - STAGE_W * s) / 2}px, ${(innerHeight - STAGE_H * s) / 2}px) scale(${s})`;
  }
  addEventListener("resize", fit);
  fit();

  // ---------- 几何 ----------
  const AX = 2000;     // 转轴所在竖线（屏幕外）
  const H = 176;       // 普通条幅厚度
  const HF = 322;      // 焦点条幅厚度
  const EXT = 392;     // 焦点条幅向左弹出的长度（弹出部分就是那块带齿孔的大底片）
  const LONG = 3200;   // 条幅图形实际长度，向右越过转轴，保证弹出后仍连到轴上

  // d: [锚点 y（在 x=AX 处的上沿）, 角度°（向下为正）, 左端到转轴的长度]
  const KEYS = [
    [-7, -4, -2.6, 1500],
    [-6,  4, -1.6, 1500],
    [-5, 13, -0.6, 1500],
    [-4, 22,  0.5, 1495],
    [-3, 30,  1.6, 1490],
    [-2, 40,  3.0, 1480],   // 头部提示条所在位置
    [-1, 99,  5.5, 1416],
    [ 0, 127, 10.8, 1416],  // 焦点
    [ 1, 261, 18.0, 1420],
    [ 2, 365, 19.4, 1365],
    [ 3, 467, 21.8, 1250],
    [ 4, 556, 24.0, 1140],
    [ 5, 574, 24.4, 1100],
    [ 6, 591, 24.8, 1065],
    [ 7, 607, 25.2, 1035],
    [ 8, 622, 25.5, 1010],
  ];
  const K0 = KEYS[0][0], KN = KEYS[KEYS.length - 1][0];

  // Catmull-Rom 插值，两端线性外推
  function keyAt(d) {
    if (d <= K0 || d >= KN) {
      const [a, b] = d <= K0 ? [KEYS[0], KEYS[1]] : [KEYS[KEYS.length - 2], KEYS[KEYS.length - 1]];
      const base = d <= K0 ? a : b;
      const t = d - base[0];
      return [1, 2, 3].map(c => base[c] + (b[c] - a[c]) * t);
    }
    const i = Math.floor(d) - K0, t = d - Math.floor(d);
    const p0 = KEYS[Math.max(i - 1, 0)], p1 = KEYS[i], p2 = KEYS[Math.min(i + 1, KEYS.length - 1)], p3 = KEYS[Math.min(i + 2, KEYS.length - 1)];
    const t2 = t * t, t3 = t2 * t;
    return [1, 2, 3].map(c =>
      0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3));
  }

  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const smooth = t => { t = clamp(t); return t * t * (3 - 2 * t); };
  const easeOutBack = (t, s = 1.25) => { t = clamp(t) - 1; return 1 + t * t * ((s + 1) * t + s); };
  const easeOutCubic = t => 1 - Math.pow(1 - clamp(t), 3);

  function rng(seed) {
    return () => {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  // ---------- 存档数据 ----------
  const SLOTS = [
    { date: [2, 3],   wd: "Fr", tod: "Evening",      loc: "???",              lv: 98, time: [96, 12], name: "Ren", diff: "NoRMaL" },
    { date: [3, 19],  wd: "Su", tod: "Daytime",      loc: "Underground Mall", lv: 98, time: [97, 29], name: "Ren", diff: "NoRMaL" },
    { date: [1, 29],  wd: "Su", tod: "Daytime",      loc: "Kichijoji",        lv: 98, time: [91, 3],  name: "Ren", diff: "NoRMaL" },
    { date: [2, 3],   wd: "Fr", tod: "Evening",      loc: "???",              lv: 98, time: [95, 47], name: "Ren", diff: "NoRMaL" },
    { date: [12, 24], wd: "Sa", tod: "Evening",      loc: "Shibuya",          lv: 99, time: [99, 59], name: "Ren", diff: "NoRMaL", done: true },
    { date: [11, 20], wd: "Su", tod: "Night",        loc: "Leblanc",          lv: 76, time: [74, 18], name: "Ren", diff: "HaRD" },
    { date: [10, 11], wd: "Tu", tod: "After School", loc: "Shujin Academy",   lv: 64, time: [63, 52], name: "Ren", diff: "NoRMaL" },
    { date: [9, 5],   wd: "Mo", tod: "Daytime",      loc: "Akihabara",        lv: 55, time: [55, 6],  name: "Ren", diff: "MeRCiLeSS", done: true },
    { date: [8, 21],  wd: "Su", tod: "Evening",      loc: "Odaiba",           lv: 48, time: [47, 33], name: "Ren", diff: "NoRMaL" },
    { date: [7, 7],   wd: "Th", tod: "Daytime",      loc: "Shinjuku",         lv: 39, time: [38, 9],  name: "Ren", diff: "NoRMaL" },
    { date: [6, 14],  wd: "Tu", tod: "Late Night",   loc: "Mementos",         lv: 30, time: [29, 41], name: "Ren", diff: "SaFeTY" },
    { date: [5, 5],   wd: "Th", tod: "Daytime",      loc: "Yongen-Jaya",      lv: 21, time: [18, 2],  name: "Ren", diff: "NoRMaL" },
    { date: [4, 12],  wd: "Tu", tod: "Morning",      loc: "Shibuya Station",  lv: 8,  time: [4, 55],  name: "Ren", diff: "NoRMaL" },
    null, null, null,
  ];
  const N = SLOTS.length;

  // ---------- DOM 构建 ----------
  const SVGNS = "http://www.w3.org/2000/svg";
  const fanEl = document.getElementById("fan");
  const pad2 = n => String(n).padStart(2, "0");
  const pts = a => a.map(p => p[0].toFixed(1) + "," + p[1].toFixed(1)).join(" ");

  function svgShape() {
    const svg = document.createElementNS(SVGNS, "svg");
    svg.setAttribute("class", "shape");
    svg.setAttribute("width", LONG + 400);
    svg.setAttribute("height", 1000);
    const g = document.createElementNS(SVGNS, "g");
    g.setAttribute("transform", "translate(200,400)");
    svg.appendChild(g);
    return { svg, g };
  }
  function poly(g, cls, points) {
    const p = document.createElementNS(SVGNS, "polygon");
    p.setAttribute("class", cls);
    p.setAttribute("points", pts(points));
    g.appendChild(p);
    return p;
  }
  function rect(g, cls, x, y, w, h) {
    const r = document.createElementNS(SVGNS, "rect");
    r.setAttribute("class", cls);
    r.setAttribute("x", x); r.setAttribute("y", y); r.setAttribute("width", w); r.setAttribute("height", h);
    g.appendChild(r);
    return r;
  }
  function el(cls, html, left, top) {
    const d = document.createElement("div");
    d.className = cls;
    d.innerHTML = html;
    d.style.left = left + "px";
    d.style.top = top + "px";
    return d;
  }

  // 勒索信字母：轮换字体/字号/倾斜
  const RANSOM_FONTS = ["Anton", "Luckiest", "NotoK", "BarlowC"];
  function ransom(text, seed, base, opt = {}) {
    const r = rng(seed);
    return [...text].map((ch, k) => {
      if (ch === " ") return `<span class="rl" style="width:${base * 0.28}px"></span>`;
      const f = RANSOM_FONTS[Math.floor(r() * (opt.fonts || 3))];
      const size = base * (0.82 + r() * 0.36) * (f === "Anton" ? 1.12 : 1);
      const rot = (r() - 0.5) * 12;
      const dy = (r() - 0.5) * 8;
      const cls = opt.boxEvery && k % opt.boxEvery === opt.boxPhase ? "rl box" : "rl";
      const lower = opt.mixCase && r() < 0.35 ? ch.toLowerCase() : ch;
      return `<span class="${cls}" style="font-family:${f};font-size:${size.toFixed(0)}px;transform:translateY(${dy.toFixed(1)}px) rotate(${rot.toFixed(1)}deg)${f === "BarlowC" ? ";font-weight:800;font-style:italic" : ""}">${lower}</span>`;
    }).join("");
  }

  function noLabel(n, cls) {
    return `<span class="no-l">N<small>o.</small></span><span class="no-d">${n}</span>`;
  }

  function dateHTML(s, big) {
    const [m, d] = s.date;
    return `<span class="dm">${m}</span><span class="ds">/</span><span class="dm${big ? " big" : ""}">${d}</span>` +
           `<span class="wd">${s.wd}</span><span class="tod">${s.tod}</span>`;
  }

  function sparkHTML(r) {
    // COMPLETED 左侧的四芒星闪光
    const rays = [[0, 230], [180, 120], [90, 70], [270, 60], [25, 90], [205, 70], [150, 50], [330, 46]];
    return rays.map(([a, len]) => `<i style="width:${len}px;transform:rotate(${a}deg);height:${len > 100 ? 3 : 2}px"></i>`).join("");
  }

  function buildNormalInfo(info, s, n) {
    info.appendChild(el("n-no", noLabel(n), 44, 46));
    if (!s) {
      info.appendChild(el("nodata", "NO DATA", 380, 28));
      return;
    }
    if (s.done) buildStamp(info, n);
    else info.appendChild(el("date", dateHTML(s), 278, 8));
    info.appendChild(el("loc", s.loc, 790, 18));
    info.appendChild(el("lv", `<span class="lv-l">Lv</span><span class="lv-d">${s.lv}</span>`, 1088, -10));
  }

  // 通关存档：日期位置换成 COMPLETED 勒索信印章，跨过上沿压到上一条
  function buildStamp(info, n) {
    info.appendChild(el("spark", sparkHTML(), 150, 58));
    info.appendChild(el("stamp",
      ransom("C", 11, 100, { fonts: 2 }) + `<span class="rl dot">★</span>` +
      ransom("MPLeteD", 41, 78, { fonts: 2, boxEvery: 3, boxPhase: 1 }) + `<span class="star">★</span>`, 158, -2));
  }

  function buildFocusInfo(info, s, n) {
    info.appendChild(el("f-no", noLabel(n), 168, 206));
    if (!s) {
      info.appendChild(el("f-nodata", "NO DATA", 300, 26));
      return;
    }
    const fd = el("f-date", dateHTML(s, true), 270, 6);
    const digits = String(s.date[0]).length + String(s.date[1]).length;
    fd.style.setProperty("--k", digits >= 4 ? 0.78 : 1);   // 12/24 这类四位日期缩小，免得压到 PLAY TIME
    info.appendChild(fd);
    info.appendChild(el("f-diff", `<span class="tag">${ransom(s.done ? "CLeaR" : s.diff, n * 7 + 3, 44, { fonts: 2 })}</span>`, 334, 214));
    info.appendChild(el("f-play", ransom("PLaY TiME", 5, 34, { fonts: 3 }), 835, 186));
    info.appendChild(el("f-time", `${pad2(s.time[0])}<span class="colon">:</span>${pad2(s.time[1])}`, 1028, 140));
    info.appendChild(el("f-loc", s.loc, 937, 83));
    info.appendChild(el("f-lv", `<span class="lv-l">Lv</span><span class="lv-d">${s.lv}</span>`, 1424, 14));
    info.appendChild(el("f-name", s.name, 1447, 102));
  }

  const strips = [];

  function buildStrip(i) {
    const isHeader = i === 0;
    const s = isHeader ? null : SLOTS[i - 1];
    const r = rng(i * 7919 + 17);
    const j = (a = 4) => (r() * 2 - 1) * a;

    const root = document.createElement("div");
    root.className = "strip" + (isHeader ? " header" : "");
    root.style.zIndex = 10 + i;
    const slide = document.createElement("div");
    slide.className = "slide";
    root.appendChild(slide);

    // 普通形态
    const base = svgShape();
    let face = null;
    if (isHeader) {
      poly(base.g, "ink", [[-30 + j(), -420], [LONG, -420], [LONG, H + 40], [6 + j(), H + 40], [-22 + j(6), 120], [-8 + j(6), 20]]);
    } else {
      poly(base.g, "ink", [[-26 + j(), -14], [LONG, -14], [LONG, H + 12], [70 + j(6), H + 12], [58 + j(4), H + 22], [-6 + j(), H + 18],
                          [-14 + j(), H * 0.62], [-30 + j(), H * 0.34], [-18 + j(), 8]]);
      face = poly(base.g, "face hit", [[2 + j(3), 0], [LONG, 0], [LONG, H], [16 + j(3), H], [6 + j(3), H * 0.55]]);
      // 左端的胶片齿孔：上沿一个缺口 + 白框里一个方孔
      poly(base.g, "ink", [[22 + j(2), -2], [70 + j(3), -2], [66 + j(3), 34 + j(3)], [26, 40 + j(3)]]);
      poly(base.g, "ink", [[-2, 92 + j(4)], [30 + j(3), 88 + j(3)], [34 + j(3), 150 + j(4)], [-2, 154]]);
    }
    slide.appendChild(base.svg);

    const nInfo = document.createElement("div");
    nInfo.className = "info n-info";
    if (isHeader) nInfo.appendChild(el("prompt", "Record your actions up to this point?", 192, 16));
    else buildNormalInfo(nInfo, s, i);
    slide.appendChild(nInfo);

    // 焦点形态（红色底片 + 齿孔），由斜切擦除显隐
    let fwrap = null, fInfo = null;
    if (!isHeader) {
      fwrap = document.createElement("div");
      fwrap.className = "focus-wrap";
      fwrap.style.left = "-200px"; fwrap.style.top = "-400px";
      fwrap.style.width = (LONG + 400) + "px"; fwrap.style.height = "1000px";
      const punch = document.createElement("div");
      punch.className = "punch";
      punch.style.left = "200px"; punch.style.top = "400px";
      fwrap.appendChild(punch);

      const fs = svgShape();
      poly(fs.g, "ink", [[-22 + j(), -214], [126, -220], [EXT + 24, -228], [EXT + 34, -16], [LONG, -16], [LONG, HF + 16],
                        [EXT + 52, HF + 16], [EXT + 32, HF + 32], [112, HF + 48], [58, HF + 40], [26 + j(), HF * 0.5], [-14 + j(), 40]]);
      const panelPts = [[-6 + j(), -198], [128, -205], [136, -190 + j()], [212, -194], [222, -208], [EXT + 10, -210], [EXT + 18, 0],
                        [LONG, 0], [LONG, HF], [EXT + 38, HF], [EXT + 22, HF + 14], [108, HF + 30], [92, HF + 14], [62, HF + 20],
                        [40 + j(), HF * 0.52], [4 + j(), 44]];
      poly(fs.g, "panel hit", panelPts);
      // 胶片齿孔：沿左缘一列
      for (let k = 0; k < 5; k++) {
        const y = -176 + k * 106 + j(4);
        const x = 16 + (y + 200) * 0.11 + j(3);
        const w = 30 + j(3), h = 64 + j(5);
        poly(fs.g, "ink", [[x, y], [x + w, y + j(2)], [x + w + 3, y + h], [x + 2, y + h + j(2)]]);
      }
      // 上沿的两处黑色缺口，让边缘不那么整齐
      poly(fs.g, "ink", [[128, -206], [150, -206], [146, -176], [132, -180]]);
      poly(fs.g, "ink", [[EXT - 30, -212], [EXT + 12, -212], [EXT + 14, -186], [EXT - 18, -190]]);
      poly(fs.g, "flash", panelPts);
      punch.appendChild(fs.svg);

      fInfo = document.createElement("div");
      fInfo.className = "info f-info";
      buildFocusInfo(fInfo, s, i);
      punch.appendChild(fInfo);
      slide.appendChild(fwrap);

      [face, fs.g.querySelector(".panel")].forEach(p => {
        p.addEventListener("pointerenter", () => { hover = i; });
        p.addEventListener("pointerleave", () => { if (hover === i) hover = -1; });
        p.addEventListener("click", ev => onStripClick(i, ev));
      });
    }

    fanEl.appendChild(root);

    return { i, root, slide, nInfo, fwrap, fInfo, hoverAmt: 0, focusT: 0, lastF: -1 };
  }

  for (let i = 0; i <= N; i++) strips.push(buildStrip(i));

  // ---------- 背景碎片（低多边形的皱红纸） ----------
  (function buildShards() {
    const layer = document.getElementById("shardLayer");
    const SH = [
      { p: [[862, -12], [1004, -16], [1016, 26], [968, 60], [930, 52], [900, 40]], g: "A", dur: 8, blur: "soft" },
      { p: [[1392, -12], [1664, -14], [1650, 38], [1596, 72], [1538, 60], [1452, 80], [1404, 42]], g: "B", dur: 10 },
      { p: [[1226, -12], [1300, -12], [1288, 22], [1246, 18]], g: "A", dur: 7 },
      { p: [[-10, 282], [50, 296], [86, 356], [82, 430], [44, 478], [-10, 468]], g: "A", dur: 9, blur: "soft" },
      { p: [[-10, 560], [22, 598], [34, 690], [-10, 704]], g: "B", dur: 7, blur: "soft" },
      { p: [[-10, -10], [96, -10], [70, 30], [-10, 48]], g: "B", dur: 11 },
      { p: [[468, 1092], [516, 1010], [600, 984], [694, 1000], [726, 1092]], g: "B", dur: 9, blur: "soft" },
      { p: [[1652, 1092], [1694, 900], [1772, 800], [1868, 756], [1932, 772], [1932, 1092]], g: "A", dur: 12 },
      { p: [[1574, 1092], [1636, 1016], [1706, 1036], [1694, 1092]], g: "B", dur: 8, blur: "softer" },
      { p: [[1880, 380], [1932, 360], [1932, 470], [1898, 450]], g: "A", dur: 9, blur: "soft" },
    ];
    SH.forEach((sh, si) => {
      const r = rng(si * 131 + 7);
      const g = document.createElementNS(SVGNS, "g");
      g.setAttribute("class", "shard");
      g.style.setProperty("--dur", sh.dur + "s");
      g.style.setProperty("--delay", (-r() * sh.dur).toFixed(2) + "s");
      g.style.setProperty("--dx", ((r() - 0.5) * 14).toFixed(1) + "px");
      g.style.setProperty("--dy", ((r() - 0.5) * 12).toFixed(1) + "px");
      g.style.setProperty("--dr", ((r() - 0.5) * 6).toFixed(1) + "deg");
      if (sh.blur) g.setAttribute("filter", `url(#${sh.blur})`);
      const c = sh.p.reduce((a, q) => [a[0] + q[0] / sh.p.length, a[1] + q[1] / sh.p.length], [0, 0]);
      c[0] += (r() - 0.5) * 20; c[1] += (r() - 0.5) * 20;
      poly(g, "", sh.p).setAttribute("fill", `url(#gShard${sh.g})`);
      // 以重心切三角面，随机压暗/提亮，做出皱纸的折面
      sh.p.forEach((q, k) => {
        const q2 = sh.p[(k + 1) % sh.p.length];
        const tri = poly(g, "", [c, q, q2]);
        const dark = r();
        tri.setAttribute("fill", dark < 0.65 ? "#000" : "#fff");
        tri.setAttribute("opacity", dark < 0.65 ? (0.08 + r() * 0.34).toFixed(2) : (0.04 + r() * 0.08).toFixed(2));
      });
      layer.appendChild(g);
    });
  })();

  // ---------- 状态 ----------
  const params = new URLSearchParams(location.search);
  let sel = clamp(parseInt(params.get("sel") || "2", 10) || 2, 1, N);
  let pos = sel, vel = 0;
  strips[sel].focusT = 1;   // 初始选中项直接满高亮（开场时由展开进度 k 控制显隐）
  let hover = -1;

  const UNFOLD_DUR = 0.62, UNFOLD_STAGGER = 0.05, UNFOLD_RANKS = 9;
  const unfoldTotal = UNFOLD_DUR + UNFOLD_STAGGER * UNFOLD_RANKS;
  let foldT = params.has("static") ? 1 : 0;   // 0 = 收起（全部叠在提示条下）, 1 = 展开
  let foldTarget = 1;

  if (params.get("theme")) document.documentElement.dataset.theme = params.get("theme");
  // 调试用：?pos=2.4 冻结在两条之间的过渡帧；?fold=0.5 冻结在展开动画中途
  const freezePos = params.has("pos") ? parseFloat(params.get("pos")) : null;
  const freezeFold = params.has("fold") ? parseFloat(params.get("fold")) : null;

  const thumb = document.getElementById("thumb");
  const TRACK = 334 - 12 - 8 - 24;

  function setSel(n) {
    n = clamp(n, 1, N);
    if (n === sel) return false;
    sel = n;
    return true;
  }
  function move(delta) {
    if (foldTarget === 0) return;
    setSel(sel + delta);
  }
  function confirm() {
    if (foldTarget === 0) { toggleFold(); return; }
    const st = strips[sel];
    st.root.classList.remove("confirm");
    void st.root.offsetWidth;
    st.root.classList.add("confirm");
    setTimeout(() => st.root.classList.remove("confirm"), 520);
  }
  function toggleFold() { foldTarget = foldTarget ? 0 : 1; }

  function onStripClick(i, ev) {
    if (dragMoved) return;
    if (i === sel) confirm();
    else setSel(i);
  }

  // ---------- 输入 ----------
  addEventListener("keydown", ev => {
    const k = ev.key;
    if (k === "ArrowDown" || k === "s" || k === "j") move(1);
    else if (k === "ArrowUp" || k === "w" || k === "k") move(-1);
    else if (k === "PageDown") move(5);
    else if (k === "PageUp") move(-5);
    else if (k === "Home") move(-N);
    else if (k === "End") move(N);
    else if (k === "Enter" || k === " ") confirm();
    else if (k === "Escape" || k === "Backspace") toggleFold();
    else if (k === "t" || k === "T") {
      const root = document.documentElement;
      root.dataset.theme = root.dataset.theme === "lavender" ? "red" : "lavender";
    } else return;
    ev.preventDefault();
  });

  let wheelAcc = 0, wheelLast = 0;
  addEventListener("wheel", ev => {
    ev.preventDefault();
    const now = performance.now();
    if (now - wheelLast > 220) wheelAcc = 0;
    wheelLast = now;
    wheelAcc += ev.deltaY;
    while (Math.abs(wheelAcc) >= 100) {
      move(Math.sign(wheelAcc));
      wheelAcc -= Math.sign(wheelAcc) * 100;
    }
  }, { passive: false });

  let dragY = null, dragMoved = false;
  addEventListener("pointerdown", ev => { dragY = ev.clientY; dragMoved = false; });
  addEventListener("pointermove", ev => {
    if (dragY === null) return;
    const dy = ev.clientY - dragY;
    if (Math.abs(dy) > 70) {
      move(dy < 0 ? 1 : -1);
      dragY = ev.clientY;
      dragMoved = true;
    }
  });
  addEventListener("pointerup", () => { dragY = null; setTimeout(() => { dragMoved = false; }, 0); });

  document.querySelector('[data-act="back"]').addEventListener("click", toggleFold);
  document.querySelector('[data-act="confirm"]').addEventListener("click", confirm);

  // ---------- 每帧布局 ----------
  const FOLD_KEY = keyAt(-2);   // 收起时全部叠到提示条的位置

  let last = performance.now();
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;

    // 欠阻尼弹簧：切换时带一点过冲，P5 的「甩」感
    const Ks = 230, Cs = 2 * Math.sqrt(Ks) * 0.66;
    const acc = Ks * (sel - pos) - Cs * vel;
    vel += acc * dt;
    pos += vel * dt;
    if (Math.abs(sel - pos) < 1e-4 && Math.abs(vel) < 1e-4) { pos = sel; vel = 0; }
    if (freezePos !== null) { pos = freezePos; vel = 0; }

    foldT = freezeFold !== null ? freezeFold : clamp(foldT + (foldTarget ? 1 : -1.6) * dt / unfoldTotal);
    const tAbs = foldT * unfoldTotal;

    for (const st of strips) {
      const d = st.i - pos;
      let [ay, th, len] = keyAt(d);

      // 展开动画：自上而下依次从提示条下方甩出
      // 按在扇面中的位置排序：上方的先甩出，往下依次展开
      const rank = clamp(d + 2, 0, UNFOLD_RANKS);
      const k = clamp((tAbs - rank * UNFOLD_STAGGER) / UNFOLD_DUR);
      const e = easeOutBack(k, 1.15);
      ay = lerp(FOLD_KEY[0], ay, e);
      th = lerp(FOLD_KEY[1], th, e);
      const retract = (1 - easeOutCubic(k)) * 1500;   // 收起时整条缩回转轴后面

      // 焦点程度
      // 焦点高亮跟随离散的 sel 立刻切换（进 0.2s / 出 0.13s），条幅本身则按弹簧连续轮转
      const want = st.i === sel && foldTarget ? 1 : 0;
      if (want > st.focusT) st.focusT = Math.min(1, st.focusT + dt / 0.2);
      else if (want < st.focusT) st.focusT = Math.max(0, st.focusT - dt / 0.13);
      if (freezePos !== null) st.focusT = smooth(1 - Math.abs(d));
      let f = st.i === 0 ? 0 : smooth(st.focusT);
      f *= smooth((k - 0.35) / 0.65);

      // 悬停：非焦点条幅微微探出
      const hv = st.i === hover && Math.abs(d) > 0.5 ? 1 : 0;
      st.hoverAmt += (hv - st.hoverAmt) * Math.min(1, dt * 14);
      if (Math.abs(hv - st.hoverAmt) < 0.002) st.hoverAmt = hv;

      // 压缩区（焦点上 2 条以外 / 下 3 条以外）：转到「背面」，用 scaleY 模拟透视缩短，并逐渐变灰
      const cBelow = smooth((d - 3.3) / 2.4), cAbove = smooth((-d - 2.1) / 2.2);
      const comp = Math.max(cBelow, cAbove) * e;
      const sy = lerp(1, 0.3, comp);

      const ext = EXT * easeOutBack(f, 0.9) + st.hoverAmt * 22;
      const tf = `translate(${AX}px, ${ay.toFixed(2)}px) rotate(${(-th).toFixed(3)}deg) scaleY(${sy.toFixed(3)})`;
      const sl = `translateX(${(-len - ext + retract).toFixed(2)}px)`;
      const g = Math.round(255 - comp * 85);
      const nAlpha = ((1 - smooth(f / 0.55)) * Math.pow(1 - comp, 1.6)).toFixed(3);
      // 静止时不重复写样式
      const sig = tf + sl + g + nAlpha;
      if (sig !== st.lastSig) {
        st.lastSig = sig;
        st.root.style.transform = tf;
        st.slide.style.transform = sl;
        st.root.style.setProperty("--face", `rgb(${g},${g},${g})`);
        st.nInfo.style.opacity = nAlpha;
      }

      if (st.fwrap && Math.abs(f - st.lastF) > 1e-4) {
        st.lastF = f;
        if (f < 0.002) {
          st.fwrap.style.visibility = "hidden";
        } else {
          st.fwrap.style.visibility = "visible";
          // 斜切擦除：红色从左端扫向转轴
          const w = easeOutCubic(f);
          if (w > 0.999) st.fwrap.style.clipPath = "none";
          else {
            const x = 200 - 260 + w * 2700;
            st.fwrap.style.clipPath = `polygon(0 0, ${(x + 220).toFixed(1)}px 0, ${x.toFixed(1)}px 100%, 0 100%)`;
          }
          const ti = smooth((f - 0.45) / 0.55);
          st.fInfo.style.opacity = ti.toFixed(3);
          st.fInfo.style.transform = `translateX(${((1 - ti) * -60).toFixed(1)}px)`;
        }
      }
    }

    thumb.style.transform = `translateY(${(clamp((pos - 1) / (N - 1), -0.05, 1.05) * TRACK).toFixed(1)}px)`;
    requestAnimationFrame(frame);
  }

  const start = () => requestAnimationFrame(t => { last = t; requestAnimationFrame(frame); });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(start); else start();
})();
