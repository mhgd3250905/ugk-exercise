# 会员订阅系统设计

日期：2026-07-09

## 结论

第一版采用 **RevenueCat + Google Play Billing + Cloudflare Worker/D1**。

原因：

- App 是 Android Flutter 应用，App 内售卖数字会员优先走 Google Play Billing，合规风险最低。
- RevenueCat 负责订阅校验、恢复购买、权益状态、Google Play 通知同步，避免前期自研订阅账本。
- Cloudflare 已是 Workers Paid，可作为账号、业务 API、会员状态快照后端。
- Stripe/Paddle 暂不接入第一版；等需要官网购买或 Web 漏斗时再接。

## 目标

第一版只做稳定可上线的会员基础能力：

- Google 账号登录。
- Google Play 内订阅购买。
- RevenueCat 管理 `premium` 权益。
- Cloudflare D1 保存用户和会员状态快照。
- App 可展示登录状态、会员状态、到期时间。
- App 可按 `premium` 权益解锁会员功能。

## 非目标

第一版不做：

- Stripe、Paddle、Lemon Squeezy。
- 多平台 iOS。
- 团队会员、邀请码、优惠券、复杂套餐。
- 自研 Google Play RTDN 和 purchase token 全量校验链路。
- 云端训练视频上传。当前 README 已明确视频帧不上传，这个约束不变。

## 系统边界

### Flutter App

负责：

- 调 Google Sign-In 获取 Google ID token。
- 调 Cloudflare `/auth/google` 换取 app session 和 `app_user_id`。
- 用 `app_user_id` 登录 RevenueCat。
- 通过 RevenueCat SDK 发起购买、恢复购买、读取 `premium` 权益。
- UI 展示会员状态，会员功能前做本地权益门控。

不负责：

- 直接相信客户端购买结果作为最终真源。
- 保存支付密钥。
- 直接调用 Google Play Developer API。

### Cloudflare Worker

负责：

- 校验 Google ID token。
- 管理 app session。
- 保存用户、登录身份、会员状态快照。
- 接收 RevenueCat webhook，更新 D1。
- 对需要服务端授权的能力提供 `/me` 和 `/membership`。

不负责：

- 第一版不直接校验 Google Play purchase token。
- 第一版不直接处理 Google Play RTDN。

### RevenueCat

负责：

- 绑定 Google Play 订阅产品。
- 管理 entitlement：`premium`。
- 处理购买、恢复购买、订阅续费/取消/过期状态。
- 通过 webhook 通知 Cloudflare。

### Google Play Console

负责：

- 创建订阅产品和 base plan。
- 测试账号、测试轨道、许可证测试。
- Google Play Billing 收款与订阅生命周期。

## 数据模型

D1 保存业务所需最小状态。

### users

- `id`：内部用户 ID，建议 UUID。
- `display_name`
- `email`
- `avatar_url`
- `created_at`
- `updated_at`

### auth_identities

- `id`
- `user_id`
- `provider`：第一版固定 `google`。
- `provider_subject`：Google ID token 的 `sub`，不是 email。
- `email`
- `email_verified`
- `created_at`
- 唯一约束：`provider + provider_subject`。

### membership_snapshots

- `user_id`
- `entitlement`：第一版固定 `premium`。
- `is_active`
- `expires_at`
- `source`：第一版固定 `revenuecat_google_play`。
- `revenuecat_app_user_id`
- `last_event_at`
- `updated_at`

### webhook_events

- `id`
- `provider`：`revenuecat`。
- `event_id`
- `event_type`
- `received_at`
- `processed_at`
- `payload_json`
- 唯一约束：`provider + event_id`，用于幂等。

## API 草案

### POST /auth/google

请求：

- `idToken`

处理：

1. 校验 Google ID token 的签名、`aud`、`iss`、`exp`。
2. 用 `sub` 查找或创建 `auth_identities`。
3. 查找或创建 `users`。
4. 返回 app session 和 `app_user_id`。

响应：

- `sessionToken`
- `appUserId`
- `user`

### GET /me

请求：

- `Authorization: Bearer <sessionToken>`

响应：

- 用户资料。
- `membership` 快照。

### GET /membership

请求：

- `Authorization: Bearer <sessionToken>`

响应：

- `entitlement`
- `isActive`
- `expiresAt`
- `source`

### POST /webhooks/revenuecat

处理：

