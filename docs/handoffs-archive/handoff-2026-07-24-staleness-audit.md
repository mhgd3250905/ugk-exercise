# 交接：investigate/staleness-audit-2026-07-24 项目过期/冗余/死代码审核（只出报告，不动代码）

> 日期：2026-07-24
> 工作树：`E:/AII/ugk-post-staleness-audit-2026-07-24`
> 分支：`investigate/staleness-audit-2026-07-24`（基于 `main@b5b1768`）
> 本机 Flutter：`3.44.7`（pubspec 要求 `flutter: '>=3.44.0'`，`sdk: ^3.8.0`）
> 派发者：main reviewer（main 工作树 `E:/AII/ugk-post`）

## ⚠️ 重要：只出报告，不动代码（用户已确认）

**本分支的任务是只读审核 + 产出清单报告，不改任何代码/文档/测试。** 用户明确选了"先出报告，不动代码"——接手后**不要删除或修改**任何文件，只盘点点位、给出判断和证据，写成报告，**等用户看完报告再决定删什么**。

**本分支当前没有具体审核范围指令。** 接手后先按"接手第一步"做只读准备，然后**等用户给你安排具体的审核重点**（见 §3 常见审核维度）。用户可能让你全量审，也可能只审某一类（比如只审 docs）。

## 1. 接手第一步（只读，不改动）

1. 用中文说明你正在使用 `$manage-pushupai-project` Skill，本次任务是**项目陈旧度/冗余审核**（只读盘点，产报告）。
2. 运行只读预检（在 App 仓库 **main 工作树**，不是这个 worktree）：

   ```bash
   cd E:/AII/ugk-post
   powershell -ExecutionPolicy Bypass -File .agents/skills/manage-pushupai-project/scripts/preflight.ps1 -ProjectRoot E:/AII/ugk-post
   git status --short --branch
   git log --oneline -1 origin/main
   ```

3. 完整读 `E:/AII/ugk-post/AGENTS.md`（项目入口、架构分层、纪律、文档地图）。
4. 读 `.agents/skills/manage-pushupai-project/SKILL.md`（验证纪律）。
5. **重点读**：
   - `docs/development-guide.md`（架构分层，判断"实现是否还在正确层"的依据）
   - `docs/architecture-analysis.md` + `docs/architecture-plan.md`（架构现状 + 债务清单——**这是已知的债务记录，审核时对照，别把已知债务当新发现**）
   - `docs/refactor-report.md`（重构复盘——判断哪些是"重构后遗留的旧实现"）
6. 确认你的 worktree 状态：

   ```bash
   cd E:/AII/ugk-post-staleness-audit-2026-07-24
   git status --short --branch
   git log --oneline -1
   ```

   应显示：分支 `investigate/staleness-audit-2026-07-24`，HEAD `b5b1768`，工作区干净。

## 2. 当前状态（2026-07-24 由 main reviewer 核实）

| 项 | 值 |
|---|---|
| 本分支基线 | `main@b5b1768` |
| 领先 main | 0 个提交（全新分支） |
| origin/main | `b5b1768`（与本地 main 同步） |
| 代码规模 | lib **75** 个 dart 文件；test **54** 个测试文件 |
| 文档规模 | docs **116** 个 md 文件（含 archive/design/modules/plans/policies/refactor/reports/reviews/superpowers 子目录） |

### main reviewer 预扫的高发靶子（接手 agent 优先看这些）

> 以下是我（派发者）只读预扫发现的**疑点/起点**，不是定论。接手 agent 需逐一核实真伪、给出证据和判断。

**① 过期文档（docs，116 个 md，体量大）**
- `docs/archive/`（7 个历史文档：M3 方案/验收、俯卧撑检测计划、计数算法重构交接、项目交接等）——按 AGENTS.md 文档地图标注"已过时，仅供参考"，**需核实是否真的都过时、有无仍被引用**。
- `docs/handoff-*.md`（多次会话的历史交接）——交接文档天然有时效性，**老的交接可能描述已变更的状态，易误导**（例：PR#14 handoff 里"info 仓库禁止配置 remote"是旧规则，已被多机器改造更新）。
- `docs/reviews/`、`docs/reports/`、`docs/plans/`、`docs/superpowers/`——审核/规划类文档，**核实是否仍反映当前架构/版本**。
- 重点查：**文档描述的版本号/分支/状态是否与当前 main `b5b1768` 一致**（发版状态文档尤其易过期，如 release-configuration.md 的快照停留在 0.3.20/`36ce274`，而 main 已到 `b5b1768`）。

**② 冗余/旧实现（lib）**
- `claimLegacyForOwner`（`lib/control/workout_sync_controller.dart:62` + `lib/product/workout_session_store.dart:341`）——legacy 记录认领逻辑。**核实是否仍活跃**：最近 P0 审核发现"遗留 session 缺 localDate"问题，需判断这套 legacy 认领是配套的活跃代码还是可清理的过渡逻辑。
- 架构重构后可能残留的旧路径（对照 `refactor-report.md` + `architecture-analysis.md` 债务清单）。

