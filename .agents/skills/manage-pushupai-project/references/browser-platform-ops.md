# 浏览器持久登录态下的远程平台操作

> 本篇记录"用 Playwright 持久浏览器 + 本机已登录态"操作 Google Play Console、Cloudflare Worker 等远程平台的可复用工作流。
> 它是 docs/release-configuration.md（发布合同）和 docs/testing-release-playbook.md（测试分流）的**操作层补充**：合同说"做什么、按什么顺序、授权边界在哪"，本篇说"浏览器里具体怎么点、有哪些 UI 坑、怎么核对"。
> 控制台 UI 会变。操作前以官方当前界面为准；本篇记录的是截至 2026-07-22 的实际路径。

## 0. 前提与边界

- 本工作流**只**在用户已明确授权某次远程动作（上传 AAB / 推进轨道 / 部署 Worker）后启动，本身不产生授权。
- 浏览器登录态是用户本机持久会话。agent 只借用它完成已授权动作，**不代用户完成登录**（输入密码/2FA 必须用户亲自操作），不保存、不回显任何凭证值。
- 每个不可逆远程写（上传、发布、推进轨道、部署）执行前用一句话声明"即将做 X"，给用户喊停机会；不反复弹窗问"要不要做"。
- 仍受 authority-and-ledger.md 约束：逐次授权、不自动扩展到下一轨道/下一平台。

## 1. 浏览器与登录态准备

### 1.1 打开浏览器

用 Playwright MCP 的 `browser_navigate` 打开目标站点。Playwright 默认用持久用户数据目录，会复用本机 Chrome 的登录态（GitHub/Cloudflare/Play Console/Google Cloud 常常已经是登录态）。

### 1.2 登录态核对（不要代登录）

逐个打开站点后，看 URL 是否被重定向到登录页：
- 跳到 `dash.cloudflare.com/<account>/home`（account home）→ Cloudflare 已登录
- 跳到 `play.google.com/console/u/0/developers/<id>/app-list` → Play Console 已登录
- 跳到 `console.cloud.google.com/welcome?project=...` → Google Cloud 已登录
- 停在 `.../login` → **未登录**，让用户亲自登录，agent 不碰密码框

### 1.3 ⚠️ 凭证泄露风险

浏览器自动填充的密码可能以**明文出现在 accessibility 快照里**（snapshot 会读取 input value）。若发现某站点密码框已被填充：
- **不要**在回复里复述、截图或记录该值
- 提醒用户：这条交互记录可能被持久化，建议事后改密
- 快照文件（`.playwright-mcp/*.yml`）含敏感内容，不得提交 Git（已在 `.gitignore`？确认）

## 2. Cloudflare Worker 部署（wrangler，不走浏览器）

Worker 部署**不经过浏览器**，用本机 `wrangler` CLI（已登录或用 `CLOUDFLARE_API_TOKEN`）。浏览器只用于部署后核对 / Secret 管理 UI。

### 2.1 部署前预检（只读，全部通过才能部署）

```bash
cd workers/membership-api
npx wrangler --version          # 应为台账记录版本（当前 4.107.1）
npx wrangler d1 migrations list ugk-membership --remote   # 应"No migrations to apply"
npm test                        # 全绿（含 app_update 清单与 Secret 守护测试）
npx wrangler deploy --dry-run --keep-vars   # 构建通过、binding 正确，不产生远程写入
```

### 2.2 生产清单回退硬约束（每次部署前必做）

`docs/release-configuration.md §7.2` 要求：部署前只读获取当前**生产** `/app-update` 清单的 versionCode，与**拟部署源码** `src/app_update.ts` 的 versionCode 比较。拟部署 ≤ 生产时**停止**（除非取得明确的清单回滚授权）。

核对命令（只读）：

```bash
curl -s "https://<worker-host>/app-update?platform=android&locale=zh"
```

或浏览器打开该 URL 看 JSON。只比对 `versionCode` 数字，不碰其他字段。

### 2.3 部署

```bash
cd workers/membership-api
npx wrangler deploy --keep-vars
```

`--keep-vars` 保留既有 Secret/变量，不重置。记录输出的 `Current Version ID`（写入 info 私密台账，作为回滚目标）。

### 2.4 部署后只读核对（至少 6 项）

