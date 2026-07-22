# 审核报告：2026-07-22 审计整改（main reviewer 复核）

> 日期：2026-07-22
> 审核：main reviewer（只读复核 + 用户授权后合并/push）
> 分支：`codex/audit-remediation-main-review`
> 审核范围：`4477ca3..4edff99`（18 个 commit，17 个文件，+3740/-308）
> 实施计划：`docs/plans/2026-07-22-audit-remediation-implementation.md`

## 1. 结论

**通过。** 18 个 commit 的代码质量、测试覆盖、文档一致性和门禁结果均满足合并标准。无 P0/P1 阻塞项。建议用户授权后 push 到 `origin/main`。

本轮只实现了计划的 **Milestone A（Task 1–3）**：Worker CSRF、WorkoutController 单会话生命周期、MembershipApiClient 超时。计划的 Task 4–12（数据完整性、死代码清理、纵深防御、性能测量、平台 P0）按设计未在本批落地，属于后续批次，不影响本次合并。

## 2. 独立门禁结果（本会话亲自验证）

| 门禁 | 结果 | 说明 |
|---|---|---|
| `flutter analyze` | ✅ No issues found | 0 issue |
| `flutter test` | ✅ 715/715 全绿 | 上一会话基线 671，本次 +44 |
| `flutter test test/domain_self_check_test.dart` | ✅ 26/26 | 回放基线 step0=5 / v3=5 / v4=3 保持 |
| `cd workers/membership-api && npm test` | ✅ 168/168 | 交接文档记 161，实际 +7 个 CSRF 新测试 |
| `cd workers/membership-api && npm run check` | ✅ tsc --noEmit 干净 | 无类型错误 |
| `git diff --check origin/main..HEAD` | ✅ 无空白错误 | |

## 3. 18 个 commit 分类

| 类别 | commit | 评级 |
|---|---|---|
| 计划文档 | `96affc6` docs(plan): add audit remediation implementation | — |
| **Worker CSRF（P1 安全）** | `4151aa5` fix(worker): bind admin posts to csrf token | ✅ 通过 |
| Worker 文档 | `7d463b6` docs(worker): clarify null origin compatibility | ✅ 通过 |
| 审计状态 | `175695d` docs(audit): align remediation status notes | ✅ 通过 |
| **Controller 单会话（P1 稳定）** | `7ce250a` fix(workout): make controller lifecycle single-session | ✅ 通过 |
| **API 超时（P1）** | `5748a08` fix(api): bound membership request duration | ✅ 通过 |
| Controller 生命周期 race 修复链（5 commit） | `391867c` close lifecycle / `e02baa2` close startup / `a76465b` share camera release / `fd9ce8c` complete cleanup after init failure / `1c338a0` contain voice disposal errors | ✅ 通过 |
| Controller trace 关闭所有权（3 commit） | `b274b1d` test cover / `d6193a7` finalize late init cleanup / `bf86840` preserve primary errors / `39cdd03` close trace on primary-error / `c9c14f5` await trace init | ✅ 通过 |
| 合并 | `8adf916` merge: integrate 2026-07-22 audit remediation | ✅ 标准 merge，无冲突黑箱 |
| 测试格式 | `4edff99` style(test): format membership API coverage | ✅ 通过 |

## 4. 重点项审核

### 4.1 P0 安全 — Worker CSRF token（`4151aa5` + `admin_csrf.ts`）

**实现正确。** `admin_csrf.ts`（38 行）：

- HMAC-SHA256，key = `env.SESSION_SECRET`，message = `admin-csrf:v1:${actor}`
- token 绑定已通过 Access JWT 验证的 actor（`actor` 来自 `verifyAccessRequest`）
- 不新增 Cookie、D1 表或 Secret（复用已有 `SESSION_SECRET`）
- `verifyAdminCsrfToken` 用正则 `/^[0-9a-f]{64}$/` 前置拒绝非 64 位十六进制，再做**常量时间比较**（`difference |= a ^ b`），防时序侧信道

**admin.ts POST 处理三层防御顺序正确**（members/action 与 avatar-reports/action 一致）：
1. Access JWT 验 actor（缺失/失败 → 403）
2. `isSameOriginPost`：同源或字面量 `Origin: "null"`（foreign/missing → 403，保留 PR #7 修的 opaque origin 兼容作第二层）
3. CSRF token：从 FormData 取 `csrfToken`，actor 绑定校验（缺失/篡改/另一 actor → 403）
4. FormData **只解析一次**，校验后传给 action handler（`applyMembershipAction(form, request.url, ...)`）

**渲染侧**：GET `/admin/members`、`/admin/avatar-reports`、`loadMemberDetail`、`renderReport` 全部注入 `csrfToken`，每个 POST form 都有隐藏字段。文档 `membership-admin.md` 同步更新了三层边界职责说明。

**测试覆盖（admin.test.mjs +425 行）**：form 渲染含 token、null-origin + 正确 token 放行、篡改/缺失/foreign origin 拒绝、CSRF 失败不写 audit。覆盖完整。

### 4.2 P0 稳定 — WorkoutController 单会话生命周期（`7ce250a` + race fix 链）

**实现正确，是本次审核的核心，质量很高。**

