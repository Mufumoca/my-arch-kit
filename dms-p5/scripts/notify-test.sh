#!/usr/bin/env bash
# 在 eDP-1 上发一条测试通知并截图（开发用）。 scripts/notify-test.sh [名字] [等待秒数]
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
prev="$(niri msg -j focused-output | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["name"])')"
niri msg action focus-monitor eDP-1
(timeout 25 notify-send -t 15000 -a "Telegram" -A "view=View" -A "reply=Reply" "Ryuji Sakamoto" "Yo, we're meeting at the hideout after school. Don't be late, Joker! 今天放学后在秘密基地集合。" >/dev/null 2>&1 &)
sleep "${2:-1.4}"
P5_CROP="${P5_CROP:-900x420+400+0}" "$PKG/scripts/grab.sh" "${1:-paper}"
[ "$prev" = eDP-1 ] || niri msg action focus-monitor "$prev"
