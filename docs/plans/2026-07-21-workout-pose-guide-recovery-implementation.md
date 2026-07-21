# Workout Pose Guide Recovery Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** Add exercise-specific static pose guides and a persistent lost-pose reacquisition flow that preserves completed reps and prepares a future voice asset contract.

**Architecture:** Keep recognition thresholds and counting in the existing product/domain layers. `WorkoutController` owns the reacquisition flag and one-shot voice event; a dedicated UI-only pose-guide widget owns asset selection and bounded camera-stage layout; `WorkoutPage` switches between the fixed target and the existing live silhouette based on `ready`.

**Tech Stack:** Flutter 3.44.7, Dart, Material 3, ARB/gen-l10n, `audioplayers`, Flutter unit/widget tests.

---

### Task 1: Lock the static pose-guide resource contract

**Files:**

- Create: `test/workout_pose_guide_test.dart`
- Create: `lib/ui/pose_feedback/workout_pose_guide.dart`
- Use: `assets/images/workout_pose_guide_standard.png`
- Use: `assets/images/workout_pose_guide_narrow.png`

**Step 1: Write one failing test**

Pump `WorkoutPoseGuide` for `ExerciseType.pushup` and assert that its `Image` uses `assets/images/workout_pose_guide_standard.png`, the image is excluded from semantics, and the visible layer uses the agreed semi-transparent opacity.

**Step 2: Run the failing test**

```powershell
flutter test test/workout_pose_guide_test.dart --plain-name "standard workout uses the compact standard pose asset"
```

Expected: FAIL because the widget does not exist.

**Step 3: Implement the minimal widget**

Create `WorkoutPoseGuide`, map the two `ExerciseType` values to explicit asset paths, wrap the image in `IgnorePointer` and `ExcludeSemantics`, and use a keyed opacity layer.

**Step 4: Run the test and expect PASS**

Run the same command.

**Step 5: Add one layout test at a time**

Verify a `567×790` parent and a `500×400` parent produce a guide frame that:

- never exceeds the parent;
- keeps a width/height ratio near `1.15`;
- uses at most 62% of portrait height and 82% of landscape height;
- remains horizontally centered.

Run each test after writing it, implement only the required `LayoutBuilder` sizing, then rerun the whole file.

### Task 2: Add the lost-pose voice event safely

**Files:**

- Modify: `test/voice_prompt_player_test.dart`
- Modify: `lib/product/voice_prompt_player.dart`
- Modify: `tool/tts/pushup_prompts.srt`
- Modify: `docs/modules/voice-themes.md`

**Step 1: Write the failing player test**

Call `playPoseLost()` with the existing fake audio player and expect the latest played asset to be `audio/prompts/pose_lost.wav` at 1.0× speed.

**Step 2: Run and confirm RED**

```powershell
flutter test test/voice_prompt_player_test.dart --plain-name "pose loss uses the reserved prompt asset"
```

Expected: FAIL because `playPoseLost` is undefined.

**Step 3: Implement the minimal event**

Add `playPoseLost()` using the same replacement policy as guide/ready/count. Catch a missing-asset playback failure inside this method because the user will supply the WAV later; do not let it break recognition or later playback.

**Step 4: Run and expect GREEN**

Run the focused player test and then the full player test file.

**Step 5: Record exact copy**

Append the Chinese cue `姿势已中断，请按剪影重新准备。` to the SRT source and record both Chinese and English (`Pose lost. Match the guide and get ready again.`) plus `pose_lost.wav` in the voice-theme contract. Do not add placeholder WAV files.

### Task 3: Make lost-pose reacquisition persistent and count-preserving

**Files:**

- Modify: `test/workout_controller_test.dart`
- Modify: `lib/control/workout_controller.dart`

**Step 1: Write the first failing Controller test**

Drive the fake camera through ready and one counted frame, then send 14 frames with materially lost shoulder confidence. Assert `ready` remains true, count remains 1, and no pose-loss voice event fires.

**Step 2: Run and confirm the existing debounce behavior**

```powershell
flutter test test/workout_controller_test.dart --plain-name "lost pose waits for the full debounce window"
```

If this passes immediately, retain it as a characterization test and continue to the new behavior slice.

**Step 3: Write the failing threshold test**

Send the 15th lost frame and assert:

