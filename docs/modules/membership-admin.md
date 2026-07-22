# 会员运营管理台

最后更新：2026-07-22

## 目标与边界

会员运营管理台用于回答日常上线运营最常见的问题：谁购买过会员、当前是否有效、购买的是月卡还是年卡、是否处于试用、何时到期、是否取消续费或发生账单异常，以及这条状态最后何时与 RevenueCat 对账。

管理台复用现有 Cloudflare Worker、D1、RevenueCat 和 Cloudflare Access，不引入独立管理服务或前端框架。它是后端运营工具，不改变 Flutter App 接口、购买流程或授权语义。

RevenueCat 当前 subscriber 仍是订阅事实，Worker 仍是云端权限裁决者，D1 只是可重建运营快照。管理台不会自行退款、取消订阅、延长权益或修改商店交易；这些高风险动作继续在 RevenueCat 和 Google Play Console 完成。

## 入口与安全

- `GET /admin`：通过 Access 鉴权后跳转到会员管理。
- `GET /admin/members`：统计、列表、筛选、分页和会员详情。
- `POST /admin/members/action`：单会员权威同步，或每次最多补齐 10 条历史待识别会员。
- `GET /admin/avatar-reports`：复用既有头像审核队列。

Cloudflare Access 必须同时覆盖精确路径 `/admin` 和通配路径 `/admin/*`，默认拒绝并只允许明确的管理员身份。Worker 还会独立验证 `Cf-Access-Jwt-Assertion` 的签名、issuer、audience 和操作者身份，因此不能把“请求经过某个 URL”当作鉴权。

页面采用服务端渲染，不加载第三方脚本、字体、图片或统计 SDK；响应使用 `no-store`、禁止 framing、禁止 referrer，并转义全部账号输入。管理台 POST 同时使用三层边界：Access JWT 鉴别操作者身份；所有服务端渲染的 POST form 携带由 `SESSION_SECRET` 计算、绑定该 Access actor 的无状态 HMAC CSRF token，证明写入意图；Origin 校验作为兼容性纵深防御，只接受 Worker 同源或已验证 Access 浏览器链路实际产生的字面量 `Origin: null`，缺失和 foreign Origin 仍拒绝。`Origin: null` 只有在 CSRF token 同时有效时才可写入，不能单独作为授权依据。每次会员同步都会写入 `membership_admin_actions`，记录操作者、目标用户、结果和时间，不保存 RevenueCat 原始响应。

## 功能合同

### 概览

- 在册会员：当前或历史上持有过 `premium` entitlement 的人数。
- 当前有效：快照标记有效，且尚未越过到期时间。
- 试用中：当前有效且 RevenueCat `period_type=trial`。
- 7 天内到期：当前有效，且到期时间落在未来 7 天内。
- 续费风险：当前有效，但已检测到取消续费或账单异常。
- 待识别：历史快照尚未补齐 RevenueCat 产品标识。

这些数字不是财务报表。退款、税费、汇率、净收入、商店分成和 MRR 应使用 RevenueCat Charts 或 Google Play 财务报告，不能从当前 D1 快照推算。

### 列表与详情

- 按用户 ID、显示名、昵称或邮箱搜索。
- 按有效、试用、7 天内到期、已取消续费、账单异常、已失效筛选。
- 按月卡、年卡、赠送、其他、待识别筛选。
- 按正式、沙盒、待识别环境筛选。
- 按到期时间、购买时间或最后同步时间排序；每页 25 条。
- 详情显示产品标识、购买/首次购买/到期时间、商店、环境、所有权、快照来源和最近管理操作。

### 权威同步与历史补齐

“立即同步”只查询 RevenueCat 当前 subscriber 并刷新 D1 快照，不直接改变权益。RevenueCat 不可用或响应无效时返回失败、保留旧快照并写失败审计。

“补齐最多 10 条待识别会员”按批次处理历史快照，单条失败不会阻断后续条目。限制批次大小是为了控制 RevenueCat API 调用和 Worker 执行时间；如仍有待识别记录，可再次执行。

## 数据库变更

Migration `0006_membership_admin_metadata.sql`：

