# 全面审核报告（2026-07-22）

> 审核基线：main 7defb46
> 审核 worktree：E:/AII/ugk-post-audit-2026-07-22
> 审核分支：audit/2026-07-22-full-review
> 审核范围：main 完整状态（Flutter App + Cloudflare Worker）
> 性质：只读审计；本次只改报告，不改产品代码

## 事实边界

- **本次亲自验证**：所有门禁（flutter analyze / flutter test / npm test / domain_self_check / git log / git diff --check）均由审核 agent 在 worktree 中实际执行
- **代码事实**：每条 finding 标注了文件路径 + 行号 + 代码片段，可直接定位
- **工程判断**：涉及"是否值得修"、"触发概率"、"未来风险"的部分明确标注为工程判断
- **历史台账记录**：历史 finding 复核基于代码验证，非照抄声明

## 基线确认

| 门禁 | 期望 | 实际 | 结果 |
|------|------|------|------|
| `git log --oneline -1` | 7defb46 | 7defb46 | ✅ |
| `flutter --version` | 3.44.7 | 3.44.7 | ✅ |
| `flutter analyze` | 0 issue | No issues found | ✅ |
| `flutter test` | 664/664 | +664: All tests passed! | ✅ |
| `flutter test test/domain_self_check_test.dart` | 26/26 | +26: All tests passed! | ✅ |
| `npm test`（workers/membership-api） | 161/161 | pass 161, fail 0 | ✅ |
| `git diff --check` | exit 0 | 无输出 | ✅ |

回放基线 step0=5 / v3=5 / v4=3 由 domain_self_check_test 26 个测试守护，全部通过。

---

## 发现清单

### 🔴 P0（必须立即修）

**无 P0 发现。**

经 12 个维度全面审核，未发现会导致数据丢失、安全漏洞、计数错误、生产崩溃、隐私泄漏或凭证泄漏的 P0 级问题。

---

### 🟡 P1（应尽快修）

#### P1-1. `WorkoutController.stop()` 缺少 session 守卫

**证据**：`lib/control/workout_controller.dart:274-293`

```dart
Future<void> stop() async {
    if (!_running || _stopping) return;
    _stopping = true;
    _session++;
    // ...
    await SchedulerBinding.instance.endOfFrame;  // ← 无守卫
    await _voice.stop();                          // ← 无守卫
    await _subscription?.cancel();                // ← 无守卫
    await _waitForFramePipelineToIdle();          // ← 无守卫
    await _camera.dispose();                      // ← 无守卫
    await _pose.dispose();                        // ← 无守卫
    await _trace.close();                         // ← 无守卫
}
```

**影响**：`start()`、`switchCamera()`、`_onCameraImage()` 中每个 await 后都有 `if (session != _session) return;` 守卫，唯独 `stop()` 没有。如果 UI 层违反生命周期约束（在 `stop()` 的 await 期间调用 `start()`），`stop()` 会 dispose 掉 `start()` 刚加载的资源。当前 UI 通过 `_stopping` 标志和 widget 生命周期阻止了这种竞态，实际触发概率低，但控制器本身缺乏防御。

**建议**：在 `stop()` 开头记录 `final session = _session;`，每个 await 后检查 `if (session != _session) return;`，或至少在 `_camera.dispose()` / `_pose.dispose()` 前检查。

---

#### P1-2. step0 回放测试使用了生产管线不存在的 SignalFilter 平滑层

**证据**：`test/domain_self_check_test.dart:163-183`

```dart
test('PushupCounter replays Step0 CSV as 5 reps', () {
    final filter = SignalFilter(window: 5);  // ← 额外平滑层
    final counter = PushupCounter();
    state = counter.update(filter.smooth(_signals(...)));
});
```

对比 v3/v4 测试（line 185-223）直接使用 `counter.update(_signals(...))` 无 SignalFilter。生产管线 `PushupPipeline.process()` (line 84-117) 直接调用 `_counter.update(signals, ...)`，不经过 `SignalFilter`。

