# `feat/account-features` 分支新增内容与审核说明

- 日期：2026-07-10
- 目标分支：`main`
- 功能分支：`feat/account-features`
- 分叉基线：`4217dbd5ce762e3d5a488a481cd884d14e585712`

## 1. 结论先行

本分支在现有 Google 登录、RevenueCat 会员和 Cloudflare Worker/D1 基础上，完成了第一版可审核的账号资料、训练记录云同步、历史记录归属、运动广场排行榜和可重复 D1 迁移，并针对账号切换、异步竞态、重复请求、时区变化、排行榜授权窗口和并发配额做了系统加固。

本分支保持本地优先：训练结束先写本地，云同步失败不阻止训练完成；新记录绑定训练发生时的账号，旧的无归属记录必须由用户明确确认后才可绑定。识别算法和回放夹具不在本分支变更范围内。

本报告之外，本分支相对分叉点包含 27 个功能、修复和设计/计划提交。当前本地 `main` 已在分叉点之后增加 2 个计数算法重设计提交，因此审核或合并前必须先整合最新 `main`，并重新执行完整验证，不能用本分支覆盖 `main` 的识别改动。

## 2. 新增能力

### 2.1 账号公开资料

- `AppUser`、`/auth/google` 和 `/me` 增加 `nickname`、`avatarKey`。
- 新增 `PATCH /me/profile`，App 个人页可编辑昵称和预设头像。
- 昵称支持中英文字母、数字、空格、下划线和连字符；拒绝控制字符、纯标点和保留名称。
- 昵称唯一性由 D1 约束守护；昵称修改有 30 天冷却，冷却期内仍允许只换头像。
- Worker 错误码在客户端保留并映射为中英文 UI 文案，不向用户展示后端异常原文。
- `AccountController` 增加 generation 守卫，旧的登录、恢复、资料更新、购买或恢复购买结果不能覆盖退出登录或更新后的账号。

关键文件：

- `lib/control/account_controller.dart`
- `lib/platform/membership_api_client.dart`
- `lib/ui/pages/profile_page.dart`
- `workers/membership-api/src/profile.ts`

### 2.2 本地训练事实、账号归属和云同步

- `WorkoutSession` 持久化 UTC `startedAt`/`endedAt`、训练发生时的 `localDate`、`timezoneOffsetMinutes` 和可空的 `ownerAppUserId`。
- 老版本 JSON 保持可读；老记录默认无归属，不会在登录后自动认领。
- 本地存储写操作串行化，避免并发 append、状态更新或云端合并丢记录。
- 同 ID 合并保持本地记录优先，云端独有记录追加到历史。
- 新增同步状态和 `WorkoutSyncController`；上传只读取已持久化事实，不根据当前设备时区重新推导。
- 同步捕获账号与 token，每个异步边界后重新校验账号身份；A 的待同步记录不会被 B 上传或回写。
- 并发同步请求合并为一个进行中的 Future；同步过程中切换账号时，会继续排空新账号的待处理触发。
- 免费账号的新训练仍绑定账号但只保留本地；Premium 激活、登录/恢复和训练入队会机会式触发上传。
- 个人页提供 Premium 专属“同步本机历史”确认流程，确认后才给旧的无归属记录绑定当前账号。
- 记录页合并云端记录，并显示待同步数量；云端失败时本地记录仍正常展示。

关键文件：

- `lib/product/workout_session_store.dart`
- `lib/control/workout_sync_controller.dart`
- `lib/ui/pages/workout_page.dart`
- `lib/ui/pages/records_page.dart`
- `workers/membership-api/src/workouts.ts`

### 2.3 运动广场排行榜

- 新增日榜/周榜模型、客户端、Controller 和页面。
- 新增 Worker 路由：
  - `POST /leaderboard/join`
  - `POST /leaderboard/leave`
  - `GET /leaderboard`
- 首页区分未登录、免费会员、Premium 未加入、Premium 已加入四态；已加入时可展示本人当日排名和数量。
- 个人页展示排行榜授权状态，并提供退出榜单操作。
- 已加入但当前为 0 分的用户仍可退出。
- 周期切换或账号切换会立即清空旧快照/错误，避免展示上一周期或上一账号的数据。
- 加入要求当前 Premium；榜单查询只包含会员仍有效且当前已加入的用户。
- 重复加入保持原 `joined_at` 和积分；退出后重新加入会更新授权窗口并清空本人当前上海周聚合，旧训练不会复活到新窗口。

关键文件：

- `lib/product/leaderboard_models.dart`
- `lib/control/leaderboard_controller.dart`
- `lib/ui/pages/leaderboard_page.dart`
- `workers/membership-api/src/leaderboard.ts`

### 2.4 Worker 数据边界与并发安全

- 新增 `POST /workouts/sync` 和 `GET /workouts`。
- 单条训练最大 1000 次；上海排行榜日累计上限 5000 次。
- 校验批量长度、客户端 session ID、UTC 时间、未来结束时间，以及 `startedAt + timezoneOffsetMinutes` 与 `localDate` 的一致性。
- workout 插入与排行榜聚合在数据库批处理中执行；重复 session 不消耗配额。
- 聚合写入时重新检查当前排行榜授权和 `joined_at`，不信任请求开始时的快照。
- 离开榜单与同步并发时，训练历史仍保存，但不会进入已失效的排行榜授权窗口。
- 会员过期、重复加入、退出后重入、乱序同步和并发配额均有路由测试与真实 SQLite/D1 SQL 测试。

