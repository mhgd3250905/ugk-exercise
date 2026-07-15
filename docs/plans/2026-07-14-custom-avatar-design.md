# 自定义头像与公开头像治理设计

日期：2026-07-14
状态：已实现并完成 production Debug 主链路验收；生产依赖、Play 边界和持续审核责任见 `docs/modules/membership.md`、`docs/testing-release-playbook.md` 与 `docs/release-configuration.md`

## 1. 目标

为所有已登录用户提供一个账号级自定义头像：用户可以从系统相册选择或现场拍照，完成 1:1 拖动、缩放和裁剪后上传。这个头像在非匿名场景中具有最高优先级，个人资料页与运动广场共用，不再维护榜单专用头像。

自定义图片会在运动广场向其他用户公开，因此本功能同时包含最低限度的公开 UGC 治理：上传前接受用户内容规则、App 内举报与屏蔽、管理员人工审核、头像下架、限制继续上传，以及账号删除时清理图片对象。

## 2. 已确认的产品规则

- 所有已登录用户都可上传，不要求 Premium。
- 相册选择和现场拍照都支持；不申请整个媒体库的广泛访问权限。
- 上传前必须进入现成裁剪组件，支持拖动、缩放和固定 1:1 裁剪。
- 每个账号只有一个当前自定义头像。
- 非匿名头像优先级固定为：有效自定义头像 → App 内置头像 → Google 头像 → 安全默认头像。
- 删除自定义头像只删除上传图片；之后优先回退到已选内置头像，没有内置头像时才显示 Google 头像。
- 运动广场只保留“使用个人资料”和“匿名参加”两种身份。
- 匿名参加始终使用系统匿名头像，绝不暴露账号头像。
- 当前只有一个测试用户，不保留旧“榜单专用身份”的产品兼容分支。迁移把已有 `custom` 身份切换为 `profile`，Worker 此后拒绝 `custom`。
- 公开图片不做上传前全量预审。举报后立即对举报者隐藏，进入人工审核队列，由管理员决定驳回、下架、隐藏公开网络头像或限制继续上传。
- 审核入口使用 Cloudflare Access 保护的内部页面，不在 App 中加入管理员角色。

## 3. 非目标

- 不保留榜单专用昵称或榜单专用头像。
- 不增加评论、点赞、关注、私信、用户主页或完整社交系统。
- 不做客户端直传签名 URL、多尺寸派生、独立媒体服务或 Cloudflare Images。
- 不接第三方 AI 图片审核服务。
- 不做复杂管理后台；首版只提供审核队列和必要处置动作。
- 不改变会员资格、训练同步、排行榜计分或识别算法。

## 4. 技术方案

继续使用现有 Flutter App + Cloudflare Worker/D1，并新增一个私有 R2 bucket。

- Flutter 使用官方 `image_picker` 获取相册图片或调用相机。
- Flutter 使用 `image_cropper` 提供原生拖动、缩放和裁剪界面。
- 客户端统一输出 512×512 JPEG；初始压缩质量和服务端大小上限作为集中常量维护。
- App 携带现有账号 session，把裁剪结果直接上传到现有 Worker。
- Worker 通过 R2 binding 读写私有 bucket，不使用 R2 REST API、S3 SDK、访问密钥或公开 bucket。
- D1 保存图片所有权、版本、状态、条款接受、举报、屏蔽和审核记录；不保存图片二进制。
- Worker 通过不可猜测的版本化 URL 提供当前有效头像，排行榜只返回服务端已解析的最终公开字段。

不采用预签名直传：头像文件很小，直传会额外引入签名、完成确认、失败回收和更多客户端状态。也不采用 Cloudflare Images：当前没有多尺寸转换的真实需求，新增费用和供应商合同不能减少 UGC 治理责任。

## 5. D1 数据模型

新增 `0004_custom_avatar_ugc.sql`，并同步更新 `schema.sql` 快照和迁移测试。

### 5.1 users 扩展

- `custom_avatar_object_id`：当前自定义头像对象，可空。
- `public_avatar_hidden_at`：管理员隐藏该账号公开网络头像的时间，可空。
- `avatar_upload_suspended_at`：管理员禁止该账号继续上传的时间，可空。

`avatar_url` 继续只表示 Google 资料图片，`avatar_key` 继续表示 App 内置头像，不能覆写两者原有语义。

### 5.2 avatar_objects

记录所有已登记的 R2 头像对象：

