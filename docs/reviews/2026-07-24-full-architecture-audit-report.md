# PushupAI 全面架构审查报告

> 日期：2026-07-24
> 审查对象：`main@ca1bb464f55e502f5a465bef9eb95bcd118d1cfd`
> App 版本：`0.3.21+24`
> 审查性质：只读架构调查与问题核验，不包含修复
> 审查范围：Flutter App、产品/domain/control/UI/基础设施分层、账号与训练同步、排行榜、Worker/D1 合同、测试守护、权威文档一致性

## 1. 结论

PushupAI 当前不是一个无边界、不可维护的“屎山项目”。项目的主要架构骨架清楚，关键业务链路有较强测试守护：

- `pushup_domain.dart` 保持纯 Dart；
- 实时训练和回放共用 `PushupPipeline`；
- `WorkoutController` 的 session generation、异步守卫和资源所有权总体严谨；
- `AccountController` 是 App 内统一账号/会员状态源；
- Worker 统一复用权威会员判定；
- D1 migration、API 输入校验、owner 隔离和回放基线有专门测试。

本轮最终确认 **0 个 P0、3 个 P1、5 个 P2**。

三个 P1 都集中在跨模块状态机和 App–Worker 合同：

1. session 401 无法在当前进程收敛；
2. 训练同步丢弃 Worker 的逐条拒绝语义；
3. App 无界批量与 Worker 200 条上限不匹配。

这说明项目整体架构健康，但账号刷新、训练同步和排行榜查询已经出现局部架构腐化风险。继续扩展这些区域前，应先收口状态、数量和权威合同。

## 2. 审查与核验方法

本报告不是单一 agent 的一次性判断，而是经过以下闭环：

1. 从 `main@ca1bb46` 创建独立审查分支与隔离 worktree；
2. 独立审查任务只读检查 App、Worker、测试和权威文档；
3. 独立审查任务提交首轮问题清单；
4. main reviewer 回到 `main@ca1bb46`，逐项读取实现、调用方、测试和合同；
5. 对 P1-02 的“永久失败”表述提出反证；
6. 独立审查任务重新追踪所有 Worker reason，修订结论；
7. main reviewer 接受修订后的 8 项问题。

问题成立标准：

- 必须有精确实现和调用链证据；
- 必须能说明真实维护成本、错误风险或书面架构违约；
- 不仅凭文件行数、命名或个人风格判断；
- 历史文档中的已修问题不得作为当前问题；
- 生产规模未知时不得把可扩展性债务夸大为线上事故。

## 3. 严重度摘要

| 编号 | 严重度 | 结论 | 主要区域 |
|---|---|---|---|
| P1-01 | P1 | 被动刷新吞掉 401，失效账号不收敛 | AccountController / UI |
| P1-02 | P1 | 客户端丢弃逐条拒绝原因，无法分类重试 | App–Worker 同步合同 |
| P1-03 | P1 | App 无界批量与 Worker 200 条限制冲突 | 训练同步 |
| P2-04 | P2 | product 层声明与平台依赖实现冲突 | 分层边界 |
| P2-05 | P2 | 排行榜游标分页仍进行全量查询与排序 | Worker / D1 |
| P2-06 | P2 | 架构契约测试过度依赖源码字符串 | 测试架构 |
| P2-07 | P2 | 窄距识别权威文档阈值落后于代码 | 文档真源 |
| P2-08 | P2 | 本地训练历史损坏恢复可能覆盖原数据 | 本地持久化 |

## 4. 已验证问题

### P1-01：被动账号刷新把 401 当普通失败，失效 session 不会在当前进程收敛

#### 证据

- `lib/control/account_controller.dart:136-156` 的 `AccountController.refresh()`：
  - 调用 `_apiClient.me()`；
  - 使用统一 `catch (_) {}` 吞掉全部异常；
  - 没有识别 `MembershipApiException.statusCode == 401`。
