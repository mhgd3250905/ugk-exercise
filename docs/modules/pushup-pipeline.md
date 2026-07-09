# PushupPipeline（计数管线）

> 文件：`lib/product/pushup_pipeline.dart`
> 职责：封装俯卧撑计数的核心管线——关键点 → 信号 → 平滑 → 计数。

## 为什么存在

重构前，`keypoint → toSignals → copyWith(handsStable) → smooth → update` 这条链在**两个地方各手写一遍且不一致**：
- 训练页：注入了 `handsStable`（WristAnchor 算出）
- 回放页：没注入 `handsStable`

这意味着回放测试验证的逻辑 ≠ 真机跑的逻辑。PushupPipeline 把装配收敛到一处，两处共用。

## 接口

```dart
class PushupPipeline {
  PushupPipeline({CounterConfig config = const CounterConfig()});

  int get count;                          // 当前计数
  FrameSignals? get lastSignals;          // 最近一帧平滑后信号（诊断用）

  CounterState process(List<KeyPoint> keypoints, {bool handsStable = true});
  void reset();                           // 清 filter + counter（新会话用）
  void resetTracking({int? count});        // 清瞬时跟踪，保留累计次数
}
```

## 设计要点

- **不持有 WristAnchor**：腕稳定性是门控信号，由调用方算好后传入 `process(handsStable:)`。训练页用 WristAnchor 算，回放页传 `true`。这样 pipeline 不掺 ready-state 逻辑，单一职责。
- **`lastSignals` getter**：给诊断日志（UGK count 日志的 torso/elbow）和未来调试用。
- **`reset()` 清 filter + counter**：用于全新会话。
- **`resetTracking()` 清瞬时跟踪但保留 count**：用于切相机、重新 ready、lost-pose 恢复。这样旧平滑窗口和检测状态不会跨异常边界污染新动作，累计次数也不会归零。

## 测试

`test/pushup_pipeline_test.dart`：
- 合成 rep 能正确计数
- `handsStable=false` 冻结计数
- `reset()` 清零

## 数据流

```
keypoints (17 COCO-17 点)
  → SignalExtractor.toSignals        → FrameSignals(torsoY, elbowAngle, handsSupported, conf...)
  → .copyWith(handsStable: ...)      → 注入腕门控
  → SignalFilter.smooth              → 平滑后 FrameSignals
  → PushupCounter.update             → CounterState.count
```

详见 [识别算法](./recognition.md)。
