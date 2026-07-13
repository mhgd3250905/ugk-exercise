# 审核报告修订实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `docs/audit-2026-07-13.md` 修订为区分“已验证事实、历史台账记录、工程判断”的可靠审核报告。

**Architecture:** 只修改审核报告，不整改代码，不改交接文档。保留已复现的健康基线和属实的文档问题；删除不成立的发现，降低证据不足的严重度，并让总结、优先级和证据索引与正文一致。

**Tech Stack:** Markdown、Git、PowerShell、现有 Flutter/Worker 验证结果。

---

### Task 1: 修正基线与结论边界

**Files:**
- Modify: `docs/audit-2026-07-13.md:1-25`

**Step 1: 保留已复现基线**

保留以下事实：

- HEAD `1531c37`，与 `main`/`origin/main` 一致。
- `e056c26..1531c37` 为 38 个提交。
- `flutter analyze` 0 issue。
- `flutter test` 312/312，回放 5/5/3。
- Worker 类型检查通过，测试 106/106。
- `git diff --check` 通过。

**Step 2: 修正工作树描述**

把“工作树干净，仅 handoff 未跟踪”改为带时间边界的表述：报告写作完成后存在审核报告与 handoff 两个未跟踪文件；报告生成前的瞬时状态无法从当前 Git 状态复原。

**Step 3: 删除绝对结论**

把“无功能性 bug、无安全泄露、无发布阻断项”改为：

> 本次自动化与静态检查未发现功能回归或仓库内凭证值；未执行新的真机、线上接口或控制台实时验收。发布链路仍以发布台账中的 BLOCKED/P0 项为准。

**Step 4: 核对差异**

Run:

```powershell
git diff -- docs/audit-2026-07-13.md
```

Expected: 只改变基线措辞，不改变测试数字。

---

### Task 2: 重写 M1-M6

**Files:**
- Modify: `docs/audit-2026-07-13.md:30-144`

**Step 1: 删除 M1**

删除“`PoseSilhouetteTracker` 错放 UI”问题。把以下事实移到“已核实的合理设计”小节：剪影 tracker 只处理视觉副本，不进入识别或计数链路；纯 Dart 不等于必须进入 product。

**Step 2: 重写 M2**

保留为中等或轻微纪律问题，标题改为“`switchCamera()` 的 session 检查晚于多个 await”。影响只描述 stop/dispose 使旧切换流程失效时的资源操作交错，不再写“快速连续切换”。建议要求先补竞态测试，再按每个会继续执行状态写入/初始化的 await 设置守卫。

**Step 3: 降级 M3**

标题改为“Workout 状态以中文字符串充当内部状态码”。明确：

- UI 已通过 `_localizedWorkoutStatus()` 映射到 ARB，当前中英文训练页测试通过。
- RevenueCat 异常消息不会直接渲染，而是映射为错误码。
- `membership_status.dart` 的中文 fallback 是单独的潜在漏翻译点。
- 建议 enum/稳定代码是可维护性改进，不是当前系统性 i18n 故障。

**Step 4: 重写 M4**

标题改为“分层规则与开发指南对资源常量位置互相矛盾”。同时引用：

- `platform/replay_utils.dart` 直接 import `ui/app_theme.dart`。
- `docs/development-guide.md` 又明确要求 `modelPath`/`replayVideoName` 放在该文件。

建议先统一文档，再决定是否迁到 `config/`；不再称其为单纯代码违规。

**Step 5: 将 M5 降为轻微**

保留服务端必返、模型必填、UI fallback 基本不可达的证据。建议只删除 UI 回退函数，不新增跨端共享抽象。

**Step 6: 删除 M6**

删除“可能把 B 的结果按 A owner 标记”的结论。补一条已核实说明：同步请求、结果和本地 `_replace` 都绑定 A 的 owner；账号切换后下一轮已有 `_isCurrent` 检查。

**Step 7: 检查编号与严重度**

Run:

```powershell
rg -n "^#### [ML][0-9]+" docs/audit-2026-07-13.md
```

Expected: 编号连续，无正文删除后遗留的旧引用。

---

### Task 3: 收紧 L1-L5

**Files:**
- Modify: `docs/audit-2026-07-13.md:146-213`

**Step 1: 保留但改写 L1**

承认空 catch 存在，同时记录三类既有策略：设置写入失败保留内存选择、云同步失败不阻塞本地训练完成、待同步记录由后续触发重试。把日志改为可选可观测性增强，不要求向用户报错。

**Step 2: 删除 L2**

删除“ReplayControl 过细”结论。它是有独立测试的小状态机；是否 `ChangeNotifier` 不是 control 层成立条件。

**Step 3: 收紧 L3**

只保留可测量的长方法事实。删除抽象 `ListenableBuilder`、统一错误映射等泛化建议；只在组件真实跨页复用或页面已难以审查时再提取。

