# ugk-post 架构现状分析

> 时间：2026-07-09
> 基线：`v0.1-architecture-baseline`（commit `c7c6593`）
> 目的：重构前的现状摸排，识别债务与边界问题。本文只做"是什么"和"问题在哪"，不改代码。

## 1. 项目概况

一个 Android 俯卧撑计数 App：相机实时姿态识别（MoveNet）→ 俯卧撑计数 → 中文语音播报 → 本地记录。功能模块清晰：首页、训练（核心）、记录日历、测试模式（离线回放 + 实时性能基准）。

| 指标 | 数值 |
|------|------|
| lib 代码 | 23 个文件，4790 行 |
| test 代码 | 17 个文件，1991 行 |
| 最大单文件 | `lib/main.dart` 2484 行（占 lib 52%） |
| 测试数 | 84（全绿） |

## 2. 当前目录结构与技术分层

```
lib/
├── main.dart              ← 【重灾区】6 个页面 + 18 个组件 + 10 个顶层函数，2484 行
├── pushup_domain.dart     ← 领域核心（纯 dart，无 Flutter 依赖）
├── control/               ← 两个互不相关的可变状态机（相机校准、回放控制）
├── inference/             ← MoveNet 推理（pose_estimator / keypoint_decoder / keypoint_log / delegate_mode）
├── pipeline/              ← 帧预处理（frame_pipeline letterbox+量化 / yuv420 转码）
├── platform/              ← 平台适配（camera / ffmpeg / 报告目录 / 视频回放服务）
├── product/               ← 产品逻辑（ready_pose_gate / voice_prompt / workout_session_store）
├── report/                ← 报告生成（performance_report / golden_frame_report）【仅测试模式用】
├── perf/                  ← 性能采集（performance_meter）【仅测试模式用】
└── ui/                    ← 渲染（overlay_renderer / perf_panel / wrist_anchor）
```

**分层意图**：domain（纯算法）→ product（产品规则）→ inference/pipeline/platform（基础设施）→ ui（展示）→ main（组装）。意图正确，但执行不彻底。

## 3. 数据流（训练主链路）

```
CameraImage (YUV420)
  → yuv420ToRgb                          [pipeline]
  → orientRgbFrame (旋转/镜像校正)        [pipeline]
  → FramePipeline.preprocess (letterbox) [pipeline]
  → PoseEstimator.infer (MoveNet)        [inference]  → List<KeyPoint> (17 点)
      │
      ├─ 未 ready: ReadyPoseGate.update   [product]    → ready?
      │     └─ ready: WristAnchor.calibrate 标定双腕基线
      │
      └─ 已 ready:
           SignalExtractor.toSignals     [domain]     → FrameSignals
           WristAnchor.isStable          [ui*]        → handsStable  ← 用 copyWith 回填
           SignalFilter.smooth           [domain]     → 平滑后 FrameSignals
           PushupCounter.update          [domain]     → CounterState.count
           VoicePromptPlayer.playCount   [product]    → 语音
```

**关键发现**：这条核心管线的装配（`toSignals().copyWith(handsStable).smooth().update()`）是 main.dart 里逐行手写的命令式代码，无封装。离线回放页另写一遍且装配不同（无 WristAnchor）。

## 4. 依赖关系图（实测 import）

```
main.dart ──→ 几乎所有模块
pushup_domain ──→ dart:math 仅此（纯 dart，洁净）✓
inference ──→ pipeline, pushup_domain           ✓ 方向正确
product/ready_pose_gate ──→ pushup_domain       ✓
ui/wrist_anchor ──→ pushup_domain               ✓
product/workout_session_store ──→ (不依赖 domain) 孤立
product/voice_prompt ──→ audioplayers           平台封装

【问题依赖】
platform/video_replay_service ──→ pipeline      ✗ 仅为 RgbFrame 类型，反向
report/performance_report ──→ inference          ✗ 调试层依赖推理实现细节
```

## 5. 债务清单（按严重度排序）

### 债务 A（严重）：main.dart 上帝文件
- **现状**：2484 行，6 个完整页面 + 18 个组件 + 10 个非 UI 顶层函数全在一个文件。
- **核心问题**：`_WorkoutPageState`（1138-1720）是"上帝 State"——同时承担 8 类职责：相机生命周期、推理调度、计数/准备/手腕业务状态机、UI setState、语音触发、调试日志、会话存储、导航副作用。直接持有 10 个非 UI 依赖对象。
- **次级重灾**：`_OfflineReplayTabState` 和 `_LiveCameraTabState` 各自重复持有 `_pose`/`_meter`/`_counter` 等并手写管线装配。
- **影响**：任何训练逻辑改动都要在这个巨型 State 里导航；测试只能覆盖纯领域层，编排逻辑无法单测。

