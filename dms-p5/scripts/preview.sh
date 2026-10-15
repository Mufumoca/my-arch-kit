#!/usr/bin/env bash
# 离屏预览（不参与安装）：把 preview/ 叠到已构建的 UI 副本上，渲染一个场景到 PNG。
#   scripts/preview.sh <场景> [输出.png]     场景见 preview/scenes/*.qml
# 环境变量：P5_SRC（默认已构建的副本，开发时可指向 work/shell）、P5_SCREEN（默认 eDP-1）、P5_W、P5_H、P5_BG、P5_DELAY
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${P5_SRC:-${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5/shell}"
TMP="$(mktemp -d /tmp/p5prev.XXXX)"
trap 'rm -rf "$TMP"' EXIT
cp -a "$SRC/DankCommon" "$TMP/"
mkdir -p "$TMP/Modules" && cp -a "$SRC/Modules/P5" "$TMP/Modules/"
cp -a "$PKG/preview/shell.qml" "$PKG/preview/scenes" "$TMP/"
mkdir -p /tmp/p5shots
OUT="${2:-/tmp/p5shots/$1.png}"
P5_PREVIEW="$1" P5_OUT="$OUT" P5_SCREEN="${P5_SCREEN:-eDP-1}" timeout 20 qs -p "$TMP" >"$TMP.log" 2>&1 || { tail -20 "$TMP.log"; exit 1; }
grep -E "ERROR|WARN.*qml" "$TMP.log" | head -10 || true
rm -f "$TMP.log"
echo "$OUT"