- 对照 `lib/control/account_controller.dart:96-133` 的 `restore()`：
  - `restore()` 会单独识别 401；
  - 调用 `_clearAccountState()`；
  - 清除 `_sessionStore`。
- 刷新调用方：
  - `lib/ui/pages/home_page.dart:66-68`：App 回到前台；
  - `lib/ui/pages/profile_page.dart:76-83`：进入个人页；
  - `lib/ui/pages/profile_page.dart:347-351`：页面主动刷新。
- 书面合同：
  - `docs/design/app-ui-v1.md:203-205` 规定前台/个人页刷新，session 401 必须清缓存并恢复未登录；
  - `docs/modules/membership.md:283-285` 规定安全存储只用于冷启动展示，后台 401 按合同清除本地 session。

#### 影响

Worker 已撤销或过期的 session 仍保留在：

- Controller 内存状态；
- 本地安全存储；
- 当前页面展示。

用户会继续看到已登录账号。若缓存会员快照尚未本地过期，UI 还可能暂时显示 Premium；后续受保护请求则持续收到 401。重启后的 `restore()` 可以纠正，但当前进程不能收敛。

这是服务器权威状态与 App 状态分裂，不是异常处理风格偏好。

#### 建议方向

- `refresh()` 单独识别 401；
- 在 generation 和 current-account 守卫后清理内存与 secure store；
- 复用统一的身份清理逻辑；
- 网络断开、timeout、5xx 仍保持被动刷新不打断用户；
- 增加“旧账号 401 晚到不得清除新账号”的竞态测试。

### P1-02：客户端丢弃 `rejected.reason`，无法执行正确的分类重试策略

#### 证据

- Worker 在 `workers/membership-api/src/workouts.ts:26-29` 定义逐条：
  - `status: "rejected"`；
  - `reason`。
- Flutter 在 `lib/platform/membership_api_client.dart:67-98` 的 `WorkoutSyncResult` 只保留：
  - `clientSessionId`；
  - `status`；
  - `aggregated`。
- `reason` 没有进入客户端模型。
- `lib/control/workout_sync_controller.dart:148-166` 对所有 `rejected` 统一调用 `markCloudSyncFailedForOwner()`。
- `failed` 不是终止态：
  - `lib/product/workout_session_store.dart:311-320` 的 pending 查询返回 `pending` 和 `failed`；
  - `lib/product/workout_session_store.dart:323-337` 又会把 `failed` 重新置为 `pending`。
- 本地缺固定日期/时区元数据时：
  - `lib/platform/membership_api_client.dart:37-42` 抛 `StateError`；
  - `lib/control/workout_sync_controller.dart:121-136` 仍写成同一个 `failed`。
- 零次训练链路：
  - `lib/ui/pages/workout_page.dart:535-569` 停止时无 `count > 0` 限制，总会保存并尝试排队；
  - `workers/membership-api/src/workouts.ts:58-62` 拒绝 `metricValue <= 0`；
  - `docs/testing-release-playbook.md:285` 明确规定零次可保留本地，但不得成为待同步记录。

#### 必须保留的 reason 分类

普通重试不会改变结果的确定性无效项包括：

- `invalid_workout`；
- `invalid_client_session_id`；
- `invalid_exercise_type`；
- `invalid_metric`；
- `session_limit_exceeded`；
- `invalid_local_date`；
- `invalid_timezone`；
- 静态 `invalid_duration`：不可解析、`endedAt <= startedAt`、持续时间超过三小时；
- 客户端缺 `localDate` 或 `timezoneOffsetMinutes`。

不能直接判为永久终止的项包括：

- `premium_required`：会员恢复或重新收敛后可能成功；
- future timestamp 导致的 `invalid_duration`：随着服务端时间追上，同一 payload 可能变得有效；
- `daily_limit_exceeded`：固定训练日通常应终止自动重试，但退出/重加排行榜可能改变是否参与聚合，需要显式产品决策。

