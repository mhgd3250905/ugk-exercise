# 交接：俯卧撑识别漏记调查

> [!IMPORTANT]
> **调查已收敛，不是当前待办。** 近距离底部肩部置信度跌落的根因与 `tooCloseGroundSpanPx=600` 的 ready 阻断已由 [`docs/modules/recognition.md` §10](modules/recognition.md#10-已知边界) 和提交 `ce3bb29` 收敛。本文仅保留 `main@cd91a4b` 时点的诊断过程与证据；后续判断以识别模块文档为准。

> 日期：2026-07-22
> 工作树：`E:/AII/ugk-post-count-miss`
> 分支：`investigate/count-miss-2026-07-22`（基于 `main@cd91a4b`）
> 任务类型：**诊断调查**（不是直接改代码，先定位根因再决定是否修）

## 1. 你的任务

用户报告**俯卧撑识别漏记**（做了但没计数 / 计数偏少）。你接手后，用户会把你把**异常日志**发给你。你的工作是用日志定位漏记发生在识别链路的哪一环，给出根因判断和修复建议，**不要在没有定位清楚根因前就改代码**。

## 2. 接手第一步

1. 完整读仓库根目录 `AGENTS.md`（项目入口、架构分层、纪律）。
2. 完整读 `docs/modules/recognition.md`（识别算法第一性原则、数据流、门控、阈值）——这是本任务的核心权威文档。
3. 读 `docs/modules/pushup-pipeline.md`（信号提取→计数的封装）。
4. 读 `docs/pushup-algorithm-remediation-2026-07-14.md`（上一轮算法整改的根因与决策，避免重复踩坑）。
5. 运行只读预检确认基线：

   ```bash
   cd E:/AII/ugk-post-count-miss
   flutter analyze                    # 必须无 issue
   flutter test test/domain_self_check_test.dart   # 硬基线 step0=5 / v3=5 / v4=3
   ```

   回放基线 **5/5/3** 是硬约束。如果基线本身已经偏了，先报告，不要改信号源。

## 3. 识别链路（漏记可能发生的环节）

```
CameraImage → YUV420→RGB → 旋转/镜像 → MoveNet 推理 → List<KeyPoint>
  → ReadyPoseGate（未 ready：判定能否进入计数态）
      ready → WristAnchor.calibrate + PushupPipeline.calibrateReadyDepth
  → 已 ready:
      SignalExtractor.toSignals → FrameSignals(torsoY, elbowAngle, ...)
      WristAnchor.isStable → handsStable（仅诊断，不门控 torso）
      PushupCounter.update(signals) → 内部 5 帧中值滤波 → CounterState.count
```

漏记可能发生在**任何一环**，按从上游到下游排查：

| 环节 | 漏记表现 | 日志关键字 | 代码位置 |
|---|---|---|---|
| MoveNet 推理 | 关键点置信度低/抖动 | `frame_error`、keypoint conf | `lib/inference/pose_estimator.dart` |
| ready 丢失 | 训练中频繁退回 reacquiringPose | `UGK lost-pose: exit ready`、`reacquiringPose` | `lib/product/ready_pose_gate.dart`、`WorkoutController._onCameraImage` |
| ready 深度标定失败 | 反复进 ready 又退出 | `ready_depth_calibration_failed` | `lib/product/pushup_pipeline.dart` |
| 腕锚点不稳 | handsStable 频繁翻转 | `UGK stable: false` | `lib/product/wrist_anchor.dart` |
| 计数器未触发 | 到了底部没 count+1 | `UGK count:` 缺失、counter `frozen`、`low/high` 不动 | `lib/pushup_domain.dart` PushupCounter |
| 帧丢弃 | 处理跟不上，掉帧 | `droppedFrames` 高、`_busy` | `WorkoutController._onCameraImage` |

## 4. ⚠️ 关键纪律（违反会埋坑，AGENTS.md / recognition.md 详细说明）

1. **`pushup_domain.dart` 保持纯 dart**，不加 Flutter/platform 依赖。
2. **绝不平均两个手腕坐标** —— 这是历史 bug 根源（见 recognition.md §2 铁律）。torsoY 是头+肩（同一刚体）的加权平均，左右腕是独立支撑点只能 AND 门控。
3. **不在生产 PushupPipeline 叠加移动平均** —— Counter 内部已有 5 帧中值滤波，再叠一层会产生双重滞后。
4. **回放基线 step0=5 / v3=5 / v4=3 是硬约束**，改了信号源必须重验。
5. **不用 `git add -A`**，显式 stage 代码文件。
6. **真实视频/csv/日志不进 git**（含人体姿态坐标，隐私）。`test/fixtures/` 是脱敏标量信号。

## 5. 日志怎么读

### 5.1 UGK tag 覆盖（`adb logcat -s flutter | grep UGK`）

```
UGK session: start #N           # 训练会话开始
UGK ready: type=... calibrated=... count=... lwY=.. rwY=..  # 进入 ready
UGK lost-pose: exit ready, keep count=N   # 丢失姿态退出 ready（15 帧无有效姿态）
UGK stable: true/false lwY=.. rwY=..      # 手腕稳定性翻转（只在变化时打）
UGK count: N torso=.. elbow=.. depth=.. stable=..   # 计数+1
```

### 5.2 运动测试日志（用户导出的 `.jsonl`）

Release 包支持用户主动开启"运动测试日志"（设置→识别诊断，默认关闭）。导出的 `.jsonl` 含逐帧：
- `frame` 编号、`processingMs`、`droppedFrames`
- 每个 keypoint 的 `x/y/confidence`
- `signals`（torsoY / elbowAngle / depthRatio / handsSupported / handsStable）
- `counter`（count / phase / frozen / calibrated / position / low / high）

**这是定位漏记的金矿**。重点看：
- 用户说"做了 N 个但只记了 M 个" → 找那 N-M 个缺失的窗口，看那段时间 `counter.position` 是不是卡在底部不回升，或 `signals.torsoY` 根本没下压到 `requiredDownY`。
- `frozen: true` 长时间不解除 → 看是哪个条件卡住（腕不稳？肘角反证？）
- `ready` 频繁 true↔false → ready_gate 的稳定性问题，不是计数器问题。

> 真实日志含人体姿态坐标，**只存本地**，不进 Git / 不贴聊天 / 不进 Issue。需要回归测试时只提取脱敏标量到 `test/fixtures/`。

## 6. 诊断工作流建议

1. 拿到用户日志后，先确认**是哪一类漏记**：完全不计 / 偶发少计 / 特定姿势少计 / 快速连做少计。
2. 在日志里定位**漏记时间窗**，看那段时间的 `signals` + `counter` 逐帧序列。
3. 形成根因假设（如"requiredDownY 标定过高" / "腕不稳冻结" / "5 帧中值滤波把快速动作抹平"）。
4. 如果能复现，**先写失败测试**（用 `test/fixtures/` 的脱敏信号复现漏记），再改代码（红→绿）。
5. 不能复现时，先报告根因假设和需要的额外信息，不要盲改。

## 7. 验证标准

- `flutter analyze` 0 issue
- `flutter test` 全绿
- `flutter test test/domain_self_check_test.dart` 保持 5/5/3
- 如果改了信号源/计数器，回放基线必须重验
- 改动只显式 `git add` 代码文件，不 `git add -A`

## 8. 当前仓库状态

- `main@cd91a4b`：含审计整改（WorkoutController 单会话生命周期 + API 超时 + Worker CSRF）+ 0.3.19 发版记录 + skill 文档
- 本分支 `investigate/count-miss-2026-07-22` 基于 main，无额外改动
- 本地 Flutter `3.44.7`（pubspec 要求 `>=3.44.0`）
- 门禁基线：`flutter analyze` 0 issue、Flutter 715/715、Worker 168/168、回放 5/5/3

## 9. 给用户的接手开场（建议）

```
已读完交接。我在 investigate/count-miss-2026-07-22 分支，基于最新 main。
我已熟悉识别链路（MoveNet→ReadyPoseGate→SignalExtractor→PushupCounter）
和关键纪律（不平均双腕、5 帧中值滤波在 Counter 内部、回放基线 5/5/3）。

请把你说的异常日志发给我。我会先定位漏记发生在哪一环（推理/ready/信号/计数），
给出根因判断，确认能复现后再改代码——不会盲改。
```
