# PushupAI 开发测试与发布手册

最后核对：2026-07-13

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

典型命令：

```powershell
flutter run
flutter build apk --debug
flutter build apk --release --split-per-abi --dart-define-from-file=<本机配置文件>
```

注意：Google Play 安装版使用 Play App Signing 证书，本地包使用 debug 或上传证书。签名不同的同包名应用不能互相覆盖；不要为了安装本地包擅自卸载用户的 Play 版本或清除数据。

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
- 登录、未登录、空榜、错误和重试；
- Premium 加入限制；
- 加入、退出、零分成员和已加入用户编辑公开身份；
- JSON 解析与错误码映射；
- 当前资料、榜单专用身份和匿名三种模式，默认匿名；
- App 昵称/头像优先于 Google 资料，榜单专用昵称唯一，旧用户保持匿名；
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

这层最快，每次会员代码改动都要跑。

### 6.2 层二：RevenueCat Test Store

Debug 构建可使用 RevenueCat `test_` Key，验证购买对话框、CustomerInfo 和 entitlement 流程，不依赖 Google Play。

限制：它不验证 Google Play 商品、真实 Billing 弹窗、续订、宽限期、RTDN 或退款。Release 构建禁止使用 Test Store Key，`validateMembershipConfig()` 会 fail-fast。

### 6.3 层三：Google Play Billing Sandbox

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
3. RevenueCat Customer 出现 sandbox 交易和 `premium`；
4. Google RTDN 被 RevenueCat 接收；
5. RevenueCat Webhook 到达 Worker；
6. Worker `/membership` 与 D1 状态一致；
7. App 退出重进、恢复购买后仍一致。

任一页面出现真实扣款入口，立即取消。不得用真实付款完成“测试”。

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

## 8. Release 构建与秘密边界

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
