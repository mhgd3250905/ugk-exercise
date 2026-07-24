# 语音主题管理（Voice Themes）

> 素材库：`assets/audio/voices/`
> 播放目录：中文默认 `assets/audio/prompts/`；英文 `assets/audio/voices/manbo/en/`
> 文案源：`tool/tts/`
> 播放端口：`lib/product/voice_prompt_player.dart`
> 平台播放器：`lib/platform/audio_voice_prompt_player.dart`

## 为什么存在

项目需要支持**多种音色和多种语言**的语音播报（不同声优配音、中/英文等）。早期是「零维度」单一音色——`prompts/` 里只有一套中文素材，player 硬编码读取。随着自制配音（曼波）的引入，以及未来可能接入更多声优/TTS 生成的音色，需要一套规范的目录结构和元数据约定来管理多套语音素材，避免散落难找、命名混乱。

本文档定义这个管理结构。player 已支持按 App 语言在中文默认目录和 `manbo/en` 间切换；多音色主题选择仍是后续工作。

## 目录结构规范

```
assets/audio/
├── prompts/                          ← 当前中文默认播放目录（进 bundle）
│   ├── guide.wav
│   ├── ready.wav
│   ├── pose_lost.wav
│   ├── too_close.wav
│   ├── narrow_form.wav
│   └── count_01.wav ... count_30.wav
│
└── voices/                           ← 语音主题素材库（多主题归档）
    └── <voice_id>/                   ← 一个 voice_id = 一套语音主题
        ├── voice_meta.json           ← 主题元数据（必需）
        └── <lang>/                   ← 语言子目录（zh / en / ...）
            ├── guide.wav
            ├── ready.wav
            ├── pose_lost.wav
            ├── too_close.wav
            ├── narrow_form.wav
            └── count_01.wav ... count_30.wav
```

### 命名约定（与 player 硬编码一致，不可改）

| 文件名 | 内容 | 触发时机 |
|--------|------|----------|
| `guide.wav` | 摆放引导语 | 训练开始、相机就绪后播一次 |
| `ready.wav` | 准备完成语 | 用户进入标准俯卧撑姿势后播一次 |
| `pose_lost.wav` | “姿势已中断，请按指引重新准备。” | 运动态连续 15 帧姿态不可用、强制退回准备态时播一次 |
| `too_close.wav` | “距离过近，请退后一点点” | 准备态标定 `readyGroundSpan` 超过阈值（600px），进入 tooClose 状态的 leading-edge 时播一次 |
| `narrow_form.wav` | “收拢双臂，手腕再靠近一点” | 窄距俯卧撑模式下，gate 判定 `doesNotMatch`（手腕距/肩宽 > 1.5）、进入 narrowForm 状态的 leading-edge 时播一次 |
| `count_01.wav` … `count_30.wav` | 数字 1-30 | 每完成一个俯卧撑播对应数字；**>30 不播报**（player 硬上限） |

- 文件名**两位零填充**：`count_01.wav` 不是 `count_1.wav`（player 用 `padLeft(2,'0')`）。
- 计数范围固定 1-30，多出无意义。
- 格式：WAV，建议 PCM_16、单声道、24000Hz（与现有素材一致，`audioplayers` 兼容）。
- `too_close.wav` / `narrow_form.wav` 为**纠错型提示**，3 秒节流（见下），避免两个独立维度的状态乒乓打断；缺失时安全静音。
- `pose_lost.wav` 播放器与控制器接口已落地，中英文音频已补录。

## 播放优先级与速度

- 所有语音都采用“最新事件优先”：新的 guide、ready、pose-lost 或 count 到来时，立即停止当前音频并播放最新音频，不等待上一条自然结束，也不积压数字队列。
- 播放器控制命令可以为规避异步竞态而串行，但不得等待 WAV 播放完成；连续快速计数时允许上一数字尾音被下一数字截断，以当前画面计数及时同步为最高优先级。
- 英文目录 `audio/voices/manbo/en` 的数字计数使用 1.2 倍速；英文 guide/ready/pose-lost/too-close/narrow-form、中文全部均保持 1.0 倍速。
- 每次播放都显式恢复该音频应使用的速度，避免英文数字的 1.2 倍速污染后续非数字提示。
- **纠错型提示节流**：`too_close` / `narrow_form` 检测两个独立维度（距离过近 / 手腕外展），在窄距+近距离场景下状态会互相乒乓切换。播放器对这两个提示做 3 秒节流——距上次实际播放不足 3 秒的纠错提示直接丢弃，防止“收拢双臂”与“距离过近”交替打断。节流时间戳只在**实际播放时**更新，被丢弃的提示不刷新时间戳。`guide` / `ready` / `pose_lost`（生命周期里程碑）和 `count`（即时同步画面）**不节流**，且能正常打断正在播的纠错提示。

### voice_meta.json 规范

每个 `<voice_id>/` 下必须有一个 `voice_meta.json`：

