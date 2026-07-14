# 会员双套餐付费墙设计

日期：2026-07-14

## 目标

在现有 `premium` 权益上提供两档 Google Play 自动续费套餐：月度和年度。年度默认选中；用户可切换后购买。价格来自 RevenueCat/Google Play 的本地化商品数据，不在 App 中硬编码美元。

## 方案

- RevenueCat 当前 Offering 使用标准月度、年度 Package，二者共同关联 `premium` entitlement。
- `product/` 增加纯 Dart 套餐标识与展示价格模型；不包含 RevenueCat 类型。
- `RevenueCatService` 加载可用套餐，并按明确的套餐标识购买；禁止继续购买 `availablePackages.first`。
- `AccountController` 只负责带账号/session 守卫地转发加载和购买。
- 付费墙同时展示可用套餐，年度存在时默认年度，否则选中唯一可用套餐。
- 缺少某档时只展示另一档；Offering 无可用套餐或加载失败时显示重试，不发起购买。
- Worker/D1 继续只保存 `premium`、active 和 expiry；月度与年度不产生新的会员等级，因此不改 schema。

## 视觉

- 弹框使用当前主题的 `surface`、`onSurface`、`onSurfaceVariant` 和 `outline`，与个人页的浅色/深色主题保持一致。
- 选中套餐使用主题浅绿色强调底、主色边框和实心圆形勾选；未选套餐使用普通表面色和常规边框，选中状态不只依赖颜色表达。
- 主操作按钮使用主题主绿色与其对比文字色；亮青绿色仅保留给会员徽标等品牌强调。

## 非目标

- 不创建或激活 Google Play/RevenueCat 远程商品。
- 不实现预付、不自动续费、试用、促销或套餐切换补差价。
- 不硬编码 `$2.99`、`$20` 或全球折扣百分比。
- 不引入 RevenueCat 默认 Paywall 或新依赖。

## 验证

- RevenueCat 适配测试：识别月度/年度、忽略其他 Package、购买明确选择的 Package。
- Controller 测试：转发选择并保留账号切换/session 守卫。
- Widget 测试：年度默认、切换月度、单档降级、空 Offering 重试、选中项购买。
- 收尾：`flutter analyze`、`flutter test`、`git diff --check`。
