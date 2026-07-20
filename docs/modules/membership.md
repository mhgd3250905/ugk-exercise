# 账号与会员系统

最后更新：2026-07-20

## 当前权威合同（2026-07-16）

会员链路必须区分四个角色：

1. Google Play 是交易来源。
2. RevenueCat `GET /v1/subscribers/{app_user_id}` 返回的当前 `premium` entitlement 是权益事实。
3. Cloudflare Worker 是 App 和云端功能的唯一授权权威。
4. D1 `membership_snapshots` 是带 `verified_at` 的可重建缓存，不是独立事实源。

### Worker 对账与授权

- `getAuthoritativeMembership` 是账户、排行榜加入/身份更新、训练同步共同使用的会员入口。五分钟内的已核验快照可直接复用；缺失、未核验或过期缓存会向 RevenueCat 查询当前 subscriber 后重建 D1。
- `POST /membership/reconcile` 供购买或恢复购买后强制核验，不复用缓存。RevenueCat 不可用时返回 `503 membership_sync_unavailable`，不修改现有快照，也不把同步故障误报成非会员。
- D1 migration `0005_membership_verified_at.sql` 为 `membership_snapshots` 增加 `verified_at`。历史行迁移后为 `NULL`，首次权威读取必须重新核验。
- RevenueCat Webhook 只是加速通知。事件中的 `entitlement_ids`、`expiration_at_ms` 和事件顺序不再决定最终会员状态；签名通过且关联用户存在后，Worker 查询 RevenueCat 当前 subscriber，再在成功后记录事件已处理。查询失败返回可重试状态，不能提前吞掉事件。
- 对账写入按 `verified_at` 做并发保护，较旧观察不能覆盖较新观察；`last_event_at` 只保留审计意义。
- Worker 需要额外 Secret `REVENUECAT_SECRET_API_KEY`。只声明变量名，值必须通过 Cloudflare Secret 管理，禁止写入仓库、日志或聊天。

### Flutter 授权语义

- RevenueCat SDK 只负责配置身份、读取 Offering、购买和恢复购买；它返回的本地 CustomerInfo 不直接授予 VIP 或云端权限。
- `AccountController` 只用 Worker 返回的 `MembershipStatus` 更新会员状态。购买或恢复购买完成后调用 `/membership/reconcile`，SDK 返回 active 也不能覆盖服务端失效状态。
- `AccountController` 是 App 内账号资料和会员状态的唯一内存源；首页、个人页、运动记录和运动广场必须使用同一实例，不复制页面级会员状态。App 回到前台或进入个人页时通过 `/me` 刷新；本地会员有效期到达时先进入核验态并自动请求 `/me`，只有 Worker 确认失效后才展示非会员，续订后的新有效期则直接替换旧快照。
- 运动广场快照保留排行、加入状态和冻结成绩等业务数据，但加入/付费操作与会员视觉必须以 `AccountController` 的当前会员状态为准；服务端仍对实际写操作做最终授权。
- 运动记录只在 `AccountController.premium` 为真时加载云端历史和显示待同步状态；非会员始终保留本地记录能力。
- `membership_sync_unavailable` 使用独立中英文提示；同步失败时不显示 VIP，也不显示“需要会员”的误导提示。
- 本地缓存的账号资料可用于冷启动快速展示，但本地缓存会员状态不授予权限。

### Google Play 双套餐试用客户端合同（2026-07-20，双 Offer 已启用 / 年卡运行验收待完成）

