# PushupAI 0.3.4 Google Play 更新 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 从已合并的 `origin/main` 生成可复现的 `0.3.4 (5)` Play 候选包，先完成内部测试，再复用同一 AAB 推进 Alpha 封闭测试。

**Architecture:** 本轮不增加业务功能，只提升版本号并按现有发布 SOP 构建、校验、记录和分轨道验收。每个远程写操作独立授权；Worker 分页已部署，本轮不修改 Worker、D1、OAuth、RevenueCat 或订阅商品。

**Tech Stack:** Flutter / Dart、Android App Bundle、Google Play Console、PowerShell、现有上传签名与 production `dart-define` 配置。

---

## 已确认基线

- 最新源码：`origin/main @ 4742abe`。
- 当前 `pubspec.yaml`：`0.3.3+4`。
- `versionCode=4` 已用于内部测试并推进 Alpha，不能复用。
- 当前 App：`minSdk=24`、`targetSdk=35`；Google 当前要求普通手机 App 更新至少 target API 35，现状符合。
- `0.3.3 (4)` 发布后进入 `main` 的用户可见变化包括：
  - 俯卧撑准备姿势、深度校准、计数延迟与语音延迟优化；
  - 首页个人入口与统计入口视觉优化；
  - 运动广场排行榜视觉、双榜缓存、下拉刷新和每页 20 条分页加载。
- 当前自动化基线：Flutter 339 项、Worker 108 项；发布候选必须重新运行并记录实际数量。
- 用户文件 `docs/handoff-account-features.md` 必须保持未跟踪，不修改、不 stage、不提交。

## 发布边界

- 本轮目标止于 Alpha 封闭测试，不申请或推进正式生产发布。
- Google Play 上传、内部测试发布、Alpha 推进分别请求一次明确授权。
- 若 `0.3.3` 仍在审核，不提交新的 Alpha 变更以免重置审核队列；可先完成本地候选与内部测试。
- License Testing、订阅/base plan、RevenueCat 商品映射不阻塞普通 App 更新，但继续阻塞 Google Play 购买验收。
- 12 名测试者连续 14 天与 OAuth 正式受众仍是未来正式发布门槛，不在本轮擅自修改。

### Task 1: 核对 Play 现状并锁定版本号

**Files:**
- Read: `pubspec.yaml`
- Read: `docs/release-configuration.md`
- Read locally only: `E:\AII\pushup-ai-info\handoffs\2026-07-13-alpha-0.3.3-candidate.md`
- Read locally only: `E:\AII\pushup-ai-info\private\PushupAI-发布与密钥台账.md`

**Step 1: 核对 Git 基线**

Run:

```powershell
git fetch origin
git status --short --branch
git log -1 --oneline origin/main
git diff --check
```

Expected: `origin/main` 指向待发布代码；除已知受保护文件外无本地改动。

**Step 2: 在 Play Console 只读核对**

检查：

1. App Bundle Explorer 中最高已使用 `versionCode`；
2. Alpha `0.3.3-closed-1` 是审核中、已发布还是被拒绝；
3. 内部测试和 Alpha 当前各自的活跃版本；
4. Console 是否出现新的政策或 target API 阻塞。

Expected: 最高已使用代码为 `4` 时使用 `0.3.4+5`；若已存在 `5` 或更高，改用“最高值 + 1”，不得猜测或复用。

**Step 3: 决定 Alpha 时机**

- `0.3.3` 仍在审核：允许继续本地构建和内部测试，暂停 Task 8。
- `0.3.3` 已发布或审核结束：完成内部测试后可进入 Task 8。
- `0.3.3` 被拒绝：先记录拒绝原因并判断是否影响 `0.3.4`，不直接覆盖提交。

### Task 2: 创建独立候选 worktree 和版本提交

**Files:**
- Modify: `pubspec.yaml:4`

**Step 1: 从最新 main 创建候选 worktree**

Run:

```powershell
git worktree add E:\AII\ugk-post-alpha-0.3.4 -b codex/alpha-0.3.4 origin/main
```

Expected: 新 worktree 只包含已提交源码，不带当前 worktree 的未跟踪文件。

**Step 2: 接入本机签名配置**

按私密台账在新 worktree 准备被 Git 忽略的 `android/key.properties`。只检查以下字段存在，不输出值：

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

Expected: `git status --short` 不显示密钥、JKS 或配置原件。

**Step 3: 修改版本号**

将：

```yaml
version: 0.3.3+4
```

改为：

```yaml
version: 0.3.4+5
```

若 Task 1 得到更高已用代码，只替换 `+5` 为下一个未使用整数。

**Step 4: 验证并提交版本号**

Run:

