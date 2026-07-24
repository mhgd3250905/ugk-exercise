# 交接说明：会员功能探索（2026-07-14）

> 给接手的 AI agent / 开发者。本会话任务是**探索和开发会员相关新功能**。
> 先读本文件 + 仓库根 `AGENTS.md`，再开始。

## 工作位置

- 仓库：`E:\AII\ugk-post-membership`（worktree）
- 分支：`feat/membership-explore`，基于 main `11f4250`（最新）
- 改这里不会影响 main 和其他 worktree

## 会员系统全景

### 当前已落地的能力

账号与会员系统已在 main 上稳定运行，包含：

| 能力 | 状态 |
|---|---|
| Google OAuth 登录 | ✅ Play 签名版真机验证通过 |
| RevenueCat 内购 | ✅ Production key 已配置；**订阅商品/base plan 尚未创建**（见下方待办） |
| Cloudflare Worker/D1 后端 | ✅ session/profile/leaderboard/workouts/membership_state 全链路可用 |
| 训练记录云端同步 | ✅ Premium 会员可同步（含排队、原子限制、account-safe） |
| 运动广场排行榜 | ✅ 日榜/周榜 + 游标分页 + 身份选择（匿名/昵称） |
| 账号资料编辑 | ✅ 昵称/头像/排行榜身份 |
| Webhook 签名鉴权 | ✊ RevenueCat webhook → Worker → D1 链路待真机购买验收 |

### 架构分层（依赖只向上）

```
config/membership_config.dart     纯常量（3 个 dart-define + validateMembershipConfig fail-fast）
product/membership_status.dart    数据模型（AppUser / MembershipState），零 Flutter 依赖
platform/membership_api_client.dart   HTTP 客户端，调 Worker
platform/google_auth_service.dart     Google Sign-In 封装
platform/revenuecat_service.dart      RevenueCat SDK 封装
platform/account_session_store.dart   会话持久化
control/account_controller.dart       编排（串起 platform + product，监听 ChangeNotifier）
workers/membership-api/               独立 Cloudflare Worker（TS，账号/会员后端）
```

### 会员相关文件清单

**Flutter App 侧：**

| 文件 | 层 | 职责 |
|---|---|---|
| `lib/config/membership_config.dart` | config | 3 个 `--dart-define` 常量 + release fail-fast |
| `lib/product/membership_status.dart` | product | `AppUser`/`MembershipState` 数据模型（纯 dart） |
| `lib/control/account_controller.dart` | control | 账号编排（登录/登出/会员状态/资料） |
| `lib/control/leaderboard_controller.dart` | control | 排行榜编排（分页/缓存/session 守卫） |
| `lib/control/workout_sync_controller.dart` | control | 训练记录同步编排 |
| `lib/platform/membership_api_client.dart` | platform | Worker HTTP 客户端 |
| `lib/platform/google_auth_service.dart` | platform | Google Sign-In |
| `lib/platform/revenuecat_service.dart` | platform | RevenueCat SDK |
| `lib/platform/account_session_store.dart` | platform | 会话持久化 |
| `lib/ui/pages/profile_page.dart` | ui | 个人页（会员卡/资料编辑/账号删除） |

**Worker 后端侧（`workers/membership-api/src/`）：**

| 文件 | 职责 |
|---|---|
| `index.ts` | 路由入口 + 中间件 |
| `session.ts` | 会话签发/验证（`requireSession`） |
| `google.ts` | Google ID token 验证 |
| `profile.ts` | 账号资料 CRUD |
| `membership_state.ts` | 会员状态读写（RevenueCat webhook 写入） |
| `leaderboard.ts` | 排行榜查询/加入/身份选择（游标分页） |
| `workouts.ts` | 训练记录同步 API |
| `webhook_auth.ts` | RevenueCat webhook 签名验证 |
| `types.ts` | 共享类型 |

**D1 Migrations（`workers/membership-api/migrations/`）：**
- `0001_membership_baseline.sql`
- `0002_account_data_leaderboard.sql`
- `0003_leaderboard_identity.sql`

## 关键纪律（违反会埋坑）

### 1. 凭证纪律（最高优先级）

本项目有历史教训（Cloudflare token 曾在聊天暴露、凭证曾硬编码为默认值）。

- **会员凭证只放 `lib/config/membership_config.dart`**，走 `--dart-define` 注入：
  - `UGK_MEMBERSHIP_API_BASE_URL`
  - `UGK_GOOGLE_SERVER_CLIENT_ID`
  - `UGK_REVENUECAT_ANDROID_API_KEY`
