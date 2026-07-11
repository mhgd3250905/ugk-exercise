// Orchestration extracted from the workout page's god-state during
// architecture refactor step 4. This controller owns the camera/pose/pipeline
// lifecycle and exposes read-only state to the UI layer, which only renders and
// handles navigation/storage. The orchestration logic is moved here verbatim
// from `_WorkoutPageState`; the only changes are `setState` -> `notifyListeners`
// and removal of `mounted` guards (replaced by a `_disposed` flag).

import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../inference/pose_estimator.dart';
import '../pipeline/frame_pipeline.dart';
import '../pipeline/yuv420.dart';
import '../product/ready_pose_gate.dart';
import '../product/pushup_pipeline.dart';
import '../product/voice_prompt_player.dart';
import '../product/wrist_anchor.dart';
import '../pushup_domain.dart';
import '../platform/camera_service.dart';
import 'camera_calibration.dart';

/// The model asset loaded by [PoseEstimator]. Kept here so the controller has
/// no dependency on the UI theme module.
const _modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';

/// Orchestrates the live pushup workout: camera lifecycle, pose inference
/// scheduling (with a session token to guard against races), the
/// ready/count/wrist-anchor state machine, and voice prompts.
///
/// The controller does NOT touch [BuildContext], [Navigator], or persistent
/// storage. Stopping a workout only halts the hardware; the owning widget
/// decides whether to persist and pop.
class WorkoutController extends ChangeNotifier {
  WorkoutController();

  static const _maxLostPoseFrames = 15;

  final _camera = CameraService();
  final _pose = PoseEstimator();
  final _pipeline = PushupPipeline();
  final _calibration = CameraCalibration();
  final _readyGate = ReadyPoseGate();
  final _wristAnchor = WristAnchor();
  final _voice = VoicePromptPlayer();

  StreamSubscription<CameraImage>? _subscription;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  DateTime? _startedAt;
  var _session = 0;
  var _running = false;
  var _stopping = false;
  var _switchingCamera = false;
  var _busy = false;
  var _ready = false;
  var _lostPoseFrames = 0;
  var _count = 0;
  var _status = '加载中';
  // Last frame's handsStable, to log only on transitions (not every frame).
  var _lastStable = true;

  bool _disposed = false;

  // === Read-only state exposed to the UI ===

  int get count => _count;
  bool get ready => _ready;
  String get status => _status;
  bool get stopping => _stopping;
  bool get switchingCamera => _switchingCamera;
  bool get running => _running;
  CameraDescription? get selectedCamera => _selectedCamera;
  List<CameraDescription> get cameras => _cameras;
  List<KeyPoint> get keypoints => _keypoints;
  Size get sourceSize => _sourceSize;
  DateTime? get startedAt => _startedAt;
  CameraService get camera => _camera;

  // === UI commands ===

