# Audit Remediation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Every App/Worker task must also use `manage-pushupai-project` and test-driven development.

**Goal:** 在不改变计数算法、会员授权语义和已通过的管理台真实浏览器链路前提下，修复已核实的安全、异步生命周期、网络超时与本地数据完整性问题，并把误报和未经测量的优化从整改范围中剔除。

**Architecture:** 采用风险优先、分批提交的路线。Worker 管理台保留生产所需的 `Origin: "null"` 兼容，但用与 Access 身份绑定的 HMAC CSRF token 建立真正的请求意图证明；`WorkoutController` 明确为单训练会话对象并拒绝重复启动；会员 HTTP 请求统一收敛到可测试的 timeout 边界；训练记录先实现崩溃可恢复写入，再决定是否迁移存储技术。性能和分层问题只在测量或架构决策成立后进入实现。

**Tech Stack:** Flutter 3.44.7、Dart 3.12.2、Flutter unit/widget tests、Cloudflare Workers、TypeScript、Node test runner、D1、Web Crypto API。

---

## 0. 基线、范围与成功标准

- 源码基线：`main@60638aa1633940fb2fe7246397110078897f88c6`。
- 当前门禁：`flutter analyze` 0 issue、Flutter 671/671、domain self-check 26/26、Worker 161/161、回放 5/5/3。
- 用户文件 `docs/audit-2026-07-22-full-review.md` 当前未跟踪；实施时不得被隐式 stage、删除或覆盖。
- 每个任务都必须按“失败测试 → 最小实现 → 聚焦测试 → 全量门禁 → 独立提交”执行。
- 不 push、不部署 Worker、不改 D1、不轮换 Token、不改 Google Play，除非用户对该次远程动作单独授权。

### 重新分级

| 等级 | 项目 | 处理决定 |
|---|---|---|
| 平台 P0 | Google Play UGC/Data safety/内容分级；历史 legacy Cloudflare Token | 独立授权轨道，Production 前完成；不与源码提交混在一起 |
| 代码 P1 | 管理台 `Origin:null` 缺少独立 CSRF 证明 | 立即修；必须保留真实 Access 浏览器兼容 |
| 代码 P1 | `WorkoutController` 可重复 `start()`，`stop()`/异常清理缺生命周期所有权 | 立即修；把 Controller 明确为单训练会话对象 |
| 代码 P1 | `MembershipApiClient` 无统一 timeout | 立即修；本批不自动重试写请求 |
| 代码 P2 | 训练记录直接覆写 JSON，崩溃时可能截断 | 下一批修；实现 crash-consistent temp/backup 恢复 |
| 代码 P2 | step0 专用 `SignalFilter`、弃用 `pressDepthY` 和双腕平均死代码 | 下一批清理；先证明 raw step0 仍为 5 |
| 代码 P2 | JWT algorithm 白名单、`X-Frame-Options`、未使用 Worker Secret 合同 | 与 Worker 安全加固分开提交 |
| 决策项 | product/platform 边界矛盾、契约测试覆盖不足 | 先写架构决定，再决定是否迁移文件；不与行为修复混改 |
| 测量项 | 主 isolate 预处理、排行榜全量排序、JSON O(n) 性能 | 先 profile/benchmark；无阈值证据不重构 |
| 接受/关闭 | app-scoped Controller 无 dispose、`handsStable` 诊断参数、report/perf 未登记、forward-only migration、回放不覆盖全部门控 | 不改代码；在复核报告中更正或记录设计意图 |

### 明确非目标

- 不把移动平均重新放回生产 `PushupPipeline`。
- 不给 `_workoutSessionMutationQueue` 直接套 `.timeout()`；Dart timeout 不取消底层 I/O，会破坏写入串行。
- 不对所有 HTTP 写请求做自动重试；幂等策略必须逐端点设计。
- 不在没有 profile 数据时使用逐帧 `Isolate.run()`。
- 不为当前 app-scoped `LeaderboardController` / `AppSettingsController` 添加假想生命周期代码。
- 不修改 forward-only migration 0004，不新增 down migration。

## Milestone A：下一次 App/Worker 候选前完成

### Task 1: 为管理台 POST 增加 Access 身份绑定的 CSRF token

**Files:**