```powershell
Select-String -LiteralPath pubspec.yaml -Pattern '^version:'
git diff --check
git diff -- pubspec.yaml
git add pubspec.yaml
git commit -m "build: prepare 0.3.4 alpha"
```

Expected: 只有 `pubspec.yaml` 的版本行进入该提交。

### Task 3: 发布候选自动化回归

**Files:**
- Test: `test/`
- Test: `workers/membership-api/test/`

**Step 1: Flutter 静态检查**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

**Step 2: Flutter 全量测试**

Run:

```powershell
flutter test
```

Expected: 全部通过；记录实际测试数量，并确认回放基线 `step0=5 / v3=5 / v4=3`。

**Step 3: Worker 全量测试**

Run:

```powershell
cd workers\membership-api
npm test
cd ..\..
```

Expected: TypeScript 检查、测试构建和全部 Worker 测试通过；记录实际数量。

**Step 4: Git 完整性检查**

Run:

```powershell
git diff --check
git status --short --branch
```

Expected: 无源码改动；只允许明确识别的本机忽略配置。

### Task 4: 构建唯一的签名 AAB

**Files:**
- Read locally only: production `dart-define` 文件
- Read locally only: `android/key.properties`
- Output, ignored: `build/app/outputs/bundle/release/app-release.aab`

**Step 1: 只验证 production 配置字段存在**

检查下列字段存在且非空，不输出任何值：

- `UGK_MEMBERSHIP_API_BASE_URL`
- `UGK_GOOGLE_SERVER_CLIENT_ID`
- `UGK_REVENUECAT_ANDROID_API_KEY`

Expected: 三项齐全，RevenueCat release key 不是 Test Store `test_` key。

**Step 2: 记录源码提交**

Run:

```powershell
git rev-parse HEAD
git status --short --branch
```

Expected: HEAD 为 Task 2 的版本提交，工作树无未提交源码。

**Step 3: 构建 AAB**

Run:

```powershell
flutter build appbundle --release --dart-define-from-file=E:\AII\运动app-prod-info.txt
```

Expected: 生成 `build\app\outputs\bundle\release\app-release.aab`，release 配置校验未被绕过。

### Task 5: 校验签名、版本、权限与产物身份

**Files:**
- Inspect: `build/app/outputs/bundle/release/app-release.aab`
- Inspect: `build/app/intermediates/bundle_manifest/release/processApplicationManifestReleaseForBundle/AndroidManifest.xml`
- Inspect: `build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json`

**Step 1: 校验 JAR 签名**

Run:

```powershell
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

Expected: 退出码为 0，并出现 `jar verified`。

**Step 2: 校验上传证书**

Run:

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Expected: SHA-1 与私密台账中的 Google Play 上传证书一致；回复和公开文档不重复私密路径或配置值。

**Step 3: 校验 bundle 元数据**

必须确认：

- 包名仍为 `com.ugkexercise.ugk_exercise`；
- `versionName=0.3.4`、`versionCode=5`（或 Task 1 确认的替代值）；
- `minSdk=24`、`targetSdk=35`；
- release 不可调试；
- 不包含 `READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、`AD_ID`。

任一项不符即停止，不上传。

**Step 4: 记录产物大小和哈希**

Run:

```powershell
Get-Item build\app\outputs\bundle\release\app-release.aab
Get-FileHash -Algorithm SHA256 build\app\outputs\bundle\release\app-release.aab
```

Expected: 得到唯一的字节大小和 SHA-256；后续内部测试与 Alpha 必须复用这同一文件。

### Task 6: 记录候选并提交审核分支

**Files:**
- Modify: `docs/release-configuration.md`
- Modify locally only: 权威私密台账（位置仅从本机 info 仓库说明读取）
- Modify locally only: `E:\AII\pushup-ai-info\public\release-configuration.md`
- Modify locally only: `E:\AII\pushup-ai-info\private\PushupAI-发布与密钥台账.md`
- Modify locally only: `E:\AII\pushup-ai-info\handoffs\2026-07-14-alpha-0.3.4-candidate.md`

**Step 1: 更新 App 公开台账**

记录：版本、候选分支、源码提交、测试数量、AAB 大小、SHA-256、签名/SDK/权限结论，以及“已构建，未上传”。同时把旧 `0.3.3` 状态校正为 Console 的真实状态。

**Step 2: 更新本机三层记录**

按 `$manage-pushupai-project` 的顺序更新权威私密台账、公开快照、私密快照、handoff 和 info `CHANGELOG.md`。不保存 Secret、Token、密码、个人邮箱或设备序列号；info 仓库保持无 remote。

**Step 3: 提交公开候选记录**

Run:

```powershell
git add docs/release-configuration.md
git commit -m "docs: record 0.3.4 alpha candidate"
```

Expected: AAB 仍对应 Task 2 的源码提交；文档提交只记录产物事实。

