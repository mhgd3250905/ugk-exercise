# Motion-stage Optional Nose Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 运动态在双肩信号仍可靠时，把鼻子不可见视为未知而非判负，避免标准俯卧撑低头看地面时丢失关键低点帧。

**Architecture:** 改动心脏位于 `product` 层的纯 Dart 门控 `motionPoseUsable`。准备态继续严格要求完整姿态；运动态只要求双肩逐点与平均置信度，并保留高置信手腕抬高反证。`SignalExtractor.torsoY`、深度标定、计数器和 Controller 不改。

**Tech Stack:** Flutter、Dart、`flutter_test`、现有 `PushupPipeline` 会话回放测试。

---

### Task 1: 用合成会话锁定新产品规则

**Files:**
- Modify: `test/pushup_session_replay_test.dart`

**Step 1: 写失败测试**

新增一个完整顶位→低点→顶位会话：低点鼻子置信度为 `0.05`，双肩仍可靠，只有 `motionPoseUsable` 通过的帧才送入 `PushupPipeline`；期望最终计数为 1。

同时把旧规则断言更新为新规格：

- 鼻子低置信但双肩可靠：`true`；
- 任一肩低于 `0.25`：`false`；
- 双肩平均低于 `0.3`：`false`；
- 高置信可见手腕抬高：`false`。

测试不得包含真实 JSONL、坐标日志或设备标识，只使用现有 `_pose` 合成数据。

**Step 2: 运行测试并确认 RED**

Run: `flutter test test/pushup_session_replay_test.dart`

Expected: 新增“低点鼻子缺失仍计数”的断言失败，原因是当前 `motionPoseUsable` 仍要求鼻子置信度至少 `0.25`。

### Task 2: 最小修改运动态门控

**Files:**
- Modify: `lib/product/motion_pose_gate.dart`
- Test: `test/pushup_session_replay_test.dart`

**Step 1: 写最小实现**

删除 `motionPoseUsable` 对鼻子置信度的硬要求；把 `_corePointConfidenceFloor` 精确重命名为肩部含义。保留：

```dart
leftShoulderConfidence >= 0.25 &&
rightShoulderConfidence >= 0.25 &&
shoulderConfidence >= 0.3
```

以及现有 `wristsNotClearlyRaised` 反证。不要修改 `SignalExtractor`、`PushupCounter`、深度比例、滤波窗口或 Controller。

**Step 2: 运行定向测试并确认 GREEN**

Run: `flutter test test/pushup_session_replay_test.dart`

Expected: 全部通过。

### Task 3: 同步权威识别文档

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/pushup-algorithm-remediation-2026-07-14.md`

**Step 1: 更新当前规则**

明确说明准备态仍严格要求鼻子；运动态鼻子只是 `torsoY` 的可选加权成分，不再参与 hard-negative，双肩仍是最低可信基础。记录本轮证据：旧漏记会话的关键低点帧被鼻子门控丢弃；两组明确真值 15/16 的离线反事实仍为 15/16。

不得写入原始坐标、设备标识或真实 JSONL。

**Step 2: 文档自检**

Run: `rg -n "鼻|nose|motionPoseUsable|shoulder" docs/modules/recognition.md docs/pushup-algorithm-remediation-2026-07-14.md`

Expected: 当前规则前后一致，历史规则明确标注为历史，不把历史验证结果改写成当前验证。

### Task 4: 自动化门禁

**Files:**
- Verify only

**Step 1: 运行识别定向测试与硬回放**

Run: `flutter test test/pushup_session_replay_test.dart test/domain_self_check_test.dart`

Expected: 全部通过，回放保持 step0=5、v3=5、v4=3。

**Step 2: 运行静态分析与全量测试**

Run: `flutter analyze`

Expected: 0 issue。

Run: `flutter test`

Expected: 全部通过，回放仍为 5/5/3。

Run: `git diff --check`

Expected: 无输出、退出码 0。

### Task 5: 独立六维只读审查与复验循环

**Files:**
- Review only; reviewer must not modify files

**Step 1: 启动独立审查线程**

审查需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果。审查线程输出按严重级别排序的修复清单，并引用文件与行号；不得直接修改代码。

**Step 2: 主线程修复**

每个有效问题先补失败测试，再做最小修复并重跑相关门禁。未经用户单独授权，不 commit、push 或合并。

**Step 3: 同一审查线程复验**

持续循环，直到审查结论为通过，或明确报告不可解决的外部阻塞。

### Task 6: 真机安装边界

**Files:**
- Verify only

**Step 1: 安装当前工作树 Debug 包**

使用已连接设备，保留 App 数据，不卸载、不清数据。若无 resident `flutter run`，只在自动化和审查通过后启动安装。

**Step 2: 交付人工验收步骤**

要求用户完成固定次数、最低点自然低头的标准俯卧撑，并导出新日志；主线程只把自动化和安装写成已验证，不能替用户声明动作准确率通过。
