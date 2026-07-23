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

import '../config/resource_constants.dart';
import '../inference/pose_estimator.dart';
import '../pipeline/frame_pipeline.dart';
import '../pipeline/yuv420.dart';
import '../platform/camera_service.dart';
import '../platform/recognition_trace_log.dart';
import '../product/motion_pose_gate.dart';
import '../product/exercise_type.dart';
import '../product/narrow_pushup_form_gate.dart';
import '../product/ready_pose_gate.dart';
import '../product/pushup_pipeline.dart';
import '../product/voice_prompt_player.dart';
import '../product/wrist_anchor.dart';
import '../pushup_domain.dart';
import 'camera_calibration.dart';

enum WorkoutStatus {
  loading,
  loadingModel,
  startingCamera,
  positionGuide,
  startupError,
  switchingCamera,
  cameraError,
  cameraPermissionDenied,
  cameraPermissionSettings,
  saving,
  holdPose,
  narrowForm,
  tooClose,
  readyToStart,
  reacquiringPose,
  training,
  frameError,
  saveFailed,
}

typedef _ErrorDetails = ({Object error, StackTrace stackTrace});

/// Orchestrates the live pushup workout: camera lifecycle, pose inference
/// scheduling (with a session token to guard against races), the
/// ready/count/wrist-anchor state machine, and voice prompts.
///
/// The controller does NOT touch [BuildContext], [Navigator], or persistent
/// storage. Stopping a workout only halts the hardware; the owning widget
/// decides whether to persist and pop.
class WorkoutController extends ChangeNotifier {
  WorkoutController({
    this.exerciseType = ExerciseType.pushup,
    CameraService? camera,
    PoseEstimator? pose,
    PushupPipeline? pipeline,
    CameraCalibration? calibration,
    ReadyPoseGate? readyGate,
    WristAnchor? wristAnchor,
    String voiceBaseDir = chineseVoicePromptBaseDir,
    VoicePromptPlayer? voice,
    RecognitionTraceLog? trace,
    NarrowPushupFormGate narrowFormGate = const NarrowPushupFormGate(),
  }) : _camera = camera ?? CameraService(),
       _pose = pose ?? PoseEstimator(),
       _pipeline = pipeline ?? PushupPipeline(),
       _calibration = calibration ?? CameraCalibration(),
       _readyGate = readyGate ?? ReadyPoseGate(),
       _wristAnchor = wristAnchor ?? WristAnchor(),
       _voice = voice ?? VoicePromptPlayer(baseDir: voiceBaseDir),
       _trace = trace ?? RecognitionTraceLog(enabled: kDebugMode),
       _narrowFormGate = narrowFormGate;

  static const _maxLostPoseFrames = 15;

  final ExerciseType exerciseType;
  final CameraService _camera;
  final PoseEstimator _pose;
  final PushupPipeline _pipeline;
  final CameraCalibration _calibration;
  final ReadyPoseGate _readyGate;
  final WristAnchor _wristAnchor;
  final VoicePromptPlayer _voice;
  final RecognitionTraceLog _trace;
  final NarrowPushupFormGate _narrowFormGate;

  StreamSubscription<CameraImage>? _subscription;
  Future<void>? _subscriptionCancellation;
  Future<void>? _cameraInitialization;
  Future<void>? _poseLoad;
  Future<_ErrorDetails?>? _cameraRelease;
  Future<_ErrorDetails?>? _resourceCleanup;
  Future<void>? _traceStart;
  Future<_ErrorDetails?>? _traceClose;
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
  var _reacquiringPose = false;
  var _lostPoseFrames = 0;
  // Latched when the ready pose is too close to the camera: while true the
  // controller keeps reporting tooClose without re-running the ready gate each
  // frame (which would otherwise cycle tooClose <-> holdPose every ~500ms).
  // Cleared once a later calibration reports a safe distance.
  var _tooClose = false;
  var _traceFrame = 0;
  var _droppedFrames = 0;
  var _count = 0;
  var _status = WorkoutStatus.loading;
  // Last frame's handsStable, to log only on transitions (not every frame).
  var _lastStable = true;

  var _started = false;
  var _starting = false;
  bool _disposed = false;

  // === Read-only state exposed to the UI ===

