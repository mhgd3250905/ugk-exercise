# 审核报告：feat/account-features（2026-07-10，对抗式审查）

> 审核对象：`feat/account-features`（worktree `E:/AII/ugk-post-account`，HEAD `876620f`）
> 分叉基线：`4217dbd`；相对 `main`：落后 2、领先 28（含报告提交）
> 改动规模：49 files、+15401 / −321
> 方法论：对抗式审查——不轻信汇报，所有数字与声称自己复跑/读码核对，3 个 subagent 分头深审

## 1. 结论

**通过。可合并。** 未发现伪造测试、凭证泄露、架构违规或可利用安全漏洞。
4 个非阻塞改进点见 `docs/plans/2026-07-10-review-backlog.md`。

合并前置条件：本分支**完全没碰** `lib/pushup_domain.dart`（`git diff main...HEAD` 为空），
与 main 的计数重设计无算法层冲突；但合并后仍须重跑验证（见 §6）。

## 2. 验证复跑（全部属实）

| 项目 | 汇报 | 复跑结果 |
|------|------|---------|
| `flutter analyze` | 0 issue | ✅ `No issues found! (9.0s)` |
| `flutter test` | 216/216 | ✅ `+216: All tests passed!` |
| Worker `npm test` | 85/85 | ✅ `tests 85 / pass 85 / fail 0` |
| 回放基线 | step0=5 / v3=5 / v4=3 | ✅ `test/domain_self_check_test.dart:106,127,146` 断言 5/5/3，在 216 内通过 |

git 状态核对一致：HEAD `876620f`，3 个新提交 `fa60480`/`b6a7e3d`/`876620f` 均在，
behind 2 / ahead 28，暂存区空，仅 `docs/handoff-account-features.md` 未跟踪。

## 3. 架构纪律（7 条全部干净）

| 纪律 | 结果 | 证据 |
|------|------|------|
| domain 纯 dart | ✅ | `pushup_domain.dart` 仅 `import 'dart:math'` |
| 依赖只向上 | ✅ | product/control 0 反向 import；4 个新文件均合规 |
| session/generation 守卫 | ✅ | WorkoutController/AccountController/WorkoutSyncController/LeaderboardController 每个 await 后都有守卫 |
| l10n 只属 UI | ✅ | domain/product/control 无 `AppLocalizations` 引用 |
| 凭证走 dart-define | ✅ | `membership_config.dart` `String.fromEnvironment` 无 `defaultValue`，release fail-fast |
| 不用 `git add -A` | ✅ | 分支提交无 apk/png/csv/log 混入 |
| fixtures 脱敏 | ✅ | `test/fixtures/*.csv` 为标量信号，无关键点/人脸 |

**手腕坐标平均**（`pushup_domain.dart:158` `weightedMean` of leftW/rightW）：确认是
**既有代码**（提交 `757580b` 同时在 main 和本分支，非本分支引入），且产出 `pressDepthY`
**不在计数路径**（counter 只读 `torsoY`）。属历史遗留死代码，另议清理，不阻塞本分支。

## 4. 安全（Worker 后端扎实）

**确认强**：
- session token HMAC-SHA256，只存 hash
- Google ID token 用 `jose.jwtVerify` 校验 issuer + audience
- RevenueCat webhook：timing-safe 比较 + ±5min 防重放 + `event.id` 去重
- 全量 SQL 参数化（31 个 prepare 站点，0 注入点）
- 配额（5000/日、1000/条）与 session 幂等在 D1 `batch()` 事务内 SQL 守护
- 聚合写入时 SQL 内复检 `joined_at`，leave + sync 并发只存历史不算分
- leaderboard 读取 `INNER JOIN membership_snapshots ... is_active=1` 再过滤，过期会员不上榜

**2 个非阻塞改进**（详见 backlog B1/B2）：
- B1：聚合 SQL 复检了 `joined_at` 但没复检 membership（读取层已兜底，不可见）
- B2：webhook `app_user_id` 未绑定已验证用户（会员系统既有设计，非本分支回归）

## 5. 汇报逐项核对（21 项，19 确认）

profile/sync/leaderboard/migration 核心机制全部属实：AppUser 字段、PATCH profile、
WorkoutSession UTC+owner、串行写队列、本地优先合并、generation 守卫、并发 coalesce、
账号切换 drain、排行榜四态、原子配额、D1 可重复迁移。

**2 项偏差（非阻塞，见 backlog B3/B4）**：
- B3：客户端**无昵称校验**（汇报 §2.1 暗示有客户端支撑，实际只映射服务端错误码）
- B4：周期切换**不清 `_snapshot`**（账号切换会清；周期切换靠 UI 过滤兜底）

## 6. 合并

- 算法层 `pushup_domain.dart` 零 diff → 合并 main 计数重设计无算法冲突
- 合并后必须重跑：`flutter analyze` + `flutter test`（确认回放 5/5/3）+ `npm test`
- 合并结果须保持回放基线 5/5/3，且 main 的计数重设计未被回退

## 7. 历史遗留（与本分支无关）

- **P0-1 Cloudflare token**：历史会话暴露过的 token 仍未轮换，需人工确认（非本分支引入，本分支未写入任何 token）
