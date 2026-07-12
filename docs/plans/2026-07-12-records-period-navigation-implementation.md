# Records Period Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add previous/next navigation to week, month, and year records while preventing future periods and preserving each mode's position.

**Architecture:** Keep navigation state inside `_RecordsContentState` as one integer offset per `_RecordsPeriod`. Derive the selected week, month, and year from `widget.now`, then reuse the existing in-memory totals and `AnimatedSwitcher`; no store, sync, or backend changes.

**Tech Stack:** Flutter, Dart, `flutter_test`, existing localization and theme APIs.

---

### Task 1: Period dates, arrows, and summaries

**Files:**
- Modify: `test/records_page_test.dart`
- Modify: `lib/ui/pages/records_page.dart`

**Step 1: Write the failing month navigation test**

Add a widget test that:

- creates records in the current and previous month;
- verifies the next button is disabled initially;
- taps `ValueKey('records-period-previous')`;
- verifies the previous month title and summary;
- verifies the next button becomes enabled and returns to the current month.

**Step 2: Run the test to verify RED**

Run:

```powershell
flutter test test\records_page_test.dart --plain-name "navigates months without entering the future"
```

Expected: FAIL because the navigation buttons do not exist.

**Step 3: Implement minimal navigation state and UI**

In `_RecordsContentState`:

```dart
final _periodOffsets = List<int>.filled(_RecordsPeriod.values.length, 0);

int get _periodOffset => _periodOffsets[_period.index];

void _shiftPeriod(int delta) {
  final next = _periodOffset + delta;
  if (next > 0) return;
  setState(() {
    _slideDirection = delta.isNegative ? -1 : 1;
    _periodOffsets[_period.index] = next;
  });
}
```

Derive:

```dart
final currentWeekStart = today.subtract(Duration(days: now.weekday % 7));
final weekStart = currentWeekStart.add(
  Duration(days: _periodOffsets[_RecordsPeriod.week.index] * 7),
);
final selectedMonth = DateTime(
  now.year,
  now.month + _periodOffsets[_RecordsPeriod.month.index],
);
final selectedYear =
    now.year + _periodOffsets[_RecordsPeriod.year.index];
```

Use these values for filtering, titles, grids, and summaries. Overlay two keyed `IconButton`s around the animated title. The next button uses `onPressed: _periodOffset < 0 ? () => _shiftPeriod(1) : null`.

Use `MaterialLocalizations.previousPageTooltip` and `nextPageTooltip`; do not add ARB strings.

**Step 4: Run the test to verify GREEN**

Run the same targeted test. Expected: PASS.

**Step 5: Commit**

```powershell
git add -- lib/ui/pages/records_page.dart test/records_page_test.dart
git commit -m "feat(ui): navigate record periods"
```

### Task 2: Week/year behavior, memory, and animation direction

**Files:**
- Modify: `test/records_page_test.dart`
- Modify: `lib/ui/pages/records_page.dart`

**Step 1: Write failing behavior tests**

Add tests that verify:

- week navigation moves exactly seven days and updates the summary;
- year navigation moves exactly one year and updates the summary;
- month and week offsets remain unchanged when switching modes;
- a previous period enters from the left and the return to the next period enters from the right;
- historical month/year cells do not mark today's day/month.

**Step 2: Run tests to verify RED**

```powershell
flutter test test\records_page_test.dart
```

Expected: at least the content-key/animation and mode-memory assertions fail.

**Step 3: Complete the minimal keyed transition**

Build the content key from the selected mode and its offset:

```dart
final baseKey = 'records-period-content-${_period.name}';
final contentKey = ValueKey(
  _periodOffset == 0 ? baseKey : '$baseKey-history${-_periodOffset}',
);
```

Use `contentKey` both on the incoming child and when detecting the incoming child in `transitionBuilder`. Keep the existing 220ms duration and curves.

Compare complete dates for month `isToday`, and require `selectedYear == now.year` for the year cell highlight.

**Step 4: Run tests to verify GREEN**

```powershell
flutter test test\records_page_test.dart
```

Expected: all records page tests pass.

**Step 5: Commit**

```powershell
git add -- lib/ui/pages/records_page.dart test/records_page_test.dart
git commit -m "test(ui): cover record period navigation"
```

### Task 3: Documentation and final verification

**Files:**
- Modify: `docs/design/app-ui-v1.md`

**Step 1: Update the records UI contract**

Document the title arrows, no-future boundary, independent mode memory, and horizontal transition.

**Step 2: Run verification**

```powershell
dart format lib\ui\pages\records_page.dart test\records_page_test.dart
flutter analyze
flutter test
git diff --check
```

Expected: zero analysis issues, all tests pass, no whitespace errors.

**Step 3: Build and install configured Debug APK**

```powershell
flutter build apk --debug --dart-define-from-file=E:\AII\运动app-prod-info.txt
adb -s QSG6Q8IFDMDELVGQ install -r build\app\outputs\flutter-apk\app-debug.apk
```

Verify on device: arrows, disabled future state, period totals, direction, and retained mode positions.

**Step 4: Commit documentation**

```powershell
git add -- docs/design/app-ui-v1.md docs/plans/2026-07-12-records-period-navigation-implementation.md
git commit -m "docs: document records period navigation"
```

