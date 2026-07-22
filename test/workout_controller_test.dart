import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
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

  testWidgets('stop during camera switch cleans the camera resource once', (
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
    final countBeforeSwitch = controller.count;
    final disposeGate = dependencies.camera.blockNextDispose();

    final switchFuture = controller.switchCamera(_backCamera);
    await _pumpUntil(
      () => dependencies.camera.disposeStarted.isCompleted,
      tester,
    );

    final stopFuture = controller.stop();
    await _pumpUntilComplete(stopFuture, tester);
    disposeGate.complete();
    await _pumpUntilComplete(switchFuture, tester);

    expect(dependencies.camera.disposedGenerations, [1]);
    expect(controller.count, countBeforeSwitch);
    expect(controller.running, isFalse);
  });

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
    NarrowPushupFormGate narrowFormGate = const NarrowPushupFormGate(),
    ReadyPoseGate? readyGate,
    RecognitionTraceLog? trace,
  }) {
    return WorkoutController(
      exerciseType: exerciseType,
      camera: camera,
      pose: pose,
      pipeline: pipeline,
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
  final _streams = <_FakeCameraStream>[];
  var cancelCalls = 0;
  var initializeCalls = 0;

  CameraDescription? _description;
  _FakeCameraStream? _images;
  Completer<void>? _disposeGate;
  var _nextGeneration = 0;
  int? activeGeneration;

  @override
  Future<List<CameraDescription>> listCameras() async => const [
    _frontCamera,
    _backCamera,
  ];

  @override
  Future<void> initialize({
    CameraDescription? camera,
    CameraLensDirection facing = CameraLensDirection.front,
  }) async {
    initializeCalls += 1;
    _description = camera ?? _frontCamera;
    activeGeneration = ++_nextGeneration;
    _images = _FakeCameraStream(onCancel: () => cancelCalls++);
    _streams.add(_images!);
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

  Future<void> closeStreams() async {
    for (final stream in _streams) {
      stream.close();
    }
  }

  @override
  Future<void> dispose() async {
    final generation = activeGeneration;
    if (generation == null) {
      return;
    }
    activeGeneration = null;
    disposedGenerations.add(generation);
    if (!disposeStarted.isCompleted) {
      disposeStarted.complete();
    }
    await _disposeGate?.future;
  }
}

class _FakeCameraStream extends Stream<CameraImage> {
  _FakeCameraStream({required this.onCancel});

  final void Function() onCancel;
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

  final void Function() onCancel;
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
      onCancel();
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
  var _nextGeneration = 0;
  int? _activeGeneration;
  Completer<void>? _loadGate;
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
    _activeGeneration = ++_nextGeneration;
    if (!loadStarted.isCompleted) {
      loadStarted.complete();
    }
    final gate = _loadGate;
    _loadGate = null;
    await gate?.future;
  }

  Completer<void> blockNextLoad() {
    return _loadGate = Completer<void>();
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
    final generation = _activeGeneration;
    if (generation == null) {
      return;
    }
    _activeGeneration = null;
    disposedGenerations.add(generation);
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

class _FakeVoicePromptPlayer extends VoicePromptPlayer {
  _FakeVoicePromptPlayer({super.baseDir});

  final stopStarted = Completer<void>();
  var stopCalls = 0;
  var readyCalls = 0;
  var poseLostCalls = 0;
  Completer<void>? _stopGate;

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
  }

  Completer<void> blockNextStop() {
    return _stopGate = Completer<void>();
  }

  @override
  Future<void> dispose() async {}
}

class _RecordingRecognitionTraceLog extends RecognitionTraceLog {
  _RecordingRecognitionTraceLog();

  final records = <Map<String, Object?>>[];
  var closeCalls = 0;

  @override
  Future<void> startSession(DateTime startedAt) async {}

  @override
  void write(Map<String, Object?> record) {
    records.add(Map<String, Object?>.of(record));
  }

  @override
  Future<void> close() async {
    closeCalls += 1;
  }
}
