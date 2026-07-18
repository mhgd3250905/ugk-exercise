# Release Recognition Trace Export Implementation Plan

> 状态：已落地。独立复验结论为 P0/P1/P2 均无遗留；尚待 Release/Play 真机文件选择器与小朋友实际动作数据验收。

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让商店 Release 包在用户主动开启后记录最近 20 次运动识别诊断，并从设置页保存为一个可供电脑分析的 JSONL 文件。

**Architecture:** 设置开关由现有 AppSettings 链路持久化，并在创建训练页时快照注入日志记录器；逐帧控制器不读取 UI 或存储。新的 platform 导出服务只读取已关闭的私有 JSONL 会话并通过现有 file_picker 保存，个人页仅负责触发和展示本地化结果。

**Tech Stack:** Dart 3、Flutter、flutter_secure_storage、path_provider、path、file_picker、package_info_plus、flutter_test/test。

---

### Task 1: 持久化 Release 日志开关

**Files:**
- Modify: `test/app_settings_test.dart`
- Modify: `lib/platform/app_settings_store.dart`
- Modify: `lib/ui/app_settings.dart`
- Modify: `test/home_page_test.dart`
- Modify: `test/profile_page_test.dart`

**Step 1: Write the failing tests**

在 `test/app_settings_test.dart` 断言：无保存值时 `recognitionTraceEnabled == false`；保存 `true` 可恢复；`setRecognitionTraceEnabled(true)` 立即通知并持久化。

**Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/app_settings_test.dart`

Expected: FAIL，原因是 store/controller 尚无运动日志设置 API。

**Step 3: Write minimal implementation**

给 `AppSettingsStore` 增加：

```dart
Future<bool?> loadRecognitionTraceEnabled();
Future<void> saveRecognitionTraceEnabled(bool value);
```

`SecureAppSettingsStore` 使用独立键 `ugk_recognition_trace_enabled`；controller 默认 `false`，restore 仅把 `true` 识别为开启，并提供 setter。同步补齐三个测试 fake store。

**Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/app_settings_test.dart`

Expected: PASS。

### Task 2: 留存 20 次并生成可保存的 JSONL 汇总

**Files:**
- Modify: `test/recognition_trace_log_test.dart`
- Modify: `lib/platform/recognition_trace_log.dart`
- Create: `test/recognition_trace_export_test.dart`
- Create: `lib/platform/recognition_trace_export.dart`

**Step 1: Write the failing retention test**

使用默认 `RecognitionTraceLog` 连续写 21 个会话，断言只保留最后 20 个；保留现有可注入 `maxFiles` 的小规模轮转测试。

**Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/recognition_trace_log_test.dart`

Expected: FAIL，当前默认只保留 10 个。

**Step 3: Implement the retention change**

把默认 `maxFiles` 改为 20，并把“解析私有日志目录、按文件名排序列出会话”的能力以最小可复用 API 提供给导出服务。

**Step 4: Run retention tests**

Run: `flutter test --no-pub test/recognition_trace_log_test.dart`

Expected: PASS。

**Step 5: Write failing export tests**

覆盖：

- 空目录返回 `noLogs` 且不调用文件保存器；
- 两个会话按时间从旧到新汇总；
- 第一行是含 schema、UTC 时间、版本、会话数和无原始媒体声明的 manifest；
- 系统保存器返回路径时为 `saved`，返回 null 时为 `cancelled`；
- 文件名形如 `pushupai_recognition_logs_20260718T120000Z.jsonl`。

**Step 6: Run test to verify it fails**

Run: `flutter test --no-pub test/recognition_trace_export_test.dart`

Expected: FAIL，导出服务尚不存在。

**Step 7: Implement the exporter**

新增 `RecognitionTraceExportOutcome { saved, cancelled, noLogs }` 与可注入 clock/version loader/save callback 的 `RecognitionTraceExportService`。默认保存回调调用：

```dart
FilePicker.saveFile(
  fileName: fileName,
  type: FileType.custom,
  allowedExtensions: const ['jsonl'],
  bytes: bytes,
)
```

导出器不吞掉真正的读取/保存异常，让 UI 统一提示失败；用户取消用结果枚举区分。

**Step 8: Run export tests**

Run: `flutter test --no-pub test/recognition_trace_export_test.dart`

Expected: PASS。

### Task 3: 把开关快照接入训练创建链路

**Files:**
- Modify: `test/home_page_test.dart`
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/ui/pages/workout_page.dart`

