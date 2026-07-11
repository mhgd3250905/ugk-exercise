# `feat/account-features` → `main` 审核报告

- 日期：2026-07-11
- 功能分支：`feat/account-features`
- 目标分支：`main`
- 本轮基线：`b16c1d7a2a6c1ccb9bfdcd0f1ede4823d65c5eb1`
- App 版本：`0.3.2 (3)`
- 发布状态：Alpha 更新已提交 Google Play 审核，尚未确认获批

## 1. 结论先行

本轮是 `0.3.2` Alpha 的最小合规与真机问题收尾：相机启动前明确端侧处理、补齐隐私政策与账号删除入口、排行榜不公开自由昵称，并修复记录页周/月/年入口无响应、底部安全区、训练计数圆环变形和昵称输入对比度。

本轮没有修改识别算法、Cloudflare Worker、D1 schema/数据、会员 API 或 RevenueCat 后端配置。Google Play 的上传与提交审核由用户在控制台完成；本提交只保存对应源码、测试和发布记录。

## 2. 本轮变更

### 2.1 相机与端侧处理说明

- 训练页不再进入页面后立即启动相机。
- 首先展示不可绕过的说明弹窗，明确画面只在本机用于姿态识别和计数，原始画面不上传。
- 用户确认后才调用现有 `WorkoutController.start()`；controller 生命周期和 session 守卫未改。
- 新增中英文文案和 Widget 回归测试。

### 2.2 隐私政策与账号删除

- 个人页增加“隐私政策与账号删除”入口，打开已发布的公开删除说明页面。
- 外部页面无法打开时显示本地化错误，不静默失败。
- 使用现有 Flutter 官方插件模式；URL launcher 可注入，Widget 测试不访问网络。
- Android 清单移除不再需要的 `READ_EXTERNAL_STORAGE` 和 `READ_MEDIA_VIDEO`，保留相机、网络和 Billing 权限。

### 2.3 排行榜公开名称

- 排行榜所有公开行统一显示本地化匿名名称，不渲染后端返回的自由昵称。
- 本轮按授权边界只改客户端，没有修改 Worker/D1；后端响应仍可能携带昵称，审核者应确认客户端匿名化是否满足当前首发策略。

### 2.4 记录页与布局修复

- 周/月/年标签从静态装饰改为真实可点击控件。
- 周视图按周日到周六显示当前周；月视图保持当前月日历；年视图汇总 12 个月。
- 标题、总次数、活跃天数和最佳单日随周期切换。
- 记录页加入底部系统安全区。
- 训练计数圆环改为 1:1 约束，短视口不再压成椭圆。
- 昵称输入及浮动标签显式使用高对比度样式。

### 2.5 发布与接手资料

- 版本提升为 `0.3.2+3`。
- 新增 `docs/testing-release-playbook.md`，明确本地、内部测试、Alpha、排行榜、OAuth 和 Billing 的测试分流。
- 更新发布台账，记录 `0.3.2 (3)` AAB、Alpha 审核状态和待办。
- 记录本机共享 Debug OAuth 签名流程：同一 Windows 用户下的分支/worktree 可复用现有 `UGK Android Debug` 客户端；不保存 keystore 或密码。

## 3. TDD 与验证证据

本轮提交前重新执行：

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，228/228 |
| 回放基线 | PASS，Step0=5 / video3=5 / video4=3（包含在完整测试中） |
| `git diff --check` | PASS |
| Worker `npm test` | 本轮未运行；Worker 未改。上一份交付记录为 86/86，不作为本轮证据 |

本轮先前已完成的产物/设备验证：

- Release AAB：`0.3.2 (3)`，签名完整性通过。
- Release 合并清单不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO` 或 `AD_ID`。
- 本机 Debug APK 已使用与 `UGK Android Debug` OAuth 客户端匹配的签名构建并安装。
- Debug App 启动和登录监听期间进程存活，无 Android/Flutter 致命崩溃；尚未取得用户确认的登录成功结果。

APK、AAB、日志、截图、设备标识和本机配置文件均不纳入 Git。

## 4. Google Play 状态

- `0.3.1-closed-1`（`versionCode=2`）是已发布 Alpha 基线。
- `0.3.2 (3)` 已上传并提交 Alpha 审核，尚未确认获批或测试者可更新。
- 2026-07-11 核对时仅 3 名测试者已选择参与；12 人连续 14 天条件尚未满足。
- License Testing、正式订阅/base plan 和 RevenueCat Product → `premium` → Package → Offering 映射尚未完成。
- 在 License Testing 和商品映射完成前，不执行真实购买测试。

## 5. `main` 审核重点

1. `WorkoutPage` 是否始终在相机启动前展示端侧处理说明，且退出页面时不会延迟启动相机。
2. `RecordsPage` 的周边界、跨月周、闰年和年汇总是否符合产品预期。
3. `SafeArea` 与 1:1 圆环约束是否在小屏、手势导航和三键导航下稳定。
4. 排行榜仅在客户端匿名是否满足首发合规边界；若要求数据最小化，应另行授权修改 Worker 响应。
5. 账号删除 URL、双语文案和失败提示是否与已发布隐私政策一致。
6. Android 权限移除后，相机实时训练和本地记录是否仍完整；离线视频回放不是当前产品入口。
7. 发布文档不得包含 Client ID、API key、keystore 密码、设备序列号或私密台账内容。

## 6. 审核后真机验收清单

等待 `0.3.2 (3)` Play 审核通过后，从 Alpha 测试链接安装 Play 签名版本并验证：

1. Google 登录成功，退出后可再次登录。
2. 运动广场能加载，所有公开行显示匿名名称。
3. 训练前先显示端侧处理说明；确认后相机和 MoveNet 正常启动。
4. 训练计数圆环保持正圆，结束训练和系统返回无崩溃。
5. 记录页周/月/年均可点击，标题、日历和汇总正确。
6. 页面底部不进入系统手势区；昵称标签在浅色/深色均清晰。
7. “隐私政策与账号删除”能打开正确锚点页面。

## 7. 明确未执行

- 未修改或部署 Worker/D1。
- 未创建 Google Play 订阅、base plan 或 RevenueCat 商品映射。
- 未执行购买、退款、续订、宽限期、RTDN/Webhook 全链路验收。
- 未合并到 `main`，未 force push。
- 用户未跟踪文件 `docs/handoff-account-features.md` 未修改、未 stage、未提交。

## 8. 审核命令

```powershell
git diff b16c1d7a2a6c1ccb9bfdcd0f1ede4823d65c5eb1..feat/account-features
flutter analyze
flutter test
git diff --check main...feat/account-features
```

审核通过后再由 `main` 正常合并本分支；禁止用 force push 或覆盖工作树的方式集成。
