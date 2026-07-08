import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'control/camera_calibration.dart';
import 'control/replay_control.dart';
import 'inference/keypoint_log.dart';
import 'inference/pose_estimator.dart';
import 'perf/performance_meter.dart';
import 'pipeline/frame_pipeline.dart';
import 'pipeline/yuv420.dart';
import 'platform/camera_service.dart';
import 'platform/ffmpeg_kit_runner.dart';
import 'platform/report_directory.dart';
import 'platform/video_replay_service.dart';
import 'product/ready_pose_gate.dart';
import 'product/voice_prompt_player.dart';
import 'product/workout_session_store.dart';
import 'pushup_domain.dart';
import 'report/performance_report.dart';
import 'ui/overlay_renderer.dart';
import 'ui/perf_panel.dart';

const _modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';
const _replayVideoName = '俯卧撑.mp4';

void main() {
  runApp(const UgkExerciseApp());
}

class UgkExerciseApp extends StatelessWidget {
  const UgkExerciseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '俯卧撑检测',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = WorkoutSessionStore();
  var _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshTodayTotal());
  }

  Future<void> _refreshTodayTotal() async {
    final total = await _store.totalForLocalDate(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() => _todayTotal = total);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    tooltip: '个人信息',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfilePlaceholderPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RecordsPage(store: _store),
                        ),
                      );
                      await _refreshTodayTotal();
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text('今日 $_todayTotal'),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox.square(
                dimension: 180,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: const Color(0xFF58CC02),
                    foregroundColor: Colors.white,
                    elevation: 10,
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutPage(store: _store),
                      ),
                    );
                    await _refreshTodayTotal();
                  },
                  child: const Icon(Icons.play_arrow, size: 72),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '开始俯卧撑训练',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TestModePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.science),
                label: const Text('测试模式'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePlaceholderPage extends StatelessWidget {
  const ProfilePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: const Center(child: Text('个人信息与同步能力将在后续版本开放')),
    );
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.store});

  final WorkoutSessionStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('训练记录')),
      body: FutureBuilder<Map<DateTime, int>>(
        future: store.totalsByLocalDate(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data!.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));
          if (entries.isEmpty) {
            return const Center(child: Text('还没有训练记录'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final day = entry.key;
              return ListTile(
                title: Text('${day.year}-${day.month}-${day.day}'),
                trailing: Text('${entry.value} 个'),
              );
            },
          );
        },
      ),
    );
  }
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.store});

  final WorkoutSessionStore store;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final _camera = CameraService();
  final _pose = PoseEstimator();
  final _counter = PushupCounter(
    config: const CounterConfig(frameHeight: 1280, fps: 30),
  );
  final _filter = SignalFilter(window: 5);
  final _extractor = const SignalExtractor();
  final _calibration = CameraCalibration();
  final _readyGate = ReadyPoseGate();
  final _voice = VoicePromptPlayer();

  StreamSubscription<CameraImage>? _subscription;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  DateTime? _startedAt;
  var _session = 0;
  var _running = false;
  var _stopping = false;
  var _busy = false;
  var _ready = false;
  var _count = 0;
  var _status = '加载中';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    return Scaffold(
      backgroundColor: const Color(0xFFF7FCFF),
      appBar: AppBar(title: const Text('俯卧撑训练')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.black,
                  child: controller == null || !controller.value.isInitialized
                      ? const Center(
                          child: Text(
                            '正在启动相机',
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
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBDE7FF)),
              ),
              child: Text(
                '$_status\n当前计数：$_count',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running ? _stopAndSave : null,
              icon: const Icon(Icons.stop),
              label: const Text('结束训练'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B4B),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    final session = ++_session;
    _startedAt = DateTime.now();
    _running = true;
    _stopping = false;
    _busy = false;
    _ready = false;
    _count = 0;
    _counter.reset();
    _filter.reset();
    _readyGate.reset();
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '加载模型';
      });
    }
    try {
      await _pose.load(assetPath: _modelPath, mode: DelegateMode.nnapi);
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      if (mounted) {
        setState(() => _status = '启动相机');
      }
      await _camera.initialize();
      if (session != _session) {
        await _camera.dispose();
        await _pose.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      unawaited(_voice.playGuide());
      if (mounted) {
        setState(() => _status = '请按提示摆放手机并保持姿势');
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

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _busy || image.planes.length < 3) {
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
          _counter.reset();
          _filter.reset();
          count = 0;
          status = '已准备好，请开始训练';
          unawaited(_voice.playReady());
        } else {
          status = '请保持俯卧撑姿势并稳定入镜';
        }
      } else {
        final signals = _filter.smooth(_extractor.toSignals(keypoints));
        final oldCount = _count;
        final state = _counter.update(signals);
        count = state.count;
        if (count > oldCount && count <= 30) {
          unawaited(_voice.playCount(count));
        }
        status = '训练中';
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

  Future<void> _stopAndSave() async {
    if (!_running || _stopping) {
      return;
    }
    final endedAt = DateTime.now();
    final startedAt = _startedAt ?? endedAt;
    _stopping = true;
    _session++;
    _running = false;
    _busy = false;
    if (mounted) {
      setState(() => _status = '保存中');
    }
    await _voice.stop();
    await _subscription?.cancel();
    _subscription = null;
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
    unawaited(_camera.dispose());
    unawaited(_pose.dispose());
    unawaited(_voice.dispose());
    super.dispose();
  }
}

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
  final _counter = PushupCounter(
    config: const CounterConfig(frameHeight: 1280, fps: 30),
  );
  final _filter = SignalFilter(window: 5);
  final _extractor = const SignalExtractor();

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
            '视频：${_selectedVideoPath == null ? _replayVideoName : p.basename(_selectedVideoPath!)}；验收计数应为 5',
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
    _counter.reset();
    _filter.reset();
    _meter.reset();

    try {
      await _pose.load(assetPath: _modelPath);
      final videoPath = await _resolveReplayVideo(_selectedVideoPath);
      setState(() => _status = '抽帧');
      await _replay.prepare(videoPath);
      final logFile = await _openKeypointLog();
      final logSink = logFile.openWrite();
      final perfSamples = <PerformanceSample>[];
      var memoryPeakMb = _currentRssMb();
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
          memoryPeakMb = _max(memoryPeakMb, _currentRssMb());
          logSink.writeln(
            keypointCsvRow(frame: frame.index, keypoints: keypoints),
          );

          final signals = _filter.smooth(_extractor.toSignals(keypoints));
          final state = _counter.update(signals);
          final image = await _rgbFrameToImage(frame.rgb);
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

      final perfFile = await _writePerformanceReport(
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
    _counter.reset();
    _filter.reset();
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
      await _pose.load(assetPath: _modelPath, mode: _mode);
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
    final perfFile = await _writeLivePerformanceReport(
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
      _liveMemoryPeakMb[mode] = _max(
        _liveMemoryPeakMb[mode] ?? 0,
        _currentRssMb(),
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

Future<String> _resolveReplayVideo(String? selectedPath) async {
  if (selectedPath != null && await File(selectedPath).exists()) {
    return selectedPath;
  }

  final local = File(_replayVideoName);
  if (await local.exists()) {
    return local.path;
  }

  final bytes = await rootBundle.load(_replayVideoName);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, _replayVideoName));
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file.path;
}

Future<File> _openKeypointLog() async {
  final dir = await _reportDirectory();
  return File(p.join(dir.path, 'app_keypoints.csv'));
}

Future<File> _writePerformanceReport({
  required List<PerformanceSample> samples,
  required int finalCount,
  required double memoryPeakMb,
}) async {
  final totalElapsedMs = samples.fold<int>(
    0,
    (total, sample) => total + sample.e2eMs,
  );
  final report = buildPerformanceReport(
    mode: 'offline_replay',
    delegate: DelegateMode.cpu.name,
    finalCount: finalCount,
    totalElapsedMs: totalElapsedMs,
    samples: samples,
    memoryPeakMb: memoryPeakMb,
  );
  return _writeJsonReport('performance_report.json', report);
}

Future<File?> _writeLivePerformanceReport(
  Map<DelegateMode, List<PerformanceSample>> samplesByMode,
  Map<DelegateMode, double> memoryPeakByMode,
) async {
  final reports = [
    for (final entry in samplesByMode.entries)
      if (entry.value.isNotEmpty)
        buildPerformanceReport(
          mode: 'live_camera',
          delegate: entry.key.name,
          finalCount: 0,
          totalElapsedMs: entry.value.fold<int>(
            0,
            (total, sample) => total + sample.e2eMs,
          ),
          samples: entry.value,
          memoryPeakMb: memoryPeakByMode[entry.key] ?? 0,
        ),
  ];
  if (reports.isEmpty) {
    return null;
  }

  return _writeJsonReport('live_performance_report.json', {
    'mode': 'live_camera',
    'reports': reports,
    'delegate_comparison': buildDelegateComparison(reports),
  });
}

Future<File> _writeJsonReport(String name, Map<String, Object> report) async {
  final dir = await _reportDirectory();
  final file = File(p.join(dir.path, name));
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(report), flush: true);
  return file;
}

Future<Directory> _reportDirectory() async {
  final dir = selectReportDirectory(
    external: await getExternalStorageDirectory(),
    documents: await getApplicationDocumentsDirectory(),
  );
  await dir.create(recursive: true);
  return dir;
}

double _currentRssMb() {
  return ProcessInfo.currentRss / 1024 / 1024;
}

double _max(double a, double b) {
  return a > b ? a : b;
}

Future<ui.Image> _rgbFrameToImage(RgbFrame frame) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    _rgbToRgba(frame.rgb),
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Uint8List _rgbToRgba(Uint8List rgb) {
  final rgba = Uint8List(rgb.length ~/ 3 * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgba[j] = rgb[i];
    rgba[j + 1] = rgb[i + 1];
    rgba[j + 2] = rgb[i + 2];
    rgba[j + 3] = 255;
  }
  return rgba;
}