**影响**：step0=5 基线验证的信号路径与生产不完全一致。如果 step0 夹具中有特定噪声模式恰好被 moving-average 抑制但 median 不能，生产计数可能与测试不一致。当前三个基线都通过说明差异在实际数据上不显著，但测试的合同价值被削弱。

**建议**：要么在 step0 测试中移除 SignalFilter 使其与生产路径一致（验证是否仍然得到 5），要么在 `PushupPipeline` 中恢复 SignalFilter 使生产与测试一致。

---

#### P1-3. `pressDepthY` 仍然计算平均手腕 Y 坐标（死代码但违反纪律字面意义）

**证据**：`lib/pushup_domain.dart:172-176`

```dart
final wristY = weightedMean(
  [leftW.y, rightW.y],
  [leftW.confidence, rightW.confidence],
  minConf: minConf,
);
```

**影响**：`pressDepthY` 未参与任何计数/门控决策（计数器只用 `torsoY`），但它的存在违反了 AGENTS.md 纪律 #2 的字面意义（"不在 domain/product 里平均两个手腕坐标"）。未来开发者可能误用此字段。搜索确认 `pushup_pipeline.dart` 和 `workout_controller.dart` 中 `pressDepthY` 未出现在任何决策逻辑中。

**建议**：移除 `pressDepthY` 字段及其相关的 `wristY` 计算和 `SignalFilter._pressDepth` 列表，或标记 `@Deprecated` 并加注释说明禁止用于计数。

---

#### P1-4. `/admin/*` 同源校验放行 `Origin: "null"`，削弱 CSRF 防护

**证据**：`workers/membership-api/src/admin.ts:165-168`

```typescript
function isSameOriginPost(request: Request, url: URL): boolean {
  const origin = request.headers.get("origin");
  return origin === url.origin || origin === "null";
}
```

**影响**：Access JWT 校验在 origin 校验之前（顺序正确），但 `Origin: "null"`（opaque origin）可由 sandboxed iframe / `data:` URL 发起，且这类请求仍会携带浏览器中的 Cloudflare Access 会话 Cookie。该放行把 CSRF 防护从"代码层"降级为"依赖 Access Cookie SameSite 配置层"。若 Access 策略被改为宽松 SameSite、或浏览器存在 Lax 豁免窗口，管理员可被诱导执行状态变更操作。需多条件叠加，故定 P1。

**建议**：为 admin POST 增加不依赖 Origin 的 CSRF token（渲染页面时下发、POST 时回验）；或收紧为仅 `origin === url.origin`，并确认 Access 应用会话 Cookie 为 `SameSite=Lax/Strict` + 短会话时长。

---

#### P1-5. `LeaderboardController` 无 `dispose()` 且 `notifyListeners()` 无 disposed 守卫

**证据**：`lib/control/leaderboard_controller.dart` 全文（1092 行），无 `dispose` 方法；17 处直接调用 `notifyListeners()` 无任何守卫。

**影响**：当前该 controller 在 `main()` 中创建、生命周期等于 App 进程，永远不会被 dispose，因此当前不会触发问题。但若未来被放入 `Provider.scope` 或页面级 `ChangeNotifierProvider`，listener 泄漏和 dispose-after-use 异常将立即出现。与 `WorkoutController`（有 `_disposed` 守卫）和 `AccountController`（有 `dispose()` 取消 Timer）形成不一致。

**建议**：添加 `_disposed` 标志 + `dispose()` 覆写，或在代码注释中明确标注 "app-scoped, never disposed" 的设计意图。

---

#### P1-6. `WorkoutSessionStore._workoutSessionMutationQueue` 无超时保护

**证据**：`lib/product/workout_session_store.dart:9, 416-426`

```dart
Future<void> _workoutSessionMutationQueue = Future.value();

Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final result = Completer<T>();
    _workoutSessionMutationQueue = _workoutSessionMutationQueue.then((_) async {
      try {
        result.complete(await mutation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
}
```

