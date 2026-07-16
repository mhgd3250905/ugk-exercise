# 项目全量 Review 报告（2026-07-16）

> 本报告是 [执行计划](2026-07-16-full-review-plan.md) 的产出物。**只读分析**，不改产品代码。
>
> 基线：`main` `d9533fd`（`docs: record 0.3.8 alpha submission`），分支 `chore/full-review-2026-07-16`，与 `origin/main` 同步。
>
> 复核方法：对抗式（不轻信文档自述，去代码核对）。下文每条"实测"标注的数字均为本次会话亲自运行命令得到，非引用历史台账。
>
> **本报告已完成全部 13 维度 + audit M1-M3/L1-L3 复核。** 维度 1-3（P0）→ 4-7（P1）→ 8-10（P2）→ 11-13（P2）逐批产出，每批发现均经源码独立验证。

---

## 执行摘要（给审核团队的一页纸）

### 一句话结论
**项目的实际工程基线是健康的**（407 测试全绿、回放基线自包含可复现、模型权重在 git、权限极简、相机帧纯端侧、上行同步契约扎实）。问题集中在三类：**(A) 文档没跟上代码（最多，低风险）；(B) 账号生命周期的数据治理缺口（隐私级，需优先）；(C) 线上可观测性近乎为零（运维级）。** 代码本身的质量明显高于文档质量。

### 🔴 阻塞接手项汇总（按修复优先级，均为文档/工程治理，非算法 bug）
| # | 项 | 维度 | 性质 |
|---|---|---|---|
| 1 | **signOut 不清本地训练数据 + 展示不按 owner 过滤 → 跨账号 PII 泄漏** | 6 / 11 | 隐私合规（GDPR/个保法） |
| 2 | **release 包零可观测**：无 Crashlytics、无全局 onError、debugPrint 被抑制、trace 被 kDebugMode 门控 | 7 / 12 | 线上无法运维 |
| 3 | **商业链路全程无日志**（购买/OAuth/同步/排行榜失败都查不到） | 7 / 12 | 用户投诉无法定位 |
| 4 | README 测试数 89→407、AGENTS "约30提交"→296 | 1 / 2 | 文档失真（接手第一屏） |
| 5 | `docs/plans/` 29 份无索引 + superpowers/plans 7 份 checkbox 全程未勾 | 3 | 文档治理 |
| 6 | Dart↔Worker 无共享 schema，端点/字段/错误码全靠人工对齐 | 4 | 跨端契约脆弱 |
| 7 | WorkoutController 零行为测试 + 零 DI（最复杂最危险的控制器） | 5 | 测试盲区 |
| 8 | WorkoutSession 无 schema version + claimLegacy 绑死手动 UI 入口 | 6 | 数据迁移静默丢数据 |
| 9 | 实时推理 App 无性能回归门禁 | 13 | 改 delegate/模型无安全网 |
| 10 | `intl: any` 无版本约束 + 无依赖升级/漏洞扫描流程 | 8 | 供应链 |

### audit M1-M3/L1-L3 复核结论
**6 项全部仍存在于 `d9533fd`**（行号有漂移，已逐一重新定位）。audit 文档自身的测试基线（312/106）已过期（现 407/138）。其中 M1（switchCamera session 守卫时序）、M2（中文字符串状态码）、M3（platform→ui 反向 import）、L1（匿名头像 UI 回退）需后续单独授权处理。

### 值得肯定的设计保留项（不当作问题）
- 回放基线 5/5/3 自包含可复现（干净 checkout 直接绿测）。
- 权限极简（仅 INTERNET/CAMERA/BILLING + 主动 remove 旧存储权限）、零广告/分析/设备指纹 SDK。
- 相机帧纯端侧不落盘不上传；上行同步 owner-scoped + pending 队列 + 服务端去重配额。
- Worker D1 migration 流程规范、测试分层健康（真 SQLite 守 SQL 契约）。
- AAB 发布 SOP 完整 step-by-step、versionCode 严格递增、文档严谨区分证据强度。
- `app-ui-v1.md` "单页 helper 就近保留"（L3 长方法）是刻意简化。

### 接手者最先该读 / 跑 / 小心什么
**见 §5（接手者索引）**——5 份必读文档、3 条必跑命令、3 个高风险区。

---

## 0. 复核基线实测值（本会话亲自运行）

| 项 | 文档自述 | 本次实测（HEAD `d9533fd`） | 命令 |
|---|---|---|---|
| Flutter 测试数 | README `89`、audit `312`、release-config `363`/`407` | **407 全绿** | `flutter test`（本会话实跑，`+407 ... All tests passed!`） |
| Worker 测试数 | audit `106`、release-config `138` | **138**（静态计数 `test("` 调用，与自述吻合；`npm test` 需 `.tmp-test` 构建步骤，未实跑） | `grep -rhn 'test("' workers/.../test/` |
| `v0.4-reproducible..HEAD` 提交数 | AGENTS `约 30` | **296** | `git rev-list --count v0.4-reproducible..HEAD` |
| 测试文件数 | — | 43 | `find test -name "*_test.dart"` |

> 结论先行：**项目的实际工程基线是健康的**（407 测试全绿、回放基线自包含可复现、模型权重在 git）。问题几乎全在"文档没跟上代码"，而不是代码本身。

---

## 1. 维度 1（P0）：环境可复现性与"跑起来"门槛

### 结论

**干净 clone 后 `flutter pub get && flutter analyze && flutter test` 预期全绿，卡点不在"跑测"，而在 README 把门槛写低了、把真机/release 前置藏在二级文档。** 改纯算法/UI 功能的门槛接近零配置；改会员/登录功能或出 release 包才会撞墙。

### 发现清单

#### 🟡 1-1 README 测试数失真（89 vs 实测 407）
- **证据**：`README.md:12` `flutter test # 89 tests passed（含回放基线 5/5/3）`；实测 407。
- **影响**：接手第一屏看到错的数字，会误判项目成熟度与"全绿"对照基准。回放基线 `5/5/3` 本身是对的。
- **建议**：改为动态描述（"400+ 用例，以 `flutter test` 实际输出为准"），避免每次加测试都要手改。

#### 🟡 1-2 README "快速开始" 不够：缺 dart-define / key.properties / 真机 / API level
- **证据**：`README.md:7-16` 只列 `pub get/analyze/test/build apk --release`，正文 0 处提及 `dart-define`/`minSdk`/`ABI`/真机要求。但：
  - `lib/config/membership_config.dart:28-45` `validateMembershipConfig()` 在 `kReleaseMode` 缺任一 `UGK_*` 即 `throw StateError`；`main.dart:25` 无条件调用。
  - `android/app/build.gradle.kts:17-19` release 任务缺 `key.properties` 即 `throw GradleException`。
  - 照 README 抄 `flutter build apk --release` 会**两段式炸**（先 dart 层 StateError，补齐后 GradleException）。
- **缓解**：**Debug 不炸**（`membership_config.dart:29` `if (!kReleaseMode) return;`，debug 默认空串）。`flutter run` 能起来，仅会员功能空转——这是设计意图（`docs/modules/membership.md:125`）。
- **建议**：README 分三段——(1) 纯算法/测试零配置；(2) 真机 Debug 前置（minSdk 24 真机、可选 dart-define）；(3) Release 前置（dart-define-from-file + key.properties，指向 `docs/testing-release-playbook.md`）。

#### 🟡 1-3 没有任何 dart-define / 配置文件模板进 git
- **证据**：`git ls-files | grep config/` = 空（AGENTS.md:36 宣称有 `config/` 目录但实际没有）；无 `.env.example`/`dart-define.example.json`。`docs/testing-release-playbook.md:284-286` 列了三个 `UGK_*` 变量名，但文件不在仓库，新人不知道格式（JSON? key=value? 哪些 key）。
- **建议**：提交 `config/dart-define.example.json`（只含 key 名 + 占位，合规不含真值），或 README 直接列出 key 清单（以 `membership_config.dart:3-11` 为准）。

#### 🟡 1-4 `.gitignore` 注释与实际自相矛盾（模型其实已在 git）
- **证据**：`.gitignore:8-9` 注释写"模型权重（第三方 license，不提交，见 README 下载说明）"，规则 `*.tflite` + 白名单 `!assets/models/*.tflite`；但 `README.md:51` 写"模型权重已打包在 `assets/models/`，无需下载"，且 README 里**没有下载说明**。实测 `git ls-files assets/models/` = `movenet_singlepose_lightning_int8_4.tflite`（2.8MB，确实在 git）。
- **影响**：不阻塞（模型在），但 `.gitignore` 注释会误导接手者去找下载源。
- **建议**：`.gitignore:8-9` 注释改为"assets/models/ 白名单提交，其余 *.tflite 不提交"。

#### 🟡 1-5 真机/模拟器最低要求散落在代码注释，README 未提
- **证据**：`android/app/build.gradle.kts:47` `minSdk = 24`（注释 :45-46 "tflite_flutter + NNAPI delegate 需 minSdk 24；NNAPI 最佳支持需 28+"）；默认推理走 NNAPI（`workout_controller.dart:120` `DelegateMode.nnapi`）。**模拟器通常无可用 NNAPI/GPU delegate，会默默回退 CPU 慢推理，不报错**（`test_mode_page.dart:336` 注释"默认 NNAPI: 真机实测 20-28 FPS"）。README 对 minSdk/API level/ABI/真机要求 0 提及。
- **建议**：README 加一句"需 API 24+ 真机，NNAPI delegate 在模拟器上不可用会回退 CPU（可能误判为卡顿 bug）"。

#### ✅ 1-6（正面）测试夹具完全自洽，回放基线可复现
- **证据**：`git ls-files test/fixtures/` = `replay_step0.csv`/`replay_v3.csv`/`replay_v4.csv` 三件全在 git。回放基线测试 `test/domain_self_check_test.dart:163-223` **只**读这三个 csv（:168,189,210），不读根目录 `俯卧撑.mp4`，不读 `step0/*.csv`。全仓 `grep "俯卧撑.mp4"` 在 test/lib 中 0 引用。语音素材 30/30 wav 在 git，图标 5 密度在 git，AndroidManifest 在 git。
- **结论**：README:16/AGENTS.md:51 "干净 checkout 可直接复现绿测"的承诺**成立**。这是项目强项。

### 卡点时间线（新人视角）
1. **0–30 min**：clone → `pub get` → `analyze` → `test`，全绿，能改算法/UI。
2. **想跑真机**：README 没说 minSdk；插 API<24 或用模拟器 → NNAPI 退化、无报错（1-5）。
3. **想跑会员/登录**：debug 空配置能起 App 但功能空转；要真功能须造 dart-define 文件，无模板可抄（1-3）。
4. **想出 release 包**：README 命令直接两段式炸，需读 354 行 playbook 才能拼齐（1-2）。

---

## 2. 维度 2（P0）：文档与代码真实性对齐（失真审计）

### 复核结论（对照 audit-2026-07-13 当年 7 条文档失真建议）

| audit 当年建议 | 当前状态 | 证据 |
|---|---|---|
| README `89` 失真 | **未修** | `README.md:12` 仍 89（实际 407） |
| AGENTS 测试数滞后 | **部分**（AGENTS 现已无测试数，但"约 30 提交"仍在） | 见 2-2 |
| "v0.4..HEAD 约 30" 失真 | **未修且更严重**（audit 时 132，现 296） | `AGENTS.md:108` |
| 三份历史架构文档加横幅 | **未加** | `architecture-analysis.md`/`-plan.md`/`refactor-report.md` 顶部仅普通引用块 |
| membership.md 更新或标历史 | **已修** | `membership.md:3` 顶部 2026-07-16 权威段 + :40 分界线 |
| release-config canJoin 前后矛盾 | **已修** | `release-configuration.md:658` 加了"以 §1/§6.3 为准" |
| handoff-2026-07-10-review.md 死链 | **未修**（文件仍不存在；audit 自身仍记该问题） | audit-2026-07-13.md:157 |

**7 条里 2 条已闭环（membership.md、release-config canJoin），4 条至今未修，其中 README 测试数与 AGENTS 版本基线属阻塞级。**