- 为 `membership_snapshots` 增加购买产品、购买时间、周期类型、商店、环境、所有权、取消续费和账单异常等运营字段。
- 使用既有快照回填 `has_entitlement`，但不猜测月卡、年卡或商店环境。
- 新增 `membership_admin_actions` 审计表。

所有新增字段都是兼容性扩展；旧 App 不读取这些字段。迁移只向前应用，不通过删除列回滚。Worker 回滚时保留新 schema 即可。

## 本地验证

```powershell
cd workers/membership-api
npm test
npx wrangler deploy --dry-run --keep-vars
```

自动化必须覆盖 Access JWT、无授权拒绝、HTML 转义、响应安全头、统计、搜索/筛选/排序/分页、详情、同源 POST、单人同步、批量上限、部分失败继续、失败不污染快照、审计和全量既有 Worker API 回归。

## 生产上线与验收

上线顺序固定为：

1. 从已提交且测试全绿的源代码准备部署。
2. 把 D1 导出到受保护的本机备份位置。
3. 应用 migration `0006`，确认远端无待迁移项。
4. 将既有 Cloudflare Access 应用同时覆盖到 `/admin` 和 `/admin/*`，保留默认拒绝和明确管理员策略。
5. **部署前只读拉取生产 `GET /app-update?platform=android` 清单，与拟部署源码 `workers/membership-api/src/app_update.ts` 的 `versionCode` 比较。管理台与更新清单共用同一 Worker，本次部署会一并覆盖更新清单；拟部署版本低于生产时必须停止，只有取得明确的更新清单回滚授权才能继续。规则全文见 [release-configuration.md §7.2](../release-configuration.md#72-app-更新清单接口)。**
6. 确认 `wrangler.toml` 的 `[secrets].required` 检查通过，再使用 `wrangler deploy --keep-vars` 部署 Worker。缺任一必需 Secret 名（`GOOGLE_CLIENT_ID`、`REVENUECAT_SECRET_API_KEY`、`REVENUECAT_WEBHOOK_AUTH`、`REVENUECAT_WEBHOOK_SECRET`、`SESSION_SECRET`、`ACCESS_TEAM_DOMAIN`、`ACCESS_AUD`）必须停止；历史事故曾因部署清掉其中三项而导致已通过 Access 的后台请求被 Worker 拒绝。
7. 未授权访问应被 Access 拦截；授权浏览器应能打开列表、筛选、详情和头像审核。
8. 执行待识别补齐，确认只更新快照和审计，不改变 RevenueCat 权益。
9. 用聚合查询核对表/列、会员数量和审计数量；不得把邮箱、用户 ID 或订阅详情写入公开日志。

精确 Access 应用 ID、管理员身份、生产地址、部署版本、D1 备份路径和远端运行证据只记录在本机私密台账，不进入仓库。

### 2026-07-21 生产状态

- 已从提交 `c526f88` 部署管理台；部署使用 `--keep-vars`，既有 Secret、变量和 D1/R2 binding 保持不变。
- 生产 D1 已先完整导出到受保护位置，再应用 migration `0006`；远端确认 10 个新增字段、审计表和迁移状态正确。只读取聚合数量，未导出会员身份或订阅明细。
- 既有 Access 应用现同时保护 `/admin` 与 `/admin/*`，仍只有原有 1 条管理员 Allow 策略；临时验证策略均已删除。
- 未登录生产探针确认 `/admin`、会员列表和头像审核入口均先进入 Access；App 更新公开接口与既有会员鉴权边界未退化。
- 自动化与未登录生产运行验证已完成。授权后的生产页面目视与交互验收仍需管理员完成一次邮箱验证码登录；在此之前不把该项记为浏览器全链路通过。
- 后续部署曾清掉 `ACCESS_TEAM_DOMAIN`、`ACCESS_AUD` 和 `GOOGLE_CLIENT_ID`，导致已通过 Access 的后台请求被 Worker 拒绝；现已将三项恢复为 Secret binding。`wrangler.toml` 已声明全部生产 Secret 为 `required`，相同缺项会在以后部署前直接失败。修复后只读探针确认三项绑定存在、后台仍由 Access 保护、会员接口仍要求登录，App 更新接口仍返回既有版本。
