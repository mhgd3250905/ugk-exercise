# 交接：feat/audio-production-2026-07-23 音频制作补全（待安排任务）

> 日期：2026-07-23
> 工作树：`E:/AII/ugk-post-audio-production-2026-07-23`
> 分支：`feat/audio-production-2026-07-23`（基于 `main@e003ef6`）
> 本机 Flutter：`3.44.7`（pubspec 要求 `flutter: '>=3.44.0'`，`sdk: ^3.8.0`）
> 派发者：main reviewer（main 工作树 `E:/AII/ugk-post`）

## ⚠️ 重要：接手后等用户安排

**本分支当前没有具体任务。** 接手后**不要自行开始改代码**，先按下面"接手第一步"做只读准备，然后**等待用户给你安排具体的音频制作任务**。用户会告诉你这次要做什么、解决什么问题。

## 1. 接手第一步（只读，不改动）

1. 用中文说明你正在使用 `$manage-pushupai-project` Skill，本次任务是语音/音频素材制作与补全。
2. 运行只读预检（在 App 仓库 **main 工作树**，不是这个 worktree）：

   ```bash
   cd E:/AII/ugk-post
   powershell -ExecutionPolicy Bypass -File .agents/skills/manage-pushupai-project/scripts/preflight.ps1 -ProjectRoot E:/AII/ugk-post
   git status --short --branch
   git log --oneline -1 origin/main
   ```

3. 完整读 `E:/AII/ugk-post/AGENTS.md`（项目入口、架构分层、纪律）。
4. 读 `.agents/skills/manage-pushupai-project/SKILL.md` 和它的 references（task-routing / authority-and-ledger）。
5. **重点读音频相关权威文档**（按 SKILL §5 任务路由表）：
   - `docs/development-guide.md`（必读：怎么分块开发）
   - `docs/modules/voice-themes.md`（**核心**：素材目录结构、命名约定、播放优先级、voice_meta.json、多音色路线图）
   - `lib/product/voice_prompt_player.dart`（播放器，硬编码命名/路径/速度的真相源）
   - `test/architecture_contract_test.dart`（守护中文文案 SRT 的契约测试，断言含引导/准备/姿势中断 + 一…三十）
6. 确认你的 worktree 状态：

   ```bash
   cd E:/AII/ugk-post-audio-production-2026-07-23
   git status --short --branch
   git log --oneline -1
   ```

   应显示：分支 `feat/audio-production-2026-07-23`，HEAD `e003ef6`，与 main 同步，工作区干净。

## 2. 当前状态（2026-07-23 由 main reviewer 核实）

| 项 | 值 |
|---|---|
| 本分支基线 | `main@e003ef6` |
| 领先 main | 0 个提交（全新分支） |
| origin/main | `e003ef6`（与本地 main 同步） |
| Play Internal | `0.3.20 (23)` |
| Play Alpha | `0.3.20-closed-1`（审核中） |
| 生产 Worker 清单 | `0.3.20 (23)`，Version ID `3e558a4b-…` |

main 上最近的内容（截至本分支创建时）：
- 多机器协作改造（info 私有远程白名单 + private/ 历史清除，`13a1af0` + `e003ef6`）
- 0.3.20 发版（Internal 已发布 + Worker 清单部署 + Alpha 送审，`b8db7f5` + `58ac743`）
- 排行榜展开明细动画（`36ce274`）

### 音频素材现状（本会话亲自 ls 核实）

| 目录 | 文件 | 缺失 |
|---|---|---|
| `assets/audio/prompts/`（中文默认播放目录，进 bundle） | guide/ready + count_01~30（共 32 个） | **`pose_lost.wav` 缺失** |
| `assets/audio/voices/manbo/zh/` | guide/ready + count_01~30（共 32 个） | **`pose_lost.wav` 缺失** |
| `assets/audio/voices/manbo/en/` | guide/ready + count_01~30（共 32 个） | **`pose_lost.wav` 缺失** |
| `assets/audio/voices/manbo/voice_meta.json` | 存在，`files.pose_lost: false`，`languages: [zh, en]`，`source: mixed` | — |
| `tool/tts/` | `pushup_prompts.srt`（中文文案真源） | — |

**`pose_lost.wav` 全项目不存在**（`find assets/audio -name "pose_lost*"` 为空）。播放器接口已落地，缺失时安全静音；这是 `voice-themes.md` 路线图里明确的待补项。

> 注意：main 工作树有个**未跟踪**文件 `tool/tts/voice_script_en.md`（main reviewer 那台机器的临时稿）。**它不在 git、不在本 worktree**。若用户提到英文文案稿，向用户确认权威来源，不要假设它存在。

