# p5lock — P5 风格锁屏

Persona 5 风格的锁屏：沿屏幕对角线的主色斜块里输入密码，左上是“勒索信”拼贴字的用户名，右下是时间日期，右下角可拉出电源菜单。基于 Wayland `ext-session-lock`（Quickshell `WlSessionLock`），由合成器保证安全上锁；认证走自带的 PAM 配置。

## 功能

- **一次性进程**：`qs -n -c p5lock` 启动即在所有屏幕上锁，解锁动画播完即退出；`-n` 保证不会重复启动。
- **输入**：字块弹入 / 弹出、带拖影的光标；`Enter` 提交，`Backspace` 删一个字，`Esc` / `Ctrl+U` / `Ctrl+Backspace` 清空（字块炸散）。
- **状态**：验证中显示 `VERIFYING`；密码错误时斜块闪红、画面抖动并盖上 `WRONG PASSWORD` 印章；Caps Lock 打开时显示 `CAPS LOCK`（轮询 `/sys/class/leds/*::capslock`）。
- **信息**：用户名取自 `$USER`，主机名取自 `/etc/hostname`，均为运行时读取。
- **电源菜单**：点右下角箭头方块拉出“予告信”信封，三张卡片：关机、重启需要再点一次确认（`SURE?`），挂起直接执行；也可用 `←` `→` 选择、`Enter` 触发、`Esc` 收起。动作通过 `systemctl poweroff|reboot|suspend` 执行。
- **解锁转场**：PAM 成功 → 斜块铺开成满屏斜条 → 解除 session lock → 在 Overlay 层上斜条交错滑出，露出实时桌面 → 进程退出。
- **配色与背景**：跟随 DMS 的 matugen 色板（`~/.cache/DankMaterialShell/dms-colors.json`）；背景是当前壁纸的模糊压暗版（读 DMS 的 `~/.local/state/DankMaterialShell/session.json`，支持分屏壁纸）。没有 DMS 时使用内置配色、纯色背景。

## 文件

```
shell/                 → ~/.config/quickshell/p5lock/
├── shell.qml          入口：WlSessionLock、PAM、Caps Lock 检测、解锁 overlay
├── LockScene.qml      单块屏幕上的锁屏画面
├── PasswordRow.qml    密码字块行 + 拖影光标
├── RansomText.qml     勒索信式拼贴字（用户名）
├── PowerMenu.qml      电源菜单
├── StripeCover.qml    解锁转场斜条（锁屏表面与 overlay 共用）
├── Theme.qml          配色、字体、壁纸路径（单例）
├── demo.qml           预览：普通窗口，不会真的锁屏
├── p5lock.sh          启动脚本（DMS 的 Custom Lock Command 指向它）
└── pam/p5lock         自带 PAM 配置（pam_unix 校验当前用户密码）
niri/p5lock.kdl        → ~/.config/niri/p5lock.kdl（可选：先上锁再挂起的快捷键）
```

`p5lock.sh` 的行为：

- `p5lock.sh`：若锁屏未在运行，用 `setsid` 脱离启动 `qs -n -c p5lock`，立即返回。
- `p5lock.sh --wait`：启动后等待合成器确认已安全上锁（锁屏写出标记文件 `$XDG_RUNTIME_DIR/p5lock.secure`）再返回，最多等 5 秒，超时返回非 0。用于 `p5lock.sh --wait && systemctl suspend`，保证挂起前屏幕已锁好。

## 依赖（Arch 包名）

- `quickshell`（推荐 `quickshell-git`；需要 `Quickshell.Services.Pam` 与 Wayland session lock 支持）
- 支持 `ext-session-lock-v1` 的合成器（niri 支持）
- `pam`（系统自带；`pam_unix` 以非 root 身份校验密码依赖其自带的 `unix_chkpwd` 辅助程序，Arch 默认即可用）
- 字体：
  - `adwaita-fonts`（Adwaita Sans：时间、大字）
  - `gsfonts`（Nimbus Sans Narrow、Nimbus Roman、C059：标签与拼贴字）
  - `otf-font-awesome`（Font Awesome 7 Free：电源菜单图标）
- `dms-shell`（可选，提供配色、壁纸和锁屏入口）

## 安装步骤

1. 检查依赖。字体缺失时画面会走样。
2. 复制：`cp -a p5lock/shell ~/.config/quickshell/p5lock`（目标已存在先备份），确认 `~/.config/quickshell/p5lock/p5lock.sh` 有可执行权限。
3. **预览**（普通窗口，不会真的锁屏）：
   ```sh
   qs -p ~/.config/quickshell/p5lock/demo.qml
   ```
   预览里输入 `fail` 回车演示失败，输入其他任意内容回车演示解锁动画；空密码时按 `Esc` 退出。电源菜单在预览里只打日志，不会真的关机。可用 `P5LOCK_SIZE=1920x1080` 指定窗口尺寸，`P5LOCK_SCREEN=<输出名>` 指定读取哪块屏幕的壁纸。
4. **接入 DMS**（让 DMS 的所有锁屏入口改为拉起 p5lock，包括 `dms ipc call lock lock`、DMS 界面里的锁屏按钮、开启 loginctl 集成时的 `loginctl lock-session`）：
   - 在 DMS 设置里填：**Settings → Power & Sleep → Custom Power Actions → Custom Lock Command**，填入脚本的绝对路径，例如 `/home/<用户名>/.config/quickshell/p5lock/p5lock.sh`。
   - 或者编辑 `~/.config/DankMaterialShell/settings.json`，把 `"customPowerActionLock"` 设为上述绝对路径。DMS 会自动热重载该文件。
   - 还原：把该项清空即恢复 DMS 自带锁屏。
5. （可选）接入 niri 挂起快捷键：复制 `niri/p5lock.kdl` 到 `~/.config/niri/`，在 `config.kdl` 追加 `include "p5lock.kdl"`。它绑定 `Mod+Alt+P` = 先上锁再挂起；DMS 默认的 `binds.kdl` 可能已占用此键，先 `grep -rn 'Mod+Alt+P' ~/.config/niri/` 检查，冲突时换键或替换原绑定，最后 `niri validate`。

## 验证

```sh
test -x ~/.config/quickshell/p5lock/p5lock.sh && echo ok
test -f ~/.config/quickshell/p5lock/pam/p5lock && echo ok
fc-list | grep -E 'Adwaita Sans|Nimbus Sans Narrow|C059|Font Awesome 7 Free' | wc -l   # 应 > 0
grep -n customPowerActionLock ~/.config/DankMaterialShell/settings.json
dms ipc call lock lock                          # 应出现 p5lock 锁屏，输入密码解锁
```

## 注意事项

- ext-session-lock 下锁屏进程在解锁前退出时，合成器会保持锁定（通常显示纯色画面）。
- 认证用自带的 `pam/p5lock`，`PamContext` 从配置目录读取，不依赖 `/etc/pam.d` 里的服务文件。当前内容只用 `pam_unix` 校验当前用户密码（`nullok` 允许空密码账户；界面本身不提交空输入）。
- DMS 拉起自定义锁屏时不检查它是否真的启动成功。如果 `qs` 不可用、配置目录名不对或脚本没有可执行权限，DMS 的锁屏入口会“什么都不发生”，屏幕不会被锁。