- Create: `workers/membership-api/src/admin_csrf.ts`
- Modify: `workers/membership-api/src/admin.ts`
- Modify: `workers/membership-api/test/admin.test.mjs`
- Modify: `docs/modules/membership-admin.md`

**Step 1: 先写失败测试**

在 `admin.test.mjs` 增加以下行为测试：

1. `GET /admin/members` 和 `GET /admin/avatar-reports` 的每个 POST form 都含隐藏 `csrfToken`。
2. `Origin: "null"` + 正确 token 仍返回 303，保留已经过生产验证的 Access 浏览器链路。
3. `Origin: "null"` + 缺失、篡改或另一 Access actor 的 token 返回 403，且不执行 RevenueCat 对账、不写审核动作。
4. foreign Origin 即使携带正确 token 仍返回 403；空 Origin 仍返回 403。

**Step 2: 运行聚焦测试并确认 RED**

```powershell
cd workers/membership-api
npm run check
npm run build:test
node --test --test-name-pattern="CSRF|same-origin POST|moderation actions" test/admin.test.mjs
```

Expected: FAIL，因为页面尚未渲染 token，POST 尚未校验 token。

**Step 3: 实现最小的无状态 token**

在 `admin_csrf.ts` 中使用 Web Crypto HMAC-SHA256：

```ts
token = HMAC_SHA256(env.SESSION_SECRET, `admin-csrf:v1:${actor}`)
```

- token 绑定已经通过 Access JWT 验证的 actor；不新增 Cookie、D1 表或 Secret。
- 使用固定长度比较，拒绝非 64 位十六进制 token。
- GET 渲染时把 token 传给 `renderMemberships`、`loadMemberDetail`、`renderQueue`、`renderReport`，所有 POST form 添加隐藏字段。
- POST 只解析一次 `FormData`，先验证 Origin 为同源或字面量 `null`，再验证 CSRF token，最后把同一份 `FormData` 交给 action handler。
- foreign/missing Origin 继续作为第二层防御；不要删除 `Origin:null` 兼容。

**Step 4: 运行测试**

```powershell
cd workers/membership-api
node --test test/admin.test.mjs
npm test
```

Expected: admin 聚焦测试和 Worker 全量测试全部 PASS。

**Step 5: 更新合同并提交**

`membership-admin.md` 应明确：Access JWT 是身份鉴权，CSRF token 是写入意图证明，Origin 校验是兼容性防御；三者职责不能混写。

```powershell
git add workers/membership-api/src/admin_csrf.ts workers/membership-api/src/admin.ts workers/membership-api/test/admin.test.mjs docs/modules/membership-admin.md
git commit -m "fix(worker): bind admin posts to csrf token"
```

### Task 2: 收紧 WorkoutController 单会话生命周期

**Files:**

- Modify: `test/workout_controller_test.dart`
- Modify: `test/architecture_contract_test.dart`
- Modify: `lib/control/workout_controller.dart`
- Modify: `docs/modules/workout-controller.md`

**Step 1: 写失败的竞态测试**

逐个添加并单独运行：

1. 第一次 `start()` 尚未完成时再次 `start()`，模型和相机只创建一代。
2. `stop()` 卡在 end-of-frame、voice stop、subscription cancel 或 camera dispose 时调用 `start()`，第二次启动被拒绝，stop 只清理原资源一次。
3. `dispose()` 发生在 stop/异常清理期间时，不再通知 UI，资源清理由 dispose 路径接管。
4. start/switch 异常清理的每个 await 后，过期 session 不得继续改状态或继续处置资源。

**Step 2: 运行并确认 RED**

```powershell
flutter test test/workout_controller_test.dart --plain-name "start is ignored while the same workout session is active"
flutter test test/workout_controller_test.dart --plain-name "start cannot replace resources while stop is cleaning up"
```

Expected: 至少第二项在当前实现中失败，能复现审核指出的资源所有权问题。

**Step 3: 实现单会话合同**