请求级网络错误、timeout、5xx、`membership_sync_unavailable` 没有逐条结果，应保持可重试，但需要明确触发和退避策略。

#### 影响

当前客户端把以下状态压成一个 `failed`：

- 确定性坏记录；
- 等待会员条件；
- 可随时间恢复；
- 网络瞬时失败。

结果包括：

- 零次、缺元数据、非法日期等记录反复上传；
- 队列无法收敛；
- UI、日志和测试无法解释记录处于何种状态；
- 不可终止记录会加速触发 P1-03 的 200 条批次上限。

#### 建议方向

- 端到端保留 Worker `reason`；
- 至少区分 `retryable`、`blockedOnPremium`、`terminal/localOnly`；
- terminal 记录退出 pending 数量，但保留本地历史及诊断原因；
- `premium_required` 只在 Worker 权威会员重新 active 后显式重新排队；
- 网络/timeout/5xx 保持 retryable 并加入有界触发或退避；
- 将 future timestamp 从通用 `invalid_duration` 中拆出；
- 未知 reason 作为协议兼容异常记录。

### P1-03：App 无界上传全部待同步记录，Worker 对单批硬限制 200 条

#### 证据

- `lib/control/workout_sync_controller.dart:111-141`：
  - 读取全部 `pendingCloudSyncForOwner()`；
  - 一次构造全部 `WorkoutSyncRequest`；
  - 一次调用 `_syncBatch()`。
- `lib/platform/membership_api_client.dart:341-355`：
  - 将整个 `workouts` list 放入单次 POST。
- 队列可批量增长：
  - `lib/control/workout_sync_controller.dart:51-59` 排整个账号历史；
  - `lib/control/workout_sync_controller.dart:62-77` 认领 legacy 历史；
  - `lib/product/workout_session_store.dart:323-337` 排全部 `localOnly/failed`。
- Worker 在 `workers/membership-api/src/workouts.ts:42-45` 定义 `MAX_BATCH_SIZE = 200`。
- `workers/membership-api/src/workouts.ts:117-123` 在 201 条时处理任何记录前直接返回 HTTP 400 `batch_too_large`。
- `workers/membership-api/test/workout-sync-sql.test.mjs:261-270` 已守护 201 → 400。
- App 端没有分块或上限合同测试。

#### 影响

长时间离线、旧历史认领或坏记录积累到 201 条后：

1. App 每次发送同一超大批次；
2. Worker 请求级拒绝；
3. 没有任何记录被处理；
4. 下一次仍发送全部记录。

同步队列由此确定性死锁。

P1-02 与 P1-03 是两个独立根因：

- P1-02 在单条 HTTP 200、逐条 rejected 时也会发生；
- P1-03 在 201 条全部合法时发生，Worker 根本不返回逐条 reason。

#### 建议方向

- 客户端按不超过 200 条分块；
- 最好由共享合同或客户端常量明确上限；
- 每块之间重新验证账号、会员和 session generation；
- 明确块级网络失败、逐条失败和部分完成策略；
- 覆盖 201、401 条、块间切账号和中途会员失效。

### P2-04：product 层的书面边界与实际平台依赖冲突

#### 证据

- `AGENTS.md` 和 `docs/development-guide.md` 声明 product 是产品规则层，只依赖 domain。
- `lib/product/workout_session_store.dart:1-6,184-456` 直接依赖：
  - `dart:io`；
  - `path`；
  - `path_provider`；
  - documents 目录；
  - JSON 文件、临时文件和 rename。
- `lib/product/voice_prompt_player.dart:1-132`：
  - 直接依赖 `audioplayers`；
  - 拥有 `AudioPlayer`；
  - 管理 stop/play/dispose 生命周期。
- `test/architecture_contract_test.dart:354-360` 只扫描 `pushup_domain.dart` 的平台依赖，没有扫描整个 product 目录。

