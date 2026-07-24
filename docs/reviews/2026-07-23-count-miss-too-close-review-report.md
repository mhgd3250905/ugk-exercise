# 审核报告：识别漏记调查 — 近距离 ready 阻断

> 日期：2026-07-23
> 审核人：main reviewer
> 分支：`investigate/count-miss-2026-07-22`
> 提交：`ce3bb29 feat(recognition): block ready when too close to camera`
> 基线：`main@cd91a4b`（领先 1 个提交）
> 审查 worktree：`E:/AII/ugk-post-count-miss`（detached 在 `ce3bb29`）

## 1. 结论

**审核通过，建议合并。** 无 P0 / 无 P1，2 个 P2（均为非阻断性建议）。门禁由 main reviewer 本会话独立复核全绿。阈值属首轮单样本经验值，发布前需真机多样本校准——这一点提交信息和文档都已明确标注，不作为合并阻断。

## 2. 改动概要（12 files, +373/-31）

近距离窄距俯卧撑漏记根因：MoveNet 在下压到底部时丢失肩部关键点（双肩平均置信度跌到 0.12–0.18），`motionPoseUsable` 连续返回 false，lost-pose 攒满 15 帧退出 ready，跨过 50% 深度线的关键帧全被丢弃。这是模型推理边界（recognition.md §10），非计数 bug。

缓解方案（ready 阶段距离阻断）：ready 标定成功后若 `readyGroundSpan > 600px`（约 47% 帧高）则阻断 ready 并提示退后。`_tooClose` 锁存标志保持状态稳定，不重置 ready gate，退够远自动恢复。

| 层 | 文件 | 改动 |
|---|---|---|
| product | `lib/product/pushup_pipeline.dart` | 新增 `tooCloseGroundSpanPx = 600` 常量 + 注释（阈值依据） |
| control | `lib/control/workout_controller.dart` | `WorkoutStatus.tooClose` + `_tooClose` 锁存 + 阻断/恢复逻辑 + `start`/`switchCamera` 重置 |
| ui/l10n | `app_zh.arb` / `app_en.arb` + 生成文件 + `workout_page.dart` | 新增 `workoutStatusTooClose` 中英文文案 + 状态映射 |
| test | `workout_controller_test.dart` / `workout_page_test.dart` | 4 个回归测试 + 状态文案断言 |
| docs | `recognition.md` / 新增 handoff | §10 补充机制与阈值依据 + 调查交接记录 |

## 3. 项目纪律逐条核对

| 纪律 | 结果 | 证据 |
|---|---|---|
| `pushup_domain.dart` 保持纯 dart | ✅ 通过 | diff --stat 对该文件无输出；本次未触及纯 dart 地基 |
| 不平均两个手腕坐标 | ✅ 通过 | `pushup_pipeline.dart:87` `span = leftSpan > rightSpan ? leftSpan : rightSpan` 取**较大者**，非平均；`calibrateReadyDepth` 要求双腕各自置信度达标 |
| WorkoutController session 守卫 | ✅ 通过 | 新逻辑全在 `_onCameraImage` 同步段（line 427–533），无新增 await；既有 `session != _session` 守卫（line 412）仍在前置 |
| 回放基线 5/5/3 | ✅ 通过 | `domain_self_check_test.dart` 未被改动；step0→5、v3→5、v4→3 断言（line 182/203/222）全过 |
| l10n 只属于 UI | ✅ 通过 | 新文案在 ARB；domain/product/control 无 `AppLocalizations` 引用；生成的 `app_localizations*.dart` 与 ARB 一致 |
| 凭证不进 app_theme | ✅ 通过 | 无凭证相关改动 |
| 不用 git add -A | ✅ 通过 | 提交 12 files 全为代码/测试/文档，无根目录临时文件（_*.log/_*.png 等） |
| 真实视频/csv 不进 git | ✅ 通过 | 隐私扫描 handoff 文件无 secret/keypoints/邮箱命中；测试仍用 `test/fixtures/` 脱敏信号 |