### 债务 B（严重）：核心管线无封装，两处装配不一致
- **现状**：`toSignals → copyWith(handsStable) → smooth → update` 在训练页手写一遍，回放页又写一遍（且回放页没接 WristAnchor）。
- **问题**：没有 `PushupPipeline`/`SessionEngine` 这样的单一职责对象封装装配。两处装配不一致意味着回放测试验证的逻辑 ≠ 真机跑的逻辑。
- **`handsStable` 注入路径别扭**：`SignalExtractor.toSignals` 不知道腕部稳定性，却把它列为字段并默认 true；真实值由 `WristAnchor`（在 `ui/`）算出后用 `copyWith` 回填——UI 层的判定结果被手工缝进领域模型。

### 债务 C（中）：WristAnchor 分层错位
- **现状**：`WristAnchor` 在 `lib/ui/`，但它是纯信号门控逻辑（只 import domain，无任何 Flutter）。
- **问题**：逻辑上与 `ReadyPoseGate`、`SignalExtractor` 同属信号层，却落在 UI 目录。名不副实。

### 债务 D（中）：共享类型错位
- **`RgbFrame`**：定义在 `pipeline/frame_pipeline.dart`，但 platform（video_replay_service）、inference、ui 都需要，导致 platform 反向依赖 pipeline。
- **`KeyPoint` 索引常量**（nose=0, leftShoulder=5...）：挂在 `SignalExtractor` 上当公共常量，被 ReadyPoseGate、WristAnchor、main 多处引用。本质是 COCO-17 共享协议，应独立。

### 债务 E（中）：CounterConfig 历史包袱
- `pushup_domain.dart` 的 `CounterConfig` 携带约 10 个 `@Deprecated` 旧状态机参数（windowN/thrDownPos/...），仅为兼容 App 构造调用。领域配置混着死代码。

### 债务 F（轻）：调试模块未隔离
- `lib/perf/` + `lib/report/` 仅被"测试模式"两个 Tab 消费，训练主链路零依赖。本可隔离为独立调试包，但 `performance_report` 反向依赖 `inference/keypoint_log`，隔离时会拽回主依赖。

### 债务 G（轻）：按技术分类而非限界上下文组织
- `control/`（两个无关状态机）、`platform/`（相机+ffmpeg+目录+回放四类无关能力）按技术分类，不利于按功能理解。

### 债务 H（轻）：navigation 全命令式
- 全部 `Navigator.push(MaterialPageRoute(...))`，无命名路由。页面间依赖通过直接构造（如 `store:` 透传）耦合。

## 6. 已经做对的地方（重构时要保住）

1. **`pushup_domain.dart` 是纯 dart**：无 Flutter/平台依赖，84 测试覆盖核心算法。这是重构最稳固的地基。
2. **`CameraService` 边界最干净**：只做相机硬件适配，引用计数式广播流，不含任何推理/UI/校准逻辑。是全项目最克制的类。
3. **识别算法已按第一性原则重写**（torsoY + WristAnchor）：核心逻辑正确，回放基线（step0=5/v3=5/v4=3）稳定。
4. **架构契约测试存在**（`architecture_contract_test.dart`）：已有部分分层约束的测试守护。
5. **`ReadyPoseGate` / `SignalExtractor` / `PushupCounter` 单一职责**：领域类的职责边界本身清晰。

## 7. 重构的价值排序（供 plan 文档展开）

| 优先级 | 动作 | 收益 |
|--------|------|------|
| P0 | 抽出 `PushupPipeline`，统一训练/回放装配，内聚 handsStable 注入 | 消除两处不一致，管线可单测 |
| P0 | 拆 main.dart：各页面独立文件，`_WorkoutPageState` 瘦身为渲染 | 可维护性最大提升 |
| P1 | `WristAnchor` 从 ui/ 移到 product/（与 ReadyPoseGate 同层） | 分层归位 |
| P1 | `RgbFrame` / KeypointIndex 提到共享层 | 断开反向依赖 |
| P2 | 清理 CounterConfig 死字段 | 领域配置洁净 |
| P2 | perf/report 隔离为调试模块 | 主依赖图瘦身 |
| P3 | 命名路由、目录按限界上下文重组 | 长期可读性 |

## 8. 不变量（重构全过程必须守住）

1. `pushup_domain.dart` 保持纯 dart（无 Flutter/平台依赖）——`architecture_contract_test.dart` 已有守护。
2. 回放基线：step0=5, v3=5, v4=3。
3. 识别正确性：抬手到下巴不计数、正常俯卧撑正常计数、异常不重置计数。
4. 每步重构后 `flutter analyze` 无 issue + `flutter test` 全绿。

---

下一步：见 `docs/architecture-plan.md`（目标架构 + 小步重构路线图）。
