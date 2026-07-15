# 审核反馈：codex/membership-custom-avatar（2026-07-15）

> 本文件是对分支 `codex/membership-custom-avatar`（HEAD `2f13bfd`）的 main 侧审核反馈。
> 接手 agent 请先读本文件，按下方两个行动项处理，然后重新推送。

## 处理结果（2026-07-15）

- 最终选择方案 C：保持上传后立即公开，不增加逐张人工预审核。Google Play 的 UGC 政策要求规则接受、举报、屏蔽、持续处置和与 UGC 类型相称的审核，但不强制每张头像公开前人工批准；当前仅有开发者本人测试，预审核工作量与现阶段风险不匹配。
- 保留现有规则接受、App 内举报/屏蔽、管理员下架、隐藏网络头像、暂停上传和审计记录。面向更多真实用户开放前，仍须确认举报处理责任能够持续履行；若滥用量上升，再评估自动扫描或预审核。
- 公开头像响应已增加 `X-Content-Type-Options: nosniff`。`ACCESS_TEAM_DOMAIN` / `ACCESS_AUD` 仍须在下一次获授权部署前确认已配置，本次不读取或修改远端配置。
- 分支已 rebase 到最新 `origin/main@9f78ce7`；本次不新增 D1 migration，也不部署 Worker、D1 或政策网站。

最终验证：`flutter analyze` 0 issue，`flutter test` 363/363，Worker `npm test` 125/125，`git diff --check` 通过。

## 审核基线

- 审核分支：`codex/membership-custom-avatar`（HEAD `2f13bfd`，8 个提交）
- 审核基点：`origin/main` 当时 @ `4742abe`
- **当前 main 已前进到 `a2b75d9`**（领先 15 个提交，含会员付费墙 + 0.3.4 release + docs）
- 审核方式：独立复跑 Flutter analyze/test + Worker test + Worker UGC 安全审计 + 架构/凭证核查

## 总体结论

**代码质量通过。** Flutter 356/356、Worker 125/125、analyze 0 issue。Worker 上传安全（magic bytes / 大小限制 / R2 key 安全 / SQL 零注入）、admin 鉴权（Cloudflare Access JWT + CSRF + CSP + 审计）、凭证零泄露——这些都做得很好。

**但有 2 个问题必须在合并前处理**（见下方行动项 1、2）。

---

## 行动项 1：UGC 头像无预审核——需评估并给出发布安全方案（必须处理）

### 问题

头像上传后立即 `status='active'` 并在排行榜公开服务。审核是纯反应式的（举报→人工处理）。D1 schema 的 `avatar_objects.status` 枚举只有 `('active', 'replaced', 'removed')`，**没有 `pending`/`approved` 状态**。

这意味着：用户上传的任何图片（包括潜在的违规/违法内容）在管理员看到之前就已经对排行榜所有用户公开可见，直到有人举报且管理员手动下架。

### 证据

- `workers/membership-api/migrations/0004_custom_avatar_ugc.sql`：`status TEXT NOT NULL CHECK (status IN ('active', 'replaced', 'removed'))` — 无 pending 状态
- `workers/membership-api/src/avatar.ts:167`：`uploadAvatar` 插入即为 `status='active'`
- `workers/membership-api/src/avatar.ts:170-171`：立即将 `users.custom_avatar_object_id` 指向新上传对象
- `workers/membership-api/src/leaderboard.ts:366-378`：`publicIdentity` 只要 `custom_avatar_status === "active"` 就返回头像 URL

### 政策文档的态度

`docs/policies/user-content-policy.md` 已明确记录了这个设计取舍，并有清醒的发布门槛：

> "若无人能够持续履行上述检查，应暂停公开自定义头像上线，而不是带着无人审核的队列发布。"

这说明开发者**知道**风险。但"知道风险"和"代码层面有防护"是两回事——当前代码层面没有任何阻止未审核内容即时公开的机制。

### 需要接手 agent 做的事

**评估并选择一个方案，在分支上实施：**

**方案 A（推荐）：加 `pending` 审核状态**
- migration 加 `pending` 到 status 枚举
- 上传后初始状态为 `pending`，不立即公开
- admin 审核通过后改为 `active` 才在排行榜公开
- `publicIdentity` 只返回 `active` 的头像
- 用户体验：上传后显示"审核中"，管理员审核通过后公开

**方案 B：上传即公开 + 自动内容扫描**
- 保持上传即 `active`
- 在上传路径加一个异步图片分类步骤（如调用 Cloudflare AI 或第三方 NSFW 检测 API）
- 未通过扫描的立即降为 `removed` 或 `pending`
- 注意：引入第三方 API 有凭证管理和延迟成本

**方案 C（最小改动，接受风险）：保持现状 + 强化补偿控制**
- 不改代码，只在文档里明确标注"Alpha 阶段，仅限受信任测试人员"
- 依赖举报即屏蔽 + 每日审核 + 24h 紧急下架
- **只有在你能保证每日有审核人力时才选这个**

### 无论选哪个方案，都要补的加固

