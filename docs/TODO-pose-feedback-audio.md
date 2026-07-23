# TODO: 补录 too_close / narrow_form 音频素材

> 创建日期：2026-07-23（分支 `feat/audio-production-2026-07-23` 时建立）
> 关联代码：`lib/product/voice_prompt_player.dart` `playTooClose()` / `playNarrowForm()`
> 关联控制器：`lib/control/workout_controller.dart`（`tooClose` 与 `narrowForm` 状态切换）
> 关联状态先例：与 `docs/TODO-pose-lost-audio.md` 同属「代码接口已就绪、音频待补录」类别

## 背景

`pose_lost.wav` 是项目里第一个「接口先行、音频后补」的提示语。本次为 `tooClose`（距离过近）和 `narrowForm`（窄距俯卧撑姿势不达标）两个已存在的 `WorkoutStatus` 补上同款语音骨架：此前它们只有屏幕文字提示（`workoutStatusTooClose` / `workoutStatusNarrowForm`），没有任何语音播报。

## 状态

- ✅ **已完成**（2026-07-23 中英文音频均已补录）
- ✅ 代码接口已就绪（`playTooClose()` / `playNarrowForm()` + `catchError` 容错）
- ✅ 控制器已接调用（每次进入 `tooClose` / `narrowForm` 状态各播一次，复用既有 leading-edge 守卫）
- ✅ 缺失时安全静音（不影响训练）
- ✅ player / controller / assets 测试已锁定
- ✅ `voice_meta.json` 的 `too_close` / `narrow_form` 已置 `true`

## 文案真源（语音版与 UI 版分离）

⚠️ **注意：这两个提示的语音播报文案与 ARB 屏幕显示文案是两套，语音版更简短口语化。** 这是有意为之——训练中用户来不及听长句，语音用短句；屏幕显示用完整指引句。

| 提示 | 文件名 | 中文语音文案（实际录制） | 英文语音文案（实际录制） | 中文 UI 文案（`app_zh.arb`，仅供参考） |
|---|---|---|---|---|
| 距离过近 | `too_close.wav` | 距离过近，请退后一点点 | You're too close. Step back so your whole body stays in frame. | 距离过近，请退后一点保持完整入镜 |
| 窄距姿势 | `narrow_form.wav` | 收拢双臂，手腕再靠近一点 | Bring your arms in and keep both wrists no wider than your shoulders. | 收拢双臂，保持两侧手腕不比肩膀更向外 |

英文沿用现有英文素材的生成约定（Qwen3-TTS Vivian, 1.15x 烘焙, PCM16/mono/24kHz）。中文为用户配音（MP3→WAV 转码）。

## 已落盘文件（中英齐全）

| 路径 | 语言 | 文案 |
|---|---|---|
| `assets/audio/prompts/too_close.wav` | 中文（默认播放） | 距离过近，请退后一点点 |
| `assets/audio/prompts/narrow_form.wav` | 中文（默认播放） | 收拢双臂，手腕再靠近一点 |
| `assets/audio/voices/manbo/zh/too_close.wav` | 中文（源归档，与 prompts/ 一致） | 同上 |
| `assets/audio/voices/manbo/zh/narrow_form.wav` | 中文（源归档，与 prompts/ 一致） | 同上 |
| `assets/audio/voices/manbo/en/too_close.wav` | 英文 | You're too close. Step back so your whole body stays in frame. |
| `assets/audio/voices/manbo/en/narrow_form.wav` | 英文 | Bring your arms in and keep both wrists no wider than your shoulders. |

## 音频规格（参考 `docs/modules/voice-themes.md`）

- 采样率：24000 Hz
- 声道：单声道（1）
- 格式：PCM_16 WAV
- 中文：曼波音色（用户配音），播放 1.0x
- 英文：Vivian 标准女声（Qwen3-TTS），素材烘焙 1.15x、播放 1.0x（与现有英文 guide/ready 一致；英文 count 素材原速、播放 1.2x，不在本提示范围）

## 触发逻辑

```dart
// lib/control/workout_controller.dart
// tooClose：进入 tooClose 状态的 leading-edge（_tooClose 由 false→true 时触发一次）
if (!_tooClose) {
  _tooClose = true;
  // ...
  _traceEvent('ready_too_close', { ... });
  unawaited(_voice.playTooClose());  // ← 这里播放
}

// narrowForm：进入 narrowForm 状态的 leading-edge（且不在 reacquiringPose 时触发一次）
if (!_reacquiringPose && _status != WorkoutStatus.narrowForm) {
  _traceEvent('narrow_form_not_ready', { ... });
  unawaited(_voice.playNarrowForm());  // ← 这里播放
}
```

两个调用都复用了状态切换既有的 leading-edge 守卫，因此：
- 用户停在 tooClose / narrowForm 时**不会每帧重复播报**（latch / 状态比对守卫）。
- 退出后再次进入会**重新播一次**（`_tooClose` 在退到安全距离 / start / switchCamera 时重置；narrowForm 在状态离开后再次 mismatch 时重触发）。
- `narrowForm` 语音在 `reacquiringPose`（姿态丢失重获）期间被抑制，避免覆盖 `pose_lost` 语音。

## 完成记录（2026-07-23）

- ✅ 音频落盘（中英文 6 个文件，见上表）
- ✅ `voice_meta.json` 的 `too_close` / `narrow_form` 置 `true`，`updated` 改为 2026-07-23
- ✅ `test/voice_prompt_assets_test.dart`：英文整集断言加入 `pose_lost.wav` / `too_close.wav` / `narrow_form.wav`；meta 断言改 `isTrue`
- ✅ 门禁：`flutter analyze` 0 issue，`flutter test` 全绿（含 voice_prompt_assets_test / voice_prompt_player_test / architecture_contract_test / domain_self_check 回放基线）

## 待真机验收

- tooClose：近距离摆放触发「距离过近」状态，确认听到一次语音；退后再靠近确认能再播。
- narrowForm：窄距俯卧撑场景手臂外展，确认听到一次语音；纠正后再次失败确认能再播。
- 确认不影响后续 ready / 计数 / pose_lost 语音（最新事件优先）。
