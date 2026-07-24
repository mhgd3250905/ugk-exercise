# 审核报告：staleness 治理 4 个分支（① doc-truth / ② legacy-domain / ③ test-mode-retire / ④ arb-testfakes）

> 日期：2026-07-24
> 审核人：main reviewer
> 治理来源：`docs/reviews/2026-07-24-staleness-audit-full-report.md`（11 项发现）
> 审查 worktree：`D:/Git/AII/_review-doc-truth-fix` / `_review-legacy-domain` / `_review-test-mode-retire` / `_review-arb-testfakes`（各 detached）

## 1. 结论：4 个分支全部通过，可合并

**无 P0 / 无 P1，2 个 P2（非阻断）。** 4 个分支各自独立、门禁全绿、约束守住，按报告要求执行。本会话对每个分支**独立跑门禁 + 核实关键约束**（不采信作者自报）。

### 合并顺序建议
① → ④ → ② → ③（风险从低到高，与审核顺序一致）。四个分支文件基本不重叠，但因都基于同一 main `5f20e0d`，**需逐个 ff-only 合并，每次合并后下一个分支需 rebase 到新 main**（否则遇到和 staleness-audit 一样的 base 过时问题）。

## 2. 逐分支审核结果

### ① `docs/doc-truth-fix-2026-07-24`（`e472b2c`）— ✅ 通过，无 P2

| 门禁 | 结果 |
|---|---|
| analyze | 0 issue |
| full test | 745 passed |
| 只动 docs | ✅ lib/test/workers 空 diff |

**D1-D7 处理核实**：
- D1：release-configuration.md 把"Git 核实"和"平台最后核对"分离（Git `5f20e0d`/`0.3.21+24` vs 平台 2026-07-23）；§6.3 改名"历史发布记录"加横幅。✅ 正确修法，没臆断平台状态。
- D2：plans/README.md 补齐漏掉的 12 份计划。✅
- D3：三份架构文档顶部加"历史基线 c7c6593，非当前 main"横幅，指向 development-guide/modules。✅
- D4：TODO-pose-*-audio.md 改名 completion-*-audio.md。✅
- D5：README 测试模式段改为当前可执行的 `flutter test --name "replays"` fixture 回放命令。✅
- D6/D7：handoff 加收敛标记 / superpowers 加 README。✅

### ② `refactor/legacy-domain-cleanup-2026-07-24`（`9f1c2e8`）— ✅ 通过，无 P2

| 门禁 | 结果 |
|---|---|
| analyze | 0 issue |
| 回放基线 | **25 测试全绿，5/5/3 不回归**（少 1 条 SignalFilter 测试，符合预期） |
| full test | 744 passed |

**约束核实**：
- ✅ domain 保持纯 dart（无 flutter/dart:io import）
- ✅ 保留项 shoulderY/headY 在位（11 处引用）
- ✅ 无 SignalFilter/pressDepthY/elbowLateral 残留（唯一命中 `wrist_anchor.dart:11` 是注释）
- ✅ L1+T1 同一提交（1 个提交）
- ✅ 删的测试正是 T1 那条 `SignalFilter smooths jitter and holds through NaN`

### ③ `refactor/test-mode-retire-2026-07-24`（`b4e7286` + `6048996`）— ✅ 通过，1 个 P2

| 门禁 | 结果 |
|---|---|
| analyze | 0 issue |
| full test | 731 passed（少 14 = 6 测试文件 + contract 断言，符合预期） |
| golden_frame CLI | **4 passed**（CLI 没坏） |
| architecture_contract | 42 passed（删断言后仍全绿） |
| 回放基线 | 25 全绿（test-mode 删除没碰算法） |

**约束核实**：
- ✅ golden_frame 4 文件全在（lib/report/golden_frame_report.dart + tool + 2 test）
- ✅ ffmpeg 依赖从 pubspec 干净移除，无残留引用
- ✅ lib 无 test_mode/replay/ffmpeg 残留
- ✅ README 同步改为"测试模式已移除"
- ✅ `replayVideoName` 常量配套删除，无悬空引用

**P2-1：第 2 个提交 `6048996` 信息标 `docs:` 但实际含 lib 改动**（删 `resource_constants.dart` 的 `replayVideoName` 常量 + contract test 断言）。改动本身合理（退休配套清理），但提交信息与实际内容不符，应标 `refactor:` 或 `chore:`。非阻断，建议合并后注意提交信息规范。

### ④ `refactor/arb-and-test-fakes-cleanup-2026-07-24`（`4b04d42`）— ✅ 通过，1 个 P2

