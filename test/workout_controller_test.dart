import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/config/resource_constants.dart';
import 'package:ugk_exercise/control/camera_calibration.dart';
import 'package:ugk_exercise/control/workout_controller.dart';
import 'package:ugk_exercise/inference/pose_estimator.dart';
import 'package:ugk_exercise/pipeline/frame_pipeline.dart';
import 'package:ugk_exercise/platform/camera_service.dart';
import 'package:ugk_exercise/platform/recognition_trace_log.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/product/narrow_pushup_form_gate.dart';
import 'package:ugk_exercise/product/pushup_pipeline.dart';
import 'package:ugk_exercise/product/ready_pose_gate.dart';
import 'package:ugk_exercise/product/voice_prompt_player.dart';
import 'package:ugk_exercise/product/wrist_anchor.dart';
import 'package:ugk_exercise/pushup_domain.dart';

const _frontCamera = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);
const _backCamera = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 0,
);

void main() {
  testWidgets('narrow form must stay matched through ready stability', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final readyGate = _TwoFrameReadyPoseGate();
    dependencies.pose
      ..queuePose(_narrowPose(wide: true))
      ..queuePose(_narrowPose())
      ..queuePose(_narrowPose());
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      readyGate: readyGate,
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.status, WorkoutStatus.narrowForm);
    expect(controller.ready, isFalse);

    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.ready, isFalse);

    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.ready, isTrue);
  });

  testWidgets('continuous wide form keeps narrow guidance visible', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final readyGate = _TwoFrameReadyPoseGate();
    dependencies.pose
      ..queuePose(_narrowPose(wide: true))
      ..queuePose(_narrowPose(wide: true))
      ..queuePose(_narrowPose(wide: true));
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      readyGate: readyGate,
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    for (var frame = 0; frame < 3; frame++) {
      dependencies.camera.addImage(_testImage());
      await tester.pump();
      expect(controller.status, WorkoutStatus.narrowForm);
      expect(controller.ready, isFalse);
    }
    expect(readyGate.updateCalls, 0);
  });

  testWidgets('narrow workout refuses ready when top form is wide', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      narrowFormGate: const _FixedNarrowFormGate(
        NarrowPushupFormStatus.doesNotMatch,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    expect(controller.ready, isFalse);
    expect(controller.status, WorkoutStatus.narrowForm);
    expect(dependencies.voice.narrowFormCalls, 1);
  });

  testWidgets('an unresolved pose does not raise the narrow-form prompt', (
    tester,
  ) async {
    // Before the subject is in frame the gate reports `unknown` (low-confidence
    // keypoints). That must not be read as "arms too wide": no narrow-form
    // status, no voice, so the guide can play undisturbed.
    final dependencies = _Dependencies();
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      narrowFormGate: const _FixedNarrowFormGate(
        NarrowPushupFormStatus.unknown,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    expect(controller.status, isNot(WorkoutStatus.narrowForm));
    expect(dependencies.voice.narrowFormCalls, 0);
  });

  testWidgets('narrow workout enters ready when top form matches', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      narrowFormGate: const _FixedNarrowFormGate(
        NarrowPushupFormStatus.matches,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    expect(controller.ready, isTrue);
  });

  testWidgets('standard workout ignores the narrow-only form gate', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController(
      narrowFormGate: const _FixedNarrowFormGate(
        NarrowPushupFormStatus.doesNotMatch,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    expect(controller.ready, isTrue);
  });

  testWidgets('ready is blocked when the subject is too close', (tester) async {
    final pipeline = _TooCloseCountingPipeline(
      PushupPipeline.tooCloseGroundSpanPx + 1,
    );
    final dependencies = _Dependencies();
    final controller = dependencies.createController(pipeline: pipeline);
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    // Too-close guard blocks ready, surfaces the step-back status, and must not
    // play the ready prompt.
    expect(controller.status, WorkoutStatus.tooClose);
    expect(controller.ready, isFalse);
    expect(dependencies.voice.readyCalls, 0);
  });

  testWidgets('ready proceeds when the subject is at a safe distance', (
    tester,
  ) async {
    final pipeline = _TooCloseCountingPipeline(
      PushupPipeline.tooCloseGroundSpanPx,
    );
    final dependencies = _Dependencies();
    final controller = dependencies.createController(pipeline: pipeline);
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    // Span equal to the threshold is allowed (guard is strictly greater-than).
    expect(controller.status, WorkoutStatus.readyToStart);
    expect(controller.ready, isTrue);
    expect(dependencies.voice.readyCalls, 1);
  });

  testWidgets(
    'too-close re-ready after a lost pose keeps the accumulated count',
    (tester) async {
      // Start at a safe distance so the first ready succeeds and a rep is
      // counted; then lose the pose (which preserves the count), and finally
      // re-ready while too close. The block must keep the prior count and must
      // not start training.
      final pipeline = _TooCloseCountingPipeline(
        PushupPipeline.tooCloseGroundSpanPx,
      );
      final dependencies = _Dependencies();
      final controller = dependencies.createController(pipeline: pipeline);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      await _countOneFrame(controller, dependencies.camera, tester);
      expect(controller.count, 1);
      expect(controller.ready, isTrue);

      // Lose the pose long enough to exit ready into reacquiring, keeping count.
      // _maxLostPoseFrames is 15 in the controller; drive that many lost frames.
      for (var frame = 0; frame < 15; frame++) {
        dependencies.pose.queuePose(_lostPose());
        dependencies.camera.addImage(_testImage());
        await tester.pump();
      }
      expect(controller.status, WorkoutStatus.reacquiringPose);
      expect(controller.count, 1);

      // Re-ready while now too close: flip the reported span above threshold.
      pipeline.span = PushupPipeline.tooCloseGroundSpanPx + 1;
      dependencies.pose.queuePose(_visiblePose());
      dependencies.camera.addImage(_testImage());
      await tester.pump();

      expect(controller.status, WorkoutStatus.tooClose);
      expect(controller.ready, isFalse);
      // The count earned before the block must survive.
      expect(controller.count, 1);
      // resetTracking must have been told to preserve the accumulated count.
      expect(pipeline.resetTrackingCounts.last, 1);
    },
  );

  testWidgets('too-close latch holds steady while the user stays too close', (
    tester,
  ) async {
    // Regression guard for the tooClose <-> holdPose flicker: once latched,
    // successive ready frames that are still too close must keep reporting
    // tooClose without re-emitting the trace event every frame.
    final pipeline = _TooCloseCountingPipeline(
      PushupPipeline.tooCloseGroundSpanPx + 1,
    );
    final trace = _RecordingRecognitionTraceLog();
    final dependencies = _Dependencies();
    final controller = dependencies.createController(
      pipeline: pipeline,
      trace: trace,
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.status, WorkoutStatus.tooClose);
    expect(dependencies.voice.tooCloseCalls, 1);

    // Drive several more frames still too close.
    for (var frame = 0; frame < 4; frame++) {
      dependencies.camera.addImage(_testImage());
      await tester.pump();
    }
    expect(controller.status, WorkoutStatus.tooClose);
    // The ready_too_close transition should be logged exactly once (leading
    // edge), not once per frame.
    final tooCloseEvents = trace.records
        .where((e) => e['event'] == 'ready_too_close')
        .length;
    expect(tooCloseEvents, 1);
    // The voice prompt likewise fires once on entry, not once per frame.
    expect(dependencies.voice.tooCloseCalls, 1);
  });

  testWidgets('motion maps narrow form verdicts to completion decisions', (
    tester,
  ) async {
    for (final testCase in [
      (NarrowPushupFormStatus.matches, RepCompletionDecision.allow),
      (NarrowPushupFormStatus.doesNotMatch, RepCompletionDecision.reject),
      (NarrowPushupFormStatus.unknown, RepCompletionDecision.wait),
    ]) {
      final dependencies = _Dependencies();
      final formGate = _SequenceNarrowFormGate([
        NarrowPushupFormStatus.matches,
        testCase.$1,
      ]);
      final controller = dependencies.createController(
        exerciseType: ExerciseType.narrowPushup,
        narrowFormGate: formGate,
      );
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      dependencies.camera.addImage(_testImage());
      await tester.pump();
      dependencies.camera.addImage(_testImage());
      await tester.pump();

      expect(dependencies.pipeline.decisions, [testCase.$2]);
    }
  });

  testWidgets('standard motion always allows without evaluating narrow form', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final formGate = _SequenceNarrowFormGate([
      NarrowPushupFormStatus.doesNotMatch,
    ]);
    final controller = dependencies.createController(narrowFormGate: formGate);
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    dependencies.camera.addImage(_testImage());
    await tester.pump();

    expect(formGate.callCount, 0);
    expect(dependencies.pipeline.decisions, [RepCompletionDecision.allow]);
  });

  testWidgets('narrow trace records type verdict and normalized scalars', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final trace = _RecordingRecognitionTraceLog();
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      trace: trace,
      narrowFormGate: const _FixedNarrowFormGate(
        NarrowPushupFormStatus.matches,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    await _pumpUntilComplete(controller.stop(), tester);

    final readyEvent = trace.records.singleWhere(
      (record) => record['event'] == 'ready_enter',
    );
    final motionFrame = trace.records.lastWhere(
      (record) => record['type'] == 'frame',
    );
    for (final record in [readyEvent, motionFrame]) {
      expect(record['exerciseType'], 'narrow_pushup');
      expect(record['narrowForm'], {
        'status': 'matches',
        'wristSpanRatio': 0.75,
        'elbowSpanRatio': 0.9,
        'forearmDirectionDeltaDegrees': 8.0,
      });
      expect(record.keys, isNot(contains('image')));
      expect(record.keys, isNot(contains('video')));
      expect(record.keys, isNot(contains('audio')));
    }
  });

  testWidgets('configured voice directory reaches the default player', (
    tester,
  ) async {
    final controller = WorkoutController(
      voiceBaseDir: englishVoicePromptBaseDir,
      camera: _FakeCameraService(),
      pose: _FakePoseEstimator(),
      pipeline: _CountingPipeline(),
      calibration: CameraCalibration(),
      readyGate: _ImmediateReadyPoseGate(),
      wristAnchor: _StableWristAnchor(),
      trace: RecognitionTraceLog(enabled: false),
    );
    addTearDown(() async {
      controller.dispose();
      await tester.pump();
    });

    expect(controller.debugVoiceBaseDir, englishVoicePromptBaseDir);
  });

  testWidgets('injected voice player keeps priority over the directory', (
    tester,
  ) async {
    final voice = _FakeVoicePromptPlayer(baseDir: chineseVoicePromptBaseDir);
    final controller = WorkoutController(
      voiceBaseDir: englishVoicePromptBaseDir,
      voice: voice,
      camera: _FakeCameraService(),
      pose: _FakePoseEstimator(),
      trace: RecognitionTraceLog(enabled: false),
    );
    addTearDown(() async {
      controller.dispose();
      await tester.pump();
    });

    expect(controller.debugVoiceBaseDir, chineseVoicePromptBaseDir);
  });

  testWidgets(
    'lost pose interrupts training, keeps count, and requires ready again',
    (tester) async {
      final dependencies = _Dependencies();
      final readyGate = _SequenceReadyPoseGate([true, false, true]);
      final controller = dependencies.createController(readyGate: readyGate);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      await _countOneFrame(controller, dependencies.camera, tester);
      expect(controller.count, 1);
      expect(dependencies.voice.readyCalls, 1);

      for (var frame = 0; frame < 14; frame++) {
        dependencies.pose.queuePose(_lostPose());
        dependencies.camera.addImage(_testImage());
        await tester.pump();
      }
      expect(controller.ready, isTrue);
      expect(controller.count, 1);
      expect(dependencies.voice.poseLostCalls, 0);

      dependencies.pose.queuePose(_lostPose());
      dependencies.camera.addImage(_testImage());
      await tester.pump();

      expect(controller.ready, isFalse);
      expect(controller.status, WorkoutStatus.reacquiringPose);
      expect(controller.count, 1);
      expect(dependencies.pipeline.resetTrackingCounts.last, 1);
      expect(dependencies.voice.poseLostCalls, 1);

      dependencies.pose.queuePose(_lostPose());
      dependencies.camera.addImage(_testImage());
      await tester.pump();
      expect(controller.status, WorkoutStatus.reacquiringPose);
      expect(dependencies.voice.poseLostCalls, 1);

      dependencies.pose.queuePose(_visiblePose());
      dependencies.camera.addImage(_testImage());
      await tester.pump();
      expect(controller.ready, isTrue);
      expect(controller.status, WorkoutStatus.readyToStart);
      expect(controller.count, 1);
      expect(dependencies.voice.readyCalls, 2);
    },
  );

  testWidgets('narrow mismatch cannot replace the reacquisition prompt', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final trace = _RecordingRecognitionTraceLog();
    final controller = dependencies.createController(
      exerciseType: ExerciseType.narrowPushup,
      trace: trace,
      narrowFormGate: _SequenceNarrowFormGate([
        NarrowPushupFormStatus.matches,
        NarrowPushupFormStatus.matches,
        NarrowPushupFormStatus.doesNotMatch,
        NarrowPushupFormStatus.doesNotMatch,
        NarrowPushupFormStatus.matches,
      ]),
    );
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    await _countOneFrame(controller, dependencies.camera, tester);
    for (var frame = 0; frame < 15; frame++) {
      dependencies.pose.queuePose(_lostPose());
      dependencies.camera.addImage(_testImage());
      await tester.pump();
    }
    expect(controller.status, WorkoutStatus.reacquiringPose);

    dependencies.pose.queuePose(_lostPose());
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.status, WorkoutStatus.reacquiringPose);
    expect(controller.count, 1);

    dependencies.pose.queuePose(_lostPose());
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.status, WorkoutStatus.reacquiringPose);
    expect(
      trace.records.where(
        (record) => record['event'] == 'narrow_form_not_ready',
      ),
      hasLength(lessThanOrEqualTo(1)),
    );

    dependencies.pose.queuePose(_visiblePose());
    dependencies.camera.addImage(_testImage());
    await tester.pump();
    expect(controller.ready, isTrue);
    expect(controller.status, WorkoutStatus.readyToStart);
    expect(dependencies.voice.poseLostCalls, 1);
  });

  testWidgets('repeated stop cleans resources once and preserves count', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    await _countOneFrame(controller, dependencies.camera, tester);
    expect(controller.count, 1);

    final firstStop = controller.stop();
    await _pumpUntilComplete(firstStop, tester);
    await controller.stop();

    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.pose.disposedGenerations, [1]);
    expect(dependencies.voice.stopCalls, 1);
    expect(controller.count, 1);
  });

  testWidgets('start is ignored while the same workout session is active', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    final loadGate = dependencies.pose.blockNextLoad();
    addTearDown(() async {
      if (!loadGate.isCompleted) {
        loadGate.complete();
      }
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    final firstStart = controller.start();
    await dependencies.pose.loadStarted.future;
    final repeatedStart = controller.start();
    await _pumpUntilComplete(repeatedStart, tester);
    loadGate.complete();
    await _pumpUntilComplete(firstStart, tester);

    expect(dependencies.pose.loadCalls, 1);
    expect(dependencies.camera.initializeCalls, 1);
    expect(dependencies.camera.activeGeneration, 1);
  });

  testWidgets('stop cancels a start blocked on trace setup', (tester) async {
    final dependencies = _Dependencies();
    final trace = _BlockingRecognitionTraceLog();
    final controller = dependencies.createController(trace: trace);
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final zoneErrors = <Object>[];
    addTearDown(() async {
      if (!trace.startGate.isCompleted) {
        trace.startGate.complete();
      }
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    final start = controller.start();
    await trace.startStarted.future;

    // stop() joins the shared trace-close ownership, which awaits the in-flight
    // trace initialization. Releasing the start gate lets both stop() and the
    // stale start converge and proves the trace closes exactly once.
    await runZonedGuarded<Future<void>>(() async {
      final stop = controller.stop();
      trace.startGate.complete();
      await _pumpUntilComplete(stop, tester);
      // Reset after stop()'s own saving notification; the stale start that
      // follows must not issue any further notification.
      notifications = 0;
      await _pumpUntilComplete(start, tester);
      await tester.pump();
    }, (error, _) => zoneErrors.add(error));

    expect(dependencies.pose.loadCalls, 0);
    expect(dependencies.camera.initializeCalls, 0);
    expect(trace.closeCalls, 1);
    expect(notifications, 0);
    expect(zoneErrors, isEmpty);
  });

  testWidgets(
    'dispose cancels a start blocked on trace setup and closes the trace once',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _BlockingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      final zoneErrors = <Object>[];
      addTearDown(() async {
        if (!trace.startGate.isCompleted) {
          trace.startGate.complete();
        }
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await trace.startStarted.future;
        notifications = 0;
        controller.dispose();
        trace.startGate.complete();
        await _pumpUntilComplete(start, tester);
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(dependencies.pose.loadCalls, 0);
      expect(dependencies.camera.initializeCalls, 0);
      expect(trace.closeCalls, 1);
      expect(notifications, 0);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'trace setup completion then stop closes the trace once even if close fails',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _BlockingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      trace.failNextClose(StateError('TRACE_CLOSE_TEST_SECRET'));
      final zoneErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        // Let trace setup settle on its own, then stop while start proceeds.
        trace.startGate.complete();
        await _pumpUntilComplete(start, tester);
        await _pumpUntilComplete(
          controller.stop().catchError((Object error, StackTrace _) {}),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(trace.closeCalls, 1);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'start blocked on trace setup then started normally keeps one close on stop',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _BlockingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      addTearDown(() async {
        if (!trace.startGate.isCompleted) {
          trace.startGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      // A start that blocks on trace setup, completes normally, and is later
      // stopped must still close the trace exactly once — proving the shared
      // ownership boundary survived an in-flight trace initialization.
      final start = controller.start();
      await trace.startStarted.future;
      trace.startGate.complete();
      await _pumpUntilComplete(start, tester);
      await _pumpUntilComplete(controller.stop(), tester);
      await tester.pump();

      expect(trace.closeCalls, 1);
    },
  );

  testWidgets(
    'stop and dispose release a camera published after initialization settles',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final initializeGate = dependencies.camera.blockNextInitialize(
        publishAfterInitialize: true,
      );
      var notifications = 0;
      var disposed = false;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        if (!disposed) {
          controller.dispose();
        }
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      final start = controller.start();
      await dependencies.camera.initializeStarted.future;
      final stop = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      controller.dispose();
      disposed = true;
      notifications = 0;
      initializeGate.complete();
      await _pumpUntilComplete(stop, tester);
      await _pumpUntilComplete(start, tester);

      expect(dependencies.camera.activeGeneration, isNull);
      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposeCalls, 1);
      expect(notifications, 0);
    },
  );

  testWidgets(
    'camera switch waits for startup to settle before replacing resources',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final loadGate = dependencies.pose.blockNextLoad();
      addTearDown(() async {
        if (!loadGate.isCompleted) {
          loadGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      final start = controller.start();
      await dependencies.pose.loadStarted.future;
      await _pumpUntilComplete(controller.switchCamera(_backCamera), tester);

      expect(dependencies.camera.initializeCalls, 0);
      expect(dependencies.pose.disposedGenerations, isEmpty);

      loadGate.complete();
      await _pumpUntilComplete(start, tester);
      await _countOneFrame(controller, dependencies.camera, tester);

      expect(controller.count, 1);
      expect(dependencies.camera.initializeCalls, 1);
      expect(dependencies.pose.disposedGenerations, isEmpty);

      await _pumpUntilComplete(controller.switchCamera(_backCamera), tester);

      expect(dependencies.camera.initializeCalls, 2);
      expect(dependencies.camera.activeGeneration, 2);
      expect(controller.selectedCamera, _backCamera);
      expect(dependencies.pose.disposedGenerations, isEmpty);
    },
  );

  testWidgets('start cannot replace resources while stop is cleaning up', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    final stopGate = dependencies.voice.blockNextStop();
    addTearDown(() async {
      if (!stopGate.isCompleted) {
        stopGate.complete();
      }
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    final stop = controller.stop();
    await _pumpUntil(() => dependencies.voice.stopStarted.isCompleted, tester);
    await controller.start();
    stopGate.complete();
    await _pumpUntilComplete(stop, tester);

    expect(dependencies.pose.loadCalls, 1);
    expect(dependencies.camera.initializeCalls, 1);
    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.pose.disposedGenerations, [1]);
    expect(dependencies.voice.stopCalls, 1);
    expect(controller.running, isFalse);
  });

  testWidgets('dispose takes ownership of cleanup while stop is in flight', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final trace = _RecordingRecognitionTraceLog();
    final controller = dependencies.createController(trace: trace);
    final stopGate = dependencies.voice.blockNextStop();
    var disposed = false;
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    addTearDown(() async {
      if (!stopGate.isCompleted) {
        stopGate.complete();
      }
      if (!disposed) {
        controller.dispose();
      }
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    notifications = 0;
    final stop = controller.stop();
    await _pumpUntil(() => dependencies.voice.stopStarted.isCompleted, tester);
    expect(notifications, 1);

    controller.dispose();
    disposed = true;
    await tester.pump();
    stopGate.complete();
    await _pumpUntilComplete(stop, tester);
    await tester.pump();

    expect(notifications, 1);
    expect(trace.closeCalls, 1);
    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.pose.disposedGenerations, [1]);
  });

  testWidgets(
    'dispose waits for a pending stop cancellation before releasing resources',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final cancelGate = dependencies.camera.blockNextCancel();
      var disposed = false;
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!cancelGate.isCompleted) {
          cancelGate.complete();
        }
        if (!disposed) {
          controller.dispose();
        }
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      notifications = 0;
      final stop = controller.stop();
      await _pumpUntil(
        () => dependencies.camera.cancelStarted.isCompleted,
        tester,
      );
      expect(notifications, 1);

      controller.dispose();
      disposed = true;
      await tester.pump();

      expect(dependencies.camera.disposedGenerations, isEmpty);
      expect(dependencies.pose.disposedGenerations, isEmpty);
      expect(notifications, 1);

      cancelGate.complete();
      await _pumpUntilComplete(stop, tester);
      await _pumpUntil(
        () =>
            dependencies.camera.disposedGenerations.length == 1 &&
            dependencies.pose.disposedGenerations.length == 1,
        tester,
      );

      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 1);
    },
  );

  testWidgets('stop defers voice and resource cleanup until the next frame', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    final stop = controller.stop();

    expect(dependencies.voice.stopCalls, 0);
    expect(dependencies.camera.cancelCalls, 0);
    expect(dependencies.camera.disposedGenerations, isEmpty);
    expect(dependencies.pose.disposedGenerations, isEmpty);

    await _pumpUntilComplete(stop, tester);

    expect(dependencies.voice.stopCalls, 1);
    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.pose.disposedGenerations, [1]);
  });

  testWidgets(
    'startup releases an unpublished failed camera and pose exactly once',
    (tester) async {
      final dependencies = _Dependencies();
      final failedController = _LifecycleCameraController(
        initializeError: StateError('unpublished start initialization'),
      );
      final camera = _LifecycleCameraService([failedController]);
      final controller = dependencies.createController(camera: camera);
      addTearDown(() async {
        controller.dispose();
        await tester.pump();
      });

      await _pumpUntilComplete(controller.start(), tester);

      expect(controller.status, WorkoutStatus.startupError);
      expect(failedController.disposeCalls, 1);
      expect(camera.controller, isNull);
      expect(dependencies.pose.disposedGenerations, [1]);
    },
  );

  testWidgets(
    'camera switch releases an unpublished failed generation exactly once',
    (tester) async {
      final dependencies = _Dependencies();
      final activeController = _LifecycleCameraController();
      final failedController = _LifecycleCameraController(
        initializeError: StateError('unpublished switch initialization'),
      );
      final camera = _LifecycleCameraService([
        activeController,
        failedController,
      ]);
      final controller = dependencies.createController(camera: camera);
      addTearDown(() async {
        controller.dispose();
        await tester.pump();
      });

      await controller.start();
      await _pumpUntilComplete(controller.switchCamera(_backCamera), tester);

      expect(controller.status, WorkoutStatus.cameraError);
      expect(activeController.disposeCalls, 1);
      expect(failedController.disposeCalls, 1);
      expect(camera.controller, isNull);
      expect(dependencies.pose.disposedGenerations, [1]);
    },
  );

  testWidgets(
    'stop owns unpublished camera initialization failure without stale notifications',
    (tester) async {
      final dependencies = _Dependencies();
      final failedController = _LifecycleCameraController(
        initializeError: StateError('unpublished initialization after stop'),
      );
      final camera = _LifecycleCameraService([failedController]);
      final controller = dependencies.createController(camera: camera);
      final initializeGate = failedController.blockInitialize();
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await tester.pump();
      });

      final start = controller.start();
      await failedController.initializeStarted.future;
      final stop = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      notifications = 0;
      initializeGate.complete();

      await _pumpUntilComplete(stop, tester);
      await _pumpUntilComplete(start, tester);

      expect(failedController.disposeCalls, 1);
      expect(camera.controller, isNull);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
    },
  );

  testWidgets(
    'dispose owns unpublished camera initialization failure without unhandled errors',
    (tester) async {
      final dependencies = _Dependencies();
      final failedController = _LifecycleCameraController(
        initializeError: StateError('unpublished initialization after dispose'),
      );
      final camera = _LifecycleCameraService([failedController]);
      final controller = dependencies.createController(camera: camera);
      final initializeGate = failedController.blockInitialize();
      final zoneErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await failedController.initializeStarted.future;
        controller.dispose();
        notifications = 0;
        initializeGate.complete();

        await _pumpUntilComplete(start, tester);
        await _pumpUntil(
          () =>
              failedController.disposeCalls == 1 &&
              dependencies.pose.disposeCalls == 1,
          tester,
        );
      }, (error, _) => zoneErrors.add(error));

      expect(failedController.disposeCalls, 1);
      expect(camera.controller, isNull);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'stop waits for a pose load that publishes only after it settles',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final loadGate = dependencies.pose.blockNextLoad(publishAfterLoad: true);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!loadGate.isCompleted) {
          loadGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      final start = controller.start();
      await dependencies.pose.loadStarted.future;
      final stop = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      notifications = 0;
      loadGate.complete();

      await _pumpUntilComplete(stop, tester);
      await _pumpUntilComplete(start, tester);

      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposeCalls, 1);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
    },
  );

  testWidgets(
    'dispose waits for a pose load that publishes only after it settles',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final loadGate = dependencies.pose.blockNextLoad(publishAfterLoad: true);
      final zoneErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!loadGate.isCompleted) {
          loadGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await dependencies.pose.loadStarted.future;
        controller.dispose();
        notifications = 0;
        loadGate.complete();

        await _pumpUntilComplete(start, tester);
        await _pumpUntil(() => dependencies.pose.disposeCalls == 1, tester);
      }, (error, _) => zoneErrors.add(error));

      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposeCalls, 1);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'voice stop failure still releases camera pose and trace before rethrowing',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final stopError = StateError('voice stop failed');
      dependencies.voice.failNextStop(stopError);
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      notifications = 0;
      final expectedFailure = expectLater(
        controller.stop(),
        throwsA(same(stopError)),
      );
      await _pumpUntil(
        () =>
            dependencies.camera.disposedGenerations.length == 1 &&
            dependencies.pose.disposedGenerations.length == 1 &&
            trace.closeCalls == 1,
        tester,
      );
      await expectedFailure;

      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(dependencies.voice.stopCalls, 1);
      expect(notifications, 1);
    },
  );

  testWidgets(
    'startup list failure keeps its mapping when camera cleanup also fails',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final listError = StateError('LIST_CAMERA_TEST_SECRET');
      final cleanupError = StateError('CAMERA_CLEANUP_TEST_SECRET');
      final logs = <String>[];
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      dependencies.camera
        ..failNextListCameras(listError)
        ..failNextDispose(cleanupError);
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
      addTearDown(() async {
        debugPrint = previousDebugPrint;
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        notifications = 0;
        await _pumpUntilComplete(
          start.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));
      debugPrint = previousDebugPrint;

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.startupError);
      final notificationsAtCompletion = notifications;
      await tester.pump();
      expect(notificationsAtCompletion, greaterThan(0));
      expect(notifications, notificationsAtCompletion);
      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposeCalls, 1);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
      expect(
        trace.records.singleWhere(
          (record) => record['event'] == 'startup_error',
        )['errorType'],
        'StateError',
      );
      expect(logs.join('\n'), contains('StateError'));
      expect(logs.join('\n'), isNot(contains('TEST_SECRET')));
      expect(trace.records.toString(), isNot(contains('TEST_SECRET')));
    },
  );

  testWidgets(
    'startup initialize failure keeps its mapping when pose cleanup also fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final initializeError = StateError('START_INITIALIZE_TEST_SECRET');
      final cleanupError = StateError('POSE_CLEANUP_TEST_SECRET');
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      dependencies.camera.failNextInitialize(initializeError);
      dependencies.pose.failNextDispose(cleanupError);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        notifications = 0;
        await _pumpUntilComplete(
          start.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.startupError);
      final notificationsAtCompletion = notifications;
      await tester.pump();
      expect(notificationsAtCompletion, greaterThan(0));
      expect(notifications, notificationsAtCompletion);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'camera switch failure keeps its mapping when camera cleanup also fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final initializeError = StateError('SWITCH_INITIALIZE_TEST_SECRET');
      final cleanupError = StateError('SWITCH_CLEANUP_TEST_SECRET');
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      dependencies.camera
        ..failNextInitialize(initializeError)
        ..failDisposeOnCall(2, cleanupError);
      var notifications = 0;
      controller.addListener(() => notifications += 1);

      await runZonedGuarded<Future<void>>(() async {
        final switchCamera = controller.switchCamera(_backCamera);
        notifications = 0;
        await _pumpUntilComplete(
          switchCamera.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.cameraError);
      final notificationsAtCompletion = notifications;
      await tester.pump();
      expect(notificationsAtCompletion, greaterThan(0));
      expect(notifications, notificationsAtCompletion);
      expect(dependencies.camera.disposedGenerations, [1, 2]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'voice stop failure stays primary while camera pose and trace cleanup fail',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final voiceError = StateError('VOICE_STOP_TEST_SECRET');
      dependencies.voice.failNextStop(voiceError);
      dependencies.camera.failNextDispose(
        StateError('VOICE_CAMERA_CLEANUP_TEST_SECRET'),
      );
      dependencies.pose.failNextDispose(
        StateError('VOICE_POSE_CLEANUP_TEST_SECRET'),
      );
      trace.failNextClose(StateError('VOICE_TRACE_CLEANUP_TEST_SECRET'));
      final zoneErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      await runZonedGuarded<Future<void>>(() async {
        final expectedFailure = expectLater(
          controller.stop(),
          throwsA(same(voiceError)),
        );
        await _pumpUntil(
          () =>
              dependencies.camera.disposeCalls == 1 &&
              dependencies.pose.disposeCalls == 1,
          tester,
        );
        await expectedFailure;
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(dependencies.voice.stopCalls, 1);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets('stop keeps its cleanup error while still closing trace', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final trace = _RecordingRecognitionTraceLog();
    final controller = dependencies.createController(trace: trace);
    final cleanupError = StateError('STOP_CLEANUP_TEST_SECRET');
    dependencies.camera.failNextDispose(cleanupError);
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    Object? stopError;
    final stop = controller.stop().then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        stopError = error;
      },
    );
    await _pumpUntil(
      () =>
          dependencies.camera.disposeCalls == 1 &&
          dependencies.pose.disposeCalls == 1,
      tester,
    );
    await _pumpUntilComplete(stop, tester);

    expect(controller.running, isFalse);
    expect(stopError, same(cleanupError));
    expect(trace.closeCalls, 1);
  });

  testWidgets(
    'dispose absorbs camera pose and trace cleanup failures without zone errors',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      dependencies.camera.failNextDispose(
        StateError('DISPOSE_CAMERA_CLEANUP_TEST_SECRET'),
      );
      dependencies.pose.failNextDispose(
        StateError('DISPOSE_POSE_CLEANUP_TEST_SECRET'),
      );
      trace.failNextClose(StateError('DISPOSE_TRACE_CLEANUP_TEST_SECRET'));
      final zoneErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      await runZonedGuarded<Future<void>>(() async {
        controller.dispose();
        await _pumpUntil(
          () =>
              dependencies.camera.disposeCalls == 1 &&
              dependencies.pose.disposeCalls == 1,
          tester,
        );
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets('startup failure releases the loaded pose and partial camera', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    dependencies.camera.failNextInitialize(StateError('start initialize'));
    final controller = dependencies.createController();
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await _pumpUntilComplete(controller.start(), tester);

    expect(controller.running, isFalse);
    expect(controller.status, WorkoutStatus.startupError);
    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.pose.disposedGenerations, [1]);
  });

  testWidgets('camera switch failure releases its partial camera and pose', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await controller.start();
    dependencies.camera.failNextInitialize(StateError('switch initialize'));

    await _pumpUntilComplete(controller.switchCamera(_backCamera), tester);

    expect(controller.running, isFalse);
    expect(controller.status, WorkoutStatus.cameraError);
    expect(dependencies.camera.disposedGenerations, [1, 2]);
    expect(dependencies.pose.disposedGenerations, [1]);
  });

  testWidgets('dispose absorbs a failing voice cleanup without notifications', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    final zoneErrors = <Object>[];
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    dependencies.voice.failNextDispose(StateError('voice dispose failure'));
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });

    await runZonedGuarded<Future<void>>(() async {
      controller.dispose();
      await tester.pump();
    }, (error, _) => zoneErrors.add(error));

    expect(dependencies.voice.disposeCalls, 1);
    expect(zoneErrors, isEmpty);
    expect(notifications, 0);
  });

  testWidgets(
    'stop releases startup resources when the pending camera initialization fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final initializeGate = dependencies.camera.blockNextInitialize();
      final initializeError = StateError('start initialize after stop');
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      final start = controller.start();
      await dependencies.camera.initializeStarted.future;
      final stop = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      notifications = 0;
      final stopComplete = expectLater(stop, completes);

      dependencies.camera.failNextInitialize(initializeError);
      initializeGate.complete();

      await stopComplete;
      await _pumpUntilComplete(start, tester);

      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
    },
  );

  testWidgets(
    'dispose releases startup resources when pending camera initialization fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      final initializeGate = dependencies.camera.blockNextInitialize();
      final initializeError = StateError('start initialize after dispose');
      final zoneErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await dependencies.camera.initializeStarted.future;
        controller.dispose();
        notifications = 0;
        dependencies.camera.failNextInitialize(initializeError);
        initializeGate.complete();

        await _pumpUntilComplete(start, tester);
        await _pumpUntil(
          () =>
              dependencies.camera.disposeCalls == 1 &&
              dependencies.pose.disposeCalls == 1,
          tester,
        );
      }, (error, _) => zoneErrors.add(error));

      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposeCalls, 1);
      expect(notifications, 0);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'stop releases switch resources when the pending camera initialization fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      late final Completer<void> initializeGate;
      final initializeError = StateError('switch initialize after stop');
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      initializeGate = dependencies.camera.blockNextInitialize();
      final switchCamera = controller.switchCamera(_backCamera);
      await _pumpUntil(() => dependencies.camera.initializeCalls == 2, tester);
      final stop = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      notifications = 0;
      final stopComplete = expectLater(stop, completes);

      dependencies.camera.failNextInitialize(initializeError);
      initializeGate.complete();

      await stopComplete;
      await _pumpUntilComplete(switchCamera, tester);

      expect(dependencies.camera.disposedGenerations, [1, 2]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(notifications, 0);
    },
  );

  testWidgets(
    'dispose releases switch resources when pending camera initialization fails',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      late final Completer<void> initializeGate;
      final initializeError = StateError('switch initialize after dispose');
      final zoneErrors = <Object>[];
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!initializeGate.isCompleted) {
          initializeGate.complete();
        }
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        await controller.start();
        initializeGate = dependencies.camera.blockNextInitialize();
        final switchCamera = controller.switchCamera(_backCamera);
        await _pumpUntil(
          () => dependencies.camera.initializeCalls == 2,
          tester,
        );
        controller.dispose();
        notifications = 0;
        dependencies.camera.failNextInitialize(initializeError);
        initializeGate.complete();

        await _pumpUntilComplete(switchCamera, tester);
        await _pumpUntil(
          () =>
              dependencies.camera.disposeCalls == 2 &&
              dependencies.pose.disposeCalls == 1,
          tester,
        );
      }, (error, _) => zoneErrors.add(error));

      expect(dependencies.camera.disposedGenerations, [1, 2]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(dependencies.camera.disposeCalls, 2);
      expect(dependencies.pose.disposeCalls, 1);
      expect(notifications, 0);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'stop shares a blocked camera-switch release without duplicate disposal',
    (tester) async {
      final dependencies = _Dependencies();
      final controller = dependencies.createController();
      var notifications = 0;
      var disposed = false;
      controller.addListener(() => notifications += 1);
      addTearDown(() async {
        if (!disposed) {
          controller.dispose();
        }
        await dependencies.camera.closeStreams();
        await tester.pump();
      });
      await controller.start();
      await _countOneFrame(controller, dependencies.camera, tester);
      final countBeforeSwitch = controller.count;
      final disposeGate = dependencies.camera.blockNextDispose();

      final switchFuture = controller.switchCamera(_backCamera);
      await _pumpUntil(
        () => dependencies.camera.disposeStarted.isCompleted,
        tester,
      );

      final stopFuture = controller.stop();
      await _pumpUntil(() => dependencies.voice.stopCalls == 1, tester);
      await tester.pump();

      expect(dependencies.camera.disposeCalls, 1);

      controller.dispose();
      disposed = true;
      notifications = 0;
      disposeGate.complete();
      await _pumpUntilComplete(stopFuture, tester);
      await _pumpUntilComplete(switchFuture, tester);
      await tester.pump();

      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposeCalls, 1);
      expect(controller.count, countBeforeSwitch);
      expect(controller.running, isFalse);
      expect(notifications, 0);
    },
  );

  testWidgets('repeated start cannot invalidate an in-flight camera switch', (
    tester,
  ) async {
    final dependencies = _Dependencies();
    final controller = dependencies.createController();
    addTearDown(() async {
      controller.dispose();
      await dependencies.camera.closeStreams();
      await tester.pump();
    });
    await controller.start();
    final inferGate = dependencies.pose.blockNextInfer();
    dependencies.camera.addImage(_testImage());
    await dependencies.pose.inferStarted.future;

    final switchFuture = controller.switchCamera(_backCamera);
    await _pumpUntil(() => dependencies.camera.cancelCalls == 1, tester);

    await controller.start();
    inferGate.complete(_visiblePose());
    await _pumpUntilComplete(switchFuture, tester);

    expect(dependencies.pose.loadCalls, 1);
    expect(dependencies.camera.initializeCalls, 2);
    expect(dependencies.camera.disposedGenerations, [1]);
    expect(dependencies.camera.activeGeneration, 2);
    expect(controller.running, isTrue);
    expect(controller.selectedCamera, _backCamera);
  });

  // === Trace cleanup on primary-error termination ===
  //
  // A primary startup/switch failure must terminate the session by closing the
  // trace alongside camera/pose, without leaking an unfinished `.jsonl.part`
  // or an open sink. The trace is started before camera initialization, so a
  // failure before the normal stop()/dispose() boundary previously left the
  // session open.

  testWidgets(
    'startup list failure closes the trace once while keeping its mapping',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final listError = StateError('LIST_CAMERA_TEST_SECRET');
      dependencies.camera.failNextListCameras(listError);
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await _pumpUntilComplete(
          start.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.startupError);
      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'startup initialize failure closes the trace once with camera and pose',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      dependencies.camera.failNextInitialize(
        StateError('START_INITIALIZE_TEST_SECRET'),
      );
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await _pumpUntilComplete(controller.start(), tester);
      await tester.pump();

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.startupError);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
    },
  );

  testWidgets(
    'switch camera release failure closes the trace once when terminating',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      // The first camera generation is released during the switch and its
      // dispose is forced to fail, terminating the session.
      dependencies.camera.failDisposeOnCall(
        1,
        StateError('SWITCH_RELEASE_TEST_SECRET'),
      );
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];

      await runZonedGuarded<Future<void>>(() async {
        final switchCamera = controller.switchCamera(_backCamera);
        await _pumpUntilComplete(
          switchCamera.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.cameraError);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'switch camera initialize failure closes the trace once when terminating',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      dependencies.camera.failNextInitialize(
        StateError('SWITCH_INITIALIZE_TEST_SECRET'),
      );

      await _pumpUntilComplete(
        controller
            .switchCamera(_backCamera)
            .catchError((Object error, StackTrace _) {}),
        tester,
      );
      await tester.pump();

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.cameraError);
      expect(dependencies.camera.disposedGenerations, [1, 2]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
    },
  );

  testWidgets(
    'startup failure keeps primary error while trace cleanup also fails',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final listError = StateError('LIST_CAMERA_TEST_SECRET');
      dependencies.camera
        ..failNextListCameras(listError)
        ..failNextDispose(StateError('CAMERA_CLEANUP_TEST_SECRET'));
      dependencies.pose.failNextDispose(StateError('POSE_CLEANUP_TEST_SECRET'));
      trace.failNextClose(StateError('TRACE_CLEANUP_TEST_SECRET'));
      final logs = <String>[];
      final zoneErrors = <Object>[];
      final futureErrors = <Object>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
      addTearDown(() async {
        debugPrint = previousDebugPrint;
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await runZonedGuarded<Future<void>>(() async {
        final start = controller.start();
        await _pumpUntilComplete(
          start.catchError((Object error, StackTrace _) {
            futureErrors.add(error);
          }),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));
      debugPrint = previousDebugPrint;

      expect(controller.running, isFalse);
      expect(controller.status, WorkoutStatus.startupError);
      expect(dependencies.camera.disposeCalls, 1);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
      expect(futureErrors, isEmpty);
      expect(zoneErrors, isEmpty);
      expect(logs.join('\n'), contains('StateError'));
      expect(logs.join('\n'), isNot(contains('TEST_SECRET')));
      expect(trace.records.toString(), isNot(contains('TEST_SECRET')));
    },
  );

  testWidgets(
    'subsequent stop and dispose do not re-close the trace after a failure',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      dependencies.camera.failNextListCameras(StateError('start list'));
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await _pumpUntilComplete(
        controller.start().catchError((Object error, StackTrace _) {}),
        tester,
      );
      await tester.pump();
      // The session has already terminated; stop()/dispose() must not re-enter
      // trace cleanup or raise an unhandled Future / stale notify.
      final zoneErrors = <Object>[];
      await runZonedGuarded<Future<void>>(() async {
        controller.dispose();
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(trace.closeCalls, 1);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'stop closes the trace once even when cleanup errors come from camera pose and trace',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      dependencies.camera.failNextDispose(
        StateError('STOP_CAMERA_CLEANUP_TEST_SECRET'),
      );
      dependencies.pose.failNextDispose(
        StateError('STOP_POSE_CLEANUP_TEST_SECRET'),
      );
      trace.failNextClose(StateError('STOP_TRACE_CLEANUP_TEST_SECRET'));
      final zoneErrors = <Object>[];
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      await runZonedGuarded<Future<void>>(() async {
        await _pumpUntilComplete(
          controller.stop().catchError((Object error, StackTrace _) {}),
          tester,
        );
        await tester.pump();
      }, (error, _) => zoneErrors.add(error));

      expect(controller.running, isFalse);
      expect(dependencies.camera.disposedGenerations, [1]);
      expect(dependencies.pose.disposedGenerations, [1]);
      expect(trace.closeCalls, 1);
      expect(zoneErrors, isEmpty);
    },
  );

  testWidgets(
    'stop surfaces the first cleanup error while still attempting trace close',
    (tester) async {
      final dependencies = _Dependencies();
      final trace = _RecordingRecognitionTraceLog();
      final controller = dependencies.createController(trace: trace);
      final cleanupError = StateError('STOP_CAMERA_CLEANUP_FIRST_SECRET');
      dependencies.camera.failNextDispose(cleanupError);
      trace.failNextClose(StateError('STOP_TRACE_CLEANUP_SECOND_SECRET'));
      addTearDown(() async {
        controller.dispose();
        await dependencies.camera.closeStreams();
        await tester.pump();
      });

      await controller.start();
      Object? stopError;
      final stop = controller.stop().then<void>(
        (_) {},
        onError: (Object error, StackTrace _) {
          stopError = error;
        },
      );
      await _pumpUntil(
        () =>
            dependencies.camera.disposeCalls == 1 &&
            dependencies.pose.disposeCalls == 1,
        tester,
      );
      await _pumpUntilComplete(stop, tester);

      expect(controller.running, isFalse);
      expect(stopError, same(cleanupError));
      expect(trace.closeCalls, 1);
    },
  );
}

Future<void> _pumpUntilComplete(
  Future<void> future,
  WidgetTester tester,
) async {
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  future.then(
    (_) => completed = true,
    onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      completed = true;
    },
  );
  await _pumpUntil(() => completed, tester);
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
}

Future<void> _pumpUntil(bool Function() condition, WidgetTester tester) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(condition(), isTrue, reason: 'asynchronous operation did not finish');
}

