# PushupAI 官网全球化、最新产品信息与 Android APK 下载区设计

- 日期：2026-07-12
- 分支：`codex/pushupai-website`
- 状态：用户已确认，待实施
- 基线：`main` / `origin/main` @ `9f01524`

## 1. 背景

PushupAI 现有官网是一个不依赖构建工具的静态 HTML/CSS/JavaScript 单页站点，当前仅提供中文内容。最新 App 已在原有端侧识别、自动计数、语音播报和本地记录之上，落地了账号/会员、云同步、运动广场、记录周/月/年切换、端侧相机告知、隐私政策/账号删除入口，并加固了近距离计数容错。

官网需在不夸大产品能力、不虚构商店可用性的前提下：

1. 与最新 App 的真实能力和发布状态对齐。
2. 为全球用户提供 8 种网站语言和可访问的语言切换。
3. 在没有真实 APK 文件和 URL 时，预留明确的 Android APK 扫码安装视觉入口。

## 2. 产品事实与内容边界

官网文案以以下项目内证据为权威来源：

- `docs/modules/recognition.md`
- `docs/modules/membership.md`
- `docs/release-configuration.md`
- `docs/design/app-ui-v1.md`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`
- `website/assets/app-home.png`
- `website/assets/app-workout.png`
- `website/assets/app-records.png`

对外信息应按以下边界改写：

| 主题 | 官网应表达 | 不应表达 |
|---|---|---|
| 识别 | 端侧 MoveNet 姿态识别；完整俯卧撑在推回顶部时计数；对近距离下压时胘腕/手臂短时离屏有容错 | 任意距离、100% 准确、动作评分或专业医疗判断 |
| 使用姿势 | 单人、手机固定正前方、保持头肩躯干可见、标准宽距俯卧撑 | 多人、手持摄像、任意动作类型 |
| 隐私 | 训练开始前告知相机用途；姿态识别和计数在设备端完成；原始视频帧不上传 | “完全不保存任何数据”（训练记录可本地保存/同步） |
| 记录 | 本地优先；周/月/年统计；会员可同步归属当前账号的记录 | 免费账号默认拥有 Premium 云同步 |
| 运动广场 | Premium 会员可选加入日榜/周榜；公开行显示匿名名称 | 虚构排名、虚构用户或真实自由昵称 |
| App 语言 | App 界面当前支持中文和英文 | 因官网支持 8 种语言而声称 App 也支持 8 种 |
| 主题 | App 支持浅色、深色和跟随系统 | 官网自身已提供深色主题切换 |
| 发布 | Google Play 处于 Alpha 封闭测试/审核阶段；App Store 准备中；公开下载未开放 | 已公开上架、虚假商店 URL、虚假 APK URL |

官网应新增已发布隐私政策与账号删除链接：

- `https://pushupai-privacy.pages.dev/`
- `https://pushupai-privacy.pages.dev/#account-deletion`

外部链接使用 `target="_blank" rel="noreferrer"`。

## 3. 语言范围

首批支持 8 种官网语言：

| Locale | 选择器原生名称 | HTML `lang` |
|---|---|---|
| `zh-CN` | 简体中文 | `zh-CN` |
| `en` | English | `en` |
| `es` | Español | `es` |
| `fr` | Français | `fr` |
| `de` | Deutsch | `de` |
| `pt-BR` | Português (Brasil) | `pt-BR` |
| `ja` | 日本語 | `ja` |
| `ko` | 한국어 | `ko` |

首批不引入需要 RTL 布局的语言。数据结构不限制未来新增 locale，但 RTL 支持需另行设计和验收。

## 4. 多语言架构

### 4.1 文件边界

- 新建 `website/locales.js`：语言元数据、8 份完整翻译字典、locale 归一化/解析纯函数。
- 修改 `website/index.html`：为可见文案、可访问性文案和元数据增加稳定翻译 key。
- 修改 `website/main.js`：语言选择、DOM 应用、URL/本地持久化、事件绑定。
- 修改 `website/styles.css`：语言选择器和长文案响应式容错。
- 修改 `website/tests/website.test.mjs`：字典对齐、locale 解析、DOM 合同、APK 占位边界。

不引入 npm 库、框架、服务端路由或构建步骤。

### 4.2 DOM 翻译合同

- 普通文本节点使用 `data-i18n="key"`，通过 `textContent` 写入，不使用 `innerHTML`。
- 多行标题将每行拆成独立 `<span data-i18n="...">`，保留 `<br>` 和当前版式控制。
- `aria-label`、`alt`、`content` 等属性使用 `data-i18n-attr="aria-label:key;alt:key"` 这一明确语法；实现只允许 `aria-label`、`alt`、`content`、`title` 四种属性，不将字典内容写入 `href`。
- `title`、description、Open Graph 文案和 `og:locale` 由固定 meta key 更新。
- 中文原文保留在 HTML 中，是 JavaScript 不可用时的完整回退。

