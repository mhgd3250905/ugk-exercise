// Extracted from main.dart during architecture refactor.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../control/camera_calibration.dart';
import '../../control/replay_control.dart';
import '../../inference/keypoint_log.dart';
import '../../inference/pose_estimator.dart';
import '../../perf/performance_meter.dart';
import '../../pipeline/frame_pipeline.dart';
import '../../pipeline/yuv420.dart';
import '../../platform/camera_service.dart';
import '../../platform/ffmpeg_kit_runner.dart';
import '../../platform/replay_utils.dart';
import '../../platform/video_replay_service.dart';
import '../../product/pushup_pipeline.dart';
import '../../pushup_domain.dart';
import '../../report/performance_report.dart';
import '../app_theme.dart';
import '../overlay_renderer.dart';
import '../perf_panel.dart';

class TestModePage extends StatelessWidget {
  const TestModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('测试模式'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.movie), text: '离线回放'),
              Tab(icon: Icon(Icons.videocam), text: '实时相机'),
            ],
          ),
        ),
        body: const TabBarView(children: [OfflineReplayTab(), LiveCameraTab()]),
      ),
    );
  }
}

class OfflineReplayTab extends StatefulWidget {
  const OfflineReplayTab({super.key});

  @override
  State<OfflineReplayTab> createState() => _OfflineReplayTabState();
}

class _OfflineReplayTabState extends State<OfflineReplayTab> {
  final _replay = VideoReplayService(ffmpegRunner: runFfmpegKit);
  final _pose = PoseEstimator();
  final _meter = PerformanceMeter();
  final _control = ReplayControl();
  final _pipeline = PushupPipeline();

  ui.Image? _image;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  String? _selectedVideoPath;
  String? _lastLogPath;
  String? _lastPerfPath;
  var _count = 0;
  var _status = '待开始';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FrameOverlay(
              image: _image,
              keypoints: _keypoints,
              sourceSize: _sourceSize,
              emptyText: '等待离线回放',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '计数：$_count',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 16),
              Expanded(child: Text('状态：$_status')),
            ],
          ),
          const SizedBox(height: 8),
          PerfPanel(snapshot: _meter.snapshot),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _control.running ? null : _onPickVideo,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择视频'),
              ),
              FilledButton.icon(
                onPressed: _control.running ? null : _onStartReplay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始回放'),
              ),
              OutlinedButton.icon(
                onPressed: _control.running ? _onTogglePause : null,
                icon: Icon(_control.paused ? Icons.play_arrow : Icons.pause),
                label: Text(_control.paused ? '继续' : '暂停'),
              ),
              OutlinedButton(onPressed: _onReset, child: const Text('重置')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '视频：${_selectedVideoPath == null ? replayVideoName : p.basename(_selectedVideoPath!)}；验收计数应为 5',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_lastLogPath != null)
            Text(
              '关键点日志：$_lastLogPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_lastPerfPath != null)
            Text(
              '性能报告：$_lastPerfPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _onStartReplay() async {
    setState(() {
      _control.start();
      _status = '加载模型';
    });
    _pipeline.reset();
    _meter.reset();

    try {
      await _pose.load(assetPath: modelPath);
      final videoPath = await resolveReplayVideo(_selectedVideoPath);
      setState(() => _status = '抽帧');
      await _replay.prepare(videoPath);
      final logFile = await openKeypointLog();
      final logSink = logFile.openWrite();
      final perfSamples = <PerformanceSample>[];
      var memoryPeakMb = currentRssMb();
      logSink.writeln(keypointCsvHeader());

      try {
        while (mounted && _control.running) {
          while (mounted && _control.paused) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_control.running) {
            break;
          }
          final frame = await _replay.nextFrame();
          if (frame == null) {
            break;
          }

          final preprocess = Stopwatch()..start();
          final input = _pose.pipeline.preprocess(
            frame.rgb,
            target: _pose.target,
          );
          preprocess.stop();
          final preprocessMs = preprocess.elapsedMilliseconds;
          _meter.recordPreprocess(preprocessMs);

          final infer = Stopwatch()..start();
          final keypoints = await _pose.infer(input);
          infer.stop();
          if (!mounted || !_control.running || _control.resetRequested) {
            break;
          }
          final inferMs = infer.elapsedMilliseconds;
          _meter.recordInfer(inferMs);
          perfSamples.add(
            PerformanceSample(
              preprocessMs: preprocessMs,
              inferMs: inferMs,
              keypoints: keypoints,
            ),
          );
          memoryPeakMb = max(memoryPeakMb, currentRssMb());
          logSink.writeln(
            keypointCsvRow(frame: frame.index, keypoints: keypoints),
          );

          final state = _pipeline.process(
            keypoints,
            sourceHeight: frame.height.toDouble(),
          );
          final image = await rgbFrameToImage(frame.rgb);
          final oldImage = _image;

          _meter.recordUiFrame();
          setState(() {
            _image = image;
            _keypoints = keypoints;
            _sourceSize = Size(frame.width.toDouble(), frame.height.toDouble());
            _count = state.count;
            _status = '${frame.index + 1}/${_replay.totalFrames}';
          });
          oldImage?.dispose();
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        await logSink.close();
      }

      if (_control.resetRequested) {
        await _replay.dispose();
        _control.reset();
        return;
      }

      final perfFile = await writePerformanceReport(
        samples: perfSamples,
        finalCount: _count,
        memoryPeakMb: memoryPeakMb,
      );
      if (mounted) {
        setState(() {
          _control.reset();
          _status = '完成：$_count';
          _lastLogPath = logFile.path;
          _lastPerfPath = perfFile.path;
        });
      }
    } catch (error) {
      if (mounted) {
        final wasReset = _control.resetRequested;
        setState(() {
          _control.reset();
          _status = wasReset ? '待开始' : '错误：$error';
        });
      }
    }
  }

  Future<void> _onPickVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    setState(() {
      _selectedVideoPath = path;
      _status = '已选择：${p.basename(path)}';
    });
  }

  void _onTogglePause() {
    setState(() {
      if (_control.paused) {
        _control.resume();
        _status = '继续';
      } else {
        _control.pause();
        _status = '暂停';
      }
    });
  }

  void _onReset() {
    final wasRunning = _control.running;
    if (wasRunning) {
      _control.requestReset();
    } else {
      _control.reset();
      unawaited(_replay.dispose());
    }
    _pipeline.reset();
    _meter.reset();
    final oldImage = _image;
    setState(() {
      _image = null;
      _keypoints = const [];
      _sourceSize = Size.zero;
      _count = 0;
      _status = '待开始';
      _lastLogPath = null;
      _lastPerfPath = null;
    });
    oldImage?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    unawaited(_replay.dispose());
    unawaited(_pose.dispose());
    super.dispose();
  }
}

