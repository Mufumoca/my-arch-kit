#!/bin/sh
# 启动 P5 锁屏。DMS 的 customPowerActionLock 指向本脚本。
#   p5lock.sh          立即返回
#   p5lock.sh --wait   等到合成器确认上锁（适合 `p5lock.sh --wait && systemctl suspend`）
marker="${XDG_RUNTIME_DIR:-/tmp}/p5lock.secure"

if ! pgrep -f 'qs -n -c p5lock' >/dev/null 2>&1; then
    rm -f "$marker"
    setsid -f qs -n -c p5lock >/dev/null 2>&1
fi

[ "$1" = "--wait" ] || exit 0

i=0
while [ ! -e "$marker" ]; do
    i=$((i + 1))
    [ "$i" -gt 50 ] && exit 1
    sleep 0.1
done
