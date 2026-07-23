# 授权与台账边界

## 操作授权

| 操作 | 默认 |
|---|---|
| Git status/log/diff、读取本地文档、检查文件存在、运行本地测试 | 可直接执行 |
| 用户已要求的本地代码修改、创建功能分支、构建本地产物 | 在请求范围内执行 |
| commit | 用户要求保存/提交，或任务明确要求形成提交时执行 |
| rebase、merge、切换关键分支、删除 worktree | 必须确认当前请求明确包含 |
| push、force push、创建/合并 PR | 必须逐次明确授权；禁止 force push |
| Worker/Pages 部署、D1 migration 或写入、Secret/变量修改 | 必须逐次明确授权 |
| Google Play 上传、轨道推进、送审、正式发布 | 每一步分别授权；不能把“打包”理解成“上传” |
| Google Cloud、OAuth、RevenueCat、Cloudflare 控制台变更 | 必须明确授权并记录变更与恢复 |
| 购买、退款、订阅测试 | 必须明确授权；只用 License Tester 测试支付 |
| 卸载 App、清除数据、删除文件/账号/记录 | 必须先确认数据已同步并获得明确授权 |

只读诊断不能演变为修复或远程写入。授权有范围和时效，不从一次操作推断下一次操作。

## 三层记录

### App 仓库

保存架构、变量名、通用命令、控制台菜单、公开证书指纹和稳定流程。

禁止保存真实 Secret/Token/密码/私钥、个人账号、完整生产配置、设备序列号、真实用户数据和 APK/AAB。

### 同步 info 仓库

位置由 App AGENTS.md 指定。保存脱敏资源定位、配置记录 ID、日期、部署/审核状态、证据摘要、故障与恢复步骤和交接快照。

强制：

- remote 必须只指向所有者指定的私有远程（白名单，见 `preflight.ps1`）；不得指向其他任何远程。
- 只有 `public/` + `handoffs/` + `CHANGELOG.md` + 根级 README/AGENTS/SECURITY 进入私有远程；`private/` 本机独占，永不进任何 remote（已 `.gitignore`，历史已清除）。
- 先更新权威源，再刷新快照。
- private 内容不得复制到聊天、Issue、PR 或 App 仓库。
- 提交前检查 noreply 邮箱、git diff、敏感模式，并确认 remote 在白名单内、`private/` 未被 stage。
- 显式 stage 文件，不使用 git add -A。
- info 仓库的 push 与 App 仓库一样需要用户授权；未经授权不 push。

### 受保护秘密存储

保存 JKS、密码记录、production dart-define、服务账号 JSON、Token 和私密台账原件。只检查是否存在或字段是否齐全，不输出内容。

## 变更记录顺序

远程配置、密钥或发布状态改变后：

1. 更新受保护的权威私密台账：记录稳定 ID、日期、作用、验证结果、影响与恢复/轮换方法；秘密值仍不记录。
2. 若稳定公开流程改变，更新 App docs；动态账号和生产细节不进入 App Git。
3. 刷新 info 仓库的 public/ + handoffs/ 快照、最新 handoff 和 CHANGELOG；`private/` 只在本机更新，不进入任何同步或远程。
4. 运行敏感扫描、确认 info remote 在白名单内且 `private/` 未被 stage，显式 stage 后单独本地提交。

发布候选至少记录：版本名/代码、源分支与提交、构建命令类别、AAB 大小与 SHA-256、签名/证书、包名、SDK、禁止权限、测试数量、上传轨道及真实审核状态。

状态词要精确：

- 已构建：只代表本地产物生成。
- 已上传：不代表已发布。
- 快速检查/审核中：不代表测试人员可用。
- 已向测试人员发布：不代表真机功能通过。
- 真机验收通过：列出实际测试项目。

## 多机器协作（Android Windows + iOS Mac）

iOS 等第二台机器开发时，按以下三层模型管理共享与独占资源。

### 三层同步模型

| 层 | 内容 | 同步方式 |
|---|---|---|
| App 仓库 | 公开流程、docs、代码 | 已有 remote（origin），两台机器 clone/push |
| info 仓库 | 脱敏交接台账（public/ + handoffs/ + CHANGELOG） | 所有者指定的**私有远程**（白名单），仅同步脱敏内容 |
| 密码管理器 | 真实密钥值（非文件） | 1Password/Bitwarden 共享库，两台机器取用 |

### 各机独占（永不跨机器，不进任何 Git）

| 机器 | 独占资源 |
|---|---|
| Windows（Android） | `pushupai-upload.jks` + `android/key.properties` + `运动app-prod-info.txt`（Android dart-define） |
| Mac（iOS） | Apple `.p12` + provisioning profile + iOS dart-define 文件（如 `ios-prod-info.txt`） |

### iOS 机器准备清单

1. clone App 仓库（`origin`）。
2. clone info 私有远程到本机 `pushup-ai-info`；读最新 handoff 了解发版状态。
3. 从密码管理器取值，填入本机 iOS dart-define 文件：`UGK_MEMBERSHIP_API_BASE_URL`、`UGK_GOOGLE_SERVER_CLIENT_ID`、`UGK_REVENUECAT_IOS_API_KEY`。
4. 本机配置 Apple 开发者证书 + provisioning profile（平台特定，agent 不代操作）。
5. 运行 `preflight.ps1` 确认 info remote 在白名单、`private/` 未跟踪。

### 关键纪律

- **RevenueCat Android key ≠ iOS key**（不同值）：iOS 打包必须用 iOS key，不能抄 Windows 的 `运动app-prod-info.txt`（那里装的是 Android key）。
- iOS 的 dart-define 文件单独建（如 `ios-prod-info.txt`），与 Android 的分开，不互相覆盖。
- `private/` 在两台机器各自本机维护，不通过 info 远程同步；需要共享的运维信息写进 `public/` 或 handoff。
- 真实密钥值只存在密码管理器和各机本机的 dart-define 文件，不进入任何 Git 仓库（包括 info 私有远程）。
- info 仓库的 push 需用户授权；两台机器都从私有远程 pull 最新 handoff 后再开始任务。
