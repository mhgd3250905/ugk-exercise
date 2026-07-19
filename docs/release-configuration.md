# PushupAI 发布、账号、订阅与后端配置台账

最后核对：2026-07-20

适用应用：Google Play 中文名“AI俯卧撑”，英文名“PushupAI”

Android 包名：`com.ugkexercise.ugk_exercise`

> 本文用于让没有参与过首次配置的人或 agent 接手发布工作。它记录“在哪里配置、配置了什么、为什么需要、目前完成到哪里”。
>
> 本文可以进入仓库，因此不保存真实 Google Client ID、RevenueCat API Key、服务账号私钥、签名密码、Cloudflare Token 或 Worker Secret。带账号标识和本机秘密文件位置的私密台账在 `E:\AII\secrets\PushupAI-发布与密钥台账.md`。

功能改完后该走本地、内部测试还是 Alpha，先按 [开发测试与发布手册](testing-release-playbook.md) 分流。

动态平台状态只代表文中注明日期的最后一次核对；下一次上传或推进轨道前必须重新查看 Play Console，不能把历史状态当实时状态。

## 1. 当前状态摘要

| 项目 | 状态 | 当前事实 |
|---|---|---|
| Google Play 应用 | 已创建 | 应用、免费、默认语言 `zh-CN`；免费应用仍可销售应用内订阅 |
| Play App Signing | 已启用 | Google 持有“应用签名密钥”；本机持有单独的“上传密钥” |
| Google Play 测试轨道（最后核对 2026-07-19） | Internal `0.3.13 (16)` 与 Alpha `0.3.11 (14)` 均已全面发布 | Play Console 独立核对：`0.3.13-internal-1` 于 2026-07-19 23:46 面向内部测试人员发布；`0.3.11-closed-1` 于 2026-07-19 11:50 面向 Alpha 测试人员发布 |
| 已发布 Internal 源码 | `feat/new-feature@6374a3c`；`0.3.13 (16)` | 3 天试用动态展示与月卡 Offer 购买；核验 AAB 已发布到 Internal |
| 当前 App 主线 | `main@5553576` | 已包含窄距俯卧撑、积分榜、本人分类次数、英文语音、多页面主题表面优化，以及实时训练页、启动流和窄距提示稳定性修复；远端 main 已核对一致 |
| 当前 Internal 发布 | `0.3.13 (16)` 已全面发布 | `feat/new-feature`；AAB 源提交 `6374a3c`；发布名称 `0.3.13-internal-1`；Play 安装、登录、月卡试用开始与自动转正已验收 |
| 当前 Alpha 发布 | `0.3.11 (14)` 已全面发布 | 复用 Internal 的同一 `versionCode=14` App Bundle；`0.3.11-closed-1` 于 2026-07-19 11:50 面向 Alpha 测试人员发布 |
| 最新 Internal 试用功能版 | `0.3.13 (16)` 已全面发布 | `feat/new-feature@6374a3c`；3 天试用动态展示与月卡 Offer 购买；AAB `187231668` 字节，SHA-256 `f491ea749b14a2cfa805adfa792090eba63f6fc0a0216f7389a024e7a90a9ea7` |
| `0.3.12` 发布后独立审查 | CODE / TEST / CURRENT LEDGER CONTENT PASS / PLAY RUNTIME PENDING / HISTORY METADATA REWRITE BLOCKED | 第六轮独立复验确认修复与测试通过；已发布 `0.3.12 (15)` 仍不含审查后修复。info 当前内容无个人邮箱，但既有提交元数据格式修正需用户明确授权历史重写 |
| 窄距与积分榜上线门槛 | BREAKDOWN WORKER DEPLOYED / DEBUG APP INSTALLED | 2026-07-18 已部署本人分类次数 Worker；积分日/周榜、旧次数查询和训练同步的未登录 `401` 探针通过。未执行 D1 migration，未改变量、Secret 或 binding；等待用户刷新 Debug App 验收 `N + 2M` 积分及本人分类次数 |
| Play 安装验收 | `0.3.11 (14)` USER REPORTED PASS / `0.3.12 (15)` PENDING / `0.3.13 (16)` MONTHLY TRIAL CORE PASS | `0.3.13` 已从 Play 全新安装并验证登录、试用购买、Sandbox 自动转月卡、Webhook/Worker/D1、冷启动恢复和订阅管理入口；取消、到期、历史账号无资格仍待独立场景 |
| Google OAuth | 已验证 | Play 签名版真机登录成功 |
| RevenueCat Google Play App | 已创建 | 已绑定同一包名，Production/Google Play Public SDK Key 已用于 release 构建 |
| RevenueCat 服务凭据 | 已上传并可用 | Google 官方权限与 API 已配置；RTDN 测试通知已被 RevenueCat 接收 |
| Google RTDN | PASS | Topic 已连接，Play 测试通知成功，RevenueCat 显示最近接收时间 |
| Play License Testing | PASS | 许可测试名单已生效；购买页显示 Google 测试卡和测试订阅声明，未使用真实付款方式 |
| Google Play 订阅商品 | 已激活 | `premium` 下的 `monthly` 与 `annual` 自动续订 base plan 已覆盖 174 个国家/地区并启用 |
| RevenueCat 商品映射 | 已完成 | Google Play 月度/年度商品均关联 `premium` entitlement，并加入当前 `default` Offering 的标准 Package |
| Google Play 3 天试用 | MONTHLY START + AUTO-RENEW PASS / MATRIX PARTIAL | `monthly-3d-trial` 已启用；全新 License Tester 在 Play `0.3.13 (16)` 完成测试购买，Sandbox 的 3 分钟试用自动转为 5 分钟月卡，`INITIAL_PURCHASE` 与 `RENEWAL` 均处理成功，D1 保持 active。取消、到期和历史账号无资格仍待独立场景，不得宣称完整矩阵通过 |
| 年卡 7 天试用 | APP LOCAL IMPLEMENTED / PLAY OFFER NOT CONFIGURED | `feat/new-feature@264af55` 已支持从 RevenueCat annual Package 精确识别完整 7 天免费阶段、年价披露与 annual Package 购买；建议 Offer `annual-7d-trial` 尚未获得远端配置授权，未创建/启用，也没有结算页、Sandbox、Webhook 或 D1 运行证据 |
| Google Play Sandbox 购买 | PASS（License Tester Debug） | Google 官方允许 License Tester 使用同包名侧载 Debug；月度购买/续订/过期、年度购买、RevenueCat entitlement、App 重启恢复及 Webhook→D1 均已验证，未进行真实购买 |
| Cloudflare Worker/D1 | 会员 Webhook→D1 PASS | 年度 `INITIAL_PURCHASE`、月度续订/取消/过期事件和 active 快照已只读核验；未登录鉴权探针返回预期 `401`，带真实会话的 `/membership` 响应仍未独立抓取 |
| 会员单一权威对账 | WORKER PRODUCTION PASS / APP ALPHA PUBLISHED | RevenueCat subscriber → Worker 权威裁决 → D1 可重建缓存已上线；`0.3.8 (10)` 排行榜核心链路已通过，包含续费即时刷新的 `0.3.8 (11)` 已发布到 Alpha，真实 Sandbox 续费回归仍待单独记录 |

## 2. 各系统如何关联

```mermaid
flowchart LR
    User["Google 用户"] --> SignIn["Google Sign-In"]
    SignIn -->|"ID token"| App["PushupAI Android App"]
    App -->|"ID token + Web Client audience"| Worker["Cloudflare Worker"]
    Worker --> D1["D1 账号/会员/训练/榜单"]

    App -->|"RevenueCat Google Play Public SDK Key"| RC["RevenueCat"]
    RC -->|"调用 Play Developer API"| Play["Google Play"]
    Play -->|"购买与订阅状态"| RC
    Play -->|"RTDN / Pub/Sub"| RC
    RC -->|"签名 Webhook"| Worker
    Worker -->|"Secret API: current subscriber"| RC
```

必须分清两条通知链：

- **Google RTDN**：Google Play → Google Cloud Pub/Sub → RevenueCat。让 RevenueCat 尽快知道续费、取消、退款、付款失败等商店事件。
- **RevenueCat Webhook**：RevenueCat → Cloudflare Worker。它负责尽快唤醒对账；Worker 随后查询 RevenueCat 当前 subscriber，再把 `premium` 权益缓存到 D1。Webhook 事件内容不是最终状态事实。

这两条链不是同一件事。只配其中一条会造成会员状态延迟或后端状态缺失；即使 Webhook 延迟或丢失，主动对账和过期缓存读取也必须能够从 RevenueCat 当前状态恢复。

## 3. Google Play Console

