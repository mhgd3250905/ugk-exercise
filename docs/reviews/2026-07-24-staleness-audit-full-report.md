# 2026-07-24 项目陈旧度全量审核报告

> 审核范围：`docs + lib + test`
>
> 审核基线：`investigate/staleness-audit-2026-07-24@b5b1768`，与审核时 `origin/main@b5b1768` 一致
>
> 审核方式：主审核执行只读引用图、全仓 `rg`、文档链接/索引扫描、Flutter analyzer 与测试；随后由独立审查任务 `019f91ee-0e28-7d13-b821-45b0c3334997` 对全部发现做对抗式静态复核。除本报告外未修改代码、文档或测试

## 1. 结论先行

经独立复核后，本次确认 **11 项需要治理的陈旧/冗余点**：

- 文档 7 项：1 项发布台账内部矛盾、1 项计划索引漏项、1 项当前入口错误标注历史架构文档、2 份已完成 TODO、1 条不可执行的测试模式说明、1 份已结束调查缺少被替代标记、1 组缺少生命周期索引的旧 `superpowers` 计划。
- `lib` 4 项：旧 `SignalFilter/pressDepthY/elbowLateral` 路径仍被测试保活；测试模式整套开发工具不从生产入口可达；10 个 ARB key 无生产 getter 调用；3 个 test fake 放在生产 `lib`。
- `test` 的陈旧点与上述代码残留绑定：一条单测只验证已退出生产管线的 `SignalFilter`；一组测试继续守护不可达测试模式。除此之外，静态扫描与抽查未发现引用不存在实现、重复测试标题或未使用 fixture。

最值得先处理的不是“批量删文档”，而是三个决策：

1. 决定测试模式是恢复为明确的 dev-only 入口，还是退休整套页面/FFmpeg 回放链。
2. 删除已经退出生产管线的 `SignalFilter + pressDepthY + elbowLateral`，并只移除对应的陈旧单测。
3. 给文档建立“当前事实 / 历史快照 / 已完成计划”三种明确生命周期，先修发布台账与计划索引。

## 2. 审核覆盖与本次事实

| 项目 | 本次核实结果 |
|---|---|
| tracked Markdown | `docs/` 下 116 份；无完全相同内容的重复文件 |
| Dart 生产文件 | `lib/` 下 75 份 |
| Dart 测试文件 | `test/` 下 54 份 |
| 生产入口可达性 | 从 `lib/main.dart` 沿 import/export 图可达 63 份，12 份不可达；其中 1 份仍由 `tool/` 使用 |
| 测试夹具 | `test/fixtures/` 3 份，全部被 `domain_self_check_test.dart` 使用 |
| 文档链接 | 排除 fenced/inline code 后，116 份 tracked Markdown 的本地文件链接未发现断链 |
| 测试静态扫描 | 736 个静态 `test/testWidgets` 声明无重复字面标题；54 份测试文件的本地/package import 均可解析 |
| TODO/FIXME/@Deprecated | `lib` 无 TODO/FIXME/@Deprecated；测试只有一处有理由说明的 `deprecated_member_use` 抑制 |
| `flutter analyze` | 本次运行：0 issue |
| domain 自检 | 本次运行：26/26；step0=5、v3=5、v4=3 |
| 全量 Flutter 测试 | 本次运行：745/745 通过 |

### 删除风险定义

- **低**：引用范围小、可由 Git 历史恢复，删除后不应影响生产行为。
- **中**：会改变公共数据结构、测试支撑或开发工具；需要同步修改和全量回归。
- **高**：可能破坏生产行为、发布/审计证据、回归硬约束或当前可用的开发诊断能力。

## 3. `docs` 发现

### D1. 发布台账在同一文件内维护了互相冲突的“当前发布”事实