1. 校验 RevenueCat webhook 授权。
2. 按 `event_id` 幂等入库。
3. 从事件中读取 `app_user_id`、entitlement、过期时间。
4. 更新 `membership_snapshots`。

## App 分层落点

按项目 `docs/development-guide.md`：

- 登录和会员状态编排放 `control/`，用 `ChangeNotifier`。
- 纯展示放 `ui/pages/` 或 `ui/widgets/`。
- 本地 session 持久化属于 page/control 边界，需要保持薄封装。
- 不改 `pushup_domain.dart`。
- 不碰计数管线，不平均手腕坐标。

建议新增：

- `lib/control/account_controller.dart`
- `lib/product/account_session_store.dart`
- `lib/product/membership_status.dart`
- `lib/platform/membership_api_client.dart`
- `lib/platform/revenuecat_service.dart`
- `lib/ui/pages/profile_page.dart` 扩展登录和会员展示。

具体文件可在实施计划阶段再收敛，先按最小 diff 落地。

## 流程

### 登录

1. 用户点 Google 登录。
2. App 拿 Google ID token。
3. App 调 Worker `/auth/google`。
4. Worker 返回 `app_user_id`。
5. App 用 `app_user_id` 配置 RevenueCat。
6. App 拉取 RevenueCat entitlement 和 Worker `/me`。

### 购买

1. 用户在 App 内点击开通会员。
2. App 调 RevenueCat SDK 展示 Google Play 购买。
3. 购买成功后 RevenueCat 更新 `premium`。
4. App 立即刷新 entitlement。
5. RevenueCat webhook 通知 Worker。
6. Worker 更新 D1 会员快照。

### 恢复购买

1. 用户点击恢复购买。
2. App 调 RevenueCat restore。
3. RevenueCat 返回当前 entitlement。
4. App 刷新本地状态。
5. 后端快照由 webhook 或下一次同步补齐。

### 过期/取消

1. Google Play 状态变化。
2. RevenueCat 接收并更新订阅状态。
3. RevenueCat webhook 通知 Worker。
4. Worker 更新 `membership_snapshots.is_active` 和 `expires_at`。
5. App 下次启动或刷新时同步状态。

## 错误处理

- Google 登录失败：保留游客态，本机训练仍可用。
- Worker 不可用：App 可继续用本地训练；会员态以 RevenueCat 本地刷新结果为准。
- RevenueCat 不可用：隐藏购买入口或显示“暂时无法连接订阅服务”。
- Webhook 重复：用 `provider + event_id` 幂等处理。
- 会员状态冲突：客户端即时体验以 RevenueCat 为准，后端受保护能力以 D1 快照为准。

## 测试

### Worker

- `/auth/google`：无效 token 拒绝。
- 用户首次登录创建用户。
- 同一个 Google `sub` 重复登录返回同一用户。
- RevenueCat webhook 幂等。
- webhook 更新会员快照。

### Flutter

- 未登录状态 Profile 展示。
- 登录成功后显示用户信息。
- `premium` active 时展示会员状态。
- 非会员时会员功能被门控。

### 真机/商店测试

- Google Play license tester 购买测试订阅。
- 购买后立即解锁。
- 恢复购买可恢复。
- 取消订阅或测试过期后状态变更。

收尾必须跑：

- `flutter analyze`
- `flutter test`

## 配置清单

需要用户配合提供或完成：

- Google OAuth Client ID。
- Google Play package name。
- Google Play 订阅产品 ID。
- RevenueCat 项目和 public SDK key。
- RevenueCat webhook secret。
- Cloudflare Worker 自定义域名或 workers.dev 地址。

密钥只放 Cloudflare secrets，不写入仓库。

## 推进顺序

1. 建 RevenueCat 项目和 Google Play 订阅商品。
2. 搭 Cloudflare Worker + D1 schema。
3. 做 `/auth/google` 和 session。
4. Flutter 接登录，Profile 显示账号。
5. Flutter 接 RevenueCat，完成购买/恢复/权益读取。
6. Worker 接 RevenueCat webhook，同步会员快照。
7. 加会员门控 UI。
8. 全量验证和真机测试。

## 后续扩展

当需要官网购买时，再加 RevenueCat Web + Paddle 或 Stripe：

- Paddle 优先：税务合规更省事。
- Stripe 次选：费率低、控制强，但税务和合规责任更重。

第一版不为这个扩展预留复杂抽象，只保证 `source` 字段能标记来源。
