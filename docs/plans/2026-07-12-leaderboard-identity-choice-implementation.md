# Leaderboard Identity Choice Implementation Plan

> **状态：已废弃。** 本计划中的 `custom` 模式已被 [2026-07-14-custom-avatar-design.md](2026-07-14-custom-avatar-design.md) 废弃；当前仅保留 `profile` / `anonymous` 两种模式。

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans and superpowers:test-driven-development to implement this plan task-by-task.

**Goal:** 加入运动广场时让用户选择当前个人资料、榜单专用身份或匿名身份，并在排行榜中只公开用户明确选择的名字和头像。

**Architecture:** D1 的 `leaderboard_profiles` 保存身份模式和榜单专用字段；Worker 在查询时统一解析最终公开身份，旧资料和旧加入请求默认匿名。Flutter 只提交选择并渲染服务端已经裁决的公开字段，账号资料仅用于加入弹窗预览。

**Tech Stack:** Flutter/Dart、Cloudflare Worker TypeScript、D1/SQLite、Wrangler migrations、`node:test`、`flutter_test`、现有 `cached_network_image`

---

### Task 1: 为榜单身份增加可迁移的 D1 字段

**Files:**
- Create: `workers/membership-api/migrations/0003_leaderboard_identity.sql`
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/test/schema-migration.test.mjs`
- Modify: `workers/membership-api/test/helpers/d1_sqlite.mjs`

**Step 1: 写失败的迁移测试**

在 `assertFullSchema()` 中要求 `leaderboard_profiles` 具有：

```text
identity_mode
leaderboard_nickname
leaderboard_nickname_key
leaderboard_avatar_key
anonymous_avatar_key
```

并要求存在唯一索引 `leaderboard_profiles_nickname_key_idx`。在 legacy upgrade 测试中断言旧排行榜资料升级后 `identity_mode == "anonymous"`，确保升级不会自动公开个人资料。

**Step 2: 运行测试确认 RED**

Run:

```powershell
cd workers/membership-api
npm run build:test
node --test --test-name-pattern "migrations" test/schema-migration.test.mjs
```

Expected: FAIL，缺少身份字段或唯一索引。

**Step 3: 写最小迁移和 schema snapshot**

`0003_leaderboard_identity.sql` 增加：

```sql
ALTER TABLE leaderboard_profiles ADD COLUMN identity_mode TEXT NOT NULL DEFAULT 'anonymous';
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_nickname TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_nickname_key TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_avatar_key TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN anonymous_avatar_key TEXT NOT NULL DEFAULT 'ring-green';

UPDATE leaderboard_profiles
SET anonymous_avatar_key = CASE ABS(rowid) % 5
  WHEN 0 THEN 'ring-green'
  WHEN 1 THEN 'ring-lime'
  WHEN 2 THEN 'ring-sky'
  WHEN 3 THEN 'ring-yellow'
  ELSE 'ring-coral'
END;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_profiles_nickname_key_idx
ON leaderboard_profiles(leaderboard_nickname_key)
WHERE leaderboard_nickname_key IS NOT NULL;
```

`schema.sql` 的新建表定义直接包含相同字段和索引，不加入裸 `ALTER`。扩展 `seedLeaderboardProfile()`，测试可显式传入身份字段。

**Step 4: 运行迁移测试确认 GREEN**

Run: `npm test`

Expected: 全部 Worker 测试通过，迁移首次执行、重复执行和 legacy upgrade 都成功。

**Step 5: 提交**

```powershell
git add -- workers/membership-api/migrations/0003_leaderboard_identity.sql workers/membership-api/schema.sql workers/membership-api/test/schema-migration.test.mjs workers/membership-api/test/helpers/d1_sqlite.mjs
git commit -m "feat(worker): add leaderboard identity schema"
```

### Task 2: 保存加入选择并支持已加入用户修改

**Files:**
- Modify: `workers/membership-api/src/profile.ts`
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify: `workers/membership-api/test/profile.test.mjs`

**Step 1: 写失败的 Worker 测试**

覆盖：

- 旧版无 body 的 `POST /leaderboard/join` 保存 `anonymous`。
- `profile` 模式不保存榜单昵称或榜单头像。
- `custom` 模式保存合法且唯一的昵称和预设头像。
- `anonymous` 模式清空榜单专用字段并保留稳定匿名头像。
- `PATCH /leaderboard/identity` 只允许已加入且会员有效的用户修改。
- 切换离开 `custom` 时释放唯一昵称。
- 无效昵称、无效头像、重复昵称和无效 mode 返回稳定错误码。

**Step 2: 运行目标测试确认 RED**

Run:

```powershell
npm run build:test
node --test --test-name-pattern "identity|custom nickname|old join" test/leaderboard.test.mjs test/leaderboard-sql.test.mjs
```

Expected: FAIL，因为加入接口不读取身份，修改接口不存在。

**Step 3: 写最小服务端实现**

- 从 `profile.ts` 导出并复用现有 `normalizeNickname()` 和昵称合法性判断，避免个人资料与榜单专用昵称采用两套规则。
- 接受以下 JSON；加入请求 body 为空时返回匿名选择：

```json
{ "mode": "profile" }
{ "mode": "custom", "nickname": "阿开", "avatarKey": "ring-green" }
{ "mode": "anonymous" }
```

- 使用一个内部 `writeLeaderboardIdentity()` 完成 join/update 共用的字段校验和 SQL 写入；不要新增单实现接口层或 repository 抽象。
- `POST /leaderboard/join` 保留当前 Premium、重复加入和重新加入清分规则，只在同一批写入中补充身份字段。
- 新增 `PATCH /leaderboard/identity` 路由。未加入返回 `leaderboard_not_joined`，昵称冲突返回 `nickname_taken`。
- 匿名头像只从现有 `ring-*` 五种颜色中选择；已有值保持不变，新用户按稳定的 `userId` 字符散列选一个并写入 D1。

**Step 4: 运行测试确认 GREEN**

Run: `npm test`

Expected: 全部 Worker 测试通过，原有重复加入、退出和重新加入行为不变。

**Step 5: 提交**

```powershell
git add -- workers/membership-api/src/profile.ts workers/membership-api/src/leaderboard.ts workers/membership-api/src/index.ts workers/membership-api/test/profile.test.mjs workers/membership-api/test/leaderboard.test.mjs workers/membership-api/test/leaderboard-sql.test.mjs
git commit -m "feat(worker): save leaderboard identity choices"
```

### Task 3: 由 Worker 解析最终允许公开的榜单身份

**Files:**
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`