  int get count => _count;
  bool get ready => _ready;
  WorkoutStatus get status => _status;
  bool get stopping => _stopping;
  bool get switchingCamera => _switchingCamera;
  bool get running => _running;
  CameraDescription? get selectedCamera => _selectedCamera;
  List<CameraDescription> get cameras => _cameras;
  List<KeyPoint> get keypoints => _keypoints;
  Size get sourceSize => _sourceSize;
  DateTime? get startedAt => _startedAt;
  CameraService get camera => _camera;

  @visibleForTesting
  String get debugVoiceBaseDir => _voice.baseDir;

  // === UI commands ===

  Future<void> start() async {
    if (_disposed || _started) {
      return;
    }
    _started = true;
    final session = ++_session;
    debugPrint('UGK session: start #$session');
    _startedAt = DateTime.now();
    _running = true;
    _starting = true;
    _stopping = false;
    _switchingCamera = false;
    _busy = false;
    _ready = false;
    _reacquiringPose = false;
    _lostPoseFrames = 0;
    _traceFrame = 0;
    _droppedFrames = 0;
    _count = 0;
    _pipeline.reset();
    _readyGate.reset();
    _tooClose = false;
    _wristAnchor.reset();
    _keypoints = const [];
    _sourceSize = Size.zero;
    _status = WorkoutStatus.loadingModel;
    _notify();
    try {
      await _startTrace(_startedAt!);
      if (session != _session) {
        // The in-flight trace initialization is owned by _traceStart and shared
        // with stop()/dispose() through _closeTraceWhenIdle(); a stale start must
        // join that handle instead of issuing a second close.
        await _closeTraceWhenIdle();
        return;
      }
      _traceEvent('session_start');
      unawaited(_voice.preloadCounts());
      await _loadPose();
      if (session != _session) {
        await _awaitOwnedCleanup('stale-start-pose');
        return;
      }
      _status = WorkoutStatus.startingCamera;
      _notify();
      final cameras = await _camera.listCameras();
      if (session != _session) {
        await _awaitOwnedCleanup('stale-start-cameras');
        return;
      }
      await _initializeCamera(_selectedOrDefaultCamera(cameras));
      if (session != _session) {
        await _awaitOwnedCleanup('stale-start-initialize');
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      unawaited(_voice.playGuide());
      _cameras = cameras;
      _selectedCamera = _camera.description;
      _starting = false;
      _status = WorkoutStatus.positionGuide;
      _notify();
    } catch (error) {
      if (session != _session) {
        return;
      }
      _traceEvent('startup_error', {'errorType': _errorType(error)});
      _running = false;
      _starting = false;
      _stopping = false;
      _status = _cameraFailureStatus(
        error,
        fallback: WorkoutStatus.startupError,
      );
      _notify();
      await _cleanupAfterPrimaryError('startup', error);
      if (session != _session) {
        return;
      }
    }
  }

  Future<void> switchCamera(CameraDescription camera) async {
    if (_disposed) {
      return;
    }
    if (_starting ||
        !_running ||
        _switchingCamera ||
        _sameCamera(camera, _selectedCamera)) {
      return;
    }
    final session = ++_session;
    debugPrint('UGK session: switch-camera #$session keep count=$_count');
    _traceEvent('switch_camera_start', {'camera': camera.name});
    _switchingCamera = true;
    _ready = false;
    _reacquiringPose = false;
    _lostPoseFrames = 0;
    _tooClose = false;
    _readyGate.reset();
    _wristAnchor.reset();
    _pipeline.resetTracking(count: _count);
    _keypoints = const [];
    _sourceSize = Size.zero;
    _status = WorkoutStatus.switchingCamera;
    _notify();
    await SchedulerBinding.instance.endOfFrame;
    if (session != _session) {
      return;
    }
    try {
      final releaseError = await _releaseCameraWhenIdle();
      if (session != _session) {
        return;
      }
      if (releaseError != null) {
        Error.throwWithStackTrace(releaseError.error, releaseError.stackTrace);
      }
      await _initializeCamera(camera);
      if (session != _session) {
        await _awaitOwnedCleanup('stale-switch-initialize');
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      _selectedCamera = _camera.description;
      _switchingCamera = false;
      _traceEvent('switch_camera_complete', {'camera': camera.name});
      _status = WorkoutStatus.positionGuide;
      _notify();
    } catch (error) {
      if (session != _session) {
        return;
      }
      _traceEvent('switch_camera_error', {'errorType': _errorType(error)});
      _running = false;
      _switchingCamera = false;
      _status = _cameraFailureStatus(
        error,
        fallback: WorkoutStatus.cameraError,
      );
      _notify();
      await _cleanupAfterPrimaryError('switch-camera', error);
      if (session != _session) {
        return;
      }
    }
  }

  /// Stops camera/pose/voice. Does NOT persist the session or navigate; the
  /// owning widget reads [count]/[startedAt] and does that itself after this
  /// returns.
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    if (!_running || _stopping) {
      return;
    }
    _stopping = true;
    final session = ++_session;
    debugPrint('UGK session: stop, saving count=$_count');
    _traceEvent('session_stop', {'droppedFramesPending': _droppedFrames});
    _running = false;
    _starting = false;
    _status = WorkoutStatus.saving;
    _notify();
    await SchedulerBinding.instance.endOfFrame;
    if (session != _session) {
      return;
    }
    _ErrorDetails? voiceError;
    try {
      await _voice.stop();
      if (session != _session) {
        return;
      }
    } catch (error, stackTrace) {
      voiceError = (error: error, stackTrace: stackTrace);
    }
    if (session != _session) {
      _throwPreferredError(primary: voiceError, boundary: 'stop');
      return;
    }
    _ErrorDetails? cleanupError;
    cleanupError = await _disposeCameraAndPoseWhenIdle();
    if (session != _session) {
      _throwPreferredError(
        primary: voiceError,
        cleanup: cleanupError,
        boundary: 'stop',
      );
      return;
    }
    final traceError = await _closeTraceWhenIdle();
    if (session != _session) {
      if (traceError != null) {
        cleanupError = _keepFirstCleanupError(
          cleanupError,
          traceError.error,
          traceError.stackTrace,
          boundary: 'stop',
        );
      }
      _throwPreferredError(
        primary: voiceError,
        cleanup: cleanupError,
        boundary: 'stop',
      );
      return;
    }
    if (traceError != null) {
      cleanupError = _keepFirstCleanupError(
        cleanupError,
        traceError.error,
        traceError.stackTrace,
        boundary: 'stop',
      );
    }
    _throwPreferredError(
      primary: voiceError,
      cleanup: cleanupError,
      boundary: 'stop',
    );
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _switchingCamera || image.planes.length < 3) {
      return;
    }
    if (_busy) {
      _droppedFrames += 1;
      return;
    }
    _busy = true;
    final session = _session;
    final frame = ++_traceFrame;
    final droppedFrames = _droppedFrames;
    _droppedFrames = 0;
    final stopwatch = Stopwatch()..start();
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
      final readyBefore = _ready;
      bool? readyGatePassed;
      bool? motionUsable;
      bool? handsStable;
      NarrowPushupFormResult? narrowForm;
      CounterState? counterState;
      FrameSignals? signals;
      if (!_ready) {
        narrowForm = _evaluateNarrowForm(keypoints);
        if (narrowForm != null &&
            narrowForm.status == NarrowPushupFormStatus.doesNotMatch) {
          _readyGate.reset();
          readyGatePassed = false;
          if (!_reacquiringPose && _status != WorkoutStatus.narrowForm) {
            _traceEvent('narrow_form_not_ready', {
              'narrowForm': _narrowFormJson(narrowForm),
            });
            unawaited(_voice.playNarrowForm());
          }
          status = _reacquiringPose
              ? WorkoutStatus.reacquiringPose
              : WorkoutStatus.narrowForm;
        } else {
          final ready = _readyGate.update(
            keypoints: keypoints,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            at: DateTime.now(),
          );
          readyGatePassed = ready;
          if (ready) {
            // Snapshot the wrist support baseline; keep the accumulated count
            // so a recovered anomaly does not wipe the set.
            _pipeline.resetTracking(count: _count);
            final depthCalibrated = _pipeline.calibrateReadyDepth(
              keypoints,
              sourceHeight: frameHeight,
            );
            if (!depthCalibrated) {
              _readyGate.reset();
              _traceEvent('ready_depth_calibration_failed');
              status = _reacquiringPose
                  ? WorkoutStatus.reacquiringPose
                  : WorkoutStatus.holdPose;
            } else {
              final groundSpan = _pipeline.readyGroundSpan;
              final tooClose = groundSpan != null &&
                  groundSpan > PushupPipeline.tooCloseGroundSpanPx;
              if (tooClose) {
                // Too close: at the bottom of a pushup the torso would leave
                // the frame and MoveNet loses the shoulders, so counting
                // silently stalls (see recognition.md §10). Latch _tooClose so
                // the status stays stable; the ready gate is *not* reset, which
                // avoids cycling tooClose <-> holdPose every 500ms while the
                // user is still too close. Once a later calibration reports a
                // safe distance, the else branch clears _tooClose and enters
                // training.
                //
                // Log the transition only on the leading edge (_tooClose was
                // false) so a user holding still too close does not flood the
                // trace/log every frame.
                if (!_tooClose) {
                  _tooClose = true;
                  _pipeline.resetTracking(count: _count);
                  debugPrint(
                    'UGK ready-too-close: '
                    'span=${groundSpan.toStringAsFixed(0)} '
                    'threshold=${PushupPipeline.tooCloseGroundSpanPx} '
                    'count=$_count',
                  );
                  _traceEvent('ready_too_close', {
                    'readyGroundSpan': _jsonNumber(groundSpan),
                    'threshold': PushupPipeline.tooCloseGroundSpanPx,
                  });
                  unawaited(_voice.playTooClose());
                }
                status = WorkoutStatus.tooClose;
              } else {
                _ready = true;
                _tooClose = false;
                _reacquiringPose = false;
                _lostPoseFrames = 0;
                _wristAnchor.calibrate(keypoints, sourceHeight: frameHeight);
                _lastStable = true;
                final lw = keypoints[SignalExtractor.leftWrist];
                final rw = keypoints[SignalExtractor.rightWrist];
                debugPrint(
                  'UGK ready: type=${exerciseType.storageValue} '
                  'calibrated=${_wristAnchor.isCalibrated} count=$_count '
                  'lwY=${lw.y.toStringAsFixed(0)} '
                  'rwY=${rw.y.toStringAsFixed(0)} '
                  'lConf=${lw.confidence.toStringAsFixed(2)} '
                  'rConf=${rw.confidence.toStringAsFixed(2)} '
                  'top=${_pipeline.readyTopY?.toStringAsFixed(0)} '
                  'span=${_pipeline.readyGroundSpan?.toStringAsFixed(0)} '
                  'downY=${_pipeline.requiredDownY?.toStringAsFixed(0)}',
                );
                _traceEvent('ready_enter', {
                  'wristAnchorCalibrated': _wristAnchor.isCalibrated,
                  'readyTopY': _jsonNumber(_pipeline.readyTopY),
                  'readyGroundSpan': _jsonNumber(_pipeline.readyGroundSpan),
                  'requiredDownY': _jsonNumber(_pipeline.requiredDownY),
                  'requiredDepthRatio': _pipeline.requiredDepthRatio,
                  if (narrowForm != null)
                    'narrowForm': _narrowFormJson(narrowForm),
                });
                status = WorkoutStatus.readyToStart;
                unawaited(_voice.playReady());
              }
            }
          } else {
            status = _reacquiringPose
                ? WorkoutStatus.reacquiringPose
                : WorkoutStatus.holdPose;
          }
        }
      } else {
        final usable = motionPoseUsable(keypoints, sourceHeight: frameHeight);
        motionUsable = usable;
        if (!usable) {
          _lostPoseFrames += 1;
          if (_lostPoseFrames >= _maxLostPoseFrames) {
            _ready = false;
            _reacquiringPose = true;
            _lostPoseFrames = 0;
            _readyGate.reset();
            _wristAnchor.reset();
            _pipeline.resetTracking(count: _count);
            debugPrint('UGK lost-pose: exit ready, keep count=$_count');
            _traceEvent('lost_pose_exit_ready');
            status = WorkoutStatus.reacquiringPose;
            unawaited(_voice.playPoseLost());
          }
        } else {
          _lostPoseFrames = 0;
          narrowForm = _evaluateNarrowForm(keypoints);
          final repCompletionDecision = switch (narrowForm?.status) {
            null ||
            NarrowPushupFormStatus.matches => RepCompletionDecision.allow,
            NarrowPushupFormStatus.doesNotMatch => RepCompletionDecision.reject,
            NarrowPushupFormStatus.unknown => RepCompletionDecision.wait,
          };
          // WristAnchor is diagnostic only during motion; torso drives counting.
          handsStable = _wristAnchor.isStable(
            keypoints,
            sourceHeight: frameHeight,
          );
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
          counterState = _pipeline.process(
            keypoints,
            handsStable: handsStable,
            sourceHeight: frameHeight,
            repCompletionDecision: repCompletionDecision,
          );
          signals = _pipeline.lastSignals;
          count = counterState.count;
          if (count > oldCount && count <= 30) {
            final sig = _pipeline.lastSignals;
            debugPrint(
              'UGK count: $count '
              'torso=${sig?.torsoY?.toStringAsFixed(0)} '
              'elbow=${sig?.elbowAngle?.toStringAsFixed(0)} '
              'depth=${_pipeline.lastDepthRatio?.toStringAsFixed(2)} '
              'stable=$handsStable type=${exerciseType.storageValue}',
            );
            _traceEvent('count', {
              'value': count,
              'torsoY': _jsonNumber(sig?.torsoY),
              'elbowAngle': _jsonNumber(sig?.elbowAngle),
              'depthRatio': _jsonNumber(_pipeline.lastDepthRatio),
              'handsStable': handsStable,
              if (narrowForm != null) 'narrowForm': _narrowFormJson(narrowForm),
            });
            unawaited(_voice.playCount(count));
          }
          status = WorkoutStatus.training;
        }
      }

      if (_trace.enabled) {
        _trace.write({
          'type': 'frame',
          'at': DateTime.now().toUtc().toIso8601String(),
          'session': session,
          'exerciseType': exerciseType.storageValue,
          'frame': frame,
          'sourceWidth': frameWidth,
          'sourceHeight': frameHeight,
          'processingMs': stopwatch.elapsedMicroseconds / 1000,
          'droppedFrames': droppedFrames,
          'readyBefore': readyBefore,
          'readyAfter': _ready,
          'readyGatePassed': readyGatePassed,
          'motionUsable': motionUsable,
          'handsStable': handsStable,
          'lostPoseFrames': _lostPoseFrames,
          'countBefore': _count,
          'countAfter': count,
          'status': status.name,
          if (narrowForm != null) 'narrowForm': _narrowFormJson(narrowForm),
          'keypoints': [
            for (final point in keypoints)
              {
                'index': point.index,
                'x': _jsonNumber(point.x),
                'y': _jsonNumber(point.y),
                'confidence': _jsonNumber(point.confidence),
              },
          ],
          if (signals != null)
            'signals': {
              'shoulderY': _jsonNumber(signals.shoulderY),
              'headY': _jsonNumber(signals.headY),
              'elbowAngle': _jsonNumber(signals.elbowAngle),
              'torsoY': _jsonNumber(signals.torsoY),
              'rawTorsoY': _jsonNumber(signals.rawTorsoY),
              'depthRatio': _jsonNumber(_pipeline.lastDepthRatio),
              'handsSupported': signals.handsSupported,
              'handsStable': signals.handsStable,
              'shoulderConf': _jsonNumber(signals.shoulderConf),
              'elbowConf': _jsonNumber(signals.elbowConf),
              'noseConf': _jsonNumber(signals.noseConf),
            },
          if (counterState != null)
            'counter': {
              'count': counterState.count,
              'phase': counterState.phase.name,
              'frozen': counterState.frozen,
              'calibrated': counterState.calibrated,
              'position': _jsonNumber(counterState.position),
              'low': _jsonNumber(counterState.low),
              'high': _jsonNumber(counterState.high),
            },
        });
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
      _traceEvent('frame_error', {
        'frame': frame,
        'errorType': _errorType(error),
      });
      _status = WorkoutStatus.frameError;
      _notify();
    } finally {
      _busy = false;
    }
  }

