# 会员权益单一权威与自动对账实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 从根本消除“个人资料显示会员、运动广场却要求会员”的状态分裂，使所有云端权限最终由 Worker 的同一套权益裁决得出，并能在 Webhook 丢失或乱序时依据 RevenueCat 当前订阅事实自动恢复。

**架构原则：** Google Play 是交易来源，RevenueCat 当前 subscriber entitlement 是权益事实，Worker 是唯一授权权威，D1 `membership_snapshots` 只是带验证时间的可重建缓存。Flutter 中 RevenueCat SDK 仅负责购买、恢复购买和收据同步，不再直接授予 VIP 或云端权限。所有需要会员的 Worker 路由复用同一个权益读取/必要时对账入口。

**技术栈：** Flutter/Dart、Cloudflare Workers/TypeScript、D1/SQLite、RevenueCat REST API v1、Vitest、Flutter test。

## 不在本轮范围内

- 不手工修改任何线上账号的 D1 会员快照。
- 不执行 Worker/D1/RevenueCat/Google Play 的平台写入、部署或发布。
- 不推送分支；部署、线上迁移、密钥配置和推送都需要用户另行明确授权。
- 不修改或暂存原工作区中的用户临时文件及未跟踪资料。

## 成功标准

1. RevenueCat 当前权益有效而 D1 缺失、过期或未验证时，Worker 能自动重建快照并允许会员操作。
2. Flutter 本地 SDK 缓存为有效、但 Worker 当前权益为失效时，App 不再显示 VIP，也不能获得会员权限。
3. Webhook 重复、乱序或携带旧的过期事件时，最终结果仍以 RevenueCat 当前 subscriber 状态为准。
4. RevenueCat 暂时不可用时，不覆盖已有快照；失效或无法验证的快照不会被错误授权，并向主动同步调用返回明确的同步失败错误。
5. 会员判断不再散落于排行榜和训练同步路由，所有调用共享同一权威入口。
6. `flutter analyze`、`flutter test`、Worker 全量测试通过，算法回放基线保持 step0=5 / v3=5 / v4=3。

---

## Task 1：锁定 Worker 对账契约（RED）

**Files:**
- Create: `workers/membership-api/test/membership-reconciliation.test.mjs`
- Create: `workers/membership-api/src/membership_reconciliation.ts`
- Modify: `workers/membership-api/src/types.ts`

**Step 1：先写失败测试**

覆盖以下契约：

- D1 过期、RevenueCat `premium` entitlement 当前有效时，对账返回有效并写回 D1。
- RevenueCat 当前已过期时，对账返回失效，不受旧 D1 有效状态影响。
- 响应缺失 entitlement 时按失效处理。
- RevenueCat 非 2xx、超时或 JSON 结构无效时抛出稳定的 `MembershipReconciliationError`，且不写 D1。
- 两次对账观察乱序落库时，较旧 `verified_at` 不能覆盖较新的观察结果。

通过可注入 `fetcher` 与 `now` 保证测试确定性；测试中只使用假 RevenueCat 响应。

**Step 2：运行测试，确认按预期失败**

Run: `npm run check && npm run build:test && node --test test/membership-reconciliation.test.mjs`

Expected: FAIL，原因是对账模块、环境密钥类型与数据库字段尚不存在。

**Step 3：实现最小对账模块**

- 在 `Env` 增加 `REVENUECAT_SECRET_API_KEY: string`，只声明绑定名，不写入任何密钥值。
- 请求 `GET https://api.revenuecat.com/v1/subscribers/{app_user_id}`，使用 Bearer secret，校验 HTTP 状态与最小 JSON 结构。
- 只读取 `subscriber.entitlements.premium` 的当前状态；`expires_date == null` 表示无固定到期时间，否则以服务端当前时间判断是否有效。
- 将结果写为 `source = 'revenuecat_verified'`，记录 `verified_at`；UPSERT 带时间比较，旧观察不得覆盖新观察。
- 网络/协议失败不执行写入。

**Step 4：运行定向测试，确认通过**

Run: `npm run check && npm run build:test && node --test test/membership-reconciliation.test.mjs`

Expected: PASS。

---

## Task 2：迁移 D1 快照为可验证缓存（RED → GREEN）

