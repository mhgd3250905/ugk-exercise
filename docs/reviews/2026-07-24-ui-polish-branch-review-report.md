# 审核报告：`feat/ui-polish-2026-07-23` — 排行榜/剪影 UI + 账号 RevenueCat 修复（6 提交）

> 日期：2026-07-24
> 审核人：main reviewer
> 分支：`feat/ui-polish-2026-07-23` → `main`
> tip：`5ad936e`（rebase 到 `origin/main@c6c6dc9`）
> 6 提交，11 files, +470/-86
> 基线：`origin/main@c6c6dc9`（音频补全已合并后）
> 审查 worktree：`E:/AII/_review-ui-polish-2026-07-24`（detached @ `5ad936e`）
> 注：本分支**未创建 PR**（仅有远程分支）；分支自带作者自审报告 `docs/review-2026-07-24-ui-polish-branch.md`，本报告为 main reviewer 独立复核，**不采信作者自审结论**

## 1. 结论

**审核通过，建议合并。** 无 P0，无 P1，2 个 P2（运行时观察 + 文档口径，非阻断）。

本会话**亲自独立运行**全部门禁，并对两个 RevenueCat/账号修复做了 PR#13 式 bug 真实性回溯——**两个修复针对的问题都真实存在，非虚构**，且第二个修复直接补上第一个修复留下的真实漏洞。

### 亲自验证结果（本会话运行，非采信作者报告）

| 门禁 | 结果 | 命令 |
|---|---|---|
| `flutter analyze` | **0 issue**（ran in 2.9s） | 审查 worktree |
| `flutter test`（全量） | **740 passed** | 全量 |
| 回放基线 | **5/5/3** ✓（26 测试全绿） | `test/domain_self_check_test.dart` |
| `git diff --check` | 无空白错误 | 分支 vs main |
| 提交内容核验 | 6 提交 11 文件全为任务文件，**无临时文件污染**（无 `_*.py/png/log`、无 apk、无 handoff） | `git log --name-only` |
| rebase 干净 | 作者报告 rebase 无冲突——本会话确认 tip `5ad936e` 线性落在 main 之上，无 merge commit | `git log --oneline` |

## 2. 六个提交核实

### 提交 `a204818` feat(leaderboard): watermark breakdown replaces fused details card — ✅ 成立
排行榜行展开：把旧的"融合卡片"（SlideTransition + 底部圆角容器 + 单行文本）换成 watermark 式淡入 + 结构化 `_BreakdownRow`（标准/窄距两栏 + 数字）。纯展示层重构，数据源 `pushupTotal`/`narrowPushupTotal` 是既有模型字段，无新逻辑。

### 提交 `93b6fd2` style(leaderboard): flatten points-rule caption + stack frozen-panel CTA — ✅ 成立
`_PointsRuleBanner` 去掉卡片背景改纯 inline caption；`_FrozenScorePanel` Row→Column 堆叠（描述在上、订阅按钮在下）。纯布局，无逻辑。

### 提交 `7108be9` fix(account): login success no longer masked by RevenueCat.configure failure — ✅ 成立（bug 真实，见 §3）
### 提交 `275e60b` style(pose-silhouette): thicker stroke, drop shadow, layered glow — ✅ 成立
`PoseSilhouettePainter` 纯绘制层美化（lineWidth 0.018→0.028、加 drop shadow / outer glow / mid stroke / crisp core）。`debugPathFor`（几何路径）未动，只改怎么画。无逻辑/数据。

### 提交 `5123a39` fix(account): re-attempt RevenueCat.configure before purchase/restore — ✅ 成立（补真实漏洞，见 §3）
### 提交 `5ad936e` docs: review report — 作者自审报告，随分支走。本会话不以其结论为准，已独立复核。

## 3. RevenueCat 修复——bug 真实性回溯（PR#13 教训，重点）

**结论：两个修复都针对真实问题，非虚构。**

### 3.1 `7108be9`：configure 失败掩盖登录成功

本会话回溯 `origin/main` 旧代码，确认因果链真实存在：

1. `signIn()` → `_run(...)` 包裹整个流程。
2. `_run` 内闭包末尾调 `_applySnapshot` → `await _revenueCat.configure(...)`（旧代码**直接 await，无 try/catch**）。
3. configure 抛错（瞬时网络错误）→ 异常穿出 `_applySnapshot` → 穿出 `action(generation)`。
4. `_run` 的兜底 `} catch (_) { errorMessage = AccountErrorCode.unexpected; }`（旧 line 511）捕获 → 设 `_error = unexpected`。
5. **结果**：Google 登录 + authGoogle 已成功（snapshot 已 apply、用户已登录），但 UI 显示"操作失败"横幅。**真实 bug。**

修复正确：在 `_applySnapshot` 内把 `configure()` 包进 try/catch 吞掉。注释充分解释了为何吞（snapshot 是权威源、已 apply）**并诚实标注了后果**："swallowed failure leaves SDK unconfigured until next signIn → purchase/restore 需先 re-attempt linkage"。注释质量高，没有掩盖副作用。

### 3.2 `5123a39`：purchase/restore 前重试 configure（补 3.1 留下的真实漏洞）

3.1 吞掉 configure 失败后，**SDK 在该 session 剩余时间处于未配置状态**，后续 purchase/restore 会静默 no-op。这是 3.1 引入的真实漏洞——**第二个修复直接补它**，不是虚构：