  WorkoutStatus _cameraFailureStatus(
    Object error, {
    required WorkoutStatus fallback,
  }) {
    if (error is! CameraException) {
      return fallback;
    }
    return switch (error.code) {
      'CameraAccessDeniedWithoutPrompt' =>
        WorkoutStatus.cameraPermissionSettings,
      'CameraAccessDenied' => WorkoutStatus.cameraPermissionDenied,
      _ => fallback,
    };
  }

  void _traceEvent(String event, [Map<String, Object?> details = const {}]) {
    if (!_trace.enabled) {
      return;
    }
    _trace.write({
      'type': 'event',
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      'session': _session,
      'exerciseType': exerciseType.storageValue,
      'count': _count,
      'ready': _ready,
      ...details,
    });
  }

  double? _jsonNumber(double? value) {
    return value != null && value.isFinite ? value : null;
  }

  NarrowPushupFormResult? _evaluateNarrowForm(List<KeyPoint> keypoints) {
    if (exerciseType != ExerciseType.narrowPushup) {
      return null;
    }
    return _narrowFormGate.evaluate(keypoints);
  }

  Map<String, Object?> _narrowFormJson(NarrowPushupFormResult result) {
    return {
      'status': result.status.name,
      'wristSpanRatio': _jsonNumber(result.wristSpanRatio),
      'elbowSpanRatio': _jsonNumber(result.elbowSpanRatio),
      'forearmDirectionDeltaDegrees': _jsonNumber(
        result.forearmDirectionDeltaDegrees,
      ),
    };
  }