## 3. 你要做的事（等用户安排后）

用户会给你具体的任务。音频制作常见任务类型（仅供参考，**以用户实际指示为准**）：
- 补录 `pose_lost.wav`（中/英，两个播放目录都补：`prompts/` + `voices/manbo/zh/` + `voices/manbo/en/`，并更新 `voice_meta.json` 的 `pose_lost: true`）
- 新增一套完整语音主题（新建 `voices/<新voice_id>/<lang>/` 全套 33 个 wav + `voice_meta.json`）
- 为现有主题新增一种语言（在 `<voice_id>/` 下加 `<lang>/` 子目录 + 更新 meta）
- 调整/重新生成某语言素材（TTS 参数、加速比、采样率，注意英文数字当前是 1.2 倍速）
- 多音色主题选择功能（`voice-themes.md` 路线图最后一项，涉及设置页 UI + player 切主题）

## 4. 关键纪律（违反会埋坑，AGENTS.md 详细说明）

1. **文件名不可改、两位零填充**：`count_01.wav` 不是 `count_1.wav`（player 用 `padLeft(2,'0')`）；计数范围固定 1-30，`>30` 不播报。
2. **音频格式**：WAV、PCM_16、单声道、24000Hz（与现有素材一致，`audioplayers` 兼容）。
3. **生效路径**：当前代码按语言固定用 `manbo` 主题。中文默认要同时放 `assets/audio/prompts/`；英文放 `assets/audio/voices/manbo/en/`。新增主题选择需先完成路线图功能，否则复制到 prompts/ 才生效。
4. **文案真源**：`tool/tts/pushup_prompts.srt` 是中文文案**正确性基准**，契约测试 `architecture_contract_test.dart` 守护它（断言含引导/准备/姿势中断 + 一…三十）。改基准 SRT 要同步跑契约测试。英文等翻译各自维护独立文案源，不要改基准。
5. **播放速度**：英文数字 1.2 倍速；其余（guide/ready/pose-lost、中文全部）1.0 倍速。每次播放显式恢复速度，避免污染。
6. **l10n 边界**：语音 wav 资源独立于 UI 文案本地化，不经过 ARB；product/control 不引用 `AppLocalizations`。唯一交集是 `app_zh.arb`/`app_en.arb` 的 `exerciseSummary`。
7. **不用 `git add -A`**：显式 stage 音频与代码文件。注意根目录有未跟踪临时文件（不要误提交 `_*.py`/`_*.png`/`_*.log`）。
8. **回放基线 5/5/3 是硬约束**：`flutter test test/domain_self_check_test.dart` 必须全绿（音频改动一般不碰算法，但跑一遍守住）。

## 5. 完成后的验证（改完素材/代码后跑）

```bash
cd E:/AII/ugk-post-audio-production-2026-07-23
flutter analyze                    # 0 issue
flutter test                       # 全绿
flutter test test/architecture_contract_test.dart   # 文案契约守护
flutter test test/domain_self_check_test.dart       # 回放硬基线 5/5/3
git diff --check                   # 无空白错误
git status --short                 # 确认只 stage 了本任务的文件
```

补/改音频后：
- 若改了 `voice_meta.json`，确认字段齐全（`voice_id`/`display_name`/`languages`/`source`/`sample_rate`/`channels`/`format`/`files`）。
- 若新增目录，确认 `pubspec.yaml` 的 `assets:` 注册了新目录（当前只注册了 `prompts/` 和 `voices/manbo/en/`，**`voices/manbo/zh/` 未单独注册**——中文默认走 prompts/）。
- 真机播报需进训练页验证（相机+计数链路），见 `docs/testing-release-playbook.md`。

涉及 Worker/D1/会员/商店配置时不在本分支范围。

## 6. 与用户对话的建议开场

```
已读完交接。我在 feat/audio-production-2026-07-23（worktree E:/AII/ugk-post-audio-production-2026-07-23），
基于最新 main@e003ef6，工作区干净。

我已完成只读准备（读了 AGENTS.md、development-guide.md、voice-themes.md、voice_prompt_player.dart、architecture_contract_test.dart）。
音频现状：三个播放目录的 pose_lost.wav 都缺失（player 接口已就绪，缺失安全静音）；其余 guide/ready/count_01~30 齐全。

等你安排具体的音频制作任务——告诉我这次要做什么（补 pose_lost？新增主题？新增语言？还是多音色选择功能？）。
```

---

**交接结束。接手后先做只读准备，然后等用户安排具体任务，不要自行开始改代码。**
