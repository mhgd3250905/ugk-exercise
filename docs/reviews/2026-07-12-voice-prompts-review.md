# 分支审核报告：feat/voice-prompts

> 分支：`feat/voice-prompts` → `main`
> 日期：2026-07-12
> 作者：agent（ mhgd3250905）
> 审核：用户在 main 上审阅

## 一句话概括

用用户自制的「曼波」中文配音替换了 App 的语音播报素材（32 个 wav），并建立了多音色/多语言语音主题的目录管理结构，为以后扩展（新声优、英文等）打好基础。**本次只改素材和文档，不改任何代码。**

---

## 改动范围

### Commit 列表（3 个）

| commit | 标题 | 内容 |
|--------|------|------|
| `3fab43c` | feat(voice): 曼波配音 + 主题结构 | 替换 prompts/ 32 个 wav；新增 voices/manbo/ 主题库；voice_meta.json；voice-themes.md 文档 |
| `9508db9` | docs(tts): qwen-tts 说明（**已撤销**） | 后来不满意 qwen-tts，在 `1eae156` 删除 |
| `1eae156` | chore(tts): 清理 qwen-tts 痕迹 | 删除 qwen-tts 说明/脚本；清理 prompts_preview；精简 .gitignore |

> `9508db9` 和 `1eae156` 是「加了又删」的一对。最终效果 = qwen-tts 痕迹为零。保留在历史里是为了可追溯（万一以后想知道试过什么）。

### 文件变更统计（vs main）

```
67 files changed, 135 insertions(+)
```

| 类型 | 文件 | 说明 |
|------|------|------|
| **修改** | `assets/audio/prompts/*.wav`（32 个） | MiMo 音色 → 曼波配音（PCM_16, 24000Hz, 单声道） |
| **修改** | `AGENTS.md` | 文档地图新增 voice-themes.md |
| **修改** | `.gitignore` | 移除 prompts_preview 规则（已清理） |
| **新增** | `assets/audio/voices/manbo/`（34 个文件） | 曼波主题归档：zh/ 下 32 wav + voice_meta.json |
| **新增** | `docs/modules/voice-themes.md`（117 行） | 多音色/多语言管理规范 |

### 未改动（明确边界）

| 文件 | 状态 |
|------|------|
| `lib/product/voice_prompt_player.dart` | ❌ 未改（player 仍只读 prompts/，硬编码路径不变） |
| `lib/control/workout_controller.dart` | ❌ 未改（无参 new VoicePromptPlayer() 不变） |
| `pubspec.yaml` | ❌ 未改（prompts/ 已注册，voices/ 本次不进 bundle） |
| `tool/tts/pushup_prompts.srt` | ❌ 未改（中文文案真源，契约测试守护） |
| `test/architecture_contract_test.dart` | ❌ 未改 |

---

## 改动详解

### 1. 曼波配音替换（prompts/）

`assets/audio/prompts/` 是 player 实际播放的目录。32 个 wav 全部替换为用户自制的曼波配音：

- 用户提供的原始素材（MPEG_LAYER_III 存成 .wav 后缀）→ 转换为标准 **PCM_16 WAV**（`audioplayers` 最佳兼容）
- 统一命名：`guide.wav` / `ready.wav` / `count_01.wav` … `count_30.wav`（两位零填充，与 player 硬编码 `padLeft(2,'0')` 一致）
- 格式：24000Hz、单声道、PCM_16
- 时长：单字 0.53-0.94s，引导句 4.75-5.02s

**旧 MiMo 素材**：已删除（本地实验阶段备份过，最终清理时删除，仓库不留）。

### 2. 多音色主题库结构（voices/）

新增 `assets/audio/voices/` 作为多音色管理根目录。曼波作为第一个主题：

```
assets/audio/voices/
└── manbo/
    ├── voice_meta.json      ← 元数据（声优/语言/来源/格式/文件清单）
    └── zh/                  ← 语言子目录
        ├── guide.wav
        ├── ready.wav
        └── count_01.wav ... count_30.wav
```

**`prompts/` 与 `voices/` 的关系**：
- `prompts/` = player 当前播放的主题（单主题，进 bundle）
- `voices/` = 主题素材库（多主题归档，本次进 git 但不进 bundle）
- 以后 player 支持多主题切换时，`prompts/` 可改为指向 `voices/<选中主题>/<lang>/`

### 3. voice_meta.json（主题元数据规范）

每个主题必须有一个，定义声优信息、来源、文件清单：

```json
{
  "voice_id": "manbo",
  "display_name": "曼波",
  "language": "zh",
  "source": "manual",
  "sample_rate": 24000,
  "channels": 1,
  "format": "PCM_16 WAV",
  "files": { "guide": true, "ready": true, "count_range": [1, 30] }
}
```

### 4. 管理结构文档（voice-themes.md）

`docs/modules/voice-themes.md` 定义了：
- 目录结构规范：`voices/<voice_id>/<lang>/<filename>.wav`
- 文件命名约定（与 player 硬编码对齐）
- 如何新增音色 / 新增语言的步骤
- 文案源管理（SRT 基准 vs 各主题独立文案）
- 与 l10n 的关系（语音独立于 UI 本地化）
- 后续演进清单（player 多主题切换等待办）

---

## 安全性验证

### 契约测试：28/28 全绿 ✅

```
flutter test test/architecture_contract_test.dart
00:00 +28: All tests passed!
```

关键守护点：
- SRT 文案完整性测试（引导语 + 一…三十）—— 未受影响（SRT 未改）
- stop 流程 voice 先停 —— 未受影响（controller 未改）

### 代码零改动 ✅

```
git diff --name-only main...HEAD | grep -E "voice_prompt_player|workout_controller|pubspec"
（无输出 = 未改动）
```

player、controller、pubspec 全部未动。本次改动是**纯素材 + 纯文档**，对运行时逻辑零影响。

### AGENTS.md 纪律遵守 ✅

| 纪律 | 遵守情况 |
|------|----------|
| 不用 `git add -A` | ✅ 全程显式 stage |
| l10n 只属于 UI 层 | ✅ 语音资源未碰 ARB |
| 会员凭证不进 git | ✅ 无关，未触碰 |
| domain 不加 Flutter import | ✅ 无关，未触碰 |

---

## 审核建议

### 直接合并即可的情况
- 只想换音色、建管理结构 → **可以合并**，纯素材+文档，零代码风险

### 合并前建议人工验收的
- [ ] **实际跑 App 试听**：`flutter run`，走一遍训练流程（guide → ready → count），确认曼波配音在真机/模拟器上播放正常
- [ ] 抽听几个数字（特别是双字数 count_11/count_20/count_30）确认清晰度
- [ ] 确认 `assets/audio/voices/` 进 git 后仓库体积可接受（+约 1.1MB，全部是 wav）

### 本次不做（后续工作）
- player 代码支持运行时多主题切换（voice-themes.md 有待办清单）
- 设置页音色选择 UI
- 英文/其他语言语音
- VoicePromptPlayer 单元测试补充

---

## 相关链接

- 分支：`origin/feat/voice-prompts`
- PR 创建：https://github.com/mhgd3250905/ugk-exercise/pull/new/feat/voice-prompts
- 管理规范文档：`docs/modules/voice-themes.md`