**③ 死代码（lib）**
- lib 75 个文件，**找未被任何地方 import 的孤儿文件/类/函数**。
- TODO/FIXME/`@deprecated` 标记（代码层真实命中较少，需精筛——注意区分 `.toDouble()`/`clamp` 等误匹配）。

**④ 过期/冗余测试（test，54 个）**
- **核实每个测试是否仍对应当前代码**：被测的类/函数是否还存在、签名是否变了、断言是否还成立。
- **回放基线**（`test/domain_self_check_test.dart`，5/5/3）是硬约束，**不可删**——但核实它依赖的 fixtures 是否冗余。
- `test/fixtures/`（脱敏信号）——核实是否有过期 fixture（对应已删除的测试/旧算法）。
- **重复/冗余测试**：测同一逻辑多份、或已被更高层测试覆盖的底层测试。

## 3. 你要做的事（等用户安排后）

用户会给你具体审核范围。常见审核维度（仅供参考，**以用户实际指示为准**）：
- 全量陈旧度审核（docs + lib + test 都过一遍）
- 只审 docs（过期/误导说明）
- 只审 lib（死代码/冗余实现/旧路径）
- 只审 test（过期/冗余/不跟版本的测试）
- 专项审某一类（如只审发版状态文档、只审架构债务是否已还清）

## 4. 报告产出要求（关键）

报告写到 `docs/reviews/2026-07-24-staleness-audit-<范围>-report.md`（跟随仓库 review 报告惯例），**每个发现必须含**：

| 字段 | 说明 |
|---|---|
| 类型 | 过期文档 / 死代码 / 冗余实现 / 冗余测试 / 误导说明 |
| 位置 | `文件:行号`（可点击） |
| 现状证据 | 引用当前代码/文档内容，证明它确实在那 |
| 判断 | 为什么判定过期/冗余/死（谁还在引用？被什么替代了？） |
| 风险等级 | 删除风险（低/中/高）——高 = 删了可能坏构建/回归 |
| 处置建议 | 可直接删 / 需进一步确认 / 保留但更新 / 保留 |

**纪律**：
- **不动代码**。本分支只产报告，删除/修改留给后续分支（用户看完报告再决定）。
- **区分"本会话核实"与"文档历史记录"**，不把文档里的旧状态当事实。
- **给出删除风险分级**：有些"看起来死"的代码可能被反射/生成代码/测试间接引用，删前必须全局搜引用（`git grep`）。
- **回放基线 5/5/3 相关的测试/fixtures 一律标"不可删"**。

## 5. 关键纪律速查（违反会埋坑）

1. **不用 `git add -A`**：本分支只写报告文件，显式 stage 报告 md。
2. **不删不改代码/文档/测试**：只盘点，处置权在用户。
3. **删除风险分级要诚实**：拿不准"是否还被引用"的标"需进一步确认"，不要轻易标"可直接删"。
4. **回放基线 5/5/3 的测试/fixtures 不可动**：`test/domain_self_check_test.dart` + `test/fixtures/` 是硬约束。
5. **对照已知债务清单**：`architecture-analysis.md`/`refactor-report.md` 已记录的债务，别当新发现，要标注"已知"。
6. **文档状态核对用当前 main**：发版状态、版本号、分支 hash 以 main `b5b1768` 为准，不以文档快照为准。

## 6. 完成后的验证（报告写完后）

```bash
cd E:/AII/ugk-post-staleness-audit-2026-07-24
# 本分支只读不改，门禁应与 main 一致（确认没误改代码）：
flutter analyze                    # 0 issue（与 main 一致）
git status --short                 # 应只有新增的报告 md
git diff --stat                    # 应只有 +报告文件，无 lib/test 改动
```

若 `git diff` 出现 lib/test 改动，说明误改了代码，必须撤销（本分支只允许加报告）。

## 7. 与用户对话的建议开场

```
已读完交接。我在 investigate/staleness-audit-2026-07-24（worktree E:/AII/ugk-post-staleness-audit-2026-07-24），
基于最新 main@b5b1768，工作区干净。本次任务：只读审核 + 出报告，不动代码。

我已完成只读准备（读了 AGENTS.md、development-guide.md、architecture-analysis/plan、refactor-report）。
预扫发现的高发靶子：docs 116 个 md（archive/handoff/reviews 易过期）、claimLegacyForOwner 待核实是否活跃、
test 54 个需核实是否跟版本。

等你安排具体审核范围——全量审，还是只审 docs / 只审 lib / 只审 test？我产出清单报告（含位置+证据+删除风险分级），
你看完再决定删什么。
```

---

**交接结束。接手后先做只读准备，然后等用户安排审核范围，只出报告不动代码。**