#### 影响

当前 product 目录同时承担：

- 模型和产品规则；
- 仓储实现；
- 文件系统适配；
- 音频插件生命周期。

平台变化会侵入“纯产品规则”目录，新维护者也无法同时遵循文档和现有先例。问题首先是架构合同不真实，而不是要求为了形式拆文件。

#### 建议方向

- 先明确项目是否仍要求 product 为纯层；
- 若要求：product 保留模型、规则和 port，文件/插件实现移动到 platform；
- control 通过接口注入 repository/player；
- 增加 product 全目录依赖守护；
- 若决定接受混合层，则必须先修正文档和目录语义，避免虚假边界。

### P2-05：排行榜分页只减少响应体，Worker 每页仍执行 O(N) 查询和排序

#### 证据

- `workers/membership-api/src/leaderboard.ts:323-336`：
  - 查询全部 day/week rows；
  - 在 Worker 内存中执行 `rankRows()`。
- `workers/membership-api/src/leaderboard.ts:337-380`：
  - 加载屏蔽列表；
  - 过滤全部用户；
  - 找当前用户；
  - 为全部 rows 构建 metadata；
  - 最后才 `slice(0, leaderboardPageSize)`。
- `workers/membership-api/src/leaderboard.ts:519-558` 的 day/week SQL 使用 `.all()`，没有 `LIMIT` 或 cursor predicate。
- `workers/membership-api/src/leaderboard.ts:327-328` 的代码注释已承认未来需要 D1 keyset pagination。
- 当前分页测试仅覆盖较小数据集，不能证明大规模读取有界。

#### 影响

第 2 页和第 1 页仍会：

- 从 D1 读取所有 joined 用户；
- 对所有行排序和构建身份 metadata；
- 占用与用户数线性增长的 CPU、内存和 rows read。

当前生产用户量和延迟没有在本轮验证，因此保留为 P2，而不是线上 P1。

#### 建议方向

- 使用 D1 keyset/window 查询；
- 按 metric、排序字段和 cursor 只取 `pageSize + 1`；
- 当前用户 rank/detail 单独查询；
- 需要保留屏蔽过滤、冻结成绩、全局名次和稳定游标语义；
- 用大数据集测量 rows read、查询数、延迟和 Worker 内存后再确定紧迫度。

### P2-06：架构契约测试大量依赖源码字符串和语句顺序

#### 证据

`test/architecture_contract_test.dart` 共约 1094 行，其中大量测试直接读取生产源码：

- `test/architecture_contract_test.dart:419-431` 使用 `contains()` 判断 Pipeline wiring；
- `test/architecture_contract_test.dart:439-467` 使用精确方法字符串和 `indexOf()` 检查顺序；
- `test/architecture_contract_test.dart:746-820` 的 `expectGuardAfter()` 要求 await 后源码文本直接 `startsWith('if (session != _session) {')`；
- 同文件还有大量 UI、主题、wiring 的 contains/indexOf 检查。

#### 影响

- 私有方法提取、改名或等价结构调整可能导致无行为变化的失败；
- 注释、死代码或错误上下文中的同名文本可能满足部分断言；
- 测试容易让维护者误以为所有 await 都具有语义正确的 session 守卫；
- 测试维护成本与实现文本耦合，而不是与公开行为耦合。

项目已有大量高质量行为测试，因此问题不是“没有测试”，而是这部分架构测试的信号质量不稳。

#### 建议方向

- 保留少量简单的 import/layer 静态扫描；
- 生命周期、错误优先级和调用顺序改用 controlled fake 行为测试；
- 必须做结构检查时使用 analyzer/AST，而不是原始文本；
- 用 mutation 对比确认新守护能抓到真实缺陷，同时允许等价重构。

### P2-07：窄距识别权威文档阈值落后于生产实现

#### 证据

