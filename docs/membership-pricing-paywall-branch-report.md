# `codex/membership-pricing-paywall` → `main` 审核报告

- 日期：2026-07-14
- 功能分支：`codex/membership-pricing-paywall`
- 目标分支：`main`
- 审核基线：`11f4250c8c93eb8cb9e0e2875ecd682de6b0bc54`
- 功能源提交：`35dfbbcaedf07dde760e35995ab71b7e21c1b0d6`

## 1. 结论先行

本分支完成会员月度/年度套餐、RevenueCat Offering 读取与指定套餐购买、浅色主题会员弹窗、个人页会员身份视觉和中英文品牌统一。代码层已通过完整 Flutter 回归，可以进入 `main` 审核。

Google Play 商品与 RevenueCat 映射已经配置，但尚未执行 Google Play Sandbox 购买。因此，合入代码不等于真实支付全链路已经验收，也不等于可以直接向普通用户收费。

## 2. 本分支变更

### 2.1 月度与年度套餐

- 新增 `PremiumPlanId.monthly`、`PremiumPlanId.annual` 和 `PremiumPlan`。
- RevenueCat 服务从当前 Offering 读取标准月度/年度 Package，并使用商店返回的本地化价格。
- `AccountController` 加载可用套餐，并购买用户明确选择的套餐。
- 套餐异步加载保留账号 session 守卫，登出或切换账号后的旧结果不会回写当前状态。
- 套餐不可用时保留重试入口；仅返回一个套餐时仍可完成选择和购买。

### 2.2 会员弹窗

- 使用与 App 浅色主题一致的卡片、边框、文字和绿色强调色。
- 月度与年度套餐均显示，年度套餐标注推荐。
- 当前套餐增加明确勾选标记和选中状态。
- 点击遮罩区域或“稍后再说”均可关闭弹窗。
- 购买按钮按当前选择购买对应 Package，不使用 RevenueCat 默认 Paywall。
- 中文标题统一为“PushupAI 会员”，英文为“PushupAI Premium”。

### 2.3 个人页会员身份

- 首页与个人页复用统一头像组件和边框语言。
- 个人页登录卡、开通会员入口和运动广场状态调整为浅色主题下的精致卡片样式。
- 已登录用户继续显示昵称、邮箱和会员/广场状态，不改变原账号业务逻辑。

### 2.4 文档与平台台账

- 新增会员定价设计和实施计划。
- 更新发布台账，记录 Google Play 商品、RevenueCat Entitlement/Package/Offering 映射和 License Testing 状态。
- 更新会员模块及 UI 规范中的弹窗品牌名称。

## 3. Google Play 与 RevenueCat 状态

以下为用户在控制台操作并确认、且已写入发布台账的状态：

- Google Play Subscription Product：`premium`。
- `monthly`：每月自动续订，美国区基准价 `$2.99`，已启用。
- `annual`：每年自动续订，美国区基准价 `$20.00`，已启用。
- 两个 Base Plan 均覆盖 174 个国家/地区。
- RevenueCat `premium:monthly`、`premium:annual` 已关联 `premium` entitlement。
- 当前 `default` Offering 已配置 `$rc_monthly` 和 `$rc_annual`。
- License Testing 名单已配置。

尚未验证：

- Google Play 测试卡购买弹窗。
- RevenueCat Sandbox 交易及 `premium` entitlement 激活。
- RevenueCat Webhook → Worker → D1 会员状态同步。
- App 重启、恢复购买、续订和到期后的真实商店行为。

## 4. 验证证据

本次提交前重新执行：

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，346/346 |
| 回放基线 | PASS，Step0=5 / video3=5 / video4=3 |
| `git diff --check` | PASS |

本分支前序设备验证：

- 带本机构建配置的 Debug APK 构建、安装和启动成功。
- 用户确认会员弹窗浅色样式、套餐选中标记、遮罩关闭、“稍后再说”关闭和个人页头像/身份卡视觉符合预期。
- 该设备验证没有发起购买，不构成 Google Play Billing 验收。

Worker 代码未修改，本轮未运行 Worker `npm test`；发布候选阶段仍应按 AAB SOP 复跑。

## 5. `main` 审核重点

1. `RevenueCatService.loadPremiumPlans()` 是否只接受当前 Offering 的标准月度/年度 Package，并正确使用商店本地化价格。
2. `AccountController` 的套餐加载、指定套餐购买和 session 守卫是否覆盖登出/切换账号竞态。
3. 弹窗在套餐缺失、单套餐、双套餐、购买取消和购买失败时是否保持现有容错行为。
4. 选中勾选、遮罩关闭和“稍后再说”是否满足浅色/深色及中英文场景。
5. 头像组件复用是否只影响展示，没有改变首页和个人页导航、登录或资料状态。
6. 发布台账是否清楚区分“商品映射完成”和“Sandbox 购买未验证”。

## 6. 合入后仍需执行

1. 从已合入源码创建更高 `versionCode` 的发布候选，并完成标准 AAB 验证。
2. 经单独授权上传内部测试轨道，从 Google Play 安装。
3. 确认购买弹窗只显示 Google 测试支付方式后，执行一次 Sandbox 购买。
4. 核对 App、RevenueCat、Webhook、Worker `/membership` 与 D1 状态一致。
5. 内部测试通过后，再单独决定是否推进 Alpha 或 Production。

## 7. 明确未执行

- 未修改或部署 Worker/D1。
- 未写入 Secret、Token、Client ID、API Key、签名密码或设备标识。
- 未构建、上传或推进本分支的 Google Play AAB。
- 未发起购买、退款或订阅测试。
- 未 push、未合并到 `main`、未创建 PR。
- 用户未跟踪文件 `docs/handoff-2026-07-14-membership-explore.md` 未修改、未暂存、未提交。

## 8. 审核命令

```powershell
git diff --stat 11f4250c8c93eb8cb9e0e2875ecd682de6b0bc54..codex/membership-pricing-paywall
git diff --check 11f4250c8c93eb8cb9e0e2875ecd682de6b0bc54..codex/membership-pricing-paywall
flutter analyze
flutter test
```

## 9. 功能提交

- `28b0862` `feat(membership): add monthly and annual plans`
- `aedada8` `docs: record membership product configuration`
- `ce2adfc` `feat(profile): polish membership identity card`
- `35dfbbc` `feat(membership): align premium branding`
