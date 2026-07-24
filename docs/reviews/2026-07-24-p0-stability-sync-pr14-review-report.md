# 审核报告：PR #14 `fix/p0-stability-and-sync-robustness` — P0 稳定性 + 同步健壮性

> 日期：2026-07-24
> 审核人：main reviewer
> PR：https://github.com/mhgd3250905/ugk-exercise/pull/14
> 分支：`fix/p0-stability-and-sync-robustness`（tip `2038602`，1 提交）
> 审查 worktree：`E:/AII/_review-p0-pr14`（detached @ `2038602`）

## 1. 结论

**代码修复审核通过（无 P0/P1，2 个 P2）。两个 P0 bug 经回溯确认真实存在、修复正确、无数据丢失风险。**

但有一个**必须先解决的合并前置问题（M0）**：PR 的 base 是**过时的 main**（`c6c6dc9`，ui-polish 合并前），与当前 `origin/main`（`5ad936e`，已含 ui-polish）不一致。**若直接合并（尤其 squash/rebase merge）会显示为回退 ui-polish 的 6 个提交**。所幸两组改动**文件零重叠、3-way merge 无冲突**，用正确的合并策略可安全并入。详见 §5。

## 2. 亲自验证结果（本会话运行）

| 门禁 | 结果 | 说明 |
|---|---|---|
| `flutter analyze` | **0 issue** | 审查 worktree |
| `flutter test` 全量 | **743 passed** | 与作者报告一致 |
| 回放基线 | **5/5/3** ✓（26 测试全绿） | `domain_self_check_test.dart` |
| `git diff --check` | 无空白错误 | 分支 vs base |
| 提交内容 | 1 提交 4 文件，全为任务文件，无临时文件污染 | `account/sync/session_store + 2 test` |

## 3. 两个 P0 bug 真实性回溯（PR#13 教训）

### Bug 1：`WorkoutSessionStore.load()` 崩溃 — ✅ 真实

**旧代码**（`c6c6dc9`，line 196）：
```dart
final raw = await file.readAsString();
final decoded = jsonDecode(raw) as List<Object?>;   // ← 直接强转
```
- 损坏/空 JSON → `jsonDecode` 抛 `FormatException`。
- 合法 JSON 但类型错（如 `{"key":"value"}`）→ `as List<Object?>` 抛 `CastError`。
- `load()` 被所有训练页调用 → **整页崩溃**。真实 P0。

**修复正确**：捕获 `FormatException` + `is! List<Object?>` 类型守卫 → 返回空列表优雅降级，下次写入覆盖坏文件。注释说明充分。
- 回归测试 3 个：坏 JSON / 空文件 / 错类型，均断言返回空不崩溃。✅

### Bug 2：单条坏 session 阻塞整批同步 — ✅ 真实

**旧代码**（`c6c6dc9`，`_syncOnce` line 121-123）：
```dart
final results = await _syncBatch(account, [
  for (final session in sessions) WorkoutSyncRequest.fromSession(session),
]);
```
- 列表推导在**传入 `_syncBatch` 前就求值**。`fromSession`（`membership_api_client.dart:40-42`）在 `localDate==null || timezoneOffsetMinutes==null` 时抛 `StateError`。
- 任一条遗留坏 session → 整个列表构建失败 → `_syncBatch`（网络请求）**永不发出** → 全部有效 session 永久 pending。真实 P0。

**修复正确**：逐条 try/catch，捕获 `StateError` 跳过坏 session，有效 session 正常组批发送。
- **无数据丢失风险**：跳过的坏 session 经 `markCloudSyncFailedForOwner`（store:297）标记为 `syncStatus: failed`，**显式追踪为失败而非静默丢弃**；用户可见、可重试/可上报，不会消失。
- 回归测试 2 个：(a) 一坏一好 → good 同步成功、bad 标 failed；(b) 全坏 → 0 次网络调用 + 全标 failed。精准覆盖。✅

## 4. 纪律核查

| 纪律 | 核查 | 结果 |
|---|---|---|
| `pushup_domain.dart` 纯 dart | 本次未触碰（只改 control/product UI 无关层） | ✅ |
| 回放基线 5/5/3 | 亲自跑 | ✅ |
| Worker 合同 | 本次无 worker 改动（作者报告 169 worker test，与本 PR 无关，未复跑） | ✅ N/A |
| 异步 session 守卫 | `_syncOnce` 内 `_isCurrent(account)` 守卫保留，skip 路径不影响 | ✅ |
| 不用 git add -A | 1 提交 4 文件全为任务文件 | ✅ |
| 数据正确性 | 坏 session 标 failed 显式追踪，非静默丢 | ✅ |

## 5. ⚠️ M0 合并前置问题（重要）

**现象**：PR base = `c6c6dc9`（ui-polish 合并前），当前 `origin/main` = `5ad936e`（已含 ui-polish 6 提交）。`gh pr view` 的 `diff` 因此把 ui-polish 的 6 个提交**显示为删除**（account_controller -34、leaderboard -222、pose_silhouette -36、l10n -8×4、account_test -90）。