class LiveCameraTab extends StatefulWidget {
  const LiveCameraTab({super.key});

  @override
  State<LiveCameraTab> createState() => _LiveCameraTabState();
}

class _LiveCameraTabState extends State<LiveCameraTab> {
  final _camera = CameraService();
  final _pose = PoseEstimator();
  final _meter = PerformanceMeter();
  final _calibration = CameraCalibration();
  final _liveSamples = <DelegateMode, List<PerformanceSample>>{};
  final _liveMemoryPeakMb = <DelegateMode, double>{};

  StreamSubscription<CameraImage>? _subscription;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  String? _lastPerfPath;
  var _running = false;
  var _busy = false;
  // 默认 NNAPI: 真机实测 20-28 FPS, 明显优于 CPU(14-16)/GPU(16-18)。
  var _mode = DelegateMode.nnapi;
  var _status = '待开始';
  // 会话版本号: 每次启动递增。异步操作完成后须校验版本号,
  // 不匹配说明期间发生过停止/重启, 丢弃过期结果(修复竞态 Bug)。
  var _session = 0;

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: controller == null || !controller.value.isInitialized
                  ? const Center(
                      child: Text(
                        '等待相机',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        CustomPaint(
                          painter: OverlayRenderer(
                            keypoints: _keypoints,
                            sourceSize: _sourceSize,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '状态：$_status | delegate：${_mode.name} | rot+${_calibration.rotationOffsetDegrees} | mirror ${_calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing) ? 'on' : 'off'}',
          ),
          const SizedBox(height: 8),
          PerfPanel(snapshot: _meter.snapshot),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _onToggleCamera,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? '停止' : '启动相机'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _onCycleDelegate,
                child: const Text('切换 delegate'),
              ),
              OutlinedButton(
                onPressed: _onRotateCamera,
                child: const Text('旋转90'),
              ),
              OutlinedButton(
                onPressed: _onToggleMirror,
                child: const Text('镜像'),
              ),
            ],
          ),
          if (_lastPerfPath != null)
            Text(
              '性能报告：$_lastPerfPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _onToggleCamera() async {
    if (_running) {
      await _stopCamera();
      return;
    }

    // 启动新会话: 递增版本号, 后续异步操作凭此校验是否仍有效。
    final session = ++_session;
    setState(() {
      _running = true;
      _status = '加载模型';
      _lastPerfPath = null;
    });
    _liveSamples.clear();
    _liveMemoryPeakMb.clear();
    _meter.reset();
    try {
      await _pose.load(assetPath: modelPath, mode: _mode);
      // 模型加载较慢(尤其 NNAPI), 期间用户可能已点停止 → 校验版本号。
      if (session != _session) {
        return;
      }
      await _camera.initialize();
      if (session != _session) {
        await _camera.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      if (mounted) {
        setState(() => _status = '运行中');
      }
    } catch (error) {
      if (session != _session) {
        // 期间已重启/停止, 此错误属于过期会话, 静默丢弃。
        return;
      }
      _running = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      if (mounted) {
        setState(() {
          _status = '错误：$error';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    // 递增版本号, 使任何进行中的启动序列立即失效(修复竞态 Bug)。
    _session++;
    _running = false;
    _busy = false;
    await _subscription?.cancel();
    _subscription = null;
    await _camera.dispose();
    final perfFile = await writeLivePerformanceReport(
      _liveSamples,
      _liveMemoryPeakMb,
    );
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '已停止';
        _lastPerfPath = perfFile?.path;
      });
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _busy || image.planes.length < 3) {
      return;
    }
    _busy = true;
    final mode = _mode;
    // 记录本帧所属会话, 推理异步完成后校验, 防止停止后仍画骨架(红屏)。
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

      final preprocess = Stopwatch()..start();
      final input = _pose.pipeline.preprocess(rgb, target: _pose.target);
      preprocess.stop();
      final preprocessMs = preprocess.elapsedMilliseconds;
      _meter.recordPreprocess(preprocessMs);

      final infer = Stopwatch()..start();
      final keypoints = await _pose.infer(input);
      infer.stop();
      // 推理异步期间用户可能已停止 → 会话失效, 丢弃结果(修复红屏)。
      if (session != _session) {
        return;
      }
      final inferMs = infer.elapsedMilliseconds;
      _meter.recordInfer(inferMs);
      (_liveSamples[mode] ??= <PerformanceSample>[]).add(
        PerformanceSample(
          preprocessMs: preprocessMs,
          inferMs: inferMs,
          keypoints: keypoints,
        ),
      );
      _liveMemoryPeakMb[mode] = max(
        _liveMemoryPeakMb[mode] ?? 0,
        currentRssMb(),
      );

      if (mounted && _running) {
        _meter.recordUiFrame();
        setState(() {
          _keypoints = keypoints;
          _sourceSize = Size(rgb.width.toDouble(), rgb.height.toDouble());
        });
      }
    } catch (error) {
      // 会话已失效(用户点了停止导致 interpreter 关闭等) → 静默, 不报红屏。
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

  void _onRotateCamera() {
    setState(() {
      _calibration.rotateClockwise();
      _status = '校准旋转：${_calibration.rotationOffsetDegrees}';
    });
  }

  void _onToggleMirror() {
    setState(() {
      _calibration.toggleMirror(isFrontFacing: _camera.isFrontFacing);
      _status =
          '校准镜像：${_calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing) ? 'on' : 'off'}';
    });
  }

  Future<void> _onCycleDelegate() async {
    if (_busy) {
      setState(() => _status = '推理中，稍后切换 delegate');
      return;
    }
    final nextMode = nextDelegateMode(_mode);
    if (!_running) {
      setState(() {
        _mode = nextMode;
        _status = 'delegate：${_mode.name}';
      });
      return;
    }

    _busy = true;
    try {
      await _pose.switchDelegate(nextMode);
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = nextMode;
        _status = 'delegate：${_mode.name}';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'delegate 错误：$error');
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _session++; // 使任何进行中的异步操作失效
    _running = false;
    unawaited(_subscription?.cancel());
    unawaited(_camera.dispose());
    unawaited(_pose.dispose());
    super.dispose();
  }
}

class _FrameOverlay extends StatelessWidget {
  const _FrameOverlay({
    required this.image,
    required this.keypoints,
    required this.sourceSize,
    required this.emptyText,
  });

  final ui.Image? image;
  final List<KeyPoint> keypoints;
  final Size sourceSize;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final currentImage = image;
    if (currentImage == null ||
        sourceSize.width <= 0 ||
        sourceSize.height <= 0) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(emptyText, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: sourceSize.width,
          height: sourceSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: currentImage, fit: BoxFit.fill),
              CustomPaint(
                painter: OverlayRenderer(
                  keypoints: keypoints,
                  sourceSize: sourceSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
