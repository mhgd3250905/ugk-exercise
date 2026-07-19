# PushupAI 开发测试与发布手册

最后核对：2026-07-17

本文给后续开发者和 AI agent 使用，解决三个问题：

1. 改完功能后应该在哪里测试；
2. 哪些能力可以本地验证，哪些必须经过 Google Play；
3. 如何在不泄露密钥、不污染正式数据的前提下完成账号、排行榜和会员验收。

动态控制台状态、版本号、产物校验值和待办以 [release-configuration.md](release-configuration.md) 为准。本文只保存稳定流程，不重复维护易过期状态。

## 1. 先做测试分流

| 改动类型 | 本地自动化 | 本地真机/模拟器 | 内部测试 | Alpha |
|---|---:|---:|---:|---:|
| 纯算法、计数、门控 | 必须 | 重要改动需要 | 不需要 | 阶段性回归 |
| 普通 UI、主题、多语言、记录页 | 必须 | 建议 | 通常不需要 | 阶段性回归 |
| 相机、端侧推理、系统安全区 | 必须 | 必须 | 发布候选建议 | 阶段性回归 |
| 排行榜 UI/Controller/解析 | 必须 | 可用 fake 数据 | 不需要 | 阶段性回归 |
| 排行榜真实登录、加入、退出、云端名次 | 必须 | 条件允许时 | 推荐 | 必须抽查 |
| RevenueCat Test Store 权益流程 | 必须 | 可以 | 不需要 | 不适用 |
| Google Play 商品、购买、恢复、续订 | 必须 | 仅 License Tester 条件下 | 必须 | 发布前抽查 |
| OAuth Play 签名、Play 更新、RTDN/Webhook | 相关测试 | 不完整 | 必须 | 必须 |
| Worker/D1 | Worker 测试必须 | 可调用测试环境 | 相关改动需要 | 发布前抽查 |

判断原则：

- 不依赖 Google Play 签名、商品、购买或通知链的改动，先本地完成，不要为每次修改上传新版本。
- 一批功能稳定后生成一个更高 `versionCode`，先走内部测试，再把同一产物推进 Alpha。
- 正式数据链路只做必要抽查。不得把“本地 UI 正常”写成“Google Play 购买全链路通过”。

## 2. 每次开发的本地闭环

开始前：

```powershell
git status --short --branch
git log -5 --oneline
git diff --stat
git diff --cached --stat
```

开发时严格 TDD：先写失败测试，确认按预期失败，再写最小实现。

完成后：

```powershell
flutter analyze
flutter test
git diff --check
```

硬约束：

- 全量测试必须通过；回放基线必须保持 step0=5、v3=5、v4=3。
- 改了 `workers/membership-api/` 才额外运行：

  ```powershell
  cd workers/membership-api
  npm test
  ```

- 不使用 `git add -A`；显式 stage 本次文件。
- 不修改、删除或提交用户未跟踪的交接文件。
- 真实视频、CSV、截图、日志、APK/AAB 和设备序列号不进入 Git。

## 3. 本地安装能验证什么

本地 Debug 或 APK 适合验证：

- 相机预览、姿态推理、计数、语音和训练保存；
- 页面布局、系统安全区、浅/深色、中英文；
- 本地记录、周/月/年汇总；
- 使用 fake Controller/API 的账号、排行榜和会员 UI；
- 能直接访问的 HTTP 接口。
- 原生 Splash 与 Flutter 启动门衔接、首次/回访均直达首页，以及相机用途说明的确认和取消。

典型命令：

```powershell
flutter run
flutter build apk --debug
flutter build apk --release --split-per-abi --dart-define-from-file=<本机配置文件>
```

注意：Google Play 安装版使用 Play App Signing 证书，本地包使用 debug 或上传证书。签名不同的同包名应用不能互相覆盖；不要为了安装本地包擅自卸载用户的 Play 版本或清除数据。

启动与权限真机验收至少覆盖：首次安装和回访冷启动都不出现三页引导并直接进入首页、浅/深色冷启动无白屏闪烁、首页先显示本地账号缓存、断网仍可进入首页、点击训练后再申请相机权限，以及允许、拒绝、永久拒绝三种结果。自动化测试不能替代系统权限对话框和 Android 12+ Splash 的真机观察。

### 3.1 Release 运动测试日志验收

Play 安装版和本地 Release 都支持用户主动记录识别诊断，默认必须关闭。真机验收步骤：

