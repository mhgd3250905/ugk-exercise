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

## 7. 审查方法：沿重构路线步步推进验证

**不要一次性看完全部 diff 再挑毛病——那样只能发现表面问题。** 重构的很多 bug 只有亲手"重放"每一步、验证前后是否真等价才能发现。请按下面的路线，一个 commit 一个 commit 地走，每步都完成"理解→验证→评估"三件事。

### 第一步：建立基准（30 分钟）

1. `git checkout v0.1-architecture-baseline`（重构前的稳定版）
2. 读 `docs/modules/recognition.md` 理解算法第一性原则
3. 读 `docs/architecture-analysis.md` 理解重构前的问题（8 项债务）
4. 跑 `flutter analyze` + `flutter test`，记下基线是 84 测试绿
5. **亲手读** `lib/main.dart` 里的 `_WorkoutPageState`（重构前），理解它怎么工作——这是后续每步对比的基准。特别记住 `_stopAndSave`、`_onCameraImage`、`_switchCamera` 的完整逻辑。

### 第二步起：逐 commit 重放验证

每一步用 `git show <commit>` 看 diff，然后 `git checkout <commit>` 切到那一步的状态验证。对每步回答三个问题：
- **理解**：这一步的意图是什么？是否和 commit message 一致？
- **验证**：`flutter analyze` + `flutter test` 是否绿？**亲手对比**这一步前后，行为是否真等价（不是"能编译"就算等价）？
- **评估**：这步改得对吗？有没有引入语义偏移、遗漏、或更好的做法？

按这个顺序走（commit 可用 `git log --oneline v0.1-architecture-baseline..v0.2-refactor-complete` 查）：

**步骤 0**（`2a8e9ae` 清 CounterConfig 死字段）
- 验证：删的 11 个字段真的没人读吗？grep 全仓确认。`CounterConfig()` 默认值和原来传的 `frameHeight:1280,fps:30` 是否行为一致（确认这两个值从不被使用）。

**步骤 1**（`c1b6deb` WristAnchor ui/→product/）
- 验证：纯文件移动，import 路径更新是否完整。这步应该零行为变化。

**步骤 2**（`6c4d8cd` 抽 PushupPipeline）★ 重点
- 这步把训练页和回放页的手写计数装配换成了 PushupPipeline。
- 验证：`PushupPipeline.process` 内部的 `toSignals().copyWith(handsStable).smooth().update()` 是否和原来训练页手写的**完全一致**？
- 关键检查：原来 ready 分支和 lost-pose 分支会 `_filter.reset()`，重构后改成了"不 reset"（注释说窗口自然刷新）。**这是行为变化，不是纯搬迁**——确认这个变化是否正确，会不会影响计数。回放基线 5/5/3 是否还守得住？

**步骤 3**（`6220591` 拆 main.dart）★ 最大
- 这步把 2484 行拆成 6 页面 + app_theme + replay_utils。
- 验证：逐文件对比，确认搬迁没有丢代码、改逻辑。颜色常量 `_ink`→`ink` 的替换有没有漏的或错配的？私有组件可见性处理对吗？
- 检查 `test/architecture_contract_test.dart` 的断言更新——这些断言是真守护还是只是改了字符串去匹配新代码（如果是后者，守护就是空的）？

**步骤 4**（`1111bf9` 抽 WorkoutController）★★ 最复杂最危险
- 这步把训练页的编排逻辑（相机/推理/计数/语音）从 State 抽到 Controller。
- **逐方法对比** `_WorkoutPageState`（步骤 3 末尾版本）和 `WorkoutController`（步骤 4 版本）：每个方法的逻辑是否一一对应？session 竞态守卫、资源清理顺序、endOfFrame 等待是否完整保留？
- 重点：`setState`→`notifyListeners` 的替换，`mounted` 检查被去掉——dispose 后的异步回调安全吗？
- 重点：`_stopAndSave` 被拆成了 `Controller.stop()` + `State._onStopPressed`。对比原逻辑，异常路径、存储时机、导航时机是否等价？
- 如果有真机，这步务必装机实测：启动训练→计数→举手异常→恢复→停止保存，全流程是否和重构前一致。