**影响**：队列无超时、无深度上限。若某次文件 I/O 挂起（Android 存储异常、文件锁），后续所有 mutation 永久阻塞。队列是 top-level 全局变量，所有实例共享。正常场景下文件操作毫秒级完成，实际触发概率极低，但一旦触发，workout 保存和同步将全部卡死，用户无感知。

**建议**：为每个 mutation 添加 `.timeout(Duration(seconds: 10))` 包装，超时后 completeError 并释放队列。

---

#### P1-7. product/ 层引入 platform 级依赖，违反"只依赖 domain"

**证据**：
- `lib/product/workout_session_store.dart:3` — `import 'dart:io';`
- `lib/product/workout_session_store.dart:6` — `import 'package:path_provider/path_provider.dart';`
- `lib/product/voice_prompt_player.dart:1` — `import 'package:audioplayers/audioplayers.dart';`

**影响**：product 层直接耦合文件系统 I/O 和音频插件，无法在纯 Dart 环境复用；违反 AGENTS.md 架构分层"product/ 只依赖 domain"的约束。AGENTS.md 已将"存储/语音"列为 product 职责，存在设计张力。

**建议**：在 product/ 定义抽象接口（`SessionStorage`、`VoicePlayer`），由 platform/ 或 control/ 提供实现并注入。短期可接受现状，但应在 `docs/architecture-plan.md` 中记录为已知债务。

---

#### P1-8. `MembershipApiClient` 无超时、无重试

**证据**：`lib/platform/membership_api_client.dart:118-123`

```dart
MembershipApiClient({required String baseUrl, http.Client? httpClient})
  : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
    _httpClient = httpClient ?? http.Client();
```

所有 `_httpClient.get/post/put/delete/patch` 调用均无 `.timeout()` 包装，无重试逻辑。

**影响**：在弱网/断网环境下，HTTP 请求可能无限挂起（依赖 OS 层 TCP 超时，通常 60-120s）。用户看到无限 loading。401 过期 token 无自动刷新/重登录机制。缓解因素：`AppUpdateChecker` 有 4s timeout；`WorkoutSyncController` 采用"下次触发时重试"策略；UI 层有 pull-to-refresh。

**建议**：给 `MembershipApiClient` 添加全局 10-15s timeout；对幂等 GET 请求添加 1 次自动重试；对 401 响应触发 session 失效通知。

---

#### P1-9. YUV→RGB 转换和预处理在主 Isolate 执行

**证据**：`lib/control/workout_controller.dart:310-326`

```dart
final rawRgb = yuv420ToRgb(          // ← 主 isolate，逐像素
  width: image.width, height: image.height, ...);
final rgb = orientRgbFrame(rawRgb, ...);  // ← 主 isolate，旋转
final input = _pose.pipeline.preprocess(rgb, target: _pose.target); // ← 主 isolate
final keypoints = await _pose.infer(input);  // ← 子 isolate ✓
```

**影响**：对于 640×480 相机帧，`yuv420ToRgb` ~921K 次运算 + `orientRgbFrame` 遍历 + `preprocess` 双线性插值，均在主 isolate 执行，会阻塞 UI 渲染。推理本身已在子 isolate（`IsolateInterpreter`），但预处理没有。缓解因素：`_busy` 标志实现背压控制（处理中丢帧），不会堆积。

**建议**：将 `yuv420ToRgb` + `orientRgbFrame` + `preprocess` 移入 `Isolate.run()` 或专用 compute isolate。`Uint8List` 可通过 `TransferableTypedData` 零拷贝传递。

---

#### P1-10. 排行榜全量加载 + 内存排序

**证据**：`workers/membership-api/src/leaderboard.ts:310-338`

```typescript
const rows = period === "day"
  ? await dayRows(env, metric, rankingDateForShanghai(now))
  : await weekRows(env, metric, weekRangeForShanghai(now));
const rankedRows = rankRows(rows.map(...));
const remaining = cursor ? visibleRows.filter(...) : visibleRows;
const page = remaining.slice(0, leaderboardPageSize);
```

