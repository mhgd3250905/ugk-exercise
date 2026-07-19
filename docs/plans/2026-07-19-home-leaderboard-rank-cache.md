# Home Leaderboard Rank Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let the Home sports-plaza card reuse the signed-in user's latest current-Shanghai-day rank while the authoritative score refreshes, without using cached data for membership, join eligibility, or ranking logic.

**Architecture:** Persist a compact, account-scoped rank value separately from `LeaderboardSnapshot`. The controller restores it before Home renders, begins the existing authoritative request, then replaces or invalidates the cache only from a successful Worker response. Home may render the value only while the account is being verified or is confirmed Premium; it replaces the score with a fixed-size loader for an active day request.

**Tech Stack:** Flutter/Dart, `flutter_secure_storage`, ARB localization, controller tests, widget tests.

---

### Task 1: Create the scoped cache value and store

**Files:**
- Create: `test/leaderboard_home_rank_store_test.dart`
- Create: `lib/product/leaderboard_home_rank.dart`
- Create: `lib/platform/leaderboard_home_rank_store.dart`

**Step 1: Write failing tests**

Cover Shanghai day and Monday-week scope calculation, secure round trip, owner/period/scope/metric isolation, corrupt and obsolete payload rejection, and account-only clearing.

**Step 2: Confirm RED**

Run `flutter test test/leaderboard_home_rank_store_test.dart`; it must fail because the value and store do not exist.

**Step 3: Implement the minimum value/store**

Create immutable `LeaderboardHomeRank` with `ownerAppUserId`, period, Shanghai scope, `pushup_points_v1`, positive rank, and non-negative points. Add injected secure and memory stores with an account-and-period key, schema validation, and no persisted snapshot rows, profile data, membership state, join state, or token.

**Step 4: Confirm GREEN**

Run `flutter test test/leaderboard_home_rank_store_test.dart` and expect PASS.

### Task 2: Add controller hydration, update, and invalidation

**Files:**
- Modify: `test/leaderboard_controller_test.dart`
- Modify: `lib/control/leaderboard_controller.dart`

**Step 1: Write failing tests**

Cover same-account hydration without fabricating `LeaderboardSnapshot`; rejection of delayed hydration after sign-out/switch; retained rank plus day loading state during refresh; replacement after success; removal after authoritative unjoined/no-rank/membership rejection or leave; preservation after request failure; account-isolated loading leases; Shanghai scope expiry and cross-boundary late responses; non-blocking cache I/O; and serialized stale write/clear ordering.

**Step 2: Confirm RED**

Run `flutter test test/leaderboard_controller_test.dart`; it must fail because cache APIs and per-period loading state are missing.

**Step 3: Implement the minimum controller behavior**

Inject optional rank store and clock. Keep rank cache outside `_snapshot`/`_snapshots`, expose owner-and-Shanghai-scope-checked `homeRankFor(period)`, `restoreHomeRankForCurrentAccount()`, and per-period `isLoading(period)`. Update/clear cache only after authoritative snapshots, keep it after transient request failures, clear it for authoritative membership/join rejection, and reject cross-scope late responses. Clear memory before notification on leave/sign-out/switch, serialize secure mutations without awaiting them in the authoritative UI path, and deduplicate an in-flight same-session reload started at launch.

**Step 4: Confirm GREEN**

Run `flutter test test/leaderboard_controller_test.dart` and expect PASS, including the existing stale-account regressions.

### Task 3: Hydrate then refresh during startup

**Files:**
- Modify: `lib/main.dart`

**Step 1: Preserve a failing controller-level startup seam**

Keep a test that hydrates cached rank then starts a pending `reloadForCurrentAccount`, proving the rank remains visible while the live request runs.

**Step 2: Wire the existing startup future**

Construct `SecureLeaderboardHomeRankStore`, await rank hydration after `controller.localRestoreCompleted`, then start—but do not await—the authoritative reload. This keeps `/me` and leaderboard requests non-blocking and lets duplicate account-completion calls share the active reload.

**Step 3: Verify**

Run `flutter test test/leaderboard_controller_test.dart` and expect PASS.

### Task 4: Keep the Home card layout stable during refresh

