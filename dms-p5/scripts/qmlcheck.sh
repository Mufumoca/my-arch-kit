#!/usr/bin/env bash
# 诊断：停掉 DMS，直接用 qs 跑一遍已安装的 UI 收集 QML 警告（`dms run` 下这些警告会被吞掉），然后恢复 DMS。
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5/shell"
pkill -x dms 2>/dev/null || true
sleep 0.5
for p in $(pgrep -f "^qs -p $DEST\$" || true); do kill "$p"; done
sleep 0.5
(cd /tmp && DMS_GREETER_AUTH_TIME=4102444800 timeout "${1:-12}" qs -p "$DEST" >/tmp/p5check.log 2>&1 </dev/null) || true
grep -E 'WARN.*(scene|qml)|ERROR' /tmp/p5check.log | grep -vE 'Theme worker|CacheData|textinput' | sort -u | head -40 || true
"$PKG/scripts/dev.sh" restart >/dev/null
