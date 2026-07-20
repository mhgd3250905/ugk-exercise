# Workout Coach Bar Adaptation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the workout coach bar fit short localized labels, cap long labels at the existing page width, and show ready/training states with a green background.

**Architecture:** Keep `WorkoutStatus` as the semantic source in `WorkoutPage` and pass it into the page-local `_WorkoutCoachBar`. The widget derives only presentation state from the enum, sizes its label within explicit min/max constraints, preserves the existing two-line height, and animates size/color without changing controller behavior.

**Tech Stack:** Flutter Material widgets, `ColorScheme`, Flutter Widget tests.

---

### Task 1: Specify coach bar width and active-state colors

**Files:**
- Modify: `test/workout_page_test.dart`
- Test: `test/workout_page_test.dart`

**Step 1: Write the failing width test**

Add a Widget test on a `320 × 640` English viewport. Render `WorkoutStatus.loadingModel`, record the `workout-coach-bar` width, switch to `WorkoutStatus.narrowForm`, settle the status/size animation, then assert:

```dart
expect(shortWidth, greaterThanOrEqualTo(150));
expect(shortWidth, lessThan(longWidth));
expect(longWidth, lessThanOrEqualTo(320 - 48));
expect(tester.takeException(), isNull);
```

**Step 2: Write the failing semantic color test**

Find the keyed coach-bar surface and verify `readyToStart` and `training` resolve to `Theme.of(context).colorScheme.primary`, while `holdPose` does not.

**Step 3: Run tests to verify RED**

Run:

```powershell
flutter test test/workout_page_test.dart --plain-name "fits coach bar width to localized content"
flutter test test/workout_page_test.dart --plain-name "uses green coach bar for ready and training states"
```

Expected: width comparison and missing/incorrect active surface assertions fail against the current full-width neutral bar.

### Task 2: Implement adaptive sizing and semantic colors

**Files:**
- Modify: `lib/ui/pages/workout_page.dart`
- Test: `test/workout_page_test.dart`

**Step 1: Pass semantic status into the widget**

Extend `_WorkoutCoachBar` with a required `WorkoutStatus status` and pass the already-derived `workoutStatus` from `WorkoutPage`. Do not infer state from localized text.

**Step 2: Apply active colors**

Derive:

```dart
final active = status == WorkoutStatus.readyToStart ||
    status == WorkoutStatus.training;
final background = active
    ? colorScheme.primary
    : surface.withValues(alpha: isDark ? 0.94 : 0.96);
final foreground = active ? colorScheme.onPrimary : colorScheme.onSurface;
```

Use `foreground` for both text and the status dot when active.

**Step 3: Make width content-driven with a cap**

Keep `maxWidth = viewportWidth - 48`, use `minWidth = min(150, maxWidth)`, subtract padding/dot/gap to cap the label, remove the expanding `Flexible + Align` behavior, and keep `reservedTextHeight` as the minimum label height. Wrap the surface in `AnimatedSize` and use `AnimatedContainer` for the color transition, with a zero duration when animations are disabled.

**Step 4: Run focused tests to verify GREEN**

Run:

```powershell
flutter test test/workout_page_test.dart
```

Expected: every workout page Widget test passes, including the existing 300ms narrow-guidance debounce and fixed-height checks.

### Task 3: Document and verify the UI change

**Files:**
- Modify: `docs/design/app-ui-v1.md`

**Step 1: Update the training-page maintenance rule**

Record that the coach bar fits localized content between the 150dp minimum and the existing page cap, preserves two-line height, and uses green only for `readyToStart` and `training`.

**Step 2: Run project verification**

Run:

```powershell
flutter analyze
flutter test
flutter test test/domain_self_check_test.dart
git diff --check
```

Expected: 0 analysis issues, all Flutter tests pass, replay baselines remain step0=5 / v3=5 / v4=3, and no whitespace errors.

**Step 3: True-device smoke test**

Use the existing production-config Debug installation workflow. Confirm loading/short prompts shrink, long English guidance stays capped without overflow, ready/training turn green, and stop/navigation remain functional. Do not rebuild or upload a Play candidate.
