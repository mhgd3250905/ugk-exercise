# Ready-relative Pushup Depth Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Require live pushups to descend at least 50% of the ready-pose head/shoulder-to-wrist screen height before the existing counter may enter its down phase.

**Architecture:** `PushupPipeline` calibrates the ready-pose scale from normalized keypoints and passes a minimum down Y into `PushupCounter`. The counter keeps its existing median, percentile, return and elbow logic; the new value only adds a condition to the armed-to-down transition. `WorkoutController` calibrates immediately after each successful ready transition and logs the calibration/progress in Debug traces.

**Tech Stack:** Dart, Flutter, package:test, existing PushupPipeline/PushupCounter.

---

### Task 1: Specify the relative-depth behavior

**Files:**
- Modify: `test/pushup_pipeline_test.dart`
- Modify: `test/pushup_session_replay_test.dart`

1. Add a pipeline test that calibrates a ready pose, replays a 45% down/up adjustment, and expects count `0`.
2. In the same calibrated pipeline, replay a deeper-than-50% down/up cycle with arms invisible and expect count `1`.
3. Add equivalent near/far keypoint scales and assert that equal proportions produce equal counts.
4. Run `flutter test test/pushup_pipeline_test.dart test/pushup_session_replay_test.dart`; expect failure because calibration does not exist yet.

### Task 2: Add the minimum down gate

**Files:**
- Modify: `lib/pushup_domain.dart`
- Modify: `lib/product/pushup_pipeline.dart`

1. Add `readyDepthRatio = 0.5` to `CounterConfig`.
2. Add optional `minDownY` to `PushupCounter.update` and require `y >= minDownY` when the armed counter enters down; keep null as the existing replay fallback.
3. Add `PushupPipeline.calibrateReadyDepth(...)` that normalizes coordinates, extracts `readyTopY`, validates each wrist independently, chooses the larger top-to-wrist span, and stores the required down Y.
4. Clear calibration in `reset` and `resetTracking`; expose read-only calibration/progress values for diagnostics.
5. Run the two focused test files; expect all green.

### Task 3: Wire live ready calibration and traces

**Files:**
- Modify: `lib/control/workout_controller.dart`
- Modify: `test/architecture_contract_test.dart`

1. After ready succeeds, reset tracking and calibrate depth before setting the live ready state.
2. If calibration fails, reset the ready gate and keep waiting instead of counting without a scale.
3. Add calibration values to `ready_enter` and relative depth to frame JSONL records.
4. Update the architecture source contract to require live calibration.
5. Run `flutter test test/architecture_contract_test.dart`; expect green.

### Task 4: Update algorithm documentation and verify

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/modules/pushup-pipeline.md`
- Modify: `docs/modules/workout-controller.md`

1. Document the ready-relative 50% down gate and its lifecycle.
2. Run `dart format` on changed Dart files.
3. Run `flutter analyze`; expect no issues.
4. Run `flutter test`; expect all tests green and replay counts step0=5 / v3=5 / v4=3.
5. Run `git diff --check`; expect no output.
6. Explicitly stage only the implementation files and commit.
