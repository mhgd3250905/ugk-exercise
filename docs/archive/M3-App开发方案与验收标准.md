# 俯卧撑检测 App — M3 开发方案与验收标准

> **文档定位**：M3 的工程实现规格书，承接《俯卧撑检测-工程实现方案与验收标准-第二版》§3-§7，落到可执行。
> **本分支**：`feat/app-m3`，worktree 目录 `E:/AII/ugk-exercise-m3`。
> **前置**：M4 Domain 层已通过验收（附录B），Step0 基线已锁定。
> **本版重心**：用户最关心的是**识别速度（延迟/FPS）**——性能测量是头等公民，不是事后估算。
>
> 设计原则：第一性原理（性能可测、与 Step0 等价）；对抗式（每步预设失败）。
> 版本：M3 v1.0　｜　日期：2026-07-08

---

## 1. 范围与边界

### 1.1 本版交付（3 件，围绕"速度可测"）
1. **离线视频回放推理**（核心交付，验收主线）
2. **实时相机流推理**（端到端延迟验证）
3. **内置性能测量**（延迟/FPS 实时显示，不靠体感）

### 1.2 不做（留给后续）
- 计数 UI 大改、历史记录、动作评分、iOS、多人

> 对抗式提醒：任何"顺手加一下"需 review 提出，不得擅自扩范围。

---

## 2. 架构（承接第二版 §2/§3 五层）

```
┌──────────────────────────────────────────────┐
│  UI Layer (OverlayRenderer, PerfPanel, Controls) │
├──────────────────────────────────────────────┤
│  Domain Layer (pushup_domain.dart 原样复用)      │  ← 零平台依赖, 已验收
├──────────────────────────────────────────────┤
│  Inference Layer (PoseEstimator + Isolate)       │
├──────────────────────────────────────────────┤
│  Pipeline Layer (FramePipeline: YUV→RGB→lb→量化) │
├──────────────────────────────────────────────┤
│  Platform Layer (CameraService, VideoReplayService, Delegate) │
└──────────────────────────────────────────────┘
```

### 2.1 关键约束
- **Domain 层原样复用**：`pushup_domain.dart` 不改动，只 import。
- **Pipeline/Inference 对输入源无感知**：离线和实时共用同一套 `FramePipeline` + `PoseEstimator`，都吃 RGB 帧。这保证离线测出的性能能反映实时。

### 2.2 数据流
```
[离线] VideoReplayService.nextFrame() → RGB帧
[实时] CameraService.imageStream → YUV420 → FramePipeline.preprocess → RGB帧
                 ↓
        FramePipeline.preprocess(rgb) → TensorInput (192×192 量化)
                 ↓
        PoseEstimator.infer(tensor) → List<KeyPoint>(17)
                 ↓
        SignalExtractor → SignalFilter → PushupCounter → CounterState
                 ↓
        UI: OverlayRenderer(骨架) + PerfPanel(延迟/FPS) + 计数
        [PerformanceMeter 全程 Stopwatch 计时]
```

---

## 3. 关键技术约束（从 Step0 提取，写死，不得偏离）⭐

这些是保证"App 端关键点质量不偏离 Step0 基线"的硬约束。违反任意一条 = 黄金帧测试失败 = 不可验收。

### 3.1 模型同一
```
assets/models/movenet_singlepose_lightning_int8_4.tflite
```
与 Step0 同一文件（已在 worktree 的 step0/models/，需复制到 assets/models/）。