Future<void> _countOneFrame(
  WorkoutController controller,
  _FakeCameraService camera,
  WidgetTester tester,
) async {
  camera.addImage(_testImage());
  await tester.pump();
  expect(controller.ready, isTrue);
  camera.addImage(_testImage());
  await tester.pump();
}

CameraImage _testImage() {
  // The camera package keeps this compatibility constructor specifically for
  // tests and legacy channels; using it avoids a direct transitive import.
  // ignore: deprecated_member_use
  return CameraImage.fromPlatformData({
    'format': 35,
    'height': 2,
    'width': 2,
    'planes': [
      {
        'bytes': Uint8List.fromList([128, 128, 128, 128]),
        'bytesPerPixel': 1,
        'bytesPerRow': 2,
      },
      {
        'bytes': Uint8List.fromList([128]),
        'bytesPerPixel': 1,
        'bytesPerRow': 1,
      },
      {
        'bytes': Uint8List.fromList([128]),
        'bytesPerPixel': 1,
        'bytesPerRow': 1,
      },
    ],
  });
}

List<KeyPoint> _visiblePose() {
  return [
    for (var index = 0; index < 17; index++)
      KeyPoint(
        index: index,
        x: 1,
        y: switch (index) {
          SignalExtractor.nose => 0.2,
          SignalExtractor.leftShoulder || SignalExtractor.rightShoulder => 0.5,
          SignalExtractor.leftWrist || SignalExtractor.rightWrist => 1.5,
          _ => 1,
        },
        confidence: 1,
      ),
  ];
}

