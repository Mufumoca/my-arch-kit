#!/usr/bin/env bash
# 在 eDP-1 上打开某个面板 → 截图 → 关闭，然后把焦点还给原来的显示器。开发用。
#   scripts/look.sh <名字> <ipc target> <function> [参数...]
#   P5_SCREEN（默认 eDP-1）、P5_WAIT（打开后等待秒数，默认 0.9）、P5_KEEP=1 不关闭
#   P5_CLOSE="<ipc 参数>" 自定义关闭命令（默认 <target> close；widget 目标默认再 toggle 一次）
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
SCREEN="${P5_SCREEN:-eDP-1}"
name="$1"; shift
prev="$(niri msg -j focused-output | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["name"])')"
[ "$prev" = "$SCREEN" ] || niri msg action focus-monitor "$SCREEN"
if [ $# -gt 0 ]; then dms ipc call "$@" >/dev/null; fi
sleep "${P5_WAIT:-0.9}"
"$PKG/scripts/grab.sh" "$name" "$SCREEN"
if [ "${P5_KEEP:-0}" != 1 ] && [ $# -gt 0 ]; then
    if [ -n "${P5_CLOSE:-}" ]; then
        # shellcheck disable=SC2086
        dms ipc call $P5_CLOSE >/dev/null 2>&1 || true
    else
        case "$1" in
        widget) dms ipc call widget toggle "$3" >/dev/null 2>&1 || true ;;
        control-center) dms ipc call control-center hide >/dev/null 2>&1 || true ;;
        *) dms ipc call "$1" close >/dev/null 2>&1 || true ;;
        esac
    fi
fi
[ "$prev" = "$SCREEN" ] || niri msg action focus-monitor "$prev"
