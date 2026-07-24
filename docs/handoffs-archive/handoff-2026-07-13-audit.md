# 交接说明：项目架构审计（2026-07-13）

> 给接手的 AI agent。本会话任务是**只读架构审计**，不是开发新功能。
> 先读完本文件 + 仓库根 `AGENTS.md`，再开始。

## 任务性质

**这是一次"找问题"的审计，不是"改问题"的会话。** 你要产出一份**问题清单报告**，而不是直接修改代码。

## 审计范围

审计基准：main `1531c37`（docs: record leaderboard identity device acceptance）
审计 worktree：`E:/AII/ugk-post-audit`，分支 `chore/audit-2026-07-13`

**审计对象 = main 当前完整状态**，重点关注最近 38 个提交（`e056c26..1531c37`）引入的问题，但不限于此——如果发现历史遗留问题也要记录。

最近 38 个提交的功能域：
- 排行榜身份选择（**Worker + D1 schema 迁移 + Flutter app**，新增 `migrations/0003_leaderboard_identity.sql`）
- 姿态剪影叠加（新增 `lib/ui/pose_feedback/` 目录：silhouette tracker/overlay/adapter）
- 记录页导航与 UI 调整
- 个人页设置/品牌/登录体验（profile settings sheet、launcher branding）
- 训练页控件打磨

## 审计清单（6 大维度）

### 1. 模块设计合理性

逐个模块判断"这个模块存在的理由是否充分、职责是否单一"：
- `lib/pushup_domain.dart` — 纯 dart 算法地基
- `lib/product/` — 产品规则（计数管线/门控/存储/语音/会员状态/排行榜模型）
- `lib/control/` — 编排（WorkoutController / AccountController / LeaderboardController / ReplayControl / WorkoutSyncController / CameraCalibration）
- `lib/ui/pages/` + `lib/ui/pose_feedback/` — 展示层
- `lib/platform/` — 基础设施（相机/会员 API/Google auth/RevenueCat/session store/视频回放）
- `lib/inference/` `lib/pipeline/` — 推理与帧处理
- `lib/config/` — 纯常量
- `workers/membership-api/` — 独立的 Cloudflare Worker 后端

**重点查**：新引入的 `lib/ui/pose_feedback/` 是否有产品逻辑泄漏到 UI 层；`lib/control/` 的 controller 数量是否过多过细；新增的排行榜身份逻辑（worker `leaderboard.ts` + app `leaderboard_controller.dart` + `leaderboard_models.dart` + `leaderboard_page.dart`）是否分层清晰。

### 2. 模块边界是否混乱（依赖方向）

项目铁律：**依赖只能向上指**。分层（见 AGENTS.md）：

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               只依赖 domain
control/               依赖 product + 基础设施
ui/                    只监听 ChangeNotifier 渲染；l10n 与主题只属于这层 + app 根
config/                纯常量
l10n/                  UI/app 根专用
inference/ pipeline/ platform/   基础设施，依赖 domain
workers/               独立后端
```

**重点查**：
- `lib/product/` 是否引用了 `package:flutter`（product 层应零 Flutter 依赖，只有 domain + 纯 dart）—— 逐个 grep `import 'package:flutter` in `lib/product/`
- `lib/ui/pose_feedback/` 是否反向引用了 `lib/control/` 或 `lib/platform/`
- domain/product/control 层是否引用了 `AppLocalizations`（l10n 只属于 UI 层）
- `lib/control/` 是否引用了 `lib/ui/`

### 3. 冗余代码与过期代码

- 根目录的 `_analyze*.py` / `_diag*.log` / `_debug_*.png` / `_workout_debug*.log` / `_v.xml` 等未跟踪临时文件（调试产物，本就不该进 git，确认 .gitignore 是否覆盖）
- 是否有"加了又删"后留下的死代码、未使用的 import、注释掉的大段代码
- 测试夹具是否有重复（`test/fixtures/` 是否只保留脱敏基线数据）
- `docs/archive/` 里的历史交接文档是否应清理或标注"已过时"
- 各 controller 是否有不再被调用的方法
- 工作树里 `feat/pushup-algo` `feat/algorithm-tuning` `feat/voice-prompts` 等已并入或停滞的分支是否该清理

### 4. 文档记录是否过期/无效/混乱/矛盾

