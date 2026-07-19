# Narrow Pushup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a separately selectable narrow-pushup workout whose ready pose and completed reps require conservative, confidence-aware narrow-arm geometry without changing standard pushups.

**Architecture:** Add a product-level exercise type and stateless narrow-form evaluator. Keep torso counting in the pure-Dart domain, extending its completion boundary with a generic allow/reject/wait decision; the controller maps narrow-form evidence to that decision while the UI and storage carry the explicit exercise type. Extend the existing generic cloud schema contract locally without deployment.

**Tech Stack:** Dart/Flutter, Flutter widget tests, pure-Dart unit tests, TypeScript Cloudflare Worker tests, Node test runner with SQLite-backed D1 harness.

---

### Task 1: 固定运动类型与窄距几何合同

**Files:**
- Create: `lib/product/exercise_type.dart`
- Create: `lib/product/narrow_pushup_form_gate.dart`
- Create: `test/narrow_pushup_form_gate_test.dart`

**Steps:**
1. 先写失败测试，覆盖窄距通过、明显宽距拒绝、低置信/退化几何未知，以及平移、镜像、等比缩放不改变结论。
2. 运行 `flutter test test/narrow_pushup_form_gate_test.dart`，确认因类型/门控不存在而失败。
3. 最小实现 `ExerciseType` 持久化键和三指标评估结果。
4. 重跑同一测试至通过，不增加时序或分类器抽象。

### Task 2: 在纯 Dart 计数闭环加入通用顶部决策

**Files:**
- Modify: `lib/pushup_domain.dart`
- Modify: `lib/product/pushup_pipeline.dart`
- Modify: `test/domain_self_check_test.dart`
- Modify: `test/pushup_pipeline_test.dart`

**Steps:**
1. 先写失败测试：回顶 `wait` 保持当前 dip，后续 `allow` 计数；`reject` 结束本次不计；默认调用仍计数。
2. 运行两个测试文件，确认新参数/枚举缺失导致预期失败。
3. 最小实现 `RepCompletionDecision`，仅在原有回顶完成分支读取；Pipeline 参数默认 `allow`。
4. 增加管线级窄距序列测试：底部手臂离屏、顶部未知后恢复、宽距拒绝、快速回顶。
5. 重跑 domain/pipeline/session replay 测试至通过。

### Task 3: 接入训练编排与诊断

**Files:**
- Modify: `lib/control/workout_controller.dart`
- Modify: `test/workout_controller_test.dart`
- Modify: `test/architecture_contract_test.dart`（仅在源码合同需要同步时）

**Steps:**
1. 先写 Controller 失败测试：窄距准备不合格不 ready、合格可 ready，常规类型不受门控影响。
2. 运行 `flutter test test/workout_controller_test.dart` 验证红灯。
3. 给 Controller 注入显式 `ExerciseType` 与门控；准备态失败显示独立状态，运动态映射顶部决策。
4. 在 session/event/frame/count 诊断记录中加入 `exerciseType` 与窄距三标量/结论，不记录新隐私数据。
5. 保留所有异步 session 守卫，重跑 Controller 与架构合同测试。

### Task 4: 打通首页、训练保存、l10n 与记录聚合

