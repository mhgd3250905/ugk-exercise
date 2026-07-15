# 会员单一权威与自动对账修复报告

日期：2026-07-16

分支：`codex/membership-authoritative-reconciliation`

基线：`b52f814`

## 结论

本次问题不是单一测试账号或单条 D1 数据异常，而是会员状态存在两个授权来源：个人页允许 RevenueCat Flutter SDK 的本地 active 覆盖 Worker inactive，运动广场和训练同步则只读取 D1。Webhook 延迟、丢失或沙盒快速过期后，两边会长期显示不同结论。

修复后只有 Worker 能授予会员权限。RevenueCat 当前 subscriber 是权益事实，D1 是带验证时间的可重建缓存，Flutter SDK 只负责购买和恢复购买。

## 现场证据（脱敏）

- Google Play 安装版个人页显示 VIP 和“会员已开通”。
- 同一会话进入运动广场时提示需要 Premium，刷新后仍不一致。
- Google Play 订阅页显示测试订阅当前有效。
- 只读 D1 查询显示该账号会员快照已经过期，最新相关 Webhook 是过期事件，之后没有新的相关事件。
- 因此交易来源与 App SDK 为 active，而 Worker/D1 为 inactive；这证明是架构性分裂，不是单纯 UI 缓存。

报告不记录账号邮箱、设备序列号、token、Secret 或任何密钥值。

## 根因

1. `AccountController._applySnapshot` 先应用 Worker 快照，又用 `RevenueCatService.refreshPremium()` 覆盖 inactive。
2. 购买或恢复购买在 SDK 返回 active 时直接创建本地 active `MembershipStatus`，不要求 Worker确认。
3. 排行榜和训练同步分别直接查询 D1，会员判断存在重复实现。
4. Worker Webhook 直接用事件 `entitlement_ids` 和 `expiration_at_ms` 计算最终状态；Webhook 成为唯一同步通道。
5. D1 快照没有“最近一次向 RevenueCat 核验”的时间，无法区分事实与陈旧缓存。

## 实现

### Worker / D1

- migration `0005_membership_verified_at.sql` 增加 `membership_snapshots.verified_at`。
- 新增共享 `getAuthoritativeMembership` / `reconcileMembership`：五分钟内复用已核验缓存，否则查询 RevenueCat `GET /v1/subscribers/{app_user_id}`。
- 对账写入使用 `verified_at` 防止旧观察覆盖新观察；RevenueCat 查询失败不写 D1。
- 新增认证路由 `POST /membership/reconcile`。
- `/me`、`/membership`、排行榜加入/身份更新、排行榜 `canJoin` 和训练同步共享同一会员入口。
- Webhook 只触发当前 subscriber 对账；成功后才记录事件已处理，失败返回 503 供重试。
- 新增 Worker Secret 绑定名 `REVENUECAT_SECRET_API_KEY`，仓库不保存值。

### Flutter

- `MembershipApiClient.reconcileMembership()` 调用 Worker 主动对账。
- `AccountController` 在购买/恢复购买后只应用 Worker 返回值。
- 删除 `RevenueCatService.refreshPremium()` 及 SDK active 覆盖服务端的路径。
- `membership_sync_unavailable` 在个人页和运动广场显示独立中英文提示，不误报为非会员。

## 自动化与构建结果

2026-07-16 在隔离 worktree 执行：

| 检查 | 结果 |
|---|---|
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，397/397 |
| `workers/membership-api npm test` | PASS，137/137 |
| 回放硬基线 | PASS，step0=5 / v3=5 / v4=3 |
| 带本机会员配置的 `flutter build apk --debug` | PASS |

新增回归覆盖：Webhook 与当前 subscriber 冲突、Webhook 失败重试、D1 自动重建、旧观察并发保护、统一路由授权、SDK active 不能覆盖 Worker inactive、购买/恢复主动对账，以及同步失败 UI。

## Git 检查点

- `0624e19`：实施计划。
- `524a67d`：Worker 单一权威、D1 migration 和统一鉴权。
- `af1d33c`：Webhook 当前状态对账。
- `3362a08`：Flutter 服务端权威购买/恢复。
- `68d9169`：会员同步失败 UI。

## 尚未执行的线上步骤

以下操作均需要用户另行明确授权，本轮没有执行：

- 远端 D1 备份或 migration `0005`。
- Cloudflare Secret `REVENUECAT_SECRET_API_KEY` 配置。
- Worker 部署、线上接口调用或指定账号对账。
- 真机安装新 Debug 包、Google Play 上传或轨道推进。
- Git push。

授权后的固定顺序为：D1 `0005` → Secret → Worker → 线上对账验收 → App。线上验收必须证明原分裂账号由对账自动恢复，禁止用手工 D1 修改掩盖问题。
