#!/usr/bin/env bash
# 启用 PHANTOM VIOLET：构建并安装 UI、安装配色、让 niri 以 `dms run -c` 启动、立即重启 DMS
#
#   ./enable.sh               完整启用
#   ./enable.sh --no-build    跳过构建（已经 ./build.sh 过）
#   ./enable.sh --no-restart  只改配置，不立即重启 DMS（下次登录生效）
#   ./enable.sh --theme       额外启用固定的 Phantom Violet 配色（默认不动配色，沿用你现有的 DMS 主题）
#
# 还原见 ./disable.sh。所有改动前都会备份：
#   ~/.config/niri/config.kdl.bak-dms-p5
#   ~/.config/DankMaterialShell/settings.json.bak-dms-p5
set -euo pipefail

PKG="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5"
SHELL_DIR="$DATA/shell"
DMS_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
NIRI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
THEME="$DMS_CFG/themes/phantom-violet.json"
BUILD=1
RESTART=1
THEME_ON=0

for a in "$@"; do
    case "$a" in
    --no-build) BUILD=0 ;;
    --no-restart) RESTART=0 ;;
    --theme) THEME_ON=1 ;;
    *) echo "未知参数：$a" >&2; exit 2 ;;
    esac
done

[ "$BUILD" = 1 ] && "$PKG/build.sh"
[ -f "$SHELL_DIR/shell.qml" ] || { echo "enable: $SHELL_DIR 不存在，先运行 ./build.sh" >&2; exit 1; }

# 1. 配色（可选）：DMS 自定义主题（同时作为 matugen 种子，音乐卡片 / 看板 / p5lock 也会跟着变）
if [ "$THEME_ON" = 1 ]; then
mkdir -p "$DMS_CFG/themes"
cp "$PKG/theme/phantom-violet.json" "$THEME"
python3 -I - "$DMS_CFG/settings.json" "$THEME" "$DATA/prev-theme.json" <<'EOF'
import json, os, shutil, sys
path, theme, prev = sys.argv[1:4]
d = json.load(open(path)) if os.path.exists(path) else {}
if os.path.exists(path) and not os.path.exists(path + ".bak-dms-p5"):
    shutil.copy2(path, path + ".bak-dms-p5")
if not os.path.exists(prev):
    json.dump({k: d.get(k) for k in ("currentThemeName", "customThemeFile")}, open(prev, "w"))
d["currentThemeName"] = "custom"
d["customThemeFile"] = theme
tmp = path + ".tmp-dms-p5"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
EOF
echo "enable: 配色 → $THEME"
fi

# 2. niri：spawn-at-startup "dms" "run" → 加上 -c <P5 UI>
if [ -f "$NIRI_CFG" ]; then
    [ -f "$NIRI_CFG.bak-dms-p5" ] || cp "$NIRI_CFG" "$NIRI_CFG.bak-dms-p5"
    python3 -I - "$NIRI_CFG" "$SHELL_DIR" <<'EOF'
import re, sys
path, shell = sys.argv[1:3]
s = open(path).read()
line = f'spawn-at-startup "dms" "run" "-c" "{shell}"'
pat = re.compile(r'^(\s*)spawn-at-startup\s+"dms"\s+"run"[^\n]*$', re.M)
if pat.search(s):
    s = pat.sub(lambda m: m.group(1) + line, s, count=1)
else:
    s += "\n" + line + "\n"
open(path, "w").write(s)
EOF
    if ! niri validate -c "$NIRI_CFG" >/dev/null 2>&1; then
        cp "$NIRI_CFG.bak-dms-p5" "$NIRI_CFG"
        echo "enable: niri validate 失败，已还原 config.kdl" >&2
        exit 1
    fi
    echo "enable: niri → $(grep -n 'spawn-at-startup "dms"' "$NIRI_CFG")"
fi

# 3. 立即切换。DMS_GREETER_AUTH_TIME 设为未来时间，让这次重启（及之后的热重载）不触发“启动时锁屏”
if [ "$RESTART" = 1 ]; then
    pkill -x dms 2>/dev/null || true
    for _ in $(seq 50); do pgrep -x dms >/dev/null || break; sleep 0.1; done
    DMS_GREETER_AUTH_TIME=4102444800 setsid -f dms run -c "$SHELL_DIR" >/dev/null 2>&1 </dev/null
    echo "enable: DMS 已以 PHANTOM VIOLET 重启"
fi
