# AGENTS.md — 接手必读

> 这个文件是给任何接手本项目的 AI agent / 开发者的**第一入口**。
> 请先读完本文件，再开始任何改动。

## 这是什么项目

ugk-post：Android 俯卧撑计数 App（Flutter）。手机固定正前方 → 相机实时姿态识别（MoveNet TFLite）→ 俯卧撑计数 → 中/英文语音播报 → 本地记录。

此外已落地：
- 账号与会员系统（Google OAuth 登录 + RevenueCat 内购 + Cloudflare Worker/D1 后端），见 [docs/modules/membership.md](docs/modules/membership.md)
- 多语言（zh/en）与浅/深色主题底座，见 [docs/design/app-ui-v1.md](docs/design/app-ui-v1.md)

## ⚠️ 开发前必读

**先读 [docs/development-guide.md](docs/development-guide.md)** —— 它告诉你在这个架构里怎么分块开发一个功能、代码放哪、按什么顺序写。

核心一句话：**先判断"心脏"在哪层，从最底层开始写，每层写完立刻测，上层只是薄薄地调用下层。** 依赖只能向上指。

## 项目专属 Skill

处理本项目的开发、测试、打包、Worker/D1、OAuth、RevenueCat、Google Play、台账或交接任务时，优先使用 $manage-pushupai-project。

- Skill 正本：.agents/skills/manage-pushupai-project/SKILL.md
- 若当前 agent 未自动发现该 Skill，必须直接完整读取上述文件并遵守其任务路由、授权和台账规则。
- Skill 是流程入口，不替代本文件和各模块权威文档。
- Skill 不保存任何密钥值；私密信息仍只按“本地发布信息备份”规则读取。