List<KeyPoint> _lostPose() {
  final points = _visiblePose();
  points[SignalExtractor.leftShoulder] = const KeyPoint(
    index: SignalExtractor.leftShoulder,
    x: 1,
    y: 0.5,
    confidence: 0,
  );
  points[SignalExtractor.rightShoulder] = const KeyPoint(
    index: SignalExtractor.rightShoulder,
    x: 1,
    y: 0.5,
    confidence: 0,
  );
  return points;
}

List<KeyPoint> _narrowPose({bool wide = false}) {
  final points = [
    for (var index = 0; index < 17; index++)
      KeyPoint(index: index, x: 1, y: 1, confidence: 1),
  ];
  points[SignalExtractor.nose] = const KeyPoint(
    index: SignalExtractor.nose,
    x: 1,
    y: 0.2,
    confidence: 1,
  );
  points[SignalExtractor.leftShoulder] = const KeyPoint(
    index: SignalExtractor.leftShoulder,
    x: 0.4,
    y: 0.5,
    confidence: 1,
  );
  points[SignalExtractor.rightShoulder] = const KeyPoint(
    index: SignalExtractor.rightShoulder,
    x: 1.6,
    y: 0.5,
    confidence: 1,
  );
  points[SignalExtractor.leftHip] = const KeyPoint(
    index: SignalExtractor.leftHip,
    x: 0.8,
    y: 1,
    confidence: 1,
  );
  points[SignalExtractor.rightHip] = const KeyPoint(
    index: SignalExtractor.rightHip,
    x: 1.2,
    y: 1,
    confidence: 1,
  );
  points[SignalExtractor.leftElbow] = KeyPoint(
    index: SignalExtractor.leftElbow,
    x: wide ? 0.1 : 0.6,
    y: 1.1,
    confidence: 1,
  );
  points[SignalExtractor.rightElbow] = KeyPoint(
    index: SignalExtractor.rightElbow,
    x: wide ? 1.9 : 1.4,
    y: 1.1,
    confidence: 1,
  );
  points[SignalExtractor.leftWrist] = KeyPoint(
    index: SignalExtractor.leftWrist,
    x: wide ? 0 : 0.7,
    y: 1.5,
    confidence: 1,
  );
  points[SignalExtractor.rightWrist] = KeyPoint(
    index: SignalExtractor.rightWrist,
    x: wide ? 2 : 1.3,
    y: 1.5,
    confidence: 1,
  );
  return points;
}