  Future<void> _waitForFramePipelineToIdle() async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _cancelSubscription() {
    final cancellation = _subscriptionCancellation;
    if (cancellation != null) {
      return cancellation;
    }
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) {
      return Future.value();
    }
    late final Future<void> pending;
    pending = subscription.cancel().whenComplete(() {
      if (identical(_subscriptionCancellation, pending)) {
        _subscriptionCancellation = null;
      }
    });
    _subscriptionCancellation = pending;
    return pending;
  }

  Future<void> _initializeCamera(CameraDescription camera) {
    // A completed release belongs to the previous camera generation. Clearing
    // it only when a new generation begins lets stop/dispose share an in-flight
    // or failed release without attempting the same generation twice.
    _cameraRelease = null;
    late final Future<void> initialization;
    initialization = _camera.initialize(camera: camera).whenComplete(() {
      if (identical(_cameraInitialization, initialization)) {
        _cameraInitialization = null;
      }
    });
    _cameraInitialization = initialization;
    return initialization;
  }

  Future<void> _loadPose() {
    late final Future<void> load;
    load = _pose
        .load(assetPath: modelPath, mode: DelegateMode.nnapi)
        .whenComplete(() {
          if (identical(_poseLoad, load)) {
            _poseLoad = null;
          }
        });
    _poseLoad = load;
    return load;
  }

  Future<_ErrorDetails?> _releaseCameraWhenIdle() {
    final release = _cameraRelease;
    if (release != null) {
      return release;
    }
    late final Future<_ErrorDetails?> pending;
    pending = _releaseCameraWhenIdleImpl();
    _cameraRelease = pending;
    return pending;
  }

  Future<_ErrorDetails?> _releaseCameraWhenIdleImpl() async {
    _ErrorDetails? cleanupError;
    try {
      await _cancelSubscription();
    } catch (error, stackTrace) {
      cleanupError = (error: error, stackTrace: stackTrace);
    }
    try {
      await _waitForFramePipelineToIdle();
    } catch (error, stackTrace) {
      cleanupError = _keepFirstCleanupError(
        cleanupError,
        error,
        stackTrace,
        boundary: 'camera-release',
      );
    }
    try {
      final initialization = _cameraInitialization;
      if (initialization != null) {
        await initialization;
      }
    } catch (error) {
      _logErrorType('camera-initialization-owned', error);
    }
    try {
      await _camera.dispose();
    } catch (error, stackTrace) {
      cleanupError = _keepFirstCleanupError(
        cleanupError,
        error,
        stackTrace,
        boundary: 'camera-release',
      );
    }
    return cleanupError;
  }

  Future<_ErrorDetails?> _disposeCameraAndPoseWhenIdle() {
    return _resourceCleanup ??= _disposeCameraAndPoseWhenIdleImpl();
  }

  Future<_ErrorDetails?> _disposeCameraAndPoseWhenIdleImpl() async {
    var cleanupError = await _releaseCameraWhenIdle();
    try {
      final poseLoad = _poseLoad;
      if (poseLoad != null) {
        await poseLoad;
      }
    } catch (error) {
      _logErrorType('pose-load-owned', error);
    }
    try {
      await _pose.dispose();
    } catch (error, stackTrace) {
      cleanupError = _keepFirstCleanupError(
        cleanupError,
        error,
        stackTrace,
        boundary: 'resource-release',
      );
    }
    return cleanupError;
  }

  Future<void> _cleanupAfterPrimaryError(
    String boundary,
    Object primaryError,
  ) async {
    final cleanupError = await _disposeCameraAndPoseWhenIdle();
    if (cleanupError != null) {
      _logErrorType(
        '$boundary-cleanup-after-${_errorType(primaryError)}',
        cleanupError.error,
      );
    }
    // The trace starts before camera initialization, so a startup/switch
    // failure that terminates the session must close it here too — otherwise
    // the `.jsonl.part` sink stays open until a later dispose(). It shares the
    // same memoized ownership boundary as camera/pose cleanup so stop()/dispose
    // never re-enter or double-close it.
    final traceError = await _closeTraceWhenIdle();
    if (traceError != null) {
      _logErrorType(
        '$boundary-trace-after-${_errorType(primaryError)}',
        traceError.error,
      );
    }
  }

  Future<void> _awaitOwnedCleanup(String boundary) async {
    final cleanupError = await _disposeCameraAndPoseWhenIdle();
    if (cleanupError != null) {
      // stop/dispose owns the same memoized cleanup Future and is responsible
      // for its caller-visible semantics. This stale operation must not leak a
      // second unhandled copy of the same failure.
      _logErrorType('$boundary-owned-cleanup', cleanupError.error);
    }
  }

  Future<void> _startTrace(DateTime startedAt) {
    // Record the in-flight trace initialization so _closeTraceWhenIdle() can
    // await it before closing. Without this, a stop()/dispose() that lands while
    // startSession() is pending would close a trace whose sink has not yet
    // opened, and the stale start would then issue a second close once its gate
    // released. Starting a new session also retires the previous session's
    // memoized close handle, which belongs to the prior trace.
    _traceClose = null;
    late final Future<void> start;
    start = _trace.startSession(startedAt).whenComplete(() {
      if (identical(_traceStart, start)) {
        _traceStart = null;
      }
    });
    _traceStart = start;
    return start;
  }

  Future<_ErrorDetails?> _closeTrace() async {
    try {
      await _trace.close();
      return null;
    } catch (error, stackTrace) {
      return (error: error, stackTrace: stackTrace);
    }
  }

  Future<_ErrorDetails?> _closeTraceWhenIdle() async {
    // RecognitionTraceLog.close() is idempotent (no-op once the sink is null),
    // so concurrent stop()/dispose()/primary-error/stale-start cleanup share a
    // single completed Future instead of double-closing the sink or re-listening
    // to an already-completed error.
    final pending = _traceClose ??= _awaitTraceStartThenClose();
    return pending;
  }

  Future<_ErrorDetails?> _awaitTraceStartThenClose() async {
    final start = _traceStart;
    if (start != null) {
      try {
        await start;
      } catch (_) {
        // A failed trace initialization still leaves no open sink to close;
        // proceed to the single shared close so callers observe one outcome.
      }
    }
    return _closeTrace();
  }

  _ErrorDetails? _keepFirstCleanupError(
    _ErrorDetails? first,
    Object error,
    StackTrace stackTrace, {
    required String boundary,
  }) {
    if (first != null) {
      _logErrorType('$boundary-secondary-cleanup', error);
      return first;
    }
    return (error: error, stackTrace: stackTrace);
  }

  void _throwPreferredError({
    _ErrorDetails? primary,
    _ErrorDetails? cleanup,
    required String boundary,
  }) {
    if (primary != null) {
      if (cleanup != null) {
        _logErrorType('$boundary-cleanup-after-primary', cleanup.error);
      }
      Error.throwWithStackTrace(primary.error, primary.stackTrace);
    }
    if (cleanup != null) {
      Error.throwWithStackTrace(cleanup.error, cleanup.stackTrace);
    }
  }

  String _errorType(Object error) => error.runtimeType.toString();

  void _logErrorType(String code, Object error) {
    debugPrint('UGK session: $code errorType=${_errorType(error)}');
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

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _session++;
    _running = false;
    unawaited(
      _disposeCameraAndPoseWhenIdle()
          .then((cleanupError) {
            if (cleanupError != null) {
              _logErrorType('dispose-resource-cleanup', cleanupError.error);
            }
          })
          .catchError((Object error, StackTrace _) {
            _logErrorType('dispose-resource-unexpected', error);
          }),
    );
    unawaited(
      _voice.dispose().catchError((Object error, StackTrace _) {
        _logErrorType('dispose-voice-cleanup', error);
      }),
    );
    unawaited(
      _closeTraceWhenIdle()
          .then((traceError) {
            if (traceError != null) {
              _logErrorType('dispose-trace-cleanup', traceError.error);
            }
          })
          .catchError((Object error, StackTrace _) {
            _logErrorType('dispose-trace-unexpected', error);
          }),
    );
    super.dispose();
  }
}
