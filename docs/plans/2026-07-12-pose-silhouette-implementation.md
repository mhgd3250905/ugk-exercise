# Reusable Pose Silhouette Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Replace the product workout's raw MoveNet skeleton with a stable, reusable head-and-shoulder outline while leaving recognition and test-mode diagnostics unchanged.

**Architecture:** Adapt model-specific keypoints into a normalized `HeadShoulderObservation`. Feed that value into a pure `PoseSilhouetteTracker` that owns confidence hysteresis and smoothing, then render its geometry with a Flutter-only overlay. The workout page wires the modules together; test mode continues using `OverlayRenderer`.

**Tech Stack:** Dart 3 records/classes, Flutter `CustomPainter`, `flutter_test`, existing MoveNet `KeyPoint` model.

---

### Task 1: Generic tracker data model and state machine

**Files:**
- Create: `lib/ui/pose_feedback/pose_silhouette_tracker.dart`
- Create: `test/pose_silhouette_tracker_test.dart`

**Step 1: Write failing tests**

Cover one behavior per test:

```dart
test('stays hidden until observations are stable for 150ms', () {});
test('smooths small valid movement', () {});
test('holds the last geometry during a short dropout', () {});
test('hides after a continuous 300ms dropout', () {});
test('requires stable observations before reappearing', () {});
test('reset removes the previous session geometry', () {});
```

Use normalized points and explicit `DateTime` values. Do not use timers or frame counts.

**Step 2: Verify RED**

Run:

```powershell
flutter test test/pose_silhouette_tracker_test.dart
```

Expected: FAIL because the tracker types do not exist.

**Step 3: Implement the minimum tracker**

Define:

```dart
class NormalizedPosePoint {
  const NormalizedPosePoint(this.x, this.y);
  final double x;
  final double y;
}

class HeadShoulderObservation {
  const HeadShoulderObservation({
    required this.at,
    required this.head,
    required this.headConfidence,
    required this.leftShoulder,
    required this.leftShoulderConfidence,
    required this.rightShoulder,
    required this.rightShoulderConfidence,
  });
}

class PoseSilhouetteGeometry {
  const PoseSilhouetteGeometry({
    required this.head,
    required this.leftShoulder,
    required this.rightShoulder,
  });
}

class PoseSilhouetteTracker {
  PoseSilhouetteGeometry? update(HeadShoulderObservation observation);
  void reset();
}
```

Keep calibrated constants together: confidence threshold, 150ms appearance delay, 300ms disappearance delay, smoothing time constant, and large-movement catch-up ratio. Do not add a public configuration system.

**Step 4: Verify GREEN**

Run the tracker test file and confirm all tests pass.

### Task 2: MoveNet adapter

**Files:**
- Create: `lib/ui/pose_feedback/movenet_pose_adapter.dart`
- Create: `test/movenet_pose_adapter_test.dart`

**Step 1: Write failing tests**

Verify that the adapter:

- maps face points and shoulders from the current 17-point order;
- normalizes coordinates by source width and height;
- returns an invalid observation when source dimensions or keypoints are insufficient;
- does not contain exercise-specific rules.

**Step 2: Verify RED**

Run the adapter test and confirm the missing API failure.

**Step 3: Implement the adapter**

Expose one function:

```dart
HeadShoulderObservation moveNetHeadShoulderObservation({
  required List<KeyPoint> keypoints,
  required Size sourceSize,
  required DateTime at,
});
```

Prefer the nose for the head center when reliable; otherwise use the available face cluster. Keep all MoveNet index knowledge in this file.

**Step 4: Verify GREEN**

Run the adapter and tracker tests together.

### Task 3: Flutter silhouette overlay

**Files:**
- Create: `lib/ui/pose_feedback/pose_silhouette_overlay.dart`
- Create: `test/pose_silhouette_overlay_test.dart`

**Step 1: Write failing Widget tests**

Build the widget with explicit observations and verify:

- no painted geometry before the 150ms stability threshold;
- a `PoseSilhouettePainter` receives geometry after stability;
- invalid observations retain geometry below 300ms and remove it after 300ms;
- replacing the widget after camera/session reset starts hidden.

**Step 2: Verify RED**

Run the overlay Widget test and confirm it fails because the widget does not exist.

**Step 3: Implement the minimum overlay**

Create a stateful `PoseSilhouetteOverlay` that owns a tracker and accepts only `HeadShoulderObservation`. Draw:

- a head ellipse;
- two rounded neck-to-shoulder curves;
- a restrained translucent brand-green stroke and subtle glow;
- no fill, points, labels, arms, or torso.

Convert normalized geometry to canvas coordinates only inside the painter.

**Step 4: Verify GREEN**

Run the overlay Widget test and keep the painter free of model/exercise imports.

### Task 4: Product workout integration

**Files:**
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `lib/ui/overlay_renderer.dart`
- Modify: `test/workout_page_test.dart`
- Modify: `test/architecture_contract_test.dart`

**Step 1: Write failing integration tests**

Assert that:

- `WorkoutPage` contains the reusable pose silhouette overlay;
- product workout disables raw skeleton drawing;
- the alignment guide remains available while not ready;
- `test_mode_page.dart` still uses the raw `OverlayRenderer` default.

**Step 2: Verify RED**

Run the workout and architecture test files. Confirm failures describe the missing product integration.

**Step 3: Implement the minimum wiring**

- Convert controller keypoints through the MoveNet adapter.
- Render `PoseSilhouetteOverlay` only while the camera preview is active.
- Add a default-true `showSkeleton` flag to `OverlayRenderer`; pass false only from the product workout so the existing guide can remain.
- Let widget removal during camera switching/stopping dispose and reset the visual tracker.
- Do not modify `WorkoutController`, `ReadyGate`, `PushupPipeline`, or domain counting code.

**Step 4: Verify GREEN**

Run all four relevant test files.

### Task 5: Full verification and device acceptance

**Step 1: Format and inspect**

```powershell
dart format lib/ui/pose_feedback test/pose_silhouette_tracker_test.dart test/movenet_pose_adapter_test.dart test/pose_silhouette_overlay_test.dart
git diff --check
```

**Step 2: Run project checks**

```powershell
flutter analyze
flutter test
```

Expected: no issues, all tests pass, replay baselines remain 5/5/3.

**Step 3: Build the correctly configured Debug APK**

Follow `docs/testing-release-playbook.md` section 4.1 and use the local `--dart-define-from-file` configuration. Never install an unconfigured Debug APK on the login/member acceptance device.

**Step 4: True-device smoke test**

Confirm:

- raw green/red points and amber lines are absent from the product workout;
- the head/shoulder outline appears only after stable recognition;
- normal keypoint jitter is visibly damped;
- short dropouts do not blink;
- sustained loss hides the outline;
- real movement still tracks without excessive lag;
- test mode retains the raw debug skeleton;
- Camera/TFLite logs contain no errors.
