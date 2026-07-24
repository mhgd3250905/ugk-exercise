# 审核报告：PR #13 — 项目审核发现的 4 个 bug 修复

> 日期：2026-07-23
> 审核人：main reviewer
> PR：[#13](https://github.com/mhgd3250905/ugk-exercise/pull/13)
> 分支：`fix/audit-bugfixes-2026-07-23` → `main`
> 提交：`a6ae3e1 fix: 修复项目审核发现的4个真实bug`
> 4 files, +27/-23
> 审查 worktree：`E:/AII/_review-audit-bugfixes`（detached @ `a6ae3e1`）

## 1. 结论

**审核通过，建议合并。** 无 P0、无 P1，2 个 P2（均为描述/纪律层面建议，不阻断）。4 个 bug 修复逐一核实均成立且在正确的层。门禁由 main reviewer 本会话独立复核全绿。

## 2. PR 与交接报告的差异（已核实，需提醒）

⚠️ 这个 PR **不是**交接报告 §4 所说的"分支 B（feat/ui-polish-2026-07-22，UI/排行榜优化）"。它是一个**独立的新分支**：
- 交接说的分支 B：`feat/ui-polish-2026-07-2026-07-22`，单提交 `8f5967f`（交接）/ `8f055a5`（worktree 实测），主题"UI/排行榜优化"。
- 本 PR：`fix/audit-bugfixes-2026-07-23`，提交 `a6ae3e1`，主题"6 维度审核发现的 4 个 bug 修复"。

两者内容完全不重叠。本报告只审 PR #13。`feat/ui-polish-2026-07-22` 仍未 push 到远程，留待后续单独审核。

## 3. 4 个 bug 修复逐一核实

### Bug #1 [高] step0 回放基线测试去除 SignalFilter — ✅ 成立（PR 描述不精确，见 P2-1）

**改动**：`domain_self_check_test.dart` 的 step0 测试移除 `SignalFilter(window: 5).smooth(...)` 包裹，直接把 `_signals(...)` 传给 `counter.update()`。

**核实**：
- ✅ 生产管线 `PushupPipeline` 确实**不使用 SignalFilter**（grep `lib/product/pushup_pipeline.dart` 无命中；SignalFilter 仅是 `pushup_domain.dart` 里供测试/诊断用的独立类）。PR"生产路径不用 SignalFilter"的论断成立。
- ✅ **只有 step0 一个测试**多套了 SignalFilter；v3/v4 测试本来就没套（与生产一致）。PR body 说"step0 测试验证非生产信号路径"——只对 step0 成立，措辞像覆盖全部基线，属夸大。
- ✅ 改后 step0 仍数出 5（本会话亲跑 `domain_self_check_test.dart` 全过，断言 `count == 5` 未放松，line 181）。中值滤波在 `PushupCounter` 内部，不受影响。
- ✅ 这是让**测试守护的链路与生产一致**，不是让测试变松。合理。

### Bug #2 [中] VoicePrompt 播放速率时序 — ✅ 成立

**改动**：`voice_prompt_player.dart:67-68`，`setPlaybackRate` 从 `play()` 之后移到之前；删除了 play 之后那段冗余的 generation 守卫。

**核实**：
- ✅ 英文计数走 `playCount` → `playbackRate: 1.2`，改后 1.2x 在 `play()` 前设置，消除开头几十毫秒 1.0x 的 bug。
- ✅ 删除 play 之后的 generation 守卫合理：`play()` 现在是链上最后一步，其后无状态写入；旧守卫是防 `await play()` 期间 generation 变化再写状态，现已无后续写。

### Bug #3 [中] WorkoutSessionStore 原子写 — ✅ 成立

**改动**：`workout_session_store.dart:430-440`，`_write` 由直接 `file.writeAsString` 改为先写 `${file.path}.tmp` 再 `rename(file.path)`。

**核实**：
- ✅ tmp+rename 是 Android 同一文件系统内原子写的标准做法，进程被杀时最坏只丢 `.tmp`，主文件不会截断。
- ✅ `.tmp` 文件不会被 `load()` 误读（`load()` 只读固定 `fileName = workout_sessions.json`）。
- ✅ 写入仍受既有 `_serializeMutation` 全局队列串行保护，无并发 rename 竞态。

### Bug #4 [低] mergeWorkoutSessions 排序 — ✅ 成立

**改动**：`workout_session_store.dart:182`，合并后按 `startedAt` 降序 `sort`；测试断言同步更新为 `['cloud-only', 'same']`。

**核实**：
- ✅ `mergeWorkoutSessions` 唯一生产调用方是 `records_page.dart:55`，且该页**自身不二次排序**（grep records_page 无 sort/reversed）。PR 论断成立。
- ✅ 修复放在数据合并层而非 UI 层，符合"UI 只展示"纪律——让数据源返回稳定时间序。
- ✅ 测试断言更新正确（cloud-only 是 7/9，same 是 7/8，降序 → cloud-only 在前）。

## 4. 项目纪律核对

| 纪律 | 结果 | 证据 |
|---|---|---|
| `pushup_domain.dart` 纯 dart | ✅ 通过 | 4 个文件均未触及 domain 地基 |
| 不平均双腕坐标 | ✅ 通过 | 无识别/信号改动 |
| WorkoutController session 守卫 | ✅ 通过 | 未改 controller |
| 回放基线 5/5/3 | ✅ 通过 | step0 去 SignalFilter 后亲跑仍 5/5/3，断言未放松 |
| l10n 只属于 UI | ✅ 通过 | 4 bug 均无用户可见文案，未动 ARB |
| 凭证不进 app_theme | ✅ 通过 | 无凭证相关改动 |
| 不用 git add -A | ✅ 通过 | 4 files 全为代码/测试，无根目录临时文件 |
| 真实视频/csv 不进 git | ✅ 通过 | 未新增 fixture 或日志 |

## 5. 门禁复核（本会话独立运行，worktree `E:/AII/_review-audit-bugfixes` @ `a6ae3e1`）

| 门禁 | 命令 | 结果 |
|---|---|---|
| 空白错误 | `git diff origin/main..HEAD --check` | clean ✅ |
| 静态分析 | `flutter analyze` | No issues found ✅ |
| 全量测试 | `flutter test` | **715/715 passed** ✅ |
| 回放基线 | `flutter test test/domain_self_check_test.dart` | 26 passed，5/5/3 不回归 ✅ |
| Worker | 本次未改 `workers/membership-api` | 无需 npm test |

> 关于测试数 715 vs main 的 719：PR 基于合并分支 A 之前的 `main@cd91a4b`（715），现在 main 已是 `ce3bb29`（719，含分支 A 的 4 个新测试）。这是 PR 未 rebase 到最新 main 导致的预期差异，非异常。

## 6. 风险与遗留（均非阻断）

### P2-1：Bug #1 的 PR 描述夸大了影响范围（纯描述问题）

PR body 标题"step0 回放基线测试验证非生产信号路径"让人以为**整个回放基线**都守护了非生产链路。实际只有 step0 一个测试多套了 SignalFilter，v3/v4 本来就与生产一致。修复本身正确且最小，但描述应限定为"step0 测试"。不影响代码，不阻断合并，建议后续 PR 描述更精确。

### P2-2：PR 基于旧 main，合并需注意基线一致性

PR 的 base 是 `cd91a4b`，当前 main 是 `ce3bb29`（已含分支 A）。mergeable 状态 MERGEABLE/CLEAN 说明无冲突，但合并后需确认：分支 A 新加的 `WorkoutStatus.tooClose` 等改动与本 PR 无交叉（本 PR 只动 voice/store/test，与 recognition 控制层无重叠，已确认）。建议合并后重跑一次全量测试确认 719+ 基线。

## 7. 审核决策

- ✅ 放行合并。
- ⏳ 合并方式 + push 为独立远程写入授权，等用户明确指示。鉴于 PR 基于 `cd91a4b` 而非最新 `ce3bb29`，合并有两个选项（见下），需用户定夺。
- 本分支未改 Worker，无清单回退风险；合并不等于发版。

## 8. 合并方式选项（需用户决策）

| 选项 | 命令 | 说明 |
|---|---|---|
| A. 直接合并 PR（squash 或 merge commit） | `gh pr merge 13` | GitHub 端合并，保留 PR 关联；会生成 merge/squash commit |
| B. 本地 rebase 到最新 main 再 ff push | rebase 到 `ce3bb29` 之上 → ff push | 历史线性 |

main reviewer 默认偏好**线性历史**。

---

# 第二轮：返工后复核（2026-07-23）

作者按 review 返工并 force-push：`a6ae3e1 → 41d2e7a`。main reviewer 独立复核。

## R1. 返工核实

| 返工项 | 结果 | 证据 |
|---|---|---|
| Bug #4 完整撤销 | ✅ 干净 | `mergeWorkoutSessions` 排序改动从 diff 消失；`workout_session_store_test.dart` 整个文件不再在 diff 中（断言回到原值）；PR 从 4 files/+27/-23 → **3 files/+15/-17** |
| Bug #1 描述更正 | ✅ 到位 | commit message 正文明确"v3/v4 测试本就与生产一致，仅 step0 多套了 SignalFilter" |
| Rebase 到 `ce3bb29` | ✅ 真实 | 新提交 `41d2e7a` 父提交 = `ce3bb29`（git log 确认） |
| Bug #1/#2/#3 原样保留 | ✅ | 三个修复 diff 与首审完全一致 |
| 无夹带范围外改动 | ✅ | 仅 3 个文件，diff --check clean |

## R2. 门禁复核（本会话独立运行，worktree `E:/AII/_review-audit-bugfixes` @ `41d2e7a`）

| 门禁 | 结果 |
|---|---|
| `git diff --check` | clean ✅ |
| `flutter analyze` | No issues found ✅ |
| `flutter test`（全量） | **719/719 passed** ✅ |
| `domain_self_check`（回放基线） | 26 passed，step0=5/v3=5/v4=3 不回归 ✅ |

> 注：作者 commit message 末尾仍写"flutter test 715/715"，这是 rebase 前的旧数字未更新。经独立验证实际为 719/719（rebase 到 `ce3bb29` 后正确值）。描述瑕疵，不影响代码。

## R3. 返工后结论

**审核通过，建议合并。** 无 P0 / 无 P1。Bug #4 已干净撤销，PR 现为 3 个真实 bug 修复（#1 描述更正 + #2 + #3），基于最新 main，719 基线全绿。

遗留（均非阻断）：
- P2：commit message 验证行写"715"实为"719"，建议作者后续修正（不阻断本次合并）。
- P2：mergeable=MERGEABLE/CLEAN，无文件冲突（本 PR 只动 voice/store/test，与 main 最新内容无重叠）。
