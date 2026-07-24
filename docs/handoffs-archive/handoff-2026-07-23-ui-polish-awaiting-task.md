# 交接：feat/ui-polish-2026-07-23 界面优化（待安排任务）

> 日期：2026-07-23
> 工作树：`E:/AII/ugk-post-ui-polish-2026-07-23`
> 分支：`feat/ui-polish-2026-07-23`（基于 `main@e003ef6`）
> 本机 Flutter：`3.44.7`（pubspec 要求 `>=3.44.0`）

## ⚠️ 重要：接手后等用户安排

**本分支当前没有具体任务。** 接手后**不要自行开始改代码**，先按下面"接手第一步"做只读准备，然后**等待用户给你安排具体的界面优化任务**。用户会告诉你这次要优化哪些界面、解决什么问题。

## 1. 接手第一步（只读，不改动）

1. 用中文说明你正在使用 `$manage-pushupai-project` Skill，本次任务是 UI 开发。
2. 运行只读预检（在 App 仓库 main 工作树，不是这个 worktree）：

   ```bash
   cd E:/AII/ugk-post
   powershell -ExecutionPolicy Bypass -File .agents/skills/manage-pushupai-project/scripts/preflight.ps1 -ProjectRoot E:/AII/ugk-post
   git status --short --branch
   git log --oneline -1 origin/main
   ```

3. 完整读 `E:/AII/ugk-post/AGENTS.md`（项目入口、架构分层、纪律）。
4. 读 `.agents/skills/manage-pushupai-project/SKILL.md` 和它的 references（task-routing / authority-and-ledger / browser-platform-ops）。
5. **重点读 UI 相关权威文档**：
   - `docs/development-guide.md`（怎么按架构分块开发）
   - `docs/design/app-ui-v1.md`（UI V1 设计规范 + 多语言与主题维护规则）
   - `docs/testing-release-playbook.md`（测试分流）
6. 确认你的 worktree 状态：

   ```bash
   cd E:/AII/ugk-post-ui-polish-2026-07-23
   git status --short --branch
   git log --oneline -1
   ```

   应显示：分支 `feat/ui-polish-2026-07-23`，HEAD `e003ef6`，与 main 同步，工作区干净。

## 2. 当前状态（2026-07-23 核实）

| 项 | 值 |
|---|---|
| 本分支基线 | `main@e003ef6`（含多机器协作改造纪律） |
| 领先 main | 0 个提交（全新分支，尚未产出改动） |
| origin/main | `e003ef6`（与本地 main 同步） |
| Play Internal | `0.3.20 (23)` 已面向内部测试人员发布 |
| Play Alpha | `0.3.20-closed-1` 审核中 |
| 生产 Worker 清单 | `0.3.20 (23)` |

main 上最近的内容（截至本分支创建时）：
- 三分支合并：近距离 ready 阻断、PR#13 三 bug 修复、排行榜展开明细
- 0.3.20 发版（Internal 已发布 + Worker 清单部署 + Alpha 送审）
- 多机器协作改造（info 私有远程同步 + private/ 历史清除）

## 3. 你要做的事（等用户安排后）

用户会给你具体的界面优化任务。常见的 UI 任务类型（仅供参考，以用户实际指示为准）：
- 页面布局/视觉调整
- 浅色/深色主题优化
- 中英文文案（进 ARB，不硬编码）
- 交互动效
- 系统安全区适配

## 4. 关键纪律（违反会埋坑，AGENTS.md / app-ui-v1.md 详细说明）

1. **UI 层只展示和转发用户操作**：逻辑不泄漏到 UI；判定谓词放 product 层，UI 只调用。
2. **用户可见文案进 ARB**（中英文都改）：不在 Widget 硬编码；`domain/product/control` 层不引用 `AppLocalizations`。
3. **不用 `git add -A`**：显式 stage 代码文件，根目录有未跟踪临时文件。
4. **回放基线 5/5/3** 是硬约束：即使改 UI 也要保持 `flutter test test/domain_self_check_test.dart` 全绿。
5. **Flutter UI 迭代默认保留 resident `flutter run` 会话**：Dart/Widget 小改用 Hot Reload（`r`），需要重跑 `main()` 用 Hot Restart（`R`）。
6. **不在 `pushup_domain.dart` 加 Flutter/platform import**（纯 dart 地基，UI 改动一般不碰它）。
7. **不平均两个手腕坐标**（历史 bug 根源，UI 改动一般不碰，但若涉及识别相关 UI 要知道）。

## 5. 完成后的验证（改完代码后跑）

```bash
cd E:/AII/ugk-post-ui-polish-2026-07-23
flutter analyze                    # 0 issue
flutter test                       # 全绿（基线 730 级别，以当前 main 为准）
flutter test test/domain_self_check_test.dart   # 回放硬基线 5/5/3
git diff --check                   # 无空白错误
```

涉及 Worker/D1/会员/商店配置时，额外读对应模块文档并走授权流程；普通 UI 改动不需要。

## 6. 真机调试日志

```bash
adb -s <device> logcat -s flutter | grep UGK
```

## 7. 与用户对话的建议开场

```
已读完交接。我在 feat/ui-polish-2026-07-23 分支（worktree E:/AII/ugk-post-ui-polish-2026-07-23），
基于最新 main@e003ef6，工作区干净。

我已完成只读准备（读了 AGENTS.md、development-guide、app-ui-v1 设计规范、纪律）。
等你安排具体的界面优化任务——告诉我这次要优化哪些界面、解决什么问题。
```

---

**交接结束。接手后先做只读准备，然后等用户安排具体任务，不要自行开始改代码。**