**影响**：每次排行榜请求都加载该周期全部用户的聚合行到内存，排序后再分页。当活跃用户达到数百/数千时，D1 查询返回全量数据 + Worker CPU 排序会成为瓶颈。代码注释已标记为有意技术债（ponytail 注释）；游标分页接口已就绪。

**建议**：当 DAU > 200 时，将排序下推到 D1 SQL（`ORDER BY total DESC, user_id ASC LIMIT ? OFFSET ?` 或 keyset），blocked users 用 `NOT IN` 子查询。

---

#### P1-11. `WorkoutSessionStore` 每次变更全文件读写

**证据**：`lib/product/workout_session_store.dart:248-253, 428-436`

```dart
Future<void> append(WorkoutSession session) async {
    await _serializeMutation(() async {
      final sessions = await load();   // ← 读取整个 JSON 文件
      sessions.add(session);
      await _write(sessions);          // ← 重写整个文件
    });
}
```

**影响**：每次 `append`/`markSynced`/`markFailed` 都执行全文件读取→JSON 解码→修改→JSON 编码（带缩进）→全文件写入 + fsync。随着历史记录增长（一年 ~500-1000 条），I/O 开销线性增长。缓解因素：写入通过 `_serializeMutation` 串行化；当前数据量小；`flush: true` 保证掉电不丢数据。

**建议**：短期去掉 `JsonEncoder.withIndent`（节省 ~30% 编码时间）；中期改用 SQLite（`sqflite`/`drift`）或 append-only JSONL + 定期 compact。

---

### 🟢 P2（有空再改）

#### P2-1. `SignalFilter` 整体为生产死代码

**证据**：`lib/pushup_domain.dart:317-370`。`SignalFilter` 类仅在 `test/domain_self_check_test.dart` 的 step0 测试中使用，生产管线不引用。若 P1-2 修复后 step0 测试移除 SignalFilter，则整个类可移除（53 行）。

#### P2-2. `handsStable` 参数传递链冗余

**证据**：`lib/product/pushup_pipeline.dart:84-100`。`handsStable` 存入 signals 但计数器不消费，仅用于 trace log 诊断输出。建议标注为 diagnostic-only。

#### P2-3. `jwtVerify` 未显式绑定 `algorithms`（无 `none` 风险，缺纵深防御）

**证据**：`workers/membership-api/src/google.ts:13-16` 与 `src/admin.ts:128-132`。审计 jose@6.2.3 源码确认 `none` 算法在 JWKS 解析层即被拒绝，不存在漏洞。但未显式 `algorithms: ['RS256']` 属于缺少纵深防御。

#### P2-4. 缺少 `X-Frame-Options` 响应头

**证据**：`workers/membership-api/src/admin.ts:405-407`。已设 CSP `frame-ancestors 'none'`，现代浏览器等效防点击劫持。仅对不支持 CSP 的老旧浏览器有意义，管理台为内部工具，风险低。

#### P2-5. Worker 未捕获异常直接 re-throw，错误响应不统一

**证据**：`workers/membership-api/src/index.ts:35-43`。非 `MembershipReconciliationError` 的异常 re-throw 后由 Cloudflare 生成默认 500，响应体格式与 JSON API 不一致。建议兜底返回 `json({error:"internal_error"},500)`。

#### P2-6. `wrangler.toml` 声明了未使用的 secret `REVENUECAT_WEBHOOK_AUTH`

**证据**：`wrangler.toml:9` 与 `test/wrangler-config.test.mjs:18`。实际用的是 `REVENUECAT_WEBHOOK_SECRET`（`types.ts:6`）。死配置被契约测试固化为必选项，易误导接手者。

#### P2-7. 无速率限制 / 滥用防护

**证据**：`/auth/google`、`/webhooks/revenuecat`、举报/拉黑均无频控。建议在 Cloudflare 层配置速率限制；对单用户举报/拉黑频率做上限。

#### P2-8. Webhook 幂等存在并发竞态窗口

**证据**：`workers/membership-api/src/index.ts:263-298`。先 SELECT 再 INSERT OR IGNORE，两个相同 event_id 的并发请求可能都通过检查。reconcile 本身幂等，无数据损坏，仅多余一次 RevenueCat 调用。

