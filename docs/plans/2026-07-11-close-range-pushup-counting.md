# Close-Range Pushup Counting Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Count a real torso down-and-up cycle after strict ready calibration even when elbows, wrists, and arms leave the frame, while retaining visible raised-hand and straight-arm rejection.

**Architecture:** Keep `ReadyPoseGate` strict. During motion, nose and shoulders are the required signal; missing arm keypoints are unknown rather than failure. Elbow observations may veto an obviously invalid visible cycle, but missing elbow data must not block a torso rep. Replace unbounded full-session percentiles with a bounded recent sample window.

**Tech Stack:** Dart, Flutter test, existing `PushupCounter` / `SignalExtractor` / `PushupPipeline`.

---

### Task 1: Lock down close-range arm dropout behavior

**Files:**
- Modify: `test/domain_self_check_test.dart`
- Modify: `test/pushup_pipeline_test.dart`

**Step 1: Write failing tests**

- A complete `torsoY` up/down/up cycle with `elbowAngle=null` and low elbow confidence counts once.
- A pipeline cycle whose wrist and elbow keypoints become low-confidence after visible ready/top frames counts once.
- A visible straight-elbow torso cycle remains zero.

**Step 2: Run tests and verify RED**

Run: `flutter test test/domain_self_check_test.dart test/pushup_pipeline_test.dart`

Expected: the new missing-arm tests fail with count `0`; existing straight-arm rejection stays green.

### Task 2: Make arms optional evidence during motion

**Files:**
- Modify: `lib/pushup_domain.dart`
- Test: `test/domain_self_check_test.dart`
- Test: `test/pushup_pipeline_test.dart`

**Step 1: Make wrist support confidence-aware**

Change `wristsBelowShoulders` so a confidently visible wrist above/not-below its shoulder is a contradiction, while a low-confidence wrist is exempt. `ReadyPoseGate` remains strict because it separately requires both wrist confidences.

**Step 2: Scope elbow evidence to the current dip**

When entering the down band, clear prior elbow evidence. Track the minimum visible elbow angle only while the current dip is active. At up-return:

- if both a visible dip angle and a visible return angle exist, require a real bend/extension cycle;
- if either observation is missing, do not veto the torso cycle.

Remove the frame-count elbow latch; arm absence duration must not decide validity.

**Step 3: Run focused tests and verify GREEN**

Run: `flutter test test/domain_self_check_test.dart test/pushup_pipeline_test.dart test/ready_pose_gate_test.dart`

Expected: new dropout tests pass; stationary/noise/straight/fixed-bent tests remain zero; replay stays 5/5/3.

### Task 3: Remove wrist stability from the motion signal

**Files:**
- Modify: `lib/pushup_domain.dart`
- Modify: `lib/product/pushup_pipeline.dart`
- Modify: `lib/control/workout_controller.dart`
- Modify: `test/domain_self_check_test.dart`
- Modify: `test/pushup_pipeline_test.dart`

**Step 1: Write a failing filter/pipeline test**

Seed the torso filter with stable top frames, then pass a complete rep through the pipeline while the legacy wrist-stability verdict is false. The torso trajectory must continue and count once.

**Step 2: Verify RED**

Run: `flutter test test/pushup_pipeline_test.dart`

Expected: count remains `0` because the current filter holds stale torso values.

**Step 3: Implement the minimum removal**

- Stop gating the torso filter on `handsStable`.
- Remove `handsStable` from `PushupPipeline.process` and `FrameSignals` if no behavioral consumer remains.
- Keep `WristAnchor` calibration/diagnostic logging in the controller for now; it must not affect counting.

**Step 4: Verify GREEN**

Run: `flutter test test/domain_self_check_test.dart test/pushup_pipeline_test.dart test/wrist_anchor_test.dart`

### Task 4: Prevent long-wait first-rep loss and unbounded sorting

**Files:**
- Modify: `lib/pushup_domain.dart`
- Modify: `test/domain_self_check_test.dart`

**Step 1: Write failing tests**

- Hold top position for 300 accepted samples, then perform one valid rep; expect count `1`.
- Pause at the top between two reps; expect count `2`.

**Step 2: Verify RED**

Run: `flutter test test/domain_self_check_test.dart --plain-name "wait"`

Expected: the first long-wait test reports count `0` with full-history p95.

**Step 3: Bound the recent amplitude history**

Add one configurable recent-sample limit to `CounterConfig` and discard the oldest accepted sample beyond it. Start with the smallest candidate that preserves 5/5/3 and the existing 1–3 reps/s tests; do not introduce a new statistics abstraction.

**Step 4: Verify GREEN and regressions**

Run: `flutter test test/domain_self_check_test.dart test/pushup_pipeline_test.dart`

Expected: long waits count correctly; noise remains zero; replay remains 5/5/3.

### Task 5: Align documentation and perform full verification

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/modules/pushup-pipeline.md`
- Modify: `docs/modules/wrist-anchor.md`

**Step 1: Update only implemented behavior**

Document strict-ready/torso-motion asymmetric evidence, optional elbow veto, confidence-aware wrist handling, bounded amplitude history, and the actual 20px support margin.

**Step 2: Run final verification**

Run: `dart format lib/pushup_domain.dart lib/product/pushup_pipeline.dart lib/control/workout_controller.dart test/domain_self_check_test.dart test/pushup_pipeline_test.dart`

Run: `flutter analyze`

Run: `flutter test`

Expected: no analyzer issues; all tests pass; replay baseline is step0=5 / v3=5 / v4=3.

