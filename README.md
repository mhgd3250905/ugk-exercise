# ugk-exercise

基于手机摄像头 + 端侧姿态估计的**俯卧撑完成检测**。第一版只做计数，不做动作标准评分。

- 平台：Android（Flutter）
- 模型：MoveNet SinglePose Lightning TFLite（端侧推理，视频帧不上传）
- 方法：人体姿态关键点 + 状态机计数（`UP → DOWN → UP` 记 1 次）

> 状态：M4（Domain 层 + 状态机单测）已通过验收。工程实现进行中。

---

## 仓库结构

```
lib/pushup_domain.dart          # 纯 Dart Domain 层：信号提取/滤波/状态机计数
test/domain_self_check.dart     # 单测（含 Step0 CSV 重放 = 5 的客观锚点）
step0/step0_verify.py           # Step 0 离线可行性验证脚本（Python + MoveNet）
step0/test_step0_verify.py      # Step 0 单测
俯卧撑检测-实现计划与验收标准.md          # 任务书 v1.0（含 Step 0 验收结论）
俯卧撑检测-工程实现方案与验收标准-第二版.md  # 工程实现规格书 v2.0
```

## 算法路线

```
相机帧 → MoveNet 推理 → 17 关键点 → 取肩部 Y 起伏(主信号)
       → 滑动百分位自适应阈值 + 滞回状态机 → 计数
```

关键点检测在最难的环节成立（已在 Step 0 用真实视频验证：肩点 98% 帧置信度 ≥0.5，肩 Y 起伏 170px）。

## 复现 Step 0（需自行准备视频和模型）

> ⚠️ 视频（`俯卧撑.mp4`）、关键点产物（`*.csv`/`*.mp4`）、模型权重（`*.tflite`）
> 因含真实人脸 / 第三方 license，**未包含在本仓库**，已 gitignore。

1. 自行录制一段俯卧撑视频，命名 `俯卧撑.mp4` 放仓库根目录
2. 下载 MoveNet Lightning TFLite（int8）放入 `step0/models/`
   - 来源：`https://tfhub.dev/google/lite-model/movenet/singlepose/lightning/tflite/int8/4`
   - 脚本 `step0_verify.py` 也会自动下载到该路径
3. 安装依赖：`pip install ai-edge-litert opencv-python matplotlib numpy`
4. 运行：`python step0/step0_verify.py --video 俯卧撑.mp4 --output-dir step0`

## 运行 Domain 层单测

```bash
dart pub get
dart run test/domain_self_check.dart    # 7 项，含 Step0 CSV 重放 = 5
dart analyze                            # No issues found
```

> 注：`PushupCounter replays Step0 CSV as 5 reps` 这一项依赖 `step0/out_signals.csv`，
> 该文件因含人体关键点未提交。如需运行该项，先按上面「复现 Step 0」生成。

## 约束（第一版）

单人 · 手机固定 · 标准俯卧撑（手臂与身体两侧垂直、肘外展）· 光线充足 · 仅判断完整上下循环。

## 文档

- 任务书与验收标准：`俯卧撑检测-实现计划与验收标准.md`
- 工程实现方案（架构师级规格）：`俯卧撑检测-工程实现方案与验收标准-第二版.md`