#### P2-9. `auth/google` 不校验 `email_verified`

**证据**：`workers/membership-api/src/google.ts:25`。身份绑定键是 Google `sub`（非 email），风险低。但 email 会被存入 `users.email` 并展示于管理台。

#### P2-10. `_waitForFramePipelineToIdle()` 为无界 spin-wait

**证据**：`lib/control/workout_controller.dart:609-613`。若 TFLite native 层挂死导致 `_busy` 永远为 true，此循环永不退出。仅在 stop/dispose 时调用，非热路径。

#### P2-11. `AppSettingsController` 无 `dispose()` 覆写

**证据**：`lib/ui/app_settings.dart:21-115`。当前 app-scoped 无问题，但与 WorkoutController/AccountController 不一致。

#### P2-12. 契约测试未覆盖分层依赖方向

**证据**：`test/architecture_contract_test.dart` 仅断言 domain 层纯度，无测试断言 product/ 不含 platform 插件 import、product/ 不 import control/ui、control/ 不 import ui/。

#### P2-13. `lib/report/` 和 `lib/perf/` 未在架构文档中登记

**证据**：AGENTS.md 架构分层图未提及 report/ 和 perf/。这两个目录依赖方向正确（仅引用 domain），但新接手者可能不清楚其定位。

#### P2-14. Migration 0004 含 DROP INDEX（非 additive）

**证据**：`workers/membership-api/migrations/0004_custom_avatar_ugc.sql:88`。删除 `leaderboard_profiles_nickname_key_idx`（昵称唯一性约束已迁移至 users 表级）。属于有意的架构演进，不会丢失用户数据，但无 down-migration 回滚路径。

#### P2-15. `startup_preferences.dart` 读取失败静默返回 true

**证据**：`lib/platform/startup_preferences.dart:33`。FlutterSecureStorage 损坏时静默跳过引导页，无任何日志记录。

#### P2-16. WorkoutController 用 `debugPrint` 而非 `ugkLog()`

**证据**：`lib/control/workout_controller.dart` 多处。功能等价（`ugkLog` 就是 `debugPrint('UGK $message')`），但不利于未来统一日志级别控制。

#### P2-17. 回放基线不覆盖 wrist/ready/narrow 门控

**证据**：`test/fixtures/` 的 3 个 CSV 仅含 torsoY/shoulderConf/elbowAngle 标量，不接 WristAnchor/ReadyPoseGate/NarrowPushupFormGate。已知设计取舍（基线只守计数核心），不构成 P0 风险。

#### P2-18. 契约测试是字符串匹配非行为测试

**证据**：`test/architecture_contract_test.dart` 34 个测试全部基于 `File.readAsStringSync()` + `contains()`。作为"防意外删除"的守护网有效，但不能替代行为测试。当前行为测试已由 controller 级 fake 测试补充。

#### P2-19. 相机/推理真机边界无自动化测试

**证据**：NNAPI/isolate 需真机验证，CI 无法覆盖。已知限制。

---

## 历史发现复核

### 2026-07-13 审计（M1-M3, L1-L3）

| 编号 | 描述 | 状态 | 证据 |
|------|------|------|------|
| M1 | switchCamera() session 检查晚于多个 await | **已关闭** | `workout_controller.dart:224-253` 每个 await 后均有守卫；`workout_controller_test.dart:332-396` 有 2 个专项竞态测试 |
| M2 | Workout 状态以中文字符串充当内部状态码 | **已关闭** | `workout_controller.dart:31-50` 已改为 `enum WorkoutStatus`；契约测试 :480 验证 |
| M3 | 分层规则与开发指南对资源常量位置互相矛盾 | **已关闭** | `lib/config/resource_constants.dart` 已定义；platform→UI 反向边已消除 |
| L1 | UI 保留基本不可达的匿名头像回退算法 | **仍然开放** | `leaderboard_models.dart:132,147,162,174-175,184,211` 仍存在 |
| L2 | 部分降级路径缺诊断可观测性 | **部分关闭** | `ugkLog` 已加入商业路径，但 `app_settings.dart` catch 仍静默，无 crash SDK |
| L3 | 数个 UI/编排方法较长 | **仍然开放** | 设计决策保留（`app-ui-v1.md` "单页 helper 就近保留"是刻意简化） |