- Flutter 支持两种精确试用条款：`premium:monthly` 只认完整的 3 天免费阶段，`premium:annual` 只认完整的 7 天免费阶段。试用开始即签约并获得完整 Premium，期满后进入所选月卡或年卡，除非用户在试用结束前取消。
- 资格规则由 Google Play 负责，Offer 必须选择“从未拥有本 App 的任何订阅（Never had any subscription in this app）”：仅从未订阅过任何 PushupAI 套餐的 Play 账号可用一次。App 和 Worker 不保存、推断或重置试用资格；历史月卡、年卡或试用用户均应由 Play 返回无资格的普通 base plan。
- Flutter 只从 RevenueCat 当前 Offering 中对应 Package 的 `defaultOption.freePhase` 和完整 `fullPricePhase` 渲染试用。月卡非 3 天、年卡非 7 天、非天单位、阶段缺失或本地化转正价为空时全部失败关闭为普通套餐，绝不修正或猜测优惠。
- 默认选择顺序为“月卡 3 天试用 → 年卡 7 天试用 → 普通年卡 → 第一项可用套餐”。当两档试用同时可用时，月卡卡片、主 CTA 和月度转正披露首先吸引新用户；年卡卡片仍清晰显示 7 天，切换后 CTA、价格、年度续费周期和取消披露同步更新。
- 购买仍按用户当前选择的 RevenueCat Package 发起。RevenueCat/Google Play 负责选择该账号可用的优惠；即使资格在展示后发生变化，最终结算页和交易结果仍以 Google Play 为准，客户端不得承诺免费资格。
- 所有已登录用户的设置页提供 Google Play 订阅管理入口，用于查看、取消或重新订阅。取消不会立刻撤销已付费或仍有效的试用权益；Worker 继续以 RevenueCat 当前 `premium` entitlement 的有效期裁决权限。
- 本功能不新增 Worker 路由、D1 字段或会员状态枚举。试用、已付费月卡和年卡在授权层都是有效 `premium`，原有购买后 `/membership/reconcile`、RTDN、Webhook 和到期收敛链路保持不变。
- Google Play Offer `monthly-3d-trial` 已于 2026-07-19 在 `premium:monthly` 下启用并完成一次全新 License Tester 的试用开始与 Sandbox 自动转月卡；取消、到期和历史订阅账号无资格仍待独立场景，因此只能表述为“月卡试用核心链路通过 / 完整矩阵未完成”。Offer `annual-7d-trial` 已于 2026-07-20 在 `premium:annual` 下创建并启用，资格同为“新客户获取 → 从未拥有本 App 的任何订阅”，免费阶段 7 天，覆盖 174/174 个国家或地区；RevenueCat `default` Offering 已只读核验为默认 Offering，`$rc_annual` 仍唯一映射 Google Play `premium:annual`，无需新增 Product、Package、Entitlement 或 Offering。年卡尚未发起结算或 Sandbox 购买，也没有 Webhook/Worker/D1 运行证据，只能表述为“年卡 Offer 已配置 / 运行矩阵未验证”。

### 运动类型与云同步合同（2026-07-18，本地实现）

- Flutter 与 Worker 源码当前识别 `pushup`、`narrow_pushup` 两个 `exerciseType`；`metricUnit` 仍只能是 `reps`，D1 继续使用现有 `exercise_type` 列，不需要 migration。
- 本地训练和记录对两种类型都可用；记录页按日期聚合两种类型，首页训练卡按类型分别统计。
- 云端训练明细保留各自 `exerciseType`，同一用户、日期和类型分别聚合。运动广场不拆分类榜单，新 App 请求版本化指标 `pushup_points_v1`：标准俯卧撑每次 1 分，窄距俯卧撑每次 2 分，响应单位为 `points`。
- Worker 在读取日榜或周榜时从现有分类型聚合行计算积分，因此已同步历史记录自动按 V1 规则回算，不新增积分表、不回写训练记录，也不需要 D1 migration。积分版本不可原地改权重；未来如需调整必须新增指标版本。
- `pushup_points_v1` 响应只在根级为当前登录用户返回 `myExerciseCounts`，字段为 `pushup` 与 `narrow_pushup` 的所选日/周原始次数；其他用户的 `top` 行不得携带分类明细。Flutter 将该对象视为可选字段，旧 Worker 或回滚期间缺失时只隐藏本人卡片明细，不让排行榜加载失败。
- 过渡期内 Worker 继续接受旧 App 的 `exerciseType=pushup` 请求并返回原次数合同；新 App 只接受带 `metric=pushup_points_v1`、`metricUnit=points` 的响应，避免旧 Worker 把次数误显示成积分。积分游标包含指标身份，不能跨次数榜和积分榜复用。
- 2026-07-18 已按两次单独授权依次部署窄距积分兼容 Worker与本人分类次数 Worker；两次均使用 `--keep-vars`，未改远端 D1、Secret、变量或 binding。积分日/周榜、旧 App 次数查询和训练同步的未登录生产探针均返回预期 `401`。带 production 配置的 Debug App 已安装；下一步由用户刷新运动广场，验证 `N + 2M` 积分及“标准 N 次 · 窄距 M 次”明细，再决定 App 发布。

### 上线状态与顺序

2026-07-16，服务端已按单独授权完成生产上线：