**风险**：若用 GitHub 的 "Rebase and merge" / "Squash and merge"，会把分支内容**线性重放到 main 上**——由于分支基于旧 base，结果是把 ui-polish **回退掉**。**绝不能直接用这两种方式合并。**

**好消息**：本会话已验证两组改动**完全正交**：
- ui-polish 触及：`account_controller` / `leaderboard_page` / `pose_silhouette` / `l10n*` / `account_controller_test` / `leaderboard_page_test`
- PR14 触及：`workout_sync_controller` / `workout_session_store` / 两个对应 test
- **文件零重叠**。`git merge-tree` 干跑 + 实测 `git merge --no-commit --no-ff` 均**无冲突**（"Automatic merge went well"），合并后工作树**同时包含** ui-polish（`_ensureRevenueCatConfigured`/`_BreakdownRow`）和 PR14 修复（`on FormatException`/`on StateError`）。

**正确合并策略（二选一，推荐方案 A）**：

- **方案 A（推荐，干净 ff 历史）**：让作者把分支 rebase 到最新 `origin/main`（`5ad936e`），重新 push（需 force-push 授权），rebase 后 PR diff 就只剩真实修复、base 也对齐。rebase 后**重跑全量测试**确认无回归，再 ff-only 合并。
- **方案 B（可接受，多一个 merge commit）**：直接在本地 `git merge --no-ff origin/fix/p0-stability-and-sync-robustness` 生成 merge commit 保留两组历史，push。已实测无冲突、结果正确。缺点：main 多一个 merge commit。

> 我**不**在未授权下执行任何合并/rebase/push。等你决定方案。

## 6. P0 / P1 / P2

### P0（代码阻断）：无
### M0（合并流程阻断）：见 §5，base 过时，不能直接 rebase/squash merge，会回退 ui-polish。
### P1（需返工）：无

### P2（非阻断）

> 以下两个 P2 已于合并后（2026-07-24）由 main reviewer 用代码证据**闭环查证**，结论：**均无需处理**。

**P2-1｜坏 session 的 failed 状态与可见性 —— 已查证，暂不做**
- **更正本报告初版一处错误**：初版称"failed 不再进同步队列"是**错的**。实际 `pendingCloudSyncForOwner`（store）取 `pending || failed` —— **failed 的 session 下次同步会被重新尝试**（再次 `fromSession` 抛 `StateError` → 再次标 failed）。这是**良性循环**：坏数据反复试反复失败，但不会阻塞好数据，P0 修复的核心目标（有效 session 不被毒化）依然达成。
- UI 层**完全不展示 syncStatus**（`grep lib/ui/` 零引用），故用户对坏数据反复失败无感知。
- 结论：只影响极少数历史遗留脏数据、不影响新数据、不影响有效同步 → 危害极小，**暂不做**。真要清理可加一次性本地清理（标 failed 且 localDate==null 的旧 session），但需单独评估，不在本 PR 范围。

**P2-2｜缺字段 session 的根因 —— 已查证，根因已不存在（历史遗留），无需再修**
- `WorkoutSession` 的 `localDate`/`timezoneOffsetMinutes` 虽是**可选构造参数**（无 `required`，字段可空），但两个生产构造点现在**都填**：
  - `workout_page.dart:551`（训练结束主路径）：显式传 `localDate` + `timezoneOffsetMinutes`。
  - `membership_api_client.dart:571`（云端历史回填）：用 `_parseCloudLocalDate` 填。
- 另有兜底：`cacheCloudHistoryForOwner`（store:353-361）对 `localDate ?? 从 startedAt 推导` 回填。
- 结论：**当前代码路径不再产生缺字段 session**，缺字段只可能是**老版本/migration 期的历史遗留**。P0 修复正是防御这些遗留毒化队列，**属必要的防御，根因已是历史、无需再修。此条关闭。**

## 7. 审查产物

- 审查 worktree：`E:/AII/_review-p0-pr14`（合并后可清理）
- 本报告：`docs/reviews/2026-07-24-p0-stability-sync-pr14-review-report.md`

---

**审核结论：代码修复通过（2 个 P0 bug 真实、修复正确、无数据丢失）。**

**合并状态（2026-07-24 更新）**：已合并。
- base 过时问题按方案 A 解决：作者 rebase 到 `origin/main@5ad936e` 后 force-push（新 tip `b5b1768`），main reviewer 重新独立复核（base 对齐 / diff 干净无 ui-polish 回退 / analyze 0 / 745 passed / 回放 5/5/3）后走 `git merge --ff-only` + push。
- main 现为 `b5b1768`，与 origin/main 双向一致（0/0）；ui-polish 与 P0 修复两组改动均保留在 main。
- 2 个 P2（§6）经合并后查证已闭环：均无需处理（根因属历史遗留、已无新增；failed 循环属良性、不影响有效同步）。
