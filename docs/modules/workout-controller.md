# WorkoutController（训练编排器）

> 文件：`lib/control/workout_controller.dart`
> 职责：封装一次训练会话的全部编排——相机、推理、计数管线、准备态、语音、状态。`extends ChangeNotifier`。

## 为什么存在

重构前，`_WorkoutPageState` 是"上帝 State"，同时承担 8 类职责（相机生命周期、推理调度、计数状态机、UI setState、语音、存储、导航、日志）。WorkoutController 把其中**非 UI 的编排逻辑**抽出，让 State 只负责渲染。

## 接口

```dart
class WorkoutController extends ChangeNotifier {
  final ExerciseType exerciseType;    // pushup / narrowPushup

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

### 单会话生命周期与 session 竞态守卫

每个 Controller 实例只承载一次训练会话。`start()` 在第一个 await 前锁定 `_started`；会话启动中、运行中或 stop 清理中再次调用 `start()` 都直接返回，不创建第二代模型或相机。启动失败后的重试通过退出训练页并创建新 Controller 完成。

异步操作（模型加载、相机初始化、推理、停止和异常清理）可能跨越用户停止、切换或页面销毁。每个 await 后都校验 `session != _session`；过期路径立即返回，不再更新状态或继续处置资源。`dispose()` 使当前 session 失效并接管剩余清理，且 dispose 后的命令均直接返回。这些守卫用于防止过期推理画骨架、重复释放资源或停止后访问已释放资源。

## 协作关系

```
WorkoutController
  ├─ CameraService        相机硬件
  ├─ PoseEstimator        MoveNet 推理（IsolateInterpreter）
  ├─ CameraCalibration    旋转/镜像校正
  ├─ ReadyPoseGate        准备态门控
  ├─ NarrowPushupFormGate 窄距模式顶部手臂几何门控；常规模式完全绕过
  ├─ motionPoseUsable     运动态头肩可见性 + 可见抬手反证
  ├─ WristAnchor          ready 标定 + 腕部稳定性诊断
  ├─ PushupPipeline       计数管线（extractor→counter 内部中值滤波）
  ├─ RecognitionTraceLog  用户主动开启的训练识别追踪（JSONL，最近 20 次）
  └─ VoicePromptPlayer    语音播报

每帧: CameraImage → yuv420→rgb → orient → preprocess → infer
      → [ready?] [narrow?] NarrowPushupFormGate → ReadyPoseGate
                → 标定腕部锚点 + 头肩到地面相对深度
      → [counting] motionPoseUsable → WristAnchor.isStable（诊断）
                   → 顶部窄距判定 → PushupPipeline.process → count
                   → 连续 15 帧不可用：保留 count、重置未完成动作、进入 reacquiringPose
                   → 重新通过窄距/通用准备门控和深度标定后恢复 ready
      → notifyListeners → State 重建 UI
```

### 姿态中断与重新准备

- 运动态的单帧或短暂遮挡不立即打断；只有连续 15 个不可用处理帧才退出 `ready`。
- 退出时已完成计数保持不变，`PushupPipeline.resetTracking(count: _count)` 丢弃未完成的半次动作，防止重入时误计。
- `_reacquiringPose` 使状态持续为 `WorkoutStatus.reacquiringPose`；窄距门控失败、通用准备门控等待或深度标定失败都不得覆盖这条恢复提示。
- 标准与窄距训练仍分别复用原有准备态门控。重新标定成功后清除恢复标记、播 `ready` 并继续累计。
- 中断时只请求一次 `pose_lost.wav`。素材尚未补录时播放器安全静音；当前确定文案为“姿势已中断，请按指引重新准备。”。

## 诊断日志

所有 `debugPrint('UGK ...')` 原样保留在 Controller：
- `UGK session: start/switch-camera/stop`
- `UGK ready: calibrated/count/lwY/rwY/lConf/rConf/top/span/downY`
- `UGK lost-pose: exit ready, keep count`
- `UGK stable: true/false ...`（只在翻转时打）
- `UGK count: N torso/elbow/depth/stable`

窄距会话的事件和逐帧 JSONL 额外包含 `exerciseType` 与 `narrowForm`（腕宽/肩宽、肘宽/肩宽、双前臂方向差及结论）。准备态不匹配时状态持续为 `narrowForm`，且不会推进 ReadyPoseGate 稳定窗口；运动态只有动作返回顶部时才消费该结论，底部遮挡不会直接否决动作。常规俯卧撑不执行窄距门控。

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

编排逻辑由 `test/architecture_contract_test.dart` 的源码断言守护每个异步清理 await 后的 session 守卫、资源清理顺序和 voice-stop-before-dispose；`test/workout_controller_test.dart` 使用 fake 依赖验证单会话启动、stop/dispose 资源所有权、相机切换、准备态、窄距门控、常规模式兼容性，以及 15 帧中断阈值、计数保留、单次语音和重新 ready。