- 增加私有 `_started`，在 `start()` 第一个 await 前置为 true；同一 Controller 后续 start 直接返回。
- `_disposed` 后的所有命令直接返回。
- `stop()` 捕获本次 session；每个 await 后检查 session。session 失效时由更新操作或 dispose 路径负责清理，旧路径不得继续更新状态。
- start/switch 的 catch cleanup 保留操作标志直到清理结束，并在每个 await 后检查 session。
- 不引入通用 async queue：相机切换和 stop 需要“新操作使旧操作失效”，不能被长队列阻塞。
- Controller 启动失败后的重试通过退出训练页、创建新 Controller 完成；当前 UI 本来就没有页内重启入口。

**Step 4: 更新旧测试语义**

把“同一 Controller 在 switch 中再次 start 并生成新相机代”的人工场景改为“重复 start 被拒绝，原 switch 或 stop 仍能安全收束”。保留真实的 stop-during-switch、blocked inference 和 repeated stop 回归。

**Step 5: 验证并提交**

```powershell
dart format lib/control/workout_controller.dart test/workout_controller_test.dart test/architecture_contract_test.dart
flutter test test/workout_controller_test.dart test/architecture_contract_test.dart
flutter test test/pushup_session_replay_test.dart test/domain_self_check_test.dart
git diff --check
git add lib/control/workout_controller.dart test/workout_controller_test.dart test/architecture_contract_test.dart docs/modules/workout-controller.md
git commit -m "fix(workout): make controller lifecycle single-session"
```

Expected: Controller/契约/识别回归全部 PASS，回放保持 5/5/3。

### Task 3: 为 MembershipApiClient 增加统一 timeout

**Files:**

