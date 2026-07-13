# Ready-Pose Wrist-Hip Gate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reject stable kneeling/upright poses whose hands hang near the hips before ready, without changing any post-ready counting behavior.

**Architecture:** Add one scale-relative, per-side wrist-to-hip condition inside `ReadyPoseGate.isPoseVisible`. Reuse the shoulder, hip, and wrist points already required by the gate; keep the condition out of `motionPoseUsable`, `WristAnchor`, `PushupPipeline`, and `PushupCounter`.

**Tech Stack:** Dart, Flutter test, existing `ReadyPoseGate` and `KeyPoint` model.

---

### Task 1: Specify the rejected and accepted ready poses

**Files:**
- Modify: `test/ready_pose_gate_test.dart`

**Step 1: Add a failing hanging-hands regression test**

Add a test that feeds a stable pose with shoulders at `420`, hips at `540`, and both wrists at `557`. The wrists remain well below the shoulders, but their wrist-to-hip ratio is about `0.14`; two updates more than 500ms apart must still return `false`.

**Step 2: Add a failing invalid-torso test**

Add a test with `hipY == shoulderY` and wrists below both. It must return `false`, preventing a zero or negative shoulder-to-hip denominator from passing trivially.

**Step 3: Extend only the existing test helper**

Add optional `hipY` to `_pose`. Update the existing 720px support-margin fixture to use a hip position below the shoulder but above its wrist, so the fixture remains a valid support pose under the new ready contract.

**Step 4: Run the focused test and verify RED**

Run:

```powershell
flutter test test/ready_pose_gate_test.dart
```

Expected: the two new regression tests fail because the current gate only checks wrists below shoulders; the pre-existing tests remain green.

### Task 2: Add the minimum ready-only gate

**Files:**
- Modify: `lib/product/ready_pose_gate.dart`

**Step 1: Add the calibration knob**

Add `minWristBelowHipRatio = 0.3` to the existing constructor and as a final field.

**Step 2: Implement the per-side check in `isPoseVisible`**

After the existing confidence checks, evaluate each side independently:

```dart
bool wristIsBelowHip(int shoulderIndex, int hipIndex, int wristIndex) {
  final shoulder = keypoints[shoulderIndex];
  final hip = keypoints[hipIndex];
  final wrist = keypoints[wristIndex];
  final torsoHeight = hip.y - shoulder.y;
  return torsoHeight > 0 &&
      wrist.y - hip.y >= minWristBelowHipRatio * torsoHeight;
}
```

Require both sides with `&&`, then retain the existing `wristsBelowShoulders` check. Do not average wrists and do not modify post-ready code.

**Step 3: Run the focused test and verify GREEN**

Run:

```powershell
flutter test test/ready_pose_gate_test.dart
```

Expected: all ready-gate tests pass.

**Step 4: Run the session-chain regression**

Run:

```powershell
flutter test test/pushup_session_replay_test.dart test/pushup_pipeline_test.dart
```

Expected: strict ready, arms-offscreen counting, fast counting, and the 50% relative-depth behavior remain green.

### Task 3: Document and verify the completed behavior

**Files:**
- Modify: `docs/modules/ready-pose-gate.md`
- Modify: `docs/modules/recognition.md`

**Step 1: Update module documentation**

Document the ready-only `0.3` same-side wrist/hip ratio, the positive torso-height guard, and the explicit boundary that post-ready motion/counting is unchanged.

**Step 2: Format and statically analyze**

Run:

```powershell
dart format lib/product/ready_pose_gate.dart test/ready_pose_gate_test.dart
flutter analyze
```

Expected: no formatting changes remain and analyzer reports no issues.

**Step 3: Run the full suite**

Run:

```powershell
flutter test
```

Expected: all tests pass; replay counts remain step0=5, v3=5, v4=3.

**Step 4: Check the diff and commit only owned files**

Run `git diff --check`, review the diff, explicitly stage only the plan, ready-gate implementation, tests, and two module documents, then commit. Do not stage `lib/l10n/app_localizations.dart`.
