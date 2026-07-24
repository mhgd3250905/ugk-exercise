# ugk-post 开发指南：如何在现有架构里开发一个功能

> 本文档告诉你：在这个项目里加一个功能，代码该放哪、怎么分块、按什么顺序写。
> 它是从项目**真实的分层和依赖**提炼的，不是通用方法论。当前实现配合各 `docs/modules/` 阅读；`docs/architecture-analysis.md` 仅用于理解 `c7c6593` 重构前历史。
>
> 改完后该在本地、内部测试还是 Alpha 验证，见 [testing-release-playbook.md](testing-release-playbook.md)。

## 1. 分层地图（先记住这个）

```
pushup_domain.dart        ← 地基：纯算法，零 Flutter 依赖。所有人都能依赖它，它不依赖任何人。
       ↑
product/                  ← 产品规则（计数管线、门控、存储、语音）。只依赖 domain。
       ↑
control/                  ← 编排（WorkoutController 把 product + 基础设施串起来）。依赖 product + infra。
       ↑
ui/pages/                 ← 纯展示。只依赖 control + product + app_theme，依赖 ChangeNotifier 监听状态。
```

基础设施层（inference / pipeline / platform）平行存在，被 control 和 ui 按需调用，依赖 domain。

**铁律：依赖只能向上指。** `domain` 不 import 任何上层；`product` 不 import `control`/`ui`；`ui` 不被任何下层 import。`architecture_contract_test.dart` 守护部分约束，新功能要自觉遵守。

## 2. 先判断：你的功能属于哪一层？

在写代码前，先问自己一个问题——**这个功能的"心脏"是什么？**

| 如果核心是… | 放在哪 | 例子 |
|------------|--------|------|
| 一个算法/规则/数据模型（不碰硬件、不碰 UI） | `pushup_domain.dart` 或新 domain 文件 | 计数器、信号提取、阈值 |
| 产品逻辑（用算法 + 规则组成一个能力） | `product/` | 准备态门控、腕锚点、计数管线装配 |
| 把多个能力串成一次会话/流程 | `control/` | 训练编排器 |
| 用户看到的东西 | `ui/pages/` 或 `ui/widgets/` | 页面、组件 |
| 和硬件/系统打交道 | `inference/` `pipeline/` `platform/` | 相机、推理、文件 |

**判断标准**：能不能脱离 Flutter 测？能 → domain/product；不能 → 往上走。

## 3. 标准开发动作（按功能类型）

### 类型 A：改识别算法 / 加新计数规则（最常见）

**例：加一个"深蹲检测"模式，或调计数阈值，或加新的对抗样本过滤。**

1. **改 domain**：`pushup_domain.dart`。算法逻辑改这里。这是纯 dart，可直接写测试。
2. **写测试**：`test/domain_self_check_test.dart` 加用例。先写**失败测试**（复现你要的行为），再改算法让它过。
3. **验证基线**：跑 `flutter test`，确认回放基线 5/5/3 不破（除非你明确改了信号源）。
4. **不动 ui/control**：算法变了，上层自动跟着变——因为 PushupPipeline 封装了装配，上层只调 `process()`。

**关键纪律**：算法改动**不要**在 WorkoutController 或 workout_page 里写。那里只编排，不算数。

### 类型 B：加一个新的"门控"或"规则"（如 WristAnchor 那样）

**例：加一个"躯干水平偏移检测"防止用户身体左右晃。**

1. **新建 `product/xxx_gate.dart`**：只依赖 domain。仿照 `wrist_anchor.dart` 的结构——一个类，calibrate/update/isXxx + reset。
2. **写测试**：`test/xxx_gate_test.dart`，覆盖正常/异常/边界。
3. **接入 pipeline**：在 `product/pushup_pipeline.dart` 的 `process()` 里注入这个新信号（像 handsStable 那样从外部传入，或 pipeline 内部持有）。
4. **接入 controller**：`control/workout_controller.dart` 在每帧调它，结果传给 pipeline。
5. **ui 不用改**（除非要显示这个状态）。

### 类型 C：加一个新页面

**例：加一个"设置页"。**

1. **新建 `ui/pages/settings_page.dart`**：只 import 它需要的（app_theme、product store 等）。仿照 `records_page.dart` 的结构。
2. **如果页面有复杂逻辑**：抽一个 controller（仿 WorkoutController），放 `control/`，`extends ChangeNotifier`，页面用 `ListenableBuilder` 监听。
3. **导航**：在 home_page 里 `Navigator.push(MaterialPageRoute(builder: (_) => SettingsPage()))`。
4. **测试**：简单页面可不测；有逻辑的抽 controller 测 controller（仿 `workout_page_test.dart` 的 fake controller 注入）。

### 类型 D：改训练流程（最复杂，最要小心）

**例：加"组间休息"功能、加"语音鼓励"、改停止流程。**

1. **先想清楚逻辑放 controller 还是 page**：规则是——**不碰 BuildContext/Navigator/Widget 的逻辑进 controller，碰的留 page**。参考 §4 的"关注点分离边界"。
2. **改 controller**：`control/workout_controller.dart`。注意保留 session 竞态守卫（每个 await 后校验 `session != _session`）。
3. **改 page**：`ui/pages/workout_page.dart` 只改渲染和"导航/存储"部分。
4. **测试**：controller 的逻辑用注入的 fake 测（仿 workout_page_test）；真机验证全流程（启动→训练→异常→停止）。
5. **更新 architecture_contract_test**：如果改了 controller 的关键方法签名/顺序，同步更新那里的源码断言。