1. 进入“个人 → 设置 → 识别诊断”，确认“运动测试日志”初始为关闭，说明明确写出仅本机保存、不含照片/视频/音频、最多保留 20 次；
2. 开启后进入一次训练，完成准备、有效动作和一次故意不完整动作，再正常结束训练；
3. 回到设置点击“导出运动测试日志”，在 Android 系统文件界面保存到“下载”；
4. 连接电脑复制 `.jsonl`，确认首行是 `export_manifest`，`containsRawMedia=false`，后续存在 `session_boundary`、逐帧关键点、ready/深度/计数和耗时字段；
5. 取消一次系统保存界面，确认 App 不报失败；清空测试环境日志后点击导出，确认显示“暂无可导出的运动测试日志”；
6. 关闭开关后再训练，确认不新增会话；已有日志仍可导出。

实现边界：训练中只产生不可导出的 `.jsonl.part`，正常结束并 flush 后才改名为 `.jsonl`；最多保留 20 次，单次上限 12 MiB、总量上限 24 MiB，汇总导出上限 25 MiB。可用受控测试数据验证“日志过大”提示；不要为制造大文件而提交真实日志。开关持久化失败时应回滚显示并提示重试，不得让 UI 状态与下次启动状态相反。

导出的真实日志含人体姿态坐标，只能存放在本地或约定的私密诊断渠道，禁止提交 Git、公开 Issue、聊天群或发布产物。需要加入自动化回归时，只提取并脱敏为 `test/fixtures/` 的标量信号。

## 4. Google 登录测试

Google 登录同时校验包名和签名证书 SHA-1。

- Play 安装版：使用 Play 应用签名证书对应的 Android OAuth Client。
- Debug/本地 release：只有对应 debug/上传证书 SHA-1 已登记时，才能稳定验证 Google 登录。
- App 代码使用 Web Client ID 作为 server audience；不要把 Android Client ID 写进 Flutter 配置。

因此：普通 UI 本地测；涉及 Google 登录的最终验收优先使用内部测试或 Alpha 的 Play 安装版。

### 4.1 本机跨分支复用 Debug Google 登录

2026-07-11 已核验：Google Cloud 中现有的 `UGK Android Debug` 客户端与当前 Windows 用户的默认 Flutter Debug 签名匹配。只要分支或 worktree 不修改包名、Debug 签名配置或 `applicationIdSuffix`，它们会自动复用同一签名，不需要为每个分支新建 OAuth 客户端。

使用带会员配置的 Debug 包：

```powershell
flutter build apk --debug --dart-define-from-file=E:\AII\运动app-prod-info.txt
```

输出：`build\app\outputs\flutter-apk\app-debug.apk`

注意：

