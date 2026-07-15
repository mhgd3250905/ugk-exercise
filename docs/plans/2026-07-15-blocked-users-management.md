# 屏蔽名单与解除屏蔽实现计划

**目标：** 登录用户可从个人设置持续查看屏蔽名单并解除屏蔽，且不泄露匿名榜单用户的账号身份。

**架构：** Worker 基于现有 `user_blocks` 提供只读列表，无 D1 migration；Flutter 在现有排行榜模型、API client 和 `LeaderboardController` 上补齐名单状态，个人设置只负责导航到薄 UI 页面。解除成功后名单立即更新，排行榜沿用进入页面时的现有刷新恢复目标。

**技术栈：** Cloudflare Worker/TypeScript/D1、Flutter/Dart、Node test、Flutter test。

---

### 1. Worker 合同

- 测试：`workers/membership-api/test/avatar-moderation.test.mjs`
- 修改：`workers/membership-api/src/avatar_moderation.ts`、`workers/membership-api/src/leaderboard.ts`、`workers/membership-api/src/index.ts`
- RED：屏蔽后 `GET /me/blocks` 应按时间返回公开身份；匿名目标不得暴露资料；解除后列表为空。
- GREEN：复用排行榜公开身份规则查询现有表并返回 `{blocks: [...]}`。
- 验证：`npm test -- --test-name-pattern="block"`，随后 `npm test`。

### 2. Flutter 模型与 API

- 测试：`test/membership_api_client_test.dart`
- 修改：`lib/product/leaderboard_models.dart`、`lib/platform/membership_api_client.dart`
- RED：验证 `GET /me/blocks` bearer token、字段解析与非法响应拒绝。
- GREEN：增加最小 `BlockedUser` 模型和 `blockedUsers()`。
- 验证：`flutter test test/membership_api_client_test.dart`。

### 3. Controller 状态流

- 测试：`test/leaderboard_controller_test.dart`
- 修改：`lib/control/leaderboard_controller.dart`、`lib/main.dart`
- RED：验证加载、解除后本地移除、失败可重试、切换账号后旧结果被丢弃。
- GREEN：增加独立名单状态与 generation 守卫，复用现有 session provider 和稳定错误码。
- 验证：`flutter test test/leaderboard_controller_test.dart`。

### 4. 设置入口与名单页

- 测试：`test/profile_page_test.dart`
- 新建：`lib/ui/pages/blocked_users_page.dart`
- 修改：`lib/ui/pages/profile_page.dart`、`lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb` 及生成文件。
- RED：登录后设置显示入口；页面覆盖加载、空态、失败重试、解除成功和失败保留。
- GREEN：复用 `UserAvatar`、原生 `ListTile`/按钮和现有 controller，不新增依赖。
- 验证：`flutter test test/profile_page_test.dart`。

### 5. 收尾

- 运行 `flutter analyze`、`flutter test`、Worker `npm test`、`git diff --check`。
- 确认回放 5/5/3，不修改或暂存 `docs/handoff-2026-07-14-membership-explore.md`。
- 不执行部署、D1 写入、push 或平台变更。
