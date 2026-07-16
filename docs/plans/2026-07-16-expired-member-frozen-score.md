# Expired Member Frozen Score Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development task-by-task.

**Goal:** 让已加入榜单但会员已过期的用户仅本人看到当前日/周成绩已冻结，不占公开名次，并可续费或退出榜单。

**Architecture:** 公开榜单继续只查询有效会员。Worker 响应新增可空 `frozenTotalValue`，只在当前用户已加入且会员无效时返回；Flutter 解析该字段并用独立底部卡片展示。复用现有日/周聚合表和续费回调，不新增表、迁移或依赖。

**Tech Stack:** Cloudflare Worker TypeScript/D1、Flutter/Dart、Node test、Flutter widget test。

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
