# Google Play 三天免费试用设计

日期：2026-07-19
状态：本地实现完成 / Offer 已启用 / Sandbox 待验收

## 1. 目标

在现有 `premium` 月度自动续订套餐上增加一次性三天免费试用：符合资格的用户通过 Google Play 确认订阅并验证付款方式，试用期间获得完整 Premium 权益；三天内取消则试用结束后不扣费，未取消则自动进入月度续订。

试用资格固定为：Google Play 账号从未拥有过 PushupAI 的任何订阅。每个 Play 账号只能获得一次试用，历史月卡或年卡用户不享受试用。资格只由 Google Play 判断，App、Worker 和 D1 不自行记录“是否试用过”。

## 2. 非目标

- 不新增独立的“试用会员”entitlement。
- 不在 App、Worker 或 D1 自建三天倒计时。
- 不给年度套餐增加试用。
- 不实现二次试用、召回优惠、开发者自定义资格或优惠券。
- 不改变 Premium 权益范围、排行榜门控、训练同步或宽限期规则。
- 本地开发不自动修改 Google Play、RevenueCat、Worker、D1 或测试轨道。

## 3. 产品合同

### 3.1 套餐与资格

- 月度套餐仍为现有 Google Play 自动续订 base plan。
- 三天试用作为月度 base plan 下的“新用户获取”Offer，不创建新 Subscription Product。
- Google Play Offer 资格选择“从未拥有本 App 的任何订阅（Never had any subscription in this app）”。
- Offer 免费阶段必须为三天，后续阶段直接进入现有月度 base plan 的本地化标准价格。
- Offer 地区不得超出月度 base plan 已启用地区；上线前核对两者地区集合一致。
- 无资格、Offer 未激活、商店未传播或商品加载失败时，App 不显示试用承诺。

### 3.2 权益语义

- 试用开始后 RevenueCat `premium` entitlement 必须为 active。
- App 购买完成后仍调用 Worker `/membership/reconcile`；SDK 的 active 结果不能直接授予会员。
- Worker 继续依据 RevenueCat 当前 entitlement、`expires_date` 和既有宽限期信息裁决会员，不增加 trial 分支。
- 用户在试用期内取消时，Premium 保持到试用结束；到期后由 RevenueCat、RTDN、Webhook 和主动对账收敛为 inactive。
- 未取消并成功扣款时，现有 entitlement 到期时间延长，App 无需执行“试用转月卡”本地动作。

## 4. 用户体验

### 4.1 有资格用户

会员弹窗从 RevenueCat 当前 Offering 读取月度 Package。只有该用户当前可购买的默认 SubscriptionOption 包含免费阶段时，月度套餐才展示试用：

- 月度卡标题：月度会员。
- 试用标记：免费试用 3 天。
- 续费价格：使用免费阶段之后的 full-price phase 本地化价格，不使用硬编码币种或金额。
- 默认选择：月度试用，而不是当前默认的年度套餐。
- 主按钮：开始 3 天免费试用。
- 披露：前三天免费；之后按本地化月价每月通过 Google Play 自动续费，除非在试用结束前取消。

用户改选年度套餐后，按钮和披露立即恢复普通年度订阅语义；不能继续显示试用提示。

### 4.2 无资格用户

- 不显示“免费试用”文字。
- 月度套餐按普通月价展示。
- 若年度套餐存在，继续沿用年度默认选择和“推荐”标识。
- 购买按钮与自动续费说明保持现有普通订阅语义。

### 4.3 管理与取消

已登录用户的设置页增加“管理订阅”入口，打开 Google Play 订阅中心。入口不依赖 Worker 当前 Premium 状态，因此已取消但尚未到期、状态同步失败或已过期用户仍能检查和管理商店订阅。打开失败时显示本地化错误提示，不改变会员状态。

## 5. 分层设计与数据流

### product

`PremiumPlan` 增加可空 `freeTrialDays`。它只表达商店已经返回给当前用户的可购买条件，不自行计算资格。`freeTrialDays == null` 表示当前不可展示试用。

### platform

