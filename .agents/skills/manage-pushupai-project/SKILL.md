---
name: manage-pushupai-project
description: "管理 PushupAI（ugk-post）项目的开发、测试和运维流程。凡是在本项目进行功能/UI/算法/语音开发、账号会员与排行榜修改、Flutter 测试与打包、Cloudflare Worker/D1 部署、Google OAuth、RevenueCat、Google Play 测试或上架、密钥与发布台账维护、Git 集成、故障排查或项目交接时使用。"
---

# 管理 PushupAI 项目

把本 Skill 当作流程入口，把项目文档和本机台账当作事实源。不要在 Skill 中猜测动态状态或复制秘密。

## 开始任务

1. 用中文说明正在使用本 Skill，以及本次任务属于开发、测试、发布、后端、平台配置还是交接。
2. 定位 App 仓库根目录。优先使用当前工作区；必须同时存在 AGENTS.md、pubspec.yaml 和 docs/development-guide.md。
3. 完整阅读仓库根目录 AGENTS.md。它覆盖 Skill 中与项目冲突的规则。
4. 运行只读预检：

   powershell -ExecutionPolicy Bypass -File <skill目录>\scripts\preflight.ps1 -ProjectRoot <App仓库根目录>

5. 完整阅读 references/task-routing.md，再按本次任务读取其中指定的权威文档。
6. 涉及远程平台、发布、账号、密钥、数据或台账时，再完整阅读 references/authority-and-ledger.md。
7. 区分本会话亲自验证的事实、用户报告的事实和历史文档记录；不得混写。

预检发现脏工作区时先识别所有者。保护用户未跟踪文件，尤其是 docs/handoff-account-features.md；不得修改、删除、stage 或提交。

## 开发

1. 先说明假设、边界和可验证成功标准。存在会改变产品行为或远程状态的歧义时只问一个关键问题。
2. 搜索完整调用链和同类实现，优先复用现有代码、Flutter/Dart 标准能力和已安装依赖。
3. 从功能“心脏”所在的最低层开始：
   - domain：纯算法，不依赖 Flutter 或平台。
   - product：产品规则，只依赖 domain。
   - control：编排 product 与基础设施；异步操作保留 session 守卫。
   - UI：只展示和转发用户操作。
4. 严格执行红—绿—整理：先写能复现需求的失败测试，再做最小实现，最后只清理本次产生的问题。
5. 用户可见文案进入 ARB；domain、product、control 不引用 AppLocalizations。语音 WAV 与 UI l10n 分开管理。
6. 不顺手重构、不加入未请求的抽象、不改相邻无关文件。

## 验证

普通 Flutter 代码至少运行：

   flutter analyze
   flutter test
   git diff --check

修改 workers/membership-api 时额外运行：

   npm test

发布候选即使 Worker 未改，也按 docs/release-configuration.md 的发布 SOP 复跑 Worker 测试。

必须保持回放基线 step0=5、v3=5、v4=3。涉及相机、推理、签名、OAuth、Billing 或真实云端合同的改动，再按 docs/testing-release-playbook.md 选择真机、内部测试或 Alpha。

只报告实际运行结果和精确测试数量。历史记录只能标为历史，不能当作本次验证。

## 安全与远程操作

- 不输出或提交 Secret、Token、密码、私钥、个人邮箱、设备序列号、生产配置值或真实用户数据。
- 只检查秘密字段是否存在，不读取或回显值。
- 不使用 git add -A；显式 stage 本次文件。
- 未经明确授权，不 push、merge、rebase、部署 Worker、修改 D1、改 Secret、上传或推进 Play 版本、改 Google/RevenueCat/Cloudflare 配置、发起购买、卸载 App 或清除数据。
- 获得授权只覆盖用户明确说出的动作；不自动扩展到下一轨道、下一平台或其他数据写入。
- 平台规则和控制台 UI 可能变化。执行高风险平台操作前，优先核对官方当前文档。
- 用浏览器持久登录态操作 Play Console / Cloudflare 等远程平台时，按 references/browser-platform-ops.md 的工作流：借用登录态但**不代用户登录或填密码**；浏览器自动填充的密码可能以明文出现在 accessibility 快照，不得复述/截图/记录，并提醒用户事后改密。

## 发布与打包

1. 先读 docs/testing-release-playbook.md 和 docs/release-configuration.md 的完整 AAB SOP。
2. 使用更高且未被 Play 使用的 versionCode；产物必须对应已提交源码。
3. production dart-define 和 android/key.properties 只检查必需字段存在。
4. 构建命令只引用受保护配置文件，不在命令行直接传值。
5. 核验签名、上传证书、包名、版本、SDK、禁止权限、AAB 大小和 SHA-256。
6. 先内部测试，再把同一 AAB 推进 Alpha；不得无故重新构建不同产物。
7. Play Console 的发布名称、快速检查、审核中、已向测试人员发布、真机通过是不同状态，逐项记录，不提前宣告成功。
8. 用浏览器或 wrangler 实际执行 Play 上传 / 轨道推进 / Worker 部署时，按 references/browser-platform-ops.md 操作：Worker 部署前比对生产清单防回退、部署后 6 项探针；Play Console 的 release notes 语言标签格式坑、Internal 立即发布 vs Alpha 需送审、设备支持数必须全 0；App+Worker 联动发版顺序固定（先部署含安全改动但旧清单的 Worker → App Internal → 部署新清单 Worker → Alpha 送审）。

## 台账与交付

远程配置、部署、密钥、构建或商店状态发生变化时，按 references/authority-and-ledger.md 更新三层记录。App 代码仓库只保存公开流程；info 仓库可 push 到所有者指定的私有远程（白名单，仅同步 `public/` + `handoffs/`，`private/` 本机独占），用于多机器交接同步；秘密原件不进入任何 Git。

完成时交代：

- 修改内容与源提交。
- 实际运行的测试及结果。
- 真机和远程链路哪些已验证、哪些未验证。
- 是否生成、上传或推进产物。
- 是否执行 push、部署、D1 或平台写入。
- 用户下一步只需做什么。

不要为了让状态“看起来干净”处理用户文件，也不要把等待审核写成发布完成。
