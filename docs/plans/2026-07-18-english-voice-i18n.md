# English Voice I18n Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让训练页按照 App 的中文、英文或跟随系统语言选择对应的中文/英文离线播报，同时保持现有中文默认行为不变。

**Architecture:** `VoicePromptPlayer` 在 product 层仅接收音频资源目录并统一拼接文件名；`AppSettingsController` 所在 UI 设置层负责把 `AppLanguage + 设备 Locale` 解析为实际播报目录；`WorkoutPage` 将目录传给 `WorkoutController`，controller 在未注入测试 fake 时据此创建 player。语音 WAV 不走 ARB，运行中的训练不热切换语言，下次进入训练页生效。

**Tech Stack:** Flutter/Dart、`audioplayers`、Flutter unit/widget tests、Flutter asset bundle。

---

### Task 1: 参数化 VoicePromptPlayer 的资源目录

**Files:**
- Create: `test/voice_prompt_player_test.dart`
- Modify: `lib/product/voice_prompt_player.dart`

**Step 1: 写失败测试**

- 用记录型 `AudioPlayer` fake 调用 `VoicePromptPlayer().playGuide()`，断言默认 `AssetSource.path == 'audio/prompts/guide.wav'`。
- 用 `VoicePromptPlayer(baseDir: 'audio/voices/manbo/en')` 调用 `playReady()` 和 `playCount(1)`，断言实际播放路径使用英文目录并保留 `count_01.wav` 命名。
- 用记录型 `AudioCache` 调用 `preloadCounts()`，断言 30 个预加载路径全部使用英文目录，首尾为 `count_01.wav`/`count_30.wav`。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/voice_prompt_player_test.dart`

Expected: FAIL，因为构造函数尚无 `baseDir`，播放和预加载仍硬编码 `audio/prompts`。

**Step 3: 写最小实现**

- 给 `VoicePromptPlayer` 增加 `baseDir` 参数，默认值为 `audio/prompts`。
- `guide.wav`、`ready.wav`、`count_NN.wav` 和 `preloadCounts()` 统一通过该目录拼接。
- 不改变 1–30 范围、队列、stop/dispose 或播放中断语义。

**Step 4: 验证测试通过**

Run: `flutter test test/voice_prompt_player_test.dart test/voice_prompt_assets_test.dart`

Expected: PASS。

### Task 2: 解析 App 语言与系统 Locale

**Files:**
- Modify: `test/app_settings_test.dart`
- Modify: `lib/ui/app_settings.dart`

**Step 1: 写失败测试**

为纯函数 `voicePromptBaseDirFor(AppLanguage, Locale)` 覆盖：

- 显式 `zh` 永远返回 `audio/prompts`。
- 显式 `en` 永远返回 `audio/voices/manbo/en`。
- `system + zh_CN/zh_TW` 返回中文。
- `system + en_US` 返回英文。
- `system + ja_JP` 返回英文，作为当前仅支持中英两套语音时的通用 fallback。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/app_settings_test.dart`

Expected: FAIL，因为解析函数尚不存在。

**Step 3: 写最小实现**

在 `lib/ui/app_settings.dart` 增加目录常量和纯解析函数；不得 import `AppLocalizations`，不得修改持久化语言枚举。

**Step 4: 验证测试通过**

Run: `flutter test test/app_settings_test.dart`

Expected: PASS。

### Task 3: 贯通 Controller、WorkoutPage 与 HomePage

**Files:**
- Modify: `test/workout_controller_test.dart`
- Modify: `test/workout_page_test.dart`
- Modify: `test/home_page_test.dart`
- Modify: `lib/control/workout_controller.dart`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `lib/ui/pages/home_page.dart`

**Step 1: 写失败测试/契约**