- **类型**：误导说明 / 过期文档
- **位置**：[docs/release-configuration.md:17](../release-configuration.md#L17)、[docs/release-configuration.md:23](../release-configuration.md#L23)、[docs/release-configuration.md:366](../release-configuration.md#L366)、[docs/release-configuration.md:370](../release-configuration.md#L370)
- **现状证据**：
  - §1 的测试轨道行写“最后核对 2026-07-23”，当前 Internal 为 `0.3.20 (23)`，Alpha `0.3.20 (23)` 审核中，当前主线为 `main@36ce274`；文档总标题的最后核对日期仍是 2026-07-21。
  - 同一文件 §6.3 标题仍是“当前发布与下一候选”，却写当前 Internal 为 `0.3.16 (19)`、当前 Alpha 为 `0.3.14 (17)`。
  - 本次 Git 核实当前主线为 `b5b1768`；`pubspec.yaml` 仍为 `0.3.20+23`。本次没有访问 Play Console，因此不把任何外部轨道状态推断为实时事实。
- **判断**：台账不是单纯“历史快照较旧”，而是同一权威文档内两个“当前”入口直接冲突。接手者按 §6.3 操作会错误判断最高 `versionCode` 和轨道状态。
- **删除风险**：**高**。该文件包含发布 SOP、历史 AAB 证据和安全边界，不能整份删除。
- **处置建议**：保留稳定 SOP；把动态状态收敛成唯一摘要区。§6.3 改名为带日期的历史记录或只链接 §1；更新主线提交时明确“Git 本次核实”与“平台最后核对”是两种事实。

### D2. `plans/README.md` 索引已漏掉 12 份计划

- **类型**：过期文档 / 误导说明
- **位置**：[docs/plans/README.md:3](../plans/README.md#L3)、[docs/plans/README.md:5](../plans/README.md#L5)
- **现状证据**：索引声称“当前收录 43 份计划”，表格也只列 43 份；目录实际有 55 份计划（不含 README），漏掉以下 12 份：
  - `2026-07-19-google-play-three-day-trial-design.md`
  - `2026-07-19-google-play-three-day-trial.md`
  - `2026-07-19-motion-pose-nose-optional.md`
  - `2026-07-19-voice-latest-wins-design.md`
  - `2026-07-20-app-update-prompt-design.md`
  - `2026-07-20-app-update-prompt.md`
  - `2026-07-20-membership-trial-card-annual-7d-design.md`
  - `2026-07-20-membership-trial-card-annual-7d.md`
  - `2026-07-20-workout-coach-bar-design.md`
  - `2026-07-20-workout-coach-bar-implementation.md`
  - `2026-07-21-workout-pose-guide-recovery-design.md`
  - `2026-07-21-workout-pose-guide-recovery-implementation.md`
- **判断**：目录已有索引治理机制，但从 2026-07-19 起未持续维护，导致“已落地/部分/废弃”的状态入口不完整。计划本身不能仅因未入索引就判死。
- **删除风险**：**高**。这些计划保存设计约束和实现依据，不应按漏项批量删除。
- **处置建议**：补齐 12 项及状态；以后用只读校验脚本检查“目录文件集合 = 索引文件集合”。

### D3. 当前入口错误地把三份重构期历史快照描述为“现状/方案”

- **类型**：过期文档 / 误导说明（**已知债务，非本次首次发现**）
- **位置**：[docs/architecture-analysis.md:3](../architecture-analysis.md#L3)、[docs/architecture-analysis.md:18](../architecture-analysis.md#L18)、[docs/architecture-plan.md:3](../architecture-plan.md#L3)、[docs/refactor-report.md:1](../refactor-report.md#L1)、[AGENTS.md:87](../../AGENTS.md#L87)
- **现状证据**：
  - 三份文档顶部已明确绑定 2026-07-09 的 `c7c6593` / `v0.1-architecture-baseline`，因此正文中的“当前目录结构”“目标分层”应按历史基线理解，不能直接视为事实错误。
  - `architecture-analysis.md` 在其历史基线中记录 2484 行 `main.dart`、`WristAnchor` 位于 `ui/`、`CounterConfig` 旧字段；当前代码已存在 `product/wrist_anchor.dart`、`PushupPipeline`、`WorkoutController`，`main.dart` 也已拆分。
  - 真正会误导当前接手者的是 `AGENTS.md` 和 `docs/modules/README.md` 仍把这些文件描述为“架构现状/重构方案”，没有标明其历史快照属性。
  - [docs/reviews/2026-07-16-full-review-report.md:138](2026-07-16-full-review-report.md#L138) 已记录同一问题；本次核实横幅仍未补。
- **判断**：历史正文自身已带日期和基线，属于有效快照；问题仅在当前入口仍把它们标为“架构现状 + 债务清单 / 目标分层 + 重构路线图”。
- **删除风险**：**中**。删除会丢失重构依据；继续无横幅保留会误导。
- **处置建议**：顶部加醒目的“历史基线，非当前 main”横幅；`AGENTS.md` 和 `modules/README.md` 改为“重构历史”；另建简短的当前架构概览，或明确以 `development-guide.md + modules/` 为当前事实源。

### D4. 两份已完成任务仍以 `TODO` 命名，其中一份正文后半仍声称尚未完成

- **类型**：过期文档 / 误导说明
- **位置（修复后已改名）**：[docs/completion-pose-feedback-audio.md](../completion-pose-feedback-audio.md)、[docs/completion-pose-lost-audio.md](../completion-pose-lost-audio.md)
- **现状证据**：
  - 两份文档状态均标“已完成”，对应中英文素材和测试已落地。
  - `TODO-pose-lost-audio.md` 的后半仍保留“为什么现在没做”“下一轮补录”“未来只需放 wav”等未完成叙述，与顶部完成状态冲突。
- **判断**：文件名会让 TODO 扫描继续报假阳性；`pose_lost` 文档内部还会误导接手者重复安排工作。
- **删除风险**：**低**。完成记录已进入 Git 历史和语音模块文档，但仍应保留必要的素材来源/验收证据。
- **处置建议**：将完成证据合并到 `docs/modules/voice-themes.md` 或移动到历史记录目录；至少改名为 completion record，并删除/改写未完成段落。

### D5. README 指示用户进入一个没有入口的“App 测试模式”

- **类型**：误导说明
- **位置**：[README.md:49](../../README.md#L49)、[README.md:54](../../README.md#L54)、[docs/design/app-ui-v1.md:7](../design/app-ui-v1.md#L7)、[docs/design/app-ui-v1.md:228](../design/app-ui-v1.md#L228)、[test/home_page_test.dart:145](../../test/home_page_test.dart#L145)
- **现状证据**：
  - README 的离线验证步骤要求“在 App 测试模式 → 离线回放 → 选择视频”。
  - UI 规范要求首页不展示测试模式入口，Debug 与 Release 一致；测试也明确断言首页找不到“测试模式”。同一设计真源又要求测试模式“保留开发可用”，因此当前缺的是可执行的开发入口，不能据此断言工具已决定退休。
  - 全仓生产调用图中没有文件 import `test_mode_page.dart`，`main.dart` 没有其 import 或导航。
- **判断**：该步骤在当前 App 中不可执行。它与 L2 的不可达开发工具属于同一根因。
- **删除风险**：**高**（README 不可删除；改写这段说明风险低）。
- **处置建议**：若恢复 dev-only 入口，README 写出实际启动命令/entrypoint；若退休测试模式，删除这段 App 操作说明，改为当前可执行的 `tool/` 或 fixture 回放命令。

### D6. 已收敛的 2026-07-22 漏记调查交接缺少被替代标记

- **类型**：过期文档 / 误导说明
- **位置**：[docs/handoff-2026-07-22-count-miss-investigation.md:5](../handoff-2026-07-22-count-miss-investigation.md#L5)、[docs/handoff-2026-07-22-count-miss-investigation.md:103](../handoff-2026-07-22-count-miss-investigation.md#L103)、[docs/modules/recognition.md:255](../modules/recognition.md#L255)、[docs/modules/recognition.md:257](../modules/recognition.md#L257)
- **现状证据**：
  - 交接绑定 `main@cd91a4b`，要求接手者等待异常日志，状态写“无额外改动”、Flutter 715/715。
  - 当前识别权威文档已记录该次漏记日志的根因：近距离底部肩部置信度跌落；并记录 `tooCloseGroundSpanPx=600` 的 ready 阻断缓解。
  - 当前历史包含 `ce3bb29 feat(recognition): block ready when too close to camera`，且本次全量测试为 745/745。
- **判断**：该文件已明确绑定日期和提交，本身是有效历史快照；问题是它位于当前 docs 根且缺少完成/被替代横幅，容易被误作待执行任务书。
- **删除风险**：**低**。其诊断流程有历史价值，但不应继续占当前交接入口。
- **处置建议**：移动到 archive 或在顶部写“已由 recognition.md §10 + ce3bb29 收敛”；当前接手只链接权威识别文档。

### D7. `docs/superpowers/` 的 14 份旧计划/规格缺少生命周期索引

- **类型**：过期文档 / 冗余计划
- **位置**：[docs/superpowers/plans/2026-07-09-membership-subscription.md:3](../superpowers/plans/2026-07-09-membership-subscription.md#L3)、[docs/superpowers/plans/2026-07-09-membership-subscription.md:13](../superpowers/plans/2026-07-09-membership-subscription.md#L13)、[docs/release-configuration.md:33](../release-configuration.md#L33)
- **现状证据**：
  - 目录有 7 份 plan + 7 份 spec，没有 README/index。
  - 会员计划保留了当时未勾选的 OAuth、Play 商品、RevenueCat entitlement/webhook 清单；这是历史执行快照，不能用来反推当前平台状态。
  - 计划顶部还要求已不在当前项目 Skill 列表中的旧 `superpowers:*` 执行方式。
- **判断**：这些文件是早期生成的实施快照，其中两份仍被 `docs/modules/membership.md` 作为历史设计依据引用；问题是目录没有 README/index、源提交和 superseded 状态，不能把历史 checklist 与当前状态差异本身算作事实冲突。该问题已见 2026-07-16 审核报告，属于已知债务。
- **删除风险**：**中**。它们保留早期设计和审计线索，但继续原位无索引会制造重复事实源。
- **处置建议**：为目录增加“历史生成计划”README，全部标记源提交与 superseded 状态；或整体移入 archive。平台当前事实只指向 `release-configuration.md` 与受保护台账。

## 4. `lib` 发现

### L1. 旧 `SignalFilter + pressDepthY + elbowLateral` 路径已经退出生产管线，但仍留在 domain 并由测试保活

- **类型**：死代码 / 旧实现 / 冗余测试支撑
- **位置**：[lib/pushup_domain.dart:46](../../lib/pushup_domain.dart#L46)、[lib/pushup_domain.dart:172](../../lib/pushup_domain.dart#L172)、[lib/pushup_domain.dart:213](../../lib/pushup_domain.dart#L213)、[lib/pushup_domain.dart:317](../../lib/pushup_domain.dart#L317)、[docs/modules/recognition.md:73](../modules/recognition.md#L73)、[docs/modules/pushup-pipeline.md:40](../modules/pushup-pipeline.md#L40)
- **现状证据**：
  - `SignalExtractor` 仍平均左右手腕得到 `wristY`，再生成 `pressDepthY = shoulderY - wristY`。
  - `SignalFilter` 仍维护 shoulder、pressDepth、torso 三个移动平均窗口。
  - 全仓生产代码没有实例化 `SignalFilter`；唯一实例在 `domain_self_check_test.dart`。
  - `PushupPipeline` 直接把信号交给 `PushupCounter`，模块文档明确“只平滑一次”，并把 `pressDepthY` 标为“已弃用（历史遗留，counter 不再用）”。
  - `elbowLateral` 只在 extractor 赋值、`copyWith` 传播和一条测试断言中出现，没有生产读取方。
- **判断**：这是重构前算法的惰性残留，不是活跃兼容合同。尤其保留“双腕平均”的 inert 字段会削弱项目最重要的“不平均双腕”纪律，未来调用者可能误用。
- **删除风险**：**中**。它们属于公开 Dart 类型/类，删除需同步测试和可能的诊断格式，但当前生产调用图无读者。
- **处置建议**：在独立清理分支中删除 `SignalFilter`、`pressDepthY`、`elbowLateral` 及 extractor 的 `wristY` 平均；保留仍被诊断日志使用的 `shoulderY/headY`。先补/确认生产 pipeline 单次中值滤波契约，再跑 5/5/3 与全量测试。

### L2. `TestModePage` 及其 10 个专属支持文件不从 `main.dart` 可达，FFmpeg 依赖只服务该不可达链

- **类型**：死代码候选 / 冗余开发工具
- **位置**：[lib/ui/pages/test_mode_page.dart:13](../../lib/ui/pages/test_mode_page.dart#L13)、[lib/main.dart:27](../../lib/main.dart#L27)、[test/home_page_test.dart:145](../../test/home_page_test.dart#L145)、[pubspec.yaml:26](../../pubspec.yaml#L26)
- **现状证据**：
  - 从 `lib/main.dart` 沿 Dart import/export 图分析，以下 11 份文件不可达，且生产代码只有它们互相引用：
    - `lib/ui/pages/test_mode_page.dart`
    - `lib/control/replay_control.dart`
    - `lib/inference/keypoint_log.dart`
    - `lib/perf/performance_meter.dart`
    - `lib/platform/ffmpeg_kit_runner.dart`
    - `lib/platform/replay_utils.dart`
    - `lib/platform/report_directory.dart`
    - `lib/platform/video_replay_service.dart`
    - `lib/report/performance_report.dart`
    - `lib/ui/overlay_renderer.dart`
    - `lib/ui/perf_panel.dart`
  - `test_mode_page.dart` 没有任何生产 import；首页测试明确要求不显示测试模式。
  - `ffmpeg_kit_flutter_new` 的唯一 `lib` import 位于 `ffmpeg_kit_runner.dart`，因此只服务不可达页面链。
  - 另一个不可达文件 `lib/report/golden_frame_report.dart` **不属于可删集合**：`tool/golden_frame_report.dart` 和两份测试仍在真实调用它。
- **判断**：这不是“单个孤儿类”，而是一套被产品入口切断、却继续留在 App package 与依赖清单中的开发工具。当前状态既不能按 README 使用，也没有独立 dev entrypoint。
- **删除风险**：**高**。整套页面仍包含离线视频、实时 delegate、性能报告等诊断能力；直接删除会损失人工工具并牵连多份测试。
- **处置建议**：先做产品决策：
  1. 保留：建立明确的 dev-only entrypoint/命令，不进入 Release 导航，并更新 README；
  2. 退休：删除上述 11 文件及对应专属测试、源码字符串契约和 `ffmpeg_kit_flutter_new`，但保留 `golden_frame_report.dart` 的 CLI 工具链。

### L3. 10 个 ARB key 已无生产 getter 调用

- **类型**：死代码 / 冗余本地化资源
- **位置**：[lib/l10n/app_zh.arb:64](../../lib/l10n/app_zh.arb#L64)、[lib/l10n/app_zh.arb:293](../../lib/l10n/app_zh.arb#L293)、[lib/l10n/app_zh.arb:527](../../lib/l10n/app_zh.arb#L527)、[lib/l10n/app_zh.arb:700](../../lib/l10n/app_zh.arb#L700)、[lib/l10n/app_zh.arb:714](../../lib/l10n/app_zh.arb#L714)、[lib/l10n/app_zh.arb:724](../../lib/l10n/app_zh.arb#L724)、[lib/l10n/app_en.arb:25](../../lib/l10n/app_en.arb#L25)、[lib/l10n/app_en.arb:210](../../lib/l10n/app_en.arb#L210)、[lib/l10n/app_en.arb:255](../../lib/l10n/app_en.arb#L255)
- **现状证据**：排除生成的 `app_localizations*.dart` 后，全仓没有 `.key` 调用：
  - `leaderboardFrozenScoreTitle`
  - `profileLocalTrainingData`
  - `testMode`
  - `workoutPreparing`
  - `workoutReady`
  - `workoutGoalValue`
  - `workoutCaloriesValue`
  - `workoutStatusError`
  - `workoutTodayGoal`
  - `workoutBurned`
- **判断**：这些 getter 之所以不被 analyzer 报 unused，是因为它们是生成的公开 API。`workoutTodayGoal/workoutBurned` 只在 `architecture_contract_test.dart` 的“不得出现”负向源码断言中以字符串形式出现，不是 getter 调用；`workoutGoalValue/workoutCaloriesValue` 对应已经移除的伪目标/热量 UI；`testMode` 与 L2 的不可达页面决策绑定。`exerciseSummary` 仍被语音资源测试直接验证，不属于本项。
- **删除风险**：**低**；`testMode` 在恢复 dev-only 页面时为**中**。
- **处置建议**：确认无设计稿/待恢复功能后从中英 ARB 同步删除并运行 `flutter gen-l10n`，不要手改生成文件。`testMode` 等 L2 决策后处理。

### L4. 三个只供测试使用的 fake/memory 实现放在生产 `lib` 中

- **类型**：冗余实现 / 测试支撑错位
- **位置**：[lib/platform/account_session_store.dart:92](../../lib/platform/account_session_store.dart#L92)、[lib/platform/leaderboard_home_rank_store.dart:95](../../lib/platform/leaderboard_home_rank_store.dart#L95)、[lib/platform/revenuecat_service.dart:135](../../lib/platform/revenuecat_service.dart#L135)、[lib/main.dart:66](../../lib/main.dart#L66)
- **现状证据**：
  - `MemoryAccountSessionStore`、`MemoryLeaderboardHomeRankStore`、`FakeRevenueCatService` 在生产 `lib` 没有实例化。
  - `main.dart` 分别使用 `SecureAccountSessionStore`、`SecureLeaderboardHomeRankStore`、`PurchasesRevenueCatService`。
  - 三个实现被大量单元/Widget 测试直接 import 使用。
- **判断**：它们不是可直接删除的死代码，而是 test fake 泄漏到生产库的公共 API；会让静态引用图看起来像多套生产实现，并扩大维护面。
- **删除风险**：**中**。直接删除会使大量测试无法编译。
- **处置建议**：迁到 `test/support/` 或测试专用 package，并让测试统一 import；生产接口和真实实现留在 `lib`。这是整理项，不应和业务删除混在一个提交。

## 5. `test` 发现与保留项

### T1. `domain_self_check_test.dart` 有一条测试只验证已退出生产管线的 `SignalFilter`

- **类型**：冗余测试 / 旧实现测试
- **位置**：[test/domain_self_check_test.dart:155](../../test/domain_self_check_test.dart#L155)、[test/domain_self_check_test.dart:163](../../test/domain_self_check_test.dart#L163)
- **现状证据**：
  - `SignalFilter smooths jitter and holds through NaN` 是唯一实例化 `SignalFilter` 的位置。
  - 紧接着的回放测试注释明确写“无外部 SignalFilter，与生产 PushupPipeline 路径一致”。
- **判断**：该测试没有守护当前生产行为，反而使 L1 的旧类看似仍有使用者。
- **删除风险**：**中**。不能单独删测试后保留无契约旧类；应与 L1 的代码删除同一提交完成。
- **处置建议**：删除 L1 旧路径时移除本条测试，并同步调整 `elbowLateral` 断言和构造 `pressDepthY` 的测试 helper；`domain_self_check_test.dart` 其余 25 条和 5/5/3 fixture 回放全部保留。

### T2. 测试套件继续守护不可达测试模式，是否冗余取决于 L2 决策

- **类型**：冗余测试候选 / 旧开发工具测试
- **位置**：[test/architecture_contract_test.dart:407](../../test/architecture_contract_test.dart#L407)、[test/architecture_contract_test.dart:545](../../test/architecture_contract_test.dart#L545)、[test/architecture_contract_test.dart:990](../../test/architecture_contract_test.dart#L990)、[test/replay_control_test.dart:1](../../test/replay_control_test.dart#L1)、[test/performance_report_test.dart:1](../../test/performance_report_test.dart#L1)
- **现状证据**：
  - `architecture_contract_test.dart` 直接读取 `test_mode_page.dart` 源码，锁定 delegate 切换、相机失败清理和 `OverlayRenderer` 字符串。
  - 同一文件还包含对 `replay_utils.dart` 的混合契约；若退休测试模式，只能删除相关断言，不能据此删除整个 `architecture_contract_test.dart`。
  - `replay_control_test.dart`、`keypoint_log_test.dart`、`performance_meter_test.dart`、`performance_report_test.dart`、`report_directory_test.dart`、`video_replay_service_test.dart` 只服务 L2 的不可达开发工具链。
  - 本次这些测试全部通过；它们不是“坏测试”，而是守护一个没有入口的工具。
- **判断**：若恢复 dev-only 入口，这些测试应保留并补真正的入口测试；若退休工具，它们会成为应同步删除的冗余测试。不能在代码决策前单独删测试。
- **删除风险**：**高**。先删会失去对仍保留开发工具的回归保护。
- **处置建议**：随 L2 二选一处理。`golden_frame_report_test.dart` 和 `golden_frame_tool_test.dart` 不在删除集合，CLI 仍活跃。

### T3. 回放 fixtures 全部活跃，不存在可删的过期 fixture

- **类型**：保留项（非发现）
- **位置**：[test/domain_self_check_test.dart:163](../../test/domain_self_check_test.dart#L163)、[test/domain_self_check_test.dart:188](../../test/domain_self_check_test.dart#L188)、[test/domain_self_check_test.dart:209](../../test/domain_self_check_test.dart#L209)
- **现状证据**：`replay_step0.csv`、`replay_v3.csv`、`replay_v4.csv` 分别被读取；本次实跑输出为 5、5、3。
- **判断**：三份 fixture 都对应当前硬约束，没有孤儿或重复 fixture。
- **删除风险**：**高 / 不可删**。
- **处置建议**：原样保留。真实视频、关键点日志仍不得进入 Git。

### T4. 静态扫描与抽查未发现其余明显断裂或重复

- **类型**：保留项（非发现）
- **位置**：`test/` 全量
- **现状证据**：
  - 54 份测试文件均被本次 `flutter test` 加载，745/745 通过。
  - 736 个静态 `test/testWidgets` 声明未发现重复字面标题；54 份测试文件的本地/package import 均可解析。
  - 除 T1/T2 外，对当前生产类、CLI 工具和架构合同的抽查未发现明显孤儿测试。
- **判断**：这些证据支持“未发现明显断裂/重复”，但不能证明每条测试都无冗余。不能因多个层级测试覆盖同一业务主题就判“重复”；controller、Widget、store/API 各自覆盖不同边界。
- **删除风险**：**高**。
- **处置建议**：不做批量测试瘦身；只随已确认删除的实现同步移除精确测试。

## 6. 明确保留的高风险点

### `claimLegacyForOwner` 是活跃的用户功能，不是可删迁移残留

- **位置**：[lib/ui/pages/profile_page.dart:575](../../lib/ui/pages/profile_page.dart#L575)、[lib/ui/pages/profile_page.dart:599](../../lib/ui/pages/profile_page.dart#L599)、[lib/control/workout_sync_controller.dart:62](../../lib/control/workout_sync_controller.dart#L62)、[lib/product/workout_session_store.dart:341](../../lib/product/workout_session_store.dart#L341)
- **证据**：Premium 用户设置页显示“同步本机历史”；确认弹窗捕获当前账号后调用 controller，store 补齐 `localDate/timezoneOffsetMinutes/ownerAppUserId` 并进入 pending；中英文 ARB、页面测试、controller 测试和 store 测试均存在。
- **结论**：**保留，删除风险高**。它是显式用户授权的旧本地记录认领流程，不是自动迁移死代码。

### `lib/report/golden_frame_report.dart` 不从 App 入口可达，但仍是活跃 CLI 库

- **位置**：[lib/report/golden_frame_report.dart:3](../../lib/report/golden_frame_report.dart#L3)、[tool/golden_frame_report.dart:4](../../tool/golden_frame_report.dart#L4)
- **证据**：CLI 直接 import 并调用 `buildGoldenFrameReport`；library 与 tool wrapper 各有测试。
- **结论**：**保留，删除风险高**。App import 图的“不可达”不等于整个仓库死代码。

## 7. 建议治理顺序

1. **先修文档真源，不删历史证据**
   - 修 D1 发布台账内部矛盾。
   - 补 D2 计划索引。
   - 给 D3/D6/D7 加历史/被替代标记。
   - 收拢 D4 完成记录，修 D5 README 不可执行步骤。

2. **独立清理旧 domain 路径**
   - L1 + T1 同一提交。
   - 必跑 `flutter analyze`、全量 `flutter test`、domain 26/26 和 5/5/3。

3. **对测试模式做明确产品决策**
   - 若保留：建立 dev-only entrypoint，并让 README 真正可执行。
   - 若退休：L2 + T2 + `ffmpeg_kit_flutter_new` 同一清理批次；保留黄金帧 CLI。

4. **低风险尾项**
   - 清 L3 ARB key 并重新生成 l10n。
   - 将 L4 test fake 移到 `test/support/`。

## 8. 验证与边界

主审核会话亲自运行：

```text
flutter analyze
  No issues found

flutter test test/domain_self_check_test.dart --reporter expanded
  26/26 passed
  Step0=5 / v3=5 / v4=3

flutter test --reporter compact
  745/745 passed
```

独立复核任务没有重跑可能创建缓存/临时目录的 Flutter 命令；它独立复算了文档、Dart 文件、导入图、fixture、测试声明和链接统计，并逐项检查 D1-D8、L1-L4、T1-T4。复核确认 D8 是 inline-code 中记录的旧问题而非真实 Markdown 链接，故已删除该误报；其余修正已合并到本报告。

未执行：

- 未修改或删除任何 `lib/test/docs` 既有文件。
- 未运行真机、相机、Play 安装、OAuth、Billing 或生产 Worker/D1 验收。
- 未读取或修改远程 Play/Cloudflare/RevenueCat 状态。
- 未运行 Worker 测试，因为本次范围是 `docs + lib + test` 的只读陈旧度审核，且未修改 Worker。
- 未 stage、commit、push、部署或执行外部写入。