## 架构分层（依赖只向上）

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               产品规则（计数管线/门控/存储/语音/会员状态），只依赖 domain
control/               编排（WorkoutController / AccountController 串起 product + 基础设施）
ui/pages/ ui/          纯展示，监听 ChangeNotifier 渲染；l10n 与主题只属于这层 + app 根
config/                纯常量（会员 API base/Google Client ID/RevenueCat key，dart-define 注入）
l10n/                  多语言 ARB + 生成的 AppLocalizations（UI/app 根专用）
inference/ pipeline/ platform/   基础设施（推理/帧处理/相机/会员服务），依赖 domain
workers/membership-api/           独立的 Cloudflare Worker（TS，账号/会员后端，与 Flutter 解耦）
```

## 跑起来 & 验证

```bash
flutter analyze          # 必须无 issue
flutter test             # 必须全绿（含回放基线 5/5/3）
flutter build apk --release --split-per-abi
cd workers/membership-api && npm test   # 会员 Worker全量测试
```

- 测试夹具在 `test/fixtures/`（脱敏标量信号，已纳入 git，干净 checkout 可复现）
- 回放基线 **step0=5 / v3=5 / v4=3** 是硬约束，改了信号源必须重验

## 关键纪律（违反会埋坑）

1. **不在 `pushup_domain.dart` 加 Flutter/platform import** —— 破坏纯 dart 地基
2. **不在 domain/product 里平均两个手腕坐标** —— 这是历史 bug 根源（见 `docs/modules/recognition.md`）
3. **WorkoutController 的异步方法保留 session 守卫** —— 每个 await 后校验 `session != _session`
4. **不用 `git add -A`** —— 显式 stage 代码文件，根目录有未跟踪临时文件（截图/apk/step0）
5. **真实视频/csv 不进 git**（含人脸隐私）—— 测试只用 `test/fixtures/` 的脱敏数据
6. **会员凭证（Google Client ID / RevenueCat key / Worker secret）不进 git、不进 `app_theme.dart`** —— 放 `lib/config/membership_config.dart`，走 `--dart-define` 注入；release 缺值由 `validateMembershipConfig()` fail-fast（见 `docs/modules/membership.md`）
7. **l10n 只属于 UI/app 根** —— domain/product/control 层不引用 `AppLocalizations`，文案进 ARB 再用（见 `docs/design/app-ui-v1.md` §7）
8. **真机登录/会员验收的 Debug 包必须带本机构建配置** —— 按 `docs/testing-release-playbook.md` §4.1 使用 `--dart-define-from-file` 构建；无配置 Debug 包不得覆盖该验收设备
9. **Flutter UI 迭代默认保留 resident `flutter run` 会话** —— Dart/Widget 小改用 Hot Reload（`r`），需要重跑 `main()` 或自制启动页时用 Hot Restart（`R`）；日常 UI 调试不要使用 `--no-resident`，只在原生/构建配置变化或最终冷启动验收时重新构建安装（见 `docs/development-guide.md` 类型 E）

## 真机调试日志

```bash
adb -s <device> logcat -s flutter | grep UGK
```

UGK tag 覆盖：session 生命周期 / ready 标定 / lost-pose / stable 翻转 / count 计数。

## 文档地图

| 文档 | 内容 |
|------|------|
| [docs/development-guide.md](docs/development-guide.md) | **开发准则：怎么分块开发一个功能** |
| [docs/testing-release-playbook.md](docs/testing-release-playbook.md) | **测试分层：本地、排行榜、会员、内部测试与 Alpha 发布怎么选** |
| [docs/modules/recognition.md](docs/modules/recognition.md) | 识别算法第一性原则、数据流、门控、阈值 |
| [docs/pushup-algorithm-remediation-2026-07-14.md](docs/pushup-algorithm-remediation-2026-07-14.md) | **本轮算法整改记录：真实场景、问题根因、决策依据、真机证据与回滚索引** |
| [docs/modules/membership.md](docs/modules/membership.md) | 账号与会员系统（OAuth/RevenueCat/Worker/D1） |
| [docs/modules/voice-themes.md](docs/modules/voice-themes.md) | 语音主题管理：多音色/多语言素材目录结构与规范 |
| [docs/release-configuration.md](docs/release-configuration.md) | Google Play、OAuth、RevenueCat、签名、密钥备份与发布接手台账 |
| [docs/design/app-ui-v1.md](docs/design/app-ui-v1.md) | UI V1 设计规范 + 多语言与主题维护规则 |
| [docs/architecture-analysis.md](docs/architecture-analysis.md) | 架构现状 + 债务清单 |
| [docs/architecture-plan.md](docs/architecture-plan.md) | 目标分层 + 重构路线图 |
| [docs/modules/](docs/modules/) | 各模块需求说明（pipeline/anchor/gate/controller/membership） |
| [docs/refactor-report.md](docs/refactor-report.md) | 重构复盘 + 审查记录 |
| [docs/handoff-template.md](docs/handoff-template.md) | 每次新会话发给 agent 的交接消息模板 |
| docs/archive/ | 历史交接文档（已过时，仅供参考） |

### 本地发布信息备份

`E:\AII\pushup-ai-info` 是仅本机使用的 Git 备份仓库，保存公开发布流程、脱敏私密台账和新会话交接快照。接手应用商店、OAuth、RevenueCat、Google Play 或 Cloudflare 配置时，先读其 `README.md` 和 `AGENTS.md`。

该仓库禁止配置 remote 或推送；不得把 `private/` 内容复制到聊天、Issue 或 App 仓库。

## 版本基线（git tag）

```
v0.4-reproducible       可复现（算法稳定基线）
v0.3-review-fixed       审查修复后
v0.2-refactor-complete  重构完成
v0.1-architecture-baseline  重构前算法稳定版
```

> 注意：以上 tag 是**重构期**的算法基线，用于回放/计数回归参照。
> 当前 `main` 已在此基础上叠加了会员系统、排行榜、i18n/主题和多轮 UI/算法改进（见上文）；精确提交数以 `git rev-list --count v0.4-reproducible..main` 为准，具体差异以 `git log v0.4-reproducible..main` 为准。
> 如需只验证算法，回放基线仍由 `test/fixtures/` 守护（step0=5 / v3=5 / v4=3），与 tag 无关。

回退到算法基线：`git checkout v0.4-reproducible`