**Files:**
- Create: `workers/membership-api/migrations/0005_membership_verified_at.sql`
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/test/helpers/d1_sqlite.mjs`
- Modify: `workers/membership-api/test/schema-migration.test.mjs`

**Step 1：扩展迁移测试并先确认失败**

断言全量迁移后 `membership_snapshots` 含 `verified_at TEXT`，旧数据迁移后字段为空且仍可读取。

Run: `npm run check && npm run build:test && node --test test/schema-migration.test.mjs`

Expected: FAIL，缺少 `0005` 迁移和字段。

**Step 2：添加仅结构变更的迁移**

使用 `ALTER TABLE membership_snapshots ADD COLUMN verified_at TEXT;`，同步更新 `schema.sql` 与 SQLite 测试夹具。历史行保持 `NULL`，由运行时首次读取触发对账。

**Step 3：运行迁移与对账测试**

Run: `npm run check && npm run build:test && node --test test/schema-migration.test.mjs test/membership-reconciliation.test.mjs`

Expected: PASS。

---

## Task 3：所有 Worker 会员权限统一走权威入口（RED → GREEN）

**Files:**
- Modify: `workers/membership-api/src/membership_reconciliation.ts`
- Modify: `workers/membership-api/src/account.ts`
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/src/workouts.ts`
- Modify: `workers/membership-api/test/worker-routes.test.mjs`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`
- Modify: `workers/membership-api/test/workout-sync.test.mjs`

**Step 1：先写失败的路由测试**

- `GET /membership` 或账户载荷遇到未验证/失效快照、RevenueCat 当前有效时，自动对账并返回有效。
- `POST /membership/reconcile` 经会话认证后强制拉取当前权益并返回统一会员载荷。
- 排行榜 `canJoin`、加入排行榜和训练同步在相同会员事实下得出一致结果。
- RevenueCat 不可用且快照已失效时不授权；主动对账返回 HTTP 503 与稳定错误码 `membership_sync_unavailable`。
- 已验证且仍在短缓存窗口内的有效快照不重复访问 RevenueCat。

Run: `npm run check && npm run build:test && node --test test/worker-routes.test.mjs test/leaderboard.test.mjs test/workout-sync.test.mjs`

Expected: FAIL，现有路由仍直接读取 D1，且主动对账路由不存在。

**Step 2：实现共享权威读取入口**

在对账模块提供两种语义：

- `getAuthoritativeMembership`：读取 D1；快照缺失、未验证、已失效/过期或超过验证新鲜度时调用 RevenueCat 对账。
- `reconcileMembership`：忽略缓存，强制核验 RevenueCat 当前状态。

新鲜且未过期的已验证有效快照可在有限 TTL 内复用，避免每次排行榜加载都请求 RevenueCat。对账失败时不得把失效快照提升为有效，也不得覆写数据库。

**Step 3：收口所有调用点**

- `/membership`、账户载荷、排行榜读取/加入/更新、训练同步全部调用共享入口。
- 删除这些模块内重复的 D1 会员布尔判断。
- 增加认证后的 `POST /membership/reconcile`。

**Step 4：运行定向测试**

Run: `npm run check && npm run build:test && node --test test/worker-routes.test.mjs test/leaderboard.test.mjs test/workout-sync.test.mjs`

Expected: PASS。

---

## Task 4：Webhook 改为“通知触发对账”而非权益事实（RED → GREEN）

**Files:**
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/test/worker-routes.test.mjs`

**Step 1：先写失败测试**

- Webhook 事件声称过期，但 RevenueCat 当前 subscriber 有效，最终快照有效。
- Webhook 事件声称有效，但 RevenueCat 当前已过期，最终快照失效。
- 重复和乱序 Webhook 不改变当前事实。
- RevenueCat 暂时失败时返回可重试状态，不能提前把事件永久标记为已处理，也不能污染快照。

Run: `npm run check && npm run build:test && node --test test/worker-routes.test.mjs`

Expected: FAIL，现有实现直接信任事件字段并在对账前去重落库。

**Step 2：改造 Webhook 事务顺序**

- Webhook 只负责鉴权、解析关联用户、触发 `reconcileMembership`。
- 成功对账后再记录事件去重；并发重复最多造成幂等的额外 RevenueCat 查询，不会产生不同权益结果。
- 对账失败返回 503，使上游可重试；不将失败事件永久吞掉。
- 保留事件时间/类型作为审计信息，不用它计算最终权益。

**Step 3：运行 Worker 全量测试**

Run: `npm test`

Expected: 全绿。

**Step 4：提交 Worker 阶段**

显式暂存本任务涉及的 Worker 源码、迁移和测试文件，不使用 `git add -A`。

Commit: `fix: make membership authorization server authoritative`

---

## Task 5：Flutter API client 增加主动对账（RED → GREEN）

**Files:**
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `test/membership_api_client_test.dart`

**Step 1：先写失败测试**

断言 `reconcileMembership(sessionToken)`：

- 使用 `POST /membership/reconcile` 和 Bearer session。
- 正确解析统一 `MembershipStatus`。
- 将 `membership_sync_unavailable` 保留为可识别的 API 错误码。

Run: `flutter test test/membership_api_client_test.dart`

Expected: FAIL，方法尚不存在。

**Step 2：实现最小客户端方法**

复用现有请求、鉴权、错误解析与 JSON 模型，不引入新的状态层或重复 DTO。

**Step 3：运行定向测试**

Run: `flutter test test/membership_api_client_test.dart`

Expected: PASS。

---

## Task 6：AccountController 移除本地 SDK 授权（RED → GREEN）

