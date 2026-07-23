# 审核报告:feat/ui-polish-2026-07-23

> 日期:2026-07-24
> 分支:`feat/ui-polish-2026-07-23`(已推送至 origin,基于 `main@c6c6dc9` rebase 对齐)
> 工作树:`E:/AII/ugk-post-ui-polish-2026-07-23`
> 用途:提交 main 审核合并

## 1. 概览

本分支包含 **5 个提交**(4 项功能/样式改动 + 1 项审查后修复),共改动 **10 个文件**(+366 / −86),覆盖三类工作:

| 类别 | 提交数 | 内容 |
|---|---|---|
| 榜单 UI 精修 | 2 | 展开明细水印化、计分说明去卡片、冻结卡布局 |
| 账号 bugfix | 2 | 登录成功被误报失败、购买前 SDK 兜底 |
| 姿态剪影美化 | 1 | 训练页头肩剪影加粗+阴影+光晕 |

**验证状态(本会话实跑)**:
- `flutter analyze`:**0 issue**
- `flutter test`:**740/740 全绿**(基于 rebase 后的 main)
- 回放基线 `domain_self_check_test`:**5/5/3 全绿**(domain 零改动)
- 真机验证:小米 arm64(API 36)上传签名 release 包,姿态剪影美化与榜单展开经真机确认;账号 bugfix 经真机确认(退出→登录错误条消失)

## 2. 提交明细

### 2.1 `a204818` feat(leaderboard): watermark breakdown replaces fused details card
**意图**:点击榜单用户卡展开的明细,从"实体卡片(背景+圆角+border+上塞6px)滑出"改为"水印式两列布局"。被点击卡纹丝不动,下方 items 下移,标准/窄距计数(标签+大数字)在空白处渐显,被点击卡的圆角阴影不再被连体破坏。

- `lib/ui/pages/leaderboard_page.dart`:`_LeaderboardRowDetails` 重写(去实体卡片/SlideTransition,保留 AnimatedSize+FadeTransition),新增 `_BreakdownRow`/`_BreakdownStat`
- `lib/l10n/app_zh.arb`/`app_en.arb`:新增 `leaderboardBreakdownStandard`/`Narrow` 词条
- `lib/l10n/app_localizations*.dart`:gen-l10n 生成
- `test/leaderboard_page_test.dart`:断言从整句改为标签+数字

### 2.2 `93b6fd2` style(leaderboard): flatten points-rule caption and stack frozen-panel CTA
**意图**:① 日/周 segment 下的计分规则去掉圆角背景卡片,变纯文字辅助说明。② 过期会员冻结成绩卡从"文字+按钮横排"改为"文字在上、按钮右对齐在下",解决英文长文案挤压按钮。

- `_PointsRuleBanner`:去掉 `decoration`(背景+圆角),改为 `Padding`+纯文字
- `_FrozenScorePanel`:非刷新态 `Row` → `Column`
- 测试:`one-layer tonal surfaces` 断言更新

### 2.3 `7108be9` fix(account): login success no longer masked by RevenueCat.configure failure
**意图**:修 bug —— 退出登录失败显示错误 → 重新登录成功 → 错误条还在。根因:`_applySnapshot` 里 `RevenueCat.configure()`(辅助步骤)网络失败,冒泡被 `_run` 记成致命 error,但此时登录主流程(session/user/membership)已成功。

- `lib/control/account_controller.dart`:`_applySnapshot` 里 configure 包 try-catch 吞掉异常
- 回归测试:`signIn succeeds without error when only RevenueCat.configure fails`
- 真机确认:退出→登录错误条消失

### 2.4 `275e60b` style(pose-silhouette): thicker stroke, drop shadow, layered glow
**意图**:训练页相机舞台识别到姿态后的头肩剪影,从"细弱两层描边"美化。形状不变。

- `lib/ui/pose_feedback/pose_silhouette_overlay.dart`:`paint` 从两层改四层(投影阴影 → 外发光 → 中柔光 → 内实线),线宽 `shoulderWidth*0.018`→`0.028`
- 光晕经真机评审后收紧(外发光 alpha 0.4→0.3、blur 9→6)