### 类型 E：Flutter UI 高频迭代（默认工作流）

普通 Dart/Widget 界面调整不得每改一点就完整打包。默认保持一个 resident Flutter 调试会话：

1. **首次连接并安装一次**：运行 `flutter run -d <device> --dart-define-from-file=<本机构建配置>`，不要加 `--no-resident`，终端保持运行。
2. **改普通页面/组件/样式**：在 Flutter 终端按 `r` 做 Hot Reload，保留当前页面和状态，优先用它完成高频视觉迭代。
3. **需要重跑 Dart 启动流程**：按 `R` 做 Hot Restart，重新执行 `main()`；自制启动页的 Dart/UI 调整先用这个验证，但它不会重放 Android 原生系统 Splash。
4. **只做一次最终冷启动验收**：界面确认后再更新安装包并冷启动，验证 Android 系统 Splash → Flutter 自制启动页、真实进程启动和构建配置。

只有以下情况才直接重新构建/安装：修改 Android/Kotlin、Manifest、Gradle、插件注册、原生系统 Splash 资源，切换 `dart-define`/构建模式/ABI，或正在做最终冷启动验收。Hot Reload 未生效时先试 Hot Restart，不要立即清缓存或完整打包。

## 4. 关注点分离的判断标准（最容易搞混的）

这是新功能最常犯错的地方。记住这个清单：

| 这个逻辑… | 放 controller | 放 page(State) |
|----------|:---:|:---:|
| 用到 BuildContext / Navigator / MediaQuery | | ✓ |
| 写本地存储（store.append） | | ✓ |
| 读 widget.xxx（构造参数） | | ✓ |
| 调相机/推理/管线/语音 | ✓ | |
| 维护训练状态（count/ready/status） | ✓ | |
| 纯布局/样式/动画 | | ✓ |

**判断不了时，问：这段代码脱离了 Widget 树还能测吗？** 能 → controller；不能 → page。

## 5. 每次开发的标准收尾清单

不论什么功能，完成前都过一遍：

- [ ] `flutter analyze` 无 issue
- [ ] `flutter test` 全绿（且**没破坏**回放基线 5/5/3）；改了 Worker 还要 `cd workers/membership-api && npm test`
- [ ] 新逻辑有对应测试（domain/product 层必须；controller 层尽量）
- [ ] 没有引入反向依赖（下层不 import 上层）
- [ ] 没在 `pushup_domain.dart` 里加 Flutter/platform import
- [ ] **没有用 `git add -A`**（只显式 stage 你改的代码文件，不混入根目录临时文件）
- [ ] **会员凭证没写进 git/app_theme**（见 §6.7）
- [ ] **l10n 没漏到 domain/product/control**（见 §6.8）
- [ ] commit message 说清楚改了什么、为什么

## 6. 常见陷阱（这个项目特有的坑）

1. **不要在 domain 里加 `dart:io` / `package:flutter`**——会破坏纯 dart 地基，`architecture_contract_test` 会抓。
2. **改了计数信号源（如 torsoY）→ 必须重验回放基线**。如果 5/5/3 变了，要么是 bug 要么是预期改动，要明确。
3. **Controller 的异步方法要保留 session 守卫**——漏掉会导致竞态（停止后访问已释放资源、过期推理画骨架）。
4. **测试夹具在 `test/fixtures/`**——脱敏的标量信号，不要把真实关键点坐标塞进 git（隐私）。
5. **`modelPath` 等跨层共享的静态资源常量放在 `lib/config/resource_constants.dart`**——资源常量归 config 层，避免 platform 等基础设施层反向依赖 UI；主题和颜色仍放 `ui/app_theme.dart`。
6. **颜色常量是公开的（`ink`/`green` 无下划线）**——直接 import app_theme 用，不要再建私有副本。
7. **会员凭证只放 `lib/config/membership_config.dart`**——走 `--dart-define` 注入，不设 defaultValue，release 缺值由 `validateMembershipConfig()` fail-fast。绝不写进 `app_theme.dart`、`wrangler.toml` 或测试代码。曾发生过把真实 Google Client ID / RevenueCat Test key 当默认值硬编码进 git，已修正——别再犯。
8. **l10n 只属于 UI/app 根**——`domain`/`product`/`control` 层不 import `AppLocalizations`。用户可见文案先进 ARB（`lib/l10n/app_*.arb`），再 `AppLocalizations.of(context)` 用。语音播报资源是另一条线，和 UI 文案本地化分开。

## 7. 一个完整例子：从零加一个"组间休息计时"功能

走一遍完整流程，演示怎么按层分块：

**Step 1 - domain**：休息计时是纯逻辑（倒计时 + 状态），可放 `pushup_domain.dart` 或新建 `product/rest_timer.dart`。因为它是产品规则（不碰硬件），放 `product/rest_timer.dart`，只依赖 dart。写 `test/rest_timer_test.dart`。

**Step 2 - controller**：`WorkoutController` 加 `RestTimer` 字段 + startRest/stopRest 命令 + `isResting` getter。计时结束调 `notifyListeners`。

**Step 3 - page**：`workout_page.dart` 在 build 里读 `controller.isResting` 显示休息 UI；按钮 onPressed 调 `controller.startRest()`。页面不持有计时逻辑。

**Step 4 - 测试**：rest_timer 单测 + controller 的休息状态用 fake 测 + 真机看 UI。

**Step 5 - 收尾**：过 §5 清单，commit。

---

记住一句话：**先想"心脏"在哪层，从最底层开始写，每层写完立刻测，上层只是薄薄地调用下层。** 这样代码自然分块干净。
