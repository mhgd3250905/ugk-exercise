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
  });

  bool update({keypoints, frameWidth, frameHeight, at});  // 推进判定，返回是否 ready
  bool isPoseVisible(List<KeyPoint> keypoints);            // 训练态持续校验
  void reset();
}
```

## ready 条件（update 全部满足才返回 true）

1. 17 个关键点齐全
2. 画面宽高有效
3. **核心关节置信度达标**（≥0.3）：鼻、双肩、双腕、双髋
4. **双腕在肩下方支撑位**（`wristsBelowShoulders`，margin 20px）
5. 姿态中心在画面安全范围内（边距 10%）
6. 姿态中心**稳定至少 500ms**（抖动 >30px 重置计时）

## isPoseVisible（训练态持续校验）

训练中每帧调用。比 ready 宽松（不要求稳定计时），但仍要求核心关节可见 + 双腕支撑。返回 false 时进入 15 帧容忍期，超时退回 ready。

## 与其他模块的关系

- 复用 `SignalExtractor.wristsBelowShoulders`（双腕支撑检查）
- ready 触发时，调用方同时调 `WristAnchor.calibrate` 标定腕基线
- `isPoseVisible` 在训练态 gate 计数（false → 进入 lost-pose 容忍）

## 测试

`test/ready_pose_gate_test.dart`：覆盖低置信度、上半身自拍、双手上举、单手离支撑、稳定计时、越界、关键点不足等。

## 不变量

`ReadyPoseGate` 只依赖 `pushup_domain`，无 Flutter/平台依赖。
