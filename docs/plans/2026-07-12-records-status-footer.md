# Records Status Footer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** 将记录页云端合并与待同步提示从周期切换下方移到热力图例上方，保持日历主流程干净。

**Architecture:** 复用现有 `_StatusMessages` 与 `_StatusChip`，不改同步状态来源、不改 Worker/D1。状态区域位于日历滚动内容之后、`_CalendarLegend` 之前并保持居中换行；`_PeriodSummaryCard` 继续只承载三项统计。

**Tech Stack:** Flutter、flutter_test

---

### Task 1: Widget RED → GREEN

**Files:**
- Modify: `test/records_page_test.dart`
- Modify: `lib/ui/pages/records_page.dart`

**Step 1: Write the failing test**

构建同时包含云端合并状态和待同步数量的 `RecordsPage`，断言两条文案不在统计卡内，且纵向位置位于 `records-calendar-legend` 上方。

**Step 2: Run test to verify RED**

Run: `flutter test test/records_page_test.dart --plain-name "places cloud status above the calendar legend"`

Expected: FAIL，因为当前 `_StatusMessages` 位于统计卡内部。

**Step 3: Write the minimal implementation**

将同一个 `_StatusMessages` 放到日历滚动内容与 `_CalendarLegend` 之间；移除统计卡的可空状态参数并恢复原统计 `Row`。

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