  Future<void> start() async {
    final session = ++_session;
    debugPrint('UGK session: start #$session');
    _startedAt = DateTime.now();
    _running = true;
    _stopping = false;
    _switchingCamera = false;
    _busy = false;
    _ready = false;
    _lostPoseFrames = 0;
    _count = 0;
    _pipeline.reset();
    _readyGate.reset();
    _wristAnchor.reset();
    _keypoints = const [];
    _sourceSize = Size.zero;
    _status = '加载模型';
    _notify();
    try {
      await _pose.load(assetPath: _modelPath, mode: DelegateMode.nnapi);
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      _status = '启动相机';
      _notify();
      final cameras = await _camera.listCameras();
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      await _camera.initialize(camera: _selectedOrDefaultCamera(cameras));
      if (session != _session) {
        await _camera.dispose();
        await _pose.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      unawaited(_voice.playGuide());
      _cameras = cameras;
      _selectedCamera = _camera.description;
      _status = '请按提示摆放手机并保持姿势';
      _notify();
    } catch (error) {
      if (session != _session) {
        return;
      }
      _running = false;
      _stopping = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      _status = '错误：$error';
      _notify();
    }
  }

  Future<void> switchCamera(CameraDescription camera) async {
    if (!_running || _switchingCamera || _sameCamera(camera, _selectedCamera)) {
      return;
    }
    final session = ++_session;
    debugPrint('UGK session: switch-camera #$session keep count=$_count');
    _switchingCamera = true;
    _ready = false;
    _readyGate.reset();
    _wristAnchor.reset();
    _pipeline.resetTracking(count: _count);
    _keypoints = const [];
    _sourceSize = Size.zero;
    _status = '切换相机';
    _notify();
    await SchedulerBinding.instance.endOfFrame;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _waitForFramePipelineToIdle();
      await _camera.dispose();
      if (session != _session) {
        return;
      }
      await _camera.initialize(camera: camera);
      if (session != _session) {
        await _camera.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      _selectedCamera = _camera.description;
      _switchingCamera = false;
      _status = '请按提示摆放手机并保持姿势';
      _notify();
    } catch (error) {
      if (session != _session) {
        return;
      }
      _running = false;
      _switchingCamera = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      _status = '相机错误：$error';
      _notify();
    }
  }

  /// Stops camera/pose/voice. Does NOT persist the session or navigate; the
  /// owning widget reads [count]/[startedAt] and does that itself after this
  /// returns.
  Future<void> stop() async {
    if (!_running || _stopping) {
      return;
    }
    _stopping = true;
    _session++;
    debugPrint('UGK session: stop, saving count=$_count');
    _running = false;
    _status = '保存中';
    _notify();
    await SchedulerBinding.instance.endOfFrame;
    await _voice.stop();
    await _subscription?.cancel();
    _subscription = null;
    await _waitForFramePipelineToIdle();
    await _camera.dispose();
    await _pose.dispose();
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _switchingCamera || _busy || image.planes.length < 3) {
      return;
    }
    _busy = true;
    final session = _session;
    try {
      final rawRgb = yuv420ToRgb(
        width: image.width,
        height: image.height,
        yPlane: image.planes[0].bytes,
        uPlane: image.planes[1].bytes,
        vPlane: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      );
      final rgb = orientRgbFrame(
        rawRgb,
        rotationDegrees: _calibration.rotationFor(_camera.sensorOrientation),
        mirrorX: _calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing),
      );
      final input = _pose.pipeline.preprocess(rgb, target: _pose.target);
      final keypoints = await _pose.infer(input);
      if (session != _session) {
        return;
      }

      final frameWidth = rgb.width.toDouble();
      final frameHeight = rgb.height.toDouble();
      var status = _status;
      var count = _count;
      if (!_ready) {
        final ready = _readyGate.update(
          keypoints: keypoints,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          at: DateTime.now(),
        );
        if (ready) {
          _ready = true;
          _lostPoseFrames = 0;
          // Snapshot the wrist support baseline; keep the accumulated count so
          // an anomaly (hands raised) that dropped back to "ready" does not
          // wipe the set. The counter/filter/anchor restart their tracking, but
          // the count survives.
          _wristAnchor.calibrate(keypoints);
          _lastStable = true;
          final lw = keypoints[SignalExtractor.leftWrist];
          final rw = keypoints[SignalExtractor.rightWrist];
          debugPrint(
            'UGK ready: calibrated=${_wristAnchor.isCalibrated} '
            'count=$_count '
            'lwY=${lw.y.toStringAsFixed(0)} rwY=${rw.y.toStringAsFixed(0)} '
            'lConf=${lw.confidence.toStringAsFixed(2)} '
            'rConf=${rw.confidence.toStringAsFixed(2)}',
          );
          _pipeline.resetTracking(count: _count);
          status = '已准备好，请开始训练';
          unawaited(_voice.playReady());
        } else {
          status = '请保持俯卧撑姿势并稳定入镜';
        }
      } else {
        if (!_coreTorsoVisible(keypoints)) {
          _lostPoseFrames += 1;
          if (_lostPoseFrames >= _maxLostPoseFrames) {
            _ready = false;
            _lostPoseFrames = 0;
            _readyGate.reset();
            _wristAnchor.reset();
            _pipeline.resetTracking(count: _count);
            debugPrint('UGK lost-pose: exit ready, keep count=$_count');
            status = '请保持俯卧撑姿势并完整入镜';
          }
        } else {
          _lostPoseFrames = 0;
          // WristAnchor is diagnostic only during motion; torso drives counting.
          final handsStable = _wristAnchor.isStable(keypoints);
          if (handsStable != _lastStable) {
            final lw = keypoints[SignalExtractor.leftWrist];
            final rw = keypoints[SignalExtractor.rightWrist];
            debugPrint(
              'UGK stable: $handsStable '
              'lwY=${lw.y.toStringAsFixed(0)} rwY=${rw.y.toStringAsFixed(0)} '
              'lConf=${lw.confidence.toStringAsFixed(2)} '
              'rConf=${rw.confidence.toStringAsFixed(2)}',
            );
            _lastStable = handsStable;
          }
          final oldCount = _count;
          _pipeline.process(keypoints, handsStable: handsStable);
          count = _pipeline.count;
          if (count > oldCount && count <= 30) {
            final sig = _pipeline.lastSignals;
            debugPrint(
              'UGK count: $count '
              'torso=${sig?.torsoY?.toStringAsFixed(0)} '
              'elbow=${sig?.elbowAngle?.toStringAsFixed(0)} '
              'stable=$handsStable',
            );
            unawaited(_voice.playCount(count));
          }
          status = '训练中';
        }
      }

      if (_running) {
        _keypoints = keypoints;
        _sourceSize = Size(frameWidth, frameHeight);
        _count = count;
        _status = status;
        _notify();
      }
    } catch (error) {
      if (session != _session) {
        return;
      }
      _status = '错误：$error';
      _notify();
    } finally {
      _busy = false;
    }
  }

  Future<void> _waitForFramePipelineToIdle() async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _disposeCameraAndPoseWhenIdle() async {
    await _waitForFramePipelineToIdle();
    await _camera.dispose();
    await _pose.dispose();
  }

  bool _sameCamera(CameraDescription camera, CameraDescription? other) {
    return other != null &&
        camera.name == other.name &&
        camera.lensDirection == other.lensDirection;
  }

  CameraDescription _selectedOrDefaultCamera(List<CameraDescription> cameras) {
    final selected = _selectedCamera;
    if (selected != null) {
      for (final camera in cameras) {
        if (_sameCamera(camera, selected)) {
          return camera;
        }
      }
    }
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  /// Motion-stage pose check. A rep stays "in pose" when:
  ///   * the torso (nose + both shoulders) is confidently visible — these drive
  ///     the motion signal, and if they go missing the user has genuinely left
  ///     frame (or the model lost lock); AND
  ///   * the hands have NOT clearly left the support — i.e. it is NOT the case
  ///     that a confidently-visible wrist sits above the shoulders. A raised
  ///     hand (the classic false-count source) is high-confidence and above the
  ///     shoulders, so this catches it without requiring wrists to be visible
  ///     (they routinely drop at close range during a real press).
  ///
  /// This is looser than [ReadyPoseGate.isPoseVisible] (which requires wrists +
  /// hips for strict calibration) on visibility, but adds the support-position
  /// check so a raised hand still triggers lost-pose.
  bool _coreTorsoVisible(List<KeyPoint> keypoints) {
    if (keypoints.length < 17) {
      return false;
    }
    final torsoVisible = keypoints[SignalExtractor.nose].confidence >= 0.3 &&
        keypoints[SignalExtractor.leftShoulder].confidence >= 0.3 &&
        keypoints[SignalExtractor.rightShoulder].confidence >= 0.3;
    if (!torsoVisible) {
      return false;
    }
    // A confidently-visible wrist above its shoulder means a hand left support
    // (raised). Low-confidence wrists are exempt — at close range the support
    // wrist is often low-confidence, and that is not a raised hand.
    final lw = keypoints[SignalExtractor.leftWrist];
    final ls = keypoints[SignalExtractor.leftShoulder];
    final rw = keypoints[SignalExtractor.rightWrist];
    final rs = keypoints[SignalExtractor.rightShoulder];
    final leftRaised = lw.confidence >= 0.3 && lw.y < ls.y - SignalExtractor.wristSupportMarginPx;
    final rightRaised = rw.confidence >= 0.3 && rw.y < rs.y - SignalExtractor.wristSupportMarginPx;
    if (leftRaised || rightRaised) {
      return false;
    }
    return true;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _session++;
    _running = false;
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_disposeCameraAndPoseWhenIdle());
    unawaited(_voice.dispose());
    super.dispose();
  }
}