```json
{
  "voice_id": "manbo",
  "display_name": "曼波",
  "languages": ["zh", "en"],
  "description": "简短描述音色风格",
  "source": "mixed",
  "source_detail": "素材来源说明（录制方式/TTS 模型/原始位置）",
  "sample_rate": 24000,
  "channels": 1,
  "format": "PCM_16 WAV",
  "created": "2026-07-12",
  "files": {
    "guide": true,
    "ready": true,
    "pose_lost": true,
    "too_close": true,
    "narrow_form": true,
    "count_range": [1, 30]
  }
}
```

`source` 字段取值：`manual`（人工录制）/ `qwen-tts`（Qwen3-TTS 生成）/ `mimo`（MiMo TTS 生成）/ `mixed`（不同语言来源不同）/ 其他。多语言主题使用 `languages` 数组；各语言来源差异写入 `source_detail`。

## 当前主题清单

| voice_id | 语言 | 来源 | 说明 |
|----------|------|------|------|
| `manbo` | zh | manual | 用户自制中文配音，当前中文默认（已复制到 prompts/ 生效） |
| `manbo` | en | qwen-tts | Vivian 标准女声，App 英文/非中文系统语言使用 |

（旧 MiMo 音色素材的本地备份在 `prompts_mimo_backup/`，untracked，不作为主题管理。）

## 如何新增一个主题

1. **准备素材**：录制或用 TTS 生成全套 35 个 wav（guide + ready + pose_lost + too_close + narrow_form + count_01~30），命名遵守上表。
2. **建目录**：`assets/audio/voices/<新voice_id>/zh/`，放入 35 个 wav。
3. **写 meta**：在 `<新voice_id>/` 下创建 `voice_meta.json`（复制 manbo 的改）。
4. **（可选）留文案源**：如果是 TTS 生成的，把生成用的 SRT/文案放到 `tool/tts/voices/<voice_id>_<lang>.srt`。
5. **生效到 App**：当前代码按语言固定使用 `manbo` 主题，尚无多音色设置。替换中文默认音色仍需复制到 `assets/audio/prompts/`；新增可选择主题需先完成下方“多音色主题选择”。
6. **提交**：`voices/` 进 git，显式 stage（遵守 AGENTS.md 不用 `git add -A`）。

## 如何新增一种语言

1. 在已有 `<voice_id>/` 下新建 `<lang>/` 子目录（如 `en/`）。
2. 放入该语言的全套 35 个 wav（文案需翻译，见下）。
3. 更新 `voice_meta.json` 的 `languages` 列表和对应 `source_detail`。
4. 文案源：`tool/tts/voices/<voice_id>_<lang>.srt`。

## 文案源管理

| 文件 | 作用 | 守护 |
|------|------|------|
| `tool/tts/pushup_prompts.srt` | 中文文案真源（曼波/Qwen3/MiMo 共用的中文文案基准） | 契约测试 `architecture_contract_test.dart` 断言含引导语、准备完成、姿势中断 + 一…三十 |
| `tool/tts/voices/<voice_id>_<lang>.srt` | 特定主题/语言的文案源（可选，TTS 生成时用） | 无硬约束 |

> **注意**：曼波是 manual 源，不走 SRT。`pushup_prompts.srt` 仍是中文文案的「正确性基准」，契约测试守护它。新主题若文案与基准不同（如英文翻译），各自维护独立文案源，不要改基准 SRT。

## 与 l10n 的关系

**语音播报资源独立于 UI 文案本地化**（见 `docs/development-guide.md` §l10n 纪律、`docs/design/app-ui-v1.md` §7）：
- UI 文案（按钮、标签）走 ARB → `AppLocalizations`，只属于 UI/app 根层。
- 语音播报内容在 wav 资源里，不经过 ARB，product/control 层不引用 `AppLocalizations`。

唯一交集：`app_zh.arb` / `app_en.arb` 的 `exerciseSummary` 分别描述中文/英文播报；新增语言时需同步对应 ARB 文案。

## 后续演进

- [x] `VoicePromptPlayer` 加 `baseDir` 参数，支持运行时切换资源目录
- [x] `WorkoutController` 注入语言对应目录，App 显式/系统语言在下次进入训练页时生效
- [x] `pubspec.yaml` 注册 `voices/` 目录
- [x] player 单元测试覆盖默认/英文播放路径与预加载路径
- [x] 预留姿势中断播放接口与中英文 UI 文案；缺失音频时安全静音
- [x] 补录 `pose_lost.wav`（中英文，2026-07-23）
- [x] 新增 `too_close` / `narrow_form` 纠错型提示（中英文音频 + player 接口 + controller 调用 + 节流，2026-07-23）
- [x] 纠错型提示 3 秒节流，防 narrowForm/tooClose 状态乒乓打断；生命周期型与 count 不节流
- [ ] 设置页增加多音色主题选择（语言继续复用 App 语言设置）

完成证据见 [`completion-pose-lost-audio.md`](../completion-pose-lost-audio.md) 与 [`completion-pose-feedback-audio.md`](../completion-pose-feedback-audio.md)。两份文件是历史完成记录，不是待执行 TODO；当前素材与扩展规范仍以本文为准。
