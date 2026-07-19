# Leaderboard Points Breakdown Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Clarify the leaderboard scoring rule and show the signed-in user's standard/narrow push-up counts inside the bottom rank card for the selected day or week.

**Architecture:** Extend the points-v1 Worker response with an optional `myExerciseCounts` object derived from the same daily-total rows and period as the score. Parse it into a typed optional Flutter model so an older Worker remains safe: when the field is absent the app hides the breakdown instead of failing the leaderboard. Keep other users' exercise counts private and leave legacy push-up leaderboard responses unchanged.

**Tech Stack:** Dart/Flutter, ARB localization, Flutter widget tests, TypeScript Cloudflare Worker, Node test runner with SQLite-backed D1 harness.

---

### Task 1: 固定 Worker 返回合同

**Files:**
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify: `workers/membership-api/src/leaderboard.ts`

**Steps:**
1. 先在日榜与周榜积分测试中断言本人明细为标准 56、窄距 6，运行定向 Worker 测试并确认红灯。
2. 在现有积分聚合 SQL 中同时计算两种运动原始次数，不增加 D1 查询或迁移。
3. 仅对 `pushup_points_v1` 且本人有排行行时返回 `myExerciseCounts`；不向 `top` 行泄露其他用户明细。
4. 重跑 Worker 测试至通过，并守护旧 `exerciseType=pushup` 返回合同。

### Task 2: 建立向后兼容的 Flutter 模型

**Files:**
- Modify: `test/membership_api_client_test.dart`
- Modify: `lib/product/leaderboard_models.dart`
- Modify: `lib/control/leaderboard_controller.dart`

**Steps:**
1. 先写 typed parser 测试，覆盖合法明细、缺失字段兼容和非法非负整数拒绝。
2. 增加 `LeaderboardExerciseCounts` 与 `LeaderboardSnapshot.myExerciseCounts` 可选字段。
3. 在分页合并和屏蔽用户后的快照复制中保留本人明细。
4. 重跑 API client 与 controller 定向测试至通过。

### Task 3: 卡片内展示与文案调整

**Files:**
- Modify: `test/leaderboard_page_test.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`

**Steps:**
1. 先把规则断言改为“标准 1 分 · 窄距 2 分”，并新增本人卡片内部底部明细的 Widget 失败测试。
2. 在 ARB 中增加中英文参数化文案，执行 `flutter gen-l10n`。
3. 将本人排名卡片改为主行加底部明细行；明细字段缺失时保持旧卡片高度与布局。
4. 验证中英文、小屏、浅深主题下无溢出且语义仍保留。

### Task 4: 全量验证与发布边界

**Steps:**
1. 运行 `npm test`、`flutter analyze`、`flutter test`、`git diff --check`。
2. 本任务不迁移 D1、不部署 Worker、不安装依赖新合同的 App。
3. 后续发布必须保持 **Worker 先、App 后**；Worker 部署与真机安装分别等待用户明确授权。