- Modify: `test/membership_api_client_test.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `docs/modules/membership.md`

**Step 1: 写失败测试**

- 注入一个永不完成的 `http.Client`，用很短的测试 timeout 调用一个 GET，断言收到 `MembershipApiException(errorCode: 'request_timeout')`。
- 对一个 POST/PUT 再写一例，证明所有 verbs 经过同一边界。
- 断言 timeout 不触发自动重试，写请求调用次数严格为 1。

**Step 2: 运行并确认 RED**

```powershell
flutter test test/membership_api_client_test.dart --plain-name "membership request timeout becomes a stable api error"
```

**Step 3: 实现最小公共包装**

- 构造函数增加可注入 `Duration requestTimeout`，生产默认 15 秒。
- 所有 `_httpClient.get/post/put/patch/delete` 的 Future 经过一个 `_awaitResponse` helper。
- 只把 `TimeoutException` 映射为稳定的 `MembershipApiException`；不得记录 token、URL query 私密值或响应正文。
- 本任务不自动重试。GET retry 若以后需要，应在真实弱网证据和幂等策略明确后另立任务。

**Step 4: 验证并提交**

```powershell
dart format lib/platform/membership_api_client.dart test/membership_api_client_test.dart
flutter test test/membership_api_client_test.dart test/account_controller_test.dart test/leaderboard_controller_test.dart
flutter analyze
git diff --check
git add lib/platform/membership_api_client.dart test/membership_api_client_test.dart docs/modules/membership.md
git commit -m "fix(api): bound membership request duration"
```

## Milestone B：数据完整性与已确认死代码

### Task 4: 让 WorkoutSessionStore 写入在进程中断后可恢复

**Files:**

- Modify: `test/workout_session_store_test.dart`
- Modify: `lib/product/workout_session_store.dart`
- Modify: `docs/modules/membership.md`

**Step 1: 写 crash-state 失败测试**

用临时目录构造三种磁盘状态：

1. 主文件缺失、`.bak` 完整：`load()` 从 backup 恢复记录。
2. 主文件完整、残留 `.next`：主文件优先，残留临时文件不能覆盖权威记录。
3. 主文件损坏、`.bak` 完整：返回 backup，不能把训练历史静默变成空列表。

再增加一次注入写失败或文件系统冲突测试，证明失败发生在交换前时原主文件仍可读。

**Step 2: 运行并确认 RED**

```powershell
flutter test test/workout_session_store_test.dart --plain-name "load recovers the last complete workout file"
```

**Step 3: 实现 crash-consistent 交换**

- 把新 JSON 完整写入同目录 `workout_sessions.json.next` 并 `flush: true`。
- `load()` 按“有效主文件 → 有效 backup → 原始解析异常”的顺序读取；不得因 JSON 损坏返回空列表，也不得让残留 `.next` 覆盖最后完整快照。
- 交换前先判断主文件是否可解析：主文件有效时才用它替换旧 `.bak`；主文件损坏而 `.bak` 有效时保留 backup，绝不能用损坏主文件覆盖最后完整快照。
- 再把 `.next` rename 为主文件；只有新主文件就位后才删除 `.bak`。任一步失败时，主文件或 backup 至少保留一份最后完整数据，并重新抛出原异常。
- 保留现有全局串行队列和带缩进 JSON。本任务解决完整性，不同时做存储迁移或性能优化。
- 不添加 mutation timeout；它不能取消底层文件 Future。

**Step 4: 验证并提交**

```powershell
dart format lib/product/workout_session_store.dart test/workout_session_store_test.dart
flutter test test/workout_session_store_test.dart test/records_page_test.dart test/workout_sync_controller_test.dart
flutter test
git diff --check
git add lib/product/workout_session_store.dart test/workout_session_store_test.dart docs/modules/membership.md
git commit -m "fix(storage): recover interrupted workout writes"
```

### Task 5: 对齐 step0 与生产计数链并删除弃用腕均值信号

**Files:**

- Modify: `test/domain_self_check_test.dart`
- Modify: `test/pushup_pipeline_test.dart`
- Modify: `lib/pushup_domain.dart`
- Modify: `docs/modules/recognition.md`
- Modify: `docs/architecture-plan.md`

**Step 1: 先移除 step0 测试中的额外 SignalFilter**

只改测试，让 step0 和 v3/v4 一样把 `_signals(...)` 直接传给 `PushupCounter.update()`。

```powershell
flutter test test/domain_self_check_test.dart --plain-name "PushupCounter replays Step0 CSV as 5 reps"
```

Decision gate：

- 若仍 PASS=5，继续删除死代码。
- 若 FAIL，立即停止本任务，记录 raw/filtered 差异并分析夹具；不得为了让测试变绿把 SignalFilter 加回生产。

**Step 2: 删除生产不可达代码**

- 删除 `SignalFilter` 类及其专用单测。
- 从 `FrameSignals`、`copyWith` 和 `SignalExtractor` 删除 `pressDepthY`。
- 删除左右腕 weighted mean；保留 `torsoY`、双腕独立可见性/支撑反证与 ready 深度标定。
- 用 pipeline/domain 测试明确守住“动作信号不含左右腕均值”和“只由 Counter 内部 5 帧中值滤波”。

**Step 3: 更新当前合同，不重写历史材料**

- `recognition.md` 把 `pressDepthY` 从当前信号表删除，并记录它已从代码移除。
- `architecture-plan.md` 顶部增加醒目说明：该 2026-07-09 历史方案中的 SignalFilter 装配已被当前 `pushup-pipeline.md` 取代；不要重写整份历史路线图。

**Step 4: 验证并提交**

```powershell
dart format lib/pushup_domain.dart test/domain_self_check_test.dart test/pushup_pipeline_test.dart
flutter test test/domain_self_check_test.dart test/pushup_pipeline_test.dart test/pushup_session_replay_test.dart
flutter analyze
flutter test
git diff --check
git add lib/pushup_domain.dart test/domain_self_check_test.dart test/pushup_pipeline_test.dart docs/modules/recognition.md docs/architecture-plan.md
git commit -m "refactor(domain): remove abandoned wrist-average signal"
```

Expected: 全量测试通过，回放仍为 5/5/3，domain/product 不再平均左右腕。

### Task 6: 完成低风险 Worker 纵深防御与死配置清理

**Files:**

- Modify: `workers/membership-api/src/admin.ts`
- Modify: `workers/membership-api/src/google.ts`
- Modify: `workers/membership-api/test/admin.test.mjs`
- Create: `workers/membership-api/test/google.test.mjs`
- Modify: `workers/membership-api/wrangler.toml`
- Modify: `workers/membership-api/test/wrangler-config.test.mjs`
- Modify: `docs/modules/membership-admin.md`
- Modify: `docs/release-configuration.md`

**Step 1: 写或更新合同测试**

- Access 与 Google `jwtVerify` 显式限制 `algorithms: ['RS256']`；Google verifier 像 Access verifier 一样提供可注入 key 的纯验证入口，使测试可用本地生成的 RS256/ES256 key 验证白名单而不访问 Google。
- 两个管理台 HTML 响应都包含 `X-Frame-Options: DENY`，同时保留 CSP `frame-ancestors 'none'`。
- `[secrets].required` 不再要求源码完全未读取的 `REVENUECAT_WEBHOOK_AUTH`；HMAC 使用的 `REVENUECAT_WEBHOOK_SECRET` 继续必需。

**Step 2: 运行 RED → 最小实现 → GREEN**

```powershell
cd workers/membership-api
npm test
npx wrangler deploy --dry-run --keep-vars
```

Expected: Worker 全量测试 PASS；dry-run 只验证构建和 binding 合同，不产生远程部署。

**Step 3: 更新公开文档并提交**

只删除过期 Secret 名称，不输出或读取任何值。历史 `docs/superpowers/plans/` 不改。

```powershell
git add workers/membership-api/src/admin.ts workers/membership-api/src/google.ts workers/membership-api/test/admin.test.mjs workers/membership-api/test/google.test.mjs workers/membership-api/wrangler.toml workers/membership-api/test/wrangler-config.test.mjs docs/modules/membership-admin.md docs/release-configuration.md
git commit -m "chore(worker): tighten jwt and admin response contracts"
```

## Milestone C：必须先有证据的决策轨道

### Task 7: 性能测量，不预先承诺重构

**Files:**

- Use: `lib/perf/performance_meter.dart`
- Use: `lib/platform/recognition_trace_log.dart`
- Use: `workers/membership-api/src/leaderboard.ts`
- Use: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Create only if needed: `docs/reports/2026-07-22-audit-performance-baseline.md`

**Step 1: App profile 基线**

在代表性 Android 真机使用 profile 模式完成 60 秒训练，记录：总处理 P50/P95、Flutter build/raster jank、丢帧率、YUV/旋转/预处理分段时间。真实姿态日志只留本机，报告只写聚合值。

Decision gate：只有预处理 P95 实际侵占 UI frame budget 或产生可复现 jank，才设计长驻 isolate；禁止每帧 `Isolate.run()` 直接上线。

**Step 2: 排行榜与存储规模基线**

- 用本地 SQLite/D1 fake 生成 200、1k、10k 用户，测 day/week、blocked users、本人 rank 和分页查询。
- 用临时目录生成 100、1k、5k 条 WorkoutSession，测 load/append/mark status。
- 记录机器、数据规模、P50/P95 和结果正确性，不把一次本机数字冒充生产 SLA。

Decision gate：

- 排行榜未越过 Worker CPU/响应预算：保留现状和 ponytail 注释。
- 越过预算：另写 SQL window/keyset 设计，必须保持冻结成绩、blocked user、零分成员、本人 rank 与积分版本合同。
- 本地记录未出现用户可感知延迟：不迁 SQLite；出现明确瓶颈后再比较 SQLite 与 JSONL compact，不在本计划直接选库。

### Task 8: 统一 product/platform 架构合同后再搬文件

**Files:**

- Modify first: `docs/development-guide.md`
- Modify first: `docs/architecture-plan.md`
- Modify first: `test/architecture_contract_test.dart`
- Possible later moves: `lib/product/workout_session_store.dart`, `lib/product/voice_prompt_player.dart`, `lib/platform/`

**Step 1: 先作架构决定**

推荐合同：product 只保存模型、规则与接口；`path_provider`、`dart:io`、`audioplayers` 的实现放 platform，control/main 注入实现。先把该决定写进当前权威文档并确认，不根据 2026-07-09 历史方案静默选边。

**Step 2: 单独制定迁移计划**

若确认严格分层，再为以下内容写独立计划/PR：

1. 拆出纯 `WorkoutSession` 模型与 store 接口。
2. 新建文件系统 store 实现，复用 Task 4 的 crash-safe 算法。
3. 把音频插件实现移到 platform，product 只保留语音命令接口。
4. 增加 product 禁止 `dart:io`、`path_provider`、`audioplayers` 的架构测试。

本整改计划不直接执行这次大范围搬迁，避免把行为修复和依赖重构混为一个回滚单元。

### Task 9: 明确接受、观察或外部治理的剩余项

不写产品代码，只在修订审核报告时记录：

- Webhook SELECT→reconcile→INSERT 的竞态当前最多造成一次额外 RevenueCat 调用；`verified_at` 防止旧结果覆盖。没有真实成本/限流证据前接受风险，不为低影响问题引入分布式 lease schema。
- `_waitForFramePipelineToIdle()` 不能靠超时后强制 dispose 修复；必须先让推理边界支持安全取消/终止。
- rate limit 先只读核对 Cloudflare 现有 WAF/Rate Limiting 配置；仓库缺少代码级限流不等于生产没有限流。
- `email_verified` 已解析但未强制；身份键是 Google `sub`。只有产品决定“必须拒绝未验证邮箱”时才改变登录合同。
- Worker 意外异常继续 rethrow 以保留平台错误可观测性；若将来统一 JSON 500，必须同时保留 sanitized `console.error` 和告警。
- `debugPrint` 在 release 可输出；无 Crashlytics/Sentry 是独立可观测性产品决策，不作为本轮 bug 修复。

## Milestone D：平台 P0 与最终验收（每项单独授权）

### Task 10: Google Play 声明核对

**Remote write — 必须单独获得用户授权。**

按 `docs/release-configuration.md §11` 和执行当日 Google Play 官方文档逐项核对 UGC、Data safety、内容分级，使声明与头像上传、举报、屏蔽、人工审核和账号删除能力一致。完成后更新受保护私密台账、App 公开状态和 info 快照；不得把账号、用户数据或控制台私密值写入 Git/聊天。

### Task 11: 轮换 legacy Cloudflare Token

**Credential change — 必须单独获得用户授权。**

只按私密台账的稳定标签定位旧 Token，撤销历史疑似暴露项，保留最小权限专用 Token；验证所需只读/部署能力后更新三层台账。不得输出 Token 值，不因轮换自动触发 Worker 部署。

### Task 12: 全量验证、真机边界与报告收口

**Step 1: 自动化总门禁**

```powershell
flutter analyze
flutter test
flutter test test/domain_self_check_test.dart
cd workers/membership-api
npm test
cd ../..
git diff --check
```

Expected: analyze 0 issue；所有 Flutter/Worker 测试全绿；step0/v3/v4 = 5/5/3。记录实际测试数量，不沿用计划中的历史数量。

**Step 2: 真机验收**

- 训练：启动、切相机、停止、系统返回、连续快速点击停止，不崩溃、不泄漏相机，计数和保存不丢。
- 弱网：会员/排行榜请求在 timeout 后收束为可重试错误，页面不无限 loading；恢复网络后手动重试成功。
- 记录：正常保存后冷启动仍可读；自动化已覆盖 crash-state，真机不通过故意杀进程制造数据损坏。
- 性能：只有 Task 7 已取得 profile 数据时才报告结论。

**Step 3: Worker 生产验收**

只有获得部署授权后执行：部署前只读比对生产 `/app-update`，确认 Secret binding 名称，`wrangler deploy --keep-vars`；部署后验证未登录 Access 边界及 App 公共接口。授权浏览器必须再次验证真实 `Origin:null` 下的会员同步/补齐 POST 携带 CSRF token 后成功，缺失/篡改 token 的测试只在本地自动化做，不能对生产真实数据发攻击式请求。

**Step 4: 修订审核结论**

把审核报告更新为实施时的真实 HEAD、真实测试数量和最终状态；删除误报，性能项只写测量结果，平台 P0 只按台账实际状态关闭。报告与实现代码分开提交，且只能显式 stage 该报告。

## 建议实施批次

1. **Worker 安全批**：Task 1；本地全绿后等待部署授权和真实浏览器验收。
2. **App 稳定性批**：Task 2 + Task 3；需要真机训练/弱网冒烟。
3. **数据与领域清理批**：Task 4 + Task 5；保持回放 5/5/3。
4. **Worker 低风险加固批**：Task 6；可与 Task 1 同一候选部署，但保持独立 commit。
5. **证据/架构批**：Task 7–9；只有 decision gate 命中才产生后续实现计划。
6. **平台治理批**：Task 10–11；每个远程动作单独授权。
7. **收口批**：Task 12；更新报告和台账，不提前宣称发布完成。