### 发现清单

#### 🔴 2-1 README 测试数严重失真（89 vs 407）
（同维度 1-1，从"接手心智模型"角度列为阻塞）`README.md:12`。接手第一屏的错数字会让新人误判覆盖度。

#### 🔴 2-2 AGENTS.md "领先 v0.4 约 30 个提交"严重失真（实际 296）
- **证据**：`AGENTS.md:108`；实测 `git rev-list --count v0.4-reproducible..HEAD` = **296**。audit 时（基线 `1531c37`）记的是 132，现已涨到 296。
- **影响**：接手者会以为 main 只比基线多一点、可快速 `git checkout v0.4` 回退理解，实际 main 已叠加会员/i18n/主题/头像 UGC/排行榜身份/拉黑/冻结分等大量功能，**领先近 300 提交**。
- **建议**：改为"约 296 个提交"或删数字、改为"已大幅领先 v0.4（会员/i18n/主题/头像 UGC/排行榜身份等均不在基线内），精确数以 `git rev-list --count v0.4-reproducible..HEAD` 为准"。

#### 🟡 2-3 audit-2026-07-13.md / review-response 测试基线整体过期（312/106 vs 现状 407/138）
- **证据**：`docs/audit-2026-07-13.md:23` `312/312`、`:25` `106/106`、`:185` 重述；`docs/audit-2026-07-13-review-response.md:19,78-79` 同。现状 407/138。
- **影响**：审计报告本质是快照，但无"已过期"提示，接手者易把"审计基线健康"外推为"当前基线健康"。
- **建议**：两份 audit 文档顶部加横幅："⚠️ 本报告快照于 `1531c37`（2026-07-13）。测试数/commit 数/行号为当时值，当前 HEAD 已大幅前进，以实时命令为准。"

#### 🔵 2-4 三份历史架构文档顶部无"历史基线"横幅
- **证据**：`docs/architecture-analysis.md:3-5`、`docs/architecture-plan.md:3-5`、`docs/refactor-report.md:5` 绑定 `2026-07-09 / c7c6593 / v0.1-architecture-baseline`，无醒目横幅（audit:154 建议过）。
- **建议**：标题下插入 `> ⚠️ 历史基线文档（2026-07-09，绑定 c7c6593）。仅作重构期设计依据，不代表当前 main 现状。`

#### 🔵 2-5 membership.md 已部分修复（顶部权威 + 底部历史）
- **证据**：`docs/modules/membership.md:3` "最后更新：2026-07-16"；:5-40 权威合同；:40 分界"以下 2026-07-09 内容保留为历史实现记录；若与本节冲突，以本节为准"。抽查端点与代码一致（`POST /membership/reconcile` 在 `index.ts:85`，`frozenTotalValue` 在 `leaderboard.ts:322`）。
- **结论**：**已修复**（audit 当年认定的失真项已闭环）。可接受现状。

#### 🟡 2-6 release-configuration.md canJoin 矛盾已修，但"长台账单一真相分散"结构性问题仍在
- **证据**：`release-configuration.md:658` 已加"以 §1/§6.3 为准"。但 §1 摘要（:21-36）写 `0.3.8(11)` 最新、§6.3（:466-468）写 `0.3.8(10)`、:599 又把 0.3.7(8)/0.3.8(9/10/11) 全串一起。接手者需横向比 4-5 处才能定"当前到底是哪个版本"。
- **建议**：§1 摘要明确为唯一"当前状态"，§6.x 标"历史追加记录（按时间倒序，旧状态已失效）"。

#### 🟡 2-7 handoff 死链 + 未跟踪 handoff 引用
- **证据**：`docs/handoff-2026-07-10-review.md` 不存在（audit:157 记过）。另多处 plan/分支报告引用 `docs/handoff-2026-07-14-membership-explore.md`、`docs/handoff-2026-07-13-audit.md` 等未跟踪文件。
- **说明**：handoff 按项目约定是"不入 git 的会话临时文件"，所以严格说不是 bug，但接手者按文档找文件会扑空。
- **建议**：audit:157 那句"应修正"要么删除，要么补"该 handoff 按约定不入仓库，引用仅作会话溯源"。

#### 🔵 2-8 audit/refactor-report 引用的 file:line 单点大多仍准，区间已漂移
- **证据**：audit M3 精确行号仍准（`replay_utils.dart:20` 仍 `import app_theme`、`:27` 仍 `replayVideoName`、`app_theme.dart:32-33` 仍定义两常量）；但 L3 区间（`records_page.dart:122-407`，现 852 行；`workout_controller.dart:217-347`，现 540 行）端点已变。
- **建议**：既然定位为快照（2-3），行号漂移可接受，配横幅即可。

---

## 3. 维度 3（P0）：计划文档状态治理（29 份 plans）

### 结论

`docs/plans/` 共 **29 份** plan，**无 README/索引**。29 份中 **23 份已落地、2 份部分落地、3 份 design-only-but-landed、1 份被后续 plan 废弃**，**真正废案为 0**。风险不是"做了没说"，而是**"文档说的和代码不一致时，文档不会告诉你它过时了"**。07-14 起的 plan 普遍自带状态+hash（接手成本低），早期 plan（尤其 `docs/superpowers/plans/`）checkbox 全程未勾（接手成本高）。

### 29 份 plan 状态表

| # | 文件 | 状态 | 证据 |
|---|---|---|---|
| 1 | `2026-07-10-account-features-hardening.md` | 🟡部分落地 | 提交 `989b7e7`；代码 `workout_sync_controller.dart`/`workouts.ts` 存在；plan 末尾"Final Verification"未回填 |
| 2 | `2026-07-10-review-backlog.md` | 🟡部分落地 | 提交 `a49dce9`；backlog 性质，文件内无逐项勾选 |
| 3 | `2026-07-11-close-range-pushup-counting.md` | ✅已落地 | 提交 `546e6f5`/`6a99101`；`pushup_domain.dart` torsoY 计数 |
| 4 | `2026-07-11-pushup-keypoint-session-replay.md` | ✅已落地 | 提交 `0ce9a3e`；`test/pushup_session_replay_test.dart` |
| 5 | `2026-07-12-account-restore-cache.md` | ✅已落地 | 提交 `fb0b01d`；`account_controller.dart:71 restore()` |
| 6 | `2026-07-12-leaderboard-identity-choice-design.md` | ⚠️被覆盖 | 自标"已确认"；`identity_mode` 在 `0003_leaderboard_identity.sql` |
| 7 | `2026-07-12-leaderboard-identity-choice-implementation.md` | ⚠️**被后续废弃，未回写** | 提交 `2293a31`；plan 写**三模式**(profile/custom/anonymous)，但 `2026-07-14-custom-avatar-design.md` 决定弃 custom，代码 `leaderboard.ts:48` 现仅 profile/anonymous（提交 `88028c4` 删 leftovers）。**跨 plan 变更未回写本文件** |
| 8 | `2026-07-12-pose-silhouette-design.md` | ✅已落地 | 自标"已实现"，hash `cc96dda` 等；`pose_silhouette_tracker.dart` |
| 9 | `2026-07-12-pose-silhouette-implementation.md` | ✅已落地 | 同 #8，design+impl 配对完整 |
| 10 | `2026-07-12-records-period-navigation-design.md` | ✅已落地 | 自标"已确认"；`records_page.dart` period 导航 |
| 11 | `2026-07-12-records-period-navigation-implementation.md` | ✅已落地 | 同 #10 |
| 12 | `2026-07-12-records-status-footer.md` | ✅已落地 | 提交 `5c20941`；`records_page.dart` 状态页脚 |
| 13 | `2026-07-13-audit-report-revision.md` | ✅已落地 | 提交 `65a4f0f`；audit 文档已改"复核修订版" |
| 14 | `2026-07-13-leaderboard-pagination.md` | ✅已落地 | 提交 `d237b70`；`leaderboard.ts:120 encodeLeaderboardCursor` |
| 15 | `2026-07-13-manage-pushupai-project-skill-design.md` | ✅已落地 | 提交 `b6c73e7`/`17e4404`；`.agents/skills/manage-pushupai-project/` 存在 |
| 16 | `2026-07-13-ready-pose-wrist-hip-gate-design.md` | ⚠️design-only，已落地 | 提交 `0143d2b`；实现见 fix `c640627`；`ready_pose_gate.dart:94` |
| 17 | `2026-07-13-ready-pose-wrist-hip-gate-implementation.md` | ✅已落地 | 提交 `0e8eeb6`；与 #16 配对 |
| 18 | `2026-07-13-ready-relative-depth-design.md` | ✅已落地 | 提交 `abaa7fd`；`pushup_pipeline.dart:18,20,78` |
| 19 | `2026-07-13-ready-relative-depth-implementation.md` | ✅已落地 | 同 #18 |
| 20 | `2026-07-13-recognition-trace-and-latency-design.md` | ⚠️design-only，已落地 | 提交 `4528827`，**无 impl 兄弟**；经 fix `d27321b`/`ce6654a` 落地；`recognition_trace_log.dart` |
| 21 | `2026-07-14-custom-avatar-design.md` | ✅已落地 | 提交 `377b8f5`，自标已验收；`avatar.ts`/`0004_custom_avatar_ugc.sql` |
| 22 | `2026-07-14-custom-avatar-implementation.md` | ✅已落地 | 同 #21 |
| 23 | `2026-07-14-membership-pricing-design.md` | ✅已落地 | 提交 `28b0862`；`premium_plan.dart PremiumPlanId.monthly/annual` |
| 24 | `2026-07-14-membership-pricing.md` | ✅已落地 | 同 #23 |
| 25 | `2026-07-15-blocked-users-management.md` | ✅已落地 | 自标"已实现部署验收"，hash `2692367`；`blocked_users_page.dart`/`leaderboard.ts:290` |
| 26 | `2026-07-15-leaderboard-long-press-actions-design.md` | ✅已落地 | 提交 `5187d3b`/`bf198b6`；`leaderboard_page.dart:775 onLongPress` |
| 27 | `2026-07-15-leaderboard-long-press-actions.md` | ✅已落地 | 同 #26 |
| 28 | `2026-07-15-membership-authoritative-reconciliation.md` | ✅已落地 | 提交 `0624f0f`，merge `56a4f31`；`membership_reconciliation.ts`/`0005`；配套报告 `docs/reports/2026-07-16-...-reconciliation.md`（良性配对，非重复） |
| 29 | `2026-07-16-expired-member-frozen-score.md` | ✅已落地 | 提交 `c82cd4b`，自标"已完成提交、部署、内部测试"；`leaderboard.ts:322 frozenTotalValue`；plan 内含"原始 Goal 被修订"自洽说明 |

**小计**：已落地 23 / 部分落地 2（#1 #2，状态未回填而非功能缺失）/ design-only-landed 3（#6 #16 #20）/ 被后续覆盖 1（#7）。

### 发现清单

#### 🔴 3-1 `docs/plans/` 无索引文件，29 份 plan 裸放
- **证据**：`docs/plans/` 无 `README.md`；而 `docs/archive/README.md`、`docs/modules/README.md` 都有索引。
- **影响**：接手者打开目录看到 29 个按日期命名的 md，无法判断哪些已实现/废弃/design-only/配对关系，只能逐个打开 + git log。
- **建议**：补 `docs/plans/README.md`，列每份 plan「主题 / 类型(design|impl|backlog) / 状态 / 配对文件 / 源提交」。

#### 🔴 3-2 `docs/superpowers/plans/` 7 份 checkbox 全程未勾（193 个 `- [ ]`，0 个 `- [x]`）
- **证据**：`2026-07-08-app-product-shell.md`(open=38)、`2026-07-09-account-data-leaderboard.md`(open=82)、`2026-07-09-membership-subscription.md`(open=73) **全部 0 勾选**，但功能早已在 0.3.1~0.3.4 发布（提交 `463004a`/`4f21449`/`7186f2f`）。后四份各剩 1 个未勾项，**无法区分"真未完成"还是"漏勾"**。
- **建议**：至少给前三份顶部加一行"全部已落地于 0.3.x，checkbox 未回填"；剩余 1 个未勾项逐个核实。

