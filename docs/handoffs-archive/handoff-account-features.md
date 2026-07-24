# 交接说明：用户账号相关功能（feat/account-features）

> 给接手本分支的 AI agent / 开发者。
> 基线：`main @ 4217dbd`（已含会员系统 + i18n/主题）。
> 接手前先读仓库根 `AGENTS.md` + `docs/development-guide.md`。

## 工作位置

- worktree：`E:\AII\ugk-post-account`
- 分支：`feat/account-features`
- 起点：`4217dbd`（与远程 main 同步）

## 这次要做什么

用户账号相关功能的新需求。**具体需求待定**（由派发者补充），但围绕现有账号/会员系统展开。
常见可能方向（仅供接手者参考，以派发者实际需求为准）：
- 统一权限入口（`canUse(feature)` / `FeatureAccess`）——当前 premium 状态只用于个人页展示，未做功能分流
- 训练记录云端同步（当前 session 只存本地 `WorkoutSessionStore`）
- 账号资料编辑（头像/昵称）
- 多设备登录 / session 管理

## 现有账号系统全貌（基于代码实测，非旧文档）

### 分层与文件

| 层 | 文件 | 职责 |
|----|------|------|
| product | `lib/product/membership_status.dart` | 纯数据模型：`AppUser` / `MembershipStatus` / `AccountSnapshot` |
| control | `lib/control/account_controller.dart` | 编排（`extends ChangeNotifier`）：登录/恢复/退出/购买/恢复购买/状态同步 |
| platform | `lib/platform/google_auth_service.dart` | Google 登录封装（`google_sign_in`） |
| platform | `lib/platform/revenuecat_service.dart` | RevenueCat 内购封装；含 `FakeRevenueCatService` 供测试注入 |
| platform | `lib/platform/membership_api_client.dart` | Worker HTTP 客户端（`authGoogle` / `me`）；可注入 `http.Client` |
| platform | `lib/platform/account_session_store.dart` | 本地 session 持久化（`flutter_secure_storage`）；含 `MemoryAccountSessionStore` 供测试 |
| config | `lib/config/membership_config.dart` | 凭证常量（dart-define 注入）+ `validateMembershipConfig()` release fail-fast |
| ui | `lib/ui/pages/profile_page.dart` | 个人页（登录态/会员态/paywall） |
| 后端 | `workers/membership-api/` | Cloudflare Worker（TS），独立 npm 项目 |

### AccountController 关键行为（control/account_controller.dart）

- 公开 getter：`user` / `membership` / `signedIn` / `premium` / `busy` / `error`
- 命令：`signIn()` / `signOut()` / `restore()` / `purchasePremium()` / `restorePurchases()`
- `_run()` 统一包装：置 busy、清 error、catch `PurchaseCancelledException`（静默）/`PurchaseFailedException`（存 message）/其他（toString）
- `restore()`：启动时恢复本地 session；401（过期）则清本地 session 不报错
- `_applySnapshot()`：后端状态 + RevenueCat SDK 状态取并集（SDK active 时不被旧 expiresAt 抵消）

### Worker 端点（workers/membership-api/src/index.ts）

- `POST /auth/google` — Google ID token 换 session
- `GET /me` — 当前账号快照（需 Bearer session）
- `GET /membership` — 当前会员态
- `POST /webhooks/revenuecat` — HMAC-SHA256 签名 + 5min 防重放 + 幂等 + 乱序原子防护

### D1 表（workers/membership-api/schema.sql）

`users` / `auth_identities` / `sessions` / `membership_snapshots` / `webhook_events`

### 测试覆盖（已落地）

- `test/account_controller_test.dart` — 9 个测试：signIn/restore/signOut/购买取消/购买失败/sdk active 覆盖过期 expiresAt 等
- `test/profile_page_test.dart` — 4 个 widget 测试：未登录/已登录非会员/已是会员/paywall
- `test/membership_api_client_test.dart` / `test/membership_status_test.dart` / `test/account_session_store_test.dart` / `test/revenuecat_service_test.dart`
- `workers/membership-api/test/*.mjs` — 21 个测试（签名/session/webhook 路由/幂等/防重放）

## 纪律（违反会埋坑，AGENTS.md 有详细说明）

1. **会员凭证不进 git/app_theme** — 只在 `lib/config/membership_config.dart`，走 `--dart-define`，release 缺值 fail-fast
2. **不用 `git add -A`** — 显式 stage 代码文件（.gitignore 已挡住临时产物，但仍守纪律）
3. **AccountController 异步方法注意状态安全** — 参考 WorkoutController 的 session 守卫思路；account 的 `_run` 已做 busy/error 包装，但新增 async 流程要考虑竞态
4. **l10n 只在 UI/app 根** — domain/product/control 不引用 `AppLocalizations`
5. **Worker 改动要同步测** — `cd workers/membership-api && npm test` 必须全绿
6. **真实 secret 绝不进代码/测试/汇报** — HMAC secret / token / key 一律 `wrangler secret` 或 `--dart-define`

## 验证（每次改动后）

```bash
flutter analyze                    # 必须无 issue
flutter test                       # 必须全绿（当前 117，含回放基线 5/5/3）
cd workers/membership-api && npm test   # Worker 改动时（当前 21）
```

- 回放基线 `Step0=5 / video3=5 / video4=3` 是硬约束，改信号源必须重验
- 账号/会员改动不应影响俯卧撑识别算法（`pushup_domain.dart`）

## 已知边界 / 可扩展点（供新需求参考）

1. **premium 状态尚未接入功能分流** — 训练/记录/测试模式仍全开放，`premium` 只在个人页用
2. **训练记录只在本地** — `WorkoutSessionStore` 无云端同步
3. **session 无主动过期清理调度** — 仅在 `requireSession` 命中过期时删该行；无 TTL 扫描
4. **webhook 无环境/store 白名单** — sandbox/production 混在一起
5. **无 D1 migrations 目录** — schema 靠手工 `schema.sql`，生产库可能漂移

## ⚠️ 未了安全事项（与代码无关，需人工处理）

- **Cloudflare API token 曾在聊天暴露，尚未轮换** — Worker/D1 资源处于"锁已知被复制"状态。上线前必须撤销重建最小权限 token。
- 上线前需在 Cloudflare `wrangler secret put REVENUECAT_WEBHOOK_SECRET`，并在 RevenueCat 后台配置同一 signing secret。
- release 构建必须 `--dart-define` 注入三项 Flutter 配置（base url / Google client id / RevenueCat key）。

## 相关文档

- `docs/modules/membership.md`（注：该文档部分内容已过时——webhook 实际已改 HMAC、测试数已变 117，以代码为准）
- `docs/superpowers/specs/2026-07-09-membership-subscription-design.md` — 会员订阅设计
- `docs/superpowers/plans/2026-07-09-membership-subscription.md` — 实施计划
- `workers/membership-api/schema.sql` — D1 表结构
- `docs/development-guide.md` — 开发准则