**Files:**
- Modify: `lib/control/account_controller.dart`
- Modify: `test/account_controller_test.dart`

**Step 1：把旧行为测试改成新的权威语义并确认失败**

- 服务端失效、RevenueCat SDK 本地缓存有效时，`isPremium == false`。
- 登录后的账户快照只按 Worker 返回会员状态渲染，不被 SDK 覆盖。
- 购买或恢复购买完成后调用 Worker 主动对账；只应用对账响应，不直接调用 `_applyRevenueCatActive` 授权。
- SDK 报告购买成功但 Worker 对账失败时，不显示 VIP，保留明确同步错误。

Run: `flutter test test/account_controller_test.dart`

Expected: FAIL，旧测试与 `_applySnapshot` 仍允许 SDK 覆盖服务端。

**Step 2：实现最小控制器改动**

- RevenueCat SDK 保留 configure、purchase、restore 能力。
- 删除或停用 `_applyRevenueCatActive` 的本地授权路径。
- `_applySnapshot` 只应用 Worker 会员快照；SDK 刷新结果不参与 `isPremium` 裁决。
- 购买/恢复成功后调用 `MembershipApiClient.reconcileMembership` 并应用返回值。
- 对账失败不伪装成“未购买”，而是保留稳定错误供 UI 显示。

**Step 3：运行控制器与相关 UI 定向测试**

Run: `flutter test test/account_controller_test.dart`

Expected: PASS。

---

## Task 7：为会员同步失败提供清晰用户反馈（RED → GREEN）

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: corresponding widget tests under `test/`

**Step 1：先写失败 Widget 测试**

当错误码为 `membership_sync_unavailable` 时，购买/恢复入口和运动广场显示“会员权益同步失败，请稍后重试”的明显反馈，而不是误报“需要会员”。英文提供等义文案。

Run: related targeted `flutter test` commands based on existing test filenames discovered during implementation.

Expected: FAIL，现有 UI 没有区分同步故障与非会员。

**Step 2：实现最小 UI 映射**

沿用现有 SnackBar/错误区域风格，不新增全局 Toast 依赖；只映射稳定错误码并保持两种语言一致。

**Step 3：生成本地化代码并运行定向测试**

Run: `flutter gen-l10n`

Run: targeted widget tests.

Expected: PASS。

**Step 4：提交 Flutter 阶段**

显式暂存客户端、控制器、l10n 与相关测试。

Commit: `fix: trust server membership after purchase and restore`

---

## Task 8：全量验证与架构台账更新

**Files:**
- Modify: `docs/modules/membership.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/release-configuration.md` only if the new Worker secret binding/deployment procedure belongs there
- Create: `docs/reports/2026-07-15-membership-authoritative-reconciliation.md`

**Step 1：更新权威文档**

记录：

- 交易来源、权益事实、授权权威、缓存四者的明确边界。
- `REVENUECAT_SECRET_API_KEY` 只通过 Worker secret 配置，值绝不进入仓库。
- Webhook 是加速通知，不是唯一同步通道，也不是最终状态事实。
- D1 `verified_at`、缓存新鲜度、失败时的保守授权语义。
- Flutter SDK 不直接授予 VIP；购买/恢复后的标准对账流程。
- 线上发布顺序：备份/迁移 D1 → 配置 secret → 部署 Worker → 验证接口 → 发布 App。以上均需另行授权。

**Step 2：执行格式化与静态检查**

Run: `dart format` on explicitly changed Dart files.

Run: `flutter analyze`

Expected: 0 issues。

**Step 3：执行 Flutter 全量测试**

Run: `flutter test`

Expected: 全绿，回放基线 step0=5 / v3=5 / v4=3。

**Step 4：执行 Worker 全量测试**

Run: `npm test` in `workers/membership-api`

Expected: 全绿。

**Step 5：进行本地构建验证**

Run: `flutter build apk --debug --dart-define-from-file=<本地已有调试配置文件>` only if the local config path is available and can be used without exposing its contents.

Expected: 构建成功。此步骤不安装、不修改线上平台；若随后需要真机安装验收，再按用户指令执行。

**Step 6：写验证报告并提交文档**

报告只记录脱敏事实、测试命令与结果，不记录邮箱、设备序列号、密钥或令牌。

Commit: `docs: record membership reconciliation architecture and verification`

---

## Task 9：授权后才执行的线上恢复验收（本计划默认不执行）

只有用户另行明确授权后，才能依次进行：

1. 远端 D1 迁移/写入。
2. 配置 Worker `REVENUECAT_SECRET_API_KEY` secret。
3. 部署 Worker。
4. 对指定测试账号触发主动对账，确认 D1 自动恢复而非人工修补。
5. 安装包含 Flutter 修复的测试包，验证个人资料与运动广场状态一致。
6. 模拟沙盒过期再续订，验证 Webhook 丢失/乱序情况下仍最终收敛。
7. 经用户授权后再推送分支、发起审核或进入 Google Play 发布流程。