- `id`
- `user_id`
- `object_key`，随机且唯一，不把用户 ID 当公开路径
- `status`：`active`、`replaced` 或 `removed`
- `created_at`
- `deleted_at`

该表让替换失败、审核下架和账号删除都能定位对象。正常替换后旧对象立即删除；若删除暂时失败，记录仍保留，允许后续清理，不让对象变成无法追踪的孤儿。

### 5.3 avatar_policy_acceptances

- `user_id`
- `policy_version`
- `accepted_at`
- 主键：`user_id + policy_version`

Worker 只接受当前条款版本。版本更新后，用户必须重新确认才能再次上传。

### 5.4 avatar_reports

- `id`
- `reporter_user_id`
- `reported_user_id`
- `report_type`：`avatar` 或 `user`
- `avatar_object_id`，举报自定义头像时保存具体版本，可空
- `avatar_source`：`custom`、`google` 或 `none`
- `reason`
- `status`：`open`、`dismissed`、`actioned` 或 `stale`
- `created_at`、`resolved_at`、`resolved_by`、`resolution`

同一举报者对同一用户、同一头像版本重复提交时保持幂等。

### 5.5 user_blocks

- `blocker_user_id`
- `blocked_user_id`
- `created_at`
- 主键：`blocker_user_id + blocked_user_id`

屏蔽是单向的，只影响屏蔽者看到的排行榜结果，不改全局成绩和他人的排名。

### 5.6 avatar_moderation_actions

记录不一定依附于单个举报的管理员动作：操作者、目标用户、头像版本、动作、时间和结果。它用于审计下架、恢复公开头像、暂停上传和恢复上传。

### 5.7 退休字段

`leaderboard_profiles.leaderboard_nickname`、`leaderboard_nickname_key` 和 `leaderboard_avatar_key` 不再被业务代码读写。为避免一次无价值的 D1 表重建，物理列可以暂时保留，但 `0004` 会把已有 `identity_mode = 'custom'` 改为 `profile` 并清空退休字段。新 API 模型只接受 `profile` 和 `anonymous`。

## 6. 统一头像解析

服务端和 Flutter 使用同一语义：

1. `anonymous`：返回稳定系统匿名头像。
2. 非匿名且 `public_avatar_hidden_at` 不为空：公开场景返回安全默认内置头像。
3. 当前 `avatar_objects` 对象有效：返回自定义头像 URL。
4. `avatar_key` 有效：返回内置头像 key。
5. Google `avatar_url` 有效：返回 Google 网络头像。
6. 全部缺失：返回安全默认内置头像。

`AppUser` 新增独立的 `customAvatarUrl` 和头像上传/条款状态，不改变 `avatarUrl` 的 Google 语义。个人页需要知道当前是否存在自定义头像，以决定是否展示“删除自定义头像”。

排行榜仍由 Worker 解析最终允许公开的 `avatarKey`/`avatarUrl`；Flutter 不自行推断隐私状态。个人资料页、排行榜预览和排行榜行统一复用一个头像 Widget，避免三处维护不同优先级。

## 7. 上传、替换和读取

### 7.1 App 流程

1. 用户选择“从相册选择”或“拍照”。
2. 取消选择、拍照或裁剪时直接返回，不修改资料。
3. 裁剪页固定 1:1，输出 512×512 JPEG。
4. 首次上传或条款版本变化时展示用户内容规则，用户主动勾选后记录接受。
5. App 调用上传接口，上传期间阻止重复提交。
6. 成功后用 Worker 返回的 `AppUser` 更新本地账号缓存。

`AccountController` 的上传、删除和条款接受方法必须沿用现有 generation/account 守卫，每个 `await` 后确认仍是同一账号，过期请求不能覆盖新登录账号。

### 7.2 Worker 信任边界

客户端裁剪和压缩只改善体验，不能替代服务端校验。Worker 必须检查：

- 有效 app session；
- 已接受当前条款版本；
- 账号未被暂停上传；
- `Content-Type` 为 JPEG；
- 使用受限读取器按实际字节计数，不能只相信 `Content-Length`；
- JPEG 魔数和尺寸头有效；
- 图片为正方形且不超过服务端最大尺寸；
- 实际字节数不超过集中配置的上限。

首版不引入通用图片解析框架；只接受客户端标准化后的 JPEG，服务端拒绝 PNG、WebP、HEIC 和伪造文件。

### 7.3 原子性与对象生命周期

