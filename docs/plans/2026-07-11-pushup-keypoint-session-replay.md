# Pushup Keypoint Session Replay Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Exercise the real strict-ready and close-range motion rules through a pure Dart keypoint sequence instead of testing only scalar Counter input.

**Architecture:** Extract the existing motion-pose predicate from `WorkoutController` into one pure product function. A test-only session harness will compose `ReadyPoseGate`, `WristAnchor`, the predicate, and `PushupPipeline`; no new production session abstraction is added.

**Tech Stack:** Dart, Flutter test, existing product/domain components.

---

### Task 1: Create the end-to-end keypoint replay test

**Files:**
- Create: `test/pushup_session_replay_test.dart`
- Create: `lib/product/motion_pose_gate.dart`
- Modify: `lib/control/workout_controller.dart`

**Step 1: Write the failing test**

Feed two full-body support frames 500ms apart to `ReadyPoseGate`, calibrate `WristAnchor`, then feed an up/down/up keypoint sequence whose elbow and wrist confidences are low during motion. Use the production motion predicate before each `PushupPipeline.process` call. Expect ready to become true and final count to equal 1.

Add focused assertions that the predicate accepts missing arms but rejects a confidently visible raised wrist.

**Step 2: Verify RED**

Run: `flutter test test/pushup_session_replay_test.dart`

Expected: compile failure because the pure motion predicate does not exist yet.

**Step 3: Implement the minimum production seam**

Move `_coreTorsoVisible` unchanged into `lib/product/motion_pose_gate.dart` as a pure function. Replace the Controller private method call and delete the private method. Do not change thresholds or lost-pose timing.

**Step 4: Verify GREEN**

Run: `flutter test test/pushup_session_replay_test.dart test/domain_self_check_test.dart test/pushup_pipeline_test.dart test/ready_pose_gate_test.dart`

Expected: close-range keypoint replay counts 1; visible raised wrist is rejected; existing 5/5/3 remains unchanged.

### Task 2: Document and verify

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/modules/workout-controller.md`

Document the pure motion predicate and keypoint replay coverage. Run `flutter analyze`, `flutter test`, and `git diff --check`, then commit this P1 checkpoint separately from P0.