### 3.2 预处理等价于 Step0（`step0_verify.py` 的 `letterbox_frame` + `make_input`）
**letterbox（target=192）：**
```
scale = min(192 / width, 192 / height)
new_w = round(width * scale), new_h = round(height * scale)
pad_x = (192 - new_w) ~/ 2,  pad_y = (192 - new_h) ~/ 2   (居中, 整除)
画布 192×192 黑底(pad区填0), 缩放图贴到 [pad_y:pad_y+new_h, pad_x:pad_x+new_w]
缩放插值: 双线性(等价 cv2.INTER_LINEAR)
```
**量化（int8 模型，`make_input`）：**
```
不除 255，输入是 [0,255] RGB
quantized = clip(round(rgb / scale + zero_point), -128, 127)
其中 scale, zero_point 来自 input_detail.quantizationParameters
```
> ⚠️ 陷阱：**不要做 `/255` 归一化**。Step0 用的是 [0,255] 直接量化，做了归一化会导致关键点全错。

### 3.3 关键点逆变换等价（`keypoints_to_pixels`）
模型输出每点 `(y_norm, x_norm, conf)`，注意 y 在前。逆变换：
```
x_pixel = (x_norm * 192 - pad_x) / scale
y_pixel = (y_norm * 192 - pad_y) / scale
clamp: x_pixel ∈ [0, width-1], y_pixel ∈ [0, height-1]
```

### 3.4 输出解析（`dequantize_output`）
```
输出 shape 经 squeeze/reshape → (17, 3) = 17关键点 × (y,x,conf)
若为 int8 输出: float_value = (int8_value - zero_point) * scale
```

### 3.5 绘制阈值同一（`draw_overlay`）
```
连线绘制: 两端点 conf 均 ≥ 0.2
点着色:   conf ≥ 0.3 绿色, < 0.3 红色
```

### 3.6 17 关键点索引（固定）
```
0 nose, 1 left_eye, 2 right_eye, 3 left_ear, 4 right_ear,
5 left_shoulder, 6 right_shoulder, 7 left_elbow, 8 right_elbow,
9 left_wrist, 10 right_wrist, 11 left_hip, 12 right_hip,
13 left_knee, 14 right_knee, 15 left_ankle, 16 right_ankle
```

---

## 4. 性能规格（本版重心）⭐⭐⭐

用户最在意识别速度。性能必须**内置可测、实时显示、可复现**，不接受体感或理论估算。

### 4.1 内置性能测量（`PerformanceMeter`）
每帧记录，UI 滚动显示：
| 指标 | 测量点 | 含义 |
|---|---|---|
| `preprocessMs` | Stopwatch 包住 preprocess | YUV→RGB→letterbox→量化 |
| `inferMs` | Stopwatch 包住 infer | 纯推理 |
| `e2eMs` | preprocess + infer | 端到端单帧 |
| `fps` | 近 N 帧(≈30) e2e 倒数均值 | 实测推理 FPS |
| `uiFps` | Overlay rebuild 计数/秒 | UI 流畅度 |

UI 面板显示：当前值 + 近 30 帧**均值/P95**。P95 用于暴露抖动。

### 4.2 离线回放性能（验收主线，干净测量）
- **离线回放不依赖实时解码**：用 ffmpeg 预抽帧到内存/临时文件，回放时逐帧喂 pipeline。这样测的是**纯预处理+推理延迟**，不被视频解码抖动污染。
- 回放显示：总帧数、总耗时、平均 e2eMs、平均 FPS、各关键点平均 conf。
- **黄金验收**：回放 `俯卧撑.mp4`，最终计数=5（与 Domain 锚点一致）。

### 4.3 实时相机流性能
- `startImageStream` 帧进 pipeline，推理在 **IsolateInterpreter**。
- 显示：实时 e2eMs / fps / uiFps。
- 主线程不执行 infer（A2 验收项）。

### 4.4 delegate 三档可切换（`DelegateMode`）
```
enum DelegateMode { cpu, nnapi, gpu }
```
启动探测可用性，运行时可切。**记录三档 FPS 对比表**写入性能报告。

### 4.5 性能硬门槛（承接第二版 §5）
| 指标 | 目标 | 硬门槛 |
|---|---|---|
| 推理 FPS（中端机） | ≥15 | ≥10，否则不验收 |
| 端到端 e2eMs | <150 | <250 |
| UI 帧率 | 60fps | 肉眼无卡顿 |
| 内存峰值 | <400MB | <600MB |
> 注：目标机型由你定（你测 APK 的真机即基准）。中端骁龙6/7系为参考。