- controller 构造契约断言：未传 `voice` 时将 `voiceBaseDir` 交给 `VoicePromptPlayer(baseDir: ...)`，已有 fake voice DI 仍可用。
- HomePage widget test：英文设置进入训练页后，`WorkoutPage.settingsController` 是同一个设置 controller。
- 语言纯函数测试已负责 system/zh/en 分支；WorkoutPage 使用设备 `platformDispatcher.locale` 解析目录。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/workout_controller_test.dart test/workout_page_test.dart test/home_page_test.dart`

Expected: FAIL，因为参数与透传链路尚不存在。

**Step 3: 写最小实现**

- `WorkoutController` 构造增加默认中文的 `voiceBaseDir`，并保留 `VoicePromptPlayer? voice` 优先级。
- `WorkoutPage` 增加必需的 `AppSettingsController settingsController`；仅在自行构造 controller 时，用设置语言和设备 locale 解析 `voiceBaseDir`。
- 所有测试与生产调用点传入 settings controller；`HomePage` 透传现有单例。
- 不修改异步 session 守卫和训练生命周期。

**Step 4: 验证测试通过**

Run: `flutter test test/workout_controller_test.dart test/workout_page_test.dart test/home_page_test.dart`

Expected: PASS。

### Task 4: 注册英文素材并更新主题元数据

**Files:**
- Modify: `pubspec.yaml`
- Modify: `assets/audio/voices/manbo/voice_meta.json`
- Modify: `test/voice_prompt_assets_test.dart`

**Step 1: 写失败测试**

- 通过 `rootBundle.load()` 断言 32 个英文 WAV 实际进入测试 asset bundle。
- 断言英文目录有且仅有 32 个约定 WAV，均为 PCM_16、单声道、24000Hz。
- 断言 `voice_meta.json` 的 `languages` 为 `['zh', 'en']`，并保留文件范围 1–30。

**Step 2: 验证测试按预期失败**

Run: `flutter test test/voice_prompt_assets_test.dart`

Expected: FAIL，因为 bundle 尚未注册 voices，meta 仍是单值 `language: zh`。

**Step 3: 写最小实现**

- 在 Flutter assets 中精确注册 `assets/audio/voices/manbo/en/`（Flutter 目录声明不递归）。
- 将 meta schema 的 `language` 单值改为 `languages` 数组，不修改 WAV。
- 同步 `docs/modules/voice-themes.md` 的当前状态、meta 示例和已完成演进项，避免权威文档继续声称 player 只读单主题。

**Step 4: 验证测试通过**

Run: `flutter test test/voice_prompt_assets_test.dart`

Expected: PASS。

### Task 5: 全量验证与独立审查循环

**Files:**
- Modify only files required by review findings.

**Step 1: 自动化收尾**

Run:

```powershell
dart format lib/product/voice_prompt_player.dart lib/control/workout_controller.dart lib/ui/app_settings.dart lib/ui/pages/workout_page.dart lib/ui/pages/home_page.dart test/voice_prompt_player_test.dart test/voice_prompt_assets_test.dart test/app_settings_test.dart test/workout_controller_test.dart test/workout_page_test.dart test/home_page_test.dart
flutter analyze
flutter test
git diff --check
```

Expected: analyze 0 issue；全量测试全绿；回放基线 step0=5、v3=5、v4=3；diff check 通过。

**Step 2: 独立审查**

启动独立审查子代理，只读检查需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果，返回带严重级别、文件/行号、复现证据的修复清单，不允许直接改代码。

**Step 3: 主线程修复与复验**

主线程对每个有效问题先补失败测试再修复；重新执行相关测试、`flutter analyze`、`flutter test`、`git diff --check`，再让同一审查子代理复验。循环至通过或明确阻塞。

**Step 4: 真机烟测**

若授权真机在线，使用带本机构建配置的 Debug resident 会话或安全的覆盖安装，验证显式英文、显式中文及系统模式对应的 guide/ready/count 播报。不得卸载 App、清数据、回显设备序列号或修改远端。

**Step 5: 本地提交**

仅显式 stage 本任务文件，禁止 `git add -A`；创建本地提交但不 push。最终报告本会话实际测试数量、真机是否完成、未验证边界和远端零写入事实。