#### 🟡 3-3 跨 plan 变更未回写源 plan（典型：identity-choice 三模式→被 custom-avatar 删成两模式）
- **证据**：见状态表 #7。`2026-07-12-leaderboard-identity-choice-implementation.md` 仍详述 `custom` 分支，但代码与 `2026-07-14-custom-avatar-design.md` 已删 custom（提交 `88028c4`）。**两 plan 互相矛盾且都未标注**。
- **建议**：在 #7 顶部加"⚠️ 本 plan 的 custom 模式已被 `2026-07-14-custom-avatar-design.md` 废弃，当前仅 profile/anonymous 两模式"。建立"被谁取代"反向链接惯例。

#### 🟡 3-4 design-only 文档无 implementation 兄弟，需靠 fix 分支还原
- **证据**：#20 `recognition-trace-and-latency-design.md` 无 impl 文件，功能经 `fix:` 提交落地。命名约定 `*-design.md` vs `*-implementation.md` 执行不彻底。
- **建议**：design 落地后在自身补"实现提交 hash"，不强制配 impl 文件。

#### 🟡 3-5 backlog 类 plan（#1 #2）无逐项状态
- **证据**：`review-backlog.md`/`account-features-hardening.md` 文件内无"已修/未修"勾选，判断需逐条 grep 代码。
- **建议**：backlog 随修随勾，或明确标"已整体落地，逐项核对见 git log"。

#### 🔵 3-6 规划类文档物理分散在 4+ 目录
- **证据**：plan 在 `docs/plans/`、早期 plan 在 `docs/superpowers/plans/`、审查在 `docs/refactor/`+`docs/reviews/`、收尾报告在 `docs/reports/`、设计稿在 `docs/superpowers/specs/`+`docs/design/`。同一特性完整故事跨 3-4 目录。
- **建议**：索引文件做交叉链接。

#### 🔵 3-7 状态标注风格不统一（有改善趋势）
- **证据**：07-10~07-13 几乎无状态行；07-14 起普遍带"已实现+hash"。
- **建议**：把"状态行（至少一行：状态/提交/配对）"写入 `manage-pushupai-project` skill 或 contribution guide 作硬性要求。

### 唯一实质方案冲突
**identity-choice（三模式）↔ custom-avatar（两模式，删 custom）**——见 3-3。其余 plan 间未发现方案性矛盾；`docs/reports/` 与 `docs/plans/` 同名 reconciliation 文件是 plan+report 良性配对，非冲突。

---

## 4. audit-2026-07-13 的 M1–M3 / L1–L3 复核（全部在 `d9533fd` 逐条核验）

> 复核结论：**6 项全部仍存在**（行号有漂移）。这印证 audit 的工程判断扎实；同时 audit 文档自身的测试基线（312/106）已过期（见 2-3）。

| 项 | audit 描述 | 当前状态 | 当前证据（本次核验） |
|---|---|---|---|
| **M1** | `switchCamera()` session 检查晚于多个 await | **仍存在** | `workout_controller.dart:160-205`：`session != _session` 首次检查在 :182，此前已 `await endOfFrame`(:176)/`subscription.cancel()`(:178)/`_waitForFramePipelineToIdle()`(:180)/`camera.dispose()`(:181)。`_switchingCamera`(:167) 已防快速连续切换，但 stop/dispose 在 await 期间使旧切换失效后旧流程仍继续的时序风险未变，且无对应 controller 竞态测试 |
| **M2** | Workout 状态以中文字符串充当内部状态码 | **仍存在** | `workout_controller.dart:69` `var _status = '加载中';`；全文多处中文字符串状态（`'切换相机'` :174、`'请按提示摆放手机并保持姿势'` :194 等）；`leaderboard_models.dart:34` `(json['displayName'] as String?) ?? '训练者'` fallback（audit 记在 membership_status.dart:26，行号已漂移）。UI 经 `_localizedWorkoutStatus()` 映射 ARB，当前中英文测试通过，非"英文用户必看中文"的现网故障，但 control↔UI 字符串契约脆弱 |
| **M3** | 分层规则与开发指南对资源常量位置互相矛盾 | **仍存在** | `platform/replay_utils.dart:20` `import '../ui/app_theme.dart';`（platform→UI 反向边）；`app_theme.dart:32-33` 定义 `modelPath`/`replayVideoName`；`development-guide.md:115` 明确要求这两常量放 `ui/app_theme.dart`。**真正问题：分层原则与具体维护规则不一致**，不能只判代码违规 |
| **L1** | UI 保留基本不可达的匿名头像回退算法 | **仍存在** | `leaderboard_models.dart:105,117,129-145,167`：`anonymousAvatarKey='ring-green'` 字段 + `_anonymousAvatarKeys` 验证集 + UI 重复服务端 hash 算法。基本不可达且重复服务端逻辑（audit 记在 :115-120，行号已漂移） |
| **L2** | 部分降级路径缺诊断可观测性 | **仍存在** | audit 记 `app_settings.dart:46,59,68`/`workout_page.dart:340-344`/`workout_sync_controller.dart:91-95` 空 catch 降级（设置写失败留内存值、云同步失败不阻塞本地训练、pending 记录后续重试）。降级语义合理，但缺 UGK 诊断日志，线上排障困难 |
| **L3** | 数个 UI/编排方法较长 | **仍存在（区间漂移）** | `records_page.dart` 现 852 行（audit 记 build 122-407）；`workout_controller.dart` 现 540 行；`profile_page.dart` 现 1700 行。长度客观大、阅读成本高，但 audit 与 `app-ui-v1.md:176-199` 一致认定"单页 helper 就近保留"是刻意简化，不强制抽框架 |

---

## 5. 批 1 阶段性结论：接手者最先该读什么 / 跑什么 / 小心什么

### 最先该读的 5 份（按顺序）
1. **`AGENTS.md`** —— 第一入口，但注意 §"版本基线"的"约 30 提交"是错的（实际 296，见 2-2）。
2. **`docs/development-guide.md`** —— 怎么分块开发；注意 :115 的常量位置约定与分层原则有张力（M3）。
3. **`docs/modules/recognition.md`** —— 算法第一性原则（双手腕锚点），这是项目核心。
4. **`docs/modules/membership.md`** —— 账号/会员后端合同（顶部 2026-07-16 段是权威，底部 2026-07-09 段是历史）。
5. **`docs/testing-release-playbook.md`** —— 测试分层与真机/release 流程（README 缺的前置都在这）。

### 最先该跑的命令
```bash
flutter pub get && flutter analyze          # 预期 0 issue
flutter test                                # 预期 407 全绿（README 写 89，勿信）
cd workers/membership-api && npm run build && npm test   # Worker 138（需先 build 到 .tmp-test）
```

### 最该小心的 3 个高风险区
1. **改会员/登录/RevenueCat 相关**：必须先搞到 dart-define 配置文件（不在 git、无模板，见 1-3）；release 缺值 fail-fast。
2. **改训练状态文案或身份模式**：control 用中文字符串当状态码（M2），改文案可能静默破坏 control↔UI 映射；身份模式历史上有三→两模式的废弃未回写（3-3/#7）。
3. **改 `switchCamera` 或训练生命周期异步流程**：session 守卫时序（M1）在每个 await 后校验是硬纪律，但 `switchCamera` 的守卫仍晚于多个 await；动这里先写竞态测试。

### 故意的设计保留项（**不当作问题**）
- `app-ui-v1.md` 规定的"单页 helper 就近保留"导致长 build 方法（L3）——刻意简化，非债务。
- `PoseSilhouetteTracker`/`ReplayControl` 放在当前层——有独立测试或跨路径复用理由。
- Debug 包会员功能空转——设计意图（`membership.md:125`），非 bug。

### 真·欠账（建议后续单独授权处理，本 review 不改）
- 🔴 README 测试数 89→407、AGENTS "约 30 提交"→296（文档更新，低风险）。
- 🔴 `docs/plans/` 补索引 README + superpowers/plans checkbox 回填（文档治理）。
- 🟡 M1 `switchCamera` session 守卫时序（先写竞态测试再补守卫，见 audit 建议）。
- 🟡 M2 训练状态改 enum/稳定状态码（control↔UI 契约硬化）。
- 🟡 M3 资源常量位置作架构决策（移到 config/ 或文档标注有意例外，二选一，不要只改一边）。
- 🟡 L1 删除 UI 匿名头像回退（让 API/模型合同失败时报错）。

---

## 6. 维度 4（P1）：Worker 子系统的可接手性

> Worker 是独立 TS 子系统（Cloudflare Worker，账号/会员/排行榜后端，`workers/membership-api/`，14 个 src 文件 / 5 个 D1 migration / 15 个测试）。前三篇审计完全没提它。

### 结论
Worker 子系统的**上行同步契约（owner-scoped、pending 队列、服务端去重+配额）和 D1 migration 流程设计扎实**，是接手友好区。最大风险是 **Dart↔Worker 无共享 schema，端点/字段/类型全靠人工对齐**，任一端改名会让另一端静默失败。部署知识有缺口（2 个必需 Secret 未进主清单）。

### 发现清单

#### 🔴 4-1 Dart↔Worker 无共享 schema，端点/字段/类型全靠人工对齐
- **证据**：无 openapi/swagger/zod/json-schema 文件（`find` 全空，`package.json` 仅依赖 `jose`）。TS 侧请求解析全手写 `as Record<string,unknown>` + 逐字段 `typeof`（`workouts.ts:259-287 asWorkoutInput`、`profile.ts:35-52`、`leaderboard.ts:413-439`）；Dart 侧响应全手写 `fromJson`（`membership_api_client.dart:74-95,125-164`）。路由路径字符串在 `index.ts:53-133`（TS）和 `membership_api_client.dart:124-403`（Dart）各写一份，20+ 处字面量需人工同步。
- **复核**：抽查 `/workouts/sync`、`GET /leaderboard` 字段当前完全对齐（请求字段、响应键、枚举值逐一对齐），但**无任何机制保证下次改动同步**。Dart 解析失败被 `membership_api_client.dart:275-277/331-333/358-362` 统一 catch 成泛化 "Invalid ... response"，排障拿不到原始字段名。
- **建议**：引入单一事实源（Worker zod schema → 导出 OpenAPI → Dart 生成，或至少 CI 跑 contract test：Worker 真实响应喂给 Dart fromJson）。

#### 🔴 4-2 `ACCESS_TEAM_DOMAIN`/`ACCESS_AUD` 两个必需 Secret 未进 §7 主部署清单
- **证据**：`types.ts:8-9` 声明这两个（admin.ts 用）；`admin.ts:59-62` 缺失即 `throw new Error("missing Access configuration")`（admin 端点 fail-closed）。但 `release-configuration.md §7`（:570-575）主 Secret 清单只列 4 个（`GOOGLE_CLIENT_ID`/`SESSION_SECRET`/`REVENUECAT_WEBHOOK_SECRET`/`REVENUECAT_SECRET_API_KEY`），这两个只在 `§7.1`(:615) 一行带过。`docs/reviews/2026-07-15-custom-avatar-review.md:78` 自己记过此风险但未吸收进主清单。
- **复核**：已确认 §7 主清单 4 个、types.ts 要 6 个。
- **建议**：把这两个加进 §7 Secret 清单（标注"仅 admin 审核端点必需，缺失则 fail-closed"）。

#### 🟡 4-3 路由表是 90 行 if-链，无集中路由常量/框架
- **证据**：`src/index.ts:45-135` `routeRequest`，22 条路由全手写 `if (method && pathname)`，含 2 处正则。无路由常量表，找某端点必须通读 index.ts。
- **建议**：抽成 `{method, pathPattern, handler}` 表（或引入 Hono/itty-router），该表同时可作契约文档来源。