1. 生成随机对象 ID/key。
2. 先把新 JPEG 写入 R2。
3. D1 batch 登记新对象、切换 `users.custom_avatar_object_id`，并把旧对象标为 `replaced`。
4. D1 失败时删除刚写入的新 R2 对象，旧头像不变。
5. D1 成功后删除旧 R2 对象并标记 `deleted_at`。

删除自定义头像时先让 D1 停止返回该 URL，再删除 R2；即使删除暂时失败，旧 URL 也不能继续由 Worker 提供。

### 7.4 头像读取

`GET /avatars/{random-id}.jpg` 不要求登录，因为头像用于公开排行榜，但 Worker 必须先确认对象仍为有效公开版本，再从 R2 流式返回。响应带正确 `Content-Type`、ETag 和适中的公共缓存时间。URL 每次替换都会变化，因此普通更新不需要缓存清除；缓存时间不能无限长，以免妨碍审核下架生效。

## 8. API 合同

### POST /me/avatar-policy/accept

请求 JSON：`policyVersion`。只接受 Worker 当前版本，幂等写入接受记录。

### PUT /me/avatar

请求体为原始 JPEG 字节，使用现有 Bearer session。成功返回更新后的 `user`。主要错误：

- `avatar_policy_required`
- `avatar_upload_suspended`
- `avatar_too_large`
- `invalid_avatar_format`
- `invalid_avatar_dimensions`
- `avatar_upload_failed`

### DELETE /me/avatar

删除当前自定义头像并返回更新后的 `user`。没有自定义头像时幂等成功。

### GET /avatars/{random-id}.jpg

仅返回仍有效且允许公开的对象；不存在、已替换、已下架或被隐藏时返回 404。

### POST /leaderboard/users/{userId}/report

请求包含受控原因枚举和可选短说明。服务端快照当前公开头像来源/版本，并在同一操作中把目标用户加入举报者的屏蔽列表，因此举报成功后立即从该用户的排行榜视图消失。禁止举报自己。

### PUT /me/blocks/{userId}

单独屏蔽用户，幂等成功。

### DELETE /me/blocks/{userId}

取消屏蔽，幂等成功。

### /admin/avatar-reports/*

提供审核队列和 POST 处置动作：驳回、下架当前自定义头像、隐藏公开网络头像、暂停上传、恢复公开头像和恢复上传资格。不提供通用 SQL 控制台。

## 9. App UI

### 9.1 个人资料编辑

- 顶部显示统一头像。
- 提供“从相册选择”和“拍照”。
- 存在自定义头像时显示“更换”和“删除自定义头像”。
- 内置头像区标记为删除自定义头像后的回退选择，避免用户误以为选择后会覆盖最高优先级头像。
- 上传只显示局部 busy/progress；失败保留原头像并允许重试。
- 用户可见文案全部进入 zh/en ARB。

### 9.2 运动广场身份

身份弹窗只保留：

- 使用个人资料：当前账号昵称和统一头像；
- 匿名参加：匿名昵称和稳定系统匿名头像。

删除榜单专用昵称输入框、榜单头像选择区和相应模型分支。

### 9.3 举报和屏蔽

每条非本人排行榜记录提供菜单：

- 举报头像/用户；
- 屏蔽用户。

举报流程只要求选择简短原因，失败时不误报成功。屏蔽后列表立即移除目标行；全局名次不重算，可能出现名次数字跳号，这是正确结果。

## 10. 管理员审核

审核页使用现有 Worker 输出的极简服务端 HTML，不新增前端框架或 App 管理员角色。Cloudflare Access 应用默认拒绝，只允许明确指定的管理员身份。

Access 负责入口认证，Worker 仍必须验证 `Cf-Access-Jwt-Assertion` 的签名、issuer 和 audience，不能只检查请求头存在。复用 Worker 已安装的 `jose`，不增加第二套 JWT 依赖。变更动作只接受同源 POST，并检查请求来源，防止跨站提交。

队列展示举报时间、原因、头像版本和目标账号。若被举报头像已被用户替换，报告标为 `stale`，管理员不能误删新头像。

处置规则：

- 驳回：头像不变，关闭报告；
- 下架自定义头像：D1 立即停止返回，删除 R2，账号回退；
- 隐藏公开网络头像：用于 Google 等非 R2 网络头像，排行榜改用安全默认头像；
- 暂停上传：用户仍可删除头像，但不能上传或替换；
- 恢复：必须是明确管理员动作并留下审计记录。

## 11. UGC、隐私和删除

公开头像上线前必须：

