# 审核报告：`feat/audio-production-2026-07-23` — 音频补全 + 窄距误报修复

> 日期：2026-07-24
> 审核人：main reviewer
> 分支：`feat/audio-production-2026-07-23` → `main`
> 提交：`c6c6dc9`（单提交），24 files, +313/-33
> 基线：`origin/main@e003ef6`（审核时 main 与 origin 同步）
> 审查 worktree：`E:/AII/_review-audio-production-2026-07-23`（detached @ `c6c6dc9`）
> 注：本分支**未创建 PR**（用户口头授权 push 后审核），仅有远程分支

## 1. 结论

**审核通过，建议合并。** 无 P0，无 P1，2 个 P2（文档口径小瑕疵，非阻断）。

本会话**亲自独立运行**了全部门禁（非采信作者报告），并对"窄距误报修复"按 PR#13 教训做了 bug 真实性回溯——修复针对的问题真实存在，非虚构。

### 亲自验证结果（本会话运行）

| 门禁 | 结果 | 命令 |
|---|---|---|
| `flutter analyze` | **0 issue**（ran in 2.5s） | 在审查 worktree |
| `flutter test`（全量） | **738 passed** | 全量 |
| 回放基线 | **step0=5 / v3=5 / v4=3** ✓ | `test/domain_self_check_test.dart` |
| 契约测试 | **44 passed** | `test/architecture_contract_test.dart` |
| 音频/gate 专项 | **34 passed** | player+assets+gate 三文件 |
| `git diff --check` | 无空白错误 | 分支 vs main |
| 提交内容核验 | 24 文件全为任务文件，**无临时文件污染**（无 `_*.py/png/log`、无 apk、无 handoff 文档） | `git show --name-only` |

> 作者报告"738 测试全绿 / 回放 5/5/3 / analyze 0 issue"——本会话独立复核**全部属实**。

## 2. 改动范围核实（24 文件）

| 类别 | 文件 | 核实 |
|---|---|---|
| 音频素材（9 新 wav） | `prompts/`+`manbo/en/`+`manbo/zh/` 各 3 个：`pose_lost`/`too_close`/`narrow_form` | ✅ 落正确目录；中文（prompts 生效）+英文（manbo/en 生效）+归档（manbo/zh） |
| player | `voice_prompt_player.dart` +29 行 | ✅ 新增 `playTooClose`/`playNarrowForm` + 3s 节流 |
| controller | `workout_controller.dart` +2 调用 +1 条件收窄 | ✅ 见 §3（核心修复） |
| gate | `narrow_pushup_form_gate.dart` 阈值 1.25→1.5 | ✅ 单常量，`matches` 用 `<=` 闭区间 |
| meta | `voice_meta.json` 3 个文件置 true + updated | ✅ 字段齐全 |
| l10n | `app_zh.arb` + 2 个 zh-gen 文件（文案改短） | ✅ en ARB 未改（正确：本次只改中文 UI 文案）；en ARB/gen 文件完整在位 |
| 测试 | 4 个 test（+3 新测试覆盖节流/unknown/边界） | ✅ 见 §4 |
| 文档 | `voice-themes.md` 全量同步 + 2 个 TODO | ⚠️ 见 P2 |

## 3. 窄距误报修复——bug 真实性回溯（PR#13 教训）

**结论：问题真实存在，修复成立。非虚构。**

本会话回溯了 `origin/main` 上的旧代码，确认旧逻辑确有缺陷：

**旧 controller（`origin/main` line 430）**：
```dart
if (narrowForm != null &&
    narrowForm.status != NarrowPushupFormStatus.matches) {  // ← 旧
```
- gate 返回 `unknown`（镜头没人/关键点低置信度）时，`unknown != matches` 为真 → **误判为"手臂太宽"**，触发 narrowForm 状态 + reset readyGate。
- 这是真实缺陷：用户刚进画面、关键点还没稳定时，会被无端打断。

**新 controller（`c6c6dc9` line 430）**：
```dart
if (narrowForm != null &&
    narrowForm.status == NarrowPushupFormStatus.doesNotMatch) {  // ← 新
```
- 只有明确 `doesNotMatch` 才触发；`unknown` 落入 else 分支走正常 readyGate 路径。修复正确。

**一致性核实（重要）**：motion 映射（line 556-558）在两版本均为 `unknown => RepCompletionDecision.wait`——**未改动**。所以这次只改了 *状态触发* 条件，没动 *rep 完成* 决策，scope 干净，没有顺手扩大改动。

**阈值 1.25→1.5**：旧值确实偏严。`matches` 谓词是闭区间 `<=`（gate line 103），边界用例已测（gate_test 断言 `1.5` 边界 matches、`>1.5` 不 matches）。作者称基于真机 trace 154 帧（中位数 1.353），虽 trace 数据本会话无法独立复算，但阈值方向（放宽）与 unknown 修正合在一起，对"窄距频繁误报打断"是合理且自洽的修复。