#### 🟡 4-4 错误码两端各维护，无注册表，新错误码在 Dart 静默落"意外错误"
- **证据**：Worker 错误码分散 7 文件（`invalid_token`/`premium_required`/`nickname_taken`/`avatar_policy_required` 等）；Dart 用硬编码 switch（`profile_page.dart:1690-1699`、`leaderboard_controller.dart:517-528`），无错误码常量文件。新增错误码在 Dart 静默落 `_ => l10n.accountErrorUnexpected`。
- **建议**：Worker 建 `errors.ts` 导出 const 错误码 + 状态码映射表，集中且可生成给 Dart。

#### 🟡 4-5 Worker 目录无 README / 架构总览
- **证据**：`workers/membership-api/` 下无 README；`docs/modules/membership.md` 是 App 视角，非 Worker 入门指南。
- **建议**：补 `workers/membership-api/README.md`（目录布局 + dev/test/migrate 启动步骤 + 与 App 契约指针）。

#### 🟡 4-6 D1 migration 0003 引入的 3 列在 0004 被作废却留在 schema（死列）
- **证据**：`0003:2-4` 加 `leaderboard_nickname`/`leaderboard_nickname_key`/`leaderboard_avatar_key`；`0004:81-86` 置 NULL + DROP INDEX 但未删列；`grep leaderboard_nickname src/` 0 命中（代码从不读写），但 `schema.sql:104-106` 仍保留。
- **影响**：新接手者读 schema 会误以为"排行榜有独立昵称"。
- **建议**：schema 注释标这三列为"deprecated by 0004，新代码勿用"。

#### 🟡 4-7 无 schema 文档（表关系/索引意图散在代码）
- **建议**：补表清单（表名/用途/关键约束/负责的 src 文件）。

#### 🟡 4-8 `wrangler deploy --keep-vars` 不在脚本/步骤，部署非 checklist 化，无 staging 区分
- **证据**：`package.json:7` 只有 `"deploy": "wrangler deploy"`，无 `--keep-vars`；但 `release-configuration.md:583/464/467` 反复提"已用 --keep-vars 部署"——关键 flag 只在叙述台账里。`wrangler.toml` 无 staging/prod 区分。§7 是叙述段落而非编号 checklist（与 §6.4 风格不一致）。
- **建议**：加 `deploy:keep-vars` 脚本；§7 重构成编号 checklist（备份 D1 → apply migration → `wrangler deploy --keep-vars` → 探针 401 → 发布 App）。

#### 🟡 4-9 线上 Worker commit 映射只在本机台账，公开文档无法对账
- **证据**：`release-configuration.md:583/464` "精确版本只在本机私密台账"。接手者无法从仓库确认"当前线上 Worker 是哪个 commit"。
- **建议**：公开台账记每次部署的 Worker commit hash + 时间 + 探针结果（commit hash 非敏感）。

#### 🔵 4-10 校验常量（单次 1000/batch 200/每日 5000）两端硬编码、cursor 结构为隐式契约
- **证据**：`workouts.ts:59` `metricValue > 1000`、Dart `membership_api_client.dart:457` 也写死 1000；`DAILY_RANKING_LIMIT=5000`（`workouts.ts:40`）只在 TS。`nextCursor` 是 base64url JSON（`leaderboard.ts:120-128`），Dart 只透传，**cursor 版本号 `v:1` 无跨端契约文档**。
- **建议**：校验常量集中到 Worker 一处并进契约文档；cursor 结构变更需 bump `v` 并容忍旧 cursor。

### 跨 Dart/TS 类型对齐现状（抽查，当前全对齐）
| 概念 | 对齐 | 说明 |
|---|---|---|
| AppUser（10 字段） | ✅ | `membership_status.dart:1-60` ↔ `account.ts:32-43` 逐字段对齐 |
| LeaderboardRow（6 字段） | ✅ | `leaderboard_models.dart:71-98` ↔ `leaderboard.ts:346-361` |
| avatarKey 枚举（8 个） | ✅ | `profile_avatar.dart:8-17` ↔ `profile.ts:5-14` 完全一致 |
| 匿名头像枚举（5 个） | ✅ | `leaderboard_models.dart:167-173` ↔ `leaderboard.ts:61-67` |
| MembershipStatus | ✅ | API 响应 4 字段对齐；TS 内部 `MembershipSnapshot` 多 `verifiedAt`（不进 API，需注释） |

### 正面发现
- D1 migration 流程（命名 `NNNN_*.sql` 严格递增、`schema.sql` 顶部强警告"非部署入口"、`schema-migration.test.mjs` 用真 wrangler CLI 验证迁移链）——接手友好。
- `wrangler.toml` binding 与 `types.ts Env` 对齐良好。

---

## 7. 维度 5（P1）：测试策略矩阵

### 结论
**407 测试 + 138 Worker 测试的量充足，但"测什么/不测什么"无策略文档。** 关键盲区：**WorkoutController（最复杂、最危险）零行为测试 + 零 DI**，只能靠源码字符串断言"假装"守护；相机/推理真机边界全靠回放 csv（且不接 wrist/ready 门控）。`architecture_contract_test.dart` 本质是源码字符串匹配而非行为/分层测试。

### 发现清单

#### 🔴 5-1 WorkoutController 无任何行为测试，audit M1"补竞态测试"优先级项未落地
- **证据**：无 `test/workout_controller_test.dart`（`find` 确认）。WorkoutController 仅出现在 `architecture_contract_test.dart`（2 处源码字符串断言）和 `workout_page_test.dart`（全用 `_FakeWorkoutController:359-399`，只测页面渲染不测 controller 逻辑）。audit M1（`audit-2026-07-13.md:37-45,192`）建议"先写 switchCamera stop/dispose 竞态测试再补守卫"——**未落地**。session 守卫/`_busy`丢帧/`_switchingCamera`互斥/`_stopping`幂等/`_maxLostPoseFrames=15` 全无行为测试。

#### 🔴 5-2 WorkoutController 构造函数无 DI，8 协作者硬编码 new，无法注入 fake 复现竞态
- **证据**：`workout_controller.dart:40` `WorkoutController();`（无参）；`:44-51` 8 个 `final _x = ...()`（CameraService/PoseEstimator/PushupPipeline/CameraCalibration/ReadyPoseGate/WristAnchor/VoicePromptPlayer/RecognitionTraceLog）全硬编码实例化。refactor-report 6.6（`:218`）标此为设计债——**仍在**。
- **对比**：Account/Leaderboard/WorkoutSync 三 controller 构造函数全可注入 fake，竞态测试成熟（`account_controller_test.dart` ~33 test、`leaderboard_controller_test.dart` ~28 test、`workout_sync_controller_test.dart` ~15 test）。**唯独 WorkoutController 是洼地。**

#### 🔴 5-3 相机/推理无真机边界测试，全靠回放 csv + 源码字符串断言
- **证据**：回放只喂 `torsoY`/`elbowAngle`（`domain_self_check_test.dart:163-223`），不经 YUV/推理/相机。NNAPI/isolate 仅 `architecture_contract_test.dart:258-289` 源码断言（`IsolateInterpreter.create`、`switchDelegate` 先 load 再替换）。refactor-report §0（`:13`）自认"测试可能没覆盖异步生命周期/真机边界"。`test_mode_page` live camera 是手动调试页非自动化测试。

#### 🟡 5-4 `architecture_contract_test.dart` 是源码字符串匹配，非行为/分层测试
- **证据**：34 个 test 全 `File('lib/...').readAsStringSync()` + `expect(source, contains('...'))`（`readAsStringSync` 出现 52 次）。仅 1 条真分层约束（`:249-256` domain 无 flutter 依赖，且只覆盖 1 文件）。M3 反向边（`platform/replay_utils.dart → ui/app_theme.dart`）就是这种字符串守护的漏网。refactor-report §7（`:164`）自疑"是真守护还是只改了字符串去匹配新代码"。
- **风险**：重命名私有方法/换行风格就红但行为没变；逻辑改了字符串还在会假绿。

#### 🟡 5-5 回放基线不接 WristAnchor/ReadyPoseGate，torso-only；改腕/ready 门控基线不变（盲区非保护）
- **证据**：`domain_self_check_test.dart:163-223` 三基线只喂 torsoY/elbowAngle，不接 wrist/ready 门控。step0 套 `SignalFilter(window:5)`（:164），v3/v4 裸 counter（:185-223）——**不对称易混**。改 wrist 阈值/ready 门控，基线不变。
- **含义**："回放 5/5/3 全绿 ≠ 真机全绿"。基线只守 PushupCounter 计数铁律。

#### 🟡 5-6 playbook 有"改动类型"矩阵但无"文件→测试"速查
- **证据**：`docs/testing-release-playbook.md §1`（:13-31）是改动类型分类表，非文件→测试映射。接手者不知"改 workout_controller 该跑什么"。
- **建议**：补文件→必跑测试映射表，显式标注 WorkoutController/inference/相机 = "自动化测不全，改后必须真机"。

### 正面发现
- **Worker 测试分层健康**：`test/helpers/d1_sqlite.mjs` 是 D1 契约的 SQLite 适配器（mirror D1 的 prepare/bind/first/all/run/batch 到 node:sqlite，batch 用真 BEGIN/COMMIT/ROLLBACK）。逻辑路由用 fake Db 快速跑，SQL/迁移/聚合用真 SQLite（内存，载 schema.sql），有 `beforeNextBatch` 并发钩子。比 Flutter 侧 WorkoutController 测试基建成熟。
- **Worker test 必须先 build 到 `.tmp-test`**（`npm run build:test` → `node --test`），`.tmp-test` 不在 git，**不能只跑 `node --test`，必须 `npm test`**（含 `tsc --noEmit` 类型检查门）。
- CSV 回放夹具现已在 git（refactor-report 曾标的 🔴"干净 checkout 无法复现"已修复）。

### 建议速查表（改各类代码该跑什么）
| 改了什么 | 必跑（最小） | 说明 |
|---|---|---|
| `pushup_domain.dart`（计数/信号铁律） | `domain_self_check_test`、`pushup_pipeline_test`，建议全量 | 地基，风险最高 |
| `lib/product/*`（pipeline/门控/腕锚/存储） | 对应 `*_test.dart` | 常跨 domain |
| `account/leaderboard/workout_sync_controller` | 对应 `*_controller_test.dart` | DI 完整 |
| **`workout_controller.dart`** | `workout_page_test`（仅页面）+ **真机** | **盲区**：无 controller 行为测试，改后必须真机验证 start/stop/switchCamera |
| `lib/ui/pages/*` | 对应 `*_page_test.dart` | widget 测布局/本地化 |
| `lib/inference/*`、`lib/pipeline/*` | 对应 `*_test.dart` + **真机** | NNAPI/isolate 无单测 |
| `workers/membership-api/src/*.ts` | `cd workers/membership-api && npm test` | 改 schema 还要跑 `schema-migration.test`/`*-sql.test` |

---

## 8. 维度 6（P1）：数据模型与持久化契约

> 技术栈：`path_provider`（文件）+ `flutter_secure_storage`（密钥值），无 sqflite/hive/drift。本地↔D1 云端单向同步存在。

### 结论
**上行同步契约（owner-scoped、pending 队列、服务端去重+配额）设计扎实。主要风险集中在"下行/持久化的另一半被忽略"**：云端记录不落盘、本地数据无版本化迁移、注销/多账号无数据隔离与清理。

### 发现清单

#### 🔴 6-1 WorkoutSession 无 schema version，靠"容错读"隐式兼容，改字段语义会静默丢数据
- **证据**：`workout_session_store.dart:25-151`（10 字段，无 version）。兼容靠 `fromJson`(:66-83) 对缺失字段 `?? 默认值`。测试 `workout_session_store_test.dart:39-53` 锁定"老 session → ownerless localOnly"。
- **风险**：只加可选字段能兼容；一旦改字段语义（count 语义变、startedAt 时区约定变、可选变必填），`fromJson` 静默吞错，老数据被悄悄"降级"无告警。
- **建议**：加 `schemaVersion` 常量 + 版本化迁移表 `{1: migrateV0toV1}`，`load()` 解析后统一升级；加"解析未来版本会抛错"测试。

