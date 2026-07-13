# ReadyPoseGate（准备态门控）

> 文件：`lib/product/ready_pose_gate.dart`
> 职责：判断用户是否以可见、居中、稳定的俯卧撑姿态入镜，持续足够时间后才允许开始计数。

## 为什么存在

计数前必须确认用户真的摆好了俯卧撑支撑姿势，而不是路过镜头/坐着/只拍上半身。这是计数的第一道闸门。

## 接口

```dart
class ReadyPoseGate {
  ReadyPoseGate({
    this.confidenceThreshold = 0.3,
    this.stableDuration = const Duration(milliseconds: 500),
    this.centerMarginRatio = 0.1,
    this.maxJitterPx = 30,
    this.minWristBelowHipRatio = 0.3,
  });

  bool update({keypoints, frameWidth, frameHeight, at});  // 推进判定，返回是否 ready
  bool isPoseVisible(List<KeyPoint> keypoints, {sourceHeight = 1280});
  void reset();
}
```

## ready 条件（update 全部满足才返回 true）

1. 17 个关键点齐全
2. 画面宽高有效
3. **核心关节置信度达标**（≥0.3）：鼻、双肩、双腕、双髋
4. **双腕在肩下方支撑位**（`wristsBelowShoulders`，1280px 基准 margin 20px）
5. **双腕分别明显低于同侧髋部**：`wristY - hipY >= 0.3 * (hipY - shoulderY)`；左右独立 AND，不平均
6. 同侧 `hipY - shoulderY` 必须大于 0，避免无效躯干尺度错误通过
7. 姿态中心在画面安全范围内（边距 10%）
8. 姿态中心**稳定至少 500ms**（1280px 基准抖动 >30px 重置计时）

20/30px 都按 `frameHeight` 换算到真实源坐标，因此 720px 与 1280px 输入的判定比例一致。
腕髋门槛使用同侧躯干高度作尺度，因此同样不依赖固定像素距离。

## isPoseVisible（严格姿态检查）

供 `update` 复用：要求核心关节可见 + 双腕支撑 + 双腕明显低于同侧髋部。该腕髋条件只用于进入准备态；训练中的持续校验仍使用更宽松的 `motionPoseUsable`，允许近距离时肘腕离屏。

## 与其他模块的关系

- 复用 `SignalExtractor.wristsBelowShoulders`（双腕支撑检查）
- ready 触发时，调用方同时调 `WristAnchor.calibrate` 标定腕基线
- `motionPoseUsable` 在训练态处理 lost-pose 容忍

## 测试

`test/ready_pose_gate_test.dart`：覆盖低置信度、上半身自拍、双手上举、单手离支撑、坐立垂手、无效躯干尺度、稳定计时、越界、关键点不足等。

## 不变量

`ReadyPoseGate` 只依赖 `pushup_domain`，无 Flutter/平台依赖。
