# p5-reference — P 系列 UI 参考包

这不是一个可安装的 Quickshell 组件，而是一个 **参考资料包**：收集 CodePen 上各种 Persona 5 风格的 UI 片段，已本地化并修好失效的依赖，用来给本仓库的 `p5lock` / `dms-p5` 等组件找灵感、抄效果。

> 虽然叫 `p5-reference`，但内容不限 P5：也有一个 **Persona 3 Reload** 菜单和一个通用的 CSS 字幕过场。

包内没有 `shell/`、`niri/`、`systemd/` 目录，**不需要安装**，也不会被 `qs` 加载。

## 怎么用

直接打开总览页，或单独打开某个 demo：

```sh
xdg-open ~/Projects/my-arch-kit/p5-reference/index.html
```

总览页 `index.html` 会列出全部 11 个 demo，点击在新标签打开。每个子目录里都有一个可离线打开的 `index.html`，双击即可，不需要服务器、不需要联网（字体/图片/第三方库全部已下载到包内）。

## 目录

| 目录 | 名字 | 技术 | 说明 |
| --- | --- | --- | --- |
| [`menu-3d/`](menu-3d/) | P5 Menu UI | HTML/CSS/Snap.svg | 主菜单：红/蓝双层斜切光标随机抖动，鼠标悬停/方向键选择 9 项 |
| [`menu-hover-effect/`](menu-hover-effect/) | P5 Menu Effect | HTML/CSS（SCSS） | 导航栏：悬停弹出红+青斜块 + jelly 抖动 + 文字 tiltBounce |
| [`menu-nav/`](menu-nav/) | P5 Style Menu | HTML/CSS | 右上角 7 项 3D 扇形倾斜菜单，黑底黄边，悬停投影放大 |
| [`calendar/`](calendar/) | P5 Calendar | HTML/CSS/JS | 每日日历：5 天卡片、今天红底上浮、实时时钟、触摸滑动切换 |
| [`toggle-switch/`](toggle-switch/) | Custom Slider | HTML/CSS | ON/OFF 开关：白→粉红，指针变形 + 抖动 |
| [`take-your-heart/`](take-your-heart/) | Take Your Heart | SVG/GSAP/MorphSVG | Logo 火焰 path morph 循环 + 小圆点沿路径环绕 |
| [`sms/`](sms/) | P5 SMS | Vue 2/GSAP | P5 短信对话气泡：SVG 遮罩 + 打字机逐字动画 |
| [`star-background/`](star-background/) | P5 Animated Star | HTML/CSS/jQuery | 黑白星星随机散布、放大缩小循环，可作背景/过场 |
| [`p3-menu/`](p3-menu/) | P3 Reload Menu | HTML/SCSS/JS | Persona 3 Reload 主菜单：蓝底渐变，选中项红白描边倾斜放大，方向键切换 |
| [`interstitial/`](interstitial/) | NEXT Interstitial | HTML/CSS | 纯 CSS 过场：黄色斜带旋转拍入 + 「NEXT」滑入居中后压扁消失 |
| [`save-carousel/`](save-carousel/) | P5R Save Carousel | HTML/SVG/JS | P5R 存档界面复刻：长条胶片沿右侧转轴扇形铺开，切换时整组轮转，焦点条弹出带齿孔的主题色底片 |

## 来源与本地化改动

除 `save-carousel` 外全部来自 CodePen。原始链接与"我改了什么"：

| 目录 | 原作者 | 原始 pen | 本地化时做的改动 |
| --- | --- | --- | --- |
| `menu-3d` | Drew Powers (dangodev) | https://codepen.io/dangodev/pen/qXdxOO | 三张素材图（joker/menu/bg）的原 S3 链接已 403，从 Wayback Machine 找回；Snap.svg 本地化 |
| `menu-hover-effect` | Kevin Quach | https://codepen.io/kevinquach/pen/JNGmKG | SCSS 编译；14 张 imgur 图 + animate.css 本地化 |
| `menu-nav` | Gurpreet Singh | https://codepen.io/gurpreet-singh-the-typescripter/pen/xxGgJjN | 图标字体（IcoMoon 临时链接）已 404 且无存档，已移除；其余无外部依赖 |
| `calendar` | Arda Duyar | https://codepen.io/editor/Arda-Duyar/pen/01a0102e-b50f-7587-9f2a-e5022b16c9c8 | 新版编辑器，从 GraphQL 响应取源；本身就是单文件，仅去掉 CodePen 注入脚本 |
| `toggle-switch` | erzulu | https://codepen.io/erzulu/pen/xMGBQr | Google Font「Luckiest Guy」下载到 `fonts/`，改为本地 `@font-face` |
| `take-your-heart` | LimeWub | https://codepen.io/LimeWub/pen/dqdVGE | 见下方「GSAP 试用版问题」 |
| `sms` | nutty7t | https://codepen.io/nutty7t/pen/qzzGOR | SCSS 编译；Vue/vue-async-computed/GSAP/ScrollToPlugin 本地化；字体本地化；加了 devicePixelRatio 补丁（见下） |
| `star-background` | Kevin Quach | https://codepen.io/kevinquach/pen/KmKGem | SCSS 编译；jQuery 本地化 |
| `p3-menu` | k8765ed | https://codepen.io/k8765ed/pen/gONYNre | SCSS 编译；Google Font「Nunito Sans」变量字体下载到 `fonts/` 并改为本地 `@font-face` |
| `interstitial` | Dudley Storey | https://codepen.io/dudleystorey/pen/ZEpvzb | 纯 CSS，无需依赖；给 `body` 补了 `overflow: hidden`（见下） |
| `save-carousel` | 本仓库原创 | 参考 P5R 存档界面截图 `~/Pictures/p5/02_P5R_存档界面.jpg` | 从零实现；字体取自 `dms-p5` 的 Anton / Barlow Condensed / Luckiest Guy 与系统的 Noto Sans（均 OFL，许可证在 `fonts/`） |

