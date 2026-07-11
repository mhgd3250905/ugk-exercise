# `codex/pushupai-website` → `main` 审核报告

- 日期：2026-07-12
- 功能分支：`codex/pushupai-website`
- 目标分支：`main`
- 审核基线：`origin/main` @ `d48df57`
- 同步状态：`origin/main` 已通过 merge commit `8977ca4` 完整合入本分支

## 1. 结论先行

本分支新增 PushupAI（中文名“AI俯卧撑”）产品官网，以现有 Flutter App 的真实截图、已落地能力和已确认的商店规划为内容边界。官网为不依赖构建工具的静态 HTML/CSS/JavaScript 项目，与 Flutter App、Cloudflare Worker 和会员配置隔离。

官网实现本身相对 `origin/main` 新增 15 个文件；加上本审核报告后共新增 16 个文件。分支没有修改 `lib/`、`android/`、`workers/`、`pubspec.yaml` 或任何凭证配置。合入最新 `origin/main` 时无冲突。

## 2. 新增内容

### 2.1 官网主页

- 品牌：AI俯卧撑 / PushupAI。
- Hero：端侧 AI 姿态识别、自动计数、语音播报和训练记录。
- 产品能力：端侧识别、语音播报、本地记录。
- 产品截图：首页、训练页、记录页，均为项目本地素材。
- 产品生态：训练记录与云同步、日/周排行榜、Google 账号与会员恢复、中英文与浅色/深色/跟随系统主题。
- 使用步骤：固定手机、进入训练、完成动作。
- FAQ：手机摆放、视频隐私、支持动作、记录同步和下载时间。
- 下载区：Google Play 与 App Store 控件，未配置真实 HTTPS URL 时保持禁用。

### 2.2 视觉与交互

- 高对比黑/酸性绿品牌视觉，配合大字标题、精简卡片和 Bento 布局。
- 支持 1440px、768px 和 360px 常见视口，无水平溢出。
- 移动端导航支持打开、关闭、Escape 和焦点恢复。
- JavaScript 未加载时保留完整导航，折叠菜单仅在 `.has-js` 渐进增强后启用。
- FAQ 使用原生 `<details>` / `<summary>`，保留键盘交互。
- 装饰性视觉容器使用 `aria-hidden="true"`，支持 `prefers-reduced-motion`。

### 2.3 素材与配置

- App 截图：`website/assets/app-home.png`、`app-workout.png`、`app-records.png`。
- 品牌背景：`website/assets/pushup-motion-bg.webp`，由 AI 生成后存入项目。
- favicon：`website/assets/favicon.svg`。
- 商店链接：仅在 `website/store-links.js` 中配置；默认为空，且只接受绝对 HTTPS URL。
- 运行与部署说明：`website/README.md`。

## 3. 内容与安全边界

1. 仅宣传已在 App 和项目文档中落地的能力，不包含虚构用户、排名数据、下载量或效果保证。
2. 隐私文案限定为“姿态识别在设备端完成，视频帧不上传”；训练记录同步另按账号与会员边界说明。
3. 云同步文案保留“本地优先”语义，不声称免费账号具备 Premium 同步能力。
4. 运动广场仅说明日榜/周榜和可选加入，不渲染真实用户昵称或排名。
5. 源码不包含追踪脚本、分析 SDK、外部字体、Google Client ID、RevenueCat key 或 Worker secret。
6. 商店按钮在真实 URL 存在前不可点击，不存在占位跳转。

## 4. 与最新 `main` 的兼容性

`origin/main` @ `d48df57` 已包含 `0.3.2 (3)` Alpha 合规更新，本分支已合入该基线。

- 新版在启动相机前明确告知端侧处理，与官网隐私文案一致。
- 新版记录页实现周/月/年真实切换，官网截图已显示这三个入口，不会形成视觉误导。
- 新版排行榜客户端统一匿名显示，官网未展示真实昵称或虚构用户数据。
- 远程更新未修改 `website/`，merge 无冲突，官网产物不受 App 编译链影响。

## 5. 验证证据

| 验证项 | 结果 |
|---|---|
| `node --test website/tests/website.test.mjs` | PASS，11/11 |
| `node --check website/main.js` | PASS |
| `node --check website/store-links.js` | PASS |
| 360px / 768px / 1440px Chromium 布局 | PASS，无水平溢出 |
| 移动导航、Escape 焦点恢复、FAQ 键盘交互 | PASS |
| 无 JavaScript 的 768px 导航 | PASS，5 个链接可见 |
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，228/228 |
| `cd workers/membership-api && npm test` | PASS，86/86 |
| `git diff --check origin/main...HEAD` | PASS |

Android Debug 构建未记为 PASS：本机首次构建自动安装 NDK `27.0.12077973` 后，Gradle 两次长时间静默无完成标记，已主动终止。Release 构建也未执行，因本机当前工作区缺少 `android/key.properties` 和生产 `dart-define` 配置。这不影响静态官网运行，但审核时不应将 Android 构建视为本分支的已验证项。

## 6. 已知注意事项

1. `0.3.2 (3)` 已提交 Google Play Alpha 审核，尚未确认获批或对公众可下载。官网当前使用“Google Play 与 App Store 版本正在准备中”，对公共下载状态仍然保守且不构成虚假可用声明，但可在上线前改为更精确的“Google Play 封闭测试中，App Store 准备中”。
2. Google Play 和 App Store URL 仍为空。获得真实商店页面后，只应修改 `website/store-links.js`。
3. 官网尚未执行真实托管和线上域名验收；本分支仅交付可部署静态文件。
4. 官网中不包含隐私政策跳转入口；若上线审核要求网站也显式链接已发布的隐私政策，需另行增加。

## 7. `main` 审核重点

1. 审核 `website/index.html` 中的功能文案是否符合当前产品边界，尤其是 Premium 云同步、运动广场和下载时间。
2. 确认对外是否使用“准备中”，还是改为“Google Play 封闭测试中”。
3. 检查三张 App 截图和 AI 生成背景是否满足发布素材要求。
4. 确认商店 URL 为空时按钮确实不可点击，且不应在审核中填入占位 URL。
5. 检查导航、FAQ、reduced-motion 和 no-JS 渐进增强的可访问性。
6. 决定部署平台、公开域名、隐私政策链接和商店链接的上线时机。

## 8. 建议审核命令

```bash
git diff --stat origin/main...codex/pushupai-website
git diff --check origin/main...codex/pushupai-website
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/store-links.js
python3 -m http.server 4173 --bind 127.0.0.1 --directory website
```

建议在 360px、768px 和 1440px 各验收一次，并额外测试 JavaScript 加载失败时的 768px 导航。

## 9. 分支提交

官网主要提交：

- `8544390` `docs: define PushupAI website design`
- `bb661af` `docs: plan PushupAI website implementation`
- `93c29c3` `feat: add PushupAI product website`
- `a7c8aca` `fix: complete website review requirements`
- `5214088` `docs: mark website plan complete`
- `03ee1db` `docs: design app resource website enhancement`
- `4cc3232` `docs: plan app resource website enhancement`
- `6bcdabd` `feat: showcase app ecosystem on website`
- `8a6db54` `fix: preserve accessible website navigation`
- `7103738` `docs: mark home enhancement plan complete`
- `4beda13` `docs: clean website enhancement formatting`
- `8977ca4` `merge: align website branch with latest main`
- `d5fc3e3` `docs: clean website branch formatting`
