# ugk-post 架构优化方案与小步重构路线图

> 时间：2026-07-09
> 基线：`v0.1-architecture-baseline`（commit `c7c6593`）
> 前置文档：`docs/architecture-analysis.md`（现状与债务）
> 决策：现有目录深化 + 抽 Controller（见下文）

## 1. 目标分层架构

在现有目录名基础上深化，补全分层、归位错位模块、拆解上帝文件。改动最小、与现有代码风格一致。

```
lib/
├── main.dart                      ← 只剩 runApp() + UgkExerciseApp 根 + 路由表
│
├── domain/                        ← 【新建】纯领域，无 Flutter/平台依赖
│   ├── pushup_domain.dart           (从根目录迁入：KeyPoint/FrameSignals/
│   │                                  SignalExtractor/SignalFilter/PushupCounter)
│   ├── keypoint_index.dart          【新建】COCO-17 索引常量独立（nose/leftShoulder...）
│   └── frame.dart                   【新建】RgbFrame 从 pipeline 提升到此（共享类型）
│
├── product/                       ← 产品规则层（只依赖 domain）
│   ├── ready_pose_gate.dart         (原位)
│   ├── wrist_anchor.dart            【从 ui/ 迁入】纯信号门控，归位
│   ├── pushup_pipeline.dart         【新建】封装 extractor+anchor+filter+counter 装配
│   ├── voice_prompt_player.dart     (原位)
│   └── workout_session_store.dart   (原位，含 WorkoutSession 实体)
│
├── inference/                     ← 推理（依赖 pipeline + domain）
│   ├── pose_estimator.dart          (原位)
│   ├── keypoint_decoder.dart        (原位，改依赖 domain/keypoint_index)
│   ├── keypoint_log.dart            (原位)
│   └── delegate_mode.dart           (原位)
│
├── pipeline/                      ← 帧预处理（依赖 domain/frame）
│   ├── frame_pipeline.dart          (原位，RgbFrame 改 import domain/frame)
│   └── yuv420.dart                  (原位)
│
├── platform/                      ← 平台适配（依赖 domain + pipeline，不反向）
│   ├── camera_service.dart          (原位)
│   ├── ffmpeg_kit_runner.dart       (原位)
│   ├── report_directory.dart        (原位)
│   └── video_replay_service.dart    (原位，RgbFrame 改 import domain/frame)
│
├── control/                       ← 会话编排
│   ├── camera_calibration.dart      (原位)
│   ├── replay_control.dart          (原位)
│   └── workout_controller.dart      【新建】训练会话编排器（见 §3）
│
├── ui/                            ← 纯展示
│   ├── pages/                       【新建目录】
│   │   ├── home_page.dart             (从 main.dart 拆出)
│   │   ├── workout_page.dart          (从 main.dart 拆出，瘦身为渲染)
│   │   ├── records_page.dart          (从 main.dart 拆出)
│   │   ├── profile_page.dart          (从 main.dart 拆出)
│   │   └── test_mode_page.dart        (从 main.dart 拆出 + 两个 Tab)
│   ├── widgets/                     【新建目录】共享组件
│   │   ├── exercise_card.dart
│   │   ├── workout_count_panel.dart
│   │   ├── frame_overlay.dart
│   │   └── ... (其余共享组件)
│   ├── overlay_renderer.dart        (原位)
│   └── perf_panel.dart              (原位)
│
├── perf/                          ← 性能采集【仅测试模式】
│   └── performance_meter.dart        (原位)
│
└── report/                        ← 报告生成【仅测试模式】
    ├── performance_report.dart       (原位，解除对 inference 的反向依赖)
    └── golden_frame_report.dart      (原位)
```

## 2. 三项核心设计

### 2.1 `PushupPipeline`（债务 A/B 的解药）

**问题**：`toSignals → copyWith(handsStable) → smooth → update` 在训练页和回放页各手写一遍且不一致。

**方案**：抽出 `product/pushup_pipeline.dart`，单一职责封装整条计数管线：

```dart
class PushupPipeline {
  PushupPipeline({required CounterConfig config});
  final _extractor = SignalExtractor();
  final _filter = SignalFilter(window: 5);
  final _counter = PushupCounter(config: ...);
  final _anchor = WristAnchor();

  void onReady(List<KeyPoint> keypoints) { _anchor.calibrate(keypoints); _filter.reset(); }
  CounterState process(List<KeyPoint> keypoints) {
    final handsStable = _anchor.isStable(keypoints);
    final signals = _filter.smooth(
      _extractor.toSignals(keypoints).copyWith(handsStable: handsStable),
    );
    return _counter.update(signals);
  }
  int get count => _counter.state.count;
  void reset() { _counter.reset(); _filter.reset(); _anchor.reset(); }
}
```

**收益**：训练页和回放页共用同一装配，回放测试验证的逻辑 = 真机逻辑。管线可独立单测。

### 2.2 `WorkoutController`（债务 A 的解药）

**问题**：`_WorkoutPageState` 承担 8 类职责，是上帝 State。

**方案**：抽出 `control/workout_controller.dart`，持有相机/推理/管线/语音/存储编排，UI 只剩渲染：

```dart
class WorkoutController extends ChangeNotifier {
  // 暴露给 UI 的只读状态
  int get count;  bool get ready;  String get status;
  List<KeyPoint> get keypoints;  Size get sourceSize;

  // UI 调用的命令
  Future<void> start();  Future<void> stopAndSave();  void switchCamera(...);
  @override void dispose();
}
```

