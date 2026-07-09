# 账号数据同步与运动广场榜单设计

日期：2026-07-09

## 结论

第一版做 **账号资料同步 + 会员运动数据云同步 + 运动广场里的俯卧撑项目日榜/周榜**。

核心规则：

- 本地训练永远优先。云同步失败不能阻塞训练、本地保存、本地记录查看。
- 免费账号只同步公开资料：昵称和 App 内置头像。
- 会员账号解锁运动记录云同步、历史补传、运动广场榜单。
- 榜单默认不公开。用户主动加入后，之后的新训练才参与排行。
- 首版只展示俯卧撑榜单，但运动记录模型保留 `exercise_type`，不把数据结构写死为俯卧撑。

## 用户能理解的产品边界

### 免费账号

- 可以 Google 登录。
- 可以设置唯一昵称。
- 可以选择 App 内置头像。
- 资料跟账号同步。
- 运动记录仍只在本机。

### 会员账号

- 训练记录可上传到云端。
- 升级会员后，本机历史训练会自动补传到个人云记录。
- 云上传失败不影响 App 本地使用，稍后后台重试。
- 会员过期后，已上传云端历史仍可查看；新的训练不再上传。

### 运动广场榜单

- 只有会员能加入榜单。
- 用户默认不加入，也不会公开历史训练。
- 用户加入榜单后，之后的新训练才进入公开排行。
- 榜单只展示昵称、内置头像、个数、排名。
- 不展示邮箱、Google 头像、会员状态。
- 首版不做点赞、关注、评论。

## 非目标

第一版不做：

- 图片头像上传、对象存储、头像审核。
- 好友榜、小组榜、同城榜、地区榜。
- 点赞、关注、评论、私信、举报体系。
- 多动作 UI。数据结构预留 `exercise_type`，但 UI 只展示俯卧撑。
- 训练视频、关键点、姿态摘要上传。
- Redis/KV 排行缓存。D1 能撑住首版。

## 架构

继续复用现有 Flutter App + Cloudflare Worker/D1 账号后端。

- Flutter 负责本地训练、本地记录、账号 UI、同步队列触发。
- Worker 负责资料修改、会员校验、云端记录写入、榜单聚合和查询。
- D1 保存用户资料、会员快照、云端运动记录、榜单公开状态和日聚合。
- RevenueCat 继续作为会员权益来源，Worker 通过现有 `membership_snapshots` 判断服务端权益。

不新增独立服务。首版不引入 Redis/KV/对象存储。

## 术语

- **本地记录**：App 写入本机 `WorkoutSessionStore` 的训练记录。未登录、免费、离线都可用。
- **云端个人记录**：会员同步到 D1 的私有训练记录。用于跨设备历史和云端恢复。
- **公开榜单记录**：用户加入榜单后，新训练产生的公开聚合数据。
- **加入榜单**：用户主动同意把之后的新训练计入公开排行。
- **榜单时区**：公开榜单使用固定产品时区，首版为 `Asia/Shanghai`。用户本地日期只用于个人记录页。

## 权益规则

| 能力 | 免费账号 | 会员账号 |
|------|----------|----------|
| 登录 | 是 | 是 |
| 修改昵称和内置头像 | 是 | 是 |
| 资料同步 | 是 | 是 |
| 本地训练和本地记录 | 是 | 是 |
| 云端运动记录同步 | 否 | 是 |
| 会员升级后补传历史 | 否 | 是 |
| 加入运动广场榜单 | 否 | 是 |
| 查看已上传云端历史 | 否；曾是会员的账号可看旧数据 | 是 |

会员过期后：

- 本地训练继续可用。
- 本地记录继续可看。
- 已上传云端历史保留并可查看。
- 新训练不再上传。
- 不再参与当前活跃榜单。

## 数据模型

### users

复用现有表，保留 Google 登录资料，不直接把 `display_name` 改成唯一公开昵称。

新增字段：

- `nickname`：公开昵称。
- `nickname_key`：昵称规范化后的唯一键，用于大小写/空格归一后的唯一校验。
- `avatar_key`：App 内置头像 key。
- `nickname_updated_at`：上次改昵称时间。

规则：

- `nickname_key` 唯一。
- 首次设置昵称不受 30 天限制，后续 30 天可改一次。
- 新用户默认昵称可以从 Google 名字生成，但必须处理冲突。
- 公开展示优先使用 `nickname` 和 `avatar_key`。

### workout_sessions

会员云端个人记录。

字段：

- `id`
- `user_id`
- `client_session_id`
- `exercise_type`
- `started_at`
- `ended_at`
- `duration_seconds`
- `local_date`
- `timezone_offset_minutes`
- `ranking_date`
- `metric_value`
- `metric_unit`
- `created_at`