### 2.5 `5123a39` fix(account): re-attempt RevenueCat.configure before purchase/restore
**意图**:审查后修复。提交 7108be9 吞掉 configure 异常是对的,但注释错误声称"reconcile/refresh 会重试 configure",实际 configure 只在 `_applySnapshot` 调一次,导致登录时一次网络抖动会让整个购买/恢复链路在剩余会话静默哑火。

- 修正 `_applySnapshot` 注释为准确描述
- 新增 `_ensureRevenueCatConfigured`:purchase/restore 前重新尝试 configure(吞异常),恢复 SDK 关联
- 回归测试:`purchase re-attempts RevenueCat.configure when the first one failed`

## 3. 独立审查结论

启动了独立审查线程,从**需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖、实际运行结果**六维验证。

**结论:无阻断项(blocker),可合并。**

- **2 个「重要」项**:均已修复(见 2.5),并加回归测试守护,全量测试 740/740
- **6 个「建议」项**:均为预存在问题或极端边界,本次不修(详见附录 A)
- commit message 声称的 analyze=0 / 测试数量 / 真机验证,**整体可信**,仅 reduce-motion 与 configure 重试两处描述在 2.5 已更正

## 4. 纪律符合性自查

- ✅ 依赖只向上:UI 只 import control/product/l10n/app_theme;account_controller 只 import platform/product;无越界
- ✅ 用户可见文案进 ARB(zh+en 都改);domain/product/control 不引用 AppLocalizations
- ✅ 未用 `git add -A`,全程显式 stage 代码文件
- ✅ 回放基线 5/5/3 是硬约束,domain 零改动,已验证
- ✅ controller 异步方法保留 session 守卫(generation 校验未丢)
- ✅ 颜色常量直接 import app_theme,未建私有副本
- ✅ 真机验证用上传签名 release 包(符合 testing-release-playbook),未卸载用户数据(首次签名冲突时由用户主动卸载重装)

## 5. 未验证 / 待办

- **购买/恢复 re-configure 兜底**(2.5)的逻辑经单元测试守护,但**未在真机做完整购买链路验证**(模拟器/真机网络环境无法走真实 Google Play Billing)。建议合并后用 Play License Tester 真机抽查一次。
- **姿态剪影美化**(2.4)在真机 ready 态已确认视觉效果,低端机连续姿态帧下的模糊性能未做压测(shouldRepaint 仅在 geometry 变化时重绘,负担可控,若反馈卡顿可降层)。
- **建议项**(附录 A)未修,记录留待后续迭代。

## 6. 下一步(给 main 审核方)

- 本分支已 rebase 到 `main@c6c6dc9` 之上,**无冲突**,5 个提交线性
- 全量验证通过(analyze 0 / test 740/740 / 回放 5/5/3)
- 可直接审核合并;合并后建议用 Play License Tester 抽查购买链路(见 §5)

---

## 附录 A:审查「建议」项(未修,记录留待后续)

| # | 提交 | 问题 | 严重度 | 处理 |
|---|---|---|---|---|
| 1 | a204818 | `_BreakdownRow` 无 FittedBox 兜底,极端超大数字+极窄屏理论溢出 | 建议 | 现实数据范围内安全,留待后续 |
| 2 | a204818 | reduce-motion 下 AnimatedSize 瞬切但 FadeTransition 仍 220ms(预存在) | 建议 | 基线 e003ef6 同样如此,非本分支回归 |
| 3 | 275e60b | 四层 drawPath+blur 在低端机每帧性能 | 建议 | shouldRepaint 已优化,真机已验,若卡顿再降层 |
| 4 | 275e60b | 投影色硬编码 0x55000000 不随深浅色 | 建议 | 叠在相机流上(始终明亮),深色模式同样适用 |
| 5 | 275e60b | paint 层无测试断言(预存在) | 建议 | 纯视觉效果难断言,非强制 |
| 6 | a204818 | 标签 vs 数字 baseline 对齐 | 建议 | alphabetic baseline 对中英文均良好,无需改 |