- **单会话合同**：`_started` 在 `start()` 第一个 await 前置位，重复 `start()` 直接 return（`workout_controller.dart:148-152`）。`switchCamera` 受 `_starting` 守卫，启动中禁切（避免旧启动路径释放新相机正在用的模型）。
- **session 守卫（AGENTS.md 纪律 3）保持完整**：`start`/`switchCamera`/`stop`/`_onCameraImage` 每个 `await` 后都校验 `session != _session`，过期路径立即返回不更新状态。架构契约测试 `workout async cleanup keeps session guards after every await` 逐个 await 断言守卫存在。
- **资源清理共享所有权**（关键设计）：`_cameraRelease` / `_resourceCleanup` / `_traceClose` 三个 memoized Future，让 `stop()` / `dispose()` / stale-cleanup / primary-error-cleanup 共享同一 handle，杜绝重复释放/二次 close。具体顺序：
  - camera release：取消订阅 → 等待帧 idle → 等待初始化落定 → dispose 相机
  - dispose camera+pose：release camera → 等 poseLoad → dispose pose
  - 各阶段互相隔离，前一阶段失败仍继续后一阶段
- **trace 关闭的微妙 race 已正确处理**（这是 race fix 链最精细的部分）：
  - `_startTrace` 记录 in-flight handle 到 `_traceStart`
  - `_closeTraceWhenIdle` → `_awaitTraceStartThenClose`：先 await 进行中的 trace 初始化，再调唯一一次 `_closeTrace()`
  - `RecognitionTraceLog.close()` 本身幂等兜底
  - 四类终止路径（正常 stop、dispose、primary-error、stale-start-after-trace-init）共用同一 memoized Future，trace 恰好关闭一次
- **错误优先级**：start/switch 主异常先完成状态映射（含 `startupError`/`cameraError`/权限细分）和通知，再执行清理，cleanup 失败不覆盖既有状态。`stop()` 以 voice-stop 为主操作：voice 主异常优先返回调用方，同时 camera/pose/trace 都必须尝试清理；无主异常时第一项清理异常返回调用方，不静默吞掉。
- **计数不丢失**：switch/lost-pose/reacquire 时 `_pipeline.resetTracking(count: _count)`。

**测试覆盖（workout_controller_test.dart +1808 行，54 个 widget test）**：单会话启动、启动中切换防回收、stop/dispose 订阅取消与资源所有权、end-of-frame 清理边界、相机切换、主异常与 cleanup 异常优先级、voice 主异常下全部资源继续清理、无主异常时清理错误传播、日志脱敏（断言不含 `*_TEST_SECRET`）、trace 恰好关闭一次（`closeCalls == 1` 在 20+ 处断言）、准备态、窄距门控、15 帧中断阈值、计数保留。覆盖扎实。

### 4.3 P1 — MembershipApiClient 统一 timeout（`5748a08`）

**实现正确。**

- 构造函数 `requestTimeout` 默认 15 秒，可注入（测试用 10ms）
- 所有 GET/POST/PUT/PATCH/DELETE 经 `_awaitResponse` helper，`.timeout(_requestTimeout)`
- `TimeoutException` → `MembershipApiException(errorCode: 'request_timeout')`，稳定错误码
- 不自动重试（测试断言 `calls == {'GET': 1, 'PUT': 1}` 等，调用次数严格为 1）
- 不记录 token、URL query 私密值或响应正文（符合现有 `ugkLog` 脱敏合同）
- 文档 `membership.md` 同步

### 4.4 其他改动

- `camera_service.dart`（`d6193a7`，+30 行）：`initialize()` 失败时 dispose 半初始化的 controller 再 rethrow，防资源泄漏。defensive cleanup，不影响正常路径。配套 `camera_service_test.dart`（+126 行）。
- `architecture_contract_test.dart`（+207 行）：新增 session 守卫逐 await 断言、启动中禁切相机、trace 关闭所有权、异常日志脱敏禁令等源码级契约。
- `pubspec.yaml`：加 `camera_platform_interface` 为 dev_dependency（测试 fake 需要），不影响生产依赖图。
- 文档 `workout-controller.md`：单会话合同、共享 cleanup Future、错误优先级、trace 四类关闭路径与代码精确对应。

## 5. 非阻塞观察项（P2，不影响合并）

| 项 | 说明 | 建议 |
|---|---|---|
| `docs/plans/README.md` 状态过期 | 新计划 `2026-07-22-audit-remediation-implementation.md` 标为"待执行/未提交"，但实际 Milestone A 已执行完毕 | 后续清理时更新状态为"部分落地" |
| 计划 Task 4–12 未落地 | 数据完整性（crash-safe 写入）、step0 SignalFilter 死代码清理、JWT/X-Frame-Options 加固、性能测量、平台 P0 均未在本批实现 | 按计划属后续批次，需独立授权轨道；不阻塞本次合并 |
| 真机/弱网未验 | Controller race fix 与 API timeout 的真机冒烟、弱网 timeout 收束未在本会话做 | 建议下一候选前按 `docs/testing-release-playbook.md` 真机冒烟；自动化已覆盖逻辑正确性 |

## 6. 合并建议

- 审计分支 `codex/audit-remediation-main-review` 已 push 到 origin（`origin/codex/audit-remediation-main-review` = `4edff99`）
- 本地 `main` 已 fast-forward 到 `4edff99`（领先 `origin/main` 18，落后 0）
- **推荐**：用户授权后直接 `git push origin main`（fast-forward，无需 merge commit，无需 force push）
- 此 push 只更新 `origin/main`，**不触发** Worker 部署 / D1 / Play / 任何远程写入。Worker CSRF 改动要生效需独立部署授权（Task 计划 Step 3）

## 7. 验证证据归档

本报告所有门禁数字为 2026-07-22 本会话亲自运行结果，非历史记录。回放基线 5/5/3 保持。Worker 168/168、Flutter 715/715、analyze 0 issue、tsc 干净、diff --check 干净。