| 门禁 | 结果 |
|---|---|
| analyze | 0 issue |
| full test | 745 passed |

**约束核实**：
- ✅ ARB 中英删除同步（两边都是同样 9 个 key；zh 删行多是因为 4 个 key 带 `@` 元数据块）
- ✅ 生成文件规范：`flutter gen-l10n` 后无差异（非手改）
- ✅ fake 迁移后生产 lib 无残留实例化，3 个 fake 移到 `test/support/`
- ✅ test 引用已更新（全量 745 过证明 import 改全了）

**P2-2：交接文档要求"testMode 先留避免与③冲突"，但实际 4 个 ARB key 里 testMode 已删**。因③已合并路径上（测试模式退休），testMode 删除实际是正确的（测试模式都没了，key 自然该删）。不是问题，只是与交接文档的"先留"建议不符——实际结果更好。非阻断。

## 3. P0/P1/P2 汇总

### P0/P1：无
### P2（非阻断）
- P2-1（③）：提交 `6048996` 信息标 `docs:` 实际含 lib 改动。
- P2-2（④）：testMode 已删（与交接"先留"建议不符），但结果正确。

## 4. 合并注意事项（重要）

4 个分支都基于 `main@5f20e0d`，但合并是**串行**的——每合一个，main 前进，下一个分支就"base 过时"了（和 staleness-audit 之前遇到的一样）。两种做法：

- **方案 A（推荐，干净）**：逐个合并，每合一个后让下一个分支 rebase 到新 main 再合。ff-only 历史最干净。
- **方案 B（快）**：逐个 `merge --no-ff`，接受 merge commit。

**重叠检查**：① 改 docs（含 README/release-config）；③ 也改 README（测试模式段）+ development-guide + app-ui-v1。**① 和 ③ 在 README/development-guide 有重叠**，合并时可能冲突——建议 ① 先合并，③ rebase 时手动解 README/development-guide 的冲突（保留两边改动）。

## 5. 审查产物

- 4 个审查 worktree（合并后可清理）
- 本报告：`docs/reviews/2026-07-24-staleness-cleanup-4branches-review-report.md`

---

**审核结论：4 个分支全部通过。建议按 ①→④→②→③ 顺序合并，注意 ①③ 在 README/development-guide 有重叠需 rebase 解冲突。等用户授权逐个合并。**

---

## 6. 合并执行结果（2026-07-24 已完成）

4 个分支按 ①→④→②→③ 顺序串行合并，全部 ff-only（rebase 后对齐）。

| 顺序 | 分支 | rebase 冲突 | 合并后 main |
|---|---|---|---|
| ① | doc-truth-fix | 无（base 已对齐） | `e472b2c` |
| ④ | arb-testfakes | 无 | `f35e6d8` |
| ② | legacy-domain | 无 | `3e24f12` |
| ③ | test-mode-retire | **README.md 1 处**（①③都改测试模式段） | `c89562e` |

**③ README 冲突解决**：① 版本（"复现识别回归"，bash + `--name "replays"` + fixture/隐私说明 + playbook 链接）比 ③ 版本（"复现离线验证"，powershell 简版）更完整准确，**采用①版本**（`git checkout --ours`），丢弃③简版。第 2 个提交 `6048996` 顺利重放。

**main 最终全量门禁（4 分支全合并后，本会话亲自跑）**：
- `flutter analyze`：0 issue
- 回放基线：5/5/3（25 测试全绿）
- full test：730 passed
- golden_frame CLI：4 文件在位（lib/report/golden_frame_report.dart + tool + 2 test）

main = `c89562e`，与 origin/main 双向一致（0/0）。

### P2 收尾（本会话处置）

- **P2-1（③ 提交信息不准）**：`6048996` 标 `docs:` 实际含 lib 改动（删 replayVideoName 常量）。**已合并进 main，历史无法改写**——记录存档于此，提醒作者后续提交信息与实际内容对齐（refactor/chore 类改动别标 docs）。无需 further action。
- **P2-2（④ testMode 已删）**：交接建议"先留 testMode 避免与③冲突"，但④实际已删，且③退休了测试模式，**删除是正确结果**。无需 action。

### 后续清理（可选，未做）
- 4 个远程分支（docs/doc-truth-fix、refactor/legacy-domain-cleanup、refactor/test-mode-retire、refactor/arb-and-test-fakes-cleanup）已全部并入 main，可删（远程删需授权）。
- 审查 worktree（`_review-doc-truth-fix` 等 4 个）可清理。