| 探针 | 方法 | 预期 |
|---|---|---|
| 公开清单 zh | `curl .../app-update?platform=android&locale=zh` | versionCode 与源码一致，release notes 正确 |
| 公开清单 en | 同上 `locale=en` | 同上 |
| 错误方法 | `curl -X POST .../app-update...` | `405` |
| 错误平台 | `curl ...platform=ios...` | `400` |
| 鉴权边界 | `curl .../me` | `401`（未登录） |
| Access 入口 | `curl .../admin/members` | `302`（Access 网关重定向到登录；不是 Worker 的 403） |

最后一项返回 302 是正常的——Cloudflare Access 网关在请求未带 JWT 时重定向到 Access 登录页。curl 不跟随重定向所以看到 302。

## 3. Google Play Console 操作（浏览器 UI）

Play Console 没有 agent 友好的 API（除非配服务账号 JSON 走 Play Developer API），实际操作走浏览器 UI。下面是 Internal 发布 + Alpha 推进的完整路径。

### 3.1 关键 URL（减少导航迷路）

| 目的 | URL 模板 |
|---|---|
| 应用首页 | `play.google.com/console/u/0/developers/<devId>/app/<appId>/app-dashboard` |
| 发布概览 | `.../app/<appId>/publishing` |
| 内部测试轨道 | `.../app/<appId>/tracks/internal-testing` |
| Alpha 轨道 | `.../app/<appId>/tracks/<alphaTrackId>` |
| 测试和发布总览 | `.../app/<appId>/test-and-release` |

`devId`（开发者账号）、`appId`（应用）、`alphaTrackId` 见 info 私密台账。直接拼 URL 比层层点菜单快得多。

### 3.2 Internal 发布完整链路（5 步 + 多个确认对话框）

1. 进内部测试轨道页 → 点"**创建新的发布版本**"
2. "**上传 app bundle**"区点"**上传**" → 文件选择器 → `browser_file_upload` 传 AAB 绝对路径
3. 等 Play 处理（160MB AAB 约 1-2 分钟，页面提示"上传要进行优化再分发，可离开此页面"）
4. 填**发布版本名称**（如 `0.3.19-internal-1`）和**版本说明**（见 3.3 语言标签坑）
5. "**下一步**" → 预览页核对设备支持数（见 3.4）→ "**保存并发布**" → **二次确认对话框**"要在 Google Play 上发布此更改吗？" → 再点对话框里的"保存并发布"

Internal 是**立即发布**，发布后测试人员可从 Play 获取。

### 3.3 ⚠️ 版本说明（release notes）语言标签格式坑

这是最容易踩的坑。Play 的 release notes 要求语言标签格式：

```
<zh-CN>
第一行说明
第二行说明
</zh-CN>
<en-US>
line one
line two
</en-US>
```

关键点：
- **语言标签必须独占一行**，内容在开闭标签之间，每条说明各占一行
- `browser_type` / `fill` 传字面 `\n` 字符串时，Play 可能把它当空格，导致"第 1 行：文本未置于语言标记之间"错误（输入框变 `[invalid]`，"下一步"禁用）
- **可靠写法**：用 `browser_fill_form` 传 value 时确保 `\n` 是真实换行（fill 通常正确处理）；如果仍报错，用 `browser_evaluate` 直接设 textarea.value 再 dispatch input 事件（注意 nativeSetter 在 Playwright 里可能 `Illegal invocation`，改用 `fill` 更稳）
- 填完核对：输入框下方应显示"**已提供 N 种语言的版本说明**"且无 `[invalid]` 标记

### 3.4 设备支持数核对（发版放行条件）

预览页有"设备支持范围变化"表。**所有设备类型的"不再支持的设备"列必须为 0**才能放心发布。如果某类型 >0，说明 manifest/bundle 变化导致旧设备掉支持，需要排查（常见原因：targetSdk 提升、移除 ABI）。

手机数通常 12,000+，平板 6,000+，Chromebook 几十，电视/车载个位数——这些是本应用的正常基线。

### 3.5 Alpha 推进（复用 Internal 的同一 AAB）

Alpha 走"**从内容库添加**"复用 Internal 已上传的 AAB，**不重新上传/构建**（SOP 要求"先 Internal 再把同一 AAB 推进 Alpha，不重新构建"）：

