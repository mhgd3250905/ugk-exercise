# 账号与会员系统分支汇报

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
  - 自定义 UGK Premium 底部弹窗，不使用 RevenueCat 默认 paywall。
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
  - Authorization header 校验。
  - `provider + event_id` 幂等入库。
  - 重复 webhook 直接短路。
  - 使用 RevenueCat `event_timestamp_ms` 防止旧事件覆盖新状态。
  - `/membership` 返回时按 `expires_at` 现算是否 active。

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
- SDK 返回 active 时不会被旧 `expiresAt` 抵消。
- 退出登录时 RevenueCat logout 失败不会阻止本地 session 清理。
- 退出登录会调用 Google signOut。
- 过期 session 启动恢复时会清理本地 session，不会每次启动反复报错。
- 已是会员时隐藏“开通会员”按钮。
- Worker 不再让重复 webhook 事件重复处理会员快照。
- Worker 不再让旧 webhook 事件覆盖更新的会员快照。
- Worker 查询会员时会按 `expires_at` 判断当前是否仍有效。

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

当前还没有真正完成免费版/会员版功能分流。`premium` 状态目前只用于个人页展示和后续功能接入准备；训练页、记录页、测试模式仍按原逻辑开放。

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
2. 购买/恢复后增加服务端同步接口，例如 `/membership/sync`，由 Worker 查询 RevenueCat 当前 customer 状态后落库。
3. Worker 增加更多测试：
   - webhook HMAC 失败。
   - sandbox/production 策略。
   - refund/cancellation/expiration。
   - RevenueCat 当前状态同步。

### 体验优化

1. 恢复购买无权益时给明确提示。
2. 会员过期时在 App resume 或进入个人页时刷新状态。
3. 会员已开通时后续可增加“管理订阅”入口。

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
