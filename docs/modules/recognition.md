# 俯卧撑识别算法

> 这是 App 的核心。本文记录算法的第一性原则、数据流、门控逻辑、计数器机制、阈值依据和已知边界。
> 对应代码：`lib/pushup_domain.dart`、`lib/product/ready_pose_gate.dart`、`lib/product/wrist_anchor.dart`（重构后归位 product/）

## 1. 目标

可靠识别一次俯卧撑，同时拒绝明显误触发。一次俯卧撑是：
1. 用户进入俯卧撑支撑姿态
2. 双手保持支撑位
3. 头、颈、肩相对双手下压
4. 回升到上方支撑位
5. 完成一次完整循环后计数一次

**必须拒绝**：坐姿自拍、晃手机、双手上举、单手贴脸/抬到下巴、只拍上半身。

## 2. 第一性原则

俯卧撑的稳定锚点是**双手腕**，不是头，也不是手机画面。

正常俯卧撑里（`step0` 回放实测数据）：
- 双手腕 y 基本稳定，波动 ±15px（713-735px）
- 发生显著上下变化的是**头+肩**：shoulderY 摆动 186px（466→652），noseY 摆动 283px（445→728）
- 肘部经历从直变弯再变直的角度变化
- 完成动作必须是连续姿态序列，不是某一帧达标

**由此导出三条独立的事**：
1. **锚点（门控）**：双腕稳定支撑 → 决定"能不能信这帧"
2. **动作（信号）**：头+肩整体下压回升 → 决定"发生了什么"
3. **确认**：肘角变化 → 确认"是手臂屈伸"

### 铁律：同一刚体可平均，独立支撑点绝不能平均

这是本算法最重要的设计原则，也是从历史错误中学来的：

> **历史教训**：早期用 `pressDepthY = shoulderY - wristY` 做动作信号，其中 `wristY` 是左右手腕的**平均**。抬一只手时，那只手腕 y 变化 200px+，平均值跟着漂，而漂移方向与真实肩部下压**完全同向**——counter 无法区分"手上抬"和"肩下压"，导致单手抬到下巴就误计。任何 freeze/margin 补丁都堵不住，因为脏数据从信号公式里产生。

**正确做法**：
- 头+肩是**同一刚体**（一起动）→ 可以加权平均合成 `torsoY`
- 左右腕是**两个独立支撑点**（各自不动）→ 只能用 AND 门控，绝不能平均

## 3. 数据流

```
每帧 CameraImage
  → YUV420→RGB → 旋转/镜像校正 → letterbox 预处理 → MoveNet 推理
  → List<KeyPoint>（17 个 COCO-17 关键点）

  ├─ 未 ready: ReadyPoseGate.update(keypoints) → ready?
  │     ready=true → WristAnchor.calibrate(keypoints) 标定双腕基线
  │
  └─ 已 ready:
       SignalExtractor.toSignals(keypoints) → FrameSignals(torsoY, elbowAngle, ...)
       WristAnchor.isStable(keypoints)      → handsStable
       SignalFilter.smooth(signals)         → 平滑后 FrameSignals
       PushupCounter.update(signals)        → CounterState.count
```

**重构后**（见 pushup-pipeline.md）：`toSignals → handsStable 注入 → smooth → update` 封装在 `PushupPipeline` 内，训练页和回放页共用。

## 4. 信号提取（SignalExtractor）

文件：`lib/pushup_domain.dart`

| 信号 | 计算 | 用途 |
|------|------|------|
| `torsoY` | weightedMean([左肩y, 右肩y, 鼻y], [三者 conf]) | **动作信号**（头肩刚体的垂直位置） |
| `elbowAngle` | 左右肩-肘-腕角度的加权平均 | 肘角变化确认 |
| `pressDepthY` | shoulderY - wristY | **已弃用**（历史遗留，counter 不再用） |
| `handsSupported` | wristsBelowShoulders（双腕在肩下方 ≥40px） | 基础支撑位检查 |
| `shoulderConf/elbowConf/noseConf` | 各关节置信度 | 信号可用性门控 |

## 5. 腕部锚点门控（WristAnchor）

文件：`lib/ui/wrist_anchor.dart`（重构后 → `lib/product/wrist_anchor.dart`）

### 机制
- ready 时 `calibrate(keypoints)` 快照双腕 y 作基线
- 每帧 `isStable(keypoints)` 判定支撑是否可信

### isStable 规则（第一性原则 + 真机教训）

> **历史教训**：最初要求"双腕置信度都 ≥0.3 才算稳定"。但真机上撑地的手腕经常置信度低（手贴地面、角度刁钻，MoveNet 检测不稳），导致正常俯卧撑每隔几帧就被判不稳定而冻结计数，举手恢复后尤其严重（恢复时腕置信度本就偏低，持续跌破 0.3 → 完全不计）。

