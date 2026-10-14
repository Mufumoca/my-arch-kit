# kanban — 看板

一个快捷键呼出的覆盖层看板。常驻后台，按 `Mod+;` 在**当前聚焦的显示器**上从顶部滑入，再按一次收起。

## 功能

- **看板页**：TODO / DOING / DONE 三列。
  - 每列标题右侧 `+` 新建卡片（任务名 → Enter → 描述 → Enter 添加；描述里 Shift+Enter 换行）。
  - 拖动卡片可在列内排序或跨列移动，插入位置有指示线。
  - 双击卡片或悬停后点 ✎ 编辑，点 ✕ 删除；DONE 列有“清空”按钮。
- **每日页**（`Tab` 切换）：每日任务模板 + 刷新时间点（如 `08:00 14:00 20:00`，也接受 `8`、`20.15`、中文冒号等写法）。到达任一时间点时，该任务会被重置回 TODO 顶部（带 ↻ 标记）；删除模板会一并删除它在看板上的实例。
- 打开期间通过 ShortcutInhibitor 暂停 niri 快捷键，`Mod+Q` 等按键交给看板处理（`Mod+Q` = 关闭看板）；`Mod+;` 带 `allow-inhibiting=false`，始终可用。
- `Esc`、`Mod+Q`、点击面板外部都会收起看板。
- 面板背后有模糊效果（需合成器支持背景模糊；不支持时为普通半透明背景），配色实时跟随 DMS。

### IPC

```sh
qs ipc -c kanban call kanban toggle | open | close
```

## 文件

```
shell/                → ~/.config/quickshell/kanban/
├── shell.qml         覆盖层窗口、动画、键盘、拖拽命中检测、IPC
├── Store.qml         数据、持久化、每日任务刷新、拖拽状态（单例）
├── Theme.qml         DMS 配色 + 字体（单例）
├── KanbanColumn.qml / Card.qml / DailyView.qml / Field.qml / IconButton.qml
niri/kanban.kdl       → ~/.config/niri/kanban.kdl（自启 + Mod+; 快捷键）
```

数据文件：`~/.local/share/kanban/board.json`（原子写入；目录不存在时自动创建）。格式：

```json
{ "version": 1, "tasks": [{ "id": "…", "title": "…", "desc": "…", "status": "todo|doing|done", "daily": "模板 id（可选）" }],
  "dailies": [{ "id": "…", "title": "…", "desc": "…", "times": ["08:00"], "last": 0 }] }
```

## 依赖（Arch 包名）

- `quickshell`（推荐 `quickshell-git`；用到了 `BackgroundEffect`、`ShortcutInhibitor`）
- `niri`（打开时通过 `niri msg -j focused-output` 定位当前显示器）
- `noto-fonts-cjk`（界面字体 Noto Sans CJK SC）

## 安装步骤

1. 检查依赖。
2. 复制：`cp -a kanban/shell ~/.config/quickshell/kanban`（目标已存在先备份）。
3. 接入 niri：复制 `niri/kanban.kdl` 到 `~/.config/niri/`，在 `config.kdl` 追加 `include "kanban.kdl"`。先检查 `Mod+Semicolon` 是否已被占用，再 `niri validate`。
4. 本次会话手动启动（之后由 `spawn-at-startup` 自启）：
   ```sh
   qs -c kanban -d
   ```

## 验证

```sh
qs list --all                                   # 能看到 kanban 实例
qs ipc -c kanban call kanban toggle             # 看板出现；再执行一次收起
```

新建一张卡片后，`~/.local/share/kanban/board.json` 应当出现。

## 注意事项

- 看板是 Overlay 层、独占键盘焦点的面板。开发或调试时如果卡在打开状态，用 `qs ipc -c kanban call kanban close` 或按 `Esc` 关闭；必要时 `qs kill -c kanban`。
- 每日任务的刷新判断每 30 秒跑一次，打开看板时也会立即检查一次；电脑休眠跨过刷新时间点后，下次检查时会补刷新。
- 标题栏日期按 `zh_CN` 区域格式显示（`M月d日 星期X`），界面文字为中文。
- 迁移数据只需复制 `board.json`。
