# 任务路由

预检后先判断任务类型，只读取相关文档。所有开发任务都读 AGENTS.md、docs/development-guide.md 和 docs/testing-release-playbook.md。

| 任务 | 追加必读 | 最低验证 |
|---|---|---|
| UI、主题、布局、多语言 | docs/design/app-ui-v1.md、相关页面与 Widget 测试 | Widget/交互测试、flutter analyze、flutter test |
| 识别、计数、阈值、关键点 | docs/modules/recognition.md、对应 docs/modules 文档、完整调用方 | 先失败测试；全量测试与回放 5/5/3 |
| 训练编排、相机、异步流程 | docs/modules/workout-controller.md、docs/modules/pushup-pipeline.md | controller 测试、session 守卫、必要真机 |
| 语音文案、音色和 WAV | docs/modules/voice-themes.md、pubspec.yaml、语音契约测试 | 文件名/数量/格式、契约测试、真机播报 |
| 账号、会员、个人资料 | docs/modules/membership.md、docs/release-configuration.md | controller/API/Widget 测试；Play 签名链路按手册抽查 |
| 记录同步、排行榜 | docs/modules/membership.md、Worker 路由/迁移、排行榜相关测试 | fake 本地测试；真实 D1 写入需授权 |
| Worker、D1、Webhook | docs/modules/membership.md、workers/membership-api/package.json、wrangler.toml、migrations 与测试 | npm test；顺序固定为 D1 迁移→Worker→App |
| Flutter 打包、签名、AAB | docs/release-configuration.md 第 6.4 节、docs/testing-release-playbook.md | 全量测试、签名/证书/清单/权限/哈希 |
| Google Play 测试或上架 | docs/release-configuration.md、docs/testing-release-playbook.md、本机 info 仓库最新 handoff | 内部测试→同一 AAB Alpha；每次推进单独授权 |
| OAuth、RevenueCat、Cloudflare、平台申请 | docs/release-configuration.md、docs/modules/membership.md、本机 info 与私密台账 | 先读现状；只用官方文档；变更后记录恢复方法 |
| Git 集成、rebase、merge、push | git status/log/worktree/remote、相关分支交接 | 保留用户文件；全量验证；push 单独授权 |
| 新会话交接 | docs/handoff-template.md、最新 Git 状态、info 最新 handoff | 明确分支/HEAD/脏文件/验证/远程状态/下一步 |

## 定位代码

- 用 rg 查文件、符号和所有调用方；不要只改截图中出现的页面。
- 先找同层已有模式，再决定是否新建文件。
- 识别算法从 domain/product 追到 controller 和 UI；Bug 优先修在所有调用方共用的根因位置。
- Worker 合同同时检查 Flutter 客户端解析、TypeScript 路由、D1 schema/migration 和双方测试。

## 测试分流

- 纯逻辑和普通 UI：本地自动化优先。
- 相机、端侧推理和系统安全区：自动化后做真机。
- Play 签名 OAuth、Billing、RTDN、更新链路：必须经 Play 测试轨道。
- RevenueCat Test Store 不能证明 Google Play Billing。
- 线上 Worker/D1 没有独立 staging 时，只在里程碑且获授权后做必要抽查。

## 读取本机发布信息

涉及发布、平台或秘密时：

1. 读 E:\AII\pushup-ai-info\README.md、AGENTS.md、SECURITY.md。
2. 读 public/release-configuration.md、public/testing-release-playbook.md。
3. 只在本机读取 private 台账和日期最新 handoff，不把内容复制到回复。
4. 私密信息以 E:\AII\secrets 中的权威原台账为准；快照不是事实源。
5. 若这些路径不存在，停止平台写入并向用户索取本机权威位置；普通代码开发可继续。