**Step 4: 推送候选分支供审核**

在获得单独 push 授权后运行：

```powershell
git push -u origin codex/alpha-0.3.4
```

Expected: 远端分支 HEAD 与本地一致；不 force push，不自动合并 `main`。

### Task 7: 上传内部测试并做 Play 安装验收

**Files:**
- Upload: Task 4 生成且 Task 5 记录哈希的同一 AAB

**Step 1: 请求上传授权**

向用户汇报源码提交、版本、哈希、测试、签名与权限结论，明确本次授权只覆盖“上传并发布到内部测试”。

**Step 2: 创建内部测试版本**

Play Console → 测试和发布 → 内部测试：

- 发布名称：`0.3.4-internal-1`；
- 上传唯一 AAB；
- 确认 Console 识别为 `5 (0.3.4)`；
- 使用与真实改动一致的更新说明；
- 发布到现有内部测试名单。

建议中文更新说明：

```text
优化俯卧撑准备姿势、深度判断和计数语音响应；升级运动广场排行榜视觉，支持日榜/周榜快速切换、双榜刷新与分页加载；优化首页个人与统计入口。
```

**Step 3: 从 Google Play 覆盖更新**

必须从内部测试链接/Play 商店更新，不侧载 APK，不卸载、不清数据。

Expected: 从 `0.3.3` 正常升级到 `0.3.4`，登录态和本地训练记录保留，无 `DEBUG` 标识。

**Step 4: 真机验收清单**

逐项记录 PASS/FAIL：

1. 冷启动、首页和前后台恢复；
2. Google 登录、会员状态、个人资料；
3. 相机预览与准备姿势，正常俯卧撑计数、停止训练、记录保存；
4. 计数反馈与中文语音没有明显延迟或重叠；
5. 运动广场日/周切换不重复联网加载；
6. 下拉刷新同时更新双榜，触底分页无重复或跳项；
7. 排行榜会员底部提示、Top 1/2/3 卡片、普通名次在真机无裁切；
8. 更新后无 Flutter/AndroidRuntime 崩溃。

失败时保留证据但不上传截图、日志或设备序列号到 Git。

**Step 5: 更新状态记录**

精确写“已向内部测试人员发布”和真机验收结果；不要提前写成 Alpha 或正式发布完成。

### Task 8: 复用同一 AAB 推进 Alpha

**Files:**
- Promote: Task 7 已上传的同一 App Bundle

**Step 1: 检查推进门槛**

必须同时满足：

- 内部测试真机清单全通过；
- `0.3.3` Alpha 已结束审核或 Console 明确允许新版本，不会把旧审核重新排队；
- AAB 哈希与 Task 5 相同；
- 用户单独授权推进 Alpha。

**Step 2: 创建 Alpha 发布**

Play Console → 封闭测试 → Alpha：从内部测试版本提升/复用现有 App Bundle。

- 发布名称：`0.3.4-closed-1`；
- 不重新构建，不上传第二份不同 AAB；
- 开始全面发布到现有封闭测试人员。

**Step 3: 记录准确状态**

依次区分：

- 已提交；
- 快速检查；
- 审核中；
- 已向测试人员发布；
- Alpha 真机验收通过。

只有 Console 显示已发布后，才从 Alpha 加入链接安装/更新并做必要抽查。内部测试账号若要收 Alpha，需按 Google 规则先退出内部测试再加入封闭测试，或使用独立 Alpha 测试账号。

### Task 9: 收尾与下一阶段门槛

**Files:**
- Modify: `docs/release-configuration.md`
- Modify locally only: info/私密台账与 handoff

**Step 1: 收尾记录**

记录最终 Play 状态、测试结果、AAB 哈希、源码提交、发布名称和回滚依据；同步 App 公开台账与本机 info 仓库，运行敏感扫描，info 只做本地提交且保持无 remote。

**Step 2: Git 收尾**

候选分支审核通过后，再由用户决定是否合并到 `main`。禁止自动 merge、force push 或删除 worktree。

**Step 3: 明确本轮未完成事项**

以下仍需独立计划和授权：

- 12 名测试者连续 14 天及生产访问申请；
- OAuth 从测试受众转为正式受众；
- License Testing、订阅/base plan、RevenueCat Product/Package/Offering；
- Google Play sandbox 购买、恢复、取消/过期及完整 RTDN/Webhook 验收；
- 正式生产发布。

## 官方依据

- [Google Play 目标 API 要求](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play 测试轨道](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Google Play 审核与发布控制](https://support.google.com/googleplay/android-developer/answer/9859654)
- [Android versionCode/versionName](https://developer.android.com/studio/publish/versioning)
- [新个人开发者账号测试要求](https://support.google.com/googleplay/android-developer/answer/14151465)