- 发布版本化用户内容规则，定义并禁止不当内容与行为；
- 在上传前取得明确接受；
- 提供 App 内举报内容/用户和屏蔽用户；
- 建立持续可执行的人工审核和处置流程；
- 更新隐私政策，说明图片的收集、存储、公开展示、保留和删除；
- 重新核对 Google Play Data safety 与内容分级中的 UGC 声明。

现有账号删除入口可以继续跳转到外部删除说明/请求页面，但实际删除流程必须查询 `avatar_objects`，删除该账号所有 R2 对象和关联 D1 记录。只删除 `users.custom_avatar_object_id` 不算完整删除。

## 12. 测试策略

### 12.1 Worker/D1

- `0004` 从迁移链和空库快照得到一致 schema。
- 旧 `custom` 身份迁移为 `profile`，退休字段清空。
- 未登录、未接受条款、暂停上传均被拒绝。
- 大小、JPEG 魔数、尺寸、非正方形和截断请求校验。
- R2 写入失败、D1 失败和旧对象删除失败的状态一致性。
- 上传、替换、删除和读取的 URL/version 行为。
- 举报幂等、自举报拒绝、屏蔽/取消屏蔽和排行榜过滤。
- 被屏蔽用户不显示，但全局排名不被改写。
- 已替换报告标为 stale，管理员不能删除新对象。
- 未经 Access 或 JWT 无效的管理请求返回 401/403。
- 下架、隐藏、暂停和恢复都有审计记录。
- 账号删除能定位并清理全部头像对象。

### 12.2 Flutter

- `AppUser` JSON 与缓存兼容，头像优先级正确。
- API client 发送原始 JPEG 并映射错误码。
- AccountController 在上传、删除和条款接受后保留账号/generation 守卫。
- 相册、拍照、裁剪取消不改变资料。
- 上传失败保留旧头像，删除后按内置 → Google 回退。
- 资料页浅/深色、中英文和加载失败兜底。
- 排行榜只显示个人资料/匿名两种身份。
- 举报、屏蔽、取消屏蔽和错误重试。
- 统一头像 Widget 在个人页、预览和排行榜行一致。

### 12.3 全量与真机

本地必须运行：

```powershell
flutter analyze
flutter test
cd workers/membership-api
npm test
git diff --check
```

回放基线保持 step0=5、v3=5、v4=3。

真机验证：相册、相机、裁剪、替换、删除、取消、断网重试、缓存更新、公开榜单、匿名例外、举报、屏蔽和管理员下架。Release 合并清单不得新增 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `READ_EXTERNAL_STORAGE`。

## 13. 上线与授权顺序

远程上线顺序：

1. 更新用户内容规则、隐私政策和账号删除流程。
2. 创建私有 R2 bucket。
3. 应用 D1 `0004` migration。
4. 配置 R2 binding 和 Cloudflare Access 审核应用。
5. 部署 Worker，验证公开 API、R2、Access 拒绝和审核动作。
6. 真机验收完整 App/Worker 链路。
7. 更新 Play Data safety、UGC/内容分级声明。
8. 构建同一候选 AAB，先内部测试，再推进 Alpha。

创建 R2、D1 migration、Access 配置、Worker/Pages 部署、Play 表单修改、AAB 上传和轨道推进都必须分别获得明确授权。设计确认不等于任何远程写入授权。

## 14. 回滚

- App 回滚：旧 App 仍可读取账号和排行榜，但已删除的榜单专用身份不可恢复；当前仅一个测试用户，接受该不兼容。
- Worker 回滚：只有在回滚版本不会读取新 App 合同的前提下执行；新 App 发布后不单独回滚到完全不认识头像字段的 Worker。
- R2/D1：停止新上传后可让 Worker忽略新字段；迁移不立即删除表和列，避免数据破坏。
- 审核下架优先通过 D1 状态阻止 URL 返回，再删除 R2，避免对象删除失败导致继续公开。

## 15. 成功标准

- 登录用户能从相册或相机选择、裁剪、上传、替换和删除一个账号头像。
- 所有非匿名页面按统一优先级显示同一个头像；匿名身份不泄露账号头像。
- Worker 在信任边界完成格式、实际大小和尺寸校验。
- 替换或失败不会丢失上一张有效头像，也不会产生无法追踪的对象。
- 举报后目标立即对举报者隐藏，管理员可以安全处置且不能误删新版本。
- 未授权用户无法访问或调用审核功能。
- 账号删除覆盖全部 R2 图片对象。
- 自动化、回放基线和真机验收通过，且没有新增广泛媒体权限。
- Play 相关 UGC、Data safety、隐私和删除声明在发布前完成。