约束：

- 唯一：`user_id + client_session_id`。
- 首版 `exercise_type = pushup`。
- 首版 `metric_unit = reps`。
- 首版 `metric_value` 表示俯卧撑个数。

说明：

- `local_date` 用于个人记录页，按用户训练时本地日期归属。
- `ranking_date` 用于公开榜单，按固定榜单时区归属。
- 以后深蹲、卷腹等计数型动作可以复用 `metric_value + reps`。
- 跑步、骑行这类多指标运动以后再加专门字段或子表，不在首版预埋复杂 JSON。

### leaderboard_profiles

用户是否加入公开榜单。

字段：

- `user_id`
- `is_joined`
- `joined_at`
- `left_at`
- `updated_at`

规则：

- 默认不存在或 `is_joined = 0`。
- 用户主动加入后设为 `is_joined = 1` 和当前 `joined_at`。
- 用户退出后设为 `is_joined = 0`，不删除个人云记录。
- 重新加入后，从新的 `joined_at` 之后开始计入榜单。
- 首版只展示当前日/当前周榜单；重新加入时清理当前榜单周内该用户旧聚合，避免旧公开周期混入新排名。

### leaderboard_daily_totals

公开榜单日聚合。

字段：

- `user_id`
- `exercise_type`
- `ranking_date`
- `total_value`
- `last_session_at`
- `updated_at`

约束：

- 唯一：`user_id + exercise_type + ranking_date`。

规则：

- 只在训练记录首次 accepted 时累加。
- 重复同步不重复加分。
- 查询榜单时过滤当前会员 active、已加入榜单的用户。
- 周榜不单独存表，从当前榜单周内每日聚合求和。

## API

### PATCH /me/profile

修改公开资料。

请求：

- `nickname`
- `avatarKey`

处理：

1. 校验 app session。
2. 校验昵称长度、字符、保留词。
3. 生成 `nickname_key` 并做唯一校验。
4. 校验距离上次改昵称是否已满 30 天。
5. 校验 `avatarKey` 是 App 支持的内置头像。
6. 更新用户公开资料。

常见错误：

- `nickname_taken`
- `nickname_change_too_soon`
- `invalid_nickname`
- `invalid_avatar_key`

### POST /workouts/sync

会员批量同步运动记录。

训练结束时可以只传 1 条；会员升级补传历史时传多条。

请求每条记录包含：

- `clientSessionId`
- `exerciseType`
- `startedAt`
- `endedAt`
- `localDate`
- `timezoneOffsetMinutes`
- `metricValue`
- `metricUnit`

处理：

1. 校验 app session。
2. 校验当前账号具备会员权益。
3. 对每条记录独立校验。
4. 用 `user_id + client_session_id` 幂等写入 `workout_sessions`。
5. 只有首次 accepted 的记录才可能更新榜单聚合。
6. 若用户已加入榜单，且 `ended_at >= joined_at`，更新 `leaderboard_daily_totals`。

响应：

- 每条返回 `accepted`、`duplicate` 或 `rejected`。
- `rejected` 带原因，不让一条坏数据卡住整批。

常见错误：

- `premium_required`
- `invalid_exercise_type`
- `invalid_metric`
- `invalid_duration`
- `daily_limit_exceeded`

### GET /workouts?month=YYYY-MM

读取自己的云端个人记录。

规则：

- 需要登录。
- 已上传过云端记录的过期会员仍可读取旧数据。
- 返回私有数据，不参与公开榜单判断。

### POST /leaderboard/join

加入公开榜单。

处理：

1. 校验 app session。
2. 校验当前账号是会员。
3. 写入 `leaderboard_profiles.is_joined = 1` 和新的 `joined_at`。
4. 不回填历史训练。

### POST /leaderboard/leave

退出公开榜单。

处理：

1. 校验 app session。
2. 设置 `is_joined = 0` 和 `left_at`。
3. 不删除个人云记录。
4. 后续查询榜单不展示该用户。

### GET /leaderboard?period=day|week&exerciseType=pushup

读取公开榜单。

响应：

- Top 100。
- 我的排名。
- 每项包含昵称、头像 key、总个数、排名。

规则：

- 日榜按当前 `ranking_date`。
- 周榜按榜单时区的当前周，从日聚合求和。
- 查询时过滤未加入榜单、会员非 active 的用户。
- 首版只支持 `exerciseType=pushup`。

## 客户端流程

### 训练结束

1. `WorkoutPage` 停止训练并生成本地 `WorkoutSession`。
2. `WorkoutSessionStore.append(session)` 写本地 JSON。
3. 本地保存成功后，用户可以立即返回首页。
4. 如果当前是会员账号，把该 session 标记为待同步。
5. 后台同步器稍后调用 `POST /workouts/sync`。

