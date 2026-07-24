# Main reviewer 复核：全面架构审查报告

> 日期：2026-07-24
> 复核对象：`docs/reviews/2026-07-24-full-architecture-audit-report.md`（独立审查任务产出）
> 复核基线：`main@ca1bb464f55e502f5a465bef9eb95bcd118d1cfd`
> App 版本：`0.3.21+24`
> 复核性质：main reviewer 逐项重新读代码、跑门禁、独立核验，不采信报告自述

## 1. 复核结论

**报告 8 项问题（0 P0 / 3 P1 / 5 P2）全部成立，证据准确，严重度分级合理。**

main reviewer 亲自：
- 逐项读取了 8 项问题的生产实现、调用方、测试和权威文档，行号与内容全部对得上；
- 独立运行全部门禁，数字与报告 §7 自述一致；
- `git diff --check` clean，main 工作区未修改任何产品代码（本次只读复核）。

复核未发现虚构问题、行号错位、夸大影响或把历史已修问题当现状的情况。报告可作为后续治理的依据。

报告唯一可强化的点见 §3（不阻断立项）。

## 2. 门禁（本会话亲自运行）

| 检查 | 命令 | 结果 |
|---|---|---|
| 静态分析 | `flutter analyze` | **No issues found!（14.4s）** |
| 全量测试 | `flutter test` | **730/730 通过（33s）** |
| 回放基线 | `flutter test test/domain_self_check_test.dart` | **25/25 通过**；测试名直接断言 `Step0=5` / `video3=5` / `video4=3` |
| 401/同步/持久化专项 | `flutter test test/account_controller_test.dart test/workout_sync_controller_test.dart test/workout_session_store_test.dart` | **93/93 通过** |
| 同步 controller 专项 | `flutter test test/workout_sync_controller_test.dart` | **21/21 通过** |
| 窄距门控专项 | `flutter test test/narrow_pushup_form_gate_test.dart` | **12/12 通过** |
| Worker | `cd workers/membership-api && npm test` | **169/169 通过，0 fail** |
| 空白检查 | `git diff --check` | **clean** |
| 工作区 | `git status --short` | 仅 untracked，无 tracked 改动 |

报告 §7 自述的 `flutter test 730/730`、`domain_self_check 25/25`、`Worker 169/169` 与本会话结果一致，无虚报。

## 3. 逐项核验

### P1-01：refresh() 吞 401，失效 session 不收敛 ✅ 成立

**亲自核实：**
- `account_controller.dart:136-157` 的 `refresh()`：`catch (_) {}` 吞掉全部异常，**没有** `MembershipApiException` 区分或 401 识别。
- 对比 `restore()`（:122-132）：单独 `on MembershipApiException catch (error)` + `error.statusCode != 401` 判断 + `_clearAccountState()` + `_sessionStore.clear()`。二者处理 401 的差异确实存在。
- 调用方确认：
  - `home_page.dart:67`：`onResume` 调 `refresh()`（前台刷新）。
  - `profile_page.dart:83`：`initState` 调 `refresh()`（进个人页刷新）。
- 文档合同确认：
  - `app-ui-v1.md:205`："session 返回 401 时必须清除缓存并恢复未登录态。"
  - `membership.md:285`："后台 401 会按原合同清除本地 session。"

**判定：** refresh() 与 restore() 对 401 的处理不一致是真实违约，文档明确要求后台 401 清缓存。P1 合理——失效 session 在当前进程不会收敛，重启才能纠正。

### P1-02：客户端丢弃 reason，无法分类重试 ✅ 成立

**亲自核实：**
- Worker `workouts.ts:26-29`：`SyncResult` rejected 变体带 `reason: string`。
- Flutter `membership_api_client.dart:67-98`：`WorkoutSyncResult` 只有 `clientSessionId` / `status` / `aggregated`，**fromJson 丢弃 `reason`**。
- `workout_sync_controller.dart:148-166`：所有非 accepted/duplicate 统一 `markCloudSyncFailedForOwner()`。
- `workout_session_store.dart:311-320`：`pendingCloudSyncForOwner` 返回 pending **和** failed（:318）。
- `workout_session_store.dart:323-337`：`queueOwnedHistoryForCloudSync` 把 `failed` 重新置 `pending`（:330）→ failed 确实非终止态，会被反复重排。
- 缺元数据：`membership_api_client.dart:37-42` 抛 `StateError`；`workout_sync_controller.dart:130-136` catch 后 `markCloudSyncFailedForOwner` → 同一 failed 状态。
- 零次训练链路：`workout_page.dart:555` `count: _controller.count`、:567-569 总是 `append` + `queueAfterLocalSave`，**无 `count > 0` 门控**；Worker `workouts.ts:59` 拒绝 `metricValue <= 0`；`testing-release-playbook.md:285`："零次训练适合保留在本地，但不应被当成'等待同步'。" 链路完整。

