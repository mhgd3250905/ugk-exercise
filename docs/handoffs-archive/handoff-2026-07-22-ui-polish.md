# 交接：App 使用界面 / 功能优化

> 日期：2026-07-22
> 工作树：`E:/AII/ugk-post-ui-polish`
> 分支：`feat/ui-polish-2026-07-22`（基于 `main@cd91a4b`）
> 任务类型：**UI / 功能开发**（用户会发具体需求）

## 1. 你的任务

用户要做 **App 使用界面或功能优化**。你接手后，用户会发具体需求。你的工作是按项目分层纪律实现：UI 层只展示和转发用户操作，业务逻辑在 product/control，文案进 ARB。

## 2. 接手第一步

1. 完整读仓库根目录 `AGENTS.md`（项目入口、架构分层、纪律、文档地图）。
2. 读 `docs/development-guide.md`（**怎么按架构分块开发一个功能、代码放哪、按什么顺序写**）——核心一句话：先判断"心脏"在哪层，从最底层开始写，每层写完立刻测。
3. 读 `docs/design/app-ui-v1.md`（UI V1 设计规范 + **多语言与主题维护规则**）。
4. 运行只读预检确认基线：

   ```bash
   cd E:/AII/ugk-post-ui-polish
   flutter analyze                    # 必须无 issue
   flutter test                       # 必须全绿
   ```

## 3. 架构分层（依赖只向上，违反会埋坑）

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               产品规则（计数管线/门控/存储/语音/会员状态），只依赖 domain
control/               编排（WorkoutController / AccountController 串起 product + 基础设施）
ui/pages/ ui/          纯展示，监听 ChangeNotifier 渲染；l10n 与主题只属于这层 + app 根
config/                纯常量（会员 API base/Google Client ID/RevenueCat key，dart-define 注入）
l10n/                  多语言 ARB + 生成的 AppLocalizations（UI/app 根专用）
inference/ pipeline/ platform/   基础设施（推理/帧处理/相机/会员服务），依赖 domain
```

**UI 改动的核心纪律**：
- UI 层（`ui/pages/`、`ui/`）只做展示和转发。业务逻辑不写在这里，往下沉到 product/control。
- `ChangeNotifier` 在 control/product，UI 监听它渲染。不要在 UI 里直接持有状态或发网络请求。
- 新页面/新控件要有对应的 Widget 测试（`test/*_test.dart`）。

## 4. ⚠️ 关键纪律（违反会埋坑）

1. **l10n 只属于 UI/app 根** —— domain/product/control 层不引用 `AppLocalizations`。用户可见文案进 ARB（`lib/l10n/app_zh.arb` + `app_en.arb`）再用，不要在 Widget 里硬编码中文字符串。
2. **会员凭证不进 `app_theme.dart`** —— 放 `lib/config/membership_config.dart`，走 `--dart-define` 注入。
3. **`pushup_domain.dart` 保持纯 dart** —— UI 改动一般不碰它，但如果你以为"只是改个常量"而加了 Flutter import，会破坏地基。
4. **WorkoutController 异步方法保留 session 守卫** —— 如果你改训练页相关的交互，注意每个 await 后校验 `session != _session`。
5. **不用 `git add -A`** —— 显式 stage 代码文件，根目录有未跟踪临时文件（截图/日志）。
6. **真实视频/csv/截图不进 git**（隐私）。
7. **Flutter UI 迭代默认保留 resident `flutter run`** —— Dart/Widget 小改用 Hot Reload（`r`），需要重跑 main() 用 Hot Restart（`R`）；只在原生/构建配置变化或最终冷启动验收时重新构建安装。

## 5. 多语言与主题（UI 改动高频涉及）

### 5.1 加一条文案

1. 在 `lib/l10n/app_zh.arb` 和 `app_en.arb` 各加一条 key（key 用驼峰，语义化）。
2. 运行 `flutter gen-l10n`（或 `flutter pub get` 触发）生成 `AppLocalizations`。
3. 在 Widget 里用 `AppLocalizations.of(context)!.yourKey`。

不要只改中文忘了英文，也不要在 Widget 里写死 `'俯卧撑'`。

### 5.2 主题

主题定义在 `lib/ui/app_theme.dart`。浅/深色都用 `appTheme(brightness: ...)`。颜色常量在主题里，不要在 Widget 里写 `Color(0xFF...)`。

架构契约测试 `test/architecture_contract_test.dart` 会检查：主题文件不含会员配置、home 页用 `Theme.of(context).brightness` 判断深色等。改主题时注意这些断言。

## 6. 常见 UI 改动落点

| 需求 | 改哪里 | 测试 |
|---|---|---|
| 改某个页面布局/控件 | `lib/ui/pages/<page>.dart` | `test/<page>_test.dart`（Widget 测试） |
| 加新页面 | `lib/ui/pages/`，在 home 或路由注册 | 新建 `test/<page>_test.dart` |
| 改主题色/字体 | `lib/ui/app_theme.dart` | 相关页面 Widget 测试 |
| 加文案 | `lib/l10n/app_zh.arb` + `app_en.arb` + 生成 | 用到该文案的 Widget 测试 |
| 改训练页交互 | `lib/ui/pages/workout_page.dart`（展示）+ 可能 `lib/control/workout_controller.dart`（逻辑） | `test/workout_controller_test.dart` |
| 改首页/记录/排行榜 | `lib/ui/pages/home_page.dart` / `records_page.dart` / `leaderboard_page.dart` | 对应 `*_test.dart` |
| 改个人/设置 | `lib/ui/pages/profile_page.dart` | `test/profile_page_test.dart` |

## 7. 验证标准（每次提交前）

```bash
cd E:/AII/ugk-post-ui-polish
flutter analyze                    # 0 issue
flutter test                       # 全绿
git diff --check                   # 无空白错误
```

UI 改动不涉及算法，通常不需要跑 `test/domain_self_check_test.dart` 的回放基线（除非你动了 pushup_domain）。但如果你改了 WorkoutController 或 pipeline，要跑回放确认 5/5/3。

改了 `workers/membership-api/` 才额外跑 `npm test`（UI 优化一般不碰 Worker）。

## 8. 真机验证（按需）

纯 UI/布局/文案改动：本地自动化 + 模拟器/真机 Hot Reload 看效果即可。

涉及以下才需要更高验证：
- 相机/系统安全区/原生 Splash → 真机
- Google 登录/会员/购买 → 按 `docs/testing-release-playbook.md`（内部测试或 Alpha）
- 详细分流见该文档第 1 节。

## 9. 当前仓库状态

- `main@cd91a4b`：含审计整改 + 0.3.19 发版记录 + skill 文档
- 本分支 `feat/ui-polish-2026-07-22` 基于 main，无额外改动
- 本地 Flutter `3.44.7`
- 门禁基线：`flutter analyze` 0 issue、Flutter 715/715

## 10. 给用户的接手开场（建议）

```
已读完交接。我在 feat/ui-polish-2026-07-22 分支，基于最新 main。
我已熟悉架构分层（UI 只展示、逻辑在 product/control、文案进 ARB、主题在 app_theme）
和关键纪律（l10n 只属于 UI 层、凭证不进主题、不用 git add -A）。

把你的具体需求发给我，我会先判断改动落在哪一层，再按红→绿→整理实现。
```
