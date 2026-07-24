# 交接：refactor/arb-and-test-fakes-cleanup-2026-07-24 低风险尾项（L3+L4）

> 日期：2026-07-24
> 工作树：`D:/Git/AII/ugk-post-arb-testfakes-cleanup-2026-07-24`
> 分支：`refactor/arb-and-test-fakes-cleanup-2026-07-24`（基于 `main@5f20e0d`）
> 本机 Flutter：`3.44.7`
> 派发者：main reviewer
> 任务来源：`docs/reviews/2026-07-24-staleness-audit-full-report.md` §4 L3 + L4

## 你的任务（L3 + L4，低风险整理项）

两个独立的低风险清理：(L3) 删无生产调用的 ARB key；(L4) 把生产 lib 里的 test fake 迁到 test 目录。

**先读任务来源**：报告 §4 L3 + L4（位置+证据）。

## L3：删除 10 个无生产 getter 调用的 ARB key

报告核实：以下 10 个 key 排除生成的 `app_localizations*.dart` 后，全仓无 `.key` 调用：

```
leaderboardFrozenScoreTitle
profileLocalTrainingData
testMode                 ← 注意：与 test-mode-retire 分支关联，那个分支会退休测试模式
workoutPreparing
workoutReady
workoutGoalValue
workoutCaloriesValue
workoutStatusError
workoutTodayGoal
workoutBurned
```

### 关键约束
- **`app_zh.arb` + `app_en.arb` 必须同步删**（中英对齐，AGENTS.md 纪律#7）。
- **删完跑 `flutter gen-l10n` 重新生成**，**不要手改** `app_localizations*.dart`（生成文件）。
- `workoutTodayGoal`/`workoutBurned` 只在 `architecture_contract_test.dart` 的**负向源码断言**（"不得出现"）中以字符串出现——删 ARB key 后检查这些断言是否需要同步调整。
- **`testMode` 的处理**：test-mode-retire 分支会退休测试模式。本分支删 `testMode` ARB key 时，若与该分支冲突，以 test-mode-retire 为准（可先不删 testMode，其余 9 个先删）。**优先删其余 9 个无争议的**。

## L4：3 个 test fake 从生产 lib 迁到 test

报告核实：以下 3 个 fake/memory 实现在生产 `lib` 无实例化，只被测试 import：

| 位置 | 类 |
|---|---|
| `lib/platform/account_session_store.dart:92` | `MemoryAccountSessionStore` |
| `lib/platform/leaderboard_home_rank_store.dart:95` | `MemoryLeaderboardHomeRankStore` |
| `lib/platform/revenuecat_service.dart:135` | `FakeRevenueCatService` |

### 要做什么
- 迁到 `test/support/`（或测试专用目录），让测试统一 import。
- 生产 `lib` 只留接口和真实实现（`SecureAccountSessionStore`/`SecureLeaderboardHomeRankStore`/`PurchasesRevenueCatService`，`main.dart` 用的）。
- **更新所有 import 这些 fake 的测试**（搜 `git grep MemoryAccountSessionStore` / `FakeRevenueCatService` / `MemoryLeaderboardHomeRankStore` 找全部引用点）。

### 关键约束
- 这会改大量测试的 import 路径——逐个确认编译通过。
- **不要改测试逻辑**，只迁文件位置 + 改 import。
- 如果某个 fake 与生产真实实现耦合（共享私有成员），可能需要把共享部分提取——若遇到，停下来问用户，不要硬拆。

## 关键纪律

1. **ARB 中英同步**：删 key 时 zh+en 一起删。
2. **生成文件不手改**：`app_localizations*.dart` 由 `flutter gen-l10n` 生成。
3. **L4 不改测试逻辑**：只迁位置 + import。
4. **不用 `git add -A`**：显式 stage 改动的文件 + 新增的 test/support 文件 + 删除的原位置文件。
5. **回放基线 5/5/3**：改完跑确认不受影响。

## 完成后验证

```bash
cd D:/Git/AII/ugk-post-arb-testfakes-cleanup-2026-07-24
flutter gen-l10n                     # 重新生成 l10n（ARB 改后）
flutter analyze                      # 0 issue
flutter test                         # 全绿（import 改后所有测试仍过）
flutter test test/domain_self_check_test.dart  # 回放 5/5/3
git diff --check
```

⚠️ 若 `flutter test` 有测试因找不到 fake 类失败，说明 import 路径没改全——`grep` 找漏的引用。

提交后等 main reviewer 审核。

## 建议开场白

```
已读完交接。我在 refactor/arb-and-test-fakes-cleanup-2026-07-24，基于 main@5f20e0d。
任务：L3 删 10 个无调用 ARB key（中英同步+gen-l10n）+ L4 迁 3 个 test fake 到 test/support。
两个独立低风险项，ARB 同步和 import 改全是重点。
```