**判定：** 确定性坏记录（零次/缺元数据/非法日期）与可恢复项（premium_required/网络）被压成一个 failed 并反复重排，队列无法收敛。P1 合理。报告中 terminal/blocked/retryable 三分类与 reason 清单准确（核对了 workouts.ts 全部 reject 路径：invalid_workout / invalid_client_session_id / invalid_exercise_type / invalid_metric / session_limit_exceeded / invalid_local_date / invalid_timezone / invalid_duration(静态+future) / premium_required / daily_limit_exceeded）。

### P1-03：App 无界批量 vs Worker 200 条上限 ✅ 成立

**亲自核实：**
- `workout_sync_controller.dart:116`：`pendingCloudSyncForOwner` 读全部；:141 `_syncBatch(account, requests)` 一次传全部。
- `membership_api_client.dart:341-355`：整个 `workouts` list 放入单次 POST body。
- 队列可膨胀：`syncForCurrentAccount`→`queueOwnedHistoryForCloudSync`（全历史）、`claimLegacyForOwner`（legacy 历史）、`queueOwnedHistoryForCloudSync`（failed 重排）。
- Worker `workouts.ts:44` `MAX_BATCH_SIZE = 200`；:121-123 `> 200` 直接 `batch_too_large` HTTP 400，**处理任何记录前返回**。
- 守护测试存在（`workout-sync-sql.test.mjs`，对应 npm test 里 "oversized batch ... are rejected" ✔）。

**判定：** 201+ 条时 Worker 请求级拒绝、无逐条结果、客户端下次仍发全部 → 确定性死锁。与 P1-02 根因独立（P1-03 在全合法记录时也发生）。P1 合理。

### P2-04：product 层边界与平台依赖冲突 ✅ 成立

**亲自核实：**
- `AGENTS.md` / `development-guide.md` 声明 product 只依赖 domain。
- `workout_session_store.dart:1-6`：`dart:io`、`package:path`、`package:path_provider` + :184-456 直接操作 Directory/File/rename。
- `voice_prompt_player.dart:1`：`package:audioplayers`；类内持有 `AudioPlayer`、管理 stop/play/dispose 生命周期（:108-132）。
- `architecture_contract_test.dart:354-361`：只扫 `lib/pushup_domain.dart`，**未扫 product 目录**。

**判定：** product 同时承载规则 + 仓储 + 文件系统 + 音频插件生命周期，与文档声明冲突。报告措辞克制（"首先是架构合同不真实，而不是要求为了形式拆文件"），P2 合理。这需先做产品决策（纯层 vs 接受混合层），不是直接重构。

### P2-05：排行榜分页只减响应体，Worker 仍 O(N) 查询排序 ✅ 成立

**亲自核实：**
- `leaderboard.ts:323-336`：`dayRows`/`weekRows` 取全部 → `rankRows()` 内存排序。
- `leaderboard.ts:337-380`：加载屏蔽列表 → 过滤全部 → 找当前用户 → 为全部 rows 建 metadata → 最后 :356 `slice(0, leaderboardPageSize)`。
- `leaderboard.ts:519-558`（day/week SQL）：`.all()`，无 LIMIT/cursor。
- :327-328 代码注释自认 "move the opaque cursor behind D1 keyset pagination if leaderboard latency grows"。

**判定：** 第 2 页仍全量读+排序+建 metadata，CPU/内存/rows read 随用户数线性增长。报告未测生产规模，故保留 P2 而非 P1，分级诚实。P2 合理。

### P2-06：架构契约测试依赖源码字符串 ✅ 成立

**亲自核实：**
- `architecture_contract_test.dart:429-431`：`expect(body, contains('PushupPipeline'))` 等。
- :439-467：`indexOf` 取方法体切片 + 精确字符串 + `indexOf` 比较顺序（:455-457 比Voice.stop 与 dispose 的先后）。
- :751-762 `expectGuardAfter`：`afterAwait.startsWith('if (session != _session) {')` —— 直接要求 await 后源码文本以该语句开头。

