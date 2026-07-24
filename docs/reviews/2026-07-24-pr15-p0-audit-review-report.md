# PR#15 审核报告：fix/p0-audit-2026-07-24

> 日期：2026-07-24
> PR：[#15](https://github.com/mhgd3250905/ugk-exercise/pull/15) `fix: P0 audit — orphan-account race, consent fail-safe, corrupt-history crash, webhook flood, report DoS`
> 分支：`fix/p0-audit-2026-07-24` → `main`
> Base：`ca1bb46`（== origin/main，**base CURRENT，无需 rebase**）
> 审查 worktree：`E:/AII/_review-p0-audit`（detached @ `ce9537f`）
> 审查性质：main reviewer 只读复核，逐提交读 diff + 独立跑门禁 + 核实每个 bug 真实性

## 1. 结论

**审核通过。0 P0 / 0 P1 / 2 P2（均为可选改进，不阻断合并）。建议授权 fast-forward 合并。**

5 个 bug **全部经 main 上改前代码核实真实存在**，修复方向正确，论证充分，测试诚实（含真实 SQL 并发测试）。8 个提交均为独立原子提交，便于逐条核对。

### 与架构审查报告的关系（重要澄清）

本 PR 的"问题1-5"编号**不对应**此前复核的架构审查报告（`2026-07-24-full-architecture-audit-report.md` 的 P1-01/02/03、P2-04…08）。两份报告的问题集不同：
- 本 PR 修的是 5 个**独立安全/稳定性 bug**（孤儿账号竞态、同意门 fail-safe、历史防崩、webhook 幂竞态、举报 DoS）。
- 唯一重叠点是"历史记录防崩"——本 PR 的 `a792b39` 修的正是架构报告 **P2-08** 描述的"`[null]`/`[42]`/坏元素使整调失败"症状，但两者修复深度不同（见 §3 问题3 说明）。

## 2. 门禁（本会话在 review worktree 亲自运行）

| 检查 | 命令 | 结果 |
|---|---|---|
| 静态分析 | `flutter analyze` | **No issues found!（2.7s）** |
| Flutter 全量 | `flutter test` | **733/733 通过**（main 为 730，+3 新测试） |
| 回放基线 | `flutter test test/domain_self_check_test.dart` | **25/25 通过**，5/5/3 不变（PR 未碰算法层） |
| Worker | `cd workers/membership-api && npm ci && npm test` | **177/177 通过，0 fail**（main 为 169，+8 新测试） |
| 空白 | `git diff --check` | **clean** |
| 分层 | 改动仅在 `lib/platform/`、`lib/product/`、`workers/` | ✅ 未碰 `pushup_domain.dart` |
| 凭证 | 新增行无真实密钥，仅 `unit-test-*` 测试占位 | ✅ |
| migration | `0007_avatar_reports_reporter_idx.sql` 接 0006 之后 | ✅ 顺序正确，schema.sql 已镜像 |

新 worktree 首次跑 Worker 因无 `node_modules`，`npm ci` 后通过——属环境准备，非产品问题（与交接 §7 先例一致）。

## 3. 逐提交核验

### 问题2 `ebe3c78` consent fail-safe ✅

**bug 真实性（main `startup_preferences.dart:33-34` 核实）：** `_completed()` 的 `catch (_) { return true; }` 在 `flutter_secure_storage` read 失败时（如 Android keystore 被 backup restore 或 OS key reset 致效）返回 true → `cameraNoticeAcknowledged()` 返回 true → **静默跳过相机授权/隐私同意门**。`cameraNoticeAcknowledged` 正是 home_page 的相机授权门字段。

**修复正确：** 改为 `return false`（fail-safe），让同意门在 read 失败时重新弹出。注释充分说明合规方向。`_save` 失败仍 swallow（合理：避免崩在 app 入口）。

**测试诚实：** 原测试 `startup_preferences_test.dart` 把 buggy 行为钉死成 `isTrue`（即测试本身固化了 bug）；本提交改为 `isFalse` 并补 rationale。这是"测试守护 bug 而非守护正确行为"的典型案例，修正得当。

### 问题3 `a792b39` 历史防崩 ✅

**bug 真实性（main `workout_session_store.dart:211-214` 核实）：** `load()` 的 try/catch 只包 `jsonDecode`（语法错误）；结构损坏（`[null]`/`[42]`/`["abc"]`、字段类型错、不支持的 schemaVersion）会从 `WorkoutSession.fromJson` 抛出，使**整份训练历史不可读**，破坏其内联注释承诺的不变式。

**修复正确：** 逐元素 `try/catch`，跳过坏元素保留有效兄弟项。`schemaVersion` 和 write 路径未改 → 回放基线不受影响（已验证 5/5/3）。

**测试覆盖：** 新增 3 个用例——`[null,42,"abc"]`、坏兄弟+有效项、非数组顶层 JSON。

**⚠️ 与架构报告 P2-08 的关系（记录，非阻断）：** 本 PR 是"最小修复让屏幕不崩"（跳过坏元素）。架构报告 P2-08 的完整治理建议是"区分 missing/corrupt、隔离或备份坏原文件、暴露受控降级状态、不覆盖未知原始数据"。本 PR 跳过坏元素后，下一次成功写仍会覆盖原始损坏内容（`_write` rename 覆盖原路径）。两者不冲突——本 PR 解了 P2-08 最急的"整调失败"症状，P2-08 的 quarantine/backup 属后续增强。**建议 P2-08 治理时在本 PR 基础上叠加。**

### 问题1 `e6b9985` auth 孤儿用户（Google 登录事务）✅

**bug 真实性（main `index.ts:165-189` 核实）：** `authGoogle` 对新用户跑两个独立 `.run()`（INSERT users，再 INSERT auth_identities），无事务。并发同 Google subject 登录时，败者能先 INSERT users 成功，再因 `auth_identities` 的 `UNIQUE(provider, provider_subject)` 失败 → **孤儿 users 行**（永远无法登录、占用 email、破坏 one-account-per-identity）。

**修复正确：** 改为 `env.DB.batch([...])`（D1 单事务，原子提交/回滚）。任一失败则两者都回滚。

**测试诚实：** `auth-account-sql.test.mjs`（90 行）用真实 SQLite 复现竞态，断言败者干净回滚、无孤儿行。

### 问题4 `e6b9985` webhook 幂等竞态（同提交）✅

**bug 真实性（main `index.ts:263-296` 核实）：** RevenueCat webhook 先 read `processed_at` → 调 `reconcileMembership`（外部 RevenueCat 请求 + 快照写）→ 再 insert 幂等记录。两个并发 webhook（同 event.id）都能通过 read 检查 → **都执行外部工作**（重复 RevenueCat 调用 + 重复快照写）。

**修复正确：** 改为 `INSERT OR IGNORE` 先 claim 幂等记录 → 只有赢家（`claim.meta.changes === 1`）进入 reconcile → 败者直接返回 duplicate。**失败时释放 claim**（DELETE 记录 + 抛 503），避免临时下游故障被永久掩埋成"已处理"，让 RevenueCat 可重试。这个失败释放设计尤其正确——幂等不应把临时故障变成永久静默。

**测试诚实（PR#13 教训正面应用）：** `18bfd46` 提交专门说明——mock-DB 的并发测试因内存 facade 不 yield，**对旧代码也通过，不守护修复**。于是用真实 SQLite 驱动编译后 webhook handler，断言同 event.id 两次请求只触发一次 RevenueCat fetch/快照写，且 reconcile 失败时 claim 被释放、事件可重试。这是"测试要真正守护修复而非看起来通过"的标准范例。

### 问题5 `a88c4b1` + `e6eaf79` 举报 DoS（限频 + 分页 + 索引）✅

**bug 真实性（main 核实）：** `reportLeaderboardUser` 无 per-reporter 限频（仅有 per-target dedupe 索引），单账号可对任意多不同目标开举报 → 无界增长；`renderQueue`（admin.ts）`SELECT` 全部 open 举报并渲染进单个内存 HTML 串 → **OOM DoS 审核台**。

**修复正确（3 层）：**
1. `a88c4b1`：加 1 小时/20 条 per-reporter 滑动窗口（429 `rate_limited`）+ `renderQueue` `LIMIT 100`。
2. `e6eaf79`：migration 0007 加 `avatar_reports_reporter_created_idx`（否则限频 COUNT 自己退化为全表扫描，用一个 DoS 换另一个）+ renderQueue 加 `id` tiebreaker 稳定排序 + "显示最新100条，共N条"溢出摘要。
3. `ce9537f`：把新索引加入 `assertFullSchema`（防 migration 被掏空而 schema 守护漏过）。

**TOCTOU 处理得当：** 作者在 `e6eaf79` 代码注释中**明确承认** count-then-insert 非原子、并发可越过阈值，定位为"soft flood brake"（软刹车），目标是阻止无界洪泛（由 renderQueue LIMIT 100 兜底），而非硬安全上限。这是诚实的权衡声明，不掩盖局限。对审核台 DoS 场景，软刹车 + 渲染上限的组合是充分防护。

## 4. P2（可选改进，不阻断合并）

### P2-1：举报限频错误码可被前端区分消费

`reportLeaderboardUser` 返回 `429 rate_limited`，但 Flutter 客户端 `MembershipApiClient` 对非 2xx 统一抛 `MembershipApiException`（errorCode 取自 body 的 `error` 字段）。当前 `rate_limited` 能进 errorCode，UI 理论可据此提示"举报过于频繁"。但未见对应 UI 文案（ARB）和交互测试。**非阻断**——功能正确，只是前端体验可后续补。若补，记得 `rate_limited` 文案进 ARB（不硬编码 UI 层）。

### P2-2：历史防崩的覆盖范围（承接架构报告 P2-08）

见 §3 问题3 说明。本 PR 跳过坏元素后仍会覆盖原始损坏文件。若数据可恢复性重要，应在 P2-08 治理时加 quarantine/backup。**非阻断**——本 PR 已消除最急的"整调崩溃"风险。

## 5. 未验证范围

本轮未执行（均非本 PR 改动域，不影响静态/合同核验）：
- 真机 secure_storage keystore 失效场景（问题2 的真实触发条件，需真机）；
- 真实 RevenueCat webhook 并发（问题4 用真实 SQLite + mock RevenueCat 验证，未打真实外部服务，合理）；
- 生产 D1 上 auth 并发（问题1 用真实 SQLite 验证，D1 事务语义与 SQLite 一致，合理）；
- 审核台真机渲染（问题5 的 OOM 阈值未实测，但 LIMIT 100 的上界保护是确定的）。

## 6. 合并建议

- **审核通过**，建议授权 **fast-forward 合并**（base 已是最新 main，无 rebase 需要）。
- 合并命令（待用户授权后执行）：
  ```
  git checkout main
  git merge --ff-only origin/fix/p0-audit-2026-07-24
  git push origin main
  git fetch origin main && git rev-parse main origin/main
  ```
- **本 PR 含 D1 migration 0007**（新增索引）。若合并后要部署生产 Worker，须按 App+Worker 联动顺序：先部署含安全改动（本 PR 的 auth/webhook/限频）但旧清单的 Worker → 验证 → 再部署带 migration 0007 的清单。**但本次审核范围不含部署授权**，部署需用户单独授权。
- 审查 worktree `E:/AII/_review-p0-audit` 合并后可删（`git worktree remove`）。

## 7. 状态

- 本报告为 main reviewer **只读复核**，未修改任何产品代码/测试/配置/远程状态。
- 门禁数字为**本会话在 review worktree 亲自运行**结果。
- 等待用户授权后执行 fast-forward 合并 + push。