`PurchasesRevenueCatService.loadPremiumPlans()` 从每个 Package 的 `storeProduct.defaultOption` 读取：

- `freePhase.billingPeriod`：仅当单位为 day 且值为正数时映射到 `freeTrialDays`。
- `fullPricePhase.price.formatted`：作为试用结束后的续费价格；缺失时回退 `storeProduct.priceString`。

购买继续传入 Package，让 RevenueCat SDK 自动选择当前用户有资格获得的最长免费试用；无合格 Offer 时 SDK 回退 base plan。当前项目只配置一个新用户三天试用 Offer，不引入 developer-determined Offer。

### control

`AccountController` 的加载、购买、账号 generation guard 和购买后强制对账流程不改变。新增字段随 `PremiumPlan` 透传，不在 Controller 解释试用资格。

### UI

`profile_page.dart` 根据当前选中 `PremiumPlan.freeTrialDays` 决定试用标记、按钮与披露。所有文字进入中英文 ARB。设置页的管理订阅入口只负责外部导航。

### Worker/D1

无源码、路由、schema 或 migration 改动。现有会员对账仍是唯一授权事实。

## 6. 失败与边界处理

- Offer 加载为空：沿用套餐加载失败和重试 UI。
- 只有月卡：有试用则默认月卡试用；无试用则普通月卡。
- 只有年卡：不显示试用，默认年卡。
- 免费阶段不是按天：不展示试用，避免生成错误文案；平台验收必须阻止该配置上线。
- 免费天数不是 3：App 显示商店实际返回的天数以避免误导，但发布验收失败，不得推进。
- 用户资格在商品加载后变化：Google Play 最终购买页负责复核；购买取消不报错，购买失败沿用短错误提示。
- 购买成功但 Worker 对账失败：不授予 Premium，显示现有“会员权益同步失败”。
- 试用期内取消：App 不立即撤销 Premium，以 RevenueCat 当前到期时间为准。
- 管理订阅链接打开失败：显示错误提示，不重试购买、不改账号状态。

## 7. 兼容与上线顺序

1. 已完成 App 动态 UI、回退行为和本地自动化；未配置或无资格 Offer 时新 App 与现有行为一致。
2. 已经单独授权并完成：Google Play 月度 base plan 下的三天新用户 Offer 已创建并激活。
3. 待执行：等待商品传播，使用从未订阅过的 License Tester 验证 Offering 返回三天免费阶段。当前真机多账号且无账号匹配 License Tester，已在购买前停止。
4. 待执行：使用 Google Play Billing Sandbox 验证首次试用、试用内取消、自动转月卡、无资格回退、恢复购买、RTDN、RevenueCat Webhook、Worker 对账和 D1 快照。
5. 未授权：生成更高 versionCode 的同一候选 AAB，先 Internal，再在单独授权下推进 Alpha。

Sandbox 设备准备优先由用户使用专用测试设备，或自行准备仅含合格 License Tester 的专用 Android 用户/工作资料。Agent 不得把本步骤理解为可直接退出或移除现有 Google 账号；任何账号退出、移除或其他设备账号状态修改都必须另行获得明确授权，并先确认相关数据、同步影响与恢复方式。

RevenueCat Test Store 只能验证本地 UI/entitlement 流程，不能证明 Google Play 资格、真实 Billing 对话框、续订、取消或 RTDN。

## 8. 验收标准

- 从未订阅用户看到三天试用、月度续费价格、扣费周期和取消说明，默认选择月度试用。
- 历史订阅用户不看到任何试用承诺，购买普通月卡或年卡。
- 年度套餐不带试用。
- 试用开始后只有 Worker 对账成功才显示 Premium。
- 试用内取消后权益持续到到期且不转为付费；未取消时自动进入月卡。
- 中英文、浅深色、窄屏无溢出；按钮和选中状态同步更新。
- 管理订阅入口可打开 Google Play 订阅中心，失败有明确提示。
- `flutter analyze` 无 issue；`flutter test` 全绿；回放硬基线保持 5/5/3；`git diff --check` 通过。
