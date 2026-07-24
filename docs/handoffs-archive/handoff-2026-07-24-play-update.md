# 交接：release/play-update-2026-07-24 Google Play 版本更新（待安排任务）

> 日期：2026-07-24
> 工作树：`E:/AII/ugk-post-play-update-2026-07-24`
> 分支：`release/play-update-2026-07-24`（基于 `main@b5b1768`）
> 本机 Flutter：`3.44.7`（pubspec 要求 `flutter: '>=3.44.0'`，`sdk: ^3.8.0`）
> 派发者：main reviewer（main 工作树 `E:/AII/ugk-post`）

## ⚠️ 重要：接手后等用户安排 + 每步单独授权

**本分支当前没有具体任务。** 接手后**不要自行开始改代码或动 Play/Worker**，先按下面"接手第一步"做只读准备，然后**等待用户给你安排具体的发版任务**。

**发版是高风险多步操作**，授权逐次单独给，不能从一步推断下一步：
- ❌ 不能把"构建 AAB"理解成"上传"
- ❌ 不能把"上传 Internal"理解成"推进 Alpha"
- ❌ 不能把"打包"理解成"部署 Worker"
- ✅ 每个动作（版本号改动 / 构建 / 上传 / 轨道推进 / Worker 部署 / Alpha 送审）都要用户**明确说出**才执行

## 1. 接手第一步（只读，不改动）

1. 用中文说明你正在使用 `$manage-pushupai-project` Skill，本次任务是 **Google Play 发版**。
2. 运行只读预检（在 App 仓库 **main 工作树**，不是这个 worktree）：

   ```bash
   cd E:/AII/ugk-post
   powershell -ExecutionPolicy Bypass -File .agents/skills/manage-pushupai-project/scripts/preflight.ps1 -ProjectRoot E:/AII/ugk-post
   git status --short --branch
   git log --oneline -1 origin/main
   ```

3. 完整读 `E:/AII/ugk-post/AGENTS.md`（项目入口、架构、纪律）。
4. 读 `.agents/skills/manage-pushupai-project/SKILL.md` 和 references（**重点 authority-and-ledger + browser-platform-ops**）。
5. **重点读发版权威文档**（按 SKILL §5 任务路由）：
   - `docs/testing-release-playbook.md`（**必读**：测试分流、Internal→Alpha 顺序、真机验收项）
   - `docs/release-configuration.md`（**必读**：AAB SOP、签名、版本号规则、Play 轨道坑、§1 当前发版状态）
   - `docs/modules/membership.md`（Worker/D1 合同，发版时 Worker 清单要同步）
6. **读本机 info 仓库最新发版 handoff**（只本机读，不外传）：
   - `E:/AII/pushup-ai-info/handoffs/2026-07-23-play-0.3.20-internal-published-worker-deployed-alpha-review.md`（0.3.20 发版全流程记录）
   - `E:/AII/pushup-ai-info/README.md` + `AGENTS.md` + `SECURITY.md`
7. **用 Play Console 独立核对当前轨道状态**（不依赖文档历史快照）：
   - Internal 当前是哪个版本、是否已发布
   - Alpha 当前是哪个版本、是否审核中/已发布
   - 因为 release-configuration.md §1 的快照是 0.3.20 发版时的（main 还在 `36ce274`），**之后 main 又合并了内容**，状态可能已变
8. 确认你的 worktree 状态：

   ```bash
   cd E:/AII/ugk-post-play-update-2026-07-24
   git status --short --branch
   git log --oneline -1
   ```

   应显示：分支 `release/play-update-2026-07-24`，HEAD `b5b1768`，与 main 同步，工作区干净。

## 2. 当前状态（2026-07-24 由 main reviewer 核实）

| 项 | 值 |
|---|---|
| 本分支基线 | `main@b5b1768` |
| 领先 main | 0 个提交（全新分支） |
| origin/main | `b5b1768`（与本地 main 同步） |
| pubspec 当前版本 | `0.3.20+23` |
| Play Internal | `0.3.20 (23)` 已发布（源 `b8db7f5`，基于旧 main `36ce274`） |
| Play Alpha | `0.3.19 (22)` 已发布；`0.3.20 (23)` **审核中**（送审 2026-07-23） |
| 生产 Worker 清单 | `0.3.20 (23)`，Version ID 见私密台账（可 rollback） |

### ⚠️ 关键：main 有未发布的新内容

- **已发布的最高 Play 版本**：`0.3.20 (23)`，源提交 `b8db7f5`，基于 **旧 main `36ce274`**。
- **当前 main `b5b1768`** 在 `36ce274` 基础上又合并了：
  - 音频补全 + 窄距误报修复（`c6c6dc9`）
  - ui-polish：排行榜水印 + 剪影美化 + 账号 RevenueCat 修复（`5ad936e`）
  - P0 稳定性：损坏 JSON 恢复 + 同步健壮性（`b5b1768`）
- **这些新内容都还没发到任何 Play 轨道**。本次「Play 版本更新」大概率就是把 `b5b1768` 的新内容做成新版本（如 `0.3.21+24` 或更高）发布。**具体版本号和发版范围由用户决定**。

### 发版 SOP 顺序（App+Worker 联动，固定，不可乱序）