- `lib/product/narrow_pushup_form_gate.dart:33-45`：
  - `maxWristSpanRatio = 1.5`。
- `test/narrow_pushup_form_gate_test.dart:35-64`：
  - 守护 1.5 包含边界；
  - 大于 1.5 判定不匹配。
- `docs/modules/voice-themes.md:46`：
  - 纠错提示合同也写 `> 1.5`。
- `docs/modules/recognition.md:157-169,187-208`：
  - 仍写 `<= 1.25`；
  - 阈值表和历史理由均未同步到 1.5。

#### 影响

`recognition.md` 是算法审查和调参的权威入口。维护者按该文档会使用错误验收标准，可能把当前正确行为误判为回归，或再次改回旧阈值。

#### 建议方向

- 将 recognition 权威文档同步为 1.5；
- 补充本次放宽到 1.5 的真实依据；
- 将关键阈值集中到命名配置或可提取规范；
- 测试和文档从同一命名来源生成或校验。

### P2-08：训练历史损坏时可能静默覆盖原数据，结构化坏元素又会抛异常

#### 证据

- `lib/product/workout_session_store.dart:191-210`：
  - 文件不存在返回空；
  - 根不是 List 返回空；
  - JSON `FormatException` 返回空；
  - 注释明确说明下一次成功写会覆盖损坏内容。
- `lib/product/workout_session_store.dart:211-214`：
  - 对数组元素直接 cast 和 `WorkoutSession.fromJson()`；
  - `[{}]`、`[null]`、未知 schema 可能抛出 TypeError/FormatException。
- `lib/product/workout_session_store.dart:260-265`：
  - append 会在 load 结果上追加并写回。
- `lib/product/workout_session_store.dart:440-449`：
  - 临时文件最终 rename 到原路径。
- `test/workout_session_store_test.dart:25-48`：
  - 只验证损坏/空文件/错误根类型被当成空；
  - 没有 quarantine、backup、逐条跳过或 append-after-corruption 测试。

#### 影响

本地历史是离线训练记录的权威来源。当前恢复策略存在两种不一致结果：

- 非法 JSON 被当成空历史，下一次训练写入后原始损坏内容消失；
- 合法 JSON 中的单个坏元素可能使整个读取调用失败。

这可能造成不可逆历史丢失，或让记录页/同步消费者反复失败。

#### 建议方向

- 区分 missing 与 corrupt；
- 对损坏原文件做隔离或备份；
- 暴露受控降级状态，不把 corrupt 伪装成“无记录”；
- 数组逐项防御解析，定义坏元素隔离策略；
- 恢复策略确定前，不覆盖未知原始数据；
- 覆盖 invalid JSON → load → append、`[{}]`、`[null]`、未知 schema。

## 5. 已确认的架构优点

1. `pushup_domain.dart` 未导入 Flutter、camera、TFLite 或 `dart:io`。
2. 未发现 domain/product 中平均两个手腕坐标；肩/肘均值和手腕选择符合识别合同。
3. 实时计数和回放统一经过 `PushupPipeline`。
4. `WorkoutController` 的 session generation、await 后守卫、错误清理和资源所有权总体严谨。
5. domain/product/control 没有导入 `AppLocalizations`。
6. `AccountController` 在 App 根创建并共享，未发现页面级第二套账号/会员真源。
7. Worker 的会员鉴权统一复用权威入口，没有在排行榜、训练同步和账号路由中各实现一套会员规则。
8. D1 migrations 是部署正本，`schema.sql` 仅作参考；fresh、重复执行和 legacy 保留有迁移测试。
9. Worker 输入校验、鉴权、CSRF、webhook、quota 和真实 SQL 测试覆盖较全面。
10. release 配置使用 `String.fromEnvironment` 和 fail-fast；本轮未发现硬编码凭证。
11. API 请求统一有 timeout，没有危险的隐式无限网络重试。
12. owner-scoped 本地记录、云缓存和账号隔离模型清晰。