**Step 1: 写失败的真实 SQLite 测试**

为日榜和周榜至少覆盖：

- `profile`：`users.nickname/avatar_key` 有值时优先；缺失字段分别回退到 `display_name/avatar_url`。
- `custom`：只返回榜单专用昵称和预设头像。
- `anonymous`：`nickname` 和 `avatarUrl` 均不返回，只有匿名预设头像；Google/App 资料不能泄漏。
- 旧行或未知 mode 安全回退匿名。
- 响应顶层只为当前用户返回可编辑的 `identity` 状态。
- 0 次成员、过期会员和退出用户仍遵守现有规则。

**Step 2: 运行测试确认 RED**

Run:

```powershell
npm run build:test
node --test --test-name-pattern "public identity|anonymous privacy|profile fallback" test/leaderboard-sql.test.mjs
```

Expected: FAIL，因为查询尚未读取身份字段、Google 头像或 display name。

**Step 3: 最小扩展查询和响应**

查询继续从 `leaderboard_profiles` 出发并保留现有会员过滤、`LEFT JOIN` 成绩和排序，只增加：

```text
profiles.identity_mode
profiles.leaderboard_nickname
profiles.leaderboard_avatar_key
profiles.anonymous_avatar_key
users.display_name
users.avatar_url
users.nickname
users.avatar_key
```

在 TypeScript 中解析公开行：

```text
profile   -> nickname ?? display_name；avatar_key ?? avatar_url
custom    -> leaderboard_nickname + leaderboard_avatar_key
anonymous -> nickname null + anonymous_avatar_key + avatarUrl null
```

响应行增加可空 `avatarUrl`；匿名名称继续由客户端本地化为“匿名训练者”。顶层 `identity` 只描述当前用户选择，不向其他用户公开 mode 或专用配置。

**Step 4: 运行测试确认 GREEN**

Run: `npm test`

Expected: Worker 全量测试通过。

**Step 5: 提交**

```powershell
git add -- workers/membership-api/src/leaderboard.ts workers/membership-api/test/leaderboard-sql.test.mjs workers/membership-api/test/leaderboard.test.mjs
git commit -m "feat(worker): resolve public leaderboard identities"
```

### Task 4: 扩展 Flutter 模型、API 与控制器

**Files:**
- Modify: `lib/product/leaderboard_models.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/control/leaderboard_controller.dart`
- Modify: `lib/control/account_controller.dart`
- Modify: `lib/main.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/leaderboard_controller_test.dart`
- Modify: `test/account_controller_test.dart`

**Step 1: 写失败的 Dart 测试**

覆盖：

- `LeaderboardRow` 解析 `nickname`、`avatarKey`、`avatarUrl`。
- `LeaderboardSnapshot` 解析当前用户的身份选择。
- API 加入请求发送选择 JSON，修改请求发送 `PATCH /leaderboard/identity`。
- Controller 把选择传给 join/update，并在成功后刷新当前周期。
- 昵称冲突和非法昵称映射为稳定错误码。
- 账号切换或退出发生在 await 期间时，旧身份修改结果不能覆盖新账号状态。
- `AccountController.currentSession.user` 提供当前资料用于加入预览。

**Step 2: 运行测试确认 RED**

Run:

```powershell
flutter test test/membership_api_client_test.dart test/leaderboard_controller_test.dart test/account_controller_test.dart
```

Expected: FAIL，模型和方法签名尚无身份参数。

**Step 3: 写最小 Dart 实现**

增加：

```dart
enum LeaderboardIdentityMode { profile, custom, anonymous }

class LeaderboardIdentityChoice {
  const LeaderboardIdentityChoice({
    required this.mode,
    this.nickname,
    this.avatarKey,
  });
}
```

