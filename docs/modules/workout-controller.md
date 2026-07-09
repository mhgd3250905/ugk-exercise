# WorkoutController（训练编排器）

> 文件：`lib/control/workout_controller.dart`
> 职责：封装一次训练会话的全部编排——相机、推理、计数管线、准备态、语音、状态。`extends ChangeNotifier`。

## 为什么存在

重构前，`_WorkoutPageState` 是"上帝 State"，同时承担 8 类职责（相机生命周期、推理调度、计数状态机、UI setState、语音、存储、导航、日志）。WorkoutController 把其中**非 UI 的编排逻辑**抽出，让 State 只负责渲染。

## 接口

```dart
class WorkoutController extends ChangeNotifier {
  // 暴露给 UI 的只读状态
  int get count;
  bool get ready;
  String get status;
  bool get stopping;
  bool get switchingCamera;
  bool get running;
  CameraDescription? get selectedCamera;
  List<CameraDescription> get cameras;
  List<KeyPoint> get keypoints;      // 渲染骨架用
  Size get sourceSize;
  CameraService get camera;          // UI 需要 controller 做 CameraPreview
  DateTime? get startedAt;

  // UI 调用的命令
  Future<void> start();
  Future<void> switchCamera(CameraDescription camera);
  Future<void> stop();   // 停止硬件，不导航/不写存储
  @override void dispose();
}
```

## 关键设计决策

### Controller 不碰 UI / 导航 / 存储
- **导航（Navigator.pop）和存储（store.append）留在 State 层**。State 监听 controller.stopping，自己 pop 和写存储。这样 Controller 不依赖 BuildContext/Widget，可独立测试。
- State 的 `_onStopPressed`：`await controller.stop()` → `store.append(WorkoutSession(...))` → `Navigator.pop()`。

### 状态通知
- 内部状态变化调 `notifyListeners()`（替代 `setState`）。
- `_notify()` 私有方法带 `_disposed` 守卫，dispose 后不通知。
- State 在 initState 注册 listener（调 setState），用 `_controller.xxx` 读取状态渲染。

### 依赖隔离
- 只 import `flutter/foundation.dart`（ChangeNotifier/debugPrint）和 `flutter/scheduler.dart`（SchedulerBinding.endOfFrame），**不依赖 material/widgets**。
- 不依赖 BuildContext，所以没有 `mounted` 概念。

### session 竞态守卫（原样保留）
异步操作（模型加载、相机初始化、推理）可能跨越用户停止/切换。每个 await 后校验 `session != _session`，不匹配则丢弃结果并清理。这套守卫从原 State 原样搬迁，是防止竞态（过期推理画骨架、停止后访问已释放资源）的关键。

## 协作关系

```
WorkoutController
  ├─ CameraService        相机硬件
  ├─ PoseEstimator        MoveNet 推理（IsolateInterpreter）
  ├─ CameraCalibration    旋转/镜像校正
  ├─ ReadyPoseGate        准备态门控
  ├─ WristAnchor          腕部稳定性门控
  ├─ PushupPipeline       计数管线（extractor→filter→counter）
  └─ VoicePromptPlayer    语音播报

每帧: CameraImage → yuv420→rgb → orient → preprocess → infer
      → [ready?] ReadyPoseGate → calibrate
      → [counting] WristAnchor.isStable → PushupPipeline.process → count
      → notifyListeners → State 重建 UI
```

## 诊断日志（保留）

所有 `debugPrint('UGK ...')` 原样保留在 Controller：
- `UGK session: start/switch-camera/stop`
- `UGK ready: calibrated/count/lwY/rwY/lConf/rConf`
- `UGK lost-pose: exit ready, keep count`
- `UGK stable: true/false ...`（只在翻转时打）
- `UGK count: N torso/elbow/stable`

抓取：`adb logcat -s flutter | grep UGK`

## 测试

目前编排逻辑由 `test/architecture_contract_test.dart` 的源码断言守护（session 守卫、资源清理顺序、voice-stop-before-dispose 等）。纯逻辑单测待补充（需要 fake CameraService/PoseEstimator）。