含安全改动时顺序固定（见 SKILL + release-configuration.md）：
1. **版本号改动**：pubspec `version: <新名>+<新号>`（新号必须高于且未被 Play 用的 versionCode）。
2. **门禁**：analyze 0 / 全量 test / 回放 5/5/3 / Worker npm test / git diff --check。
3. **构建 AAB**：`flutter build appbundle --release --dart-define-from-file=<prod 配置>`（正斜杠路径；只引用受保护配置文件，命令行不传值）。
4. **AAB 核验**：签名 / 上传证书 / applicationId / 版本 / SDK / 禁止权限 / 大小 / SHA-256。
5. **Worker 清单部署**（若版本号变）：先部署含安全改动但**旧清单**的 Worker → App Internal → 部署**新清单** Worker（防 App 被旧版本误判强制更新）。部署前比对生产清单防回退，部署后 6 项探针。
6. **Internal 发布**：上传 AAB → Internal 轨道 → 立即发布。
7. **Alpha 送审**：复用同一 AAB 从内容库推进 Alpha → 送审（**审核通过前不算发布**）。
8. **真机验收**：Internal/Alpha 真机逐项过（见 testing-release-playbook.md）。

每一步都要用户单独授权，且**状态词要精确**（已构建≠已上传≠已发布≠真机通过）。

## 3. 你要做的事（等用户安排后）

用户会给你具体任务。Play 发版常见任务（仅供参考，**以用户实际指示为准**）：
- 把当前 main `b5b1768` 的新内容做成新 Play 版本（改 versionCode/Name + 构建 + 发 Internal）
- 推进某个已在内容库的 AAB 到 Alpha 送审
- 修复发版门禁发现的某个问题（如权限、SDK、签名）
- 更新 Worker `app_update.ts` 清单（新 versionCode + 中英文 release notes）
- 真机验收某个已发布版本
- 处理 Play 审核被拒 / Alpha 卡审核

## 4. 关键纪律（违反会埋坑，AGENTS.md + release-configuration.md 详细说明）

1. **versionCode 必须更高且未被 Play 使用**：当前最高是 23，下一个候选至少 24。先查 Play Console 确认 24 没被占用。
2. **产物必须对应已提交源码**：构建前 commit 版本号改动，AAB 对应那个提交。
3. **production dart-define / key.properties 只检查字段存在，不读取/输出值**：秘密不进 Git、不进命令行、不复述。
4. **Internal 立即发布 vs Alpha 需送审**：两个轨道机制不同，不能混。
5. **同一 AAB 从 Internal 推进 Alpha**：不得无故重新构建不同产物。
6. **Worker 部署防回退**：部署前比对生产清单 Version ID；App+Worker 联动顺序固定。
7. **浏览器操作 Play Console/Cloudflare**：借用持久登录态，**不代用户登录或填密码**；浏览器自动填充的密码可能明文出现在 accessibility 快照，**不得复述/截图/记录**，并提醒用户事后改密（见 browser-platform-ops.md）。
8. **不用 `git add -A`**：显式 stage 版本号/清单文件，根目录有未跟踪临时文件。
9. **回放基线 5/5/3 是硬约束**：`flutter test test/domain_self_check_test.dart` 必须全绿。
10. **状态词精确**：已构建/已上传/审核中/已发布/真机通过是不同状态，逐项记录，不提前宣告成功。

## 5. 完成后的验证（改完版本号/构建后跑）

```bash
cd E:/AII/ugk-post-play-update-2026-07-24
flutter analyze                    # 0 issue
flutter test                       # 全绿
flutter test test/domain_self_check_test.dart   # 回放硬基线 5/5/3
cd workers/membership-api && npm test && cd ..   # 若改了 Worker 清单
git diff --check                   # 无空白错误
git status --short                 # 确认只 stage 了版本号/清单文件
```

构建 AAB 后核验：签名 / 上传证书 / applicationId / versionCode/Name / SDK / 禁止权限（无 READ_MEDIA_*/AD_ID）/ 大小 / SHA-256（见 release-configuration.md §6.4）。

## 6. 与用户对话的建议开场

```
已读完交接。我在 release/play-update-2026-07-24（worktree E:/AII/ugk-post-play-update-2026-07-24），
基于最新 main@b5b1768，工作区干净。

我已完成只读准备（读了 AGENTS.md、development-guide.md、testing-release-playbook.md、
release-configuration.md、membership.md、authority-and-ledger、browser-platform-ops，以及 info 最新 0.3.20 handoff）。

发版现状：Play Internal/Alpha 最高都是 0.3.20 (23)（源 b8db7f5，基于旧 main 36ce274）；
当前 main b5b1768 在那之后又合并了音频补全+窄距修复+ui-polish+P0稳定性，这些还没发到任何轨道。

等你安排具体的发版任务——告诉我这次发什么版本（versionCode/Name）、发到哪个轨道、范围多大。
每一步（版本号改动/构建/上传/Worker部署/轨道推进/送审）我都会单独向你确认授权后再执行。
```

---

**交接结束。接手后先做只读准备（含 Play Console 独立核对当前轨道状态），然后等用户安排具体发版任务，每步单独授权，不自行开始。**
