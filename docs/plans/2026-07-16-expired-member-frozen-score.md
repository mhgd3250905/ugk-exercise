# Expired Member Frozen Score Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development task-by-task.

**原始 Goal（已被下文“用户测试后的规则修订”替代）：** 让已加入榜单但会员已过期的用户仅本人看到当前日/周成绩已冻结，不占公开名次，并可续费或退出榜单。

**原始 Architecture（已被下文修订）：** 公开榜单继续只查询有效会员。Worker 响应新增可空 `frozenTotalValue`，只在当前用户已加入且会员无效时返回；Flutter 解析该字段并用独立底部卡片展示。复用现有日/周聚合表和续费回调，不新增表、迁移或依赖。

**Tech Stack:** Cloudflare Worker TypeScript/D1、Flutter/Dart、Node test、Flutter widget test。

**执行结果（2026-07-16）：** 计划内功能随后在用户逐项授权下完成提交、Worker 部署和 `0.3.8 (10)` 内部测试发布；本计划 Task 4 的“不要部署/上传”仅是实现阶段的授权边界，不代表当前发布状态。

## 用户测试后的规则修订

用户在 `0.3.8 (10)` 真机测试后确认目标不是“过期后退出公开排名”，而是：加入过榜单的用户只有主动退出才移除；会员过期后公开保留冻结成绩并继续参与排序，其他会员可通过新增成绩超过他；过期本人额外看到冻结说明、续费和退出入口。

最小实现只修改 Worker：公开日榜/周榜查询所有 `is_joined = 1` 用户，当前用户会员状态继续走权威对账并决定是否返回 `frozenTotalValue`；训练同步的会员门控保持不变。不新增 D1 migration，现有 `0.3.8 (10)` App 已兼容新的响应组合，无需重建 AAB。用户单独授权后，修订 Worker 已于 2026-07-16 12:13:41（北京时间）部署，三个生产未登录鉴权探针均返回预期 `401`；用户随后报告真机已看到公开排名行与本人冻结卡，核心线上链路测试通过。

---

### Task 1: Worker 本人冻结成绩合同

**Files:**
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify: `workers/membership-api/src/leaderboard.ts`

1. 增加失败测试：过期且已加入的当前用户不在 `top`/`me`，但日榜和周榜返回自己的 `frozenTotalValue`。
2. 运行 `npm test -- --test-name-pattern="frozen"`，确认因字段缺失失败。
3. 最小实现：复用 `leaderboard_daily_totals` 查询当前用户当日或当周总数；只有 `isJoined && !membershipActive` 时返回。
4. 重新运行定向 Worker 测试并确认通过。

### Task 2: Flutter 响应模型

**Files:**
- Modify: `test/membership_api_client_test.dart`
- Modify: `lib/product/leaderboard_models.dart`

1. 增加失败测试：解析非负 `frozenTotalValue`，缺失字段保持向后兼容。
2. 运行 `flutter test test/membership_api_client_test.dart`，确认字段不存在导致失败。
3. 给 `LeaderboardSnapshot` 增加可空整数字段和边界校验。
4. 重新运行定向测试并确认通过。

### Task 3: 本人冻结成绩卡片

**Files:**
- Modify: `test/leaderboard_page_test.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`

1. 增加失败 Widget 测试：冻结卡片显示成绩和续费入口，不显示名次；仍可退出榜单。
2. 运行 `flutter test test/leaderboard_page_test.dart`，确认卡片缺失导致失败。
3. 添加最小底部卡片，复用现有 `onSubscribe`、退出动作和成绩格式化文案。
4. 运行 `flutter gen-l10n` 和定向测试，确认通过。

### Task 4: 全量验证

1. 运行 `npm test`。
2. 运行 `flutter analyze`、`flutter test`、`git diff --check`。
3. 核对回放基线保持 `5/5/3`，且仅修改计划内文件和先前引导页修复文件。
4. 不提交、不部署、不修改 D1、不构建或上传 Play；等待用户汇总其余测试项。