class _Dependencies {
  final camera = _FakeCameraService();
  final pose = _FakePoseEstimator();
  final pipeline = _CountingPipeline();
  final readyGate = _ImmediateReadyPoseGate();
  final wristAnchor = _StableWristAnchor();
  final voice = _FakeVoicePromptPlayer();

  WorkoutController createController({
    ExerciseType exerciseType = ExerciseType.pushup,
    CameraService? camera,
    PoseEstimator? pose,
    PushupPipeline? pipeline,
    NarrowPushupFormGate narrowFormGate = const NarrowPushupFormGate(),
    ReadyPoseGate? readyGate,
    RecognitionTraceLog? trace,
  }) {
    return WorkoutController(
      exerciseType: exerciseType,
      camera: camera ?? this.camera,
      pose: pose ?? this.pose,
      pipeline: pipeline ?? this.pipeline,
      calibration: CameraCalibration(),
      readyGate: readyGate ?? this.readyGate,
      wristAnchor: wristAnchor,
      voice: voice,
      trace: trace ?? RecognitionTraceLog(enabled: false),
      narrowFormGate: narrowFormGate,
    );
  }
}

class _FakeCameraService extends CameraService {
  final disposedGenerations = <int>[];
  final disposeStarted = Completer<void>();
  final cancelStarted = Completer<void>();
  final initializeStarted = Completer<void>();
  final _streams = <_FakeCameraStream>[];
  var cancelCalls = 0;
  var disposeCalls = 0;
  var initializeCalls = 0;