## 4. 测试覆盖核对

四个回归测试精准覆盖新行为（`workout_controller_test.dart`）：

| 测试 | 覆盖点 | 状态 |
|---|---|---|
| `ready is blocked when the subject is too close`（166） | span=阈值+1 → 阻断 + 不播 ready 提示 | ✅ |
| `ready proceeds when the subject is at a safe distance`（189） | span=阈值（严格大于）→ 放行 + 播 ready | ✅ |
| `too-close re-ready after a lost pose keeps the accumulated count`（211） | 先计数1 → lost pose 退 reacquiring → 再 ready 太近 → 计数保留 + `resetTracking` 传入1 | ✅ |
| `too-close latch holds steady while the user stays too close`（259） | 连续多帧保持 tooClose，`ready_too_close` trace 事件只触发1次（leading edge 去抖） | ✅ |

`_TooCloseCountingPipeline`（2734）正确 override `readyGroundSpan` getter 并继承计数行为，能驱动安全→太近的状态翻转，设计合理。

## 5. 门禁复核（本会话独立运行）

| 门禁 | 命令 | 结果 |
|---|---|---|
| 空白错误 | `git diff --check origin/main..ce3bb29` | clean ✅ |
| 静态分析 | `flutter analyze` | No issues found ✅ |
| 全量测试 | `flutter test` | 719/719 passed ✅ |
| 回放基线 | `flutter test test/domain_self_check_test.dart` | 26 passed，5/5/3 不回归 ✅ |
| Worker | 本次未改 `workers/membership-api` | 无需 `npm test` |

## 6. 风险与遗留（均非阻断）

### P2-1：阈值 600px 来自单用户单机位单份日志（已知，提交信息和文档均明确标注）

`tooCloseGroundSpanPx = 600` 的依据是一份窄距近距离诊断日志：漏记组 659/668px vs 正常组 478px。这是单样本经验值：
- 不同身高/臂长/机型/摆放距离的用户，真实"过近"的 span 分布可能不同。
- 文档已诚实标注"宽距近距离（实测 617px）也会被阻断，但退后半步即可恢复，属于可接受的保守取舍"。
- **建议**：合并后、若计划进 Alpha/Internal 发版，安排多机型多用户真机验证，必要时把 600 调成可配置或按帧高比例。这不阻断本次合并（main 合并不等于发版）。

### P2-2：`_tooClose` 字段注释措辞略有歧义（纯文档建议）

`workout_controller.dart:118-122` 注释称"without re-running the ready gate each frame"。实际 ready gate 每帧仍 `update`（line 442），真正不反复的是**状态决策**（用锁存的 `_tooClose` 决定 tooClose/holdPose，避免每 ~500ms 闪烁），不是 ready gate 调用本身。测试 `too-close latch holds steady` 已证明去抖行为正确。建议把注释从"re-running the ready gate"改为"re-deciding the too-close verdict"，避免后人误读。不影响行为，不阻断合并。

## 7. 审核决策

- ✅ 放行合并（ff-only）到 main。
- ⏳ 合并 + push origin/main 为独立远程写入授权，等用户明确指示后再执行。
- 合并不等于发版；若后续要发版，需按 P2-1 安排真机校准，并走 `browser-platform-ops.md` 的 App+Worker 联动发版流程（本分支未改 Worker，无清单回退风险）。

## 8. 附：审查使用的只读命令

```bash
git fetch origin
git diff --stat origin/main..origin/investigate/count-miss-2026-07-22
git log -1 --format=%B origin/investigate/count-miss-2026-07-22
git diff --check origin/main..origin/investigate/count-miss-2026-07-22
# 在 detached worktree E:/AII/ugk-post-count-miss @ ce3bb29：
flutter analyze
flutter test
flutter test test/domain_self_check_test.dart
```