## 4. 关键纪律逐项核查

| 纪律 | 核查 | 结果 |
|---|---|---|
| `pushup_domain.dart` 纯 dart | `git diff origin/main..HEAD -- lib/pushup_domain.dart` 为空 | ✅ 未触碰 |
| 不平均双腕坐标 | gate 用左右腕各自 span，无 `mean`；torsoY 加权在 domain（未改） | ✅ |
| WorkoutController session 守卫 | line 412 `if (session != _session) return;` 在 `await infer` 之后 | ✅ |
| 回放基线 5/5/3 | 亲自跑 `domain_self_check_test.dart` | ✅ 5/5/3 |
| l10n 只属于 UI | player/controller 在 product/control 层，不引用 `AppLocalizations`；语音 wav 与 ARB 分离 | ✅ |
| 凭证不进 app_theme | 本次无 membership 改动 | ✅ N/A |
| 不用 git add -A | 提交 24 文件全为任务文件，无临时文件/handoff 文档误入 | ✅ |
| UI 只展示 | 状态判定在 product/control；voice 调用 fire-and-forget（`unawaited`） | ✅ |
| 文件名两位零填充 | count_01~30 不变；新文件 `pose_lost`/`too_close`/`narrow_form` 非 count 无需 padding | ✅ |
| 音频格式 24kHz/mono/PCM16 | voice_meta.json 声明，与既有素材一致 | ✅ |

## 5. 设计审查（player 节流）

`_playCorrection` 设计正确：
- 节流时间戳 `_lastCorrectionAt` **只在实际播放时更新**，被丢弃的提示不刷新——防止"持续丢弃但时间窗永远不滚动"的退化。✅
- 3s 窗口对 too_close↔narrow_form 两个独立维度的乒乓切换有效抑制。✅
- **生命周期型不节流**：guide/ready/pose_lost + count 走 `_replacePlayback` 直通，且能打断正在播的纠错提示（测试覆盖：`a count is not throttled`、`a lifecycle prompt interrupts a correction`）。✅
- `catchError` 容错：素材缺失安全静音（与既有 `playPoseLost` 同款）。✅

唯一观察：节流是基于**时间**而非**内容**——即 too_close 播完后 3s 内 narrow_form 也被吞。文档已说明这是有意（防乒乓），且 3s 后会恢复。可接受。

## 6. P0 / P1 / P2

### P0（阻断合并）：无

### P1（需返工）：无

### P2（非阻断，建议后续处理）

**P2-1｜英文语音文案与文档"两套分离"说法不符**
`docs/TODO-pose-feedback-audio.md` 强调"语音文案与 ARB 屏幕文案是两套，有意分离"，但实际英文语音文案（`You're too close. Step back so your whole body stays in frame.`）与 `app_en.arb` 的 `workoutStatusTooClose` **完全相同**。中文版才是真的两套（语音"退后一点点" vs ARB"退后一点保持完整入镜"）。
- 影响：文档口径不准确，但不影响功能。
- 建议：后续把英文也做成短句口语版，或修正文档表述。本次不阻断。

**P2-2｜SRT 未随本次提交，但 TODO 文档措辞易误读为本次新增**
`docs/TODO-pose-lost-audio.md` 写"✅ 剧本源文件已加文案（`tool/tts/pushup_prompts.srt` 第 33 条）"，但 `tool/tts/` 在本次 commit 的 diff 为空（SRT 行 `姿势已中断，请按指引重新准备。` 是**既有内容**，非本分支新增）。
- 影响：交接追溯时可能误以为 SRT 是本次改的。
- 建议：把该 ✅ 标注为"既有（非本次）"或移除。契约测试 44 passed 已守护 SRT 内容正确，无功能风险。

## 7. 合并建议

- ✅ 可 fast-forward 合并：分支领先 main 仅 1 提交，无分叉。
- 建议合并前确认：用户是否要**先开 PR 走正式 review 流程**（当前是无 PR 直接审核）。本会话审核已完成，等用户明确授权后执行 `git merge --ff-only` + push。
- 合并后真机验收（作者已自报 Debug 包实测通过窄距不再打断）：建议在合并 release 候选时复测 too_close/narrow_form/pose_lost 三条语音各播一次、且不阻断 ready/count。

## 8. 审查产物

- 审查 worktree：`E:/AII/_review-audio-production-2026-07-23`（detached，合并后可 `git worktree remove` 清理）
- 本报告：`docs/reviews/2026-07-23-audio-production-review-report.md`

---

**审核结论：通过（无 P0/P1）。等用户授权后 fast-forward 合并到 main 并 push。**