**Files:**
- Modify: `test/home_page_test.dart`
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`

**Step 1: Write failing widget tests**

Cover immediate cached day-rank display with a `home-sports-plaza-score-loading` indicator and no old score text; successful refresh replacing it with new score; confirmed non-Premium or server-confirmed unjoined state hiding cache; no cache retaining today's prompt; and week-only rank never appearing on Home.

**Step 2: Confirm RED**

Run `flutter test test/home_page_test.dart`; it must fail because the card does not expose cache or loading semantics.

**Step 3: Implement the minimal UI**

Add one localized semantic loading label and run `flutter gen-l10n`. Resolve Home rank from the controller's day display value, never its selected page snapshot. Use cache only for signed-in verification/Premium display continuity. Add `isRefreshing` to `_JoinedRank`; replace only its score text with a fixed 20dp, 2dp-stroke spinner while the day request runs.

**Step 4: Confirm GREEN**

Run `flutter test test/home_page_test.dart` and expect PASS without narrow-layout regressions.

### Task 5: Document, verify, and hand off

**Files:**
- Modify: `docs/design/app-ui-v1.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/plans/README.md`

**Step 1: Document boundaries**

State that this is an account-scoped, Shanghai-period-scoped, display-only cache; `AccountController` and Worker remain authoritative. Add store/controller/widget cache coverage to leaderboard testing guidance and index this plan.

**Step 2: Run final gates**

Run `flutter analyze`, `flutter test`, `flutter test test/domain_self_check_test.dart test/pushup_session_replay_test.dart`, and `git diff --check`. Require zero analyzer issues, all tests green, replay step0=5/v3=5/v4=3, and clean whitespace.

**Step 3: Respect delivery boundaries**

Report exact results; wait for separate authorization before installing, committing, pushing, merging, deploying, or changing any remote data/configuration.

## 2026-07-19 独立审查修复补记

- 跨上海日/周边界返回的旧请求必须在写入 `_snapshots`、当前 `_snapshot` 或首页名次缓存之前整体丢弃；日榜和周榜测试同时断言三类状态均不被污染。
- 首页缓存名次只允许在本地账号已恢复但服务端会员结论尚未返回，或账号已确认 Premium 时展示。通用账号 `busy` 不再代表会员仍待核验；服务端确认 inactive 后，即使本地持久化或 RevenueCat 配置仍在等待，也必须立即隐藏缓存名次。
- 兼容合同补测包括：窄距腕宽 `1.25` 精确放行与 `1.25 + ε` 拒绝、训练提示 debounce 在 dispose/recreate 后不残留、v1 次数游标拒绝用于积分榜、旧 Worker 次数响应由新 App 安全转为本地化可重试错误。
- 第二轮复验进一步要求每份内存榜单快照记录自身上海周期 scope；`loadMore`、`refreshAll`、身份刷新、当前快照回填和本地屏蔽过滤必须共用同一过期判定，不能只保护首次 `load`。
- 会员核验 pending 必须由“接受任一有效 `/me` 快照”统一结束，覆盖 restore 正常返回以及 restore 暂时失败后由 refresh 恢复的路径；对应 Widget 测试在安全存储仍阻塞时断言旧缓存排名已隐藏。
- 所有可接受有效 `/me` 的账号入口都必须复用同一用户与会员接收方法，包含头像政策接受后的刷新；账号 generation/session 守卫必须保证迟到快照不能结束新账号状态。
- 上海周期隔离同时覆盖成功与失败结果：`load`、`loadMore`、`refreshAll` 和身份变更后的刷新如果跨界，均不得写入快照、首页排名、错误或 loading 状态；当前周期失败仍保留既有可重试错误语义。
- 分页 loading 必须使用请求级 lease，而不是只按 period 记录；lease 绑定 generation、session、账号、上海周期与 cursor，迟到的旧账号请求只能释放自身 lease，不能提前结束新账号分页或放开重复请求。
- 头像政策刷新中的两处账号守卫分别需要竞态测试：政策请求迟到时不得为旧账号调用 `/me`，旧 `/me` 迟到时不得覆盖新账号的 user、membership 或 pending。
- 第六轮独立复验确认代码、测试与当前台账内容通过；Play 运行结果仍由用户验收，info 历史提交元数据修正不得在未授权时执行。
