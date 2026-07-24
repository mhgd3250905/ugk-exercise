# 窄距俯卧撑计数异常排查交接（未完成）

日期：2026-07-22
分支：`feat/workout-pose-guide-recovery`
状态：**诊断已初步完成但原修复方向被否，计数修复未落地；剪影移除改动已落地待提交**

> 给新会话：本文件是上一会话的诚实交接。计数修复部分经历过两次失败（自编测试导致假绿），新会话必须从真实日志数据重新出发。

## 一、本次会话已落地、可保留的改动（剪影移除）

这些改动经过测试，与计数 bug 无关，可以独立提交：

- 移除 `assets/images/workout_pose_guide_standard.png` 和 `workout_pose_guide_narrow.png`
- `lib/ui/pose_feedback/workout_pose_guide.dart` 改为透明占位 frame（保留两个 UI 锚点的对齐逻辑，不渲染图片，留待未来补素材）
- `lib/ui/pages/workout_page.dart` 加 `_poseGuideTopAnchorFraction` / `_poseGuideBottomAnchorFraction` 把锚点传给 guide
- 文案"剪影"→"指引"：`lib/l10n/app_zh.arb`、`lib/l10n/app_zh.arb` 生成文件、`tool/tts/pushup_prompts.srt`、`docs/modules/recognition.md`、`docs/modules/voice-themes.md`、`docs/modules/workout-controller.md`、`docs/design/app-ui-v1.md`
- 测试更新：`test/workout_pose_guide_test.dart`、`test/workout_page_test.dart`、`test/architecture_contract_test.dart`
- `flutter analyze` 零 issue，`flutter test` 全量绿

验证状态（上一会话亲自跑）：analyze 干净、全量测试通过、Debug 包带会员配置构建并装机验证过 UI。

## 二、计数 bug 诊断（已确认的事实，新会话直接用）

### Bug 现象

用户做窄距俯卧撑，App 出现两种异常：
1. **做了没数**：ready 后 21 秒稳定训练段（15:01:58→15:02:19），App 只数了 0→1，远少于实际做的
2. **假数**：重新 ready 后（15:02:28→15:02:56）App 连数到 10，但每次计数瞬间 elbow≈170°（几乎伸直），并未真正下压

### 数据来源

真机日志：`trace_narrow.jsonl`（3.5MB，JSONL 格式，1469 帧 + 23 事件）

**真机上的位置**：`/data/data/com.ugkexercise.ugk_exercise/files/recognition_traces/recognition_20260721150150656541.jsonl`

**导出命令**（设备序列号 `QSG6Q8IFDMDELVGQ`）：
```bash
adb -s QSG6Q8IFDMDELVGQ shell run-as com.ugkexercise.ugk_exercise cat files/recognition_traces/recognition_20260721150150656541.jsonl > E:/AII/trace_narrow.jsonl
```

**本地副本**：`E:/AII/trace_narrow.jsonl`（上一会话已拉取，但新会话建议重新导出确认未被覆盖；若 App 重装会清掉，需用户重做一次窄距并开识别日志）

设备可能掉线，重连后 `adb devices -l` 确认序列号。

### Session 时间线（机器 ground truth，来自事件流）

```
15:01:50  session_start（窄距）
15:01:58  ready_enter（count=0）
15:01:58 → 15:02:19  稳定训练 21 秒 ← "做了没数"发生在这段
   App 只数了 0→1
15:02:19  lost_pose_exit_ready（count 保留=1）
   ← 这是用户故意举手测试 lost-pose，是正确行为，不是 bug
15:02:28  ready_enter（count=1）
15:02:28 → 15:02:56  稳定训练 28 秒，App 数了 1→10 ← "假数"在这段
15:02:56  session_stop
```

### 核心事实（用真实数据确认过，**不是假设**）

**MoveNet 偏移帧的关节位置（关键纠正）**：

在 count 2-10 段（frame≥1020）里，torsoY>350 的"偏移帧"（157 帧）：
- 鼻子 y：min=156，**median=322**，max=516
- 左肩 y：min=204，median=301，max=416
- 右肩 y：min=195，median=301，max=416
- torsoY：min=352，median=543，max=765

真实帧（torsoY 在 150-350，292 帧）：
- 鼻子 y：min=56，**median=94**，max=201

**所以偏移帧的关节并不在画面物理边缘**（图像高 720，边缘是 y<108 或 y>612）。偏移帧的鼻子中位数 322、肩 301，是在**躯干中段**。MoveNet 把头/肩整体向下偏移到躯干中段，置信度 0.4-0.5。

**个别帧 torsoY 飙到 700+（如 f1062 torsoY=722），但其鼻子 y 其实是 466、肩 y 是 354-383**——是加权平均在高 conf 关节偏移时被拉高，不是关节本身在画面底。

### 置信度分布（有部分区分力，但不够干净）

偏移帧 vs 真实帧的鼻子置信度分布（count 2-10 段）：

| nose conf | 偏移帧 | 真实帧 |
|-----------|--------|--------|
| <0.3 | 28 | 2 |
| 0.3-0.4 | 23 | 1 |
| 0.4-0.5 | 83 | 52 |
| 0.5-0.6 | 18 | 50 |
| 0.6-0.7 | 4 | 67 |
| ≥0.7 | 1 | 120 |

