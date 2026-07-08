// 俯卧撑检测 App — M3 入口骨架
// 见 M3-App开发方案与验收标准.md §5 模块规格
// 新同事：按 §6 实现顺序填充各模块，本文件提供 UI 骨架与占位
import 'package:flutter/material.dart';

import 'pushup_domain.dart' show CounterConfig, PushupCounter, SignalExtractor, SignalFilter;

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

/// 主页：离线回放 / 实时相机 两个入口
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('俯卧撑检测'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.movie), text: '离线回放'),
            Tab(icon: Icon(Icons.videocam), text: '实时相机'),
          ]),
        ),
        body: const TabBarView(children: [
          OfflineReplayTab(),
          LiveCameraTab(),
        ]),
      ),
    );
  }
}

/// 离线视频回放 Tab（M3 核心交付，验收主线）
/// 实现：见 M3 文档 §5.3 VideoReplayService + §6 步骤②③
class OfflineReplayTab extends StatefulWidget {
  const OfflineReplayTab({super.key});
  @override
  State<OfflineReplayTab> createState() => _OfflineReplayTabState();
}

class _OfflineReplayTabState extends State<OfflineReplayTab> {
  // TODO(M3): 接入 VideoReplayService / FramePipeline / PoseEstimator / PerformanceMeter
  // 以下三个为接入推理后使用的 Domain 层实例，骨架阶段暂未调用。
  final _counter = PushupCounter(config: const CounterConfig(frameHeight: 1280, fps: 30));
  final _filter = SignalFilter(window: 5);
  // ignore: unused_field
  final _extractor = const SignalExtractor();

  int _count = 0;
  String _status = '待开始';
  String _perfSummary = '-';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 视频预览 + 骨架叠加区（占位）
        Expanded(
          child: Container(
            color: Colors.black12,
            child: const Center(child: Text('骨架叠加预览\n(OverlayRenderer)', textAlign: TextAlign.center)),
          ),
        ),
        const SizedBox(height: 12),
        // 计数 + 状态 + 性能面板
        Row(children: [
          Text('计数：$_count', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(width: 16),
          Text('状态：$_status'),
        ]),
        const SizedBox(height: 8),
        Text('性能：$_perfSummary', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton.icon(
            onPressed: _onStartReplay,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始回放'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _onReset, child: const Text('重置')),
        ]),
        const SizedBox(height: 8),
        Text(
          '验收：回放 俯卧撑.mp4 计数应为 5（见 M3 文档 §7.2/§7.4 F1）',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]),
    );
  }

  void _onStartReplay() {
    // TODO(M3): §6 步骤②③
    // 1. VideoReplayService.prepare('俯卧撑.mp4')
    // 2. 循环 nextFrame() → FramePipeline.preprocess → PoseEstimator.infer
    // 3. PerformanceMeter 计时（preprocessMs / inferMs / e2eMs）
    // 4. SignalExtractor → SignalFilter → PushupCounter.update
    // 5. 更新 _count / _status / _perfSummary
    setState(() => _status = '待实现：接入 VideoReplayService');
  }

  void _onReset() {
    _counter.reset();
    _filter.reset();
    setState(() {
      _count = 0;
      _status = '待开始';
      _perfSummary = '-';
    });
  }
}

/// 实时相机流 Tab（端到端延迟验证）
/// 实现：见 M3 文档 §5.2 CameraService + §6 步骤④⑤⑥
class LiveCameraTab extends StatefulWidget {
  const LiveCameraTab({super.key});
  @override
  State<LiveCameraTab> createState() => _LiveCameraTabState();
}

class _LiveCameraTabState extends State<LiveCameraTab> {
  // TODO(M3): 接入 CameraService / FramePipeline / PoseEstimator
  bool _running = false;
  String _perfSummary = '-';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Container(
            color: Colors.black12,
            child: const Center(child: Text('相机预览 + 骨架\n(CameraService + OverlayRenderer)', textAlign: TextAlign.center)),
          ),
        ),
        const SizedBox(height: 12),
        Text('性能：$_perfSummary', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.icon(
            onPressed: _onToggleCamera,
            icon: Icon(_running ? Icons.stop : Icons.play_arrow),
            label: Text(_running ? '停止' : '启动相机'),
          ),
          const SizedBox(width: 8),
          // delegate 切换（M3 文档 §4.4）
          OutlinedButton(onPressed: _onCycleDelegate, child: const Text('切换 delegate')),
        ]),
      ]),
    );
  }

  void _onToggleCamera() {
    // TODO(M3): §6 步骤④
    // CameraService.initialize(facing: front) → startImageStream
    // 每帧：FramePipeline.preprocess → PoseEstimator.infer (Isolate) → 骨架
    setState(() {
      _running = !_running;
      _perfSummary = '待实现：接入 CameraService';
    });
  }

  void _onCycleDelegate() {
    // TODO(M3): §6 步骤⑥  PoseEstimator.switchDelegate(cpu/nnapi/gpu)
    setState(() => _perfSummary = '待实现：delegate 三档切换 + FPS 对比');
  }
}