硬约束：

- 云同步不阻塞训练结束。
- 云同步失败不显示全局错误。
- 云同步失败不影响本地记录页。

### 登录与免费账号

1. 用户登录 Google。
2. App 恢复账号资料和会员状态。
3. 免费账号只同步昵称和头像。
4. 免费账号不上传运动记录。

### 升级会员

1. 会员状态变 active。
2. 后台扫描本地历史记录。
3. 批量补传到云端个人记录。
4. 不回填榜单。

### 加入榜单

1. 用户进入榜单页或首页榜单卡。
2. 如果未加入，展示加入确认。
3. 用户确认后调用 `POST /leaderboard/join`。
4. 之后的新训练才参与排行。

### 退出榜单

1. 用户在榜单页或个人页关闭公开排行。
2. 调用 `POST /leaderboard/leave`。
3. 榜单不再展示该用户。
4. 本地记录和云端个人记录不受影响。

## UI 变化

### 首页

新增“今日广场榜”卡片。

- 卡片弱于“开始训练”主入口。
- 未登录：提示登录后查看账号能力。
- 免费账号：提示会员可加入榜单。
- 会员未加入：提示加入榜单。
- 会员已加入：展示今日排名、今日个数、进入榜单。

### 个人页

新增：

- 昵称编辑。
- 内置头像选择。
- 榜单公开状态。
- 会员权益说明：云同步、榜单、高级统计。

### 记录页

- 本地记录继续可用。
- 会员账号可展示云端同步状态。
- 云端记录用于跨设备恢复和补全。
- 本地和云端合并时用 `clientSessionId` 去重。

### 榜单页

- 日榜 / 周榜切换。
- Top 100。
- 我的排名固定展示。
- 未加入时展示加入说明。
- 不做社交互动。

## 服务端校验

`POST /workouts/sync` 校验：

- 账号 session 有效。
- 当前会员 active。
- `exerciseType` 首版只接受 `pushup`。
- `metricUnit` 首版只接受 `reps`。
- `metricValue` 必须大于 0。
- `startedAt < endedAt`。
- 时长合理。
- 单次个数不超过上限。
- 每日总量不超过上限。

轻量防刷边界：

- 不上传视频、关键点、姿态摘要。
- 不做严格动作真实性服务端复验。
- 只用硬上限拦截明显异常数据。

## 异常处理

- 本地保存失败：训练页保留待保存 session，允许重试。这是唯一阻塞训练结束的保存错误。
- 云同步失败：保留待同步状态，后台重试，不影响本地功能。
- 会员过期：暂停新同步，旧云端记录可读。
- 昵称冲突：资料页提示昵称已被使用。
- 昵称改太频繁：提示下次可修改日期。
- 榜单加入失败：保持未加入，不影响本地训练和本地记录。

## 分层落点

按现有架构：

- `product/`：运动记录模型、同步状态模型、榜单数据模型。
- `control/`：账号资料编辑、同步编排、榜单状态编排。
- `platform/`：Worker API client 扩展。
- `ui/pages/`：首页榜单卡、个人资料编辑、榜单页、记录页同步状态。
- `workers/membership-api/`：D1 schema、路由、校验和聚合。

不改：

- `pushup_domain.dart`
- 识别算法
- 计数管线
- 回放夹具

## 测试策略

### Flutter

- 本地保存不因云同步失败阻塞。
- 免费账号不上传运动记录。
- 会员账号训练后生成待同步记录。
- 会员升级后触发历史补传。
- 本地和云端记录按 `clientSessionId` 去重。
- 首页榜单卡在未登录、免费、会员未加入、会员已加入状态下展示正确。

### Worker

- 昵称唯一。
- 昵称 30 天限制。
- 头像 key 白名单。
- 批量同步部分成功。
- 重复同步不重复加榜单。
- 非会员不能同步新记录。
- 未加入榜单时只写个人云记录。
- 加入前历史不回填榜单。
- 退出榜单后查询不展示。
- 日榜 Top 100 + 我的排名。
- 周榜从日聚合求和。

### 回归

每次实现后运行：

```bash
flutter analyze
flutter test
cd workers/membership-api && npm test
```

账号数据和榜单不应改变回放基线：Step0=5 / video3=5 / video4=3。

## 推进顺序

1. 扩展 Worker schema 和资料接口。
2. 扩展 App 用户模型，做昵称和内置头像。
3. 增加云端运动记录 schema 和 `POST /workouts/sync`。
4. 增加本地同步状态和后台同步器。
5. 做会员升级后的历史补传。
6. 增加榜单加入/退出和日聚合。
7. 增加首页榜单卡和榜单页。
8. 做记录页云端历史合并。

每一步都保持本地训练和本地记录独立可用。
