# 审核报告：`feat/ui-polish-2026-07-22` — 排行榜 UI 优化（4 提交）

> 日期：2026-07-23
> 审核人：main reviewer
> 分支：`feat/ui-polish-2026-07-22` → `main`
> tip：`36ce274`（rebase 到 `origin/main@41d2e7a`，父提交 `41d2e7a`）
> 4 提交，14 files, +613/-30
> 审查 worktree：`E:/AII/_review-ui-polish`（detached @ `36ce274`）
> 注：本分支**未创建 PR**（`gh pr list --head` 为空），仅有远程分支

## 1. 结论

**审核通过，建议合并。** 无 P0，1 个 P1（流程纪律，非代码），2 个 P2（非阻断）。4 个提交逐一核实均成立、在正确层、设计严谨。Worker 生产部署声明属实，但存在"Worker 先于 App 合并即部署"的流程顺序偏差（向后兼容，无害）。

## 2. 4 个提交核实

### 提交 1 `379f834` fix: 训练结束积分即时刷新（因果链）— ✅ 成立

**改动**：`WorkoutSyncController extends ChangeNotifier`，仅在 `syncedAny && _isCurrent(account)` 时 `notifyListeners()`；`main.dart` 加 listener 调 `reloadForCurrentAccount()`。

**核实**：
- ✅ notify 条件精确（line 150）：真有 pending→synced 且仍当前账号才通知，空 sync/网络失败/rejected/账号切换不通知。
- ✅ **并发去重核实**：`reloadForCurrentAccount` 是 main 既有方法（leaderboard_controller.dart:198），用 `_activeAccountReload` + `_activeAccountReloadSession`（按稳定 `appUserId`）去重，并发同账号复用同一 in-flight Future，whenComplete 按 `identical` 清理。作者"快速连发不扇出"的论断成立。
- ✅ 架构契约测试（architecture_contract_test.dart）静态断言 `extends ChangeNotifier` + `notifyListeners` + main.dart addListener + reloadForCurrentAccount 四要素都在，固化因果链不被无意删除。
- ✅ 测试覆盖 8 个 notify 行为用例（accepted/duplicate 通知，empty/失败/rejected/切账号不通知）。

### 提交 2 `3976cb7` style: 深色榜单 segment 配色对齐记录页 — ✅ 成立

**改动**：`_LeaderboardPeriodPill` 去掉 dark/light 硬编码三元（`darkMutedSurface`/`lightMintSurface`），改用统一 `green` indicator + 辉光 boxShadow。

**核实**：配色简化为单一路径，视觉与 `_CalendarModePill` 同构，代码反而更简洁。尺寸/无 border 契约/220ms 动画保持。

### 提交 3 `ee987a3` feat: 榜单点击展开运动明细（全栈）— ✅ 成立

**改动**：
- Worker `leaderboard.ts`：`LeaderboardRankRow` 加可选 `pushupTotal?`/`narrowPushupTotal?`，`rankRows` 透传。
- 客户端 `leaderboard_models.dart`：`LeaderboardRow` 解析 + `shouldShowBreakdown` getter（`totalValue > 0 && pushupTotal != null`）。
- UI：`_StaggeredLeaderboardRows` 加 `_expandedUserId` 状态 + 展开/收起。

**核实**：
- ✅ 第一性诊断准确：`pushup_points_v1` SQL 早查出拆分字段，只是 `rankRows` 映射时丢了，修复=数据透传，无新表/新查询/新路由。
- ✅ **向后兼容有测试守护**：新增 `plain pushup metric does not surface per-exercise breakdown` 测试，断言纯 pushup 路径不携带字段（undefined→JSON 省略）。
- ✅ `shouldShowBreakdown` 统一判定入口和显示，0 分用户（pushupTotal=0 非 null）不可展开，注释明确。
- ✅ 长按举报/屏蔽保留，0 分不展开，TalkBack hint 组合完整。

### 提交 4 `36ce274` feat: 明细卡滑出+下移动画 — ✅ 成立

**改动**：`_LeaderboardRowDetails` 改 StatefulWidget + AnimationController，AnimatedSize 始终挂载撑高度 + SlideTransition/FadeTransition 滑出。

**核实**：
- ✅ 正确解决"瞬间闪现"：AnimatedSize 始终挂载（高度 0→卡片高驱动下方 item 平滑下移），AnimatedBuilder 在 `isDismissed` 时移出树。
- ✅ reduce-motion 处理到位：`MediaQuery.disableAnimationsOf` → Duration.zero，`_controller.duration` 跟随同步。
- ✅ `pushupTotal!` 的 `!` 安全（外层 shouldShowBreakdown 已保证非 null）。

## 3. ⚠️ Worker 生产部署核实（重点）