## 6. 已核验不存在或证据不足的问题

### 已核验不存在

- domain 反向依赖 Flutter/platform；
- l10n 泄漏到 domain/product/control；
- 计数信号平均左右手腕；
- 页面创建第二套账号/会员状态真源；
- `schema.sql` 被当成生产 migration 入口；
- production 配置硬编码真实密钥；
- 当前回放基线回归；
- 当前 Flutter/Worker 自动化失败。

### 证据不足，不应直接立项

- `profile_page.dart`、`leaderboard_page.dart`、`leaderboard_controller.dart` 很大，但仅凭 LOC 不能判为 god object；
- LeaderboardController 职责较多，但已有大量专门测试，是否拆分应根据变化原因、缺陷聚类和变更耦合决定；
- Home/Profile 中仍有缓存与平台动作编排，但除 P2-04 外，没有足够证据拆成新的独立问题；
- dev 工具链的依赖漏洞不能直接等同于 Worker 生产 runtime 漏洞；
- 未测量生产排行榜用户量、D1 rows read 或真实延迟，P2-05 不升级为 P1。

## 7. 验证记录

### 独立审查任务亲自运行

- `flutter analyze`：0 issue；
- `flutter test`：730/730；
- `flutter test test/domain_self_check_test.dart`：25/25，回放 `step0/v3/v4 = 5/5/3`；
- `flutter test test/pushup_session_replay_test.dart`：6/6；
- Worker `npm test`：169/169；
- `npm audit --omit=dev --json`：0 个生产依赖漏洞；
- `git diff --check`：clean。

独立 worktree 最初没有 `node_modules`，首次 Worker 测试因找不到 `tsc` 未启动；按 lockfile 执行 `npm ci` 后重跑通过。这是环境准备，不是产品失败。

### main reviewer 亲自运行

- 逐项读取本报告全部问题的生产实现、调用方、测试和权威文档；
- `flutter test test/account_controller_test.dart test/workout_sync_controller_test.dart test/workout_session_store_test.dart`：93/93；
- P1-02 退回复验后的同步专项：
  - Flutter 同步 Controller：20/20；
  - Worker workout sync 专项：30/30；
- `git diff --check`：报告写入前 main clean。

## 8. 未验证范围

本轮没有执行：

- 真机 camera/MoveNet/语音链路；
- Google OAuth Play 签名验收；
- Google Play Billing 或 RevenueCat 真实购买；
- 生产 Worker/D1 读写；
- Play Internal/Alpha 操作；
- 生产排行榜大规模延迟或 rows-read 压测；
- 本地历史真实损坏样本恢复。

这些未验证项不影响静态调用链和合同问题成立，但会影响整改验收方案。

## 9. 建议治理顺序

### 第一阶段：先修跨端状态机

1. P1-01：401 收敛与账号切换竞态；
2. P1-02：逐条 reason、terminal/blocked/retryable 状态；
3. P1-03：不超过 200 条分块与块间 session 守卫。

这三项应联合设计、分层提交，避免分别修补后再次产生状态组合漏洞。

### 第二阶段：保护真源与修正文档

4. P2-08：损坏历史隔离、备份和逐项解析；
5. P2-07：同步识别权威阈值；
6. 明确 P2-04 的 product 边界决策。

### 第三阶段：降低长期维护成本

7. P2-06：将脆弱源码字符串检查迁移为行为测试或 AST 检查；
8. P2-05：在真实规模数据下评估并实施 D1 keyset pagination。

## 10. 报告状态

- 本报告只记录已经过独立审查和 main reviewer 核验的结论；
- 当前未修改任何产品代码、测试、配置或远程状态；
- 当前未生成修复提交、PR 或发布产物；
- 下一步应先由另一名 agent 对本报告逐项做独立复核；
- 复核通过后，再把治理拆成可独立验收的功能分支，不建议直接在 main 上一次性重构。