---

## 5. 模块实现规格（逐模块接口契约）

### 5.1 `lib/pushup_domain.dart`（原样复用，不改）
M4 已验收。import 即可。

### 5.2 `lib/platform/camera_service.dart`
```dart
class CameraService {
  Future<void> initialize({CameraLensDirection facing = CameraLensDirection.front});
  Stream<CameraImage> get imageStream;
  CameraController? get controller;
  Size? get previewSize;
  int get sensorOrientation;        // Android 旋转修正必需
  Future<void> dispose();
}
```
- 处理 Android sensor orientation（多数 90°/270°）。竖屏持机时输出帧方向须与 Step0 视频一致。

### 5.3 `lib/platform/video_replay_service.dart`（离线核心）⭐
```dart
class VideoReplayService {
  Future<void> prepare(String videoPath);   // ffmpeg 抽帧到临时目录
  Future<Frame?> nextFrame();               // 返回 RGB 帧 + 原始尺寸, null=结束
  int get totalFrames;
  int get currentIndex;
  Future<void> dispose();
}
```
- 抽帧命令参考：`ffmpeg -i input.mp4 -vsync 0 tmp/frame_%05d.png`（保持原始帧率，不丢帧）。
- **测量干净性**：抽帧在 prepare 阶段一次性完成，回放 nextFrame 只读文件，不计入延迟测量。

### 5.4 `lib/pipeline/frame_pipeline.dart`（等价 Step0）
```dart
class TensorInput { final Uint8List bytes; final int target; final LetterboxInfo lb; }
class FramePipeline {
  TensorInput preprocess(ui.Image rgbFrame, {int target = 192, required int srcW, required int srcH});
}
```
- 必须实现 §3.2 的 letterbox + 量化。黄金帧测试对此验证。

### 5.5 `lib/inference/pose_estimator.dart`
```dart
class PoseEstimator {
  Future<void> load({required String assetPath, DelegateMode mode});
  List<KeyPoint> infer(TensorInput input);   // 17 点, 已逆变换回原图坐标
  void switchDelegate(DelegateMode mode);
  Future<void> dispose();
}
```
- 用 `IsolateInterpreter.create(address: ...)` 做异步推理。
- 逆变换复用 §3.3。
- delegate 切换：NNAPI (`InterpreterOptions.useNnApiForAndroid=true`) / GPU (`GpuDelegateV2`) / CPU。

### 5.6 `lib/perf/performance_meter.dart`
```dart
class PerformanceMeter {
  void recordPreprocess(int ms); void recordInfer(int ms);
  PerfSnapshot get snapshot;   // 含均值/P95/fps
  void reset();
}
```

### 5.7 `lib/ui/overlay_renderer.dart`（CustomPainter）
- 绘骨架连线（conf≥0.2）、点（conf≥0.3 绿/<红）、计数、状态。
- 骨架边定义复用 Step0 `EDGES`。

### 5.8 `lib/ui/perf_panel.dart`
- 绑定 PerformanceMeter，显示 §4.1 各指标。

---

## 6. 实现顺序（增量，每步可独立验证）

```
① 工程骨架 + pubspec + Domain 复制 + Android 配置
   验证: flutter pub get 通过; dart run test 通过(锚点=5); flutter analyze 无 issue

② 离线回放: VideoReplayService → FramePipeline → PoseEstimator → 关键点日志
   验证: 黄金帧测试 — App 输出关键点 vs Step0 out_signals.csv 坐标差 ≤ 容差

③ 离线回放: + OverlayRenderer 骨架 + 接 PushupCounter
   验证: 回放 俯卧撑.mp4 计数 = 5

④ 实时相机: CameraService → FramePipeline → PoseEstimator → 骨架(不接计数)
   验证: 骨架贴合人体, 关键点不偏离

⑤ 接计数 + PerformanceMeter + PerfPanel
   验证: 性能面板实时显示延迟/FPS

⑥ delegate 切换 + 三档性能实测
   验证: NNAPI/GPU/CPU 三档 FPS 对比表
```
> 对抗式铁律：② 是 App 端 Step0。黄金帧测试不过，禁止进 ③。