**正确规则**：
- 高置信度的腕（≥0.3）**必须**稳定（偏离基线 ≤50px）
- 低置信度的腕**豁免**（看不见就无法判定它离开了支撑）
- 双腕都低置信度 → 不可信 → false

| 场景 | 行为 | 正确性 |
|------|------|--------|
| 正常俯卧撑，一腕 conf 偶尔跌破 0.3 | 另一只稳 → true | ✓ 不误杀 |
| 抬手到下巴（手高 conf + 偏离 200px） | 那只腕可见且偏离 → false | ✓ 正确拦截 |
| 相机平移（双腕高 conf 都偏离） | 都可见都偏离 → false | ✓ 正确拦截 |
| 双腕都低 conf（全盲） | 不可信 → false | ✓ |

### 阈值依据
- `maxDriftPx = 50`：step0 正常俯卧撑腕波动 ±15px，50px 留 3 倍余量；抬手偏离 200px+ 立即触发。
- `minConf = 0.3`：与 counter 的 confThr 一致。

## 6. 计数器（PushupCounter）

文件：`lib/pushup_domain.dart`

### 可用性门控（每帧）
一帧"可用"（参与计数）需同时满足：
- `torsoY` 存在且有限
- `handsSupported == true`（双腕在肩下方）
- `handsStable == true`（双腕在基线附近）
- `shoulderConf >= 0.3`
- `elbowAngle` 存在
- `elbowConf >= 0.3`

不可用帧：hold 计数状态（不推进、不回退、不清零）。

### 动作序列检测
1. `motionY = torsoY` 加入 `_samples`
2. 局部中值滤波（窗口 5）去抖
3. 全历史百分位（pLow=0.05, pHigh=0.95）算鲁棒幅值 `amp`
4. `amp < ampMinPx(80)` 时不评估 rep（信号未达有意义幅度）
5. 自适应阈值 `thr = max(thrRatio*amp, ampMinPx)`
6. 滞回带：`enterDown = low + 0.65*amp`，`enterUp = low + 0.35*amp`（死区 0.30*amp 防抖）
7. 武装态下：信号进入 down 带 + 摆幅 ≥ thr + 肘角有有效变化 → 计数 +1，解除武装
8. 信号回到 up 带 → 重新武装，重置 valley 和肘角极值

### 肘角确认
- 最低肘角 ≤ `145°`（确认手臂弯过）
- 肘角变化 ≥ `25°`（确认是屈伸，不是固定弯曲）
- 拒绝"肩部上下动但肘不弯"（相机/身体整体平移）

### 异常处理
- 不可用帧 hold 状态，不清零计数
- 异常（举手）导致退回准备态时：**保留已完成计数**，重新 ready 后继续累计

## 7. 阈值一览与依据

| 参数 | 值 | 依据 |
|------|-----|------|
| `ampMinPx` | 80 | Gaussian 噪声 ±20px 的 p5-p95 范围 25-50px，80px 永不误触；video4 最小真实 rep 摆幅 106px |
| `thrRatio` | 0.5 | 自适应：小幅度动作用比例阈值，保底用 ampMinPx |
| `hystHigh/hystLow` | 0.65/0.35 | 死区 0.30*amp 防止临界处反复计数 |
| `elbowBentMaxDegrees` | 145 | 手臂要明显弯过；相机平移时肘角接近 180° |
| `elbowAngleDeltaMinDegrees` | 25 | 排除"固定弯曲但无屈伸" |
| `wristSupportMarginPx` | 40 | 正常支撑腕在肩下方 ~240px，6 倍余量 |
| `wristAnchor.maxDriftPx` | 50 | 正常俯卧撑腕波动 ±15px |
| `confThr` | 0.3 | 与 ReadyPoseGate 一致 |

## 8. 已覆盖的对抗测试

`test/domain_self_check_test.dart`、`test/wrist_anchor_test.dart`：
- 坐姿/只拍上半身（缺关键点）→ 不计
- 双手上举 → 不计
- **抬手到下巴/面部**（torsoY 不动 + 一腕偏离）→ 不计
- 肩部动但肘不弯 → 不计
- 肘固定弯曲无屈伸 → 不计
- 相机平移（双腕都偏离）→ 不计
- ±20px Gaussian 噪声 → 不计
- 低幅度（5px）→ 不计
- 低置信度帧 → 不计
- 双腕置信度豁免（一只低 conf 另一只稳）→ 正常计数
- 真实回放：step0=5, v3=5, v4=3

## 9. 已知边界

当前算法**无法判断手掌是否真正接触地面**：单目 2D 姿态无深度信息，MoveNet 只给关节位置和置信度。当前用"双腕持续在支撑位 + 腕稳定性"作为最小可用替代。

## 10. 后续优化方向（若启发式达上限）

1. 继续积累真机负样本，每个误触发先写回归测试
2. 考虑轻量姿态分类（17 关键点归一化后做 up/down/non-pushup 分类），不引入重模型
3. 暂不建议引入视频动作识别网络，除非样本证明启发式无法支撑