  CameraDescription? _description;
  _FakeCameraStream? _images;
  Completer<void>? _cancelGate;
  Completer<void>? _disposeGate;
  Completer<void>? _initializeGate;
  Object? _listCamerasError;
  Object? _initializeError;
  Object? _disposeError;
  final _disposeErrorsByCall = <int, Object>{};
  var _publishAfterInitialize = false;
  var _nextGeneration = 0;
  int? activeGeneration;

  @override
  Future<List<CameraDescription>> listCameras() async {
    final error = _listCamerasError;
    _listCamerasError = null;
    if (error != null) {
      throw error;
    }
    return const [_frontCamera, _backCamera];
  }

  @override
  Future<void> initialize({
    CameraDescription? camera,
    CameraLensDirection facing = CameraLensDirection.front,
  }) async {
    initializeCalls += 1;
    _description = camera ?? _frontCamera;
    final generation = ++_nextGeneration;
    final images = _FakeCameraStream(onCancel: _cancelImages);
    final publishAfterInitialize = _publishAfterInitialize;
    _publishAfterInitialize = false;
    if (!publishAfterInitialize) {
      _publishInitializedCamera(generation, images);
    }
    if (!initializeStarted.isCompleted) {
      initializeStarted.complete();
    }
    final initializeGate = _initializeGate;
    _initializeGate = null;
    await initializeGate?.future;
    final error = _initializeError;
    _initializeError = null;
    if (error != null) {
      throw error;
    }
    if (publishAfterInitialize) {
      _publishInitializedCamera(generation, images);
    }
  }