---

## 7. 验收标准（核心）

### 7.1 交付物清单（缺一不验收）
- [ ] 可安装 APK（debug 可，附架构说明）
- [ ] 源码（§5 全模块 + §2 架构）
- [ ] 黄金帧测试报告（§7.2，App 关键点 vs Step0 CSV 坐标差）
- [ ] 性能报告（§7.3，离线+实时 FPS/延迟 + delegate 三档对比表）
- [ ] 离线回放录屏（计数过程）+ 实时相机录屏

### 7.2 黄金帧测试（验收方离线复核）
- 取 `俯卧撑.mp4`，App 回放输出每帧 17 关键点坐标
- 与 `step0/out_signals.csv` 逐帧对比：
  - 关键点坐标差 **≤ 5px**（中位数），P95 **≤ 15px**
  - 关键点 conf 均值差 **≤ 0.1**
- 输出 `golden_frame_report.json`：逐帧逐点差值统计
> 目的：证伪 App 预处理（旋转/量化/letterbox）引入偏差。

### 7.3 性能验收（你看 APK + 报告）
| 项 | 标准 |
|---|---|
| 离线回放 FPS | ≥10（实测，附报告） |
| 离线回放 e2eMs 均值 | <250ms |
| 实时相机 FPS | ≥10 |
| delegate 三档对比表 | CPU/NNAPI/GPU 各 FPS |
| UI 流畅 | 肉眼无卡顿 |

### 7.4 功能验收（你装 APK 自测）
| 编号 | 项 | 标准 |
|---|---|---|
| F1 | 离线回放计数 | 回放 俯卧撑.mp4 显示 5 |
| F2 | 骨架贴合 | 实时相机骨架贴人体 |
| F3 | 性能面板 | 实时显示延迟/FPS |
| F4 | delegate 切换 | 三档可切，FPS 有差异 |
| F5 | 暂停/重置 | 功能正确 |

### 7.5 架构验收（代码审查）
| 编号 | 项 | 标准 |
|---|---|---|
| A1 | Domain 零依赖 | pushup_domain.dart 不含 camera/tflite/flutter import |
| A2 | 推理 Isolate 化 | 主线程无 infer 调用 |
| A3 | pipeline 等价 Step0 | letterbox/量化逻辑等价（黄金帧测试佐证） |

---

## 8. 风险登记（承接第二版 §11 + App 特有）
| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| 旋转修正错致关键点全乱 | 高 | 致命 | 黄金帧测试 §7.2 |
| 误做 /255 归一化 | 中 | 高 | §3.2 写死, 黄金帧 |
| Dart YUV→RGB 慢致 FPS 低 | 中 | 中 | FFI/Platform Channel, 测量定位 |
| Isolate 通信开销 | 中 | 中 | PerformanceMeter 定位 |
| 真机 sensorOrientation 差异 | 中 | 中 | CameraService 探测+文档 |
| ffmpeg 抽帧依赖体积大 | 低 | 中 | 评估 ffmpeg_kit 体积或替代方案 |

---

## 附：给新同事的 3 条铁律
1. **黄金帧测试不过，不接计数**（② 是 App 端 Step0）。
2. **不做 /255 归一化**（§3.2 写死，Step0 用 [0,255] 直接量化）。
3. **所有性能数字都用 PerformanceMeter 实测**，附报告，不接受理论估算。

---

版本：M3 v1.0　｜　验收：用户 APK 自测 + 验收方离线复核黄金帧
