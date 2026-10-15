#!/usr/bin/env bash
# 还原：niri 改回内置 UI 启动、配色改回启用前的设置、以原版 DMS 重启。
# 不删除 ~/.local/share/dms-p5（可随时 ./enable.sh --no-build 再切回来）。
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5"
DMS_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
NIRI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"

if [ -f "$NIRI_CFG" ]; then
    python3 -I - "$NIRI_CFG" <<'EOF'
import re, sys
path = sys.argv[1]
s = open(path).read()
s = re.sub(r'^(\s*)spawn-at-startup\s+"dms"\s+"run"\s+"-c"\s+"[^"]*"\s*$', r'\1spawn-at-startup "dms" "run"', s, flags=re.M)
open(path, "w").write(s)
EOF
    niri validate -c "$NIRI_CFG" >/dev/null && echo "disable: niri → $(grep -n 'spawn-at-startup "dms"' "$NIRI_CFG")"
fi

if [ -f "$DATA/prev-theme.json" ] && [ -f "$DMS_CFG/settings.json" ]; then
    python3 -I - "$DMS_CFG/settings.json" "$DATA/prev-theme.json" <<'EOF'
import json, os, sys
path, prev = sys.argv[1:3]
d = json.load(open(path))
for k, v in json.load(open(prev)).items():
    if v is None:
        d.pop(k, None)
    else:
        d[k] = v
tmp = path + ".tmp-dms-p5"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
EOF
    rm -f "$DATA/prev-theme.json"
    echo "disable: 配色已还原"
fi

pkill -x dms 2>/dev/null || true
for _ in $(seq 50); do pgrep -x dms >/dev/null || break; sleep 0.1; done
DMS_GREETER_AUTH_TIME=4102444800 setsid -f dms run >/dev/null 2>&1 </dev/null
echo "disable: 已以原版 DMS 重启"