  @override
  Stream<CameraImage> get imageStream => _images!;

  @override
  CameraDescription? get description => _description;

  @override
  int get sensorOrientation => _description?.sensorOrientation ?? 0;

  @override
  bool get isFrontFacing =>
      _description?.lensDirection == CameraLensDirection.front;

  void addImage(CameraImage image) => _images!.add(image);

  Completer<void> blockNextDispose() {
    return _disposeGate = Completer<void>();
  }

  Completer<void> blockNextInitialize({bool publishAfterInitialize = false}) {
    _publishAfterInitialize = publishAfterInitialize;
    return _initializeGate = Completer<void>();
  }

  Completer<void> blockNextCancel() {
    return _cancelGate = Completer<void>();
  }

  void failNextInitialize(Object error) {
    _initializeError = error;
  }

  void failNextListCameras(Object error) {
    _listCamerasError = error;
  }

  void failNextDispose(Object error) {
    _disposeError = error;
  }

  void failDisposeOnCall(int disposeCall, Object error) {
    _disposeErrorsByCall[disposeCall] = error;
  }

  Future<void> _cancelImages() async {
    cancelCalls += 1;
    if (!cancelStarted.isCompleted) {
      cancelStarted.complete();
    }
    final gate = _cancelGate;
    _cancelGate = null;
    await gate?.future;
  }

