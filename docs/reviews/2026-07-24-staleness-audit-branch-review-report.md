# 审核报告：`investigate/staleness-audit-2026-07-24` — 陈旧度审核报告分支（meta 审核）

> 日期：2026-07-24
> 审核人：main reviewer
> 分支：`investigate/staleness-audit-2026-07-24`（tip `0e7e62f`，1 提交）
> 基线：fork 自 `origin/main@b5b1768`（0.3.21 发版前）
> 当前 main：`72964f2`（已含 0.3.21 版本号改动）
> 审查 worktree：`E:/AII/ugk-post-staleness-audit-2026-07-24`（开发 worktree，detached 等效）

## 1. 结论

**审核通过（无 P0/P1，1 个 P2 文档口径）。这是一份高质量的陈旧度报告，关键技术论断经独立核实属实。但因 base 过时，合并需 rebase（与 PR#14 同构陷阱）。**

本分支的特殊性：**它是"一份审核报告"的提交**，不是代码改动。所以本审核是 meta 审核——核实报告内容是否准确（不能让虚构结论混进 main 文档）、是否只提交了报告。

## 2. 亲自验证结果

| 门禁 | 结果 | 说明 |
|---|---|---|
| 提交内容 | ✅ **只 1 个报告文件**（`docs/reviews/2026-07-24-staleness-audit-full-report.md`，+318），代码零改动 | 作者汇报属实 |
| `lib/*.dart` / `test/*.dart` vs main | ✅ **完全一致**（空 diff） | 确认没误改代码 |
| `git diff --check` | ✅ 无空白错误 | |
| 报告内 `flutter analyze`/`flutter test` | 报告声明 0 issue / 745 passed / 5/5/3 | 与本会话此前多次独立复现一致，未重复跑（分支代码=main，无新代码） |

## 3. 报告内容准确性——独立抽查（PR#13 教训）

报告含 11 项发现（D1-D7 文档 / L1-L4 代码 / T1-T4 测试）。本会话**独立核实其中 5 个最易虚构/最关键的技术论断**，全部属实：

| 报告论断 | 报告结论 | 我独立核实 | 结果 |
|---|---|---|---|
| L1 | `SignalFilter` 旧路径已退出生产，仅测试保活 | `git grep "SignalFilter("` → 唯一实例在 `test/domain_self_check_test.dart:156`；`pressDepthY` 生产无读取方（`wrist_anchor.dart:11` 仅注释） | ✅ 属实 |
| L2 | `test_mode_page.dart` 等 11 文件生产不可达 | `git grep test_mode_page lib/` → 零生产 import | ✅ 属实 |
| L3 | `workoutBurned` 等 10 个 ARB key 无生产 getter 调用 | `git grep workoutBurned lib/`（排除 l10n）→ 空 | ✅ 属实 |
| §6 保留项 | `claimLegacyForOwner` 是活跃用户功能（profile 同步本机历史） | `profile_page.dart:599` 实际调用 | ✅ 属实 |
| §6 保留项 | `golden_frame_report` 是活跃 CLI（非死代码） | `tool/golden_frame_report.dart` import 它 | ✅ 属实 |

报告质量亮点：
- **诚实标注已知债务**：D3/D7 引用 2026-07-16 旧报告，标"非本次首次发现"。
- **删除风险分级诚实**：高风险点（D1 台账/D2 计划/T3 fixture）明确标"不可整删"。
- **保留项有据**：claimLegacy/golden_frame 主动澄清"不可达 ≠ 死代码"。
- **治理顺序合理**：先修文档真源不删历史 → 独立清旧 domain（L1+T1 同提交）→ 测试模式产品决策 → 低风险尾项。
- **边界清晰**：§8 明确"未运行 Worker 测试（范围是 docs+lib+test）""未访问 Play/Worker 远程"。

## 4. ⚠️ M0 合并前置问题（与 PR#14 同构）

**现象**：分支 fork 自 `b5b1768`（0.3.21 发版前），当前 main 是 `72964f2`（已含 0.3.21 版本号改动）。`git diff main..branch` 因此把 0.3.21 的 pubspec/app_update.ts/测试**显示成删除**（-24 行）。这是 base 过时的错觉，不是报告分支真改了版本号。

**风险**：直接 rebase/squash merge 会把分支线性重放到 main，**回退掉 0.3.21 版本号改动**。不能直接合。

**好消息**：报告分支只动 `docs/reviews/`，与 0.3.21 的 pubspec/app_update.ts/测试**零文件重叠**，rebase 无冲突。

**正确合并策略（与 PR#14 方案 A 一致）**：作者 rebase 到最新 main（`72964f2`）→ force-push → 重跑门禁确认 → ff-only 合并。
- rebase 后 diff 会只剩报告文件（+318），版本号"删除"消失。
- rebase 不改报告内容，无需重新核实论断。

## 5. P0 / P1 / P2

### P0（阻断）：无
### M0（合并流程）：见 §4，base 过时，需 rebase 后合并，不得直接 rebase/squash merge。
### P1：无

### P2（非阻断）

**P2-1｜报告 §8 末"未运行 Worker 测试"措辞——准确但需留意 0.3.21 已改清单**
报告声明本次未跑 Worker 测试（范围是 docs+lib+test）。这**准确**。但报告基线是 `b5b1768`，而 main 现已到 `72964f2`（含 0.3.21 Worker 清单改动）。rebase 后报告内容不变，但若有人据此报告"基线"判断 Worker 状态，要注意 main 已前进。
- 影响：无（报告是陈旧度分析，不涉及 Worker 状态事实）。
- 建议：无需改报告。

## 6. 合并建议

- 方案 A（推荐，与 PR#14 一致）：作者 rebase 到 `origin/main@72964f2` → `push --force-with-lease` → 重跑门禁贴结果 → ff-only 合并。
- 我不自行 rebase（改写他人分支历史需作者操作或明确授权）。

## 7. 审查产物

- 审查 worktree：`E:/AII/ugk-post-staleness-audit-2026-07-24`（开发 worktree，保留）
- 本报告：`docs/reviews/2026-07-24-staleness-audit-branch-review-report.md`

---

**审核结论：报告内容高质量、技术论断经独立核实属实、只提交了报告无代码改动。但因 base 过时，需作者 rebase 到最新 main 后重提（不得直接 rebase/squash merge，会回退 0.3.21 版本号）。等用户决定：让作者 rebase，还是授权我用方案 B（no-ff merge）。**