- `workers/membership-api/src/avatar.ts` 的 `getAvatar` 响应加 `X-Content-Type-Options: nosniff` 头（防御 JPEG/HTML polyglot）
- 确认 `ACCESS_TEAM_DOMAIN` / `ACCESS_AUD` 两个 Worker secret 在部署前已配置，否则 admin 端点 fail-closed 不可用

### 完成标准

- [x] 选定方案 C；按最终产品决策不增加 migration 或预审核状态
- [x] `npm test` 全绿（保留公开读取安全头回归测试）
- [x] `docs/policies/user-content-policy.md` 与最终方案一致
- [x] 在反馈报告里记录最终选择了哪个方案

---

## 行动项 2：rebase 到最新 main（必须处理）

### 问题

分支基点是 `4742abe`，**当前 main 已到 `a2b75d9`**，领先 15 个提交。落后的内容包含：

- **会员付费墙**（`a2b75d9`）：月/年订阅计划 + 付费墙 UI + RevenueCat 重构
- **0.3.4 release**（`5b77bd8`）：版本号升 `0.3.4+5` + 官网 APK 下载
- docs 更新

### 冲突评估

main 改了 29 个文件，本分支改了 51 个文件，**13 个文件重叠**（大概率冲突）：

| 冲突文件 | 冲突原因 |
|---|---|
| `lib/control/account_controller.dart` | 两边都加了新方法（付费墙 + 头像） |
| `lib/ui/pages/profile_page.dart` | 两边都大改（付费墙 +279 / 头像 +279） |
| `lib/l10n/app_zh.arb` / `app_en.arb` | 两边都加了新 key |
| `lib/l10n/app_localizations*.dart` | 生成文件，改 arb 后需重新生成 |
| `lib/ui/pages/home_page.dart` | 两边都改了 |
| `pubspec.yaml` | 版本号 + 新依赖 |
| `test/account_controller_test.dart` | 两边都加了测试 |
| `test/profile_page_test.dart` | 两边都加了测试 |
| `docs/release-configuration.md` | 两边都更新了 |
| `docs/modules/membership.md` | 两边都更新了 |

### 需要接手 agent 做的事

```bash
cd E:/AII/ugk-post-custom-avatar
git fetch origin
git rebase origin/main
```

rebase 时重点解决上述 13 个文件的冲突：

1. **`account_controller.dart`**：保留两边的功能——付费墙的 `loadPremiumPlans`/`purchasePremiumPlan` + 头像的新方法
2. **`profile_page.dart`**：付费墙卡片 + 头像编辑 UI 共存
3. **l10n**：合并两边的 arb key，然后重新生成 `app_localizations*.dart`（`flutter gen-l10n`）
4. **`pubspec.yaml`**：版本号保持 main 的 `0.3.4+5`（或更高），依赖合并两边新增
5. **测试**：保留两边的新增测试

### 完成标准

- [x] rebase 到 `origin/main` 无残留冲突
- [x] `flutter analyze` 0 issue
- [x] `flutter test` 全绿（363/363）
- [x] `cd workers/membership-api && npm test` 全绿（125/125）
- [x] `git diff --check` 通过
- [x] 强制推送：`git push --force-with-lease origin codex/membership-custom-avatar`

---

## 已确认无问题的部分（供参考，无需处理）

以下是本次审核确认通过的项：

### Worker 安全
- ✅ 所有上传/删除/举报端点 `requireSession` 鉴权
- ✅ JPEG magic bytes 校验（SOI/EOI/SOF），不只信 Content-Type
- ✅ 1 MiB 大小限制（流式截断，写 R2 前终止）
- ✅ R2 key 服务端 `crypto.randomUUID()` 生成，无路径穿越
- ✅ 跨用户覆写防护（所有 UPDATE 绑 `session.userId`）
- ✅ SQL 全用 `?` 占位符，零注入
- ✅ Admin Cloudflare Access JWT 验签 + fail-closed
- ✅ Admin CSRF 防护 + HTML escapeHtml + CSP
- ✅ 所有管理动作写审计记录
- ✅ 被举报/下架/隐藏的头像返回 404，无法通过旧 URL 访问

### 凭证安全
- ✅ `wrangler.toml` 只有 R2 binding 配置，零 secret
- ✅ `membership_config.dart` 未修改，3 个 dart-define 保持空默认
- ✅ 全 diff 零 API key / token / secret 匹配
- ✅ 新依赖 `image_picker` + `image_cropper` 是标准 Flutter 插件

### 架构
- ✅ AndroidManifest 用 `tools:node="remove"` 移除存储权限 + UCropActivity 声明，无过度权限
- ✅ 受保护文件（`pushup_domain.dart`/`membership_config.dart`）零触碰

## 处理顺序建议

1. **先做行动项 2**（rebase 到最新 main）——因为行动项 1 的代码改动要在最新基点上做
2. **再做行动项 1**（UGC 预审核方案）——在 rebase 后的干净基点上实施
3. 跑全部测试确认全绿
4. `git push --force-with-lease` 重新推送
5. 通知 main 侧复审