**Files:**
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `lib/product/workout_session_store.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Modify: `test/home_page_test.dart`
- Modify: `test/workout_page_test.dart`
- Modify: `test/workout_session_store_test.dart`
- Modify: `test/records_page_test.dart`（仅补聚合守护）

**Steps:**
1. 先写失败 Widget/存储测试：两张卡、窄距路由类型、窄距 session 持久化、按类型首页统计、记录页合并 reps、中英文提示。
2. 运行相关测试并确认红灯。
3. 为 Home/WorkoutPage 传递 `ExerciseType`，保存其 storage key；复用同一训练页和卡片组件。
4. Store 的当日汇总增加可选类型过滤，默认无过滤以保持旧调用聚合行为。
5. 新文案进入 ARB 后执行 `flutter gen-l10n`，不在 domain/product/control 引用 l10n。
6. 重跑四个相关测试文件至通过。

### Task 5: 本地扩展云同步合同

**Files:**
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `workers/membership-api/src/workouts.ts`
- Modify: `workers/membership-api/test/workout-sync.test.mjs`
- Modify: `workers/membership-api/test/workout-sync-sql.test.mjs`

**Steps:**
1. 先写失败测试：Flutter 云历史解析窄距；Worker 接受窄距、按独立类型存储/聚合；未知类型继续拒绝。
2. 分别运行相关 Flutter 测试与 Worker `npm test`，确认红灯来自当前 pushup-only 白名单。
3. 最小扩展双方白名单为 `pushup`、`narrow_pushup`；不改 schema、不改排行榜固定查询。
4. 重跑双方测试至通过，不执行部署、migration 或远程写入。

### Task 6: 文档与完整验收

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/modules/pushup-pipeline.md`
- Modify: `docs/modules/workout-controller.md`
- Modify: `docs/design/app-ui-v1.md`
- Modify: `docs/modules/membership.md`

**Steps:**
1. 更新算法含义、阈值依据、已知边界、运动类型数据流、首页/记录聚合和本地云合同。
2. 运行 `dart format`（仅本任务 Dart 文件）和 `flutter gen-l10n`。
3. 运行 `flutter analyze`、`flutter test`、`cd workers/membership-api; npm test`、`git diff --check`。
4. 从全量输出报告精确测试数量并核对 step0/v3/v4 = 5/5/3。
5. 检查 `git status`、`git diff --stat` 与隐私/临时文件边界；不 stage、不 commit、不 push、不 merge、不部署。

### Task 7: 独立六维审查循环

**Files:**
- Read-only review of the complete task diff and test evidence.

**Steps:**
1. 启动独立审查 agent，明确只读不改，提供基线、设计、实际 diff、测试输出和未完成真机项。
2. 要求按需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖、实际运行结果六方面输出按严重度排序的可执行清单。
3. 主 agent 对每项先补失败测试再修复，重跑相关与全量验证。
4. 让同一审查 agent 复验；循环至 P0/P1/P2 清零或明确阻塞。

### 发布硬门槛（2026-07-18 审查补充）

1. 固定上线顺序为 **兼容 Worker → 生产接口探针 → App**。本功能不需要 D1 migration，不得先发布或安装请求 `pushup_points_v1` 的新 App。
2. 新 Worker 必须继续接受旧 App 的 `exerciseType=pushup` 查询和 v1 游标；旧 App 在 Worker 先部署期间继续显示原次数榜。
3. 新 App 只接受带 `metric=pushup_points_v1`、`metricUnit=points` 的响应。旧 Worker 会忽略新参数并返回次数合同，客户端应将其作为可重试加载失败处理，不得把次数降级显示成积分。
4. Worker 部署并通过探针后，才能安装带本机构建配置的新 App；用受控测试数据验证标准 `N` 次加窄距 `M` 次显示为 `N + 2M` 分，并确认未同步的窄距记录会在兼容 Worker 上线后补传。
5. 商店正式发布前补充窄距门控真机矩阵：近景/远景、快速动作、底部手臂遮挡，以及至少 2 个机型或用户；当前单用户单机位结果不能代替该门槛。
6. 执行任何 Worker 部署或 App 发布前，必须在本机发布信息仓库登记源分支/提交、验证结果、部署顺序、探针结果和回滚依据；若权威台账不可用则停止远程操作。

2026-07-18 发布进度：兼容 Worker 已使用 `--keep-vars` 部署，未执行 D1 migration，也未修改变量、Secret 或 binding；积分指标、旧次数查询和训练同步的未登录生产探针均返回预期 `401`。App 尚未发布，下一门槛仍是带有效测试会话验收 `N + 2M` 积分合同及窄距记录补传。