- 模型只保存 UI/API 真正需要的字段，不增加通用序列化框架。
- `MembershipApiClient` 使用现有 `_parseJson()` 和 `http` 依赖。
- Controller 继续沿用 `_runGeneration` 和 session token/app user id 守卫。
- `AccountController.currentSession` 带上 `_user`；不新增第二套账号 provider。
- `main.dart` 只补充 update identity wiring。

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/membership_api_client_test.dart test/leaderboard_controller_test.dart test/account_controller_test.dart`

Expected: PASS。

**Step 5: 提交**

```powershell
git add -- lib/product/leaderboard_models.dart lib/platform/membership_api_client.dart lib/control/leaderboard_controller.dart lib/control/account_controller.dart lib/main.dart test/membership_api_client_test.dart test/leaderboard_controller_test.dart test/account_controller_test.dart
git commit -m "feat(app): add leaderboard identity contracts"
```

### Task 5: 实现加入选择、身份编辑和公开头像显示

**Files:**
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated: `lib/l10n/app_localizations.dart`
- Modify generated: `lib/l10n/app_localizations_zh.dart`
- Modify generated: `lib/l10n/app_localizations_en.dart`
- Modify: `test/leaderboard_page_test.dart`

**Step 1: 写失败的 Widget 测试**

覆盖：

- 点击“加入广场”先打开身份选择 sheet，不立即调用 join。
- 默认选中匿名；三张卡均显示预览和隐私说明。
- `profile` 预览优先 App 昵称/头像，缺失时显示 Google 名字/照片。
- `custom` 展开昵称输入和现有预设头像；输入和选择提交给 Controller。
- 请求失败或昵称重复时 sheet 保持打开，内容不丢失。
- 已加入用户从“我的排名”编辑按钮打开相同 sheet。
- 榜单行显示公开昵称；匿名行显示本地化“匿名训练者”。
- `avatarKey` 使用现有预设图标，`avatarUrl` 使用已安装的 `CachedNetworkImageProvider`，加载失败显示默认头像。
- 中英文文案与语义标签存在。

**Step 2: 运行测试确认 RED**

Run: `flutter test test/leaderboard_page_test.dart`

Expected: FAIL，当前加入按钮直接 join，榜单名称固定为匿名。

**Step 3: 写最小 UI 实现**

- 复用 `profile_page.dart` 的现有头像规格和 `cached_network_image`，不新增依赖。
- 在 `leaderboard_page.dart` 内增加单个私有 identity sheet；加入和编辑共用，通过初始值区分。
- Sheet 使用单选卡、预览、条件输入区和“取消/确认”按钮；匿名默认。
- “我的排名”卡只增加一个轻量编辑图标，保留退出按钮。
- 行名称使用 `row.nickname ?? l10n.leaderboardAnonymousName`。
- 错误继续使用稳定 error code 映射，不显示原始异常。
- 运行 `flutter gen-l10n` 更新生成文件。

**Step 4: 运行测试确认 GREEN**

Run:

```powershell
flutter gen-l10n
flutter test test/leaderboard_page_test.dart
```

Expected: PASS，无 overflow 或未处理异步异常。

**Step 5: 提交**

```powershell
git add -- lib/ui/pages/leaderboard_page.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart test/leaderboard_page_test.dart
git commit -m "feat(ui): choose public leaderboard identity"
```

### Task 6: 全量验证、部署和交接

**Step 1: Worker 全量验证**

Run: `cd workers/membership-api && npm test`

Expected: 全部通过。

**Step 2: Flutter 全量验证**

Run:

```powershell
flutter analyze
flutter test
```

Expected: analyze 0 issue；全部测试通过；回放基线保持 5/5/3。

**Step 3: 差异和秘密检查**

Run:

```powershell
git diff --check
git status --short --branch
```

显式确认未修改或 stage `docs/handoff-account-features.md`，代码和文档中没有 Token、Secret、个人邮箱或构建配置值。

**Step 4: 获取用户远端授权**

部署前明确说明：

- D1 将应用 migration `0003_leaderboard_identity.sql`。
- Worker 将先以兼容旧 App 的形式部署。
- 不修改 RevenueCat、Webhook Secret 或会员数据。

只有用户明确同意后，才使用本机受保护 Token 文件执行 remote migration 与 `wrangler deploy --keep-vars`。不得输出 Token 值。

**Step 5: 线上和真机验收**

- 旧 App 加入请求默认匿名。
- 新 App 三种模式分别真机验证日榜和周榜。
- 修改个人资料后 `profile` 模式自动更新。
- 切换匿名后旧名字/照片立即消失。
- 专用昵称重复提示正确，头像失败有兜底。

**Step 6: 记录与提交**

- App 仓库只记录公开行为、migration 名称和通用验证结果。
- `E:\AII\pushup-ai-info` 私密台账记录准确部署版本、日期、Token 文件键名、D1 migration 和回滚路径，不记录任何值。
- 显式 stage 本功能文件并提交；不 merge/rebase/push，等待用户决定整合方式。
