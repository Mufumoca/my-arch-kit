#!/usr/bin/env bash
# 开发辅助（不参与安装）。work/shell 是上游 UI 的 git 工作副本，在里面改代码：
#
#   scripts/dev.sh init [<上游目录>]   建立 work/shell（上游原版 + git 基线）
#   scripts/dev.sh export              work/shell 的改动 → patches/（每个文件一个补丁）与 overlay/（新增文件）
#   scripts/dev.sh restart             以 $DEST 重启 DMS（跳过 lockAtStartup），日志写 /tmp/dms-p5.log
#   scripts/dev.sh stock               以内置原版 UI 重启 DMS
#   scripts/dev.sh shot <名字>          截取当前聚焦屏幕到 /tmp/p5shots/<名字>.png
#   scripts/dev.sh go                  export + build + restart；DMS 主界面没加载起来时自动跑 scripts/qmlcheck.sh 报错
set -euo pipefail

PKG="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$PKG/work/shell"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5/shell"

start_dms() {
    pkill -x dms 2>/dev/null || true
    for _ in $(seq 50); do pgrep -x dms >/dev/null || break; sleep 0.1; done
    pkill -f 'qs -p /run/user/.*/danklinux-shell' 2>/dev/null || true
    pkill -f "qs -p $DEST" 2>/dev/null || true
    sleep 0.3
    # DMS_GREETER_AUTH_TIME 设为未来时间：Lock.qml 视为刚经 greeter 登录，重启 / 热重载都不触发 lockAtStartup
    DMS_GREETER_AUTH_TIME=4102444800 setsid -f dms run "$@" >/tmp/dms-p5.log 2>&1 </dev/null
}

case "${1:-}" in
init)
    src="${2:-$(ls -d "${XDG_DATA_HOME:-$HOME/.local/share}"/dms-p5/upstream/"$(cat "$PKG/patches/BASE_VERSION")")}"
    rm -rf "$WORK"
    mkdir -p "$(dirname "$WORK")"
    cp -a "$src" "$WORK"
    chmod -R u+w "$WORK"
    git -C "$WORK" init -q
    git -C "$WORK" add -A
    git -C "$WORK" -c user.name=upstream -c user.email=upstream@local commit -qm "upstream $(cat "$WORK/VERSION")"
    find "$PKG/patches" -name '*.patch' | sort | while read -r p; do patch -d "$WORK" -p1 --batch -s <"$p"; done
    cp -a "$PKG/overlay/." "$WORK/"
    echo "work/shell 已就绪"
    ;;
export)
    cd "$WORK"
    find "$PKG/patches" -name '*.patch' -delete
    git diff --name-only | while read -r f; do
        git diff --no-color -- "$f" >"$PKG/patches/$(echo "$f" | tr '/' '_').patch"
    done
    rm -rf "$PKG/overlay"
    mkdir -p "$PKG/overlay"
    git ls-files --others --exclude-standard | grep -v '\.qsb$' | while read -r f; do
        mkdir -p "$PKG/overlay/$(dirname "$f")"
        cp -a "$f" "$PKG/overlay/$f"
    done
    echo "patches: $(find "$PKG/patches" -name '*.patch' | wc -l)  overlay: $(find "$PKG/overlay" -type f | wc -l)"
    ;;
restart)
    start_dms -c "$DEST"
    echo "DMS 以 $DEST 重启，日志 /tmp/dms-p5.log"
    ;;
stock)
    start_dms
    echo "DMS 以内置 UI 重启"
    ;;
shot)
    mkdir -p /tmp/p5shots
    niri msg action screenshot-screen -p false --path "/tmp/p5shots/${2:-shot}.png"
    sleep 1.2
    echo "/tmp/p5shots/${2:-shot}.png"
    ;;
go)
    "$0" export
    "$PKG/build.sh" --check
    # 先停掉 DMS 再替换安装目录，避免热重载在半成品上触发
    pkill -x dms 2>/dev/null || true
    "$PKG/build.sh"
    "$0" restart
    for _ in $(seq 20); do
        sleep 1
        [ "$(qs -p "$DEST" ipc show 2>/dev/null | grep -c '^target')" -gt 20 ] && { echo "DMS 主界面已加载"; exit 0; }
    done
    echo "DMS 主界面没有加载起来，诊断："
    "$PKG/scripts/qmlcheck.sh"
    ;;
*)
    sed -n '2,10p' "$0"
    exit 2
    ;;
esac