入口：[Google Play Console](https://play.google.com/console/)

### 3.1 创建应用

位置：Play Console 首页 → “创建应用”。

已配置：

- 中文商店名称：`AI俯卧撑`
- 英文商店名称：`PushupAI`
- 包名：`com.ugkexercise.ugk_exercise`
- 默认语言：简体中文 `zh-CN`
- 类型：应用
- 定价：免费

目的：在 Google Play 中建立不可混淆的应用身份。包名是 OAuth、RevenueCat、Billing、Play App Signing 和后续所有版本共同使用的主键，不能随意变更。

### 3.2 Play App Signing 与两个签名密钥

新版网页位置：应用 → “由 Google Play 提供保护” → “Play 商店保护” → “Play 应用签名”。

这里有两个完全不同的证书：

| 名称 | 谁持有 | 用途 |
|---|---|---|
| 上传密钥 | 本机开发者 | 给上传的 `.aab` 签名，Google 用它确认上传者身份 |
| 应用签名密钥 | Google Play | 给用户实际下载的 APK 签名；Google OAuth 必须登记这个证书的 SHA-1 |

首次 AAB 已使用本机上传密钥签名。Play 安装包的 Google 登录能成功，是因为已从“应用签名密钥证书”复制 SHA-1，并在 Google Cloud 建立对应 Android OAuth Client。

重要：不要把“上传密钥 SHA-1”填成 Play 分发版 OAuth 的 SHA-1。

### 3.3 内部测试

位置：应用 → “测试和发布” → “测试” → “内部测试”。

轨道初始配置已由历史版本 `0.3.0 (1)` 完成。当前已发布内部测试版本、下一候选版本和精确证据统一以 §1 与 §6.3 为准，不能继续把 `0.3.0-internal-1` 当作当前版本。

- Android：API 24 及以上；当前上传产物目标 API 35。
- 测试名单：`PushupAI Internal Testers`。
- 测试人员已通过 opt-in 链接加入，并可从 Google Play 安装内部测试版本。

“尚未审核”不等于公开发布失败；这是内部测试轨道，只有名单中的账号通过加入链接才能获取。

内部测试名单位置：内部测试 → “测试人员” → 选择邮件列表 → 保存。加入链接也在这个页面。

### 3.4 RevenueCat 服务账号的 Play 权限

位置：Play Console 首页（账号级）→ “用户和权限” → RevenueCat 服务账号。

该服务账号已被添加为有效用户，并仅授予当前应用所需的三项权限：

- 查看应用信息和批量下载报告（只读）
- 查看财务数据
- 管理订单和订阅

未授予管理员、正式发布、测试轨道发布或商店资料编辑权限。

目的：RevenueCat 需要读取商品、订阅、订单和取消状态，但不应该拥有发布 App 或修改商店资料的能力。

### 3.5 License Testing（已通过 Play 安装包核验）

注意：这是 **Play Console 首页的账号级设置**，不是某个 App 页面里的设置。

位置：Play Console 首页 → “设置” → “许可测试 / License testing”。

已完成：

1. 选择当前内部测试使用的邮件列表或测试 Google 账号。
2. 保存更改。

Sandbox 购买时必须：

3. 购买弹窗必须明确显示 Google 的测试支付方式，例如 “Test card, always approves”。
4. 如果出现真实银行卡或真实金额扣费入口，立即取消，不能继续。

内部测试人员不自动等于 License Tester。只有 License Tester 才能使用不会真实扣款的测试支付方式。

2026-07-14 首次在侧载 Debug 包中看到真实支付入口并立即取消，原因是 License Testing 邮件列表尚未被实际勾选。勾选并保存名单后，同一侧载 Debug `0.3.5 (6)` 显示 `Test card, always approves` 与测试订阅声明，License Testing 验收通过。Google 官方允许 License Tester 使用同包名侧载 Debug 测试 Billing；该结果不证明 Play App Signing 分发包的安装、签名或更新链路。

### 3.6 Google Play 订阅商品（已激活）

位置：应用 → “通过 Play 创收 / Monetize with Play” → “商品” → “订阅”。

当前配置：

- Subscription Product ID：`premium`。
- `monthly`：每月自动续订，美国区基准价 `$2.99`，已启用。
- `annual`：每年自动续订，美国区基准价 `$20.00`，已启用。
- 两档均覆盖 174 个国家/地区；用户实际看到的价格以 Google Play 本地化价格为准。
- 月度宽限期 7 天、自动账号冻结期 53 天；年度宽限期 14 天、自动账号冻结期 46 天；两档均允许重新订阅。

2026-07-19 已执行配置：在 `premium` 订阅的 `monthly` base plan 下创建并启用 Offer `monthly-3d-trial`，资格为“新客户获取 → 从未拥有本 App 的任何订阅（Never had any subscription in this app）”，免费阶段 3 天，覆盖继承月卡现有 174/174 个国家/地区；免费阶段结束后进入现有月卡价格。年卡当前仍未挂接优惠；`annual-7d-trial` 只是本地实现采用的建议 ID，本轮没有远端配置授权或执行记录。

当前状态：`0.3.13 (16)` 已从 Play 验证月卡 3 天试用开始和首次 Sandbox 自动转正；月卡取消、到期和历史账号无资格仍未完成。`feat/new-feature@264af55` 的本地代码进一步支持年卡 7 天：只有 monthly `P3D` 或 annual `P7D` 且完整付费阶段存在时才显示试用，并在两档同时可用时默认月卡。RevenueCat `default` Offering 仍复用 `$rc_monthly → premium:monthly` 与 `$rc_annual → premium:annual`，无需新增 Product、Package、Entitlement 或 Offering。年卡 Offer 未配置，必须在单独授权后核对资格、范围、启用状态和 RevenueCat 返回结果，再按测试手册 §6.6 使用独立全新 License Tester 验证；不能把 App fake 数据或月卡证据扩写为年卡已上线。

Product ID 和 Base Plan ID 一旦启用后不能随意改名或复用，创建前应由用户确认产品命名、周期和价格，不能由 agent 猜测。

### 3.7 Google RTDN（已完成）

位置：应用 → “通过 Play 创收” → “变现设置 / Monetization setup” → “实时开发者通知”。

RevenueCat 已成功创建并连接：

`projects/healthhelper-482705/topics/Play-Store-Notifications`

已完成：

1. 从 RevenueCat 复制完整 Topic 名称，格式类似 `projects/.../topics/...`。
2. 粘贴到 Play Console 的 Topic name。
3. 通知内容选择订阅、作废购买和所有一次性商品。
4. 保存。
5. 点击“发送测试通知”。
6. 回 RevenueCat 确认出现最近接收时间。

## 4. Google Cloud 与 Google OAuth

项目入口：[Google Cloud 项目](https://console.cloud.google.com/home/dashboard?project=healthhelper-482705)

项目显示名称：`HealthHelper`

项目 ID：`healthhelper-482705`

### 4.1 Google OAuth 客户端

位置：[Google Auth Platform → 客户端](https://console.cloud.google.com/auth/clients?project=healthhelper-482705)。

现有三类客户端承担不同职责：

| 客户端 | 作用 | 本项目怎么用 |
|---|---|---|
| Web OAuth Client | 作为 Google ID token 的 server audience | 通过 `UGK_GOOGLE_SERVER_CLIENT_ID` 注入 App；Worker 的 `GOOGLE_CLIENT_ID` 必须匹配 |
| Android OAuth Client：`PushupAI Google Play` | 允许 Play 签名的 Android App 发起 Google 登录 | 绑定包名 + Play“应用签名密钥证书”SHA-1 |
| Android OAuth Client：`UGK Android Debug` | 允许本机 Debug 包发起 Google 登录 | 绑定包名 `com.ugkexercise.ugk_exercise` + 当前 Windows 用户默认 Debug 证书 SHA-1 `6B:D0:20:64:89:68:3B:63:6A:BA:52:68:6A:9C:5A:CF:1B:5F:4B:2B` |

Android Client 创建后不需要下载 JSON，也不需要把 Android Client ID 写入 Flutter 代码。代码使用的是 Web Client ID 作为 `serverClientId`。

`UGK Android Debug` 已于 2026-07-11 用本机 `debug` variant 的 `signingReport` 复核。该证书指纹是公开身份信息，不是私钥；真正的 keystore、密码和会员配置文件仍只保存在本机，禁止复制进仓库或聊天。

### 4.2 OAuth 受众和测试用户

位置：[Google Auth Platform → 目标对象/受众群体](https://console.cloud.google.com/auth/audience?project=healthhelper-482705)。

当前：

- 用户类型：外部
- 发布状态：测试
- 测试账号已加入测试用户列表

目的：OAuth 处于测试状态时，只允许受控账号完成授权。正式公开发布前，需要重新评估 OAuth 发布状态、品牌信息、数据访问范围和是否需要验证。

### 4.3 RevenueCat 服务账号与 GCP 角色

位置：[IAM](https://console.cloud.google.com/iam-admin/iam?project=healthhelper-482705) 和 [服务账号](https://console.cloud.google.com/iam-admin/serviceaccounts?project=healthhelper-482705)。

已创建 RevenueCat 专用服务账号。当前项目角色：

- `Monitoring Viewer`
- `Pub/Sub Admin`

最初使用 `Pub/Sub Editor`，RevenueCat 在创建 Pub/Sub Topic 时仍返回无权限。按 RevenueCat 官方排障建议改成 `Pub/Sub Admin` 后，权限传播完成，RevenueCat 已连接成功。

目的：

- 服务账号 JSON 让 RevenueCat 服务器代表本项目调用 Google Play Developer API。
- Monitoring Viewer 用来监控通知队列。
- Pub/Sub Admin 用来让 RevenueCat 创建和连接开发者通知 Topic。

### 4.4 已启用 API

- [Google Play Android Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=healthhelper-482705)
- [Google Play Developer Reporting API](https://console.cloud.google.com/apis/library/playdeveloperreporting.googleapis.com?project=healthhelper-482705)
- [Cloud Pub/Sub API](https://console.cloud.google.com/apis/library/pubsub.googleapis.com?project=healthhelper-482705)

### 4.5 RTDN 权限仍失败时

先等待 IAM 和服务凭据传播，不要反复新建服务账号。若 RevenueCat 已能创建 Topic，但 Play 的测试通知发送失败，则在该 Topic 的“权限”页给以下 Google 系统服务账号授予 `Pub/Sub Publisher`：

`google-play-developer-notifications@system.gserviceaccount.com`

这只在测试通知失败时添加，不要提前扩大其他账号权限。

## 5. RevenueCat

入口：[RevenueCat Dashboard](https://app.revenuecat.com/)

### 5.1 已创建的 Google Play App

位置：RevenueCat 项目 → Apps & providers / Apps → `PushupAI (Google Play)`。

已配置：

- App name：`PushupAI (Google Play)`
- Google Play package：`com.ugkexercise.ugk_exercise`
- Custom URL Scheme：已由 RevenueCat 生成，见私密台账
- Service Account Credentials JSON：已上传
- Public SDK Key：已写入本机 production build 配置文件，文档不抄值
- Financial reports bucket ID：保持空白

Financial reports bucket 主要用于财务报告导入，新应用当前不依赖它完成购买验证。

Custom URL Scheme 主要服务 RevenueCat paywall preview/deep link；当前 App 使用自定义会员弹窗，尚未把该 scheme 注册到 Android。除非开始使用 RevenueCat paywall preview，否则不是当前阻塞项。

### 5.2 Test Store 与 Google Play Store 的区别

- Debug/旧测试配置使用 RevenueCat Test Store key（前缀为 `test_`），只用于开发模拟。
- Play release 使用 Google Play Public SDK Key（前缀为 `goog_`），会走 Google Play Billing。
- `validateMembershipConfig()` 会拒绝 release 使用 Test Store key。

绝不能把 Test Store key 打进上传 Google Play 的 release 包。

### 5.3 Entitlement、Product、Package、Offering

代码固定检查 entitlement ID：`premium`。

代码购买流程会读取 RevenueCat 的 `current` Offering，展示标准月度/年度 Package，并购买用户明确选择的套餐。当前映射：

- `$rc_monthly` → Google Play `premium:monthly`；同时保留 Test Store Monthly 供本地测试。
- `$rc_annual` → Google Play `premium:annual`；不配置旧 SDK fallback。
- 两个 Google Play 商品均关联 entitlement `premium`。
- `default` 是当前 Offering。
- 月卡/年卡试用都不新增 entitlement、Product 或 Package；Google Play 优惠仍分别通过 `$rc_monthly` / `$rc_annual` Package 返回。App 只接受 monthly 的完整 `P3D` 和 annual 的完整 `P7D` 默认 option，并以对应完整付费阶段的本地化价格披露转正条款；其他时长或不完整阶段一律按普通套餐展示。
- RevenueCat/Play 对无资格账号应回退到 `monthly` base plan；App 不维护资格名单，也不允许通过 Test Store 结果声称 Google Play 资格已验证。

漏掉任一关联都会出现“购买入口存在但没有可购买 Package”或购买后不解锁 `premium`。

### 5.4 Sandbox Testing Access

位置：RevenueCat 项目 → Project Settings → General → Sandbox Testing Access。

首次内部 QA 可选 `Anybody`；若选择 `Allowed App User IDs only`，必须把当前 App 登录后由 Worker 分配的 App User ID 加入 allowlist。该设置影响 Test Store 和 Google Play sandbox 是否授予 entitlement，但不会阻止交易被记录。

正式购买测试前必须确认这里不是 `Nobody`。

查看测试 Customer 时还必须开启 RevenueCat Dashboard 的 `Show sandbox data`。关闭该开关时，Customer Profile 会按正式数据视图显示 `No current entitlements`，不能据此判断测试权益失败。

### 5.5 Google Developer Notifications 当前状态

位置：Google Play App 设置 → Service credentials 下方 → Google developer notifications。

Topic ID `Play-Store-Notifications` 已连接成功，完整路径为：

`projects/healthhelper-482705/topics/Play-Store-Notifications`

Play Console 已启用实时通知，通知内容选择订阅、作废购买和所有一次性商品；测试通知发送成功。RevenueCat 显示 `Last received 2026-07-10, 6:13 p.m. UTC`，RTDN 全链路已通过。

成功标准：

- RevenueCat 页面显示完整 Topic ID。
- Play Console 能保存该 Topic。
- Play “发送测试通知”成功。
- RevenueCat 显示最近收到通知的时间。

## 6. Android release 构建和本地签名

### 6.1 构建时配置

代码只认以下三个 `dart-define` 名称：

- `UGK_MEMBERSHIP_API_BASE_URL`
- `UGK_GOOGLE_SERVER_CLIENT_ID`
- `UGK_REVENUECAT_ANDROID_API_KEY`

Release 缺少任一值会 fail-fast；release 使用 `test_` RevenueCat key 也会 fail-fast。

Production AAB 构建命令：

```powershell
flutter build appbundle --release --dart-define-from-file=E:\AII\运动app-prod-info.txt
```

输出：`build\app\outputs\bundle\release\app-release.aab`

### 6.2 Gradle 签名

`android/app/build.gradle.kts` 从被 Git 忽略的 `android/key.properties` 读取：

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

Release 构建找不到该文件会直接失败，禁止回退到 debug 签名。

本机 Debug 构建使用当前 Windows 用户的默认 Flutter/Android Debug keystore（`%USERPROFILE%\.android\debug.keystore`），不读取 release 的 `android/key.properties`。因此同一 Windows 用户下的所有分支和 worktree 默认共享 `UGK Android Debug` OAuth 登录能力；前提是包名、Debug 签名和 `applicationIdSuffix` 未被修改。跨分支使用命令和换机规则见 [testing-release-playbook.md](testing-release-playbook.md#41-本机跨分支复用-debug-google-登录)。

`.gitignore` 必须持续忽略：

- `/android/key.properties`
- `*.jks`
- `*.keystore`

### 6.3 当前发布与下一候选

当前发布事实：

- 本会话于 2026-07-19 独立核对并发布：当前 Internal 为 `0.3.12-internal-1`，`versionCode=15`，已于 15:55（北京时间）面向内部测试人员全面发布，App Bundle 状态有效。
- 当前 Alpha 为 `0.3.11-closed-1`，复用同一 `versionCode=14` AAB，已于 2026-07-19 11:50 面向 Alpha 测试人员全面发布。
- `0.3.11 (14)` 包含窄距俯卧撑、标准 ×1/窄距 ×2 积分榜与本人分类次数、英文训练语音，以及首页、训练记录、运动广场和个人信息的主题表面优化。
- 用户报告 `0.3.11 (14)` Internal 测试通过，但未提供逐项清单；该结论不扩大为所有主链路或 Sandbox 购买均已复验。
- 经用户明确授权，`0.3.11-closed-1` 已复用 Internal 的同一 `versionCode=14` App Bundle，并于 2026-07-19 11:50 面向 Alpha 测试人员全面发布。
- `0.3.12 (15)` 源自 `main@5553576`，已完成发布门禁、签名 AAB 构建与核验，并于 2026-07-19 15:55 发布到 Internal；未推进 Alpha、开放测试或 Production。
- `0.3.12` 发布后独立审查以 `601d696` 为只读候选；主线程第一轮 `2cef529` 修复首次加载与正常 restore 路径，第二轮 `c92a00d` 继续覆盖分页、批量刷新、身份刷新、旧快照回填，以及 restore 失败后由 refresh 接受会员结论的路径，第三轮 `1edcc06` 统一头像政策后的有效 `/me` 会员状态接收并隔离跨上海周期迟到失败，第四轮 `3710a6f` 以请求级 lease 隔离账号切换时的新旧分页 loading，第五轮 `fbc6df8` 补齐头像政策 `/me` 调用前 guard 的精确竞态测试。第六轮独立复验确认代码、测试与当前台账内容通过；Play 运行反馈仍待用户完成，info 既有提交元数据格式修正仍需明确历史重写授权。这些修复均未进入已发布的 `versionCode=15` AAB。
- `0.3.13 (16)` 源自 `feat/new-feature@6374a3c`，包含 3 天免费试用的动态资格展示、转正月价披露、合格月卡 Offer 购买和无资格回退。候选通过 `flutter analyze` 0 issue、Flutter `601/601`、Worker `143/143`、回放 `5/5/3`；签名、上传证书、包名、`minSdk=24`、`targetSdk=35`、Release 不可调试及禁止权限检查通过。AAB 为 `187231668` 字节，SHA-256 `f491ea749b14a2cfa805adfa792090eba63f6fc0a0216f7389a024e7a90a9ea7`。发布名称 `0.3.13-internal-1`，Play Console 于 2026-07-19 23:46 显示“已面向内部测试人员发布”；未推进 Alpha、开放测试或 Production。
- 2026-07-20 的 Play 安装版验收使用全新 License Tester：安装器为 Google Play，版本 `0.3.13 (16)`，Google 登录成功；App 默认月卡并披露 3 天免费与试用后本地化月价。结算页明确显示测试卡和不收费声明，Sandbox 将生产 3 天/每月压缩为 3 分钟/每 5 分钟；一次测试订阅成功后 `INITIAL_PURCHASE` 与首个 `RENEWAL` 均已处理，D1 为 `premium / active / revenuecat_verified`，冷启动恢复和订阅管理入口通过。最后只读核对时订阅仍 active，未获本轮取消授权；取消、到期和历史订阅账号无资格仍待独立场景，不能扩写为完整试用矩阵通过。

<details>
<summary>历史 AAB 记录（0.3.1–0.3.7，仅供审计）</summary>

首次发布基线产物：

- 版本：`0.3.1 (2)`
- 已确认包含三项 release 配置
- 已确认上传签名证书正确
- 标准 JAR 签名完整性验证通过
- release 合并清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`

2026-07-11 Alpha 更新产物（已上传并提交审核，尚未确认获批）：

- 版本：`0.3.2 (3)`
- 历史本机路径：`E:\AII\ugk-post-account\build\app\outputs\bundle\release\app-release.aab`（同名输出现已被 `0.3.3 (4)` 覆盖）
- 大小：`184154578` 字节
- SHA-256：`9BCA49E196C76A37C13D83C6CE33962140E0F8959A8D1018E1C0790551CE5184`
- `flutter analyze`：0 issue；`flutter test`：228/228，回放基线 5/5/3
- JAR 签名完整性验证通过；release 合并清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`

2026-07-13 Alpha 产物（已发布并通过内部测试真机验收）：

- 版本：`0.3.3 (4)`
- 分支：`codex/alpha-0.3.3`；产物源提交：`6e8d9d3 build: prepare 0.3.3 alpha`
- 本机路径：`E:\AII\ugk-post-account\build\app\outputs\bundle\release\app-release.aab`
- 大小：`184774242` 字节
- SHA-256：`80BE40ABDFD9D8B3C14DCA70A20D184D54196A4C3706877B15C3F94CCA6F3E9D`
- 包名 `com.ugkexercise.ugk_exercise`；`minSdk=24`；`targetSdk=35`；release 不可调试
- Flutter `312/312`；Worker `106/106`；`flutter analyze` 0 issue
- JAR 签名完整，并与已记录的 Google Play 上传证书匹配
- release 合并清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`
- Play Console 中 `0.3.3 internal` 与 `0.3.3-closed-1` 均已面向测试人员发布；内部测试真机验收通过。

2026-07-14 Alpha 候选产物（内部测试验收通过，已向 Alpha 测试人员发布）：

- 版本：`0.3.4 (5)`
- 分支：`codex/alpha-0.3.4`；产物源提交：`c5f167c build: prepare 0.3.4 alpha`
- 本机路径：`build\app\outputs\bundle\release\app-release.aab`
- 大小：`184731165` 字节
- SHA-256：`9139AB07E7A71EA05FE4CA79D7E12085E7ED201BFF9DDE725D8EE66959253F43`
- 包名 `com.ugkexercise.ugk_exercise`；`minSdk=24`；`targetSdk=35`；release 不可调试
- Flutter `339/339`；Worker `108/108`；`flutter analyze` 0 issue；回放基线 `5/5/3`
- JAR 签名完整，并与已记录的 Google Play 上传证书匹配
- release 合并清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`
- 候选分支已推送；用户报告同一 AAB 已作为 `0.3.4-internal-1` 于 2026-07-14 09:59 面向内部测试人员发布，并确认从 Google Play 覆盖更新后，版本/数据保留、账号会员、训练计数与语音、排行榜切换刷新分页、布局和稳定性检查均通过。
- 用户报告同一 `5 (0.3.4)` App Bundle 已作为 `0.3.4-closed-1` 于 2026-07-14 10:42 在 Google Play 面向 Alpha 测试人员全面发布。

2026-07-14 `0.3.5 (6)` 内部测试候选产物（已构建并验证可从内部测试安装）：

- 配置记录 ID：`PLAY-AAB-20260714-01`。
- 分支：`codex/alpha-0.3.5`；产物源提交：`19bdbec732df547a204866a3b62fe02e66225fbb`。
- 本机路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`184824887` 字节；SHA-256：`118C249CC8D3F4C0C478B0CA312AFD2124E18953C5A8963E5191EB438ED910B2`。
- 包名 `com.ugkexercise.ugk_exercise`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- Flutter `346/346`；Worker `108/108`；`flutter analyze` 0 issue；回放基线 `5/5/3`。
- JAR 签名完整，并与已记录的 Google Play 上传证书匹配。
- release 清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`；包含 Billing 与 Internet 权限。
- 用途：上传 Google Play 内部测试轨道，从 Play 安装后验证月度/年度沙盒购买入口。
- 状态：同一候选已从 Google Play Internal Early Access 商店页安装；版本为 `0.3.5 (6)`，安装器为 `com.android.vending`，包不可调试。月度/年度 Sandbox 购买发生在侧载 Debug，Play 安装版验证的是 Google 登录和已有会员恢复，不得误记为再次购买通过。

2026-07-15 `0.3.6 (7)` 内部测试产物（用户报告已发布并完成非举报/屏蔽主链路验收）：

- 配置记录 ID：`PLAY-AAB-20260715-01`。
- 分支：`codex/alpha-0.3.6`；产物源提交：`a88ee5ad24c6dd8bc96a7209c325348d004c7255`。
- 本机路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`185452922` 字节；SHA-256：`1D86650BF70329A1FA06565392F846BE61316FE6C4E9C4E9703872498225BB16`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.6`；`versionCode=7`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- Flutter `363/363`；Worker `125/125`；`flutter analyze` 0 issue；回放基线 `5/5/3`。
- JAR 签名完整，并与台账记录的 Google Play 上传证书匹配。
- release 清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、`READ_EXTERNAL_STORAGE`、`WRITE_EXTERNAL_STORAGE` 或 `AD_ID`；包含 Billing 与 Internet 权限。
- 自定义头像生产依赖已有记录证明完成：规则页面、私有 R2、D1 `0004`、Access 和 Worker 已部署并回验。
- 状态：用户报告发布名称 `0.3.6-internal-1` 已于 2026-07-15 09:14（北京时间）面向内部测试人员发布，包含 1 个版本代码；随后在模拟器中从 Google Play 将 `0.3.5 (6)` 覆盖更新为 `0.3.6 (7)`，确认安装器为 `com.android.vending`、包不可调试，启动、登录态、自定义头像和运动广场状态保留。更新后首次页面短暂沿用本地会员缓存，冷启动联网刷新后变为非会员；Google Play 订阅页未显示有效 PushupAI 订阅，结果与加速 Sandbox 订阅已过期一致，不记为会员恢复失败。用户随后报告在 `0.3.6 (7)` 中修改头像和重新开通 Google Play Sandbox 会员均通过；该测试交易不是真实扣款，也不代表 Production 购买通过。Google Play 的 UGC、Data safety 和内容分级声明尚未记录为完成，因此不得推进 Alpha 或 Production。
- 用户补充验收：重新开通 Sandbox 会员并刷新后，当前账号恢复显示排名；榜单显示最新头像；删除自定义头像后默认头像回退正常。
- 2026-07-15 后续用户验收：训练计数、语音、训练保存和记录页；中英文与浅色/深色主题；排行榜退出后重新加入及资料恢复；头像拍照、1:1 裁剪、取消、断网失败保护和联网重试；同账号退出后重新登录、会员恢复、排名及公开资料恢复均通过。
- 发布边界：上述 Play AAB 固定对应 `a88ee5a`。其后加入的屏蔽名单、启动引导、首页视觉、记录切换动效、交互确认和长按举报/屏蔽入口均不在 `0.3.6 (7)` 中；这些能力后来只在带 production 配置的 Debug 模拟器完成验收。不得复用 versionCode 7；新版候选见下方 `0.3.7 (8)` 记录。
- 后续 production Debug 验收：屏蔽名单空态、屏蔽后榜单隐藏、解除屏蔽后恢复、受控账号举报后自动屏蔽，以及举报加载/成功反馈、长按主题操作面板均通过；生产 Worker 已上线 `GET /me/blocks`。举报记录按合同保留，该结果不冒充 Play 安装版验收。

2026-07-15 `0.3.7 (8)` 内部测试版本（用户报告已发布并安装）：

- 配置记录 ID：`PLAY-AAB-20260715-02`。
- 分支：`codex/play-0.3.7-candidate`；产物源提交：`7c7570c`。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`185375670` 字节；SHA-256：`696D0045CF9FE16EC9D297BC60A3BE1741C27C33577C3EB44AC13C76C76F2D96`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.7`；`versionCode=8`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `392/392`；Worker `126/126`；回放硬基线 step0=5 / v3=5 / v4=3。
- `jarsigner` 退出码 0 且英文区域明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- 用户报告：已由用户上传至 Google Play 内部测试、通过审核，并在测试机安装新的内测版本；本会话未读取 Console 或设备证据，因此不补写精确发布时间、发布名称、安装来源或完整功能验收结论。
- 用户后续报告升级保留冒烟通过：连续两次冷启动未重复出现引导；登录状态、头像、主题和历史记录保留；首页测试按钮已隐藏，浅色与深色首页显示正常。
- 计数语音尾音修正及本轮新增体验仍待 Play 安装版人工回归；Google Play UGC、Data safety 与内容分级增量声明尚未记录完成，不得据此直接推进 Alpha 或 Production。

</details>

2026-07-16 `0.3.8 (9)` Google Play 内部测试版本（用户报告已发布）：

- 配置记录 ID：`PLAY-AAB-20260716-01`。
- 基线：`main@465172f`；分支：`codex/play-0.3.8-candidate`；产物源提交：`73759a28521fa699198024ea95f152c15fffe702`。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`185368438` 字节；SHA-256：`66E0C68B4F538754DC7233B58B11CE56D4FE24AB5D1440D7C51DFCF910D2C95F`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.8`；`versionCode=9`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `397/397`；Worker `137/137`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且英文区域明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- 用户报告：发布名称 `0.3.8-internal-1` 已面向内部测试人员发布，包含 1 个版本代码；Console 显示发布时间为 2026-07-16 10:05。本会话未独立读取 Console 证据。
- 尚未报告从 Play 安装、覆盖更新、Google 登录或 Billing 冒烟；未推进 Alpha、未送审。购买后的强制对账与恢复路径仍须从 Play 安装此版本后验证。

2026-07-16 `0.3.8 (10)` Google Play 内部测试版本（Console 已独立核对发布）：

- 配置记录 ID：`PLAY-AAB-20260716-02`。
- 基线：`main@465172f`；分支：`codex/play-0.3.8-candidate`；产物源提交：`ad19ccffe812b8ed515c1d5a8278c09352aef129`。
- 改动：修复系统关闭动画时引导页无法前进；过期会员的当前日/周历史成绩只对本人显示，不占公开名次。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`；构建时间：2026-07-16 11:05:23（北京时间）。
- 大小：`185386041` 字节；SHA-256：`BE1761A4A98EEEFACFDABAE2189EF0E8B59C26DDE3D36D328B92C34E10C0364D`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.8`；`versionCode=10`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `402/402`；Worker `138/138`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且明确返回“jar 已验证”；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- Worker 已于 2026-07-16 11:12:08（北京时间）使用 `--keep-vars` 部署；未执行 D1 migration、未修改变量或 Secret，生产 `/membership` 未登录探针返回预期 `401`。精确部署版本只记录在本机私密台账。
- Play Console 已独立核对：发布名称 `0.3.8-internal-2` 于 2026-07-16 11:18（北京时间）面向内部测试人员发布，包含 `versionCode=10`。
- 用户已从 Play 更新并进入 `0.3.8 (10)` 的运动广场，真机确认首版规则会把过期本人移出公开排名、只显示冻结卡；其余完整回归尚未记录完成，未推进封闭测试、Alpha 或 Production。
- 用户随后明确修订为“加入后只有主动退出才移除；会员过期后公开保留冻结成绩并继续参与排序”。源提交 `cf1014e` 的 Worker 已于 2026-07-16 12:13:41（北京时间）使用 `--keep-vars` 部署；未执行 D1 migration，未修改变量、Secret 或 binding，三个生产未登录鉴权探针均返回预期 `401`。现有 `0.3.8 (10)` App 直接兼容，未重建或上传 AAB。
- 用户随后报告刷新运动广场后已看到过期账号的公开排名行，同时本人冻结卡仍保留，核心线上真机验收通过；该结论不扩大为日榜/周榜双周期、其他账号视角、续费/退出或整版回归均已人工验证。

2026-07-16 `0.3.8 (11)` 内部测试已验证，Alpha 已发布：

- 功能提交：`eef876b`；版本提交：`e9feee8`；AAB 源提交：`e1dacfb`；分支仍为 `codex/play-0.3.8-candidate`。
- 改动：续费成功后运动广场立即监听会员状态并移除冻结提示；修正首页训练卡圆角边界；统一 Android 原生 Splash 与 Flutter 启动画面；品牌图保持静态，启动口号以 400ms 透明度渐显。
- 本地验证：`flutter analyze` 0 issue；Flutter `407/407`；Worker `138/138`；`git diff --check` 通过；带本机配置的 Debug APK 已覆盖安装到模拟器，用户确认启动视觉符合预期。
- 边界：续费后即时刷新已有 Widget 自动化证据，尚未在下一 Play 安装版完成真实 Sandbox 续费回归。
- 产物：`build\app\outputs\bundle\release\app-release.aab`；构建时间 2026-07-16 16:35:39（北京时间）；大小 `185676676` 字节；SHA-256 `2E1718DE9BA542619ED2A4974AC5E603EDDFB3424ECCB0F9606F25645F0042F6`。
- 产物核验：包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.8`；`versionCode=11`；`minSdk=24`；`targetSdk=35`；release 不可调试；JAR 完整签名和上传证书匹配；包含 Billing/Internet，不包含媒体、外部存储或 `AD_ID` 权限；production 配置字段齐全且 RevenueCat Key 不是 Test Store Key。
- 内部测试状态：Play Console 已独立核对发布名称 `0.3.8-internal-3` 于 2026-07-16 16:54（北京时间）面向内部测试人员发布，包含 1 个版本代码（11）。用户随后报告测试未发现明显问题，但未提供逐项清单；真实 Sandbox 续费及整版完整回归仍未单独记录。
- Alpha 状态：经用户明确授权，复用同一 `11 (0.3.8)` App Bundle 创建 `0.3.8-closed-1`，发布比例 `100%`，未重新构建或上传另一份产物。2026-07-17 已由 Console 独立核对：该版本于 2026-07-16 17:54（北京时间）面向 Alpha 测试人员全面发布。
- 发布边界：本轮未推进开放式测试或 Production。此前 `0.3.8 (10)` AAB 不包含这些体验优化，不能冒充本版本。

2026-07-17 `0.3.9 (12)` Google Play 内部测试版本（用户报告已发布）：

- 配置记录 ID：`PLAY-AAB-20260717-01`。
- 基线：`main@dacc643`；分支：`codex/play-0.3.9-candidate`；产物源提交：`3bb285b121b9f66261f22a6b3ec2151cfbf0047c`。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`；构建时间：2026-07-17 09:29:38（北京时间）。
- 大小：`185760971` 字节；SHA-256：`2C481E6AC5EF06587B65FAC9E46A83E66F936BAAD320EF30FB6A15BD8A7F305C`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.9`；`versionCode=12`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `412/412`；Worker `138/138`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- Play Console 构建前只读核对：最高版本代码为 11；Internal `0.3.8-internal-3` 和 Alpha `0.3.8-closed-1` 均已向对应测试人员全面发布。
- 发布状态：用户报告发布名称 `0.3.9-internal-1` 已通过审核并面向内部测试人员发布，包含 1 个版本代码；Console 显示发布时间为 2026-07-17 09:53（北京时间）。本会话未独立读取 Console；尚未记录 Play 覆盖更新或真机功能验收。

2026-07-17 `0.3.10 (13)` Google Play 内部测试版本（用户报告已发布）：

- 配置记录 ID：`PLAY-AAB-20260717-02`。
- 分支：`codex/play-0.3.10-candidate`；产物源提交：`00ac78c5fab6922953d868b91ceb18fdfc91d0d7`。
- 候选变更：修复版本入口被浏览器当作包名搜索的问题；账号、头像与会员状态改为全局单一状态源，首页、个人页、记录页和运动广场同步刷新。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`；构建时间：2026-07-17 14:00:44（北京时间）。
- 大小：`185757585` 字节；SHA-256：`6142593CB9DBE2CF787771E5511EAD42BE7A79B4B068345C08B2BBA31CC2054D`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.10`；`versionCode=13`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `423/423`；Worker `138/138`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- 本次没有 Worker、D1 或 API 合同变更，不需要后端部署。
- 发布状态：用户报告发布名称 `0.3.10-internal-1` 已通过审核并面向内部测试人员发布；未提供 Console 精确发布时间。本会话未独立读取 Console；Play 安装验收仍待记录。
- 用户随后报告初步测试未发现明显问题；未提供逐项清单，因此不扩大为完整回归通过。
- Alpha 状态：用户报告复用同一 `0.3.10 (13)` AAB 创建 `0.3.10-closed-1` 并提交审核；当前尚未记为审核通过或发布，本次未推进开放测试或 Production。
- 主线同步：候选分支完整历史已通过 fast-forward 纳入本地 `main`，同步基线为 `2bd7333`；发布 AAB 未重建，产物哈希不变。

2026-07-19 `0.3.11 (14)` Google Play 内部测试版本（已全面发布）：

- 配置记录 ID：`PLAY-AAB-20260719-01`。
- 基线：`origin/main@70ea843`；分支：`codex/play-0.3.11-candidate`；AAB 源提交：`99065aa9f9a247feb0ba04c677139f450b6cfcb5`。
- 候选变更：新增窄距俯卧撑；排行榜改为标准 ×1、窄距 ×2 的积分制并显示本人分类次数；补齐英文训练语音；统一首页、训练记录、运动广场和个人信息的浅深色主题表面。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`187209320` 字节；SHA-256：`14C67651B9ADD7DE19EAB04E5CD5E401F7176BC17B14B422801721D9AC8D118F`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.11`；`versionCode=14`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `530/530`；Worker `142/142`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体/外部存储权限或 `AD_ID`；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- 发布状态：用户报告审核通过；本会话随后于 2026-07-19 独立只读核对 Play Console：`0.3.11-internal-1`、`versionCode=14` 已于 11:10（北京时间）面向内部测试人员全面发布，App Bundle 状态有效。
- Internal 验收：用户报告测试通过，但未提供逐项清单；不据此扩写未明确验证的完整功能、更新或 Sandbox 购买场景。
- Alpha 草稿：经用户明确授权，复用同一 `versionCode=14` App Bundle 创建 `0.3.11-closed-1`，发布比例 100%，中英文版本说明已保存；设备支持范围相对上一 Alpha 无减少。
- Alpha 发布状态：本会话于 2026-07-19 独立核对，`0.3.11-closed-1` 已于 11:50（北京时间）面向 Alpha 测试人员全面发布。
- 发布边界：本轮未重新上传 AAB，未推进开放测试或 Production，未部署 Worker、未写 D1、未修改任何平台配置。

2026-07-19 `0.3.12 (15)` Google Play 内部测试版本（已全面发布）：

- 配置记录 ID：`PLAY-AAB-20260719-02`。
- 基线：`origin/main@5553576`；分支：`codex/play-0.3.12-candidate`；AAB 源提交：`e6659dd023905ccda9dbc293d96b9bc98fbcf649`。
- 候选变更：优化实时训练页的信息层级与操作体验；精简启动流程并稳定首页排名加载；修复窄距训练提示闪烁，并将手腕宽度容差从肩宽的 `1.15` 放宽到 `1.25`。
- 本机相对路径：`build\app\outputs\bundle\release\app-release.aab`。
- 大小：`187198161` 字节；SHA-256：`8EEB7E1F9F7616326565F43146014A4B5FE10ABD0C6C6C8FA2DCE3EAA71F9789`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.12`；`versionCode=15`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- `flutter analyze` 0 issue；Flutter `564/564`；Worker `142/142`；回放硬基线 step0=5 / v3=5 / v4=3；`git diff --check` 通过。
- `jarsigner` 退出码 0 且明确返回 `jar verified`；上传证书与权威私密台账一致。
- release 清单包含 Billing 与 Internet，不包含媒体、外部存储或 `AD_ID` 权限；production 三项配置存在，RevenueCat Key 不是 Test Store Key。
- 发布状态：本会话经用户授权上传同一核验 AAB，保存中英文版本说明，并以 `0.3.12-internal-1` 发布到 Internal；Play Console 显示 `versionCode=15` 已于 2026-07-19 15:55（北京时间）面向内部测试人员发布。
- Play 预览确认手机、平板、电视、Chromebook 与 Android XR 的支持设备数量相对上一版本均无减少；新安装大小约 41.2 MB，更新大小约 1.3 MB。
- Play 安装验收尚未执行；“已发布”不能扩大为覆盖更新、数据保留或本轮功能真机回归已通过。
- 后端边界：本候选没有 Worker、D1 或 API 合同变更，不需要后端部署。

发布后独立审查与修复记录（2026-07-19）：

- 审查线程只读核对需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果；候选基线为 `601d696`，修复/测试提交为 `2cef529`、`c92a00d`、`1edcc06`、`3710a6f`、`fbc6df8`。
- 修复一：每份日榜/周榜内存快照显式绑定请求时的上海周期 scope；首次加载、分页、批量刷新、身份刷新、当前快照回填和本地屏蔽过滤均不会读取、合并或保留已过期快照。
- 修复二：恢复本地账号后仅在服务端会员核验尚未完成时允许显示缓存排名；任一有效 `/me` 快照被 restore 或 refresh 接受时统一结束 pending，服务端确认非会员后立即隐藏，不受后续本地持久化或 RevenueCat 阶段影响。
- 新增精确边界与兼容测试：窄距腕宽 `1.25` 及 epsilon、提示防抖页面销毁/重建、积分榜拒绝 v1 次数游标、旧 Worker 排行榜响应的安全失败与本地化重试。
- 第二轮新增日/周分页跨界、已有旧快照跨界批量刷新、身份刷新和 restore 失败后 refresh inactive 五个回归测试；本地门禁为 `flutter analyze` 0 issue、Flutter `574/574`、Worker `143/143`、回放硬基线 step0=5 / v3=5 / v4=3、`git diff --check` 通过。
- 第三轮补齐头像政策接受后的有效 `/me` 统一结束会员核验 pending，以及日/周首次加载、分页和身份刷新在跨上海周期后迟到失败不污染快照、首页排名、错误或 loading 状态；本地门禁为 `flutter analyze` 0 issue、Flutter `581/581`、Worker `143/143`、回放 `31/31` 且硬基线 step0=5 / v3=5 / v4=3、`git diff --check` 通过。独立第四轮复验随后指出分页 loading 仍有账号切换竞态，并确认头像守卫与批量刷新失败测试证据不足。
- 第四轮将分页 loading 改为绑定 generation、session、账号、上海周期和 cursor 的请求级 lease；旧账号成功或失败的分页均不能释放新账号 lease，且新分页完成前重复请求被拒绝。迟到头像测试改为 A 账号 active 快照与 B 账号 pending 状态正面对照，并新增普通日界、周界 `refreshAll` 迟到失败及当前周期可重试失败测试。本地门禁为 `flutter analyze` 0 issue、Flutter `586/586`、Worker `143/143`、回放 `31/31` 且硬基线 step0=5 / v3=5 / v4=3、`git diff --check` 通过。
- 独立第五轮确认代码、分页 lease、`refreshAll` 与当前台账通过，但指出头像测试只守护 `/me` 返回后的第二个 guard。第五轮新增阻塞旧账号 `acceptAvatarPolicy` 的竞态：切换并恢复 B 账号 pending 后释放 A 请求，断言 A 不得再调用 `/me`，B 的 user、membership 与 pending 均不变；与既有迟到 `/me` 测试共同守护调用前后两个 guard。本地门禁为 `flutter analyze` 0 issue、Flutter `587/587`、Worker `143/143`、回放 `31/31` 且硬基线 step0=5 / v3=5 / v4=3、`git diff --check` 通过。
- 第六轮独立只读复验确认代码、逻辑、边界、质量、测试与当前台账内容通过；独立实跑为 `flutter analyze` 0 issue、Flutter `587/587`、账号控制器 `36/36`、Worker `143/143`、回放 `31/31` 且硬基线 step0=5 / v3=5 / v4=3、`git diff --check` 通过。原审查任务连续三次启动级 system error 后，替代 Codex 任务也同样启动失败，最终由隔离只读审查代理完成 Standards/Spec 双轴复验；未以主线程自审替代。
- 当前结论是“代码/测试/当前台账内容通过”；仍待用户完成 Play `0.3.12 (15)` 运行反馈。info 仓当前 tracked 内容未检出个人邮箱，后续提交身份已改为 `users.noreply.github.com`；既有可达提交元数据格式修正属于历史重写，必须另行取得明确授权并先完成可验证备份。
- 本轮只修改源码、测试和台账；未重新构建或上传 AAB，未修改 Play 轨道，未部署 Worker、未写 D1、未修改 Secret、变量或 binding。由于 `versionCode=15` 已发布，若后续要把这些修复送入 Internal，必须使用更高的 `versionCode` 并另行获得发布授权。
- 实际运行结果仍待用户从 Google Play 覆盖更新 `0.3.12 (15)` 后反馈：版本与安装来源、数据保留、首页排名加载、运动广场、实时训练页、启动流、窄距提示与容差、中英文、浅深色及安全区。

官网直装 APK：

- 来源：从 Play Console 的 `5 (0.3.4)` App Bundle 下载“已签名的通用 APK”，不是使用本机上传密钥重新构建的 APK。
- 大小：`317226209` 字节；SHA-256：`1F45FFD3AD5F7E59D3FF8FEC6DD5A900E6980B3F4B1AE2E342CA0CEA1B8499E7`。
- 包名 `com.ugkexercise.ugk_exercise`；`versionName=0.3.4`；`versionCode=5`；`minSdk=24`；`targetSdk=35`；release 不可调试。
- APK Signature Scheme v2/v3 验证通过；签名证书不同于上传 AAB 的上传证书，符合 Play App Signing 分发产物特征。
- 不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`。
- Cloudflare R2 公共下载地址：`https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk`；已从该 HTTPS 地址完整回下载，字节数与 SHA-256 均匹配。
- `r2.dev` 仅作为当前 Alpha 阶段的临时下载端点，正式大规模分发前应绑定项目自定义域名。
- 官网已配置下载链接、版本/大小/SHA-256 和可解码二维码；网站测试 `44/44`，桌面与 390px 移动浏览器验收通过。Cloudflare Pages 于 2026-07-14 从 `main` 合并提交 `5b77bd8` 手动生产部署成功；本会话已回验线上首页、二维码 PNG 哈希和 APK 链接，用户确认页面显示正常，并报告 Android 真机下载、安装和使用正常。

注意：AAB 是可重建产物，不是密钥备份。构建目录会被 Git 忽略。

### 6.4 Google Play AAB 标准打包 SOP

任何 agent 打包前都必须走完本节。真实 JKS、密码记录和构建配置位置只在本机私密台账中读取，不把值复制到聊天或命令输出。

#### 6.4.1 打包前检查

1. 从已同步的 `main` 创建独立候选分支；不直接在含未提交代码的 worktree 打包。
2. `git status --short --branch` 只允许已知的用户未跟踪文件；不删除、不 stage 它们。
3. `pubspec.yaml` 使用 `versionName+versionCode` 格式；`versionCode` 必须高于 Play Console 中所有已上传版本。先单独提交版本号，再打包。
4. 当前 worktree 必须存在被 Git 忽略的 `android/key.properties`，且包含 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`四个字段。只检查字段存在，不输出值。
5. production `dart-define` 文件必须存在，且包含：
   - `UGK_MEMBERSHIP_API_BASE_URL`
   - `UGK_GOOGLE_SERVER_CLIENT_ID`
   - `UGK_REVENUECAT_ANDROID_API_KEY`
6. Release 配置缺值或使用 RevenueCat `test_` Key 必须由 `validateMembershipConfig()` 直接阻止；禁止为了构建成功绕过校验。
7. 运行：

   ```powershell
   flutter analyze
   flutter test
   cd workers/membership-api
   npm test
   ```

   Worker 没有改动时仍建议在发布候选上复跑，确保 App 与已部署合同没有漂移。

#### 6.4.2 构建

```powershell
flutter build appbundle --release --dart-define-from-file=E:\AII\运动app-prod-info.txt
```

固定输出：

`build\app\outputs\bundle\release\app-release.aab`

不在命令行直接传入任何 Key/Secret 值，不打印 `android/key.properties` 或 production 配置文件内容。

#### 6.4.3 产物必检项

1. `jarsigner -verify -verbose -certs` 返回成功，并明确出现 `jar verified`。自签名上传证书的 PKIX/时间戳警告可以存在，但退出码不能失败。
2. `keytool -printcert -jarfile <AAB>` 的 SHA-1 必须与私密台账记录的 Google Play 上传证书一致。
3. 检查本次 Gradle bundle 直接输入：
   - `build/app/intermediates/bundle_manifest/release/processApplicationManifestReleaseForBundle/AndroidManifest.xml`
   - `build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json`
4. 必须核对：包名、`versionName`、`versionCode`、`minSdk`、`targetSdk`、release 不可调试。
5. 必须确认 release 清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`。
6. 记录 AAB 字节大小和 SHA-256：

   ```powershell
   Get-Item build\app\outputs\bundle\release\app-release.aab
   Get-FileHash -Algorithm SHA256 build\app\outputs\bundle\release\app-release.aab
   ```

7. 本机 Android SDK 的 `apkanalyzer` 针对 APK，不要用它解析 AAB；Gradle 缓存中的 `bundletool-*.jar` 是库 JAR，不要假设可直接 `java -jar`。优先使用上述签名工具 + Gradle bundle manifest/元数据。

#### 6.4.4 记录与上传

1. 在 App 公开台账记录：版本、分支、产物源提交、大小、SHA-256、测试、签名/权限结论和是否已上传。
2. 在本机 info 私密台账记录真实产物路径、上传证书核验、Play Console 轨道/状态和回滚依据；不记录凭据值。
3. AAB、JKS、`key.properties` 和 production 配置文件不进 Git。
4. 上传前必须获得用户明确授权，并先核对 Play Console 中上一版的状态。
5. 先用这一份 AAB 走内部测试，从 Play 安装后验收签名、更新、Google 登录和主链路；通过后再把同一份 AAB 推进封闭测试，不重新构建。

## 7. Cloudflare Worker 与 D1

入口：[Cloudflare Dashboard](https://dash.cloudflare.com/)

本项目资源：

- Worker：`ugk-membership-api`
- D1：`ugk-membership`
- D1 binding：`DB`
- 配置文件：`workers/membership-api/wrangler.toml`

Worker 当前代码要求四个会员/登录 Secret 或变量名：

- `GOOGLE_CLIENT_ID`
- `SESSION_SECRET`
- `REVENUECAT_WEBHOOK_SECRET`
- `REVENUECAT_SECRET_API_KEY`

不要把它们的值写进 `wrangler.toml`、仓库、日志或文档。应只通过 Cloudflare Dashboard 或交互式 `wrangler secret put` 管理。

2026-07-13 的核对结果：

- Wrangler `4.107.1`
- D1 排行榜公开身份迁移 `0003_leaderboard_identity.sql` 已应用，远端无待迁移项
- 新 Worker 已使用 `--keep-vars` 部署，未改动 Secret、变量或 D1 binding；精确版本和验证证据只在本机私密台账中记录
- 线上排行榜与身份更新路由在未登录时均返回 `401`，鉴权仍生效
- 可用部署 Token 只保存在受保护的本机文件中，文档只记录键名和轮换流程，不记录值

排行榜公开身份的上线顺序必须保持：

1. 先应用 D1 `0003` 迁移。
2. 再部署新 Worker，并保留 Dashboard 变量。
3. 验证 Worker 后，才安装或发布新 App。

旧 App 连接新 Worker 是安全的：无身份 body 的加入请求仍默认匿名。新 App 不得连接旧 Worker，否则排行榜会因缺少当前用户的稳定匿名头像键而加载失败。新 App 已发布后不要单独回滚 Worker；回滚 App 到旧版是安全的。

2026-07-13，带 production 会员配置的 Debug `0.3.2 (3)` 已保留数据覆盖安装，用户确认本次排行榜公开身份界面与交互验收通过。该结论不代表 Google Play 签名、安装或更新链路已验收。

2026-07-15，侧载 Debug `0.3.5 (6)` 的 Google Play Billing Sandbox 通过：RevenueCat Webhook 已接收年度 `INITIAL_PURCHASE`，D1 `membership_snapshots` 为 `premium / active`；此前月度 `RENEWAL`、`CANCELLATION`、`EXPIRATION` 事件均已处理。远端 `/membership` 鉴权响应未被单独抓取，不能把 D1 查询扩写成该接口已独立验证。查询只读取脱敏状态，未修改 Worker、D1、Secret 或线上配置。

2026-07-16，会员单一权威修复已完成服务端生产上线：D1 已备份并应用 `0005_membership_verified_at.sql`，Cloudflare 已配置 `REVENUECAT_SECRET_API_KEY`，`main@56a4f31` Worker 已部署。生产未登录探针确认 `POST /membership/reconcile`、`GET /me`、`GET /membership` 均返回预期 `401`。真机 Play `0.3.7 (8)` 先验证过期 Sandbox entitlement 权威收敛为 inactive，再通过新的 Sandbox 购买和真实业务请求把 D1 自动更新为 `revenuecat_verified + active`；全程未手工修改会员快照。`flutter analyze` 0 issue，Flutter `397/397`，Worker `137/137`，回放硬基线 `5/5/3`，带本机会员配置的 Debug APK 构建成功。随后在模拟器侧载 `main@82bddbe` 的同配置 x86_64 Debug 包：登录后个人页显示会员、运动广场正常，冷启动后两处仍一致；卸载重装清除 App 本地数据后，同一账号重新登录仍由线上恢复会员；点击“恢复会员权益”无错误，D1 `verified_at` 随之刷新且仍为 `revenuecat_verified + active`。包含 Flutter 购买/恢复强制对账语义的 `0.3.8 (9)` 已于内部测试发布；`0.3.8 (10)` 也已发布并由用户从 Play 更新，过期账号排名核心链路已通过。包含续费即时刷新和最新启动视觉的 `0.3.8 (11)` 已在内部测试发布，用户报告测试未发现明显问题；同一 AAB 已以 `0.3.8-closed-1` 于 2026-07-16 17:54 面向 Alpha 测试人员全面发布。

2026-07-18，窄距俯卧撑与积分榜兼容 Worker 已按“Worker → 生产探针 → App”顺序先行上线。部署源为 `codex/home-card-compact@af6d95e`，其中生产 Worker 源码与已审核的 `b2233fc` 相同；部署使用 `--keep-vars`，未执行 D1 migration，未修改变量、Secret 或 binding。发布前 `flutter analyze` 0 issue、Flutter `500/500`、Worker `142/142`、`git diff --check` 与 Wrangler dry-run 均通过；生产 `pushup_points_v1` 查询、旧 App `exerciseType=pushup` 查询和训练同步的未登录探针均返回预期 `401`。精确部署版本与回滚依据只记录在本机私密台账。当前只证明新 Worker 已上线且鉴权边界正常；仍需用带本机构建配置的新 App 和有效测试会话验证标准 `N` 次加窄距 `M` 次显示为 `N + 2M` 分，之后才能发布 App。

2026-07-18，用户报告 main 审核通过后，已从 `codex/home-card-compact@8ac3821` 部署本人分类次数 Worker。积分响应现在只在根级返回当前用户所选日/周的 `pushup` 与 `narrow_pushup` 原始次数，其他排行行不含该明细；App 对字段缺失保持向后兼容。部署使用 Wrangler `4.107.1 --keep-vars`，未执行 D1 migration，未写 D1，也未修改变量、Secret 或 binding。部署前 Worker `142/142` 与 Wrangler dry-run 通过；部署后 Active Version 匹配，积分日榜、积分周榜、旧标准次数榜和训练同步的未登录探针均返回预期 `401`。精确版本和回滚依据只记在私密配置记录 `CF-WORKER-20260718-POINTS-BREAKDOWN-V1`；当前仍需用户刷新已安装的 Debug App，确认卡片实际显示本人分类次数。

会员对账上线顺序固定为：

1. 取得用户对远端 D1 写入的单独授权，备份后应用 `0005`；
2. 取得平台配置授权，通过 Cloudflare Secret 配置 `REVENUECAT_SECRET_API_KEY`，不输出其值；
3. 取得部署授权，部署 Worker 并验证 `/membership/reconcile`、Webhook 重试和旧 App 兼容；
4. 用测试账号证明过期 D1 可由 RevenueCat 当前状态自动恢复，禁止手工把快照改成 active；
5. 最后才构建并发布包含 Flutter 权威语义的新版 App。

### 7.1 自定义头像 UGC 上线配置

本地代码使用以下公开配置名，不在文档记录其值：

- R2 binding：`AVATAR_BUCKET`，bucket 名 `ugk-profile-avatars`；bucket 必须保持私有。
- D1 migration：`workers/membership-api/migrations/0004_custom_avatar_ugc.sql`。
- Cloudflare Access Worker 变量：`ACCESS_TEAM_DOMAIN`、`ACCESS_AUD`。
- 审核入口：`/admin/avatar-reports`；Worker 仍会验证 `Cf-Access-Jwt-Assertion` 的签名、issuer、audience 和操作者身份，不能只依赖 Access 网关或请求头存在。
- 内容规则版本：`2026-07-14`，权威常量为 `workers/membership-api/src/account.ts` 的 `avatarPolicyVersion`。

生产上线必须严格分步：

1. 发布[用户头像内容规则](policies/user-content-policy.md)及相应隐私/账号删除说明；
2. 经单独授权创建私有 R2 bucket；
3. 经单独授权应用 D1 `0004` migration，并记录备份/回滚证据；
4. 经单独授权建立默认拒绝的 Access 应用，只允许明确管理员身份，并配置 Worker 所需变量；
5. 经单独授权部署 Worker，验证 R2 私有、公开头像读取、403 拒绝、举报队列、过期版本保护和审核审计；
6. 安装候选 App 完成真机流程与 300 秒缓存下架验证；
7. 经单独授权更新 Google Play Data safety、用户生成内容和内容分级声明；
8. 经单独授权上传产物并推进测试轨道。

回滚时先停止 App 端入口或回滚候选 App，再保持新 D1 schema 兼容旧客户端；不得先删除 bucket 或回退 migration。若审核责任暂时无人承担，应暂停公开头像能力。精确资源 ID、Access 域、audience、部署版本和远端证据只记录在本机私密台账。

## 8. 本机秘密与备份

精确账号标识、文件路径、上传证书指纹和轮换方法见：

`E:\AII\secrets\PushupAI-发布与密钥台账.md`

最低备份要求：

1. 上传 keystore 和对应密码记录必须成对备份。
2. Production build 配置文件要备份，但不得进入 Git。
3. RevenueCat Play 服务账号 JSON 是高危私钥文件；只放加密存储，泄露后立即轮换。
4. 至少保留两份加密离线备份，存放在不同介质。
5. 不要把密钥粘贴进聊天、Issue、PR、日志、截图或未加密云盘。

## 9. 首次发布分支历史与当前可复现性

以下 `feat/account-features` 与首次 AAB 描述仅记录 `0.3.0` 建立发布链路时的历史。当前候选以 §6.3 的最新版本、提交和产物证据为准。

功能分支：`feat/account-features`

首次 Play AAB 是在本分支最终整理提交之前构建。它对应的功能内容包括：

- Google Play upload signing 配置与 `.gitignore`
- 非会员加入排行榜时的正确提示与 Worker `canJoin` 合同
- 对应 Flutter/Worker 测试

这些内容已作为当时分支最终整理的一部分提交，后续应以 `git log` 和本文件历史确定精确提交。该阶段的 Worker `canJoin` 改动当时尚未确认部署；当前生产 Worker 状态见 §1 与 §6.3，不得用这句历史记录覆盖当前结论。

用户拥有的未跟踪文件 `docs/handoff-account-features.md` 不得修改、删除、stage 或提交。

## 10. 首次 Play 真机验收记录

设备：Android 16 真机（ADB serial 不写入仓库文档）

安装来源：Google Play

版本：`0.3.0 (1)`

| 场景 | 状态 | 证据/说明 |
|---|---|---|
| 冷启动与首页 | PASS | 页面正常，无 Flutter/AndroidRuntime 崩溃 |
| 前后台切换与恢复 | PASS | 锁屏、回到前台后页面可继续使用 |
| Google 登录 | PASS | Play App Signing 对应 OAuth Client 生效 |
| 日榜/周榜/刷新 | PASS | 无错误、卡死或溢出 |
| 非会员加入广场 | PASS | 正确提示需要会员，不再显示通用加载失败 |
| 个人页登录态 | PASS | 用户信息、会员状态、广场状态和操作按钮正常显示 |
| 编辑资料基础交互 | PASS | 头像选择、点弹窗外关闭、未保存不改变资料均正常 |
| 中英文切换 | PASS | 首页、个人页、记录页和训练页均无溢出；验收后已恢复跟随系统中文 |
| 浅色/深色切换 | PASS | 首页、个人页和记录页均可用；验收后已恢复浅色 |
| 记录页基础渲染 | PASS | 月历、云端状态和统计内容可显示 |
| 记录页底部安全区 | CANDIDATE | `0.3.2 (3)` 已使用系统安全区并补 Widget 回归测试，待真机手势/三键导航确认 |
| 记录页周/月/年切换 | CANDIDATE | `0.3.2 (3)` 已实现当前周/月/年真实范围、日历和汇总切换，待真机确认 |
| 相机预览 | PASS | 真机画面正常 |
| MoveNet 初始化 | PASS | 页面绘制姿态关键点；未把本次画面当识别准确率验收 |
| 训练结束与系统返回 | PASS | 结束训练可回首页；系统返回后相机客户端断开，无资源泄漏或崩溃 |
| 训练页计数圆环 | CANDIDATE | `0.3.2 (3)` 已使用 1:1 约束并补短视口 Widget 回归测试，待真机确认 |
| 编辑资料昵称标签 | CANDIDATE | `0.3.2 (3)` 已显式设置高对比度文本与浮动标签样式，待浅/深色真机确认 |
| 云端训练记录完整链路 | CANDIDATE | 生产 Worker 部署和鉴权探针已核实；仍需用 Play 安装版测试账号验证上传、拉取与合并全链路 |
| Google Play 订阅购买 | PASS（Debug 购买 + Play 恢复） | 侧载 Debug `0.3.5 (6)` 的月度购买/续订/过期、年度购买、RevenueCat Sandbox entitlement、App 重启恢复及 Webhook→D1 均通过；Play 安装版已验证 Google 登录和已有年度会员恢复 |

## 11. 当前待办清单

| 优先级 | 待办 | 当前原因 | 完成标准 |
|---|---|---|---|
| P0 | 重新核对 Google Play UGC、Data safety 与内容分级声明 | 历史 `0.3.6 (7)` 交接未记录这些声明是否完成；Console 接受本次 Alpha 送审不等于三项声明已逐项核验 | Console 声明与实际头像上传、举报、屏蔽、人工审核和账号删除能力一致，并写入台账；Production 前必须完成 |
| P0 | 轮换历史疑似暴露的 legacy Cloudflare Token | legacy 环境变量 Token 仍只有有限读取能力；已有受保护的专用部署 Token 可用，但不能代替旧 Token 撤销 | 撤销旧 Token，保留最小权限专用 Token；私密台账只记录标签、用途和核验日期 |
| P1 | 跟进 `0.3.10-closed-1` Alpha | 用户报告同一 `0.3.10 (13)` AAB 已提交审核，尚未记为发布 | 审核通过后确认面向 Alpha 测试人员发布，并抽查版本、登录、排行榜和会员刷新 |
| P1 | 复验 App 内更新入口 | `0.3.10-internal-1` 已发布；版本入口修复尚未记录 Play 安装版验收 | 从 Play 安装 `0.3.10 (13)`，确认直接打开正确商品页、覆盖更新成功且数据保留 |
| P2 | 修复零次训练持续进入云同步失败队列 | 历史 production Debug 证据显示零次记录被 Worker 以 `invalid_metric` 拒绝，客户端仍可能保留为失败/待同步 | 客户端不将零次 session 排入云同步，增加 controller/store 回归测试，服务端校验保持不放宽 |

任何远端部署、密钥轮换、商品创建和购买测试都需要用户明确授权；购买测试只能使用 License Tester 的测试支付方式，不得真实扣款。

## 12. 新 agent 接手顺序

1. 读 `AGENTS.md`、`docs/development-guide.md`、本文和私密台账。
2. 执行 `git status --short --branch`，保护用户未跟踪文件。
3. 不输出任何配置值，只确认所需字段存在。
4. 在 GCP IAM 确认 RevenueCat 服务账号仍为 `Monitoring Viewer + Pub/Sub Admin`。
5. 确认 RevenueCat 的 Google developer notifications 仍显示最近接收时间；除非迁移 Topic，否则不要断开现有连接。
6. 核对 Play Console 账号级 License Testing 仍包含测试名单。
7. 核对 `premium` 的 `monthly`、`annual` base plan 仍处于启用状态。
8. 核对 RevenueCat `default` Offering 仍包含 `$rc_monthly` 与 `$rc_annual`。
9. 确认 Sandbox Testing Access 允许当前 App User ID。
10. 购买弹窗必须显示测试卡后，才能执行一次 sandbox 购买；不得使用真实支付。
11. 检查 RevenueCat Customer、entitlement、RTDN、Webhook、Worker `/membership` 和 D1 快照是否一致。
12. 按本文“当前待办清单”逐项完成并更新状态；修复设备缺陷后再构建更高 `versionCode` 的 AAB。

## 13. 官方参考

- [Google Play：创建应用](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- [Google Play：内部测试](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)
- [Google Play：Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-EN)
- [Google Play Billing：License Tester 与测试支付](https://developer.android.com/google/play/billing/test?hl=en)
- [Google Play：订阅与 Base Plan](https://support.google.com/googleplay/android-developer/answer/140504?hl=en)
- [Google Auth Platform：管理 OAuth Clients](https://support.google.com/cloud/answer/15549257?hl=en)
- [Google Auth Platform：管理受众](https://support.google.com/cloud/answer/15549945?hl=en)
- [RevenueCat：Google Play 服务凭据](https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials)
- [RevenueCat：Google RTDN](https://www.revenuecat.com/docs/platform-resources/server-notifications/google-server-notifications)
- [RevenueCat：Product 配置](https://www.revenuecat.com/docs/offerings/products-overview)
- [RevenueCat：Entitlements](https://www.revenuecat.com/docs/getting-started/entitlements)
- [RevenueCat：Offerings](https://www.revenuecat.com/docs/offerings/overview)
- [RevenueCat：Sandbox Testing Access](https://www.revenuecat.com/docs/projects/sandbox-access)

## 14. 历史快照：2026-07-11 商店资料与封闭测试进展

> 本节只保留首次商店资料准备时的证据，不代表当前版本、测试人数或待办。当前状态只看 §1、§6.3 和 §11。

### 14.1 已完成

- Cloudflare Pages 隐私政策：`https://pushupai-privacy.pages.dev/`。
- 账号删除直达页：`https://pushupai-privacy.pages.dev/#account-deletion`；处理时限为 30 天。
- 用户头像内容规则：`https://pushupai-privacy.pages.dev/#avatar-policy`；版本 `2026-07-14`，已于 2026-07-14 部署并回验正文与安全响应头。
- 自定义头像生产后端与上传、替换、删除、举报、屏蔽链路已通过带 production 配置的 Debug 验收；该结论不替代 Google Play 安装包验收。
- Cloudflare Pages 产品官网：`https://pushupai.pages.dev/`；Git 集成 `main`，静态输出目录 `website`，首次生产部署提交 `1b5a490` 已于 2026-07-13 验证成功；`0.3.4` 官网更新已于 2026-07-14 从 `main` 合并提交 `5b77bd8` 手动生产部署并回验成功。
- App 个人信息页已在本分支加入账号与数据删除入口。
- Play 基础应用内容声明曾完成隐私政策、数据安全、广告、登录详细信息、目标受众、内容分级、广告 ID、政府应用、金融产品和服务、健康类应用；加入自定义头像 UGC 后，UGC、Data safety 与内容分级的增量更新尚未记录完成，旧记录不得作为当前发布放行依据。
- 目标受众仅选 18 周岁及以上，并启用限制未成年人访问。
- 健康类应用仅声明“健康与健身 → 活动和健身”；商店说明已加入非医疗设备声明。
- 默认简体中文商品详情、应用图标、置顶大图和 4 张手机截图已保存。
- 商店类别为“健康与健身”；标签为健康与健身、运动指导、运动跟踪器、锻炼。
- RevenueCat 中的 Play 审核账号已免费授予 `premium` 无限期权益；不涉及购买或试用。
- `0.3.1 (2)` 已发布至内部测试和 Alpha 封闭测试；广泛媒体权限提醒已消失。
- Alpha 已配置开发者互助 Google Group；群成员必须实际选择参与才计入 12 人。
- 2026-07-11 Play Console 信息中心显示 3 名测试者已选择参与；尚未达到 12 人，14 天资格条件未满足，正式版权限按钮仍禁用。
- `0.3.2 (3)` 签名 Alpha AAB 已构建、验证、上传并提交审核；尚未确认获批。

### 14.2 未完成/风险

- 2026-07-11 快照仅记录 3 名测试者选择参与；当前人数未在本节核对。正式版权限仍应以 Play Console 当日显示的参与人数和连续测试天数为准。
- 正式订阅、base plan、License Testing 名单和 RevenueCat Product → `premium` → Package → Offering 映射已完成；侧载 Debug 的月度/年度 Sandbox 购买与 Webhook→D1、Play 安装版 `0.3.5 (6)` 的 Google 登录与会员恢复均已于 2026-07-15 验证通过。
- Google OAuth 受众状态仍需在正式发布前核对；若仍为测试状态，普通用户无法登录。
- `0.3.2 (3)` 候选版已在 App 内明确标识“隐私政策与账号删除”，并在启动相机前显示端侧处理说明；待真机回归。
- `0.3.2 (3)` 候选版已在客户端将排行榜自由昵称统一匿名显示，不改 Worker/D1；待真机回归。
- 圆环、记录页安全区、周/月/年真实切换和昵称标签对比度已在 `0.3.2 (3)` 修复并通过自动化测试，仍需真机验收。
- Cloudflare Token 疑似暴露的历史风险仍需由用户在 Dashboard 中轮换；未授权修改 Worker/D1。

### 14.3 非 Git 素材和测试记录

- 商店素材：`E:\AII\需求\PushupAI-商店素材-2026-07-11`。
- 封闭测试说明：`E:\AII\需求\PushupAI-商店素材-2026-07-11\封闭测试-测试说明与反馈记录.md`。
- 这些文件不加入 App 仓库。