1. D1 已在受保护位置完成迁移前备份，并应用 migration `0005`；远端确认 `verified_at` 存在且无待迁移项。
2. Worker Secret `REVENUECAT_SECRET_API_KEY` 已通过 Cloudflare Secret 配置，值未进入仓库、日志或台账。
3. `main@56a4f31` 的会员权威 Worker 已部署；后续过期会员冻结成绩 Worker 也已在 App 发布前使用 `--keep-vars` 部署，未执行 D1 migration、未修改变量或 Secret；未登录生产探针返回预期 `401`。
4. Play 内测版 `0.3.7` 先将已过期 Sandbox entitlement 权威收敛为 inactive；重新 Sandbox 购买后，真实业务请求又将同一快照自动更新为 `revenuecat_verified + active`，全程未手工修改会员行。
5. 包含 Flutter 购买/恢复强制对账语义的 `0.3.8 (9)` 已发布到内部测试；包含冻结成绩和关闭动画引导修复的 `0.3.8 (10)` 也已发布并由用户从 Play 更新，过期账号公开排名与本人冻结卡核心链路已通过。续费返回后立即刷新和最新启动视觉进入 `0.3.8 (11)`；其 AAB 已通过本地自动化、签名与清单核验，并已面向 Internal 和 Alpha 测试人员发布，仍待 Play 安装版回归。