- `purchasePremiumPlan` / `restorePurchases` 在调 SDK 前各加 `await _ensureRevenueCatConfigured(account)`（内部 try/catch 吞错，configure 成功则 linkage 恢复）。
- 位置正确：在 `_serializeIdentity` 内（串行，防竞态）、在 `if (!_isCurrentAccount)` session 守卫之后、purchase/restore 调用之前。
- **回归测试覆盖**（test/account_controller_test.dart 新增 2 个）：
  - `signIn succeeds without error when only RevenueCat.configure fails`：验证登录不被掩盖（`controller.error == null`）。
  - `purchase re-attempts RevenueCat.configure when the first one failed`：用 `_RecoveringConfigureRevenueCatService`（首次抛错、后续成功），断言 `configureCalls == 2`（signIn 1 次 + purchase 前 1 次）+ `purchaseCalls == 1`。精准覆盖"恢复 linkage"路径。

> 一致性核实：configure 是 RevenueCat SDK 的幂等操作（同 appUserId 重复 configure 无害）；正常成功路径下 purchase 前会多调一次 configure，是可接受的运行时开销（见 P2-1）。

## 4. 关键纪律逐项核查

| 纪律 | 核查 | 结果 |
|---|---|---|
| `pushup_domain.dart` / `lib/product/` 纯 dart | `git diff --stat ... lib/pushup_domain.dart lib/product/` 为空 | ✅ 未触碰 |
| 不平均双腕坐标 | 本次无算法改动（N/A） | ✅ N/A |
| WorkoutController session 守卫 | account_controller 的 `_isCurrentAccount`/`_isCurrent` 守卫在 configure/purchase 前均校验 | ✅ |
| 回放基线 5/5/3 | 亲自跑 | ✅ 5/5/3 |
| l10n 只属于 UI + 双语同步 | 新增 2 个 key（`leaderboardBreakdownStandard`/`Narrow`）**zh+en ARB 都改**，带 `@` description 元数据；gen 文件同步 | ✅ |
| UI 只展示 | `_BreakdownRow`/`_BreakdownStat` 只读模型字段渲染，无判定谓词泄漏 | ✅ |
| 凭证不进 app_theme | 本次无 membership 配置改动；RevenueCat 调用走既有 `_revenueCat` 抽象，无硬编码 key | ✅ |
| 不用 git add -A | 6 提交 11 文件全为任务文件，无临时文件/handoff 误入 | ✅ |
| 语音/Worker 合同 | 本次无 worker/音频改动（N/A） | ✅ N/A |

## 5. P0 / P1 / P2

### P0（阻断合并）：无
### P1（需返工）：无

### P2（非阻断）

**P2-1｜正常路径下 purchase 多调一次 configure（运行时开销，非 bug）**
登录 configure 成功后，每次 purchase/restore 前会再 `_ensureRevenueCatConfigured` 一次。configure 是幂等的（RevenueCat SDK 约定，同 appUserId 重复无害），但会多一次 SDK 往返。
- 影响：极小（仅成功登录后的购买路径），换取的是 3.1 吞错后的自愈能力，权衡合理。
- 建议：无需改。若日后 SDK 提供显式 `isConfigured` 查询，可优化为仅在未配置时重试。

**P2-2｜作者自审报告与分支命名日期不一致**
作者自审文件名 `docs/review-2026-07-24-ui-polish-branch.md`（注意：放在 `docs/` 根，不是本仓库惯例的 `docs/reviews/`；且文件名 `review-` 前缀而非 `*-review-report.md`）。与本仓库历史 review 报告命名惯例（`docs/reviews/<日期>-<主题>-review-report.md`）不一致。
- 影响：纯归档口径，不影响代码/功能。
- 建议：本次不阻断；后续可让作者统一到 `docs/reviews/` 命名。

## 6. 真机/Billing 验收状态（提醒，非本审核范围）

作者自报小米 arm64 签名 release 包真机验证了剪影美化 + 账号 bugfix。但 **RevenueCat 购买 re-configure 兜底逻辑（`5123a39`）涉及真实 Billing 链路**：
- 单元测试用 fake 覆盖了"configure 失败后 purchase 恢复 linkage"，但 **fake 不能证明 Google Play Billing 真实链路**（见 AGENTS.md 测试分流：Billing 必须经 Play 测试轨道）。
- 建议合并后用 **Play License Tester** 真机抽查一次完整购买链路（模拟 configure 首次失败的场景较难，但至少验证正常购买 + restore 不被多余 configure 调用打断）。

## 7. 合并建议

- ✅ 可 fast-forward 合并：tip `5ad936e` 线性领先 main 6 提交，无分叉。
- 分支已 push origin（`origin/feat/ui-polish-2026-07-23`）。
- 等用户明确授权后执行 `git merge --ff-only` + push。

## 8. 审查产物

- 审查 worktree：`E:/AII/_review-ui-polish-2026-07-24`（detached，合并后可 `git worktree remove` 清理）
- 本报告：`docs/reviews/2026-07-24-ui-polish-branch-review-report.md`

---

**审核结论：通过（无 P0/P1）。两个 RevenueCat 修复经 bug 真实性回溯确认成立。等用户授权后 fast-forward 合并到 main 并 push。**
