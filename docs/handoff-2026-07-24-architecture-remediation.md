# 交接：fix/architecture-remediation-2026-07-24 全面架构治理

> 日期：2026-07-24
> 工作树：`E:/AII/ugk-post-architecture-remediation-2026-07-24`
> 分支：`fix/architecture-remediation-2026-07-24`
> 基线：`main@ca1bb46`
> 本机 Flutter：`3.44.7`

## 1. 已批准任务

用户已批准方案 A：在一个治理 worktree 中，以分阶段、可独立审核的提交修复已确认的 3 个 P1 和 5 个 P2。无需等待再次安排，但必须从测试开始，不能一次性无边界重构。

main 工作树的两份未跟踪报告是事实源之一，只读使用，不移动、不删除、不 stage：

- `E:/AII/ugk-post/docs/reviews/2026-07-24-full-architecture-audit-report.md`
- `E:/AII/ugk-post/docs/reviews/2026-07-24-full-architecture-audit-review-report.md`

## 2. 治理范围

### 阶段一：跨端状态机

1. P1-01：`AccountController.refresh()` 收到 401 后清理当前账号和安全存储，同时守住旧请求/新账号竞态。
2. P1-02：端到端保留 workout `rejected.reason`，区分 terminal、会员阻塞和可重试失败；零次训练不进入云队列。
3. P1-03：训练同步按 Worker 上限最多 200 条分块，每块之间重新校验账号和会员。

### 阶段二：product 与数据真源

4. P2-04：product 只保留模型、规则与 port；文件系统和音频插件实现移到 platform。
5. P2-08：损坏训练历史隔离/备份，逐项防御解析，不静默覆盖唯一原文件。

### 阶段三：Worker 可扩展性

6. P2-05：排行榜改为 D1 有界分页，保持全局名次、屏蔽、冻结成绩、本人排名和稳定 cursor 语义。

### 阶段四：测试与文档真源

7. P2-06：将关键生命周期和顺序字符串断言替换为行为测试或结构化检查；保留少量简单依赖扫描。
8. P2-07：将窄距腕宽权威阈值统一为 1.5，并记录依据。

## 3. 接手第一步

完整阅读并遵守：

- `AGENTS.md`
- `docs/development-guide.md`
- `docs/testing-release-playbook.md`
- `docs/modules/membership.md`
- `docs/modules/recognition.md`
- `docs/modules/voice-themes.md`
- `docs/modules/workout-controller.md`
- `.agents/skills/manage-pushupai-project/SKILL.md`
- `.agents/skills/manage-pushupai-project/references/task-routing.md`
- `.agents/skills/manage-pushupai-project/references/authority-and-ledger.md`

确认：

```powershell
git status --short --branch
git rev-parse --short HEAD
```

预期为 `fix/architecture-remediation-2026-07-24@ca1bb46`。

## 4. 开发纪律

- 每一项先写能复现问题的失败测试，再做最小实现。
- 依赖只能向上；`pushup_domain.dart` 保持纯 Dart。
- `WorkoutController` 的每个异步边界保留 session generation 守卫。
- 不平均两个手腕坐标。
- l10n 只属于 UI/app 根。
- 不加入未经批准的生产依赖。
- 不使用 `git add -A`，只显式 stage 本阶段文件。
- 不 push、部署 Worker、修改 D1 或操作平台。
- 每阶段完成后运行最相关测试并形成独立提交。

## 5. 最终验证

```powershell
flutter analyze
flutter test
flutter test test/domain_self_check_test.dart
git diff --check
cd workers/membership-api
npm test
```

硬约束：回放 `step0=5 / v3=5 / v4=3`。

## 6. 独立审查

开发和全量门禁完成后，新开独立审查线程，只读验证：

1. 需求完整性；
2. 逻辑正确性；
3. 边界情况；
4. 代码质量；
5. 测试覆盖；
6. 实际运行结果。

审查问题交回主线程修复，再退回复验，直至通过或明确阻塞。
