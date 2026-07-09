# ugk-post 架构重构报告与接手审查指南

> 本报告供新接手的审查者使用。目的是让你快速进入项目、理解刚完成的重构，并**挑出设计不合理、不通顺、或重构改错的地方**。
> 作者会诚实地把已知的疑点和风险点标出来，但一定还有我没发现的问题——请用对抗式的眼光独立审查，不要默认报告是对的。
> 时间：2026-07-09　|　基线 tag：`v0.1-architecture-baseline`　|　当前 HEAD：见 `git log`

---

## 0. 你是谁、要做什么

你的角色是**红队审查者**。这个 App 刚经历一次大规模架构重构（6 步，纯结构搬迁），目标是让边界清楚、便于后续迭代。重构全程用测试守行为不变，但：

- 测试可能没覆盖到所有行为（尤其异步生命周期、真机边界条件）。
- 结构搬迁可能引入了"能编译能过测试但语义已经偏了"的问题。
- 有些设计决策是权衡，未必正确。

**你的任务**：从头阅读代码和文档，找出上述三类问题。不必客气，问题越尖锐越好。审查结论请直接在本文档末尾的"审查记录"区追加，或另起 issue。

---

## 1. 项目是什么

一个 Android 俯卧撑计数 App：手机固定正前方 → 相机实时姿态识别（MoveNet，TFLite）→ 俯卧撑计数 → 中文语音播报 → 本地记录日历。

四个页面：
- **首页**（HomePage）：今日计数 + 入口
- **训练**（WorkoutPage）：核心，实时计数
- **记录**（RecordsPage）：月历热力图
- **测试模式**（TestModePage）：离线视频回放 + 实时多 delegate 性能对比（调试用）

代码规模：lib 4926 行（32 文件），test 2094 行（87 测试）。

---

## 2. 重构前是什么样

重构前 `lib/main.dart` 是一个 **2484 行的上帝文件**，塞了全部 6 个页面 + 18 个 UI 组件 + 10 个顶层工具函数。其中 `_WorkoutPageState`（训练页）是"上帝 State"，同时承担 8 类职责：相机生命周期、推理调度、计数状态机、UI setState、语音、存储、导航、日志。

核心计数管线（关键点→信号→平滑→计数）在**训练页和回放页各手写一遍且不一致**——训练页注入了腕部稳定性门控，回放页没有。这意味着回放测试验证的逻辑 ≠ 真机跑的逻辑。

## 3. 重构做了什么（6 步，每步一个 commit）

| 步骤 | commit | 做了什么 |
|------|--------|---------|
| 0 | `2a8e9ae` | 删除 CounterConfig 的 11 个 `@Deprecated` 死字段 + frameHeight/fps |
| 1 | `c1b6deb` | WristAnchor 从 `ui/` 移到 `product/`（它是纯逻辑无 Flutter 依赖，归位） |
| 2 | `6c4d8cd` | 新建 PushupPipeline，封装 extractor→filter→counter，训练/回放共用 |
| 3 | `6220591` | 拆 main.dart：2484→21 行，6 页面独立文件 + app_theme.dart + replay_utils.dart |
| 4 | `1111bf9` | 新建 WorkoutController(ChangeNotifier)，把训练页编排逻辑从 State 抽出 |
| 5 | `f0788d8` | keypointNames 移到 pushup_domain，断开 report→inference 反向依赖 |

每步都通过了 `flutter analyze`（无 issue）+ `flutter test`（87 绿）+ release APK 编译。

## 4. 现在的架构

```
main.dart (21行)               runApp + App 根
pushup_domain.dart (600行)     纯算法，零 Flutter 依赖（领域地基）
product/                       产品规则
  ├ pushup_pipeline.dart       计数管线装配
  ├ wrist_anchor.dart          腕部稳定性门控
  ├ ready_pose_gate.dart       准备态门控
  ├ voice_prompt_player.dart   语音
  └ workout_session_store.dart 本地记录存储
control/                       编排
  ├ workout_controller.dart    训练会话编排器（ChangeNotifier）
  ├ camera_calibration.dart    相机旋转/镜像校正
  └ replay_control.dart        回放状态标志
inference/ pipeline/           基础设施（推理/帧处理）
platform/                      平台适配（camera/ffmpeg/replay）
ui/pages/ ui/                  纯展示
perf/ report/                  调试模块（主链路不依赖）
```

依赖方向：ui → control → product → pushup_domain；inference/pipeline/platform → pushup_domain。**不应有反向依赖**（有 architecture_contract_test 守护部分约束）。

---

## 5. 识别算法核心（最需要审对的逻辑）

俯卧撑识别的第一性原则：**双手腕是稳定锚点（不动），头+肩是动作（下压回升），肘角变化是确认**。

关键铁律：**同一刚体（头+肩）可以平均合成信号；两个独立支撑点（左右腕）绝不能平均，只能 AND 门控。**