翻译字典必须覆盖所有可见内容，包括：

- skip link、导航、菜单和 CTA
- Hero、功能、截图标题、产品生态、使用步骤
- FAQ 问题/答案
- 下载区、商店状态、APK 占位和安装说明
- footer、隐私政策和账号删除
- 图像 alt、视觉区 aria-label、导航 aria-label 和语言选择器 label

### 4.3 locale 选择顺序

1. URL 参数 `?lang=<locale>`
2. `localStorage` 中的用户手动选择
3. `navigator.languages` / `navigator.language`
4. English (`en`) 回退

归一化规则：

- `zh`、`zh-CN`、`zh-SG` → `zh-CN`
- `pt`、`pt-BR` → `pt-BR`
- 其他支持语言的区域变体按主语言映射，如 `fr-CA` → `fr`
- 不支持或非法 locale 不写入 DOM，继续检查下一优先级

用户切换语言后：

- 立即更新 DOM、`<html lang>` 和 meta
- 尝试写入 `localStorage`；写入被浏览器禁止时页面仍继续工作
- 通过 `history.replaceState` 更新 `?lang=`，不刷新页面、不丢失当前 anchor

### 4.4 语言选择器

- 使用原生 `<select>`，不建造自定义 combobox。
- 选项始终显示各语言的原生名称，避免用当前语言翻译所有语言名。
- 选择器是 `#site-nav` 中的最后一个控件：桌面端自然位于导航链接与下载 CTA 之间，移动端随展开导航显示，不复制第二个控件。
- 选择器默认隐藏，仅在 `.has-js` 生效后显示，避免 no-JS 页面出现无效切换控件；触控高度至少 44px。
- 提供可见的地球 SVG 图标和 screen-reader label；不使用 emoji 图标。
- 焦点环、高对比、Escape 菜单关闭和 no-JS 导航回退保持现有行为。

## 5. Android APK 扫码占位设计

### 5.1 下载信息架构

当前下载区从两个商店按钮扩展为三渠道下载 hub：

1. Google Play：Alpha 封闭测试中，真实公开 URL 未配置时禁用。
2. App Store：准备中，真实 URL 未配置时禁用。
3. Android APK：预留直接安装通道，当前为不可扫描/不可点击的占位卡片。

不在本次实现中扩展 `store-links.js` 的 APK 真实下载逻辑，因为当前无 APK 文件、无稳定 HTTPS URL、无版本/校验和签名信息。未来接入时需单独定义安全合同。

### 5.2 占位卡片

- 卡片使用当前黑/酸性绿品牌色，与商店按钮形成不对称下载面板。
- 视觉包含 Android SVG 线性标识、“Android APK”标题、简短安装说明和“即将提供”状态。
- QR 区是明确不可扫描的品牌几何占位：使用非标准网格、大面积中心 `APK` 标识，不生成任何 QR payload，不指向官网或占位 URL。
- 整个图案使用 `aria-hidden="true"`；卡片文字明确说明“当前无可扫描下载”。
- 卡片不使用 `<a>`、不添加 click handler、不伪装为可用按钮。

### 5.3 响应式

- 桌面端：左侧下载文案/商店按钮，右侧 APK 卡片，与现有下载轨道背景共存。
- 平板：两列或上下布局，不压缩 QR 占位图到低于 152px。
- 手机：商店按钮全宽排列，APK 卡片置于其后，文字可换行，无水平溢出。

## 6. 官网内容结构调整

保留现有 Hero → 能力 → App 截图 → 产品生态 → 使用步骤 → FAQ → 下载的顺序，避免再增加大型营销模块。更新集中在已有位置：

- Hero 隐私注释：端侧处理/原始帧不上传。
- 识别能力卡：补充“完整推回顶部时计数”和近距离短时离屏容错，但不扩大支持范围。
- 记录能力卡：从“训练日历”更新为周/月/年统计。
- 运动广场卡：明确匿名展示。
- 界面卡：始终说明“App 界面支持中文/英文”，不随官网 locale 扩大。
- 使用步骤：第二步补充进入训练后先确认相机端侧处理告知。
- FAQ：保留现有 5 项，将下载答案更新为 Alpha/App Store/APK 三渠道状态；在隐私答案内增加隐私政策和账号删除链接。
- footer：增加隐私政策和账号删除文本链接。

## 7. 错误处理与降级

- JavaScript 不可用：展示完整中文站点，导航保持可见，商店和 APK 保持禁用。
- URL locale 非法：忽略该值，不报错、不将非法文本写入 DOM。
- `localStorage` 读写异常：捕获异常，保留当前会话选择。
- 单个翻译 key 缺失：回退到 English；测试必须阻止任何已知 key 缺失进入提交。
- 用户切换语言时不重建交互节点，避免丢失导航/FAQ 事件和焦点。
- 真实商店 URL 未配置：保持 `aria-disabled="true"`、无 `href`、无跳转。
- APK 未配置：纯文本/视觉占位，无交互。

