#version 450

// P5 板：任意凸四边形（斜切、歪斜、抖动出来的不规则角）+ 左上/右下切角，一次画出
//   主体填充（可叠静态星星、流动条纹、流光、左侧色条）→ 内框线 → 描边
//   → 两层错位板（各自可平移、旋转、外扩）→ 柔和投影
// 所有形状共用同一个四边形 SDF，抗锯齿用 fwidth。

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float widthPx;
    float heightPx;
    float phase;        // 0..1 循环的流动相位
    vec4 rectPx;        // 板的外接矩形：x, y, w, h（本元素坐标）
    vec4 quadA;         // 左上角、右上角相对矩形角的偏移 px
    vec4 quadB;         // 右下角、左下角相对矩形角的偏移 px
    vec4 shape;         // x = 左上切角，y = 右下切角，z = 描边宽，w = 未用
    vec4 fillColor;     // 非预乘 rgba
    vec4 borderColor;
    vec4 rimColor;      // 内框线颜色；a = 0 关闭
    vec4 rimParam;      // x = 内缩 px，y = 线宽 px
    vec4 slabColor;     // 第一层错位板；a = 0 关闭
    vec4 slabParam;     // xy = 偏移，z = 旋转（弧度），w = 外扩 px
    vec4 slab2Color;    // 第二层错位板；a = 0 关闭
    vec4 slab2Param;
    vec4 shadowColor;   // 柔和投影；a = 0 关闭
    vec4 shadowParam;   // x = 模糊 px，y = 扩张 px，zw = 偏移
    vec4 accentColor;   // 条纹 / 流光的颜色
    vec4 fx;            // x = 星星强度，y = 条纹强度，z = 流光强度，w = 左侧色条宽度 px
} ubuf;

// 点到有向边 a→b 的有符号距离（顺时针多边形，外侧为正）
float edgeDist(vec2 p, vec2 a, vec2 b) {
    vec2 e = b - a;
    vec2 n = normalize(vec2(e.y, -e.x));
    return dot(p - a, n);
}

vec2 cornerTL() { return ubuf.rectPx.xy + ubuf.quadA.xy; }
vec2 cornerTR() { return vec2(ubuf.rectPx.x + ubuf.rectPx.z, ubuf.rectPx.y) + ubuf.quadA.zw; }
vec2 cornerBR() { return ubuf.rectPx.xy + ubuf.rectPx.zw + ubuf.quadB.xy; }
vec2 cornerBL() { return vec2(ubuf.rectPx.x, ubuf.rectPx.y + ubuf.rectPx.w) + ubuf.quadB.zw; }

float plateDist(vec2 p) {
    vec2 a = cornerTL(), b = cornerTR(), c = cornerBR(), d = cornerBL();
    float dist = max(max(edgeDist(p, a, b), edgeDist(p, b, c)), max(edgeDist(p, c, d), edgeDist(p, d, a)));
    if (ubuf.shape.x > 0.0) {
        float k = min(ubuf.shape.x, 0.5 * min(length(b - a), length(d - a)));
        dist = max(dist, edgeDist(p, a + normalize(d - a) * k, a + normalize(b - a) * k));
    }
    if (ubuf.shape.y > 0.0) {
        float k = min(ubuf.shape.y, 0.5 * min(length(b - c), length(d - c)));
        dist = max(dist, edgeDist(p, c + normalize(b - c) * k, c + normalize(d - c) * k));
    }
    return dist;
}

// 错位板：先平移，再绕板中心旋转，最后外扩
float slabDist(vec2 px, vec4 prm) {
    vec2 ctr = ubuf.rectPx.xy + ubuf.rectPx.zw * 0.5;
    vec2 q = px - prm.xy - ctr;
    float co = cos(prm.z), si = sin(prm.z);
    q = vec2(co * q.x + si * q.y, -si * q.x + co * q.y);
    return plateDist(q + ctr) - prm.w;
}

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 五角星的“同心层数”：p 落在缩放了多少倍的同一颗星的边上（0 = 中心，1 = 星的外沿）
// rb = 该方向上星沿到中心的距离 px（用来算抗锯齿宽度：循环里分支不一致，不能用 fwidth）
float starScale(vec2 p, float r, float rot, out float rb) {
    const float PI5 = 0.6283185;  // 2π/10，尖角与凹角之间的夹角
    float a = mod(atan(p.y, p.x) - rot, 2.0 * PI5);
    a = a > PI5 ? 2.0 * PI5 - a : a;
    vec2 A = vec2(r, 0.0);
    vec2 B = r * 0.48 * vec2(cos(PI5), sin(PI5));
    vec2 e = B - A;
    vec2 d = vec2(cos(a), sin(a));
    rb = (A.x * e.y - A.y * e.x) / (d.x * e.y - d.y * e.x);
    return length(p) / rb;
}

