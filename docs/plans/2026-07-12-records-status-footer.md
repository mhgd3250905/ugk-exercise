# Records Status Footer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** 将记录页云端合并与待同步提示从周期切换下方移入统计卡底部，保持日历主流程干净。

**Architecture:** 复用现有 `_StatusMessages` 与 `_StatusChip`，不改同步状态来源、不改 Worker/D1。`_PeriodSummaryCard` 接收可空状态区域，在三项统计下方用分隔线承载可换行状态标签；无云状态时保持原高度。

**Tech Stack:** Flutter、flutter_test

---

### Task 1: Widget RED → GREEN

**Files:**
- Modify: `test/records_page_test.dart`
- Modify: `lib/ui/pages/records_page.dart`

**Step 1: Write the failing test**

构建同时包含云端合并状态和待同步数量的 `RecordsPage`，断言两条文案都是 `records-period-summary` 的后代。

**Step 2: Run test to verify RED**

Run: `flutter test test/records_page_test.dart --plain-name "places cloud status inside the period summary card"`

Expected: FAIL，因为当前 `_StatusMessages` 位于周期切换与日历之间。

**Step 3: Write the minimal implementation**

删除顶部状态块，将同一个 `_StatusMessages` 作为可空 `status` 传给 `_PeriodSummaryCard`；统计卡用 `Column` 包住原统计 `Row`，存在状态时追加分隔线和状态区域。

**Step 4: Run test to verify GREEN**

Run: `flutter test test/records_page_test.dart`

Expected: PASS。

### Task 2: 验证与交付

**Files:**
- Modify: `docs/design/app-ui-v1.md`

**Step 1:** 更新记录页结构说明。

**Step 2:** Run `flutter analyze`，Expected: no issues。

**Step 3:** Run `flutter test`，Expected: all tests pass，回放基线保持 5/5/3。

**Step 4:** Run `git diff --check`，Expected: no output。

**Step 5:** 使用本机配置构建 Debug APK并覆盖安装真机；不输出配置值。

**Step 6:** 显式提交本次文件，不触碰 `docs/handoff-account-features.md`，不做远端写入。