## 注意事项

- **`take-your-heart` 换掉了 GSAP 版本。** 原 pen 用的是 GSAP 2 的 `TweenMax` + MorphSVGPlugin **试用版**。GreenSock 已弃用试用版（页面会直接显示 "Oops! Trial version of MorphSVGPlugin deployed" 并停止渲染）。现在 GSAP 3.13+ 已把 MorphSVGPlugin 免费开放，所以本包改用 `gsap@3.13` + `MorphSVGPlugin@3.13`，并把动画代码适配成 GSAP 3 写法（`TimelineMax` → `gsap.timeline`、`Linear.easeNone` → `"none"`）。原 pen 源码完整保留在 `take-your-heart/source.pen.js`，适配版是 `take-your-heart/app.js`。
- **`sms` 需要 `devicePixelRatio === 1`。** 原 pen 自己就写了：DPR 不等于 1 时只显示 "Oops, my bad..." 提示（它的 SVG 遮罩按 1:1 像素写死，不做缩放）。HiDPI 屏幕上永远看不到内容，甚至某些 1x 屏上 DPR 会返回 `1.00000003` 也不满足严格相等。本包在 `index.html` 顶部加了一段 shim 把 `devicePixelRatio` 固定成 1，让 demo 能正常显示。
- **`menu-nav` 的图标没了。** 原 pen 引用 `https://i.icomoon.io/public/temp/.../style.css`，是 IcoMoon 临时链接，已 404、Wayback 也没存档，所以每个菜单项末尾的小图标无法恢复。需要的话可以用本机的 `otf-font-awesome` 或纯 CSS 自己补。
- **`calendar` 是德语 + 触摸交互。** 标签是 `HEUTE / VERGANGEN / KOMMT`，切换日期只绑了 `touchstart/touchend`，桌面鼠标划不动。改中文或加鼠标/键盘事件的话改 `calendar/index.html` 里的 `months`/`label` 和事件监听即可。
- **`menu-nav` 没有 JS。** 汉堡按钮点不动是原 pen 就这样（`menuActive` 写死在 HTML 上），只有 hover 交互。
- **`interstitial` 补了 `overflow: hidden`。** 原 pen 的黄色斜带是 `width:180%` 且旋转过的，在独立页面里会撑出滚动条（CodePen 预览里被 iframe 裁掉了）。本地副本给 `body` 加了 `overflow: hidden`，让它看起来是真正的全屏过场。
- **`p3-menu` 用方向键操作。** `↑`/`↓` 切换选中项，`Tab` 被禁用。它 `cursor: none`，桌面看不到鼠标指针是原 pen 的设计。
- **`save-carousel` 的几何是从原图量出来的。** 条幅并不共用一个圆心：对原图逐列取样后发现，焦点上方的条幅向右急剧收拢，下方的近乎平行、逐渐变窄。所以 `app.js` 里用 `KEYS` 表给「相对焦点的偏移 d」定义 [锚点 y, 角度, 长度] 关键帧，Catmull-Rom 插值；滚动时 d 连续变化，条幅就沿关键帧轮转。焦点高亮跟随离散选择立即切换（斜切擦除），条幅位置走欠阻尼弹簧。压缩区用 `scaleY` 模拟转到背面的透视缩短。操作：`↑↓`/滚轮/拖动切换、点击选中、`Enter` 确认、`Esc` 收起/展开、`T` 在 P5 红与 DMS 粉紫之间切主题。调试参数：`?sel=5` 初始选中、`?static` 跳过开场、`?pos=2.4` 冻结在过渡帧、`?fold=0.5` 冻结在展开中途、`?theme=lavender`。已移植成 QML，作为 `dms-p5` 的应用列表（`Mod+Z`），见 `dms-p5/AGENTS.md`。
- **版本/授权。** 这些代码版权归各自作者，仅作参考。第三方库（GSAP、Vue、jQuery、Snap.svg）各自遵循自己的许可证；GSAP 3.13+ 全包免费。

## 相关

- 组件包：`music/`、`kanban/`、`p5lock/`、`dms-p5/`
- 仓库总说明：`../AGENTS.md`