## 8. 可访问性与视觉规则

- 不改变现有黑/酸性绿、高对比、大字标题和 Bento 产品卡的品牌基调。
- 所有新交互目标至少 44×44px，鼠标、键盘和触摸均可用。
- 不移除焦点环；新选择器使用 `:focus-visible` 与现有轮廓体系一致。
- 不使用 emoji 作结构图标；使用内联 SVG 且装饰性图标 `aria-hidden="true"`。
- 德语、法语、葡萄牙语的长文案优先换行，不使用截断或过小字号。
- 日语/韩语沿用系统字体回退，不引入第三方字体请求。
- 所有动画保持 `prefers-reduced-motion` 适配；语言切换不添加大范围过渡。

## 9. 测试与验收

### 9.1 自动化测试

`website/tests/website.test.mjs` 应覆盖：

1. 语言元数据恰好包含 8 个已批准 locale。
2. 8 份字典 key 集合与 English 完全一致，值为非空字符串。
3. HTML 中每个 `data-i18n` / `data-i18n-attr` key 均存在于字典。
4. `resolveLocale` 覆盖 URL、存储、浏览器列表、区域归一化和 English 回退。
5. 语言切换更新文本、属性、`<html lang>` 和 meta。
6. 商店链接仍只接受绝对 HTTPS URL。
7. APK 占位卡片存在，不包含 `href`、可扫描 payload、APK 文件或虚假 URL。
8. 隐私政策/账号删除 URL 精确且具备安全外链属性。
9. 产品文案保留 Premium、App 中英文语言范围和识别边界，不出现免费试用/虚假可用声明。

运行：

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
git diff --check
```

### 9.2 浏览器 QA

用本地 HTTP 服务和 Chromium 验证：

- 视口：360px、768px、1440px，外加一次手机横屏。
- locale：8 种全部切换；德语/法语/葡萄牙语做完整页面长文案检查。
- 交互：语言选择、URL 同步、刷新持久化、移动菜单、Escape 焦点恢复、FAQ 键盘操作。
- 降级：阻断 `main.js` 后中文页面与 5 个导航链接仍完可用。
- 布局：无水平溢出、无截断、APK 卡片和 QR 占位不伪装为交互元素。
- 辅助偏好：`prefers-reduced-motion: reduce` 下页面内容不被隐藏。
- console 和 page error 为空。

### 9.3 App 回归

官网不改 Flutter/Worker 代码，仍运行：

```bash
flutter analyze
flutter test
```

当前 `main` 存在一个已确认的异步 flaky test：`premium workout is queued and starts sync without waiting for network`。官网分支不修改该测试或 App 同步逻辑；回归报告必须区分官网回归与远程已有时序失败。

## 10. SEO 与静态站点限制

本设计使用客户端字典替换，保留单份静态 HTML 和无 JavaScript 中文回退。`?lang=` 使翻译链接可分享，但不等价于每种语言拥有独立可爬取静态 URL 和 `hreflang` 页面。

首批优先交付产品可用的多语言切换；若未来 SEO 成为核心获客渠道，再基于同一字典生成 `/en/`、`/es/` 等静态语言页。本次不复制 8 份 HTML。

## 11. 非目标

- 不给 Flutter App 新增 6 种语言。
- 不增加网站深色主题切换。
- 不生成、签名、托管或提交 APK。
- 不制作可扫描到虚假地址的 QR code。
- 不配置 Google Play/App Store 虚假 URL。
- 不修改 App 识别算法、会员逻辑、Worker 或发布凭证。
- 不在本次实现 RTL 布局或多语言静态 SEO 页。

## 12. 验收标准

1. 官网可在不刷新的情况下切换 8 种语言，且所有可见/可访问文案和 meta 同步更新。
2. URL、用户保存和浏览器 locale 按已定义优先级解析；非法值安全跳过到下一优先级，全部无匹配时最终回退 English。
3. 中文 no-JS 站点仍完整可用。
4. 官网内容与最新 App 事实一致，明确 App 仅支持中文/英文，不夸大识别或发布状态。
5. 官网包含安全的隐私政策和账号删除链接。
6. 下载区包含 Google Play、App Store 和 Android APK 三渠道视觉；无真实 URL 时均不宣称可公开下载。
7. APK QR 为明确不可扫描、不可点击的占位，无 APK 产物或虚假 payload。
8. 360/768/1440px 和手机横屏无水平溢出，长文案不截断，交互和辅助功能可用。
9. 官网自动化测试、JavaScript 语法检查和分支 diff 检查通过。
