# Main reviewer 复核:架构整改分支 fix/architecture-remediation-2026-07-24

> 日期:2026-07-24
> 复核对象:分支 `fix/architecture-remediation-2026-07-24`(远程 HEAD `c0ad47b`)
> 对比基线:`main@ce9537f`(== origin/main,**base CURRENT,落后 0 / 领先 11,无需 rebase**)
> 审查 worktree:`E:/AII/_review-arch-remediation`(detached @ `c0ad47b`)
> 对应问题集:架构审查报告 `2026-07-24-full-architecture-audit-report.md` 的 0 P0 / 3 P1 / 5 P2
> 审查性质:main reviewer 只读复核,逐项读代码 + 独立跑门禁 + 核实 rebase 冲突正确性

## 1. 结论

**审核通过。8 项整改全部落实,0 P0 / 0 P1 / 3 P2(均为措辞/记录类,不阻断合并)。建议授权合并。**

整改实质性完成,不是"只改测试/文档"。每个 P1/P2 都有对应的根因代码改动 + 测试守护。rebase 到 `main@ce9537f`(已含 PR#15)的冲突解决正确——PR#15 的损坏恢复语义完整保留并迁移到新的 platform 实现。

### 与汇报的措辞偏差(非阻断,记录)

1. **P2-06 措辞偏差**:汇报说 session 守卫"迁移为行为测试"。实际是**删除**了脆弱的源码字符串测试,其保护的语义由**整改前就存在**的 `workout_controller_test.dart` 行为测试覆盖(并非新迁移)。措辞略夸张,但实际保护在、且更健康(去掉了脆弱断言)。
2. 另见 §4 的 3 个 P2。

## 2. 门禁(本会话在 review worktree 亲自运行)

| 检查 | 命令 | 结果 |
|---|---|---|
| 静态分析 | `flutter analyze` | **No issues found!(5.0s)** |
| Flutter 全量 | `flutter test` | **744/744 通过**(main 733,+11) |
| 回放基线 | `flutter test test/domain_self_check_test.dart` | **25/25**,断言 step0=5 / v3=5 / v4=3 不变 |
| Worker | `cd workers/membership-api && npm ci && npm test` | **179/179,0 fail**(main 177,+2) |
| 空白 | `git diff --check origin/main...HEAD` | **clean** |

与汇报 §5 自述(744/744、25/25、179/179、analyze 0)一致,无虚报。新 worktree 首次跑 Worker 需 `npm ci`,属环境准备。

## 3. 逐项核验

### P1-01:401 收敛 + 账号切换竞态 ✅

**实现**(`account_controller.dart:136-171`):`refresh()` 现单独 `on MembershipApiException catch`,401 时三重校验 `request == _refreshRequest && _isCurrentAccount(generation, account)` 后才清理:
- `_refreshRequest++`(使后续晚到的同代请求失效)
- `_clearAccountState()`(清内存)
- `notifyListeners()`(立即通知 UI)
- `_serializeIdentity` 内再查 `currentSession == null`(:162)才清 secure store(双保险:清理期间若已登录新账号则不清)

**评估**:比我复核报告建议的"旧账号 401 晚到不得清新账号"更严谨。会员到期复核路径(`_drainMembershipExpiryVerification:514` 调 `refresh`)一并收敛——这正是我在复核报告 §4 补充意见 1 指出的影响面。**测试覆盖**:`account_controller_test.dart` +111 行,含 401 收敛与竞态场景。

### P1-02:reason 状态机 + 零次终止 ✅(端到端合同对齐)

这是改动最深的一项,核验了完整链路:

1. **Worker 端 reason 拆分**(`workouts.ts:87`):future 情况从 `invalid_duration` 拆出为独立 `future_ended_at`。**这是端到端正确性的关键**——原架构报告建议拆分,已落实。
2. **客户端 reason 保留**(`membership_api_client.dart:78,84,97-105`):`WorkoutSyncResult` 新增 `reason` 字段;`fromJson` 读 `json['reason']`,且 **rejected 时强制要求 reason 非空**(否则 FormatException)——合同守护。
3. **分类策略**(`workout_sync_policy.dart`):`classifyWorkoutSyncRejection` 四分类:
   - `premium_required` → blockedOnPremium
   - `future_ended_at` → retryable(与 Worker 拆出的 reason 对齐)
   - 其余 invalid_*/daily_limit → terminal
   - 未知 → protocolError
4. **状态机闭环**(`WorkoutSyncStatus` 7 态:`localOnly/pending/synced/failed/blockedOnPremium/rejected/protocolError`):
   - `failed` = 可重试(网络瞬时),在 `pendingCloudSyncForOwner` 重排 ✅
   - `rejected` = terminal,**不在** `pendingCloudSyncForOwner`(:327-333 只返回 pending+failed)→ 退出队列 ✅
   - `blockedOnPremium` 不在自动重排,只在显式 `queueOwnedHistoryForCloudSync` 重排 ✅
   - `protocolError` 不在任何重排 ✅
5. **零次训练**(`workout_sync_controller.dart:129-135`):`count <= 0` → `markCloudSyncLocalOnlyForOwner`,不再无限重试。且 `queueOwnedHistoryForCloudSync` 加了 `count > 0` 门控(:347)。

**测试**:`workout_sync_controller_test.dart` +403 行,含 reason 分类、零次终止、缺元数据隔离。状态机设计完整,terminal 不再无限重试。

### P1-03:200 条分块 + 块间守卫 ✅

**实现**(`workout_sync_controller.dart:20,152-183`):
- `maxBatchSize = 200` 常量(与 Worker `MAX_BATCH_SIZE` 对齐)
- 分块循环 `for (offset; offset < length; offset += 200)`,每块 `sublist(offset, end)`
- **每块前重验** `_isCurrent(account) || _premiumProvider()`(:153)——块间切账号/掉 Premium 立即停止

**测试**:`account switch between batches stops remaining old-account uploads`(测试名直接见证)。队列死锁根因消除。

### P2-04:product/platform 分层 ✅

**实现**:
- `lib/product/workout_session_store.dart` 现为 **abstract `WorkoutSessionRepository` port**(:190-276)+ 纯模型(`WorkoutSession`/`WorkoutSyncStatus`),**无平台依赖**(核验:`rg` 整个 `lib/product/` 无 `dart:io`/`path`/`path_provider`/`audioplayers`)。
- 实现迁到 `lib/platform/workout_session_store.dart`(529 行,持 dart:io/path)和 `lib/platform/audio_voice_prompt_player.dart`(137 行,持 audioplayers)。
- controller 经 repository 接口注入(`workout_sync_controller.dart:23` required `WorkoutSessionRepository`)。

依赖方向正确:product 只依赖 domain,port 在 product,实现在 platform,control 注入接口。**AST 守护**(`architecture_layer_test.dart`)用 analyzer 守护此边界。

### P2-05:leaderboard keyset 分页 ✅(子代理核验)

**实现**(`leaderboard.ts`):
- `leaderboardPageRows`(:571-607):SQL 带 `LIMIT 21`(`leaderboardPageSize+1`)+ keyset 谓词(`total_value < ? OR (total_value=? AND user_id>?)`)+ ORDER BY `total_value DESC, user_id ASC`。不再全量读。
- me 独立查询(`leaderboardSelfRow`:609-625,`WHERE user_id=? LIMIT 1`)。
- block 过滤在 SQL 内(:582-587 `NOT EXISTS user_blocks`),**先过滤后截断,不会漏人**。
- 全局名次由 CTE `ROW_NUMBER()` 在全部 joined 用户上计算,block 只影响可见行不重排名次。
- 冻结成绩 `frozenTotalValue` 保留(:356-357)。

**测试**:新增 `leaderboard-sql.test.mjs` 用真实 SQLite 端到端测分页 + block(25 用户 block 5 人,首页 ranks=[6..25] 证明不重排)。原 O(N) 全量读+内存切片问题消除。

### P2-06:AST 守护 + 源码字符串清理 ✅(措辞偏差,非阻断)

**AST 守护**(`architecture_layer_test.dart`,168 行):用 `analyzer` 的 `parseString` + 遍历 `NamespaceDirective` 守护 product 分层依赖,非字符串匹配。有专门测试验证注释里的 `import` 不被误识别、条件导入正确提取。扎实。

**源码字符串清理**:`architecture_contract_test.dart` 从 1094→722 行(-372)。删除的是 workout_controller 生命周期的脆弱源码断言。**session 守卫测试被删除**(非汇报说的"迁移为行为测试"),但语义由整改前就存在的 `workout_controller_test.dart` 行为测试覆盖(stale session 清理、start/switch/stop/dispose 资源收敛)。剩余 722 行是声明式接线契约(Android 资源/manifest/main 接线),对源码依赖可接受。

### P2-07:窄距阈值文档同步 ✅

三处全部统一为 **1.5**:
- `narrow_pushup_form_gate.dart:36` `maxWristSpanRatio = 1.5`
- `recognition.md:163`(`≤1.25`→`≤1.5`)、`:204`(阈值表 `1.25`→`1.5`,依据文字重写)
- `voice-themes.md:47`(`>1.5`,原本就对)
- `narrow_pushup_form_gate_test.dart` 边界测试以 1.5 为包含边界

全文无残留 1.25。算法权威文档与代码对齐。

### P2-08:损坏历史备份/逐项恢复 ✅(比 main 的 PR#15 更强)

**实现**(`platform/workout_session_store.dart`):
- **原始字节备份**:`_copyCorruptFile`(:465-513)写 `.corrupt.${ts}.${size}.bak` sidecar,临时文件+copy+逐字节校验+rename。
- **备份失败禁止覆盖**:`_recordCorruption`(:130-149)若备份抛 `FileSystemException` 且 `requireRecoveryBackup=true`,抛 `WorkoutSessionCorruptionException` 阻止后续 `_write` 覆盖原文件。`append`/`cacheCloudHistoryForOwner` 要求备份成功,只读 `load()` 不要求(best-effort)。
- **逐项恢复**:跳过坏元素保留有效兄弟(:103-116)。
- **区分 missing/corrupt**:`lastLoadIssue` 携带 type(`invalidJson`/`invalidRoot`/`invalidEntries`),corrupt 不再伪装成"无记录"。

**rebase 冲突正确性(关键)**:PR#15(main)给 product/workout_session_store.dart 加的逐元素跳过逻辑,在整改把该文件改成 port 后,**正确迁移到 platform/workout_session_store.dart** 实现,逻辑更强(还触发备份+计数)。PR#15 的 3 个测试场景全覆盖(2 个合并为更严格的 1 个 + 1 个原样保留)。**无语义丢失**。

## 4. P2(可选改进,不阻断合并)

### P2-1:汇报 P2-06 措辞偏差(建议修正文档,非代码)

汇报说 session 守卫"迁移为行为测试",实际是删除脆弱源码断言、依赖既有行为测试。建议在最终报告/汇报里把措辞改为"移除脆弱的源码字符串守卫,其语义由 workout_controller_test.dart 既有行为测试覆盖",避免误导。**非代码问题**。

### P2-2:leaderboard 每次请求仍全量计算窗口排名

子代理观察:page + self 两次查询都会对全量 joined 用户重新计算 CTE 窗口排名(DB 侧仍 O(N log N)),Worker 侧已不 O(N) 内存/排序。当前不构成正确性回归,生产用户量未测。建议日后观测 D1 rows read,必要时把 self 名次优化为 `COUNT(*)+1`。**非阻断**——Worker 侧的 O(N) 内存问题(原 P2-05 核心)已解决。

### P2-3:测试名追溯性

PR#15 的两个测试名(`load skips non-map array elements` / `load keeps valid sessions skipping corrupt sibling`)被合并为一个更严格的测试(`load keeps valid entries and quarantines invalid list entries`),行为覆盖更强但原名称消失。若团队策略要求保留测试名做追溯,需留意。**非阻断**——覆盖更全。

## 5. 未验证范围

- 真机 camera/MoveNet/语音/secure_storage(keystore 失效)链路;
- 生产 D1 leaderboard 大规模 rows read/延迟(子代理已建议观测);
- 真实 RevenueCat webhook(用真实 SQLite + mock 验证);
- 真实损坏文件用户提示 UI(`lastLoadIssue` 已暴露状态,但 UI 消费未在本分支验证)。

不影响静态/合同/状态机问题成立。

## 6. 合并建议

- **审核通过**,建议授权合并。base 已是最新 main,可 fast-forward 或合并提交。
- **注意:本分支改了 Worker**(`leaderboard.ts` keyset + `workouts.ts` reason 拆分)。若合并后部署生产 Worker:
  - `workouts.ts` 的 `future_ended_at` reason 拆分是 **App-Worker 合同变更**——**必须 App 和 Worker同时部署**,否则:新 Worker 返回 `future_ended_at`,旧 App 的 `classifyWorkoutSyncRejection` 不认识它 → 归 protocolError(不会崩,但 future 记录不会正确 retryable)。或旧 Worker 仍返回 `invalid_duration`,新 App 把它归 terminal(语义偏严但不崩)。
  - 安全顺序:**先部署 Worker(返回新 reason)→ 再发新 App(消费新 reason)**。或同批部署。
  - leaderboard keyset 改动不依赖 App(响应结构兼容)。
  - **部署需单独授权**,本次审核不含部署。
- 审查 worktree `E:/AII/_review-arch-remediation` 合并后可删。

## 7. 状态

- 本报告为 main reviewer **只读复核**,未修改任何产品代码/测试/配置/远程状态。
- 门禁数字为**本会话在 review worktree 亲自运行**结果。
- 等待用户授权后执行合并 + push(以及是否部署 Worker,另行授权)。