### 2026-07-16 全面 review（P1/P2 关键项）

| 编号 | 描述 | 状态 | 证据 |
|------|------|------|------|
| 5-1 | WorkoutController 零行为测试 | **已关闭** | `test/workout_controller_test.dart` 12 个 testWidgets，含 2 个 M1 竞态测试 |
| 5-2 | WorkoutController 零 DI | **已关闭** | 构造函数接受 8 个可选协作者，有默认值 |
| 6-1 | WorkoutSession 无 schema version | **已关闭** | `workout_session_store.dart:26` `schemaVersion = 1`，读取验证 |
| 6-2 | claimLegacy 绑死手动 UI 入口 | **仍然开放** | `profile_page.dart:599` 仍是唯一触发点 |
| 6-3 | signOut 不清本地数据 + 展示不按 owner 过滤 | **部分关闭** | RecordsPage 已按 owner 过滤；但 signOut 仍不清本地训练数据 |
| 6-4 | 单文件 JSON 非原子写 | **仍然开放** | `workout_session_store.dart:432` 仍直接覆写，无 temp+rename |
| 6-6 | Session ID 基于微秒时钟 | **仍然开放** | `workout_page.dart:483` 仍 `microsecondsSinceEpoch.toString()` |
| 7-1 | release 包零可观测 | **部分关闭** | 有 `runZonedGuarded` + `FlutterError.onError`，但无 Crashlytics/Sentry |
| 7-2 | 错误呈现两套并存 | **部分关闭** | WorkoutController 已改 enum；但 `revenuecat_service.dart:111` 仍硬编码中文 |
| 7-3 | 无错误处理总则文档 | **仍然开放** | `docs/policies/error-handling.md` 不存在 |
| 8-1 | `intl: any` 无版本约束 | **仍然开放** | `pubspec.yaml:39` 仍 `intl: any` |
| 9-3 | membership_status.dart '训练者' fallback | **仍然开放** | `membership_status.dart:34` 仍 `?? '训练者'` |
| 11-2 | 无用户自助删除账号 API | **仍然开放** | Worker 无 DELETE /me 路由 |
| 11-3 | webhook_events 永久留存无 TTL | **仍然开放** | Worker 无 cleanup/TTL 逻辑 |
| 12-2 | 商业链路全程无日志 | **部分关闭** | `ugkLog` 已加入 purchase/auth/sync/api 路径，但底层仍是 debugPrint |
| 13-1 | 无性能回归门禁 | **仍然开放** | 无 CI，无自动化性能测试 |
| 4-1 | Dart↔Worker 无共享 schema | **仍然开放** | 无 openapi/zod/json-schema 文件 |
| 4-2 | ACCESS secrets 未进主部署清单 | **已关闭** | `release-configuration.md:696-697` 已列出 |
| 2-1 | README 测试数失真 | **已关闭** | 改为"以实际输出为准" |
| 2-2 | AGENTS "约 30 提交"失真 | **已关闭** | 改为"精确提交数以 git rev-list 为准" |
| 3-1 | docs/plans/ 无索引 | **已关闭** | `docs/plans/README.md` 已存在 |
| 3-2 | superpowers/plans checkbox 未勾 | **仍然开放** | 前 3 份文件仍 0 个 `[x]` |

**汇总**：已关闭 12 项，部分关闭 5 项，仍然开放 12 项。2026-07-13 的 3 个 M 级 finding 全部已关闭。2026-07-16 最严重的测试盲区（WorkoutController 零测试/零 DI）已修复。剩余开放项集中在数据治理、可观测性、依赖治理和文档治理，均为 P2 级长期债务。

---

## 工程判断（非 bug，但值得讨论）

### 1. 单文件过大