**Step 4: 删除 L4**

删除置信度字面量和语音 30 上限问题。参数已有命名/注入入口，30 也有语音资源合同和 player 守卫。

**Step 5: 把 L5 移入“已确认的有意约定”**

记录生成文件被跟踪且设计文档已标注其来源。删除“手工加生成文件头”与“.gitignore 加注释”的建议。

---

### Task 4: 修正六维总结与遗漏

**Files:**
- Modify: `docs/audit-2026-07-13.md:215-270`

**Step 1: 模块设计**

删除 tracker/adapter 错层结论。保留排行榜身份链路整体清晰、匿名头像 fallback 可删除。

**Step 2: 依赖方向**

把“product/domain 纯净度满分”改为文档矛盾：

- domain 无 Flutter/平台依赖，属实。
- product 中 `voice_prompt_player.dart` 依赖 `audioplayers`。
- product 中 `workout_session_store.dart` 依赖 `dart:io`/`path_provider`。
- 这与“product 只依赖 domain”不一致，但 AGENTS 又把语音/存储列入 product；需要另开架构决策，不在本报告顺手迁移。

**Step 3: 冗余与死代码**

删除“无死代码”，避免与匿名头像 fallback 自相矛盾。保留分支 ahead/behind 数字与计划文档未标状态的事实。

**Step 4: 文档维度**

保留以下属实项：测试数滞后、v0.4 实际领先 132 提交、架构文档是旧基线、membership 文档过时、release 文档 canJoin 状态矛盾、旧 handoff 引用不存在。

明确旧基线架构文档不应直接改写历史，而应增加“历史基线”横幅或另写当前架构概览。

**Step 5: 安全与发布边界**

改为：

- 仓库敏感模式扫描无真实凭证值命中，敏感签名文件未被跟踪。
- 邮箱形态内容只有示例域名和公开系统服务账号，不能写“完全无邮箱”。
- Worker 鉴权/HMAC 结论由代码和测试支持。
- 疑似暴露 Token 的 P0 轮换项仍存在，不能写“项目安全全部闭环”。
- 正式购买链路仍 BLOCKED，不得写“无发布阻断”。

---

### Task 5: 重写总体结论、优先级与证据索引

**Files:**
- Modify: `docs/audit-2026-07-13.md:272-300`

**Step 1: 重写总体结论**

结论限定为：自动化健康、仓库静态安全扫描干净、文档状态明显滞后；不推断没有未知 bug，也不把历史台账当实时平台验证。

**Step 2: 更新优先级**

改为：

1. 更新测试数量、membership 和 release 文档矛盾。
2. 为 `switchCamera()` 补竞态测试，再修 session 守卫。
3. 删除匿名头像死回退。
4. 另开架构决策统一资源常量与 product 平台依赖规则。

明确“不移动 `PoseSilhouetteTracker`”。

**Step 3: 重建证据索引**

删除已取消的 M1/M6/L2/L4/L5 索引；逐条确认剩余 `file:line` 存在且与正文一致。

Run:

```powershell
rg -n "M1|M6|L2|L4|L5|纯净度满分|无死代码|无发布阻断|安全干净" docs/audit-2026-07-13.md
```

Expected: 旧结论无命中；若在“已删除/不建议”语境中保留，人工确认语义明确。

---

### Task 6: 文档级验证与交付

**Files:**
- Verify: `docs/audit-2026-07-13.md`
- Preserve: `docs/handoff-2026-07-13-audit.md`

**Step 1: 确认代码基线未变**

Run:

```powershell
git rev-parse HEAD
git status --short --branch
```

Expected: HEAD 仍为 `1531c37`；只出现原有两份用户文档和本计划/审核报告的预期状态。

**Step 2: 检查 Markdown 与空白**

Run:

```powershell
git diff --check
git diff --stat -- docs/audit-2026-07-13.md
git diff -- docs/audit-2026-07-13.md
```

Expected: 无空白错误；只修改审核报告。

**Step 3: 决定是否重跑测试**

若 HEAD 未变且只改 Markdown，不重复运行 Flutter/Worker 全量测试，直接引用本次已复现的 312/106 结果并写明日期。若执行期间 HEAD 或代码发生变化，则重新运行：

```powershell
flutter analyze
flutter test
Push-Location workers/membership-api
npm run check
npm test
Pop-Location
```

Expected: 0 issue、312/312、106/106；若数量变化，报告写实际数字。

**Step 4: 可选提交（仅在用户明确要求时）**

```powershell
git add -- docs/audit-2026-07-13.md docs/plans/2026-07-13-audit-report-revision.md
git commit -m "docs: correct architecture audit findings"
```

禁止 stage `docs/handoff-2026-07-13-audit.md`，禁止使用 `git add -A`。
