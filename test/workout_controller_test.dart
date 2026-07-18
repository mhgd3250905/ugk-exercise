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

  testWidgets('stale switch cannot dispose the new session camera', (
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

    final staleSwitch = controller.switchCamera(_backCamera);
    await _pumpUntil(() => dependencies.camera.cancelCalls == 1, tester);

    await controller.start();
    expect(dependencies.camera.activeGeneration, 2);
    final currentStatus = controller.status;

    await _pumpUntilComplete(staleSwitch, tester);
    inferGate.complete(_visiblePose());
    await tester.pump();

    expect(controller.running, isTrue);
    expect(controller.status, currentStatus);
    expect(controller.selectedCamera, _frontCamera);
    // The session guard stops the stale switch after the old frame pipeline
    // becomes idle, before it can dispose generation 2 from the new session.
    expect(dependencies.camera.disposedGenerations, isEmpty);
    expect(dependencies.camera.activeGeneration, 2);
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

class _Dependencies {
  final camera = _FakeCameraService();
  final pose = _FakePoseEstimator();
  final pipeline = _CountingPipeline();
  final readyGate = _ImmediateReadyPoseGate();
  final wristAnchor = _StableWristAnchor();
  final voice = _FakeVoicePromptPlayer();

  WorkoutController createController() {
    return WorkoutController(
      camera: camera,
      pose: pose,
      pipeline: pipeline,
      calibration: CameraCalibration(),
      readyGate: readyGate,
      wristAnchor: wristAnchor,
      voice: voice,
      trace: RecognitionTraceLog(enabled: false),
    );
  }
}

class _FakeCameraService extends CameraService {
  final disposedGenerations = <int>[];
  final disposeStarted = Completer<void>();
  final _streams = <_FakeCameraStream>[];
  var cancelCalls = 0;

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
  final inferStarted = Completer<void>();
  var _nextGeneration = 0;
  int? _activeGeneration;
  Completer<List<KeyPoint>>? _inferGate;

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
    _activeGeneration = ++_nextGeneration;
  }

  @override
  Future<List<KeyPoint>> infer(TensorInput input) async {
    if (!inferStarted.isCompleted) {
      inferStarted.complete();
    }
    final gate = _inferGate;
    _inferGate = null;
    return gate == null ? _visiblePose() : gate.future;
  }

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
  }) => const CounterState(
    count: 1,
    phase: Phase.up,
    frozen: false,
    calibrated: true,
  );
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

  var stopCalls = 0;

  @override
  Future<void> preloadCounts() async {}

  @override
  Future<void> playGuide() async {}

  @override
  Future<void> playReady() async {}

  @override
  Future<void> playCount(int count) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}