#### 🔴 6-2 claimLegacy 是唯一老数据迁移路径，绑死手动 UI 入口，默认不执行
- **证据**：`claimLegacyForOwner`（`workout_session_store.dart:277-310`）把 ownerless 未同步老记录绑到当前账号。触发方式：`profile_page.dart:433-459` **手动对话框确认**才调用。`syncForCurrentAccount`（`workout_sync_controller.dart:47-56`）只队列**已 owned** 的，不 claim ownerless。
- **风险**：升级到带账号版本后，老用户历史默认不被认领、不上云，必须自己点 Profile→"同步本地历史"。多数用户不会发现，等于静默丢失历史备份。无"迁移完成"持久标记。
- **建议**：登录成功后自动 claimLegacy，至少首页/记录页强提示；加 secure storage 标记防重复弹窗。

#### 🔴 6-3 signOut 不清本地训练数据 + 展示层不按 owner 过滤 → 多账号串号 + 注销后数据残留
- **证据**：`signOut`（`account_controller.dart:137-156`）只 `_sessionStore.clear()` + `revenueCat.logOut()` + `googleSignOut()`，**不碰 workout_sessions.json**。`records_page._totalsByLocalDate`(:531-539) 和 `store.totalsByLocalDate`(:318-325) **不按 owner 过滤**，直接全量求和。
- **后果**：A 登录训练 → signOut → B 登录 → records 页把 A 的训练算进 B 的日历统计；注销后前任数据残留被新账号看到。**隐私泄漏 + 数据串号**。
- **建议**：records/totals 加 owner 过滤参数（含 ownerless 作"本地匿名"独立分组）；signOut 时询问是否清该 owner 本地记录；账号设置加"删除我的账号"入口（GDPR/个保法要求）。

#### 🟡 6-4 单文件全量 JSON 非原子写，崩溃可丢全部历史
- **证据**：`workout_session_store.dart:178` 单文件 `workout_sessions.json`；`_write`(:363-371) `file.writeAsString(..., flush: true)` 直接覆写，无 temp+rename 原子交换、无 .bak。所有变更走"load 全量→改内存→全量重写"（`_serializeMutation`(:351-361) 用 Future 队列串行化，并发测试 :395-463 锁定）。
- **风险**：写入过程中掉电/崩溃 → 文件截断 → 下次 `load()` 的 `jsonDecode`(:189) 抛 FormatException，**整个会话历史不可读**且无恢复路径。训练历史是核心资产。
- **建议**：写临时文件再 rename 覆盖（POSIX/Android rename 原子）；`load()` try/catch 解析失败回退 .bak 或返回空+上报；保留写入前 .bak。

#### 🟡 6-5 云端记录不落盘 + 只拉当前月 → 换设备/翻历史月份数据"消失"
- **证据**：`mergeWorkoutSessions`(:162-173) 把云端会话并入内存**仅用于展示**（`records_page.dart:53`），全仓库无写回 store（grep 确认）。`home_page.dart:181-188` `_cloudSessionsFuture()` 硬编码 `${now.year}-${now.month}`，永远只装当前月。records_page 的 week/month/year 偏移可往历史翻，但云端不参与历史月份合并。
- **后果**：换设备/重装后本地清零，云端历史在 records 只能看当前月，历史月等于消失（仅排行榜聚合还在）。下行 `cloudWorkouts` 响应丢弃 `timezoneOffsetMinutes` 等（`membership_api_client.dart:439-469`），即便落盘也无法再上传。
- **建议**：明确产品意图——若"云端即真相源"需首次登录回拉全部历史并 append；若"本地为主"至少 records 历史月份也调 cloudWorkouts(month=selected)。

#### 🟡 6-6 session id 基于微秒时钟，冲突解决隐式依赖时钟
- **证据**：客户端 session id = `endedAt.microsecondsSinceEpoch.toString()`（`workout_page.dart:346`）。服务端 `UNIQUE(user_id, client_session_id)` 去重（`0002:32`）。本地 merge `putIfAbsent`（:170）local 优先。
- **风险**：时钟回拨可能同 id 覆盖；local 优先 merge 在同 id 字段不一致时无法发现冲突。
- **建议**：id 改 `crypto.randomUUID`/`uuid`（已在依赖树）；merge 加"同 id 字段不一致"告警分支。

#### 🟡 6-7 flutter_secure_storage 跨平台配置缺失，Keystore 损坏无降级
- **证据**：3 文件（`account_session_store.dart:37`/`app_settings_store.dart:12`/`startup_preferences.dart:17`）全用默认 `FlutterSecureStorage()`，未配 `AndroidOptions(resetOnError:)`/`IOSOptions(accessibility:)`。`ugk_account_user` 存了 email/displayName 等画像（写放大：每次 updateProfile 重写整条 JSON）。
- **风险**：Android Keystore 损坏（系统升级后偶发）→ read 抛异常 → 登录态恢复无降级。
- **建议**：统一封装 SecureStorageFactory，显式设 Android `resetOnError: true`；账号画像考虑移普通文件。

#### 🟡 6-8 头像磁盘缓存注销不清
- **证据**：`cached_network_image ^3.4.1`（pubspec）自动把头像缓存到 App 缓存目录，signOut 不调 `DefaultCacheManager().emptyCache()`。注销后前任账号及 leaderboard 用户头像缩略图可能残留。
- **建议**：signOut 时清头像缓存。

#### 🔵 6-9 无数据目录结构文档，README 引用不存在的模块文档
- **证据**：`docs/modules/README.md:17` 引用 `[会话存储 WorkoutSessionStore](./workout-session-store.md)` —— **该文件不存在**。
- **建议**：补 `docs/modules/workout-session-store.md` + 本地数据清单表（路径/key/类型/生命周期/清理时机）。

### 正面发现
- **相机帧/视频默认不落盘**：`WorkoutController` 全程内存处理 YUV→RGB→推理，无 `writeAsBytes` 对相机帧（grep 全仓 0 处）。`RecognitionTraceLog(enabled: kDebugMode)` 仅 debug 写姿势骨架坐标（非原始视频），`maxFiles:10` 滚动删除。符合"相机帧不落盘"隐私承诺。
- **owner 绑定严谨**：`copyWith` 在 owner 不一致时抛 `StateError('Workout owner cannot be replaced')`（:98-102）；所有状态变更 owner-scoped；账号切换有 generation 守卫（`workout_sync_controller._isCurrent:140-144`，双重校验 sessionToken+appUserId，测试 :135-162/:210-246 覆盖 stale 写入丢弃）。
- **同步状态字段完备**：`WorkoutSyncStatus` 四态 localOnly/pending/synced/failed（:11-23）；pending+failed 都纳入待传；`_drain` 单飞+排空合并请求避免循环风暴。

---

## 9. 维度 7（P1）：错误处理与降级总则

> audit L2 只列 3 处空 catch，未给全仓"错误如何分层"总则。

### 结论
代码层**实际存在一套相当成熟的隐式分层约定**（control 层 `rethrow → 外层 _run 映射 errorCode → UI 映 l10n`），但**这套约定从未写成文档，且执行不彻底**：account/leaderboard 三件套很干净，但 workout/test_mode/page 这条线直接把 raw 异常塞进 `_status = '错误：$error'` 绕过 errorCode 体系；**可观测性几乎为零**（无 Crashlytics、release 无日志、33/36 catch 全静默）。

### 全仓 catch 模式（36 处 / 16 文件）
| 类别 | 数量 | 代表 |
|---|---|---|
| 空 catch / 纯吞 | 18 | `app_settings.dart:46/59/68`、`workout_sync_controller.dart:93`、`recognition_trace_log.dart:46/54/68` |
| 转 errorCode（用户可见，经 l10n） | 5 | `account_controller.dart:391/393`、`leaderboard_controller.dart` 经 `_mapError` |
| 转状态码 + raw 字符串塞 UI | 7 | `workout_controller.dart:144/196/459`、`test_mode_page.dart:248/446/545/597`、`workout_page.dart:370` |
| rethrow（含 cleanup 后） | 2 | `pose_estimator.dart:103`、`account_controller.dart:96` |
| 转 domain exception | 1 | `revenuecat_service.dart:74` |
| 完整捕获并降级 | 3 | `startup_preferences.dart:33/41`、`account_session_store.dart:86` |

### 发现清单

#### 🔴 7-1 无可观测性基础设施：release 包无日志/无上报，33/36 catch 全静默
- **证据**：pubspec 无 crashlytics/sentry/firebase_analytics/logger/logging（grep 零命中）。`debugPrint` 仅 7 处全在 `workout_controller.dart` 且全是 session 流程日志（UGK session: start/switch/stop/ready/count/stable），**没有一条在 catch 块里**。catch 里仅 3 处 `_traceEvent`（`workout_controller.dart:150/202/463`）但经 `RecognitionTraceLog(enabled: kDebugMode)`(:51) 门控——**release 不写**。UGK tag（`adb logcat -s flutter | grep UGK`）只覆盖 session 正常流程，**不覆盖任何错误路径**。
- **后果**：线上用户遇 app_settings 写失败、云同步失败、头像上传失败、购买失败，开发者**无任何手段定位**。这不是"增加接手成本"，是"接手后无法运维"。
- **建议**：release 加最小日志/上报通道（哪怕只写本地文件循环覆盖），catch 块至少 debugPrint 错误摘要。

#### 🔴 7-2 错误呈现两套并存、自相矛盾
- **证据**：account/leaderboard 走 errorCode→l10n 且 `leaderboard_controller.dart:462-463` 注释明令"raw exception strings are never rendered to the user"；但 `workout_controller.dart:155/464` 的 `_status = '错误：$error'`、`workout_page.dart:374` 的 `_saveError = '保存失败：$error'`、`test_mode_page.dart:253/551/599` 直接拼 raw `$error` 进 UI（**不经 l10n，英文用户看中文"错误："**）。同一仓库自相矛盾。
- **建议**：workout/test_mode 改走 errorCode 体系；统一错误呈现 helper（`_accountErrorMessage` 和 `_leaderboardErrorMessage` 是两个平行 switch，未抽共享）。

#### 🔴 7-3 无错误处理总则文档
- **证据**：`development-guide.md` 仅泛泛"写测试覆盖异常/边界"（:56,77）；`app-ui-v1.md` 仅 3 条单点规则（:90 启动偏好读取失败不卡死、:137 保存失败留 pending 允许重试、:177 编辑资料失败用持久横幅）；无"错误分层总则"章节。唯一把原则写进代码的是 `leaderboard_controller.dart:462` 注释——但 workout_controller 恰恰违反它。
- **建议**：补 `docs/policies/error-handling.md` 把隐式分层约定（platform 翻译/control 映射/ui 呈现）写成显式总则。

#### 🟡 7-4 云同步无 backoff、无失败上限
- **证据**：`workout_sync_controller.dart:87-100 _drain` 失败即吞，重试纯靠账号切换/冷启动等外部事件触发。无 Timer/退避。弱网下 pending 积压无主动恢复。
- **建议**：加最短重试间隔或失败次数上限后转"需手动重试"。

#### 🟡 7-5 PurchaseFailedException 硬编码中文，绕过 l10n
- **证据**：`revenuecat_service.dart:79` `PurchaseFailedException('购买没有完成，请稍后再试。')`。英文环境显示中文。
- **建议**：改走 errorCode + l10n。

#### 🔵 7-6 errorCode 不进 ARB 文件（设计合理但易误解）
- errorCode 字符串（`account_unexpected_error` 等）是 control 层稳定 key，通过 l10n getter 间接映射，grep ARB 零命中——设计合理但易让接手者误以为"错误文案没本地化"。

#### 🔵 7-7 18 处空 catch 无注释说明为何吞
- 部分有注释（recognition_trace_log/workout_sync），但 `app_settings.dart:59/68`、`onboarding_page.dart:49`、profile 多处纯空。