`_WorkoutPageState` 只做：持有 controller、`AnimatedBuilder`/`ListenableBuilder` 监听、渲染骨架和计数面板、转发按钮事件。

**收益**：编排逻辑可单测；UI 改动不影响计数逻辑；Session 竞态、资源清理集中一处。

### 2.3 共享类型归位（债务 C/D 的解药）

- `RgbFrame` → `domain/frame.dart`：pipeline/platform/inference/ui 都 import domain，断开 platform→pipeline 反向依赖。
- Keypoint 索引 → `domain/keypoint_index.dart`：从 `SignalExtractor` 剥离，ReadyPoseGate/WristAnchor/main 共用。
- `WristAnchor`：`ui/` → `product/`，与 ReadyPoseGate 同层。

## 3. 小步重构路线图

**铁律**：每步独立可验证（analyze 无 issue + 84 测试全绿 + 回放基线 5/5/3）、独立可回退（每步一个 commit）、不改行为（纯结构搬迁，业务逻辑零改动）。每步结束可随时停。

### 步骤 0：清理 CounterConfig 死字段（债务 E）
- **范围**：删除 `CounterConfig` 的 `@Deprecated` 字段及 main.dart 构造处对它们的传参。
- **验证**：analyze + test 全绿。
- **风险**：极低（死代码）。

### 步骤 1：共享类型归位（债务 C/D）
- **范围**：
  - 新建 `domain/keypoint_index.dart`，把 COCO-17 常量从 `SignalExtractor` 剥离；更新 ReadyPoseGate/WristAnchor/main 的引用。
  - 新建 `domain/frame.dart`，把 `RgbFrame` 从 pipeline 提升；更新 platform/video_replay_service 的 import。
  - `WristAnchor` 从 `ui/` 移到 `product/`，更新 import。
- **验证**：analyze + test 全绿；`architecture_contract_test.dart` 补充"platform 不依赖 pipeline 的预处理算法"断言。
- **风险**：低（纯移动 + import 调整）。

### 步骤 2：抽出 PushupPipeline（债务 B）
- **范围**：新建 `product/pushup_pipeline.dart`，封装 extractor+anchor+filter+counter。训练页和回放页都改为调用 pipeline。
- **验证**：新增 `test/pushup_pipeline_test.dart`（单测管线装配）；回放基线 5/5/3 不变；analyze 全绿。
- **风险**：中（触及训练/回放两处的装配，但行为不变）。

### 步骤 3：拆 main.dart —— 页面层（债务 A 前半）
- **范围**：把 6 个页面 + 组件拆到 `ui/pages/` 和 `ui/widgets/`，`main.dart` 只剩 `runApp` + App 根。**此步不抽 Controller**，`_WorkoutPageState` 保持胖但搬出。
- **验证**：analyze + test 全绿（架构契约测试更新文件路径断言）；真机冒烟（启动/训练/记录/测试模式可进）。
- **风险**：中（大量文件移动，但纯结构；需仔细处理私有组件可见性，部分 `_` 组件可能需改公开）。

### 步骤 4：抽出 WorkoutController（债务 A 后半）
- **范围**：从 `_WorkoutPageState` 抽出相机/推理/管线/语音/存储编排到 `control/workout_controller.dart`。State 改为 `ListenableBuilder` 监听 controller。
- **验证**：新增 `test/workout_controller_test.dart`（用 fake 相机/推理测编排逻辑）；analyze + test 全绿；真机验证训练计数正常。
- **风险**：中高（最复杂的一步，涉及异步生命周期和竞态守卫迁移）。**建议此步单独 PR，充分真机验证**。

### 步骤 5：调试模块隔离（债务 F）
- **范围**：`perf/` + `report/` 收敛，解除 `performance_report` 对 `inference/keypoint_log` 的反向依赖（把 `keypointNames` 提到 domain 或 report 自带）。
- **验证**：analyze + test 全绿。
- **风险**：低。

### 步骤 6（可选）：路由与目录整理（债务 G/H）
- **范围**：命名路由；`control/`、`platform/` 按功能重组。
- **风险**：低，但收益偏长期，可延后。

## 4. 每步的验证清单（通用）

每步 commit 前必须全部通过：
- [ ] `flutter analyze` 无 issue
- [ ] `flutter test` 全绿（84 测试 + 本步新增）
- [ ] 回放基线 step0=5, v3=5, v4=3 不变（除非该步明确改了信号源）
- [ ] 契约测试更新（分层约束变化时）

步骤 3/4 额外：
- [ ] 真机冒烟：启动 → 训练计数 → 记录 → 测试模式 各路径可达
- [ ] 真机验证：抬手到下巴不计数、正常俯卧撑正常计数

## 5. 回退策略

- 每步一个 commit，出问题 `git revert <step-commit>`。
- 重大回退：`git checkout v0.1-architecture-baseline`。
- 步骤 4（Controller）若真机出问题，可 revert 到步骤 3 末尾（页面已拆但未抽 Controller），不影响页面拆分的收益。

## 6. 不做的事

- 不改识别算法（torsoY + WristAnchor 已正确）。
- 不引入新依赖（状态管理用 Flutter 自带 ChangeNotifier，不引入 Riverpod/Bloc）。
- 不重写 UI（只搬迁、归位，不重新设计界面）。
- 不动 `pushup_domain.dart` 的算法逻辑（只迁位置 + 清死字段）。

---

各模块的详细需求说明与接口契约：见 `docs/modules/`。