以下 2026-07-09 内容仅保留作首次实现审计；其中“待办”和测试数量均不是当前状态。当前合同以上文及后续专题合同为准，当前发布待办只看 [发布配置台账](../release-configuration.md#11-当前待办清单)。

## 历史实现记录（2026-07-09）

日期：2026-07-09  
分支：`feat/ui-design`  
审核对象：main 分支合入前审查

## 目标

本分支为 UGK Android Flutter App 建立第一版账号与会员基础能力：

- Google 账号登录。
- RevenueCat + Google Play Billing 会员购买与恢复购买。
- Cloudflare Worker + D1 保存用户、session、会员快照。
- App 个人页展示登录态、会员态、购买入口和恢复购买入口。
- 为后续免费版/会员版功能区分打基础。

本分支没有改 `pushup_domain.dart`，没有改俯卧撑识别算法、腕部锚点、计数管线或真实视频/CSV 夹具。

## 已完成

### Flutter App

- 新增 `lib/product/membership_status.dart`
  - `AppUser`
  - `MembershipStatus`
  - `AccountSnapshot`
- 新增账号编排器 `lib/control/account_controller.dart`
  - 登录、恢复 session、退出登录。
  - 购买、恢复购买。
  - RevenueCat 状态和 Worker `/me` 状态同步。
  - 处理取消购买、购买失败、过期 session。
- 新增平台封装：
  - `lib/platform/membership_api_client.dart`
  - `lib/platform/account_session_store.dart`
  - `lib/platform/google_auth_service.dart`
  - `lib/platform/revenuecat_service.dart`
- 新增个人页 `lib/ui/pages/profile_page.dart`
  - 未登录：显示 Google 登录。
  - 已登录非会员：显示开通会员、恢复购买、退出登录。
  - 已登录会员：显示会员已开通，隐藏重复开通按钮，保留恢复购买。
  - 自定义 PushupAI 会员底部弹窗，不使用 RevenueCat 默认 paywall。
- `lib/main.dart` 负责创建 `AccountController` 并初始化平台服务。
- `lib/ui/pages/home_page.dart` 通过头像入口进入个人页。
- Android manifest 增加：
  - `android.permission.INTERNET`
  - `com.android.vending.BILLING`

### Cloudflare Worker

- 新增 `workers/membership-api`：
  - `POST /auth/google`
  - `GET /me`
  - `GET /membership`
  - `POST /webhooks/revenuecat`
- D1 schema：
  - `users`
  - `auth_identities`
  - `sessions`
  - `membership_snapshots`
  - `webhook_events`
- Google ID token 服务端校验：
  - issuer
  - audience
  - signature
  - expiry
- session token 使用 HMAC hash 入库。
- RevenueCat webhook：
  - HMAC 签名校验。
  - `provider + event_id` 幂等入库。
  - Webhook 触发 RevenueCat 当前 subscriber 对账，不直接信任事件权益字段。
  - `/membership` 与会员受限路由共享权威对账入口。

### RevenueCat / Google / Cloudflare 配置

- Worker 已部署到 workers.dev。
- D1 `ugk-membership` 已创建并应用 schema。
- Google OAuth 已完成 Android/后端登录配置。
- RevenueCat 已配置：
  - Test Store App。
  - `premium` entitlement。
  - `monthly` Test Store subscription。
  - `default` offering。
  - webhook 到 Worker。
- Flutter 不保存会员配置默认值。Debug/release 均通过 `--dart-define` 或 `--dart-define-from-file` 注入；release 缺值或使用 RevenueCat Test Store key 会 fail-fast。测试与发布分层见 [../testing-release-playbook.md](../testing-release-playbook.md)。

注意：Cloudflare API token 曾在聊天中暴露，必须在正式交付前撤销并重新创建最小权限 token。

## 已修复的问题

- RevenueCat 取消购买不再显示错误。
- RevenueCat 失败购买不再把 `PlatformException(...)` 原文显示给用户。
- `Test failed purchase` 显示短提示：`购买没有完成，请稍后再试。`
- 购买成功后 App 会刷新后端会员状态，不再停留在旧状态。
- SDK 返回 active 时不能覆盖 Worker 返回的过期或失效状态。
- 退出登录时 RevenueCat logout 失败不会阻止本地 session 清理。
- 退出登录会调用 Google signOut。
- 过期 session 启动恢复时会清理本地 session，不会每次启动反复报错。
- 已是会员时隐藏“开通会员”按钮。
- Worker 不再让重复 webhook 事件重复处理会员快照。
- Worker 以 RevenueCat 当前 subscriber 状态收敛，Webhook 重复或乱序不会成为最终事实。
- Worker 查询会员时会核对 `verified_at` 与 `expires_at`，必要时自动重建快照。

## 验证记录

最近一次验证命令：

```bash
flutter analyze
flutter test
cd workers/membership-api
npm test
flutter build apk --debug
```

结果：

- `flutter analyze`：无 issue。
- `flutter test`：113 个测试通过。
- 回放基线仍为 Step0=5 / video3=5 / video4=3。
- `workers/membership-api npm test`：4 个 Worker 规则测试通过。
- debug APK 构建成功。
- 模拟器验证：
  - Google 登录成功。
  - `Test valid purchase` 后 D1 会员快照为 active。
  - 安装最新 debug 包后个人页显示“会员已开通”。
  - `Test failed purchase` 显示短错误提示。

## 当前边界

当前已经具备账号、购买、恢复购买、会员状态展示、后端会员快照能力。

当前 Premium 已用于运动广场加入/身份更新和云端训练同步；本地训练与本地记录仍可离线使用。

## 待办

### 合入前建议处理

1. 轮换曾暴露的 Cloudflare API token。
2. RevenueCat webhook 增加 HMAC 签名校验。
3. Release 构建下禁止默认使用 RevenueCat Test Store key。
4. 建立 D1 migrations 目录，避免生产库靠手工 schema 漂移。

### 会员功能设计待办

1. 定义免费版/会员版功能矩阵。
2. 新增统一权限入口，例如 `canUse(feature)` 或 `FeatureAccess`。
3. 所有付费功能入口必须走统一权限入口，不在页面里散落判断。
4. 需要服务端保护的能力必须以 Worker 会员状态为准，客户端状态只用于即时 UI。

### 订阅账本增强

1. webhook 按 environment/store/event type 做白名单过滤。
2. 已完成：购买/恢复后使用 `/membership/reconcile`，由 Worker 查询 RevenueCat 当前 subscriber 状态后落库。
3. Worker 增加更多测试：
   - webhook HMAC 失败。
   - sandbox/production 策略。
   - refund/cancellation/expiration。
   - RevenueCat 当前状态同步。

### 体验优化

1. 恢复购买无权益时给明确提示。
2. 会员过期时在 App resume 或进入个人页时刷新状态。
3. 已完成：所有已登录用户可从设置打开 Google Play 订阅管理。

## 审核重点

main 审核时建议重点看：

1. `control/account_controller.dart` 的异步状态流是否足够稳。
2. Worker webhook 的幂等、防乱序和会员快照计算是否符合第一版要求。
3. 默认测试配置是否允许合入主线，还是需要改为 release fail-fast。
4. 免费/会员功能矩阵是否需要在合入前先定稿。

## 相关文档

- `docs/superpowers/specs/2026-07-09-membership-subscription-design.md`
- `docs/superpowers/plans/2026-07-09-membership-subscription.md`
- `workers/membership-api/schema.sql`
- `docs/development-guide.md`

## 排行榜分页合同（2026-07-13）

- `GET /leaderboard` 首次固定返回 20 条，响应通过可空 `nextCursor` 表示是否还有下一页。
- 下一页只回传服务端生成的不透明 `cursor`；客户端不得解析或自行构造。
- App 进入排行榜时并行预载日榜和周榜，切换只读取本地缓存；用户下拉刷新时同时重载两份第一页。
- 接近当前列表底部时按各榜单自己的 cursor 追加下一页；失败保留已加载行并允许重试。
- 本合同不需要 D1 schema migration。旧 App 可忽略新增字段并继续显示第一页。

## 过期会员冻结成绩合同（2026-07-16 修订）

> 状态：修订 Worker 已于 2026-07-16 12:13:41（北京时间）部署；用户随后报告真机刷新后，过期账号已重新出现在公开榜单且本人冻结卡仍保留，核心线上链路验收通过。

- 用户一旦加入榜单，只有主动退出才从公开榜单移除；会员过期不删除其日榜/周榜聚合，也不隐藏其公开排名行。
- 过期用户继续用冻结成绩参与排序并占据名次；成绩不会增长，其他仍在训练的会员可以超过他。
- Worker 只在过期用户自己的鉴权响应中额外返回 `frozenTotalValue`，让 App 显示“我的成绩已冻结”卡片、续费和退出入口；其他用户只看到正常公开排名行。
- 训练同步继续使用权威会员门控，会员无效时不增加排行榜聚合；续费后恢复正常累计。
- 复用现有 `leaderboard_profiles` 和 `leaderboard_daily_totals`，不新增 D1 migration。现有 `0.3.8 (10)` App 已能同时渲染公开排名行与本人冻结卡，修订上线只需部署 Worker，不需要重建 AAB。

## 自定义头像与公开 UGC 合同（2026-07-14）

- 账号只维护一份个人资料；不再存在榜单专用昵称或榜单专用头像。自定义头像优先级最高，匿名榜单身份是唯一不使用个人资料的例外。
- `AccountController.user` 是 App 内唯一账号资料源；安全存储中的 `SavedAccountSession.user` 只作为冷启动展示缓存。首页、个人页和榜单资料预览监听同一 Controller，后台 `/me` 刷新后自动更新，不复制第二份页面状态。
- App 启动门只等待 `AccountController.localRestoreCompleted`，因此本地缓存资料已发布后即可进入首页；不得等待 `/me` 或 RevenueCat 网络核验。缓存仍不授予 Premium 权限，后台 401 会按原合同清除本地 session。
- App 通过系统相册/相机选择器取得图片并裁成不超过 `512 × 512` 的 JPEG；不申请广泛媒体或存储权限。
- 首次上传或规则更新后，必须接受版本 `2026-07-14` 的[用户头像内容规则](../policies/user-content-policy.md)。Worker 对规则版本、JPEG 格式、正方形尺寸、1 MiB 上限和上传暂停状态做最终校验。
- D1 是头像所有权、版本、规则接受、举报、屏蔽和审核状态的权威；私有 R2 binding `AVATAR_BUCKET` 只保存图片二进制。公开读取必须经过 `GET /avatars/{random-id}.jpg`，Worker 只返回仍有效且未隐藏的当前版本。
- 举报头像/用户会同时屏蔽目标；屏蔽只过滤当前用户的榜单结果，不重写全局排名。受 Cloudflare Access 保护的 `/admin/avatar-reports` 提供最小人工审核和审计操作。
- 登录用户可通过 `GET /me/blocks` 读取自己的屏蔽名单，并通过既有 `DELETE /me/blocks/{userId}` 解除屏蔽；名单只返回目标当前可公开的排行榜身份，已退出或匿名用户不得泄露账号资料。
- 加入榜单在身份选择面板中说明公开排名范围并由用户明确确认；退出在排行榜和个人页所有入口统一二次确认。退出后新训练不再进入排行榜，重新加入会按既有 Worker 合同清除本周退出前聚合，不能在提示中承诺恢复旧榜单统计。
- 替换、用户删除、审核下架和账号删除都先撤销 D1 公开引用，再删除 R2 对象；对象删除暂时失败不得导致旧头像继续公开。

运行时路由、数据结构和上线顺序以[用户头像内容规则](../policies/user-content-policy.md)、[测试与发布手册](../testing-release-playbook.md)和[发布配置台账](../release-configuration.md)为准。
