#!/usr/bin/env bash
# 截取某个输出到 PNG（不碰剪贴板、不切焦点）。开发用。
#   scripts/grab.sh [名字] [输出名，默认 eDP-1]   → /tmp/p5shots/<名字>.png
#   P5_CROP=WxH+X+Y   按逻辑像素裁剪（输出统一缩放到逻辑尺寸，eDP-1 为 1706x1066）
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /tmp/p5shots
OUT="/tmp/p5shots/${1:-grab}.png"
P5_SCREEN="${2:-eDP-1}" P5_OUT="$OUT" timeout 10 qs -p "$PKG/preview/grab" >/tmp/p5grab.log 2>&1 || { tail -5 /tmp/p5grab.log; exit 1; }
# 统一缩放到逻辑尺寸，再按需裁剪
LW="$(niri msg -j outputs | python3 -I -c 'import json,sys; o=json.load(sys.stdin)[sys.argv[1]]; print(o["logical"]["width"])' "${2:-eDP-1}")"
magick "$OUT" -resize "${LW}x" ${P5_CROP:+-crop "$P5_CROP" +repage} "$OUT"
echo "$OUT"
