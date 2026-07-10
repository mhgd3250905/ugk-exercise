# 审核发现的改进 backlog（feat/account-features 评审，2026-07-10）

> 来源：对抗式审查 `feat/account-features`（审核文档见
> `docs/refactor/2026-07-10-account-features-review.md`）。
> 下列条目**均非阻塞合并项**（无安全/隐私/架构硬伤、无伪造测试），
> 但建议作为合并后的加固任务跟进。按优先级排序。

## 优先级一览

| # | 项 | 层 | 风险 | 建议 |
|---|----|----|------|------|
| B1 | membership 写时未复检（聚合 SQL） | Worker | 低（有读取层兜底） | 合并后顺手修 |
| B2 | webhook `app_user_id` 未绑定已验证用户 | Worker | 中（依赖 HMAC 守门） | 单独立项 |
| B3 | 客户端无昵称校验 | Flutter | 体验 | 小改进 |
| B4 | 周期切换不清排行榜 `_snapshot` | Flutter | 低（UI 已过滤） | 小改进 |

---

## B1 — membership 写时未在聚合 SQL 复检

- **现状**：`workers/membership-api/src/workouts.ts:121` 只在请求开始读一次
  `premium = await membershipActiveForUser(...)`；聚合 UPSERT（`:450`）在 SQL 内
  复检了 `leaderboard_profiles.is_joined` 和 `joined_at <= workout.endedAt`，
  但**没有**复检 membership 有效性。
- **风险**：membership 在请求开始与 D1 batch 提交之间过期（亚秒~几秒窗口）时，
  这一条训练仍会被算进排行榜聚合。
- **缓解（已存在）**：`leaderboard.ts:210/224` 查榜时 `INNER JOIN membership_snapshots
  ... is_active = 1` 重新过滤，过期会员的聚合分**不会出现在榜上**，用户不可见。
- **建议改法**：在 aggregate UPSERT 的 `WHERE` 条件里补一个对称的 `EXISTS
  (SELECT 1 FROM membership_snapshots WHERE user_id = ? AND is_active = 1
  AND (expires_at IS NULL OR expires_at > ?))` 子句，与现有 `joined_at` 复检同构。
  改动约十几行，加一个真实 SQL 回归测试覆盖"聚合时 membership 已过期"。
- **非本分支回归**：属于本分支新写的聚合逻辑的对称性缺口，但靠读取层兜底。

## B2 — webhook `app_user_id` 未绑定已验证用户

- **现状**：`workers/membership-api/src/index.ts:151,174-203` 处理 RevenueCat webhook 时，
  `appUserId = event.app_user_id` 直接当 user id，仅 `SELECT id FROM users WHERE id = ?`
  检查存在性（不存在静默返回 ok），**不校验**该 id 是否通过 Google OAuth 建立、
  是否与登录时的 RevenueCat 身份绑定。
- **风险**：webhook secret 一旦泄露，攻击者可构造任意 `app_user_id` 给任意 user 授 Premium。
  当前安全性完全依赖 webhook HMAC（`webhook_auth.ts`，timing-safe + 5min 防重放）。
- **这是会员系统既有设计，非本分支回归**：main 上的 webhook 逻辑同样如此。
- **建议改法**：跨 OAuth/RevenueCat/webhook 三处的**设计级改动**——
  登录时把已验证的 RevenueCat `app_user_id` 绑定到 user 并持久化，webhook 只信任已绑定的映射。
  **不建议塞进本大分支**，应单独立项 + 设计评审。
- **缓解（已存在）**：webhook HMAC 校验 + `webhook_events` 去重。P0-1 Cloudflare token
  轮换（历史遗留）仍是更高优先级的人工动作。

## B3 — 客户端无昵称校验

- **现状**：`lib/` 内**无任何客户端昵称校验**（无 RegExp / InputFormatter / 长度上限）。
  昵称原样发给服务端，客户端只映射错误码（`profile_page.dart:721-725` 映射
  `invalid_nickname`/`nickname_taken`/`nickname_change_too_soon`）。
- **风险**：无安全洞（服务端校验完整），但用户体验弱——非法输入要等一次网络往返才报错。
- **建议改法**：在 `profile_page.dart` 或新建 `lib/ui/...` 层加一个镜像服务端规则的
  轻量校验（长度 1~N、`^[\p{L}\p{N}_ -]+$`、至少一个字母或数字、非保留名），
  给输入框一个 `inputFormatters` + 实时提示。注意校验只属 UI 层，别下沉到 product/control。

## B4 — 周期切换不清排行榜 `_snapshot`

- **现状**：`lib/control/leaderboard_controller.dart` 的 `load(period)`（`:68-104`）
  进入 `_run` 时清 `_error` 但**不清 `_snapshot`**，加载新周期期间 controller 仍持有旧周期快照。
- **缓解（已存在）**：`leaderboard_page.dart:60-63` 按 `snapshot?.period != _period` 过滤，
  旧周期数据不会渲染。账号切换路径（`reloadForCurrentAccount` `:55-66`）则**会**立即清快照。
- **风险**：功能正确，但 controller 持有过期状态；若有其他消费者读 `_snapshot`
  （如 `home_page._resolveStatus:303-304`）可能拿到旧周期数据。
- **建议改法**：`load()` 进入 `_run` 前 `if (period != _lastPeriod) { _snapshot = null; }`，
  与账号切换路径对称，约 3 行。

---

## 审查中确认干净的项（无需跟进，仅备查）

- session token HMAC（只存 hash）、Google ID token `jose.jwtVerify`（issuer+audience）
- RevenueCat webhook timing-safe 比较 + 5min 防重放 + event.id 去重
- 全量 SQL 参数化（0 注入点）
- 配额（5000/日、1000/条）在 D1 batch 事务内 SQL 守护
- session 幂等（重复 session 不消耗配额）
- leave + sync 并发：聚合写入时 SQL 复检 `joined_at`，只存历史不算分
- domain 纯 dart、依赖只向上、session/generation 守卫、l10n 只属 UI、凭证走 dart-define 无 defaultValue
- 分支提交无 apk/png/csv/log 混入（未滥用 `git add -A`）、fixtures 脱敏标量