项目文档地图在 `AGENTS.md`。重点核对：
- `docs/handoff-2026-07-10*.md` 已严重滞后（停在 `6a99101`，main 已到 `1531c37`），是否应归档/删除
- `docs/modules/membership.md` 历史审查曾标记"部分过时，以代码为准"，是否已更新
- `docs/architecture-analysis.md` / `docs/architecture-plan.md` 是否还反映当前架构（新增了 pose_feedback、leaderboard identity 等）
- `docs/release-configuration.md` 的"当前状态摘要"和"待办清单"是否与实际一致（排行榜身份已加，Worker schema 已动）
- 多个 plan/design 文档（`docs/plans/`、`docs/superpowers/`）是否标注了完成状态，还是混在一起分不清哪些已落地
- 新增 `docs/reviews/` 目录与已有的 `docs/account-features-branch-report.md` 审核报告是否矛盾

**关键矛盾点**：`docs/handoff-2026-07-10-review.md` 写"main HEAD：6a99101"，但 main 实际已到 `1531c37`，领先 50+ 提交。任何引用旧 commit/旧测试数的文档都要标注。

### 5. 屎山代码审核

不限维度，凭工程嗅觉找"味道不对"的代码：
- 超长函数（>100 行）、超长文件（>500 行）是否有拆分必要
- 重复的 try/catch / 重复的 null 检查 / 复制粘贴的代码块
- 命名歧义（同一个概念多种叫法）、魔法数字
- 过度嵌套（>4 层）、回调地狱、 Future 链过长
- 注释说一套代码做另一套
- 硬编码字符串本应进 l10n
- controller 里的 session 守卫是否每个 await 后都校验了（铁律：`session != _session`）
- 异常被静默吞掉（`catch (_) {}` 无处理）

### 6. 机密信息泄露风险

本项目有历史教训（Cloudflare token 曾在聊天暴露、凭证曾硬编码为默认值）。严格查：
- Google Client ID / RevenueCat key / Worker secret / Cloudflare token 是否硬编码在 `lib/config/` 之外的任何地方（应在 `lib/config/membership_config.dart`，走 `--dart-define` 注入）
- grep 全仓库 `AIza` / `goog_` / `apps.googleusercontent.com` / `sk-` / `REVENUECAT` / `CLOUDFLARE_API_TOKEN` / `SESSION_SECRET` / `REVENUECAT_WEBHOOK_SECRET`
- `workers/membership-api/wrangler.toml` 是否含明文 secret（应只有变量名）
- 真实视频/csv/人脸数据是否进 git（应只用 `test/fixtures/` 脱敏数据）
- Worker 路由是否有未鉴权的敏感端点（`workers/membership-api/src/index.ts`）
- `android/key.properties` / `*.jks` / `*.keystore` 是否被误提交
- 真机设备序列号 / 账号邮箱是否出现在 docs/test/代码里

## 审计方法

1. **不要轻信任何汇报**：包括本文件。任何声称的状态自己去代码/测试里验证。
2. **先跑验证基线**，确认审计对象健康：
   ```bash
   cd E:/AII/ugk-post-audit
   flutter analyze          # 应 0 issue
   flutter test             # 应全绿（记录数字）
   cd workers/membership-api && npm test   # 应全绿
   git diff --check
   ```
3. **按模块逐层扫描**：从 `pushup_domain.dart` 开始向上，每层核对依赖方向、职责边界。
4. **用工具辅助**：grep / Glob / Read 大量并行。架构纪律用 grep import 即可快速判断。
5. **证据要实**：每个问题要给 `file_path:line_number` 证据，不要泛泛而谈。

## 产出要求

在 `docs/audit-2026-07-13.md` 产出审计报告，结构：

```markdown
# 架构审计报告（2026-07-13）

## 基线确认
- main commit / analyze / test / worker test 结果

## 发现清单（按严重度排序）

### 🔴 严重（必须修，影响正确性/安全/发布）
- [问题] 证据 `file:line` + 影响 + 建议

### 🟡 中等（应修，影响可维护性/可读性）
...

### 🟢 轻微（建议修，锦上添花）
...

## 6 维度小结
1. 模块设计：...
2. 边界混乱：...
3. 冗余/过期：...
4. 文档：...
5. 屎山代码：...
6. 机密风险：...
```

## 纪律

- **只读审计，不要改代码**。发现问题写报告，不要当场修（除非用户明确要求）。
- 不用 `git add -A`（根目录有未跟踪临时文件）。
- 审计报告可以提交到 `chore/audit-2026-07-13` 分支。
- 引用代码用 `file_path:line_number` 格式（可点击）。

## 关键文档入口

| 文档 | 内容 |
|------|------|
| `AGENTS.md` | 架构分层、关键纪律、文档地图 |
| `docs/development-guide.md` | 分层开发准则 |
| `docs/architecture-analysis.md` | 架构现状 + 债务清单（可能已过时） |
| `docs/modules/recognition.md` | 识别算法 |
| `docs/modules/membership.md` | 账号与会员系统 |
| `docs/release-configuration.md` | 发布台账 |