- 偏移帧鼻子 conf 中位数 **0.43**，真实帧 **0.64**
- 但 0.4-0.5 区间重叠严重（偏移 83 + 真实 52）
- `minConf=0.5` 能抓 134/157 偏移帧，但会误杀 55/292=19% 真实帧（太多）
- 单靠置信度无法干净分离

## 三、已尝试并被否的修复方向（新会话**不要**重复）

### ❌ 方向 1：边缘带过滤（"贴边 = 钳制"）

**前提错误**：假设偏移帧关节在画面边缘。实际在躯干中段（y≈300）。`y>0.9×frameHeight` 的判别条件永远不触发。

### ❌ 方向 2：百分位收紧（pHigh 0.95→0.8）

把幅度统计的 high 百分位收紧到 0.8。**破坏回放基线**：`test/pushup_session_replay_test.dart` 和 `test/domain_self_check_test.dart` 共 5 个测试失败（quick cycle、long wait、first rep、step0=5）。原因：真实短暂 dip（如 5 帧占 45 帧窗口的 11%）也会被 top-20% 排除带误杀。

### ❌ 方向 3：dipPeak 跳变守卫（peakJumpFraction）

给 `_dipPeak` 增长加单帧跳变阈值。**对"单帧跳变"有效，对"渐进爬升"失效**。用真实日志 f292→f302 的序列（358→377→435→469→501→580→541→663→711，逐帧涨 19-122px）复现：守卫被绕过，count=1 假计数。

**这个方向最初用自编测试数据（单帧跳变、i%7 离散）"验证通过"，是假绿**——教训：测试数据必须取自真实 trace 序列。

### ❌ 方向 4：物理上限（readyTopY + readyGroundSpan）

用 ready 标定值算"物理最大下压深度"作为 dipPeak 上限。**不可行**：trace 里第二次 ready 的 `readyTopY=378 + readyGroundSpan=481 = 859`，而偏移 torsoY 才 700——偏移值在物理上限内，挡不住。原因：用户构图时手腕支撑位本来就在画面偏下，span 大，物理上限高。

## 四、给新会话的建议方向（未验证，需用真实数据评估）

以下方向**都还没试**，新会话要从数据出发判断哪个可行：

1. **置信度 × 位置的联合判别**：单看置信度有 0.4-0.5 重叠区，单看位置在中段。但联合（如"鼻子 y 偏离 ready 基线超过某阈值 AND conf<0.6"）可能有更好的分离度——需要用 trace 的全部偏移帧/真实帧做 ROC 分析确认。

2. **时序一致性（多帧窗口）**：偏移帧是否成簇出现？真实下压是平滑的周期，偏移是否表现为"突然整体下移再突然回来"？分析偏移帧的连续性长度、与相邻帧的差分。

3. **跨关节一致性**：偏移帧里鼻子（0.43）和肩膀（0.7-0.75）置信度不同步——真实帧两者都高（0.64/0.88）。鼻子单独低置信度而肩膀正常，可能是头被遮挡的信号。但要区分"真低头（下压时鼻子确实更难看到）"和"偏移"。

4. **counter 内部的鲁棒统计升级**：不只是 dipPeak，整个 `_percentile` / `_samples` 处理链都容易被偏移污染。考虑用 MAD（中位绝对偏差）或 IQR 剔除，但要先在真实 trace 上验证不破回放基线。

**任何方向都必须**：
- 先用 `E:/AII/trace_narrow.jsonl` 的真实序列写复现测试（红）
- 修复后让复现测试绿
- 回放基线 5/5/6 全绿（`test/pushup_session_replay_test.dart`）
- 全量测试绿、analyze 干净
- 真机重做窄距 + 标准俯卧撑复测

## 五、代码位置参考

- `lib/pushup_domain.dart`：
  - `SignalExtractor.toSignals`（:150）—— torsoY 加权平均（:204），minConf=0.1（注意：SignalExtractor 实例的 minConf 默认 0.1，但下游各消费者用自己的阈值）
  - `PushupCounter.update`（:503）—— 主计数循环
  - `_pushMedian`（:712）—— 5 帧中位数平滑
  - `_percentile`（搜 `_percentile`）—— 窗口百分位
  - `_step`（:628）—— 相位机，dipPeak 追踪（:653 附近）
  - `CounterConfig`（:377）—— 所有阈值常量
- `lib/product/pushup_pipeline.dart`：`PushupPipeline.process`（:84），`calibrateReadyDepth`（:49）
- `lib/control/workout_controller.dart`：`_onCameraImage`（:299）—— keypoints 分发给 4 个消费者
- `lib/product/motion_pose_gate.dart`：`motionPoseUsable`—— lost-pose 判定（用户故意举手那次是正确行为）

## 六、本次会话的经验教训（写在这里提醒新会话）

1. **测试数据必须取自真实 trace**，不能自编。自编数据会按自己的假设构造，掩盖真实 bug 形态。
2. **不要抓住一个特征就冲**。偏移帧的位置、置信度、时序都要交叉验证，找到真正可靠的判别特征再设计修复。
3. **"边缘钳制"是误诊**。MoveNet 实际是把关节偏移到躯干中段，不是画面边缘。任何基于"画面边缘"的方案都不适用。
4. 真机日志是唯一事实源。代码注释、之前的设计文档、本文件之外的假设，都要用 trace 数据验证。