- **凭证不进 git、不进 `app_theme.dart`、不进聊天/Issue/PR**
- **release 缺值由 `validateMembershipConfig()` fail-fast**——禁止为了构建成功绕过校验
- **release 不可使用 RevenueCat `test_` key**——`validateMembershipConfig` 会拒绝
- Worker 的 `GOOGLE_CLIENT_ID`/`SESSION_SECRET`/`REVENUECAT_WEBHOOK_SECRET` 只通过 Cloudflare Dashboard 或 `wrangler secret put` 管理，不写进 `wrangler.toml`
- 私密台账在 `E:\AII\secrets\PushupAI-发布与密钥台账.md`（仓库外）

### 2. 架构纪律

- **`product/` 层零 Flutter 依赖**（`membership_status.dart` 不能 import flutter）
- **l10n 只属于 UI 层**——`AppLocalizations` 不能出现在 product/control/config 层
- **control 层不引 ui/l10n**
- **依赖只向上**：config ← product ← control ← ui

### 3. session 守卫

- `AccountController`/`LeaderboardController`/`WorkoutSyncController` 的异步方法**每个 await 后必须校验 session/account 守卫**
- 账号切换时的竞态是已知陷阱——`LeaderboardController` 用了三重守卫（generation + account + cursor-drift），新功能要照此模式

### 4. Worker 安全

- 所有 D1 查询用 `?` 占位符，**禁止 SQL 字符串拼接**
- 所有敏感端点必须以 `requireSession(env, request)` 为首语句
- RevenueCat webhook 必须验签（`webhook_auth.ts`），防重放

### 5. 测试

- `flutter analyze` 必须无 issue
- `flutter test` 必须全绿（当前 339 项）
- `cd workers/membership-api && npm test` 必须全绿（当前 108 项）
- 回放基线 5/5/3 是硬约束（算法相关，改信号源必须重验）

## 当前会员相关待办（来自 release-configuration.md）

这些是已知的、与会员直接相关的未完成项：

| 优先级 | 待办 | 当前状态 |
|---|---|---|
| **P0** | 轮换疑似暴露的 Cloudflare API Token | 历史泄露，尚未轮换 |
| **P0** | 核对 Worker 线上版本与三个 Secret | CLI 权限不足，需 Dashboard 核对 |
| **P1** | 创建 Google Play 订阅商品 + base plan | Product ID / 周期 / 价格未由用户确认 |
| **P1** | RevenueCat 商品映射（Product → premium → Package → Offering） | 尚无可购买 Offering |
| **P1** | License Testing 名单 | 未确认测试账号进入许可测试 |
| **P1** | 真实购买全链路验收 | 购买 → RTDN → RevenueCat → webhook → Worker → D1 状态一致 |

## 可探索的功能方向（供参考，非强制）

以下是基于当前架构可以自然扩展的方向，具体做什么由用户决定：

1. **会员权益细化**：当前 `premium` 是单一 entitlement。可探索分级（免费/Pro/Premium）、按功能门控（云端同步、排行榜、数据分析报告等）
2. **会员期试用/促销**：RevenueCat 支持 introductory offer / promotional offer
3. **会员恢复购买体验**：`profile_page.dart` 有"恢复购买"，可优化流程和反馈
4. **订阅状态过期/降级处理**：会员过期后云端数据的保留策略和降级体验
5. **排行榜社交扩展**：好友榜、地区榜、团队挑战（当前只有全球日/周榜）
6. **训练数据导出/报告**：Premium 会员的深度数据分析
7. **跨设备同步体验**：多设备登录时的数据合并策略
8. **会员引导/付费墙优化**：`profile_page.dart` 的 `_showPremiumSheet` 可做成更丰富的付费墙

## 验证命令

```bash
cd E:/AII/ugk-post-membership
flutter analyze                    # 必须无 issue
flutter test                       # 当前 339 绿
cd workers/membership-api && npm test   # 当前 108 绿
```

## 相关文档

| 文档 | 内容 |
|------|------|
| `docs/modules/membership.md` | 会员系统模块说明（注：部分可能过时，以代码为准） |
| `docs/release-configuration.md` | 发布台账（含 Worker/D1/OAuth/RevenueCat/Play 完整配置记录） |
| `docs/testing-release-playbook.md` | 测试分层（本地/排行榜/会员/Alpha） |
| `AGENTS.md` | 架构分层、关键纪律、文档地图 |

## 本分支纪律

- 不用 `git add -A`（根目录有未跟踪临时文件）
- 真机登录/会员验收的 Debug 包必须带本机构建配置（按 `docs/testing-release-playbook.md` §4.1 用 `--dart-define-from-file` 构建）
- 完成后提交到 `feat/membership-explore`，推送给 main 侧审核