**判定：** 私有方法改名/提取/等价重构可能导致无行为变化的失败；注释或死代码里的同名文本可能误满足断言。P2 合理（报告也指出"项目已有大量高质量行为测试，问题不是没测试，而是这部分信号质量不稳"）。

### P2-07：窄距识别权威文档阈值落后于代码 ✅ 成立

**亲自核实：**
- `narrow_pushup_form_gate.dart:36`：`maxWristSpanRatio = 1.5`（默认值，实际生效值）。
- `recognition.md:163`：仍写 `腕宽 / 肩宽 ≤ 1.25`；:204 阈值表 `narrow.maxWristSpanRatio | 1.25`。
- `voice-themes.md:46`：纠错提示合同写 `> 1.5`（与代码一致）。
- 即：代码与语音合同是 1.5，唯独算法权威文档 recognition.md 停留在 1.25，三处不同步。

**判定：** recognition.md 是算法调参权威入口，按它验收会把当前正确行为误判为回归。P2 合理。

### P2-08：损坏历史可能覆盖原数据，结构化坏元素又抛异常 ✅ 成立

**亲自核实：**
- `workout_session_store.dart:191-210`：文件不存在→空；非 List→空；FormatException→空（注释明言"下一次成功写会覆盖损坏内容"）。
- :211-214：`WorkoutSession.fromJson(Map<String,Object?>.from(item! as Map))` —— 对 `[{}]` 抛 TypeError、`[null]` 抛 TypeError、未知 schema 抛 FormatException（:73-74 schemaVersion 检查），**整个 load 调用失败**。
- :260-265 append 在 load 结果上追加写回；:440-449 rename 覆盖原路径。
- 测试 `workout_session_store_test.dart:25-48`：只覆盖 corrupted JSON / 空文件 / 错误根类型当空，**无** quarantine/backup/逐条跳过/`[{}]`/`[null]`/append-after-corruption 用例。

**判定：** 两种不一致结果真实存在（非法 JSON 静默当空后覆盖 vs 合法 JSON 单坏元素整调失败）。P2 合理。

## 4. 对报告的补充意见（不阻断立项）

1. **P1-01 影响面可再精确**：`refresh()` 在 `_drainMembershipExpiryVerification()`（:500）也会被调（会员到期定时器触发）。即 401 不收敛不仅影响前台/个人页主动刷新，也影响"会员到期自动续验"路径——失效 session 到期后 refresh 仍吞 401，UI 可能继续显示过期会员态。这加强而非削弱 P1，整改时该路径要一并覆盖。

2. **P1-02 的 reason 清单建议入测试**：报告列出了 terminal/blocked/retryable 三类 reason，但这些分类目前**没有任何测试守护**（WorkoutSyncResult 根本不持 reason）。整改时建议先写"reason 端到端保留 + 分类"的失败测试再实现，符合项目红-绿-整理纪律。

3. **P2-04 与 P2-06 有关联**：`architecture_contract_test.dart` 只扫 domain 不扫 product，正是 P2-04 描述的"虚假边界"在测试侧的体现。若决定 product 维持混合层，契约测试也不必扩展到 product；若决定拆纯层，契约测试要同步加 product 守护。两者应协同决策。

4. **报告 §2 的"闭环"措辞**：报告自称经过"独立审查 → main reviewer 反证 → 修订 → main reviewer 接受"闭环。本次复核确认修订后的 8 项确实成立，但闭环过程本身无法从代码验证——这属于过程声明，不影响问题成立性。

## 5. 复核产出与下一步

- 本复核报告已写入 `docs/reviews/2026-07-24-full-architecture-audit-review-report.md`。
- **未修改任何产品代码、测试、配置或远程状态**（main reviewer 只读复核）。
- 报告 §9 的三阶段治理顺序（先 P1 跨端状态机联合设计 → 再 P2 真源/文档 → 最后降维护成本）合理，建议采纳。
- **建议治理方式**：每个 P1/P2 拆成独立功能分支，按报告 §9 顺序逐个评审合并；P1-01/02/03 报告已建议联合设计、分层提交，避免分别修补后产生状态组合漏洞——认同。
- 复核通过后，下一步由用户决定是否启动治理分支；main reviewer 不主动开分支改代码。

## 6. 状态词精确性

- 原报告：**只读架构调查与问题核验**，未修改代码/测试/配置/远程状态——本会话核实属实（main 工作区无 tracked 改动）。
- 本复核：同样**只读**，未生成修复提交、PR 或产物。
- 门禁数字为**本会话亲自运行**结果，非引用报告自述。
