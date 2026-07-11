# WristAnchor（腕部锚点门控）

> 文件：`lib/product/wrist_anchor.dart`（已从 `lib/ui/` 归位）
> 职责：ready 时标定双腕支撑基线，并提供运动态诊断信息（`handsStable`）。

## 第一性原则

俯卧撑的锚点是双手腕——ready 阶段用它们确认用户进入了支撑环境。进入运动态后，近距离下压会让腕部离屏或产生透视抖动，因此漂移结果只用于诊断，不再决定是否计数。

**铁律**：左右腕是两个**独立**支撑点，只能 AND 门控，**绝不能平均**。平均两腕正是历史 bug 的根源（一只手动了，平均值漂，伪造下压信号）。

## 接口

```dart
class WristAnchor {
  WristAnchor({this.maxDriftPx = 50, this.minConf = 0.3});

  void calibrate(List<KeyPoint> keypoints, {sourceHeight = 1280});
  bool isStable(List<KeyPoint> keypoints, {sourceHeight = 1280});
  bool get isCalibrated;
  void reset();
}
```

## isStable 规则（含真机教训）

> **历史教训**：最初要求"双腕置信度都 ≥0.3"。但真机上撑地手腕常低置信度（手贴地面角度刁钻），导致正常俯卧撑每隔几帧被冻结，举手恢复后尤其严重→完全不计。

**正确规则**：
- 高置信度腕（≥0.3）**必须**稳定（偏离基线 ≤50px）
- 低置信度腕**豁免**（看不见无法判定它离开）
- 双腕都低置信度 → 不可信 → false

| 场景 | 行为 |
|------|------|
| 正常俯卧撑，一腕偶跌 conf | 另一只稳 → true |
| 抬手到下巴（高 conf + 偏离） | 可见且偏离 → false |
| 相机平移（双腕都偏离） | false |
| 全盲（双腕都低 conf） | false |

## 阈值依据

- `maxDriftPx = 50`：以 1280px 高度为基准；输入先按 `sourceHeight` 归一。step0 正常俯卧撑腕波动 ±15px，50px 留 3 倍余量。
- `minConf = 0.3`：与 counter 的 confThr 一致。

## 测试

`test/wrist_anchor_test.dart`：覆盖上述场景与 720/1280 尺度一致性。

## 当前在管线中的位置

`isStable` 的结果作为诊断信息传入 `PushupPipeline.process()`，但不会冻结 torso 信号。运动态只在手腕高置信可见且明确离开支撑位置时使用反证；低置信/不可见腕不否决真实动作。详见 [识别算法](./recognition.md)。
