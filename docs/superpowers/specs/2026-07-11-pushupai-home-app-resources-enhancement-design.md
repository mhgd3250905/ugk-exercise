# PushupAI 官网 App 资源增强设计

日期：2026-07-11
状态：视觉方向已确认，待实现
范围：增强现有 `website/` 首页，不修改 Flutter App、Worker 或商店配置

## 1. 目标

利用仓库中已经落地的 App 产品信息完善 PushupAI 官网首页，使网站从“AI 俯卧撑计数功能页”升级为“完整 App 产品页”。官网仍以端侧姿态识别和自动计数为核心，同时真实呈现训练记录、账号、会员云同步、运动广场、多语言和系统主题能力。

本次不更换现有视觉方向，不重做 Hero，不生成虚构 App 截图。

## 2. 信息依据

首页新增内容只来自当前仓库中的真实实现：

- `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`：中英文产品文案。
- `lib/ui/pages/home_page.dart`：训练入口、今日计数、运动广场入口。
- `lib/ui/pages/profile_page.dart`：Google 登录、个人资料、会员和本地历史同步。
- `lib/ui/pages/leaderboard_page.dart`：日榜、周榜和个人排名。
- `lib/ui/pages/records_page.dart`：本地记录、云端记录合并和同步状态。
- `docs/modules/membership.md`：账号、RevenueCat 会员和 Cloudflare Worker/D1 能力边界。
- `docs/design/app-ui-v1.md`：颜色、圆角、主题和页面视觉规则。

Android launcher 当前仍为默认 Flutter 图标，不作为官网品牌素材。

## 3. 内容策略

### 3.1 第一层：训练核心

保留现有 Hero、三项核心能力、真实 App 截图和三步使用流程：

- 端侧 MoveNet 姿态识别。
- 自动计数与中文语音播报。
- 视频帧不上传。
- 训练日历与记录。

现有首屏不加入账号、会员或排行榜文案，避免削弱主价值主张。

### 3.2 第二层：产品生态

在产品截图区和使用流程之间新增 `#ecosystem` 区域，标题为：

`不只记住这一次，也陪你坚持下一次。`

使用四张 Bento 卡展示：

1. **训练记录与云端同步**
   - 本地训练可正常使用。
   - 登录会员后可同步归属当前账号的训练记录。
   - 云端不可用时仍展示本地记录。
2. **运动广场**
   - 会员可选择加入俯卧撑日榜和周榜。
   - 展示个人排名和完成次数。
   - 不虚构真实用户、排名或实时数据。
3. **一个账号，恢复权益**
   - Google 账号登录。
   - 会员状态和后续高级训练能力归属当前账号。
   - 可恢复购买。
4. **跟随你的设备**
   - 中文和英文界面。
   - 浅色、深色和跟随系统主题。

Premium 只作为上述能力的条件说明，不新增购买按钮、价格、折扣或付费宣传区。

### 3.3 FAQ

在使用流程与最终下载区之间新增 `#faq`：

- 手机应该放在哪里？
- 视频会上传吗？
- 当前支持哪些动作？
- 训练记录如何同步？
- 什么时候可以下载？

使用原生 `<details>` / `<summary>`，无 JavaScript 时仍可操作。回答必须遵守项目当前边界：单人、固定正前方、标准宽距俯卧撑、光线充足；商店版本尚未发布。

## 4. 导航调整

顶部导航从：

`产品能力 / 产品界面 / 使用方式 / 下载`

调整为：

`产品能力 / 产品生态 / 使用方式 / 常见问题 / 下载`

桌面端保持单行；在较窄平板宽度提前切换为折叠菜单，避免五个导航项挤压品牌和 CTA。

## 5. 视觉设计

新增内容沿用现有产品编辑感：

- 米白/浅绿背景、深墨绿文字、亮绿色强调。
- Bento 区使用 2×2 非对称卡片布局。
- 云同步卡使用本地记录与云端连接的抽象 CSS 图形。
- 排行榜卡使用无真实姓名的 `01 / 02 / 03` 排名条。
- 账号卡使用已有品牌 `P` 标记和权益恢复状态。
- 语言/主题卡使用 `中 / EN` 与日月图形。
- 所有图形由 HTML/CSS/SVG 原生实现，不生成虚假 App UI。
- 移动端改为单列卡片；FAQ 全宽展示。

## 6. 技术边界

- 修改 `website/index.html`、`website/styles.css` 和 `website/tests/website.test.mjs`。
- `website/main.js` 仅在现有移动菜单、商店链接和渐入逻辑需要适配时做最小修改。
- 不增加运行时依赖、构建工具、分析脚本或第三方字体。
- 不修改 `website/store-links.js` 的空商店 URL。
- 不复制账号密钥、Worker URL、RevenueCat key 或任何凭证到网页。
- 不修改 Flutter App、Worker、l10n ARB 或现有 App 截图。

## 7. 降级与可访问性

- `<details>` 使用浏览器原生交互和键盘行为。
- FAQ 展开状态提供清晰的 `focus-visible`、hover 和 active 反馈。
- Bento 卡的装饰图形标记为 `aria-hidden="true"`。
- 页面没有 JavaScript 时，新内容仍完整可读。
- `prefers-reduced-motion` 下不新增动画。
- 运动广场和同步卡不表现为可点击控件，避免误导。

## 8. 验证

实现后必须完成：

- 官网 Node 测试覆盖新增标题、锚点、真实能力文案和 FAQ。
- `node --check website/main.js` 与 `website/store-links.js`。
- `git diff --check`。
- Chromium 360px、768px、1440px 检查无页面横向溢出。
- 移动菜单在新增导航项后仍可打开、关闭并支持 Escape。
- FAQ 可用鼠标和键盘展开。
- 默认商店入口仍显示“即将上架”且无 `href`。
- Console、page errors 和资源加载均无错误。
- `flutter analyze` 和 `flutter test` 保持通过，证明未影响 App。

## 9. 明确不做

- 不新增 Premium 价格、试用期、折扣或购买 CTA。
- 不声称免费用户可以使用会员云同步或排行榜。
- 不虚构排行榜用户、训练数据或社区规模。
- 不新增网站账号登录、排行榜 API 或后台请求。
- 不把开发测试模式、离线回放工具或内部架构信息公开为产品卖点。
- 不使用默认 Flutter launcher 作为 PushupAI 品牌图标。