  void _publishInitializedCamera(int generation, _FakeCameraStream images) {
    activeGeneration = generation;
    _images = images;
    _streams.add(images);
  }

  Future<void> closeStreams() async {
    for (final stream in _streams) {
      stream.close();
    }
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    final generation = activeGeneration;
    if (generation != null) {
      activeGeneration = null;
      disposedGenerations.add(generation);
    }
    if (!disposeStarted.isCompleted) {
      disposeStarted.complete();
    }
    await _disposeGate?.future;
    final error = _disposeErrorsByCall.remove(disposeCalls) ?? _disposeError;
    _disposeError = null;
    if (error != null) {
      throw error;
    }
  }
}

class _LifecycleCameraService extends CameraService {
  _LifecycleCameraService(this.controllers)
    : super(controllerFactory: (description) => controllers.removeAt(0));

  final List<_LifecycleCameraController> controllers;
  late final _FakeCameraStream _images = _FakeCameraStream(
    onCancel: () async {},
  );

  @override
  Future<List<CameraDescription>> listCameras() async => const [
    _frontCamera,
    _backCamera,
  ];

  @override
  Stream<CameraImage> get imageStream => _images;
}

class _LifecycleCameraController extends CameraController {
  _LifecycleCameraController({this.initializeError})
    : super(
        _frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

  final Object? initializeError;
  final initializeStarted = Completer<void>();
  Completer<void>? _initializeGate;
  var disposeCalls = 0;

  @override
  Future<void> initialize() async {
    if (!initializeStarted.isCompleted) {
      initializeStarted.complete();
    }
    final gate = _initializeGate;
    _initializeGate = null;
    await gate?.future;
    final error = initializeError;
    if (error != null) {
      throw error;
    }
  }

  Completer<void> blockInitialize() {
    return _initializeGate = Completer<void>();
  }

  @override
  Future<void> startImageStream(onLatestImageAvailable onAvailable) async {}

  @override
  Future<void> stopImageStream() async {}

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await super.dispose();
  }
}

class _FakeCameraStream extends Stream<CameraImage> {
  _FakeCameraStream({required this.onCancel});

  final Future<void> Function() onCancel;
  _FakeCameraSubscription? _subscription;

  @override
  StreamSubscription<CameraImage> listen(
    void Function(CameraImage event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _subscription = _FakeCameraSubscription(
      onData: onData,
      onDone: onDone,
      onCancel: onCancel,
    );
  }

  void add(CameraImage image) => _subscription?.add(image);

  void close() => _subscription?.close();
}

class _FakeCameraSubscription implements StreamSubscription<CameraImage> {
  _FakeCameraSubscription({
    required void Function(CameraImage event)? onData,
    required void Function()? onDone,
    required this.onCancel,
  }) : _onData = onData,
       _onDone = onDone;

  final Future<void> Function() onCancel;
  void Function(CameraImage event)? _onData;
  void Function()? _onDone;
  var _canceled = false;
  var _paused = false;

  void add(CameraImage image) {
    if (!_canceled && !_paused) {
      _onData?.call(image);
    }
  }

