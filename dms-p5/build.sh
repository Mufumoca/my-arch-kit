#!/usr/bin/env bash
# 构建 PHANTOM VIOLET 版 DMS UI：上游 UI + patches/ + overlay/ → $DEST
#
#   ./build.sh                      自动定位上游 UI（见下）并安装到 ~/.local/share/dms-p5/shell
#   ./build.sh --upstream <dir>     指定上游 UI 目录（含 shell.qml 与 VERSION）
#   ./build.sh --dest <dir>         指定安装目录
#   ./build.sh --check              只检查补丁能否干净应用，不安装
#
# 上游 UI 的来源（按顺序）：
#   1. --upstream 参数
#   2. ~/.local/share/dms-p5/upstream/<版本>/（之前缓存的原版）
#   3. /run/user/$UID/danklinux-shell/*/ 中 VERSION 与已安装 dms-shell 一致的目录
#      （内置 UI 由 `dms run` 运行时解压到这里；用 -c 启动时不会解压，所以第一次构建时缓存一份）
set -euo pipefail

PKG="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/dms-p5"
DEST="$DATA/shell"
UPSTREAM=""
CHECK_ONLY=0
QSB="${QSB:-/usr/lib/qt6/bin/qsb}"

while [ $# -gt 0 ]; do
    case "$1" in
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
    esac
done

die() { echo "build: $*" >&2; exit 1; }

BASE="$(cat "$PKG/patches/BASE_VERSION")"
INSTALLED="v$(pacman -Q dms-shell 2>/dev/null | awk '{print $2}' | sed 's/-[0-9]*$//')"

if [ -z "$UPSTREAM" ]; then
    if [ -f "$DATA/upstream/$INSTALLED/shell.qml" ]; then
        UPSTREAM="$DATA/upstream/$INSTALLED"
    else
        for d in /run/user/"$(id -u)"/danklinux-shell/*/; do
            if [ -f "$d/VERSION" ] && [ "$(cat "$d/VERSION")" = "$INSTALLED" ]; then
                UPSTREAM="${d%/}"
                break
            fi
        done
    fi
fi
[ -n "$UPSTREAM" ] && [ -f "$UPSTREAM/shell.qml" ] ||
    die "找不到 $INSTALLED 的上游 UI。先用原版 \`dms run\` 启动一次（会解压到 /run/user/$(id -u)/danklinux-shell/），或用 --upstream 指定。"

UPVER="$(cat "$UPSTREAM/VERSION" 2>/dev/null || echo unknown)"
if [ "$UPVER" != "$BASE" ]; then
    echo "build: 警告：补丁基于 $BASE，上游是 $UPVER；下面若有补丁失败，需要按新版本重新适配。" >&2
fi

# 缓存原版，之后即使不再用内置 UI 启动也能重建
if [ "$UPSTREAM" != "$DATA/upstream/$UPVER" ] && [ ! -f "$DATA/upstream/$UPVER/shell.qml" ]; then
    mkdir -p "$DATA/upstream"
    cp -a "$UPSTREAM" "$DATA/upstream/$UPVER.tmp"
    chmod -R u+w "$DATA/upstream/$UPVER.tmp"
    mv "$DATA/upstream/$UPVER.tmp" "$DATA/upstream/$UPVER"
    echo "build: 已缓存上游 $UPVER → $DATA/upstream/$UPVER"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/shell"
cp -a "$UPSTREAM" "$OUT"
chmod -R u+w "$OUT"
rm -rf "$OUT/.git"

failed=0
while IFS= read -r p; do
    if ! patch -d "$OUT" -p1 --forward --batch --no-backup-if-mismatch -r - <"$p" >"$TMP/patch.log" 2>&1; then
        echo "build: 补丁失败：${p#"$PKG"/}" >&2
        sed 's/^/    /' "$TMP/patch.log" >&2
        failed=1
    fi
done < <(find "$PKG/patches" -name '*.patch' | sort)
[ "$failed" = 0 ] || die "有补丁未能应用，已中止（未改动 $DEST）。"

cp -a "$PKG/overlay/." "$OUT/"

# 编译新增着色器：*/Shaders/frag/p5_*.frag → */Shaders/qsb/p5_*.frag.qsb
while IFS= read -r f; do
    q="$(dirname "$(dirname "$f")")/qsb/$(basename "$f").qsb"
    mkdir -p "$(dirname "$q")"
    "$QSB" --qt6 -o "$q" "$f" >/dev/null || die "着色器编译失败：$f"
done < <(find "$OUT" -path '*/Shaders/frag/p5_*.frag')

echo "P5 PHANTOM VIOLET on $UPVER" >"$OUT/P5_BUILD"

if [ "$CHECK_ONLY" = 1 ]; then
    echo "build: 检查通过（$UPVER）。"
    exit 0
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST.prev"
[ -d "$DEST" ] && mv "$DEST" "$DEST.prev"
cp -a "$OUT" "$DEST"
echo "build: 已安装到 $DEST"
