# Account Restore Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** 冷启动时立即展示上次已确认的账号资料和磁盘缓存头像，同时用轻量同步指示器告知用户后台正在核验登录态。

**Architecture:** `AccountSessionStore` 在现有安全存储中连同 session 保存最后确认的 `AppUser`；`AccountController.restore()` 先发布缓存身份，再调用 `/me` 和 RevenueCat 刷新权威状态。头像继续使用服务端 URL，但改由持久化图片缓存 provider 加载；缓存资料不授予 Premium 权限，401 时仍清除本地 session。个人卡在已登录且账号控制器 `busy` 时显示小型同步转圈。

**Tech Stack:** Flutter、Dart、flutter_secure_storage、cached_network_image、package:test、flutter_test

---

### Task 1: 缓存账号资料并优先恢复展示

**Files:**
- Modify: `lib/product/membership_status.dart`
- Modify: `lib/platform/account_session_store.dart`
- Modify: `lib/control/account_controller.dart`
- Test: `test/account_session_store_test.dart`
- Test: `test/account_controller_test.dart`

**Step 1: Write the failing tests**

- 保存带 `AppUser` 的 session 后能完整读回。
- `/me` 尚未返回时，`restore()` 已把缓存用户发布为登录态且 `busy == true`。
- `/me` 返回后用最新用户覆盖缓存，并令 `busy == false`。
- 401 仍清除 session、缓存用户和登录态。

**Step 2: Run tests to verify RED**

Run: `flutter test test/account_session_store_test.dart test/account_controller_test.dart`

Expected: FAIL，因为 `SavedAccountSession` 尚不保存用户，`AccountController` 也没有 `restoring` 和提前发布缓存的行为。

**Step 3: Write the minimal implementation**

- 为 `AppUser` 增加对称 JSON 序列化。
- 为 `SavedAccountSession` 增加可空 `user`；安全存储用单个 JSON 字段保存，损坏或账号 ID 不匹配时忽略资料但保留 session。
- `restore()` 读到 session 后立即设置 token、appUserId、缓存用户并通知 UI，再请求 `/me`。
- 所有新鲜 snapshot 和资料编辑结果都回写同一 session；沿用 generation 与串行身份写入守卫。
- 复用现有 `busy` 表达账号同步，不新增重复状态。

**Step 4: Run tests to verify GREEN**

Run: `flutter test test/account_session_store_test.dart test/account_controller_test.dart`

Expected: PASS。

### Task 2: 持久头像缓存与轻量同步图标

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated: `lib/l10n/app_localizations*.dart`
- Test: `test/profile_page_test.dart`

**Step 1: Write the failing widget tests**

- 恢复未完成时，个人卡显示缓存昵称、邮箱和 `profile-account-sync-indicator`。
- 恢复完成后同步图标消失。
- Google 头像 URL 使用持久缓存图片 provider。

**Step 2: Run test to verify RED**

Run: `flutter test test/profile_page_test.dart`

Expected: FAIL，因为同步指示器和持久图片 provider 尚不存在。

**Step 3: Write the minimal implementation**

- 使用 `cached_network_image` 的 provider 替换 `NetworkImage`，保留默认头像作为失败兜底。
- 在 VIP 标记左侧放置 16–18px 的低对比度 `CircularProgressIndicator`，仅在已登录且 `controller.busy` 时出现，并提供本地化语义标签。

**Step 4: Run test to verify GREEN**

Run: `flutter test test/profile_page_test.dart`

Expected: PASS。

### Task 3: 全量验证与交付

**Step 1:** Run `flutter analyze`，Expected: no issues。

**Step 2:** Run `flutter test`，Expected: all tests pass，回放基线保持 5/5/3。

**Step 3:** Run `git diff --check`，Expected: no output。

**Step 4:** 使用 `--dart-define-from-file=E:\AII\运动app-prod-info.txt` 构建 Debug APK；只报告结果，不输出配置值。

**Step 5:** 显式提交本次文件，不触碰 `docs/handoff-account-features.md`，不做远端写入。
