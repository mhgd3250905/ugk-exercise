# PushupPipeline（计数管线）

> 文件：`lib/product/pushup_pipeline.dart`
> 职责：封装俯卧撑计数的核心管线——关键点 → 信号 → 计数。

## 为什么存在

重构前，关键点提取与计数装配在训练页和回放页各写一遍，容易产生行为差异。

这意味着回放测试验证的逻辑 ≠ 真机跑的逻辑。PushupPipeline 把装配收敛到一处，两处共用。

## 接口

```dart
class PushupPipeline {
  PushupPipeline({CounterConfig config = const CounterConfig()});

  int get count;                          // 当前计数
  FrameSignals? get lastSignals;          // 最近一帧提取信号（诊断用）
  double? get lastDepthRatio;              // 当前头肩相对下压比例（诊断用）

  bool calibrateReadyDepth(
    List<KeyPoint> keypoints, {
    double sourceHeight = 1280,
  });                                     // 准备态标定 50% 最小下压线

  CounterState process(
    List<KeyPoint> keypoints, {
    bool handsStable = true,
    double sourceHeight = 1280,
    RepCompletionDecision repCompletionDecision = RepCompletionDecision.allow,
  });
  void reset();                           // 清 counter（新会话用）
  void resetTracking({int? count});        // 清瞬时跟踪，保留累计次数
}
```

## 设计要点

- **不持有 WristAnchor**：训练页仍可传入 `handsStable` 作为诊断信息，但它不再冻结 torso 平滑或计数。近距离下压时腕部离屏/抖动属于正常情况。
- **只平滑一次**：`PushupCounter` 内部的 5 帧中值滤波负责抑制单帧毛刺；Pipeline 不再叠加 5 帧移动平均，避免完成动作后的计数滞后和快动作漏计。
- **统一坐标尺度**：按 `sourceHeight` 将关键点等比映射到既有 1280px 高度基准，再使用已回放验证的 80/20px 阈值；UI 覆盖点仍保留原始坐标。
- **准备态相对深度**：ready 时以 `torsoY` 为头肩初始高度，以两只可靠手腕中更靠下者为地面高度；动作必须下压两者间距的 50% 才能进入 down 相位。这样主要深度门槛随拍摄远近同比缩放，固定像素值只保留为 MoveNet 抖动的最低噪声保护。
- **小尺度摆幅一致性**：已标定会话使用 `max(50px, min(80px, 50%*groundSpan))` 作为摆幅地板；因此人物在画面中较小时，同样的相对动作不会被 80px 固定门槛额外加深要求，同时极小人物的 MoveNet 抖动也不能把地板降到 50px 以下。未标定的 CSV 回放继续使用 80px。
- **双腕不平均**：左右腕分别通过置信度与有效高度检查，只选择更保守的地面高度，避免重引入历史上的“平均腕坐标污染动作信号”问题。
- **`lastSignals` getter**：给诊断日志（UGK count 日志的 torso/elbow）和未来调试用。
- **完成态决策只作用于顶部**：`repCompletionDecision` 默认为 `allow`，因此常规俯卧撑行为不变。窄距模式可在完整 torso 循环返回顶部时传 `reject` 否决本次动作，或在肘腕短暂不可见时传 `wait` 保留当前 dip，等待后续可靠顶部帧；它不要求底部手臂可见。
- **`reset()` 清 counter**：用于全新会话。
- **`resetTracking()` 清瞬时跟踪但保留 count**：用于切相机、重新 ready、lost-pose 恢复。这样旧平滑窗口和检测状态不会跨异常边界污染新动作，累计次数也不会归零。

## 测试

`test/pushup_pipeline_test.dart`：
- 合成 rep 能正确计数
- 手臂离屏仍可通过 torso 完成计数
- `handsStable=false` 不冻结 torso 运动
- 1280px 与 720px 源高度下的等价动作计数一致
- 45% 的准备后调整不计，达到 50% 的完整动作计数
- 近景与远景的相同比例动作行为一致
- `groundSpan < 160px` 的小尺度人物完成 60% 相对动作仍计数
- 小尺度人物 45% 的准备后调整不计，极小 `groundSpan` 下约 25px 往返抖动不计
- 顶部动作类型证据 `wait` 后恢复为 `allow` 仍只计一次，`reject` 则解决本次 dip 但不计数
- `reset()` 清零

## 数据流

```
keypoints (17 COCO-17 点)
  → 按 sourceHeight 等比归一到 1280px 高度基准
  → ready 时标定 torsoTop、wristGround、minDownY
  → SignalExtractor.toSignals        → FrameSignals(torsoY, elbowAngle, handsSupported, conf...)
  → .copyWith(handsStable: ...)      → 附加腕部诊断信息（不门控）
  → PushupCounter.update(minDownY, 会话摆幅地板, repCompletionDecision)
                                      → 内部中值滤波 → CounterState.count
```

详见 [识别算法](./recognition.md)。