- `ready == false`;
- `count == 1`;
- status is the new `WorkoutStatus.reacquiringPose`;
- `resetTracking(count: 1)` was called;
- `playPoseLost()` was called exactly once.

Expected: FAIL on the new status and voice event.

**Step 4: Implement the minimal Controller state**

Rename the old lost-only `fullPose` status to `reacquiringPose`. Add `_reacquiringPose`, set it only at the 15-frame transition, keep it true while standard/narrow ready gates are retried, and clear it only after successful depth calibration, new-session initialization, or camera switching. Preserve all existing session guards and `resetTracking(count: _count)`.

**Step 5: Prove recovery**

Add one test that supplies a valid pose after the loss and asserts ready re-enters, count remains 1, status becomes `readyToStart`, ready voice fires, and a second loss episode can produce exactly one new pose-loss event.

Run each focused test, then the complete Controller test file.

### Task 4: Switch the camera overlay by readiness

**Files:**

- Modify: `test/workout_page_test.dart`
- Modify: `test/architecture_contract_test.dart`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`

**Step 1: Write the failing localization test**

Update the exhaustive `WorkoutStatus` map to expect:

- Chinese: `姿势已中断，请按剪影重新准备。`
- English: `Pose lost. Match the guide and get ready again.`

Run the specific status test and confirm it fails before ARB/code changes.

**Step 2: Add and generate l10n**

Replace the old full-pose key with `workoutStatusReacquiringPose`, update initial setup wording to refer to the silhouette, then run:

```powershell
flutter gen-l10n
```

Rerun the localization test.

**Step 3: Write the overlay contract test**

Require `WorkoutPage` to render `WorkoutPoseGuide` while preview is active and `ready` is false, and the existing `PoseSilhouetteOverlay` only while `ready` is true. Keep `OverlayRenderer` exclusive to test mode.

**Step 4: Implement the minimal page switch**

Import the new widget. In the camera stack, use a single readiness branch so the fixed and live silhouettes are never simultaneously visible. Keep the bottom gradient, camera controls, coach bar, count panel, and stop/save lifecycle unchanged.

**Step 5: Run UI tests**

```powershell
flutter test test/workout_pose_guide_test.dart test/workout_page_test.dart test/architecture_contract_test.dart
```

Expected: all PASS with no overflow.

### Task 5: Update authoritative behavior documentation

**Files:**

- Modify: `docs/modules/recognition.md`
- Modify: `docs/modules/workout-controller.md`
- Modify: `docs/design/app-ui-v1.md`

**Step 1: Update only affected sections**

Document the fixed target versus live silhouette split, persistent reacquisition status, one-shot future audio contract, preserved count, unchanged 15-frame threshold, and true-device validation requirement.

**Step 2: Check documentation and generated files**

```powershell
git diff --check
```

Expected: no whitespace errors.

### Task 6: Verify the complete change

**Step 1: Format changed Dart files**

```powershell
dart format lib/control/workout_controller.dart lib/product/voice_prompt_player.dart lib/ui/pages/workout_page.dart lib/ui/pose_feedback/workout_pose_guide.dart test/workout_controller_test.dart test/voice_prompt_player_test.dart test/workout_page_test.dart test/workout_pose_guide_test.dart test/architecture_contract_test.dart
```

**Step 2: Run focused recognition regression**

```powershell
flutter test test/workout_controller_test.dart test/pushup_session_replay_test.dart test/domain_self_check_test.dart
```

Expected: PASS and replay counts remain step0=5, v3=5, v4=3.

**Step 3: Run project gates**

```powershell
flutter analyze
flutter test
git diff --check
```

Expected: zero analyze issues and all tests green.

**Step 4: Record the real-device boundary**

Automated tests cannot prove camera crop, real-person alignment, MoveNet reacquisition, or audible `pose_lost.wav` because the WAV is intentionally pending. Record those as explicit true-device follow-ups rather than claiming completion.

### Task 7: Independent review loop

After implementation and local gates pass, start the user-requested independent review thread. It must make no edits and must report findings under exactly six headings: requirements completeness, logic correctness, edge cases, code quality, test coverage, and actual runtime results. Apply its concrete fix list in the main thread, rerun relevant gates, and ask the same reviewer to recheck. Repeat until it reports no blocking findings or an external blocker is explicit.