`profile_page.dart`（2227 行）和 `leaderboard_page.dart`（1845 行）远超 Flutter 社区通常建议的 300-500 行/文件。虽然 `app-ui-v1.md` 明确"单页 helper 就近保留"是刻意简化，但随着功能迭代，这两个文件的认知负担会持续增长。建议在下一个 UI 迭代周期中，将独立的子功能（如会员卡片、头像上传、排行榜筛选栏）抽取为独立 widget 文件。

### 2. 测试与生产路径一致性

step0 测试使用 SignalFilter 而生产不使用（P1-2），这类"测试路径 ≠ 生产路径"的偏差是回归测试最隐蔽的失效模式。建议建立原则：回放测试的信号处理链必须与 `PushupPipeline.process()` 完全一致，任何偏差都需要在测试注释中明确说明理由。

### 3. 防御性编程的一致性

项目在 `start()`/`switchCamera()` 中有严格的 session 守卫，但 `stop()` 没有（P1-1）；`WorkoutController` 有 `_disposed` 守卫，但 `LeaderboardController` 没有（P1-5）。这种不一致暗示防御性编程是"逐个 bug 修复"而非"系统性设计"。建议在 `docs/development-guide.md` 中增加"异步生命周期守卫"模式的标准写法，作为所有 Controller 的必选模板。

### 4. 可观测性的 release 缺口

`ugkLog` 基于 `debugPrint`，在 release 包中被 Flutter 框架抑制。这意味着生产环境中的计数异常、会员状态异常、同步失败等关键事件完全不可见。当前无 Crashlytics/Sentry。对于已上架 Play Internal 的 App，这是一个显著的运维盲区。建议至少接入 Firebase Crashlytics 或 Sentry，将 `ugkLog` 的关键事件（session start/stop/count/error）上报。

### 5. 数据持久化的原子性

`WorkoutSessionStore` 使用 `file.writeAsString()` 直接覆写（P1-11 + 历史 6-4），无 temp+rename 原子写保护。虽然 `flush: true` 保证了刷盘，但在写入过程中如果 App 被系统杀死（Android 低内存 killer），文件可能处于截断状态。建议改为 write-to-temp + rename 模式，或迁移到 SQLite。

---

## 总结

### 整体代码质量评估

项目整体代码质量**良好**。核心算法（torsoY 信号 → median filter → 自适应阈值 → 滞回状态机 → 肘部可选否决）设计合理，边界条件处理完整，历史手腕平均 bug 未在计数路径复发。Worker 安全基线扎实：鉴权链完整、SQL 全参数化、HTML 全转义 + 强 CSP、webhook 签名规范、JWT 无 `none` 风险、密钥全部经 env 注入。并发设计质量较高：generation 计数器 + account identity 双重校验在三个 controller 中一致使用。测试覆盖充分：664 个 Flutter 测试 + 161 个 Worker 测试，关键控制器均有竞态测试。

**无 P0 发现**是一个强有力的信号——项目在计数正确性、安全性、数据完整性三个最关键的维度上没有已知缺陷。

### 推荐优先级

1. **短期（1-2 周）**：P1-1（stop 守卫）、P1-4（CSRF token）、P1-8（API 超时）——这三个影响生产稳定性和安全性
2. **中期（1 个月）**：P1-2（step0 测试路径）、P1-3（pressDepthY 清理）、P1-9（预处理 isolate）、P1-11（存储 I/O）
3. **长期（按需）**：P1-5/P1-6/P1-7/P1-10 为架构债务，可在对应模块迭代时顺带修复

### 建议下一轮迭代重点

1. **可观测性**：接入 Crashlytics/Sentry，将 `ugkLog` 关键事件上报到 release 包
2. **存储层升级**：`WorkoutSessionStore` 迁移到 SQLite 或 append-only JSONL
3. **预处理管线优化**：YUV→RGB + preprocess 移入 isolate，释放主线程
4. **CSRF 加固**：admin POST 改用 CSRF token 替代 Origin 校验
5. **文档治理**：关闭 12 个仍然开放的历史 P2 项（intl:any、error-handling 总则、webhook TTL 等）
