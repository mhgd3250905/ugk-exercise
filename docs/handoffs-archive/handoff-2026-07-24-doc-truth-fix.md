# 交接：docs/doc-truth-fix-2026-07-24 文档真源修复（7 项，只改文档）

> 日期：2026-07-24
> 工作树：`D:/Git/AII/ugk-post-doc-truth-fix-2026-07-24`
> 分支：`docs/doc-truth-fix-2026-07-24`（基于 `main@5f20e0d`）
> 本机 Flutter：`3.44.7`
> 派发者：main reviewer
> 任务来源：`docs/reviews/2026-07-24-staleness-audit-full-report.md` §3（D1-D7）

## 你的任务（范围明确，可直接开始）

修复陈旧度报告 §3 的 **7 项文档发现（D1-D7）**。**只改文档，不动任何代码/测试**（`lib/`/`test/`/`workers/`）。核心目标：让文档成为可信的"当前事实源"，不删历史证据。

**先读任务来源**：`docs/reviews/2026-07-24-staleness-audit-full-report.md` §3（D1-D7 每项有位置+证据+判断+处置建议）。

## 7 项具体任务

| 项 | 文件 | 要做什么 | 风险 |
|---|---|---|---|
| **D1** | `release-configuration.md` | §1 与 §6.3 的"当前发布"互相冲突（§1 说 0.3.20，§6.3 说 0.3.16）。**收敛成唯一摘要区**：§6.3 改名为带日期的历史记录或只链接 §1；明确区分"Git 核实"与"平台最后核对"两种事实 | 高（含发布 SOP，不能整删，只改动态状态段） |
| **D2** | `docs/plans/README.md` | 索引说 43 份计划，实际 55 份，漏 12 份。**补齐 12 项及状态** | 高（计划是设计依据，不能删，只补索引） |
| **D3** | `architecture-analysis.md`/`architecture-plan.md`/`refactor-report.md` | 三份重构期历史快照被 AGENTS.md/modules/README.md 标为"现状"。**顶部加"历史基线 c7c6593，非当前 main"横幅**；改 AGENTS.md/modules/README.md 的描述为"重构历史" | 中（不删，加横幅） |
| **D4** | `TODO-pose-feedback-audio.md`/`TODO-pose-lost-audio.md` | 已完成但仍叫 TODO，pose-lost 后半还写"未完成"。**改名 completion record，删除/改写未完成段落**（证据可并入 voice-themes.md） | 低 |
| **D5** | `README.md` | §49/§54 指示进入"App 测试模式"（已无入口）。**注：测试模式在另一分支退休，这里先改 README 为当前可执行步骤**（或暂时标注"待测试模式退休后更新"） | 高（README 不可删，改写这段） |
| **D6** | `docs/handoff-2026-07-22-count-miss-investigation.md` | 已收敛的调查缺被替代标记。**顶部加"已由 recognition.md §10 + ce3bb29 收敛"**或移到 archive | 低 |
| **D7** | `docs/superpowers/` | 14 份旧计划无索引。**加"历史生成计划"README**，标源提交与 superseded 状态 | 中 |

## 关键纪律

1. **只改文档**：本分支禁止碰 `lib/`/`test/`/`workers/`/`pubspec.yaml`。
2. **不删历史证据**：D1-D7 都是"加标记/补索引/收敛状态"，不是删除文件（D4 可改名/合并，但保留证据）。
3. **动态状态用当前 main 核实**：版本号/提交 hash 以 `main@5f20e0d` 为准（pubspec `0.3.21+24`）。
4. **不用 `git add -A`**：显式 stage 改动的 md 文件。
5. **D1 发版状态**：以 info 仓库台账为权威，App 文档只记公开流程；不确定的平台状态标"需 Play Console 核对"，不臆断。

## 完成后验证

```bash
cd D:/Git/AII/ugk-post-doc-truth-fix-2026-07-24
git diff --stat origin/main      # 应只有 docs/*.md 改动，无 lib/test/workers
flutter analyze                  # 0 issue（确认没误碰代码）
git diff --check                 # 无空白错误
```

提交后等 main reviewer 审核。

## 建议开场白

```
已读完交接。我在 docs/doc-truth-fix-2026-07-24，基于 main@5f20e0d。
任务：修复 staleness 报告 §3 的 D1-D7 七项文档发现，只改文档不动代码。
我先读报告 §3 每项的详细证据，逐项处理。
```