这条铁律来自一个历史 bug：早期用 `pressDepthY = shoulderY - wristY`（wristY 是左右腕平均），抬一只手时平均值漂移方向和真实下压同向 → counter 无法区分 → 单手抬到下巴就误计。现在的 `torsoY`（头肩平均）做动作信号，腕只做门控，彻底分开。

详见 `docs/modules/recognition.md`。

**审查重点**：这套算法的逻辑是否真的自洽？`torsoY` + WristAnchor 双门控是否有漏洞？阈值（ampMinPx=80 等）的依据是否站得住？

---

## 6. ⚠️ 已知疑点和风险点（作者主动交代，但请独立验证）

以下是我自己觉得**可能有问题但没深究**的地方。请重点审查，可能其中就有真 bug。

### 6.1 stop 流程的状态分裂
`WorkoutController.stop()` 负责"停止硬件 + 设'保存中'状态 + notifyListeners"，但实际的**存储写入（store.append）和导航（Navigator.pop）在 State 的 `_onStopPressed` 里**，发生在 `await controller.stop()` 之后。
- 疑点：为什么"保存中"状态在 controller，保存动作在 state？这是合理的关注点分离，还是把一次原子操作劈成了两半？
- 潜在问题：如果 `controller.stop()` 抛异常，State 不会写存储也不会 pop，用户卡在"保存中"。原代码 `_stopAndSave` 是一体的，异常处理更完整。

### 6.2 WorkoutController 没有 mounted 概念
Controller 从 State 抽出后，去掉了所有 `mounted` 检查（Controller 没有 Widget 树概念）。用 `_disposed` 守卫阻止 dispose 后的 notifyListeners。
- 疑点：dispose 后如果有进行中的 async（推理/相机），回调里访问已 disposed 的字段是否安全？`_session` 守卫能覆盖所有路径吗？

### 6.3 回放页（OfflineReplayTab）的计数逻辑
重构后回放页用 `PushupPipeline.process(keypoints)`（handsStable 默认 true），但**回放页没有接 WristAnchor**。
- 疑点：回放验证的是"torsoY 计数"，但真机训练有 WristAnchor 门控。回放全绿（5/5/3）不代表真机全绿。这个差距是否可接受？回放页是否应该也模拟腕门控？

### 6.4 SignalFilter 的入队条件
`SignalFilter.smooth` 里 torsoY 只在 `handsSupported && handsStable` 时入队平滑窗口。
- 疑点：如果 handsStable 频繁翻转（腕置信度抖动），平滑窗口会时断时续，可能影响计数稳定性。

### 6.5 replay_utils.dart 的函数可见性
从 main.dart 搬出的 10 个工具函数（`resolveReplayVideo`、`writePerformanceReport` 等）去掉了 `_` 前缀变公开，放 `platform/replay_utils.dart`。
- 疑点：这些函数只被 test_mode_page 用，是否应该更内聚（放进 test_mode_page 或一个 replay service 类），而非散落的顶层函数？

### 6.6 test_mode_page.dart 仍较大（664 行）
TestModePage + OfflineReplayTab + LiveCameraTab + _FrameOverlay 都在这一个文件。
- 疑点：是否应该进一步拆？还是因为它们都是"调试模式"且共享少，保持一个文件合理？

### 6.7 颜色常量的归属
颜色常量从 main.dart 提到 `ui/app_theme.dart` 并去掉了 `_` 前缀（`_ink`→`ink`）。
- 疑点：`ink`/`green` 这种通用名字现在全局可见，有命名冲突风险吗？放 ui/ 但 control/product 层不引用——是否合理？

---

## 7. 如何开始审查（建议路径）

1. **先读文档**：`docs/modules/recognition.md`（算法核心）→ `docs/architecture-analysis.md`（债务）→ `docs/architecture-plan.md`（重构方案）。
2. **跑测试**：`flutter analyze` + `flutter test`，确认 87 绿。
3. **看 diff**：`git diff v0.1-architecture-baseline..HEAD --stat`，了解改了哪些文件。
4. **重点审**：
   - `lib/control/workout_controller.dart`（393 行，最复杂，从 State 抽出的编排逻辑，异步生命周期是否完整）
   - `lib/ui/pages/workout_page.dart`（State 与 Controller 的衔接）
   - `lib/product/pushup_pipeline.dart`（装配是否和原手写逻辑等价）
   - `test/architecture_contract_test.dart`（这些源码断言是真守护还是只是字符串匹配游戏）
5. **对抗测试**：尝试构造能打破"行为不变"假设的场景（特别是异步竞态、异常路径、资源泄漏）。

## 8. 验证命令

```bash
flutter analyze
flutter test
flutter build apk --release --split-per-abi
adb -s <device> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb -s <device> logcat -s flutter | grep UGK   # 抓诊断日志
```

回退点：`git checkout v0.1-architecture-baseline`

---

## 9. 审查记录（请在此追加你的发现）

> 格式建议：`[严重度] 文件:行 — 问题 — 建议`
> 严重度：🔴 bug / 🟡 设计问题 / 🔵 建议

（待审查者填写）

---
*本报告由重构主导者编写。报告本身可能有误——如果你发现报告与代码不符，那也是发现。*