  void close() {
    if (!_canceled) {
      _canceled = true;
      _onDone?.call();
    }
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;

  @override
  Future<void> cancel() async {
    if (!_canceled) {
      _canceled = true;
      await onCancel();
    }
  }

  @override
  bool get isPaused => _paused;

  @override
  void onData(void Function(CameraImage data)? handleData) {
    _onData = handleData;
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {
    _paused = true;
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    _paused = false;
  }
}

class _FakePoseEstimator extends PoseEstimator {
  final disposedGenerations = <int>[];
  final loadStarted = Completer<void>();
  final inferStarted = Completer<void>();
  var loadCalls = 0;
  var disposeCalls = 0;
  var _nextGeneration = 0;
  int? _activeGeneration;
  Completer<void>? _loadGate;
  Object? _disposeError;
  var _publishAfterLoad = false;
  Completer<List<KeyPoint>>? _inferGate;
  final _queuedPoses = <List<KeyPoint>>[];

  @override
  int get target => 2;

  @override
  FramePipeline get pipeline =>
      const FramePipeline(inputType: InputTensorType.uint8);

  @override
  Future<void> load({
    required String assetPath,
    DelegateMode mode = DelegateMode.cpu,
  }) async {
    loadCalls += 1;
    final generation = ++_nextGeneration;
    final publishAfterLoad = _publishAfterLoad;
    _publishAfterLoad = false;
    if (!publishAfterLoad) {
      _activeGeneration = generation;
    }
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }
    final gate = _loadGate;
    _loadGate = null;
    await gate?.future;
    if (publishAfterLoad) {
      _activeGeneration = generation;
    }
  }

  Completer<void> blockNextLoad({bool publishAfterLoad = false}) {
    _publishAfterLoad = publishAfterLoad;
    return _loadGate = Completer<void>();
  }

  void failNextDispose(Object error) {
    _disposeError = error;
  }

  @override
  Future<List<KeyPoint>> infer(TensorInput input) async {
    if (!inferStarted.isCompleted) {
      inferStarted.complete();
    }
    final gate = _inferGate;
    _inferGate = null;
    if (gate != null) {
      return gate.future;
    }
    if (_queuedPoses.isNotEmpty) {
      return _queuedPoses.removeAt(0);
    }
    return _visiblePose();
  }

  void queuePose(List<KeyPoint> pose) => _queuedPoses.add(pose);

  Completer<List<KeyPoint>> blockNextInfer() {
    return _inferGate = Completer<List<KeyPoint>>();
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    final generation = _activeGeneration;
    if (generation == null) {
      return;
    }
    _activeGeneration = null;
    disposedGenerations.add(generation);
    final error = _disposeError;
    _disposeError = null;
    if (error != null) {
      throw error;
    }
  }
}

class _CountingPipeline extends PushupPipeline {
  final decisions = <RepCompletionDecision>[];
  final resetTrackingCounts = <int?>[];

  @override
  void resetTracking({int? count}) {
    resetTrackingCounts.add(count);
    super.resetTracking(count: count);
  }

  @override
  bool calibrateReadyDepth(
    List<KeyPoint> keypoints, {
    double sourceHeight = PushupPipeline.referenceSourceHeight,
  }) => true;

  @override
  CounterState process(
    List<KeyPoint> keypoints, {
    bool handsStable = true,
    double sourceHeight = PushupPipeline.referenceSourceHeight,
    RepCompletionDecision repCompletionDecision = RepCompletionDecision.allow,
  }) {
    decisions.add(repCompletionDecision);
    return const CounterState(
      count: 1,
      phase: Phase.up,
      frozen: false,
      calibrated: true,
    );
  }
}

/// Pipeline variant that reports a ready ground span exceeding the too-close
/// threshold, so the controller's too-close guard can be exercised. Calibration
/// succeeds (returns true) and the span getter reports the configured value.
/// The span is mutable so a test can drive a safe-distance ready+count first,
/// then flip to too-close to exercise the block while preserving the count.
class _TooCloseCountingPipeline extends _CountingPipeline {
  _TooCloseCountingPipeline([this.span]);

  double? span;

  @override
  double? get readyGroundSpan => span;
}

class _FixedNarrowFormGate extends NarrowPushupFormGate {
  const _FixedNarrowFormGate(this.status);

  final NarrowPushupFormStatus status;

  @override
  NarrowPushupFormResult evaluate(List<KeyPoint> keypoints) {
    return NarrowPushupFormResult(
      status: status,
      wristSpanRatio: 0.75,
      elbowSpanRatio: 0.9,
      forearmDirectionDeltaDegrees: 8,
    );
  }
}

class _SequenceNarrowFormGate extends NarrowPushupFormGate {
  _SequenceNarrowFormGate(this.statuses);

  final List<NarrowPushupFormStatus> statuses;
  var callCount = 0;

  @override
  NarrowPushupFormResult evaluate(List<KeyPoint> keypoints) {
    final index = callCount < statuses.length ? callCount : statuses.length - 1;
    callCount += 1;
    return NarrowPushupFormResult(status: statuses[index]);
  }
}

class _TwoFrameReadyPoseGate extends ReadyPoseGate {
  var updateCalls = 0;
  var _consecutiveUpdates = 0;

  @override
  bool update({
    required List<KeyPoint> keypoints,
    required double frameWidth,
    required double frameHeight,
    required DateTime at,
  }) {
    updateCalls += 1;
    _consecutiveUpdates += 1;
    return _consecutiveUpdates >= 2;
  }

  @override
  void reset() {
    _consecutiveUpdates = 0;
  }
}

class _ImmediateReadyPoseGate extends ReadyPoseGate {
  @override
  bool update({
    required List<KeyPoint> keypoints,
    required double frameWidth,
    required double frameHeight,
    required DateTime at,
  }) => true;
}

class _SequenceReadyPoseGate extends ReadyPoseGate {
  _SequenceReadyPoseGate(this.results);

  final List<bool> results;
  var _index = 0;

  @override
  bool update({
    required List<KeyPoint> keypoints,
    required double frameWidth,
    required double frameHeight,
    required DateTime at,
  }) {
    final result = results[_index.clamp(0, results.length - 1)];
    _index += 1;
    return result;
  }
}

class _StableWristAnchor extends WristAnchor {
  @override
  bool get isCalibrated => true;

  @override
  bool isStable(
    List<KeyPoint> keypoints, {
    double sourceHeight = SignalExtractor.referenceFrameHeight,
  }) => true;
}

class _FakeVoicePromptPlayer extends VoicePromptPort {
  _FakeVoicePromptPlayer({super.baseDir});

  final stopStarted = Completer<void>();
  var stopCalls = 0;
  var disposeCalls = 0;
  var readyCalls = 0;
  var poseLostCalls = 0;
  var tooCloseCalls = 0;
  var narrowFormCalls = 0;
  Completer<void>? _stopGate;
  Object? _stopError;
  Object? _disposeError;

  @override
  Future<void> preloadCounts() async {}

  @override
  Future<void> playGuide() async {}

  @override
  Future<void> playReady() async {
    readyCalls++;
  }

  @override
  Future<void> playPoseLost() async {
    poseLostCalls++;
  }

  @override
  Future<void> playTooClose() async {
    tooCloseCalls++;
  }

  @override
  Future<void> playNarrowForm() async {
    narrowFormCalls++;
  }

  @override
  Future<void> playCount(int count) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    if (!stopStarted.isCompleted) {
      stopStarted.complete();
    }
    final gate = _stopGate;
    _stopGate = null;
    await gate?.future;
    final error = _stopError;
    _stopError = null;
    if (error != null) {
      throw error;
    }
  }

  Completer<void> blockNextStop() {
    return _stopGate = Completer<void>();
  }

  void failNextStop(Object error) {
    _stopError = error;
  }

  void failNextDispose(Object error) {
    _disposeError = error;
  }

  @override
  Future<void> dispose() {
    disposeCalls++;
    final error = _disposeError;
    _disposeError = null;
    if (error != null) {
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }
}

class _RecordingRecognitionTraceLog extends RecognitionTraceLog {
  _RecordingRecognitionTraceLog();

  final records = <Map<String, Object?>>[];
  var closeCalls = 0;
  Object? _closeError;

  @override
  Future<void> startSession(DateTime startedAt) async {}

  @override
  void write(Map<String, Object?> record) {
    records.add(Map<String, Object?>.of(record));
  }

  @override
  Future<void> close() async {
    closeCalls += 1;
    final error = _closeError;
    _closeError = null;
    if (error != null) {
      throw error;
    }
  }

  void failNextClose(Object error) {
    _closeError = error;
  }
}

class _BlockingRecognitionTraceLog extends _RecordingRecognitionTraceLog {
  final startStarted = Completer<void>();
  final startGate = Completer<void>();

  @override
  Future<void> startSession(DateTime startedAt) async {
    startStarted.complete();
    await startGate.future;
  }
}