### audit L2 三处复核（行号 drift）
| audit 记录 | 实际位置 | 模式 | 评价 |
|---|---|---|---|
| `app_settings.dart:46,59,68` | **仍 :46/59/68** | 读失败留 system 默认；写失败已 setState 内存值，吞 | 降级合理 |
| `workout_page.dart:340-344` | **实际 :360-365** | `queueAfterLocalSave` 失败吞，注释"Cloud sync must not block local workout" | 降级合理 |
| `workout_sync_controller.dart:91-95` | **实际 :93-95** | `_syncOnce()` 失败吞，注释"later trigger retries persisted pending" | 降级合理 |

**三处降级都对。audit 的问题"缺诊断可观测性"成立——但这是全仓 36 catch 的通病，audit 把它框在 3 处低估了范围。**

### 隐式分层约定还原（供接手者参考，未被文档化但代码大体遵守）
| 层 | 应做 | 遵守范例 | 违反 |
|---|---|---|---|
| platform | 翻译底层异常为 domain exception；或降级留默认，绝不抛 UI 字符串 | `membership_api_client._parseJson:418`、`recognition_trace_log`（吞+注释） | `revenuecat_service.dart:79` 硬编码中文 |
| control | 内层 catch 按需 rethrow，最外层 `_run` 统一映射 errorCode；raw 异常绝不进 UI | `account_controller._run:379`、`leaderboard_controller._run:449` | `workout_controller.dart:155/464` |
| ui | errorCode → l10n getter；持久错误用横幅，瞬时反馈用 snackbar | `profile_page._accountErrorMessage:1689`、`leaderboard_page._leaderboardErrorMessage:16` | `workout_page.dart:374`、`test_mode_page.dart` 拼 raw |
| product/inference | 资源 cleanup 后 rethrow | `pose_estimator.dart:103`、`workout_session_store.dart:356` | （无） |

---

## 10. 维度 8（P2）：依赖与版本治理

### 结论
**锁文件入 git + Gradle 插件精确锁定 + Worker 依赖最小化（仅 jose）是接手友好区。最大空白是升级流程和漏洞治理几乎完全缺失**（无 Renovate/Dependabot、无 `pub audit`/`npm audit` 记录、无升级策略文档），且 `intl: any` 是明显的版本约束疏漏。

### 发现清单

#### 🔴 8-1 `intl: any` 无任何版本约束
- **证据**：`pubspec.yaml:37` `intl: any`（其他依赖全用 `^`，唯独 intl 用 any）。lock 实际 `0.20.2`。
- **风险**：`any` 是最弱约束，`pub upgrade` 无差别拉最新主版本。intl 是 flutter_localizations 强依赖，主版本升级破坏 ARB/格式化，编译期才暴露。
- **建议**：改 `intl: ^0.20.2`（对齐 lock）。

#### 🔴 8-2 完全没有自动化依赖升级机制（无 Renovate/Dependabot）
- **证据**：无 `.github/`、无 `renovate.json`/`dependabot.yml`。所有 `^` caret 范围 patch/minor 会在 upgrade 时漂移，但谁触发/多久一次/怎么验未定义。
- **风险**：对支付（purchases_flutter）和账号（google_sign_in）这类敏感依赖，无声漂移高危。

#### 🔴 8-3 无任何安全/漏洞扫描记录
- **证据**：docs+README+AGENTS 全量搜 `pub audit`/`flutter audit`/`CVE`/`vulnerability`/`pub outdated` 零命中。高风险面均无扫描留痕：`tflite_flutter` 0.12.1（第三方 native，TF lite C++ 组件，CVE 高发）、`purchases_flutter` 10.4.1（支付凭据）、`google_sign_in` 7.2.0（OAuth）、`ffmpeg_kit_flutter_new` 4.3.2（FFmpeg native CVE 频发）、worker `jose` 6.2.3（JWT 签名验证）。
- **建议**：建 `flutter pub audit` + `npm audit`（worker）+ `flutter pub outdated` 定期 SOP，结果入 docs。

#### 🟡 8-4 锁文件已偏离 pubspec 声明（无声升级证据）
- **证据**：camera `^0.11.0+2`→lock `0.11.2+1`；path_provider `^2.1.4`→`2.1.5`；tflite_flutter `^0.12.0`→`0.12.1`。漂移本身不一定有害，但无任何 commit/PR/文档记录何时升/为何升/验了什么。对有回放基线精度要求的项目，tflite patch 漂移理应有验证留痕。

#### 🟡 8-5 targetSdk 未显式锁定（依赖 Flutter SDK）
- **证据**：`app/build.gradle.kts:48` `targetSdk = flutter.targetSdkVersion`（非字面量）；compileSdk=36/minSdk=24/ndkVersion 均显式锁定。targetSdk 跟随本机 Flutter 浮动，影响 Play 策略合规判定。
- **建议**：显式 `targetSdk = 36`。

#### 🟡 8-6 `kotlin.incremental=false` 与 `enableJetifier=true` 的隐性成本
- **证据**：`gradle.properties:1,3`。两项都是"绕过历史问题全局关优化"信号。Jetifier 很可能已可关（依赖应已 AndroidX 化）。
- **建议**：验证能否开 `kotlin.incremental=true`、关 Jetifier，可显著降构建时间。

#### 🟡 8-7 锁文件指向中国镜像源（供应链可复现性）
- **证据**：`pubspec.lock` 多包 `url: "https://pub.flutter-io.cn"`。对海外 CI/接手者造成可复现性问题。锁文件含 sha256 部分缓解。
- **建议**：docs 记录镜像前提，CI 显式配 `PUB_HOSTED_URL`/`FLUTTER_STORAGE_BASE_URL`。

#### 🔵 8-8 无升级策略文档
- **建议**：新增 `docs/policies/dependency-upgrade-policy.md`（升级频率、`pub upgrade` vs `--major-versions` 边界、必跑验证、敏感依赖单独评审）。

### 正面发现
- **锁文件全入 git**：pubspec.lock、worker package-lock.json、gradle-wrapper.properties 均跟踪——可复现构建基础在。
- **Gradle 插件精确锁定**：AGP 8.7.3、Kotlin 2.1.0、ndkVersion 27.0.12077973、gradle-8.12-all 全字面量。
- **Worker 运行依赖最小化**：仅 jose 一个，攻击面小。
- **tflite 模型权重入仓**：assets/models/ 已跟踪。
- **SDK 约束合理**：Dart `^3.8.0` / Flutter `>=3.32.0`。

---

## 11. 维度 9（P2）：l10n / 国际化可维护性

### 结论
**ARB 基础设施健全**（zh/en 各 235 key 完全对齐、生成配置正确、生成文件入 git）。audit M2（中文字符串状态码）**仍成立**：control 层 16 处中文状态码 + UI 字符串 switch 映射，且**无测试守护映射完整性**，反而 `architecture_contract_test` 把字符串契约钉死。`membership_status.dart:34` 的 `'训练者'` fallback 是现行漏翻译点。

### 发现清单

#### 🟡 9-1 audit M2 仍成立：control 层 16 处中文状态码 + UI 字符串 switch 映射
- **证据**：`workout_controller.dart` 16 处中文 `_status` 赋值（:69 `'加载中'`、:115 `'加载模型'`、:125 `'启动相机'`、:142/194 `'请按提示摆放手机并保持姿势'`、:155/464 `'错误：$error'`、:174 `'切换相机'`、:224 `'保存中'`、:303/332 `'请保持俯卧撑姿势并稳定入镜'`、:328 `'已准备好，请开始训练'`、:347 `'请保持俯卧撑姿势并完整入镜'`、:393 `'训练中'`）。UI 映射 `workout_page.dart:17-36 _localizedWorkoutStatus`（10 字面量精确匹配 + 3 动态前缀分支 + 兜底 `_ => l10n.workoutStatusError`）。
- **风险**：改 control 任一中文字面量（哪怕加空格），switch 静默落兜底，英文用户全看到 "发生错误，请重试。"，测试不会失败。这是 audit 说的"脆弱字符串契约"。

#### 🟡 9-2 无测试守护状态码→l10n 映射完整性，架构测试反而把字符串契约钉死
- **证据**：`workout_page_test.dart` 只用 fake controller 固定 `'训练中'`(:360,386)，从不枚举所有真实状态。`architecture_contract_test.dart:376` 断言 `expect(body, contains("_status = '保存中'"))`——**把脆弱契约钉死**，任何改成 enum 的修复会先撞这个测试。无测试遍历 controller 所有可能 status 断言不落兜底。
- **建议**：加测试遍历 controller 所有可能 status 字面量断言不落 `_` 兜底；或将 `_status` 改 `enum WorkoutStatus`，switch 表达式编译期强制穷尽。

#### 🟡 9-3 `membership_status.dart:34` 的 `'训练者'` fallback 是现行漏翻译点
- **证据**：`leaderboard_models.dart:34` `(json['displayName'] as String?) ?? '训练者'`。后端缺 displayName 时，**英文用户也会看到"训练者"**。audit M2 点名的独立漏翻译点，仍在。
- **建议**：fallback 改成非中文占位或空串由 UI 层 l10n 处理。

#### 🟡 9-4 新增文案步骤文档存在但极简，实操流程散落在 plan 文件
- **证据**：`app-ui-v1.md §7`(:230-242) 4 条维护规则，但**没写具体步骤**（改 zh/en ARB 两边 → `flutter gen-l10n` → 用 getter）。实操只散落在各 plan（如 `plans/2026-07-14-membership-pricing.md:103` `Run: flutter gen-l10n`）。新人要翻历史 plan 才能拼出步骤。
- **注**：§7 规则 `:242`"不在 domain/product/control 层引用 l10n"已被 workout_controller 违反（见 9-1），文档与现实不一致。

#### 🔵 9-5 platform 层硬编码中文 message（潜在风险，非现行故障）
- `revenuecat_service.dart:79` `PurchaseFailedException('购买没有完成，请稍后再试。')`——当前 account_controller 捕获后映射 errorCode 不直接显示，但一旦某处 `e.toString()` 透传就漏出。
- `replay_utils.dart:36-37` `FileSystemException('no replay video', '俯卧撑.mp4', OSError('请先选择一个视频文件'))`——测试模式路径，app-ui-v1 明确测试模式不纳入 V1 l10n。
- domain 层 `pushup_domain.dart` 干净，无中文残留。

#### 🔵 9-6 测试层用中文 ARB 值断言，强化"以中文为锚"
- `leaderboard_page_test.dart` 多处 `find.text('中文文案')`(:52,257,260,284,329,408,863,1255)。改中文文案会让测试失败但**不保护英文侧**。

### 正面发现
- **ARB key 两侧完全对齐**：zh/en 各 235 value key，无遗漏（脚本对比确认）。
- **生成配置健全**：`l10n.yaml` arb-dir/template-arb-file/output-class/synthetic-package:false（生成文件落盘入 git）/preferred-supported-locales:[zh,en]。
- **第三语言可扩展**：复制 ARB + gen-l10n 自动生成；`main.dart:152-154` 用动态 delegates/supportedLocales。语音固定中文是已记录设计取舍。
- **RTL 未考虑**（zh/en 均 LTR，加 ja/ko 无影响；加阿/希伯来需额外布局）——当前无影响。

---

## 12. 维度 10（P2）：CI/CD 与发布流水线

### 结论
**项目零 CI，全部门禁靠手工。** 但发布文档质量在同类规模项目里属上乘——台账详尽、措辞严谨区分证据强度、AAB SOP 完整 step-by-step、versionCode 严格递增。主要弱点是完全没自动化兜底，加 Flutter 版本未 pin、git tag 与发版脱节、官网测试命令未文档化几个小缺口。**好消息：flutter test 可在 Linux CI 跑**（测试不碰 tflite/camera 原生）。

### 发现清单

#### 🔵 10-1 零 CI，全部门禁靠手工
- **证据**：无 `.github/`/`.gitlab-ci.yml`/`.circleci/`/bitrise.yml/Jenkinsfile。无 pre-commit/husky/lefthook。`AGENTS.md:44-49` 把验证列为手工步骤。
- **影响**：当前不阻塞（项目纪律强），但任何一次忘记跑 test/回放基线，或新人漏跑 worker 测试，不会被任何系统拦住。

