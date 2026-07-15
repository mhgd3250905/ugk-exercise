# 排行榜长按用户操作 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 用长按主题操作面板替换排行榜卡片右侧菜单图标，并补齐举报提交反馈。

**Architecture:** 交互仍留在 `leaderboard_page.dart`，复用现有 `LeaderboardController` 审核命令。底部面板只返回操作枚举；原有举报原因和屏蔽确认继续负责后续步骤，不改后端合同。

**Tech Stack:** Flutter、Dart、Material 3、Flutter Widget Test、ARB l10n。

---

### Task 1: 长按入口与操作面板

**Files:**
- Modify: `test/leaderboard_page_test.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Generated: `lib/l10n/app_localizations*.dart`

**Step 1: 写失败测试**

- 断言其他用户行不再存在 `leaderboard-row-menu-*`。
- 长按稳定用户行 key 后，断言出现用户操作标题和三项操作。
- 长按当前用户行，断言不出现操作面板。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/leaderboard_page_test.dart --plain-name "long press opens moderation actions without a trailing menu"`

Expected: FAIL，因为当前仍使用 `PopupMenuButton`，卡片没有长按操作。

**Step 3: 最小实现**

- 为用户行增加稳定 userId key。
- 使用 Flutter 原生 `GestureDetector`、`Semantics` 和 `HapticFeedback.selectionClick()`。
- 使用 `showModalBottomSheet<_LeaderboardRowAction>` 返回现有操作枚举。
- 面板复用 `ListTile`、主题 surface/outline 和现有图标，不新建共享组件或依赖。

**Step 4: 验证测试通过**

Run: `flutter test test/leaderboard_page_test.dart`

Expected: PASS。

### Task 2: 举报提交反馈

**Files:**
- Modify: `test/leaderboard_page_test.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Generated: `lib/l10n/app_localizations*.dart`

**Step 1: 写失败测试**

使用未完成的 `Completer` 模拟网络等待：选择举报原因后应立即显示“正在提交举报”，完成后显示“已举报并屏蔽该用户”，并从榜单移除目标。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/leaderboard_page_test.dart --plain-name "report shows progress and success feedback"`

Expected: FAIL，因为当前等待期间和成功后都没有提示。

**Step 3: 最小实现**

在现有 `_handleAction` 中复用 `ScaffoldMessengerState`：举报开始时显示带进度指示的 SnackBar，结束后清除；成功显示完成提示，失败显示现有失败提示。屏蔽确认流程保持不变。

**Step 4: 验证测试通过**

Run: `flutter test test/leaderboard_page_test.dart`

Expected: PASS。

### Task 3: 文档、全量验证与提交

**Files:**
- Modify: `docs/design/app-ui-v1.md`

**Step 1:** 更新排行榜卡片低频操作维护规则。

**Step 2:** 运行 `flutter analyze`、`flutter test`、`git diff --check`，确认回放基线 5/5/3。

**Step 3:** 显式暂存本次文件并提交；不得修改或暂存 `docs/handoff-2026-07-14-membership-explore.md`。