1. 进 Alpha 轨道页 → "创建新的发布版本"
2. 点"**从内容库添加**"（不是"上传"）→ 对话框列出所有历史 AAB → 勾选目标 versionCode 行 → "添加到版本"
3. 填发布名（如 `0.3.19-closed-1`）和 release notes（与 Internal 一致）
4. 预览页：核对**分阶段发布百分比**（本应用固定 100%）+ 设备支持数
5. Alpha 的按钮是"**保存**"（不是"保存并发布"）→ 提示"更改已保存，前往发布概览送审"
6. 跳"发布概览" → "**提交 N 项更改以供审核**" → **送审确认对话框**"要将更改送审吗？审核通常 7 天" → "将更改内容送审"

**Internal 立即发布 vs Alpha 需送审**——这是两个轨道的本质区别。Alpha "保存"后只是进了待送审草稿，还要去发布概览点送审。

### 3.6 状态词精确性（不能提前宣告成功）

| Play 显示 | 正确说法 |
|---|---|
| "正在快速检查常见问题"（至多 N 分钟） | 已提交，快速检查中 |
| "正在审核中的更改" | 已送审，审核中（通常 7 天） |
| "已面向内部测试人员发布" | Internal 已发布 |
| "已面向 Alpha 测试人员全面发布" | Alpha 已发布（**只有这步才算 Alpha 发布完成**） |

"已提交送审"≠"已发布"。台账里必须区分。

## 4. 一次发版的完整顺序（App + Worker 联动）

当一次发版同时含 App 代码改动和 Worker 清单改动时，顺序固定（`docs/release-configuration.md §7.2`）：

1. **Worker 部署（第一次，可选）**：如果 Worker 有非清单的安全/功能改动（如本次 CSRF），先部署含改动但仍广告**旧版本清单**的 Worker。预检只比对清单 versionCode，不碰 App。
2. **App 候选**：bump pubspec + `app_update.ts` + 测试期望值 → 门禁 → build AAB → 核验。
3. **Internal 发布**：上传 AAB，立即发布。
4. **Worker 部署（第二次）**：部署含**新版本清单**的 Worker（拟部署 versionCode > 生产，无回退）。此时 App 已在 Play 可获取，清单与 App 对齐，0.3.x-1 用户会收到更新提示。
5. **Alpha 推进**：复用 Internal 同一 AAB 推进 Alpha，送审。

注意：Worker 清单部署和 AAB 上传是**两个独立的远程写入授权**，不能用一次授权覆盖两个动作。

## 5. 常见错误与排查

| 现象 | 原因 | 处理 |
|---|---|---|
| release notes 输入框 `[invalid]` | 语言标签没独占行 / `\n` 被当空格 | 用 fill 重传，确保真实换行；标签独占行 |
| "下一步"按钮 disabled | 版本说明未通过校验 / AAB 未处理完 / 发布名为空 | 逐项检查，等 AAB 处理完成 |
| 上传后提示"请重新上传 app bundle 以应用增强功能更改" | Play App Signing/自动保护重新关联提示 | 不影响本次，AAB 已在制品表显示即成功 |
| `/admin/members` 返回 302 不是 403 | Cloudflare Access 网关重定向（正常） | 302 是 Access 行为，非 Worker 鉴权失败 |
| jarsigner `command not found` | git bash 子 shell 丢了 PATH | 用完整路径：`E:/Android/Android Studio/jbr/bin/jarsigner.exe` |
| keytool SHA-1 没输出 | `grep -iE` 在中文 locale 冲突 | 单独 `grep -i "SHA1:"`，不要组合 `-E` |
| grep `conflicting matchers` | `-nE`/`-iE` 组合在此 shell 报错 | 拆成单 flag 或分开跑 |

## 6. 产物核验工具路径

`jarsigner` / `keytool` 不在 git bash 默认 PATH，用 Android Studio JBR 完整路径：

```
E:/Android/Android Studio/jbr/bin/jarsigner.exe
E:/Android/Android Studio/jbr/bin/keytool.exe
```

AAB 内 `base/manifest/AndroidManifest.xml` 是 **protobuf 二进制**，python `zipfile` + decode 读不到标签。版本/包名用 Gradle 产物更可靠：
- `build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json`（含 `applicationId` / `versionCode` / `versionName`）
- `android/app/build.gradle.kts` 的 `compileSdk` / `minSdk` / `targetSdk`