- 本机 Debug 登录基线的客户端名、包名和公开 SHA-1 见 [release-configuration.md](release-configuration.md#41-google-oauth-客户端)；密钥文件和密码不进入文档或 Git。
- 同包名但不同签名的 Debug、上传签名 release 和 Play 安装版不能互相覆盖；切换前需要卸载，必须先确认允许清除本机 App 数据。
- 本地 `--release` 使用上传签名，当前未登记为本地 OAuth 客户端；不要把“Debug 可登录”误写成“本地 release 可登录”。
- 换电脑后默认 Debug 签名通常会变化；应新增该电脑专用的 Android OAuth 客户端，不能替换或删除现有 Debug/Play 客户端。
- Google Play 正式候选仍必须从 Play 测试轨道安装，验证 Play App Signing、Billing 和真实发布链路。

## 5. 排行榜怎么测

### 5.1 本地测试

本地测试必须覆盖：

- 日榜/周榜切换和旧快照隐藏；
- 首页排行榜缓存的同账号/同上海周期命中、跨账号/跨日拒绝、跨周期晚到响应拒绝、网络刷新时名次稳定而积分槽 loading、成功覆盖、失败保留，以及服务端未加入/无会员权限清除；缓存读写变慢不得阻塞权威结果或 loading 收束；
- 登录、未登录、空榜、错误和重试；
- Premium 加入限制；
- 加入、退出、零分成员和已加入用户编辑公开身份；
- 有效会员零分时仍正常排名；已加入但过期的用户仍以冻结成绩公开排名，只有本人额外看到冻结卡；
- `pushup_points_v1` 日榜和周榜均按标准 ×1、窄距 ×2 聚合，历史分类型行可直接回算；次数榜游标不能用于积分榜；
- 本人卡片的标准/窄距次数与当前日榜或周榜使用同一服务端范围；旧响应缺少可选明细时隐藏该行，且其他用户排行行不泄露分类次数；
- JSON 解析与错误码映射；
- 个人资料和匿名两种榜单身份模式，默认匿名；
- profile 模式复用 App 的唯一昵称/头像资料源，anonymous 模式不公开账号资料；
- 公开行不泄露其他用户的身份模式或编辑配置。

主要测试文件：

- `test/leaderboard_page_test.dart`
- `test/leaderboard_controller_test.dart`
- `test/membership_api_client_test.dart`
- `test/home_page_test.dart`
- `test/profile_page_test.dart`

这些测试不需要 Google Play，也不应读写 D1。

### 5.2 真实联网测试

真实链路需要：Google 登录、线上 Worker、测试账号和对应会员状态。它会读写真实排行榜/D1，因此：

- 只使用明确的测试账号；
- 不伪造测试者反馈或训练成绩；
- 不为方便测试加入客户端后门、固定 token 或跳过会员校验；
- 未经用户授权，不部署 Worker、不改 D1、不手工修改会员记录。

当前没有独立 staging Worker/D1 时，频繁开发只跑本地自动化；里程碑版本再用 Play 测试轨道抽查加入、退出、上传训练和名次刷新。

涉及排行榜 schema 与 Worker 响应合同时，上线顺序固定为 `D1 迁移 → Worker → App`。每一步验证通过后再进入下一步；精确部署版本、远程证据和回滚依据只记录在本机私密台账。

## 6. 会员测试分三层

### 6.1 层一：本地单元/Widget 测试

使用 fake RevenueCat/API 验证：

- 购买成功、取消和失败的 UI；
- Premium 状态渲染；
- 恢复购买按钮；
- 登出、过期 session 和竞态守卫。
- SDK active 不能覆盖 Worker inactive；购买/恢复后只应用 `/membership/reconcile` 返回值。
- Webhook 事件内容与 RevenueCat 当前 subscriber 冲突时，当前 subscriber 状态胜出。
- RevenueCat 查询失败不污染 D1，并显示“会员权益同步失败”而不是“需要会员”。

这层最快，每次会员代码改动都要跑。

### 6.2 层二：RevenueCat Test Store

Debug 构建可使用 RevenueCat `test_` Key，验证购买对话框、CustomerInfo 和 entitlement 流程，不依赖 Google Play。

限制：它不验证 Google Play 商品、真实 Billing 弹窗、续订、宽限期、RTDN 或退款。Release 构建禁止使用 Test Store Key，`validateMembershipConfig()` 会 fail-fast。

### 6.3 层三：Google Play Billing Sandbox

Google 官方允许 License Tester 使用与 Play 应用相同包名的侧载 Debug 包测试 Billing，即使签名不同也可以。该方式能验证商品、购买、续订和后端通知，但不能证明 Play App Signing、Play 安装/更新或 Play 签名 OAuth；发布候选仍需从测试轨道安装后做冒烟。

完整购买前必须全部满足：

1. Play Console 账号级 License Testing 已加入测试账号；
2. 测试账号已加入对应内部/封闭轨道；
3. Play 订阅和 base plan 已创建并激活；
4. RevenueCat 已完成 Product → `premium` entitlement → Package → current Offering；
5. RevenueCat Sandbox Testing Access 允许当前 App User ID；
6. 购买页明确显示 Google 测试卡，而不是真实银行卡。

验证顺序：

1. 发起购买并使用测试卡；
2. App 解锁 Premium；
3. RevenueCat Customer 开启 `Show sandbox data` 后出现 sandbox 交易和 active `premium`；关闭该开关时的 `No current entitlements` 仅代表正式数据视图；
4. Google RTDN 被 RevenueCat 接收；
5. RevenueCat Webhook 到达 Worker并触发当前 subscriber 对账；
6. Worker `/membership/reconcile`、`/membership` 与 D1 状态一致；
7. 个人页、运动广场和训练同步使用同一 Worker 结论；
8. App 退出重进、恢复购买后仍一致。

任一页面出现真实扣款入口，立即取消。不得用真实付款完成“测试”。

### 6.4 手工授予权益只用于 Webhook 冒烟测试

RevenueCat Customer 页的 Grant 可以给测试账号临时或无限期 `premium`，适合验证 App 权益显示、Webhook、Worker、D1 和训练上传，但它不验证 Google Play Billing、商品映射、续订、退款或 RTDN。

本项目 2026-07-15 的验收记录表明，手工 Grant 产生的 Webhook 属于 Production `NON_RENEWING_PURCHASE`，并标记为 `PROMOTIONAL`；即使使用 Debug App，也不能把 Webhook 只配置成 Sandbox。冒烟测试前确认：

1. RevenueCat Webhook Environment 为 Production and Sandbox；
2. HMAC webhook signing 为 Enabled；
3. RevenueCat signing secret 与 Cloudflare Worker Secret `REVENUECAT_WEBHOOK_SECRET` 值一致，但任何文档和聊天都不记录值；
4. 事件状态为 Sent/Succeeded；`401` 表示 HMAC 缺失或不一致，应先修鉴权再 Retry 原事件；
5. Worker 成功查询 RevenueCat 当前 subscriber 后，D1 `membership_snapshots` 最终为 active，再冷启动 App 验证正数训练上传。

不要为了补发 Webhook 反复移除/授予权益。先在 Webhook Events 中找到失败事件并 Retry；Webhook 只负责触发对账，最终状态必须以 RevenueCat 当前 subscriber 和 Worker 返回值为准，不能用某个事件类型推断当前权益。

### 6.5 会员状态分裂回归

此场景专门防止“个人页显示 VIP，但运动广场要求会员”再次出现：

1. 准备一条过期或 `verified_at IS NULL` 的 D1 快照，不手工改成 active。
2. RevenueCat 当前 subscriber 保持 active `premium`。
3. 调用 `/membership/reconcile` 或访问需要会员的 Worker 路由，确认 D1 自动写为 `source=revenuecat_verified` 并记录 `verified_at`。
4. 确认个人页、运动广场 `canJoin`、加入操作和训练同步均得到 active。
5. 反向验证：App SDK 假定 active，但 RevenueCat/Worker 当前 inactive 时，个人页不得显示 VIP，会员路由不得放行。
6. 让 RevenueCat 查询临时返回失败，确认 D1 不被改写、Worker 返回 `membership_sync_unavailable`，App 显示同步失败而非非会员提示。
7. 在 Google Play Sandbox 模拟过期后重新订阅，确认即使 Webhook 延迟或乱序，主动对账仍使所有界面最终一致。

步骤 1–6 可由本地 SQLite/fake HTTP 自动化完成。步骤 7 涉及真实平台和生产 Worker/D1 时，必须分别获得用户授权。

服务端只接收大于 0 的训练次数。零次训练适合保留在本地，但不应被当成“等待同步”；若客户端仍显示零次记录待同步，应作为 App 队列/文案缺陷处理，不要放宽服务端校验。

## 7. 什么时候上传 Google Play

推荐顺序：

```text
本地 TDD/真机 → 内部测试 → Alpha 封闭测试 → 正式版申请
```

上传内部测试的触发条件：

- OAuth、Billing、RevenueCat 或签名发生变化；
- 需要验证 Play 安装/更新行为；
- 一批功能已完成本地回归，准备成为候选版本。

推进 Alpha 的触发条件：

- 内部测试通过；
- `flutter analyze` 和 `flutter test` 全绿；
- Release 配置完整；
- AAB 版本代码高于所有已上传产物；
- 签名和合并清单已检查；
- 更新说明与真实改动一致。

不要为每个小提交创建 Play 版本。一个候选版本可以包含一组已经独立测试过的改动。

### 7.1 App 内版本与更新入口怎么验收

- 本地 Debug/侧载包可以验证设置菜单显示真实 `versionName (versionCode)`，且无论是否检测到更新，点击整行都能交给 Google Play 商品页处理。
- “新版本可用”标签只能由 Google Play 官方更新 API 的结果驱动；侧载包、模拟器未登录 Play 或检测失败时不显示标签是正常边界。
- 要验证真实更新提示，必须先从 Play 测试轨道安装较低 `versionCode`，再发布更高 `versionCode` 的候选，并等待 Play 对该测试账号提供更新。
- 验收时同时确认：旧版显示更新标签、点击进入正确商品页、Play 可覆盖更新、更新后版本号变化且本地数据保留。

## 8. Release 构建与秘密边界

### 8.1 自定义头像本地与真机验收

本地自动化必须覆盖：规则接受、JPEG/尺寸/大小拒绝、替换/删除、公开读取、匿名例外、举报幂等、自举报拒绝、屏蔽过滤、审核鉴权、头像版本过期保护和账号删除清理。

真机候选版按以下顺序验收：

1. 相册选择、相机拍摄、1:1 裁剪、取消和断网重试；
2. 首次上传主动勾选规则，替换后 URL 更新，删除后按“内置头像 → Google 头像 → 默认头像”回退；
3. 个人页、资料身份榜单行均优先显示自定义头像，匿名身份不泄漏账号头像；
4. 举报头像、举报用户和屏蔽用户成功后目标立即从当前榜单移除；举报提交期间有加载反馈，成功有明确提示，失败可重试；
5. 管理员下架旧版本不能误删当前新头像，暂停上传后 App 明确禁用上传；
6. 浅/深色、中文/英文无溢出，Release 合并清单不存在 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、`READ_EXTERNAL_STORAGE` 或 `WRITE_EXTERNAL_STORAGE`。

生产验收还必须证明：R2 bucket 不公开、Worker 是唯一读取边界、Access 未授权请求返回 403、审核动作有审计记录、公开缓存最多 300 秒，以及[用户头像内容规则](policies/user-content-policy.md)中的队列检查责任已经落实。

任何 R2 创建、D1 `0004_custom_avatar_ugc.sql` 生产迁移、Access 应用/策略配置、Worker/政策网站部署、Play 声明修改、产物上传或轨道推进，均为独立远端写入，必须分别获得用户明确授权。

Release 只认：

- `UGK_MEMBERSHIP_API_BASE_URL`
- `UGK_GOOGLE_SERVER_CLIENT_ID`
- `UGK_REVENUECAT_ANDROID_API_KEY`

构建示例：

```powershell
flutter build appbundle --release --dart-define-from-file=<本机生产配置文件>
```

完整的版本号、签名、清单、权限、哈希、台账和上传检查清单见 [发布配置台账 §6.4](release-configuration.md#64-google-play-aab-标准打包-sop)。候选产物只有在以下全部成立时才能上传：

- `versionCode` 高于 Play Console 已有所有版本。
- Flutter/Worker 测试和 `flutter analyze` 全绿。
- JAR 签名完整，上传证书与私密台账一致。
- 包名、版本、SDK 和禁止权限已从 release bundle manifest/元数据验证。
- AAB 大小、SHA-256、源提交和上传状态已写入两层台账。
- 用户已对当次上传明确授权。

禁止：

- 输出配置值；
- 把凭证写入仓库、`app_theme.dart`、测试或文档；
- 把 Test Store Key 打进 release；
- 把上传 keystore、`key.properties`、服务账号 JSON 或 AAB 提交到 Git。

精确文件位置和轮换方法只读本机私密台账，不复制到聊天或公开文档。

## 9. Git 与多 worktree 收尾

正常流程：

1. 在功能分支完成并提交；
2. Play 候选通过自动化和真机验证；
3. 审核后合并到 `main`；
4. 再正常 push，禁止 force push；
5. 其他功能分支基于新 `main` rebase/merge 后继续。

发布产物必须能对应到一个提交；不要上传 AAB 后长期把源码留在未提交状态。

独立 worktree 中的未跟踪截图、脚本和日志属于用户文件。不要为了“清理状态”删除、移动或提交它们。

## 10. 新 agent 接手检查

开始前必须：

1. 阅读 `AGENTS.md`、`docs/development-guide.md`、本文；
2. 涉及账号/会员/商店时再读 `docs/modules/membership.md` 和 `docs/release-configuration.md`；
3. 执行 Git 只读检查，确认分支、HEAD、staged/unstaged/untracked；
4. 只确认秘密字段存在，不输出值；
5. 明确本次改动属于本地测试、内部测试还是 Alpha 验收；
6. 任何购买、上传、提交审核、部署、D1 修改、push 前确认授权范围；
7. 汇报测试结果时区分“本会话已运行”和“历史交付记录”。

交付时必须写清：

- 改了什么；
- 跑了哪些测试及数量；
- 哪些真实链路尚未验证；
- 是否生成/上传产物；
- 是否做了远端写入；
- 下一步需要用户做什么。

## 11. 官方参考

- [Google Play Billing 测试](https://developer.android.com/google/play/billing/test?hl=en)
- [Google Play 测试轨道](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Google Android 客户端签名认证](https://developers.google.com/android/guides/client-auth)
- [RevenueCat Sandbox Testing](https://www.revenuecat.com/docs/test-and-launch/sandbox)
- [RevenueCat Google Play Sandbox](https://www.revenuecat.com/docs/test-and-launch/sandbox/google-play-store)
- [RevenueCat Sandbox Testing Access](https://www.revenuecat.com/docs/projects/sandbox-access)
