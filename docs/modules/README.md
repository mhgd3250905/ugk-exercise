# ugk-post 模块需求说明

> 各模块的职责、接口契约、关键决策依据。按层组织。
> 配合 `docs/architecture-analysis.md`（现状）和 `docs/architecture-plan.md`（重构方案）阅读。

## 目录

### 核心领域（domain）
- [识别算法](./recognition.md) — 俯卧撑计数的完整说明：第一性原则、信号流、门控、计数器、阈值依据

### 产品规则（product）
- [账号与会员系统](./membership.md)
- [准备态门控 ReadyPoseGate](./ready-pose-gate.md)
- [腕部锚点 WristAnchor](./wrist-anchor.md)
- [计数管线 PushupPipeline](./pushup-pipeline.md)（重构后）
- [会话存储 WorkoutSessionStore](./workout-session-store.md)

### 基础设施（inference / pipeline / platform）
- [姿态推理 PoseEstimator](./pose-estimator.md)
- [帧预处理 FramePipeline](./frame-pipeline.md)
- [相机服务 CameraService](./camera-service.md)

### 编排（control）
- [训练编排器 WorkoutController](./workout-controller.md)

### UI（ui）
- 页面与组件说明（重构后补充）

---

> 注：标注"（重构后）"的模块尚不存在，是 `architecture-plan.md` 规划的目标。现有模块文档描述当前实现。