#### 🟢 10-2（正面/好消息）flutter test 可在 Linux CI 跑
- **证据**：`architecture_contract_test.dart:249-256` 源码静态断言强制 `pushup_domain.dart` 不含 camera/tflite_flutter/flutter/dart:io。全量 grep test/ 对 tflite_flutter/package:camera **零命中**。测试通过纯 dart 的 PushupCounter/SignalFilter 回放 csv，不需 Android 模拟器/tflite 模型/相机硬件。Widget 测试用 flutter_test（自带 Skia）。**回放基线 5/5/3 完全可在 CI 复现。**
- **含义**：引入最小 CI（analyze + test + 回放 + worker test + website test）零额外脚本成本，全 Linux 可跑。**签名/AAB 构建必须留本机人工**（密钥不在仓库，正确设计）。

#### 🟡 10-3 Flutter SDK 未 pin 版本
- **证据**：无 `.fvmrc`/`.tool-versions`/`ci.yaml`。`.metadata:8-9` 仅信息性（channel:stable, revision fcf2c11572）。`pubspec.yaml:7` 只约束 Dart SDK `^3.8.0`。CI 必须显式指定 Flutter 版本，否则不同时间跑结果漂移。

#### 🟡 10-4 官网测试无 package.json、无文档化运行命令
- **证据**：`website/` 无 package.json；`website/tests/website.test.mjs` 用 node:test（44 个测试），靠 `node --test` 跑。`release-configuration.md:491` 只记"网站测试 44/44"结果，`website/README.md` 无 test 说明。新 agent/CI 不知怎么跑这块。

#### 🟡 10-5 git tag 与发布版本完全脱节
- **证据**：`git tag -l` 仅 4 个，全是重构期算法基线（v0.4-reproducible 等）。**没有任何已发布 Play 版本（0.3.3→0.3.8）有对应 tag**。发布产物靠 release-configuration §6.3 逐版本记的"源提交 SHA + AAB SHA-256"定位。`git checkout <tag>` 无法取回任何发布版本。
- **建议**：发版打 `release/0.3.8+11` 之类 tag。

#### 🟡 10-6 回滚的 Play Console staged rollout 操作未文档化
- **证据**：`release-configuration.md:554,593,630,607` 文档化了 App/Worker/D1 回滚方向（新 App 发布后不单独回滚 Worker；回滚 App 到旧版安全；UGC 回滚先停 App 入口再保 D1 schema；会员对账回滚靠回滚 App）。但**无 Play Console halt/pause rollout 操作指引**。当前仅 Alpha 封闭测试（未到生产 staged rollout），尚非阻塞，生产发布前必须补。

#### 🟡 10-7 回滚依据单点存于本机私密台账
- **证据**：`release-configuration.md:554` "回滚依据只记录在本机私密台账"；`AGENTS.md:92-96` 该本机备份仓库"禁止配置 remote 或推送"——单点故障。新 agent 接手若拿不到该文件，不知每版本可回滚到哪个旧 versionCode。

### 正面发现（维度 10 的亮点）
- **versionCode 严格单调递增**：8 个 `build: prepare candidate` 提交 versionCode 严格 +1（0.3.3+4 → 0.3.8+11），无跳号/复用。规则文档化（`release-configuration.md:503`）。
- **AAB SOP 完整 step-by-step**：§6.4（:495-557）4 小节：打包前检查 7 步（含 versionCode 校验、key.properties 四字段存在性、validateMembershipConfig fail-fast、analyze/test/npm test）、构建固定命令、产物必检 7 步（jarsigner -verify、keytool SHA-1、包名/versionName/versionCode/minSdk/targetSdk/release 不可调试、禁止权限 READ_MEDIA_IMAGES/READ_MEDIA_VIDEO/AD_ID、AAB 大小+SHA-256）、记录与上传两层台账。
- **文档与 git log 高度对齐**：d9533fd alpha 送审 ↔ §6.3 记录；24e5eda 内部测试 ↔ 0.3.8-internal-3；093dbda verified AAB ↔ SHA-256 2E1718DE。文档严谨区分证据强度（"USER REPORTED SMOKE PASS...未提供逐项清单，不能扩写为真实回归已通过"）。
- **内部测试→Alpha 严格复用同一 AAB**：0.3.8(11) "复用同一 App Bundle 创建 0.3.8-closed-1，发布比例 100%，未重新构建"。

---

## 13. 维度 11（P2）：权限与隐私合规

> 四篇审计均未提权限与隐私。audit 安全维度只查凭证不查权限。

### 结论
**整体合规姿态显著优于同类健身 App**（无广告 SDK、无设备 ID、无位置、相机帧纯端侧、权限极简）。但存在 **1 项阻塞级隐私泄露**（signOut 不清本地训练数据，跨账号可见——维度 6 已发现，此处从合规角度升级）和 3 项需政策闭环的对齐缺口。

### 发现清单

#### 🔴 11-1 signOut 不清本地训练数据 —— 跨账号 PII 泄漏（合规层面）
- **证据**：`account_controller.dart:137-156` signOut 仅 `_sessionStore.clear()` + revenueCat.logOut()，**不碰 workout_sessions.json**。records 页 totals 不按 owner 过滤（维度 6 D6-4.3 已详述）。
- **合规升级理由**：不只是 UX bug，是**账号切换时前用户运动行为数据对新用户可见**，触发 GDPR/个保法"未授权的个人信息披露"。若新用户是未成年人，叠加 COPPA 顾虑。
- **建议**：signOut 清该 owner 本地记录，或 records/totals 按 owner 过滤。

#### 🟡 11-2 无用户自助删除账号 API，依赖人工 30 天 SLA
- **证据**：Worker 路由（`index.ts:45-134`）**无 DELETE /me 或 /account**，仅 DELETE /me/avatar。账号删除是纯人工流程（用户点外链→邮件→运营手工）。隐私政策承诺 30 天（`release-configuration.md:739`），但无代码级 SLA。`deleteAllAvatarObjects`（avatar.ts:283-315）存在说明删除路径已部分实现，**未暴露为用户可触发 API**。
- **建议**：增 `POST /me/delete`（软删除+异步清理）。GDPR/CCPA 要求删除权，人工流程在量上来后会违约。

#### 🟡 11-3 webhook_events.payload_json 永久留存，无 TTL/清理
- **证据**：`schema.sql:62-71` `webhook_events` 存 `payload_json TEXT NOT NULL`（完整 RevenueCat webhook 原文，含购买事件+用户标识）。grep `DELETE FROM webhook`/`cleanup`/`purge`/`retention`/`TTL` 全 Worker 0 命中。
- **建议**：加定时清理（保留 90 天后匿名化 payload，仅留 event_id/type）。

#### 🟡 11-4 无儿童/年龄门槛（COPPA 轻度风险）
- **证据**：grep `Child`/`COPPA`/`未成年`/`age` 全 lib/workers/docs/policies 0 命中。App 收集 Google 账号+头像 UGC+训练数据，未声明"仅限 13 岁以上"，无 Play 目标受众声明证据。
- **建议**：政策与 Play 分级明确目标年龄。

#### 🟡 11-5 隐私政策声称"读取视频权限"但 manifest 未声明/禁止
- **证据**：隐私政策正文提到"读取视频"权限，但 main AndroidManifest **不含 READ_MEDIA_VIDEO**（§6.4.3 :541 明确禁止）。`test_mode_page.dart:260` 用 FilePicker 走系统选择器**无需 App 申请存储权限**。App 实现比政策更严（好事），但 Play Data Safety 与政策文本偏差，Play 审核可能追问。

#### 🟡 11-6 Play Data Safety 填报无台账证据
- **证据**：grep `data safety`/`数据安全` 0 命中。仅 user-content-policy.md:52 提"同步复核 Play Data safety"，无填报台账/截图。
- **建议**：release-configuration 增 Data Safety 填报清单（与权限清单并列）。

#### 🔵 11-7 debug trace 含姿势坐标，隐私政策未提及
- **证据**：`workout_controller.dart:51` `RecognitionTraceLog(enabled: kDebugMode)` 仅 debug。写入逐帧 17 关键点 x/y/conf + 时间戳（:397-461），较敏感生物特征。release 不启用（隐私角度可接受），但政策未提及"debug 构建可能本机记录骨架坐标"。
- **建议**：政策补一句"调试版本可能在本机临时记录骨架坐标用于诊断，不离开设备"。

#### 🔵 11-8 release 配置未校验 baseUrl 为 https
- **证据**：`membership_config.dart:28-45` validateMembershipConfig 确保三项配置齐全+RevenueCat key 非 test，但**未校验 baseUrl scheme 为 https**。
- **建议**：加 `if (!Uri.parse(membershipApiBaseUrl).isHttps)` 防御。

### 正面发现（合规亮点，同类 App 标杆）
- **权限极简**：仅 INTERNET/CAMERA/BILLING，主动 `tools:node="remove"` 旧存储权限（READ/WRITE_EXTERNAL_STORAGE），逐版本核验不含 READ_MEDIA_*/AD_ID。
- **零广告 SDK、零分析 SDK、零设备指纹、零位置**（pubspec 无 device_info_plus/geolocator/firebase_analytics/crashlytics/任何广告）。
- **相机帧纯端侧**：不落盘、不上传；关键点纯本地（WorkoutSyncRequest 只含次数/时间/时区，不含姿势坐标）。
- **默认 HTTPS**：targetSdk 35 下默认 `usesCleartextTraffic=false`，全 App 强制 HTTPS。Worker 走 workers.dev 强制 HTTPS。Webhook HMAC 验签。
- **头像 R2 私有 bucket + 随机对象键（crypto.randomUUID）+ nosniff + 状态校验**。
- **隐私政策已部署上线**（pushupai-privacy.pages.dev），含账号删除入口与 30 天时限。
- **UGC 头像策略文档完整**（举报/审核/删除/申诉/版本常量）。

---

## 14. 维度 12（P2）：可观测性与线上排障

> 维度 7 已确认"无 Crashlytics/release 无日志/33-36 catch 全静默"。本维度聚焦"开发者拿到线上反馈后能不能定位问题"。

### 结论
可观测性**只覆盖"debug 包下的训练计数排障"这一条窄路径，且做得相当扎实**（trace 字段完整、文档准确、导出命令给齐）。但作为线上产品存在三个结构性缺口：**release 包完全黑盒、商业链路全程无日志、无排障 SOP 文档**。

### 发现清单

#### 🔴 12-1 release 包零可观测：debugPrint 被 Flutter 自动抑制，trace 被 kDebugMode 门控，无 Crashlytics
- **证据**：`workout_controller.dart:51` `RecognitionTraceLog(enabled: kDebugMode)`；7 处 debugPrint 全在 workout_controller。`main.dart` 无 `FlutterError.onError`/`runZonedGuarded`/`PlatformDispatcher.instance.onError`（grep 确认）。pubspec 无 crash SDK。
- **后果**：线上 release 用户遇任何问题，开发者只能靠用户口述 + 自己装 debug 包复现。对偶发/设备相关/账号相关问题几乎无法定位。**这是维度 12 的根本性缺口。**

#### 🔴 12-2 商业链路（购买/OAuth/同步/排行榜）全程无日志
- **证据**：UGK 日志只覆盖训练计数链。`revenuecat_service.dart:74-79` 购买失败只 throw 不打日志；`google_auth_service.dart` 无 debugPrint；`workout_sync_controller.dart:93` `catch (_) {}` 静默；`membership_api_client.dart:273-277/304-308/329-333/356-360` 把格式错误全泛化成 "Invalid ... response"（排障拿不到原始字段名）。
- **后果**：购买失败、登录失败、同步失败这三个最易触发用户投诉的场景，在 logcat 和 trace 里都查不到。

#### 🔴 12-3 无全局错误兜底，release 崩溃无栈
- **证据**：`main.dart` 只 `WidgetsFlutterBinding.ensureInitialized()` + `validateMembershipConfig()` + `runApp`，无 FlutterError.onError/runZonedGuarded。任意未 catch 异常/Widget build 异常走默认红色 ErrorWidget，release 静默崩溃，本地不落盘、不上报、无栈。