### 2.5 可重复 D1 迁移

- 新增：
  - `migrations/0001_membership_baseline.sql`
  - `migrations/0002_account_data_leaderboard.sql`
- `schema.sql` 只作为最新空库快照，不再作为旧库升级入口。
- `npm run migrate` 明确带 `--remote`；本地测试使用 `migrate:local`，避免命令语义含糊。
- 迁移测试直接运行项目内安装的 Wrangler，不依赖 shell，也不硬编码 Miniflare 内部 D1 hash。
- 自动验证空库首次迁移、二次执行无变更、旧会员库升级且原数据不丢失。

### 2.6 设备验收收尾修复

- 训练页所有可见文案接入 zh/en ARB；control 层继续不依赖 `AppLocalizations`，UI 层映射已知训练状态并对未知错误使用通用文案。
- 训练页统计行允许在底部安全区内收缩，修复 API 35 模拟器 411×914dp 下 `BOTTOM OVERFLOWED BY 8.3 PIXELS`。
- 新增对应 widget 回归测试，精确模拟 1080×2400、420dpi 和 24dp 底部安全区。

## 3. 关键产品与安全语义

审核时应保持以下约束不变：

1. 本地训练保存优先于云同步，网络失败不能阻止训练完成。
2. 记录归属使用训练发生时捕获的账号，不使用同步时的当前账号。
3. 旧的无归属历史必须显式确认，不能自动认领。
4. 客户端会员状态只控制即时 UI；需要保护的写操作由 Worker 再检查会员和排行榜授权。
5. 排行榜授权是时间窗口：退出前或重新加入前的旧训练不能进入新窗口。
6. session 幂等、日配额和授权检查必须在 D1 写入边界成立，不能只靠请求前查询。
7. Google Client ID、RevenueCat key、Worker secret 和 Cloudflare token 不进入代码、测试、日志或本报告。

## 4. 验证证据

本报告提交前重新执行：

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，216/216 |
| 回放基线 | PASS，Step0=5 / video3=5 / video4=3 |
| `flutter build apk --release --split-per-abi` | PASS，3 ABI |
| Worker `npm test` | PASS，85/85，含 TypeScript check 与 build |
| 本地真实 Wrangler/D1 迁移 | PASS，空库、二次执行、旧库升级 |
| API 35 模拟器 debug 覆盖安装 | PASS |
| 英文/深色训练页与底部安全区 | PASS，无 overflow |
| 相机初始化、MoveNet 覆盖点、训练进入/退出、前后台恢复 | PASS（虚拟相机，不作为识别准确率结论） |
| `git diff --check` | PASS |

Release 产物：

- `app-armeabi-v7a-release.apk`：约 105.4 MB
- `app-arm64-v8a-release.apk`：约 74.1 MB
- `app-x86_64-release.apk`：约 83.4 MB

APK、截图和日志均为本地临时产物，不纳入 Git。

## 5. 未覆盖与明确未执行

- 未执行真实 Google OAuth、RevenueCat 购买/恢复、Premium 激活、云同步和排行榜 join/leave；当前会话没有注入真实凭证或受控后端状态。
- 未进行真实购买。
- 未运行远端 D1 migration、Worker 部署、推送或合并。
- 模拟器虚拟相机只验证初始化和失败不崩溃，不代表识别准确率或真实相机性能。
- Cloudflare API token 曾在历史会话暴露的事项仍需人工确认已轮换；本分支没有写入任何 token。

## 6. `main` 审核重点

建议审核者优先检查：

1. `WorkoutSessionStore` 的不可变训练事实、owner 过滤、串行写和本地优先合并。
2. `WorkoutSyncController` 与 `AccountController` 的账号/generation 守卫，尤其是 await 后的身份复核。
3. `workers/membership-api/src/workouts.ts` 的原子配额 SQL、重复 session 行为，以及 leave/rejoin 并发时“保存历史但不聚合”的语义。
4. `leaderboard.ts` 的会员有效性、重复 join 和重新加入清周聚合逻辑。
5. D1 migration 的旧库兼容性，以及 `npm run migrate` 默认明确指向 remote 是否符合发布流程。
6. UI 错误码本地化、账号/周期切换清旧状态，以及训练页 UI 对 control 状态字符串的映射边界。

## 7. 合并前置条件

当前本地分支关系为：`main` 比本分支多 2 个提交，本分支比 `main` 多 27 个功能/计划提交（不含本报告提交）。`main` 的新增提交是：

- `546e6f5 feat: pushup counting redesign — count on up-return + close-range tolerance`
- `6a99101 docs: record pushup counting redesign (up-return + close-range tolerance)`

因此审核完成后应先把最新 `main` 整合进本分支或在目标合并结果上解决差异，然后至少重新执行：

```powershell
flutter analyze
flutter test
flutter build apk --release --split-per-abi
Set-Location workers/membership-api
npm test
```

合并结果仍必须保持回放基线 5/5/3，并确认 `main` 的计数算法重设计未被回退。

## 8. 相关设计与计划

- `docs/superpowers/specs/2026-07-09-account-data-leaderboard-design.md`
- `docs/superpowers/plans/2026-07-09-account-data-leaderboard.md`
- `docs/plans/2026-07-10-account-features-hardening.md`
- `docs/modules/membership.md`
- `docs/development-guide.md`