作者声明提交 3 的 Worker 改动**已部署到生产**。main reviewer 从私密台账核实（`E:/AII/pushup-ai-info/handoffs/2026-07-23-worker-leaderboard-breakdown-field-deployed.md`）：

| 核实项 | 结果 |
|---|---|
| 防回退检查 | ✅ 生产前 versionCode 22 = 源码 22（非回退） |
| 部署前预检 | ✅ migrations 无待应用、npm test 169/169、dry-run 通过 |
| 6 项探针 | ✅ zh/en 清单 200、错误方法 405、错误平台 400、无鉴权 401、admin 302 |
| 回滚目标记录 | ✅ Current Version ID `47d90630-...` 已记录 |
| 向后兼容论证 | ✅ 纯增可选字段，旧 App 忽略未知字段 |
| 真机验证 | ✅ BboyUgk 144pts 展开 "Standard 72 · Narrow 36"（72×1+36×2=144） |

**部署声明属实，预检/探针/回滚记录规范。**

## 4. 项目纪律核对

| 纪律 | 结果 | 证据 |
|---|---|---|
| `pushup_domain.dart` 纯 dart | ✅ | 未触及 domain 地基 |
| 不平均双腕坐标 | ✅ | 无识别/信号改动 |
| WorkoutController session 守卫 | ✅ | 未改 controller 的异步方法 |
| 回放基线 5/5/3 | ✅ | 未改信号源；730 全测含 domain_self_check |
| l10n 只属于 UI | ✅ | ARB 加 2 key 中英齐全；domain/product/control 无 AppLocalizations 引用 |
| 凭证不进 app_theme | ✅ | 凭证扫描无命中 |
| 不用 git add -A | ✅ | 14 文件全为代码/测试，无临时文件 |
| 真实视频/csv 不进 git | ✅ | 无 fixture/日志新增 |
| UI 只展示不承担逻辑 | ✅ | 展开判定 `shouldShowBreakdown` 在 product 层 getter，UI 只用谓词 |

## 5. 门禁复核（本会话独立运行，worktree `E:/AII/_review-ui-polish` @ `36ce274`）

| 门禁 | 命令 | 结果 |
|---|---|---|
| 空白错误 | `git diff --check` | clean ✅ |
| Flutter 静态分析 | `flutter analyze` | No issues found ✅ |
| Flutter 全量测试 | `flutter test` | **730/730 passed** ✅ |
| Worker 测试 | `npm test`（装依赖后） | **169/169 passed** ✅ |

> 审查 worktree 首次 npm test 因 `node_modules` 不存在（新 worktree 未装依赖）失败，装依赖后全绿。代码本身无问题。

## 6. 风险与遗留

### P1-1：Worker 在 App 合并前已部署到生产（流程顺序偏差，向后兼容故无害）

按 `browser-platform-ops.md §4` 的 App+Worker 联动发版顺序，标准做法是"Worker 部署 → App Internal → 新清单 Worker → Alpha"。本分支 Worker 改动在 **App 客户端代码尚未合并、更未发版** 时就部署了生产。

**为何此处无害**：改动是**纯增可选字段**（旧 App 忽略未知 JSON 字段），生产 Worker 不会破坏任何已发布 App。新字段只有本分支的客户端会用。所以这个"Worker 先行"的顺序在此特定改动下安全。

**纪律提醒**：这不应成为常态。若未来 Worker 改动涉及字段重命名/语义变更/破坏性契约，必须严格按联动顺序（先 App Internal 发布再部署对应 Worker）。建议作者后续 Worker 改动回归标准顺序。

### P2-1：未创建 PR

分支已 push 但**没有 PR**（`gh pr list --head` 为空，作者报告里的链接是 `pull/new/...` 创建入口）。合并时直接用 ff-only 合并远程分支即可，不阻塞，但流程上建议未来先开 PR 再审核。

### P2-2：Worker npm test 依赖环境

审查 worktree 需先 `npm install` 才能跑 npm test（node_modules 不进 git）。这是预期行为（gitignore），但审核 Worker 分支时需记得装依赖。非代码问题。

## 7. 审核决策

- ✅ 放行合并（ff-only）到 main。
- ⏳ 合并 + push origin/main 为独立远程写入授权，等用户明确指示。
- Worker 已在生产部署，本次合并的是 App 客户端代码；合并后若要发版，需独立授权走 Internal→Alpha 流程。
- 合并前需用户知悉 P1-1（Worker 先行部署）的事实。

## 8. 附：合并命令（授权后）

```bash
cd E:/AII/ugk-post
git checkout main
git merge --ff-only origin/feat/ui-polish-2026-07-22
git push origin main
git fetch origin main && git rev-parse main origin/main   # 双向验证
```
