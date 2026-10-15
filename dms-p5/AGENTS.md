# dms-p5 — PHANTOM VIOLET（女神异闻录风格的 DMS 改造）

不是独立的 Quickshell 配置，而是对 DMS 内置 UI 的**补丁包**：上游 UI + `patches/` + `overlay/` → `~/.local/share/dms-p5/shell`，
再让 niri 用 `dms run -c <该目录>` 启动。DMS 的服务、设置、IPC 全部照常工作。

## 依赖

- `dms-shell`（补丁基于 `patches/BASE_VERSION`，当前 v1.6.3；版本不同时 `./build.sh --check` 会报出失败的补丁）
- `qt6-shadertools`（`qsb` 编译 `p5_plate.frag`）、`patch`、`python3`
- DMS 的 Dank Island 顶栏模式（拉绳与勒索信时钟挂在岛上；普通栏也能用，只是没有这两样）

## 安装 / 还原

```sh
./enable.sh            # 构建 → 改 niri 的 spawn-at-startup → 立即以 P5 UI 重启 DMS（不动配色）
./enable.sh --theme    # 另外启用 theme/phantom-violet.json（浅粉紫）。默认沿用 DMS 原本的主题色
./disable.sh           # 改回内置 UI 并重启；配色若由 --theme 改过也会还原
```

第一次构建需要上游原版：先用原版 `dms run` 跑过一次（会解压到 `/run/user/$UID/danklinux-shell/`），之后会缓存到 `~/.local/share/dms-p5/upstream/`。

## 设计约定（改样式前先读）

- 主色 = 主题 primary（默认 `#D0BCFF`，偏粉的浅紫，和 niri 边框同色）；它是浅色，上面的字用墨色。
  黑、白、粉、梅紫都从它派生，见 `overlay/DankCommon/Common/P5.qml`。
- **红色（`P5.blood`）只用于动效瞬间**（按下闪红、拉绳闪红）和紧急状态，不做常驻底色或错位板。
- 栏上不要大面积纯黑：组件底色是梅紫（`P5.plum`），粗白框 + 黑色内线。
- 所有造型走 `P5Plate`（不规则四边形、切角、内框线、两层可旋转的错位板、网点/条纹）；弹出面板统一由
  `DankCommon/Common/ElevationShadow.qml` 画。

## 开发

`work/shell` 是上游 UI 的 git 工作副本（不入库）：`scripts/dev.sh init` 建立，改完 `scripts/dev.sh go`（导出补丁 + 构建 + 重启；
主界面没起来时自动跑 `scripts/qmlcheck.sh`——`dms run` 会吞掉 QML 警告，它直接用 `qs -p` 跑一遍收集）。
`scripts/preview.sh kit` 在背景层离屏渲染组件总览到 `/tmp/p5shots/kit.png`，不打扰前台窗口、不碰剪贴板。

截图验证（都在 eDP-1 上，不碰剪贴板，完成后把焦点还给原显示器）：

- `scripts/grab.sh <名字> [输出]`：截整块屏到 `/tmp/p5shots/<名字>.png`，`P5_CROP=WxH+X+Y` 按逻辑像素裁剪。
- `scripts/look.sh <名字> <ipc 参数…>`：调 IPC 打开面板 → 截图 → 关闭。例：`look.sh home dash open overview`、
  `look.sh weather dash open weather`、`look.sh media dash open media`、`look.sh cc control-center open`、
  `look.sh chat notifications open`、`P5_WAIT=1.6 look.sh apps spotlight open`、
  `look.sh clip widget toggle clipboard`、`look.sh dossier widget toggle focusedWindow`、`look.sh proc widget toggle cpuUsage`。
  DMS 刚重启时岛还没就绪，第一次调用可能打不开，等几秒再试。
- `scripts/notify-test.sh [名字]`：发一条带动作的测试通知并截下岛下方掉出的 P5 短信。
- `P5_SRC=$PWD/work/shell P5_W=1706 P5_H=1066 P5_DELAY=1800 scripts/preview.sh apps`：离屏渲染应用列表（假数据，
  `P5_APPS=insert|query|empty`、`P5_SEL=n` 切状态）；`preview.sh vimtest` 用合成按键跑一遍 vim 键位，日志里看 `VIM ok/FAIL`。

P5 页面都在 `overlay/Modules/P5/`（主页、左轮菜单、通缉令剪贴板、窗口档案、手机聊天通知与新通知（共用 `P5SmsBubble` 短信气泡）、音乐页、天气页、
性能情报板、栏上的读数），共用造型在 `overlay/DankCommon/Widgets/P5*.qml`；上游文件只改接线（补丁）。
不要用宽泛的 `pkill qs`：用户还在跑 `qs -c kanban` / `qs -c music`。

应用列表：`Mod+Z`（`dms ipc call spotlight toggle`）打开全屏的 P5R 存档界面式列表（`Modules/P5/P5Apps.qml` 单例 →
`P5AppsWindow` → `P5AppCarousel`，几何移植自 `p5-reference/save-carousel`，红色换成主题淡紫）。补丁只改了 `DMSShellIPC.qml`
里 spotlight 的 open/close/toggle/openQuery/toggleQuery；`launcher` 目标和按模式打开（openWith/toggleWith）仍是原版启动器。
数据与搜索走启动器的 `Controller`（应用模式），每条只显示图标、名字、简介。栏左上的 `launcherButton`（左轮菜单入口）已从 DMS 设置里移除。
键位是单行 vim：普通模式 `j/k`、`gg/G`、`Ctrl-d/u` 选，`Enter` 启动，`i/a/I/A//` 进插入模式（标题位置拉出搜索长条，
`Enter` 启动、`↑↓`/`Ctrl-j/k` 选）；`Esc` 回普通模式后长条保留，可用 `h/l/w/b/e/0/^/$`、`x/X/s/S/D/C`、`d/c/y` + 动作或 `iw/aw`、
`p/P/r/~/u/Ctrl-r` 编辑搜索词；普通模式再按 `Esc`（或 `q`）关闭。

通知：铃铛常驻在岛上（`IslandController.homeNotificationBadge` 不再要求有未读），栏右侧的 `notificationButton` 应从
DMS 设置里移除，避免重复。
