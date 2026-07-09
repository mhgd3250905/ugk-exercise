// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../control/camera_calibration.dart';
import '../../inference/pose_estimator.dart';
import '../../platform/camera_service.dart';
import '../../product/ready_pose_gate.dart';
import '../../product/pushup_pipeline.dart';
import '../../product/voice_prompt_player.dart';
import '../../product/workout_session_store.dart';
import '../../product/wrist_anchor.dart';
import '../../pushup_domain.dart';
import '../../pipeline/frame_pipeline.dart';
import '../../pipeline/yuv420.dart';
import '../app_theme.dart';
import '../overlay_renderer.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.store});

  final WorkoutSessionStore store;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
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

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    final showPreview =
        !_stopping &&
        !_switchingCamera &&
        controller != null &&
        controller.value.isInitialized;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: ink,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = (constraints.maxHeight * 0.4)
                .clamp(330.0, 370.0)
                .toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  bottom: cardHeight - 28,
                  child: Container(
                    color: ink,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showPreview) CameraPreview(controller),
                        if (showPreview)
                          CustomPaint(
                            painter: OverlayRenderer(
                              keypoints: _keypoints,
                              sourceSize: _sourceSize,
                            ),
                          ),
                        if (!showPreview)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: lime),
                                const SizedBox(height: 18),
                                Text(
                                  _stopping ? '正在保存训练' : '正在启动相机',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SafeArea(
                          bottom: false,
                          child: Stack(
                            children: [
                              const Positioned(
                                left: 18,
                                top: 18,
                                child: _CameraBackButton(),
                              ),
                              Positioned(
                                top: 22,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _WorkoutChip(
                                    label: _ready ? '已准备' : '准备中',
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 26,
                                top: 28,
                                child: PopupMenuButton<CameraDescription>(
                                  tooltip: '选择摄像头',
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  onSelected: _switchCamera,
                                  itemBuilder: (context) {
                                    if (_cameras.isEmpty) {
                                      return const [
                                        PopupMenuItem<CameraDescription>(
                                          enabled: false,
                                          child: Text('相机加载中'),
                                        ),
                                      ];
                                    }
                                    return [
                                      for (final camera in _cameras)
                                        PopupMenuItem<CameraDescription>(
                                          value: camera,
                                          enabled: !_sameCamera(
                                            camera,
                                            _selectedCamera,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _cameraIcon(
                                                  camera.lensDirection,
                                                ),
                                                color: ink,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _cameraLabel(camera),
                                                  style: const TextStyle(
                                                    color: ink,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (_sameCamera(
                                                camera,
                                                _selectedCamera,
                                              ))
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: greenDark,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ),
                                    ];
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white,
                                    size: 28,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x88000000),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  enabled: !_switchingCamera,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: _WorkoutCountPanel(
                    count: _count,
                    status: _status,
                    ready: _ready,
                    onStop: _running ? _stopAndSave : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _cameraIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return Icons.camera_front_rounded;
      case CameraLensDirection.back:
        return Icons.camera_rear_rounded;
      case CameraLensDirection.external:
        return Icons.videocam_rounded;
    }
  }

  String _cameraLabel(CameraDescription camera) {
    final direction = switch (camera.lensDirection) {
      CameraLensDirection.front => '前置',
      CameraLensDirection.back => '后置',
      CameraLensDirection.external => '外接',
    };
    final firstSameDirection = _cameras.firstWhere(
      (item) => item.lensDirection == camera.lensDirection,
      orElse: () => camera,
    );
    final type = _looksWide(camera)
        ? '广角摄像头'
        : _sameCamera(firstSameDirection, camera)
        ? '正常摄像头'
        : '备用摄像头 ${camera.name}';
    return '$direction$type';
  }

  bool _looksWide(CameraDescription camera) {
    final name = camera.name.toLowerCase();
    return name.contains('wide') ||
        name.contains('ultra') ||
        name.contains('0.5') ||
        name.contains('uw');
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

  Future<void> _start() async {
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
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '加载模型';
      });
    }
    try {
      await _pose.load(assetPath: modelPath, mode: DelegateMode.nnapi);
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      if (mounted) {
        setState(() => _status = '启动相机');
      }
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
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _selectedCamera = _camera.description;
          _status = '请按提示摆放手机并保持姿势';
        });
      }
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
      if (mounted) {
        setState(() => _status = '错误：$error');
      }
    }
  }

  Future<void> _switchCamera(CameraDescription camera) async {
    if (!_running || _switchingCamera || _sameCamera(camera, _selectedCamera)) {
      return;
    }
    final session = ++_session;
    debugPrint('UGK session: switch-camera #$session keep count=$_count');
    _switchingCamera = true;
    _ready = false;
    _readyGate.reset();
    _wristAnchor.reset();
    _pipeline.reset();
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '切换相机';
      });
      await WidgetsBinding.instance.endOfFrame;
    }
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
      if (mounted) {
        setState(() {
          _selectedCamera = _camera.description;
          _switchingCamera = false;
          _status = '请按提示摆放手机并保持姿势';
        });
      } else {
        _switchingCamera = false;
      }
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
      if (mounted) {
        setState(() => _status = '相机错误：$error');
      }
    }
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
          // No pipeline reset here: the count must survive a re-ready after an
          // anomaly, and the 5-frame smoothing window refreshes on its own.
          status = '已准备好，请开始训练';
          unawaited(_voice.playReady());
        } else {
          status = '请保持俯卧撑姿势并稳定入镜';
        }
      } else {
        if (!_readyGate.isPoseVisible(keypoints)) {
          _lostPoseFrames += 1;
          if (_lostPoseFrames >= _maxLostPoseFrames) {
            _ready = false;
            _lostPoseFrames = 0;
            _readyGate.reset();
            _wristAnchor.reset();
            // Keep the count and the pipeline state; the smoothing window
            // refreshes on its own once counting resumes.
            debugPrint('UGK lost-pose: exit ready, keep count=$_count');
            status = '请保持俯卧撑姿势并完整入镜';
          }
        } else {
          _lostPoseFrames = 0;
          // Wrists gate (AND, never averaged); torso drives the motion signal.
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

      if (mounted && _running) {
        setState(() {
          _keypoints = keypoints;
          _sourceSize = Size(frameWidth, frameHeight);
          _count = count;
          _status = status;
        });
      }
    } catch (error) {
      if (session != _session) {
        return;
      }
      if (mounted) {
        setState(() => _status = '错误：$error');
      }
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

  Future<void> _stopAndSave() async {
    if (!_running || _stopping) {
      return;
    }
    final endedAt = DateTime.now();
    final startedAt = _startedAt ?? endedAt;
    _stopping = true;
    _session++;
    debugPrint('UGK session: stop, saving count=$_count');
    _running = false;
    if (mounted) {
      setState(() => _status = '保存中');
      await WidgetsBinding.instance.endOfFrame;
    }
    await _voice.stop();
    await _subscription?.cancel();
    _subscription = null;
    await _waitForFramePipelineToIdle();
    await _camera.dispose();
    await _pose.dispose();
    await widget.store.append(
      WorkoutSession(
        id: endedAt.microsecondsSinceEpoch.toString(),
        startedAt: startedAt,
        endedAt: endedAt,
        count: _count,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _session++;
    _running = false;
    unawaited(_subscription?.cancel());
    unawaited(_disposeCameraAndPoseWhenIdle());
    unawaited(_voice.dispose());
    super.dispose();
  }
}

class _WorkoutChip extends StatelessWidget {
  const _WorkoutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xDFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCountPanel extends StatelessWidget {
  const _WorkoutCountPanel({
    required this.count,
    required this.status,
    required this.ready,
    required this.onStop,
  });

  final int count;
  final String status;
  final bool ready;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final progress = (count > 30 ? 30 : count) / 30;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 34 + bottomPadding),
      decoration: const BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A17261F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: _WorkoutStat(
                  label: '今日目标',
                  value: '100 个',
                  valueColor: green,
                ),
              ),
              SizedBox.square(
                dimension: 154,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: const Color(0xFFFFF8C9),
                        color: green,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 66,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 4),
                          child: Text(
                            '个',
                            style: TextStyle(
                              color: muted,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: _WorkoutStat(
                  label: '消耗',
                  value: '32 千卡',
                  icon: Icons.local_fire_department_rounded,
                  valueColor: Color(0xFFFF7A21),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: greenDark),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: greenDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('结束训练'),
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor = ink,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 20, color: valueColor),
            if (icon != null) const SizedBox(width: 2),
            Flexible(
              child: Text(
                value,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: valueColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraBackButton extends StatelessWidget {
  const _CameraBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(
        Icons.close_rounded,
        shadows: [Shadow(color: Color(0x88000000), blurRadius: 8)],
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        fixedSize: const Size(46, 46),
        shape: const CircleBorder(),
      ),
    );
  }
}