**Step 1: Write the failing widget test**

将测试 settings controller 的日志开关设为 true，点击首页训练入口，断言创建出的 `WorkoutPage.recognitionTraceEnabled` 为 true；默认场景为 false。

**Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/home_page_test.dart`

Expected: FAIL，WorkoutPage 尚无该属性。

**Step 3: Implement minimal wiring**

`HomePage` 打开训练页时传入当前值；`WorkoutPage` 未注入测试 controller 时构造：

```dart
WorkoutController(
  trace: RecognitionTraceLog(
    enabled: widget.recognitionTraceEnabled,
    maxFiles: 20,
  ),
)
```

这使设置从下一次训练生效，并保持 controller 的逐帧逻辑不接触设置层。

**Step 4: Run focused tests**

Run: `flutter test --no-pub test/home_page_test.dart test/workout_page_test.dart test/workout_controller_test.dart`

Expected: PASS，且 controller session 守卫相关测试不变。

### Task 4: 设置页开关、隐私说明和导出反馈

**Files:**
- Modify: `test/profile_page_test.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Generated: `lib/l10n/app_localizations.dart`
- Generated: `lib/l10n/app_localizations_zh.dart`
- Generated: `lib/l10n/app_localizations_en.dart`

**Step 1: Write failing widget tests**

断言设置页：开关默认关闭；说明本地保存且不含照片/视频/音频；切换后 controller 为 true；导出成功和无日志显示对应 Snackbar；取消不显示错误；异常显示失败；英文界面显示英文文案。

**Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/profile_page_test.dart`

Expected: FAIL，UI 与 l10n getter 尚不存在。

**Step 3: Add ARB messages and generate localization code**

添加设置分组标题、开关标题/说明、导出动作、成功/无日志/失败提示。运行：

`flutter gen-l10n`

**Step 4: Implement minimal UI behavior**

在 `_ProfileSettingsSheet` 增加诊断卡片：`SwitchListTile` 调用 controller setter，`ListTile` 触发导出。`ProfilePage` 接受可选导出回调用于测试；生产默认调用 `RecognitionTraceExportService.export()`。点击导出先关闭设置弹层，随后按结果展示本地化 Snackbar；取消静默。

**Step 5: Run focused tests**

Run: `flutter test --no-pub test/profile_page_test.dart test/app_settings_test.dart`

Expected: PASS。

### Task 5: 文档与全量验证

**Files:**
- Modify: `docs/modules/recognition.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/plans/README.md`

**Step 1: Update operational documentation**

记录 Release 默认关闭、设置路径、20 次留存、日志内容/隐私边界、导出操作和电脑分析方法；明确真实导出文件不得提交 Git。

**Step 2: Format and analyze**

Run: `dart format lib test`

Run: `flutter analyze --no-pub`

Expected: 0 issues。

**Step 3: Run the complete test suite**

Run: `flutter test --no-pub`

Expected: 全绿，回放基线 step0=5、v3=5、v4=3。

**Step 4: Check the patch**

Run: `git diff --check`

Expected: 无输出、退出码 0。确认没有真实日志、视频、CSV、密钥或无关文件进入差异。

### Task 6: 独立审查与复验闭环

**Step 1: Start a read-only review agent**

审查范围为本任务全部差异与实际验证输出；禁止审查 agent 修改文件。要求从需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果六方面给出证据与按优先级排序的修复清单。

**Step 2: Fix each confirmed issue with TDD**

主线程对每个行为问题先补失败测试，再做最小修复；重新运行相关测试、analyze、完整测试和 diff check。

**Step 3: Ask the same review agent to re-verify**

提供修复摘要与最新验证结果；循环步骤 2–3，直到审查 agent 明确通过，或存在需要用户/外部设备的新权限而无法继续，并如实报告阻塞。

### 审查后加固（2026-07-18）

首轮独立审查发现并已纳入实现：小体型会话保留 50px 独立噪声地板；日志采用 `.jsonl.part` 正常关闭后再发布；单次/总量/导出分别限制为 12/24/25 MiB；超限与非法 JSONL 不进入系统保存；日志开关写入串行化，失败时回滚并提示。对应行为均先增加失败测试，再做最小实现，最终状态以本计划的独立复验结果为准。