**步骤 5**（`f0788d8` 断 report→inference 反向依赖）
- 验证：keypointNames 移到 pushup_domain 后，所有引用方都能正确拿到。纯依赖方向调整，应该零行为变化。

### 最后：整体评估

走完 6 步后，回答：
1. 重构整体方向对吗？边界是否真的更清楚了？
2. 哪些步骤改得好，哪些有遗留问题？
3. 如果让你继续优化，下一步会做什么？
4. 有没有发现"重构改错了"的地方（行为和重构前不一致且非预期）？

**你的发现请追加到本文档末尾"审查记录"区。** 每步的验证结论也建议记下来（哪步确认等价、哪步发现疑点），这样作者能据此修正。

## 8. 验证命令

```bash
flutter analyze
flutter test
flutter build apk --release --split-per-abi
adb -s <device> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb -s <device> logcat -s flutter | grep UGK   # 抓诊断日志
```

回退点：
- `git checkout v0.2-refactor-complete`（重构完成后）
- `git checkout v0.1-architecture-baseline`（重构前，算法稳定版）

---

## 9. 审查记录（请在此追加你的发现）

> 格式建议：`[严重度] 文件:行 — 问题 — 建议`
> 严重度：🔴 bug / 🟡 设计问题 / 🔵 建议

（待审查者填写）

2026-07-09 红队审查：`flutter analyze` 无 issue；`flutter test` 87/87 绿。

[🔴bug] lib/control/workout_controller.dart:156 — `switchCamera()` 调 `_pipeline.reset()` 会清空 `PushupCounter`，但 UI 的 `_count` 仍保留旧值；切换相机后第一帧 `_count = _pipeline.count` 会把累计次数覆盖成 0。重构前这里只 `_filter.reset()`，不会清 counter — 把 `PushupPipeline` 拆出“新会话清零”和“中途重获姿态/切相机只清平滑窗口”两个操作，或让 pipeline 支持保留 count 的 reset。

[🔴bug] lib/control/workout_controller.dart:274 — 重新进入 ready 时为了不清 count，代码不再清平滑窗口；lib/control/workout_controller.dart:289 丢姿态退回 ready 也同样保留旧 filter/counter 内部样本。重构前这两个路径都会 `_filter.reset()`，现在旧 torso/elbow 窗口会跨异常边界污染恢复后的前几帧 — 同上，给 pipeline 一个只清 `SignalFilter`/瞬时跟踪、不清累计计数的路径。

[🟡设计] lib/ui/pages/test_mode_page.dart:207 — 离线回放调用 `_pipeline.process(keypoints)` 使用默认 `handsStable=true`，仍没有接 `ReadyPoseGate/WristAnchor`；因此回放基线验证的是 torso-only 管线，不是训练页真实的 wrist-gated 管线，未达成“回放测试验证的逻辑 = 真机逻辑”的重构目标 — 回放页至少用首个稳定 ready 帧标定 WristAnchor 后把 `handsStable` 传入 pipeline；如果刻意只测 torso-only，要在 UI/报告里明确标成算法子集。

[🔴bug] lib/ui/pages/workout_page.dart:218 — `_onStopPressed()` 把 `controller.stop()`、`store.append()`、`Navigator.pop()` 串在一起但没有错误恢复；任一 await 抛错都会停在“正在保存训练”，且 controller 已经 `_running=false/_stopping=true`，停止按钮不可再点。lib/control/workout_controller.dart:198 也没有 finally 恢复 stopping — 用一个 try/catch 包住停止+保存，失败时显示可恢复错误并允许重试/退出；或把 stop+save 合成一个原子命令统一维护状态。

[🟡设计] lib/control/workout_controller.dart:43 — Controller 直接 new `CameraService/PoseEstimator/VoicePromptPlayer/PushupPipeline`，异步生命周期只能靠 `test/architecture_contract_test.dart:177` 这类源码字符串断言守护，造不出相机 dispose 抛错、推理挂起、保存失败、切相机保留计数等场景 — 给构造函数加可选依赖（默认真实实现即可），补最小 fake 单测覆盖 start/stop/switch 的异常和竞态。

---
*本报告由重构主导者编写。报告本身可能有误——如果你发现报告与代码不符，那也是发现。*
