# PR 返工说明：staleness-audit 分支 rebase（给分支作者）

> main reviewer，2026-07-24
> 分支：`investigate/staleness-audit-2026-07-24`
> 关联审核报告：`docs/reviews/2026-07-24-staleness-audit-branch-review-report.md`
> 一句话：**报告内容已审核通过（高质量、技术论断属实），不用改。但分支 base 过时，需要 rebase 到最新 main 后重推——否则合并会回退掉刚合并的 0.3.21 版本号改动。**

---

## 报告没问题，是 base 过时了

你的陈旧度报告 main reviewer 已审核通过：

- **11 项发现（D1-D7 / L1-L4 / T1-T4）独立抽查 5 个关键技术论断全部属实**：L1 旧 SignalFilter 退出生产、L2 test_mode 不可达、L3 ARB key 无调用、claimLegacy 活跃、golden_frame 活跃 CLI。
- **删除风险分级诚实**，高风险保留项（fixture/claimLegacy/golden_frame）标"不可删"。
- **只提交了 1 个报告文件**，`lib`/`test` 与 main 完全一致，没误改代码。

不用改报告内容。问题在**分支的起点**。

## 为什么要 rebase（和 PR#14 一模一样的陷阱）

你的分支从 `b5b1768`（0.3.21 发版**之前**）拉的。但之后 main 上又合并了 `release/play-update-2026-07-24`（0.3.21 版本号改动：pubspec `0.3.21+24` + Worker 清单 + 测试），现在 main 是 `72964f2`。

所以你这个分支的 diff 把 0.3.21 的版本号改动**全部显示成删除**（你会看到 `pubspec.yaml -2`、`app_update.ts -16`、`app-update.test.mjs -15`——那不是你的改动，是 base 没跟上 main 的错觉）。

**风险**：如果直接在 GitHub 点 "Rebase and merge" / "Squash and merge"，会把分支线性重放到 main，**回退掉刚合并的 0.3.21 版本号**。所以不能直接合。

**好消息**：你的报告文件（`docs/reviews/`）和 0.3.21 版本号文件**改的是完全不同的文件，零重叠，rebase 无冲突**（main reviewer 干跑验证过）。

## 你需要做的（rebase 三步）

在你这个分支的工作树里：

```bash
# 1. 拉最新 main
git fetch origin

# 2. rebase 到最新 main（你的 1 个提交重放到 72964f2 之上，预期无冲突）
git rebase origin/main

# 3. force-push 更新远程分支（rebase 改写了提交 hash，必须 --force-with-lease）
git push --force-with-lease origin investigate/staleness-audit-2026-07-24
```

rebase 完之后：
- 分支的 diff 会**只剩你的 1 个报告文件**（+318），版本号"删除"行会消失。
- 提交 hash 会变（从 `0e7e62f` 变成新的），正常。

## rebase 后请重跑一次门禁

rebase 不改报告内容，但基线变了，按规矩重跑确认无回归（这次分支只加了文档，主要是确认代码没被 rebase 误碰）：

```bash
flutter analyze                    # 0 issue
flutter test                       # 全绿（应仍 745）
flutter test test/domain_self_check_test.dart  # 回放基线 5/5/3
git status --short                 # 确认只有报告文件
git diff --stat origin/main        # 确认只 +1 个报告 md，无 lib/test 改动
```

跑完把结果贴回，我复核后走 ff-only 合并。

## 关于 force-push

用 `--force-with-lease`（不是 `--force`）：只在你本地知道的远程状态下才覆盖，更安全。这是你自己独立开发的分支，force-push 是常规操作，不需要额外审批。

---

**小结**：报告不用动，只需 `fetch → rebase origin/main → push --force-with-lease`，重跑门禁贴结果，完事我合并。