#### 🟡 12-4 常见故障无排障 SOP 文档
- **证据**：grep `购买失败`/`登录失败`/`同步失败`/`相机黑屏`/`计数不准`/`troubleshoot`/`SOP`/`runbook` 全 docs 0 命中。唯一排障入口是 AGENTS.md:65-71 一行 adb 命令 + workout-controller.md:75-101 trace 导出命令。仓库最接近排障 case study 的是 `pushup-algorithm-remediation-2026-07-14.md:77-85`"疑似误计先抓 Debug trace"，但未抽成通用 SOP。
- **建议**：写覆盖 5 类常见故障（计数不准/登录失败/同步失败/相机黑屏/购买失败）的排障 SOP。

#### 🟡 12-5 trace 用户侧无提取入口
- **证据**：grep `recognition_traces`/`Share.`/`share_plus` 在 lib/ui 0 命中。即使装 debug 包，**无 App 内 UI 一键导出 trace**，必须开发者 USB 连真机跑 `adb shell run-as ... cat`。对内部测试还行，对 Alpha/正式用户不可行。

#### 🟡 12-6 UGK 日志无级别、无结构化、无采样
- **证据**：纯文本 key=value（`UGK ready: calibrated=true count=0 lwY=320 ...`），无 info/warn/error 区分，无 JSON。ready 标定成功和 startup_error/frame_error 这种 catch 路径完全没有 UGK 日志输出（只进 trace 文件，logcat 看不到）。release 下不输出所以实际影响小，但"UGK 诊断日志"这个名字对线上用户不成立。

#### 🔵 12-7 RecognitionTraceLog _removeOldFiles 按文件名字典序非 mtime
- **证据**：`recognition_trace_log.dart:79` 按文件名字典序排序删最旧。目前靠"文件名=UTC 数字时间戳"的隐式约定保持正确，改文件名格式会静默破坏滚动。

### 排障可观测性矩阵（按故障域）
| 故障域 | UGK 日志 | Trace | Crash 上报 | 排障 SOP | 严重度 |
|---|---|---|---|---|---|
| 计数偏多/偏少/误计 | 有(count/ready/stable) | 有(完整骨架) | — | 有先例无SOP | 🟡 debug 可查，release 拿不到现场 |
| 相机启动失败/黑屏 | **无**(startup_error 只进 trace) | 仅 debug | 无 | 无 | 🔴 release 黑屏无线索 |
| Google 登录失败 | **无** | 无 | 无 | 无 | 🔴 全靠用户描述 |
| RevenueCat 购买失败 | **无**(只 throw) | 无 | 无 | 无 | 🔴 最赚钱路径零可观测 |
| 云同步失败/pending 堆积 | **无**(catch(_){}静默) | 无 | 无 | 无 | 🔴 拿不到原始字段名 |
| 排行榜拉取/加入失败 | **无** | 无 | 无 | 无 | 🔴 |
| 训练保存本地失败 | 部分(UI 显示但不落日志) | 无 | 无 | 无 | 🟡 |
| App 崩溃/ANR | — | — | **无 Crashlytics，无 onError** | 无 Play Vitals 文档 | 🔴 release 崩溃无栈 |

### 正面发现
- **RecognitionTraceLog 信息完整度高**：每帧 17 关键点 + 门控状态 + counter 状态 + signals，是仓库唯一能"事后精确复现一次训练"的可观测性资产，对计数争议排障极有价值。
- **UGK 事件清单文档准确**：AGENTS.md:71 与 workout-controller.md:78-82 的清单与代码 7 处 debugPrint 一致。
- **performance_report/app_keypoints.csv 仅测试模式生成**，训练主链路不写，不用于线上排障（设计如此）。

---

## 15. 维度 13（P2）：性能预算与基准

### 结论
项目**存在性能采集与一个硬门槛字段（`pass`），但不存在成文性能预算、不存在回归基线、不存在自动化性能门禁**。唯一"目标值"是 `performance_report.dart:45` 的一行魔法字面量（`fps>=10 && meanE2e<250 && memoryPeakMb<=600`），无文档背书、无 CI 执行。`pass` 字段语义被 refactor-report 点名"混淆"（既像性能通过又像验收通过），未修复。所谓"20-28 FPS 真机实测"只作为单行代码注释存在。

### 发现清单

#### 🔴 13-1 实时推理 App 无任何性能回归门禁
- **证据**：无 `.github/`/CI workflow。`test/performance_meter_test.dart`/`performance_report_test.dart` 只做纯算术单测（用 2 个手工 sample 验证汇总公式、验证 pass 在 fps=2/memory=601 时 false），**不真起 tflite/不跑相机/不测真机延迟**。"性能基准"纯手动：打开 TestModePage LiveCameraTab 肉眼看 PerfPanel 实时数字，停止后看落盘 `live_performance_report.json`。
- **后果**：推理任何一处改动（preprocess/delegate/isolate/模型替换）都无法被自动化发现性能回归。接手者改 pose_estimator 或换模型时无安全网。**对一个实时相机推理 App 是阻塞级。**

#### 🟡 13-2 `fps` 字段口径歧义
- **证据**：`performance_report.dart:30` `fps = frames*1000/sum(e2eMs)`（端到端推理吞吐）；`performance_meter.dart:25,71` 另有 `fps`+`uiFps`（UI rebuild 帧率）双口径。两者不交叉核对，报告里不出现 uiFps。读者易把"推理吞吐"误当"UI 帧率"或"相机帧率"。

#### 🟡 13-3 `pass` 字段语义混淆且未修复
- **证据**：`performance_report.dart:45` `'pass': fps>=10 && meanE2e<250 && memoryPeakMb<=600`。混淆点：(1) 同份 JSON 里 `final_count` 与 `pass` 并列，UI 文案说"验收计数应为 5"，模拟器典型结果 final_count=5(计数对)+pass=false(性能不达标)，读者极易把 pass 误解为"计数验收通过"；(2) `buildDelegateComparison`(:49-71) 复用同名 'pass' 键但语义是"三 delegate 全出现且各自 pass"；(3) **pass 只写入落盘 JSON，不上传、不进 CI 断言、不在 UI 显示**——形似门禁实为人工读 JSON。refactor-report:258 建议拆 `count_pass`/`performance_pass`，**未落实**。

#### 🟡 13-4 内存门槛口径错位
- **证据**：`replay_utils.dart:113` `currentRssMb() = ProcessInfo.currentRss/1024/1024`（整个 Flutter 进程 RSS，非推理 isolate 专属）。门槛 `memoryPeakMb<=600` 判进程 RSS，但目标语义应是推理 isolate 内存。推理跑在 IsolateInterpreter（`pose_estimator.dart:100-102`），主进程 RSS 与 isolate 占用量级差异大，600MB 对进程 RSS 偏松、对 isolate 无意义。

#### 🟡 13-5 性能预算零文档化
- **证据**：`10/250/600` 三个魔法字面量全库无定义/无注释/无文档（grep 仅命中 :45 一行）。`recognition.md` grep 无 FPS/latency/内存预算。无 `performance*.md`/`benchmark*.md`。唯一性能数据是 `test_mode_page.dart:336` 注释"默认 NNAPI: 真机实测 20-28 FPS, 明显优于 CPU(14-16)/GPU(16-18)"——无机型/Android 版本/温度上下文。

#### 🔵 13-6 NNAPI delegate 失败静默无 fallback 告警
- **证据**：`pose_estimator.dart:171-175` `_delegateFor` 对 nnapi 返回 null delegate（仅靠 useNnApiForAndroid），模拟器无 NNAPI 时默默回退 CPU 慢推理不报错（维度 1-5 已记）。

#### 🔵 13-7 目标值不可配置、无 per-device/per-delegate 区分、p95 只采集不参与门槛
- `performance_report.dart:45` 三字面量硬编码；p95_e2e_ms 采集但不进 pass 判断。

### 正面发现
- **perf 模块职责清晰**：`lib/perf/`（运行时实时采集，30 帧滚动）+ `lib/report/`（停止后落盘汇总），仅被 TestModePage 消费，训练主链路零依赖（架构正确，不污染生产路径）。
- **模型权重小**：`movenet_singlepose_lightning_int8_4.tflite` ≈ 2.76MB（int8 量化）。
- **recognition-trace-and-latency plan 的"latency"指计数管线平滑层延迟**（去重复移动平均），与推理延迟预算无关——命名易混但内容自洽。

---

## 复核状态声明

- **本报告已完成全部 13 维度 + audit M1-M3/L1-L3 复核**（维度 1-3 批 1 / 4-7 批 2 / 8-10 批 3 / 11-13 批 4）。每批的关键断言均由主会话独立源码验证，非仅采信子 agent。
- 所有 git 跟踪断言基于本会话实际 `git ls-files`/`git rev-list`/`git tag` 输出。
- Flutter 测试数 407 = 本会话实跑 `flutter test` 末行 `+407 ... All tests passed!`。
- Worker 测试数 138 = 静态计数（`npm test` 需 `.tmp-test` 构建步骤，未实跑；与 release-config 自述吻合）。
- audit M1-M3/L1-L3 行号漂移已逐一重新定位确认（M1 `:160-205`、M2 `:69`+`leaderboard_models.dart:34`、M3 `:20`、L1 `leaderboard_models.dart:105,117,129-145,167`）。
- 独立验证的关键断言：signOut 不清 workout_sessions（account_controller.dart:137-156）、workout raw error 进 UI（:155）、无 crash SDK（pubspec grep）、无全局 onError（main.dart grep）、AndroidManifest 仅 4 权限+2 remove、`intl: any`（pubspec.yaml:37）、ARB zh/en 各 235 key 对齐、`pass` 魔法阈值（performance_report.dart:45）、ACCESS_TEAM_DOMAIN 未进 §7 主清单。
- 本会话**未修改任何产品代码、未 push、未部署、未动 36 个未跟踪文件**。工作树唯一未跟踪文件是本报告与执行计划（均在 `docs/reviews/`）。
- **本 review 是只读分析**，所有"建议"均需后续单独授权处理，本次不执行任何代码/文档变更。

---

## 附录：交付物清单（给审核团队）

1. **主报告**：本文件 `docs/reviews/2026-07-16-full-review-report.md`——13 维度 + audit 复核，每条发现含维度/严重度/证据（file:line）/复核状态/建议。
2. **接手者索引**：见 §5（最先该读的 5 份文档 + 最先该跑的命令 + 最该小心的 3 个高风险区）+ 执行摘要的 🔴 阻塞项汇总表。
3. **失真文档更新清单**：散见于维度 2（§2-1 README 89→407、§2-2 AGENTS 约30→296、§2-3/2-4 audit 横幅、§2-7 handoff 死链）+ 维度 3（§3-1 plans 索引、§3-2 checkbox 回填、§3-3 identity-choice 被废弃回写）+ 维度 8（§8-1 intl:any）。更新动作本身需单独授权，本 review 只产出"该改什么"清单。
4. **执行计划**：`docs/reviews/2026-07-16-full-review-plan.md`（任务定义）。

### 审核建议优先级排序（非本次执行，仅供决策）
- **P0（隐私/运维阻塞，建议最先处理）**：11-1 signOut 数据清除 + owner 过滤；12-1/12-3 release 可观测（Crashlytics 或安全本地日志 + 全局 onError）；12-2 商业链路加 UGK 日志。
- **P0（文档失真，低风险高收益）**：2-1 README 测试数、2-2 AGENTS 提交数、3-1 plans 索引。
- **P1（接手质量）**：5-1/5-2 WorkoutController 加 DI + 竞态测试；6-1 WorkoutSession schema version；4-1 Dart↔Worker 契约单一事实源；7-3 错误处理总则文档；M1/M2/M3 audit 项。
- **P2（长期治理）**：10-1 引入最小 CI（analyze+test+回放+worker，全 Linux 可跑）；8-2 依赖升级 SOP + 漏洞扫描；13-1 性能回归门禁；11-2 删除账号 API。
