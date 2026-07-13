# `feat/website-polish` → `main` 审核报告

- 日期：2026-07-13
- 功能分支：`feat/website-polish`
- 目标分支：`main`
- 审核基线：`origin/main` @ `2f858d1`
- 功能提交：`9aa28b8`、`eefa955`

## 1. 本次结果

本分支完成官网品牌、用户文案和下载入口的整理。页面从偏技术说明的表达调整为更有温度、面向用户的产品介绍，同时保留真实的功能、隐私和下载状态边界。

改动仅涉及静态官网 `website/` 和本报告，不修改 Flutter App、Cloudflare Worker、D1、Secret 或会员配置。

## 2. 主要变化

### 品牌与首屏

- 网页品牌图标和 favicon 统一使用 App Logo。
- 手机端和桌面端左侧首屏居中展示 Logo、PushupAI、中文名和产品介绍。
- 中文首屏文案调整为：
  - `来做俯卧撑吧！`
  - `AI 帮你数，放心去练。`
  - `AI 看懂动作，你的训练画面，只属于你。`
- 8 种语言同步调整为面向用户、突出方便和训练体验的表达。

### 下载按钮与 APK 入口

- Google Play 与 App Store 按钮改为等宽、紧凑布局。
- 使用用户熟悉的 Google Play 彩色标志和 Apple 标志。
- 去掉 `Get it on`、`Download on the`、测试状态等冗余文字，右侧统一使用下载图标。
- 删除页面底部重复的整块下载区域，首页首屏保留主要下载入口。
- 商店按钮下新增“点击下载安装包”入口：
  - 桌面端点击或悬浮时，在按钮右侧、按钮区域下方展示二维码占位卡片，不遮挡商店按钮。
  - 手机端点击时弹出确认对话框；当前未配置地址，因此只提示安装包准备中，不触发无效下载。
  - 后续只需在 `website/store-links.js` 的 `STORE_LINKS.apk` 填入有效 HTTPS 地址，即可启用手机端确认下载。
- 当前二维码是明确的视觉占位，不包含虚假下载地址，也不应被当作可扫码二维码。

### 导航与内容边界

- 移除桌面端和手机菜单中重复的“下载”导航项。
- 保留首屏商店按钮、APK 入口和页头行动入口。
- 隐私政策与账号删除仍指向已存在的 `pushupai-privacy.pages.dev` 页面。
- Google Play、App Store 和 APK 地址当前均未配置，不宣称已经可以公开下载。

## 3. 部署边界

- 官网是 `website/` 下的纯静态站点，不依赖后端接口。
- 本分支没有新增 Pages Functions、环境变量、D1 绑定或 Worker Secret。
- 计划在 main 审核并合并后，使用 Cloudflare Pages 的 Git 集成部署：生产分支为 `main`，构建命令留空，输出目录为 `website`。
- 暂无自定义域名，首次上线使用 Cloudflare 提供的 `pages.dev` 地址。
- 当前分支尚未部署，此报告仅用于合并前审核。

## 4. 验证结果

| 验证项 | 结果 |
|---|---|
| `node --test website/tests/website.test.mjs` | PASS，43/43 |
| `node --check website/main.js` | PASS |
| `node --check website/locales.js` | PASS |
| `node --check website/store-links.js` | PASS |
| `git diff --check origin/main...HEAD` | PASS |
| 桌面端 1280×720 首屏与下载区 | PASS |
| 桌面端 APK 卡片位于按钮右侧且不遮挡按钮 | PASS |
| 重复下载区域与菜单“下载”项已移除 | PASS |

手机端 APK 确认流程、空地址保护和响应式样式已由自动化测试覆盖。Flutter App 和会员 Worker 未改动，因此本轮未运行 Flutter/Worker 测试；当前官网 worktree 也未安装 Worker 的 npm 依赖。

本地预览地址：`http://127.0.0.1:4173/?lang=zh-CN`

## 5. main 审核重点

1. 首屏及多语言文案是否具备宣传吸引力，同时没有超出实际产品能力。
2. 隐私、会员、排行榜和下载状态是否保持真实边界。
3. 桌面端二维码占位与手机端 APK 确认交互是否符合预期。
4. 移动菜单、无 JavaScript 导航、语言切换和可访问性是否正常。
5. 合并后是否按上述 Cloudflare Pages 配置上线。

## 6. 建议审核命令

```powershell
git diff --stat origin/main...feat/website-polish
git diff --check origin/main...feat/website-polish
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
python -m http.server 4173 --bind 127.0.0.1 --directory website
```

未跟踪的 `docs/reviews/2026-07-13-website-polish-review.md` 是外部评审材料，本分支不会修改或提交该文件。

## 7. 功能提交

- `9aa28b8` `feat(website): polish landing page branding and copy`
- `eefa955` `feat(website): refine copy and APK download flow`
