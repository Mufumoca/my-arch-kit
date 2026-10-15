import QtQuick
import qs.DankCommon.Common

// 锯齿爆炸框：spikes 个尖角的星形，尖角长度随机抖动（P5 手机里头像的白色锯齿框、强调用的爆炸贴）。
P5Poly {
    id: root

    property int spikes: 14
    property real depth: 0.16       // 内外半径比的差（0..1）
    property int seed: 7
    property real spin: 0           // 度

    points: {
        const out = [];
        const cx = width / 2, cy = height / 2;
        const rx = width / 2, ry = height / 2;
        const n = spikes * 2;
        for (let i = 0; i < n; i++) {
            const a = (i / n) * Math.PI * 2 + spin * Math.PI / 180;
            const outer = i % 2 === 0;
            const r = outer ? 1 - Math.abs(P5.rand(seed, i)) * depth * 0.4 : 1 - depth;
            out.push([cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r]);
        }
        return out;
    }
}
