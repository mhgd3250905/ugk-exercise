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
  WorkoutStatus get status;
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
  ├─ motionPoseUsable     运动态头肩可见性 + 可见抬手反证
  ├─ WristAnchor          ready 标定 + 腕部稳定性诊断
  ├─ PushupPipeline       计数管线（extractor→counter 内部中值滤波）
  ├─ RecognitionTraceLog  用户主动开启的训练识别追踪（JSONL，最近 20 次）
  └─ VoicePromptPlayer    语音播报

每帧: CameraImage → yuv420→rgb → orient → preprocess → infer
      → [ready?] ReadyPoseGate → 标定腕部锚点 + 头肩到地面相对深度
      → [counting] motionPoseUsable → WristAnchor.isStable（诊断）
                   → PushupPipeline.process → count
      → notifyListeners → State 重建 UI
```

## 诊断日志

所有 `debugPrint('UGK ...')` 原样保留在 Controller：
- `UGK session: start/switch-camera/stop`
- `UGK ready: calibrated/count/lwY/rwY/lConf/rConf/top/span/downY`
- `UGK lost-pose: exit ready, keep count`
- `UGK stable: true/false ...`（只在翻转时打）
- `UGK count: N torso/elbow/depth/stable`

抓取：`adb logcat -s flutter | grep UGK`

Debug 和 Release 包都提供“运动测试日志”能力，但默认关闭，只有用户在“个人 → 设置 → 识别诊断”明确开启后，下一次训练才写入应用私有目录
`recognition_traces/`。每帧包含 17 个关键点、准备/运动态门控、
手腕稳定性、准备态深度标定、每帧相对下压比例、计数信号、计数器状态、处理耗时和跳帧数，不含照片、视频或音频。
文件按训练分开，先写 `.jsonl.part`，正常关闭后才成为可导出的 `.jsonl`；最多保留最近 20 次，同时限制单次 12 MiB、总量 24 MiB。日志不上传、不纳入 Git，设置页可经 Android 系统文件界面汇总导出，汇总上限 25 MiB。

连接真机后查看文件名：

```bash
adb -s <device> shell run-as com.ugkexercise.ugk_exercise ls files/recognition_traces
```

Debug/可 `run-as` 的本地包也可直接导出其中一份（PowerShell）；商店 Release 应使用 App 设置页的“导出运动测试日志”：

```powershell
adb -s <device> exec-out run-as com.ugkexercise.ugk_exercise cat files/recognition_traces/<file.jsonl> > recognition_trace.jsonl
```

## 测试

目前编排逻辑由 `test/architecture_contract_test.dart` 的源码断言守护（session 守卫、资源清理顺序、voice-stop-before-dispose 等）。纯逻辑单测待补充（需要 fake CameraService/PoseEstimator）。