// 静态星星底纹（p5-reference/star-background 的定格）：网格里散落大小、角度不一的五角星，
// 每颗星由一圈圈同心星环组成，深浅两色交替；重叠时按随机层级取最上面那颗。坐标以板的顶边中点为原点，
// 面板展开变形时星星不会跟着滑动。返回 x = 覆盖度，y = 浅色环权重。
vec2 starField(vec2 p) {
    const float CELL = 150.0;
    const float RINGS = 5.0;
    vec2 cell = floor(p / CELL);
    float bestZ = -1.0;
    vec2 res = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = cell + vec2(float(i), float(j));
            if (hash12(c + 3.7) > 0.8)
                continue;
            vec2 ctr = (c + 0.15 + 0.7 * vec2(hash12(c), hash12(c + 11.3))) * CELL;
            float r = mix(52.0, 108.0, hash12(c + 23.9));
            float rb;
            float s = starScale(p - ctr, r, hash12(c + 37.1) * 6.2831853, rb);
            float fs = 0.75 / rb;
            float cov = 1.0 - smoothstep(1.0 - fs, 1.0 + fs, s);
            float z = hash12(c + 51.7);
            if (cov <= 0.0 || z < bestZ)
                continue;
            bestZ = z;
            // 外沿那一圈是浅色，往里深浅交替
            float u = (1.0 - s) * RINGS * 0.5;
            float w = fs * RINGS * 0.5;
            float light = 1.0 - smoothstep(0.25 - w, 0.25 + w, abs(fract(u + 0.25) - 0.5));
            res = vec2(cov, light);
        }
    }
    return res;
}

vec4 over(vec4 top, vec4 bottom) {
    return top + bottom * (1.0 - top.a);
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.widthPx, ubuf.heightPx);
    float d = plateDist(px);
    float fw = max(fwidth(d), 1e-4);
    float cov = 1.0 - smoothstep(-fw, fw, d);
    float bw = ubuf.shape.z;
    float covInner = bw > 0.0 ? 1.0 - smoothstep(-fw, fw, d + bw) : cov;

    // ---- 主体 ----
    vec3 body = ubuf.fillColor.rgb;
    float bodyA = ubuf.fillColor.a;
    vec2 q = px - ubuf.rectPx.xy;
    vec2 wh = max(ubuf.rectPx.zw, vec2(1.0));
    vec3 acc = ubuf.accentColor.rgb;

    // 静态星星：浅环往强调色靠一点，深环往黑压一点，都贴近底色
    if (ubuf.fx.x > 0.0) {
        vec2 st = starField(q - vec2(wh.x * 0.5, 0.0));
        vec3 tone = mix(body * (1.0 - 0.6 * ubuf.fx.x), mix(body, acc, ubuf.fx.x), st.y);
        body = mix(body, tone, st.x);
    }
    // 流动斜条纹
    if (ubuf.fx.y > 0.0) {
        float s = fract((q.x + q.y * 0.85) / 26.0 - ubuf.phase * 4.0);
        float band = smoothstep(0.0, 0.06, s) * (1.0 - smoothstep(0.42, 0.48, s));
        body = mix(body, acc, band * ubuf.fx.y * ubuf.accentColor.a);
    }
    // 流光：一条柔和的斜向光带缓慢扫过（P3 的水波感）
    if (ubuf.fx.z > 0.0) {
        float tpos = (q.x / wh.x + q.y / wh.y) * 0.5;
        float c = mix(-0.35, 1.35, ubuf.phase);
        float sheen = exp(-pow((tpos - c) / 0.14, 2.0));
        body = mix(body, acc, sheen * ubuf.fx.z * ubuf.accentColor.a);
    }
    // 左侧色条（沿左边）
    if (ubuf.fx.w > 0.0) {
        float inside = -edgeDist(px, cornerBL(), cornerTL());
        float bar = 1.0 - smoothstep(ubuf.fx.w - fw, ubuf.fx.w + fw, inside);
        body = mix(body, ubuf.accentColor.rgb, bar);
        bodyA = mix(bodyA, max(bodyA, ubuf.accentColor.a), bar);
    }
    // 内框线：距边 rimParam.x 处一圈细线
    if (ubuf.rimColor.a > 0.0) {
        float r0 = ubuf.rimParam.x, r1 = ubuf.rimParam.x + ubuf.rimParam.y;
        float rim = smoothstep(-r1 - fw, -r1 + fw, d) * (1.0 - smoothstep(-r0 - fw, -r0 + fw, d));
        body = mix(body, ubuf.rimColor.rgb, rim * ubuf.rimColor.a);
        bodyA = mix(bodyA, max(bodyA, ubuf.rimColor.a), rim);
    }

    vec4 col = vec4(body, 1.0) * (bodyA * covInner)
             + vec4(ubuf.borderColor.rgb, 1.0) * (ubuf.borderColor.a * max(0.0, cov - covInner));

    // ---- 错位板 ----
    if (ubuf.slabColor.a > 0.0) {
        float ds = slabDist(px, ubuf.slabParam);
        float fs = max(fwidth(ds), 1e-4);
        float cs = 1.0 - smoothstep(-fs, fs, ds);
        col = over(col, vec4(ubuf.slabColor.rgb, 1.0) * (ubuf.slabColor.a * cs));
    }
    if (ubuf.slab2Color.a > 0.0) {
        float ds = slabDist(px, ubuf.slab2Param);
        float fs = max(fwidth(ds), 1e-4);
        float cs = 1.0 - smoothstep(-fs, fs, ds);
        col = over(col, vec4(ubuf.slab2Color.rgb, 1.0) * (ubuf.slab2Color.a * cs));
    }
    // ---- 柔和投影 ----
    if (ubuf.shadowColor.a > 0.0) {
        float dk = plateDist(px - ubuf.shadowParam.zw) - ubuf.shadowParam.y;
        float bk = max(ubuf.shadowParam.x, fw);
        float covK = 1.0 - smoothstep(-bk, bk, dk);
        col = over(col, vec4(ubuf.shadowColor.rgb, 1.0) * (ubuf.shadowColor.a * covK));
    }
    fragColor = col * ubuf.qt_Opacity;
}
