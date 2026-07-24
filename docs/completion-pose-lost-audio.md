# 完成记录：pose_lost.wav 音频素材

> 创建日期：2026-07-22（合入 PR #8 `4d41b96` 时建立）
> 关联合并：`4d41b96 merge: pose guide recovery and reacquisition state with placeholder guide layer`
> 关联代码：`lib/product/voice_prompt_player.dart` `playPoseLost()`
> 关联审核：`docs/reviews/2026-07-22-workout-pose-guide-recovery-review-report.md`

## 状态

- ✅ **已完成**（2026-07-23 于分支 `feat/audio-production-2026-07-23` 补齐中英文音频）
- ✅ 代码接口已就绪（`playPoseLost()` + `catchError` 容错）
- ✅ 剧本源文件已加文案（`tool/tts/pushup_prompts.srt` 第 33 条）
- ✅ 缺失时安全静音（不影响训练）
- ✅ 契约测试已锁定 SRT + UI + controller（`test/architecture_contract_test.dart`）
- ✅ 中英文音频已补录落盘

## 已补录文件

| 路径 | 语言 | 文案 | 来源 |
|---|---|---|---|
| `assets/audio/prompts/pose_lost.wav` | 中文（默认播放） | 姿势已中断，请按指引重新准备 | 用户配音（MP3→WAV 转码） |
| `assets/audio/voices/manbo/zh/pose_lost.wav` | 中文（源归档） | 同上 | 同上（与 prompts/ 一致） |
| `assets/audio/voices/manbo/en/pose_lost.wav` | 英文 | Pose lost. Match the guide and get ready again. | Qwen3-TTS Vivian, 1.15x 烘焙 |

英文文案取自 `app_en.arb` `workoutStatusReacquiringPose`（本文档此前标注的「待翻译确认」已于 2026-07-23 落定为该 ARB 文案）。

## 音频规格（参考 `docs/modules/voice-themes.md`）

- 采样率：24000 Hz
- 声道：单声道（1）
- 格式：PCM_16 WAV
- 中文：曼波音色，1.0x 速度
- 英文：Vivian 标准女声（Qwen3-TTS），1.0x 速度（guide/ready/pose-lost 不加速；仅数字 count 用 1.2x）

## 已完成的同步动作（2026-07-23）

补录音频时同步完成了以下事项：

1. **更新 `voice_meta.json`**：`assets/audio/voices/manbo/voice_meta.json` 的 `files.pose_lost` 已从 `false` 改为 `true`。

2. **更新测试断言**：`test/voice_prompt_assets_test.dart` 已断言 `files['pose_lost']` 为 `isTrue`。

3. **更新文档状态**：`docs/modules/voice-themes.md` 的 `pose_lost.wav` checklist 已勾选；本文件现作为完成记录保留素材来源和验收证据。

4. **自动化门禁**：完成音频提交时已运行以下命令并记录为通过：
   ```bash
   flutter analyze
   flutter test
   flutter test test/voice_prompt_assets_test.dart
   flutter test test/voice_prompt_player_test.dart
   ```

5. **真机验收边界**：完成记录保留以下独立体验验收步骤，但不把本记录未附证据的真机结果写成已通过：
   - 触发 lost-pose 场景（跑出镜头 15 帧）
   - 确认能听到一次清晰的 pose_lost 语音
   - 确认不影响后续 ready/计数语音

## 触发逻辑（音频补录前已实现，现仍有效）

```dart
// lib/control/workout_controller.dart（合并后约第 423-433 行）
_lostPoseFrames += 1;
if (_lostPoseFrames >= _maxLostPoseFrames) {
  _ready = false;
  _reacquiringPose = true;
  _lostPoseFrames = 0;
  _readyGate.reset();
  _wristAnchor.reset();
  _pipeline.resetTracking(count: _count);  // 保留 _count
  debugPrint('UGK lost-pose: exit ready, keep count=$_count');
  _traceEvent('lost_pose_exit_ready');
  status = WorkoutStatus.reacquiringPose;
  unawaited(_voice.playPoseLost());  // ← 这里播放
}
```

## 历史实施顺序

PR #8 分支作者在 commit `99f89cc` 说明：先合入代码骨架和契约，音频素材作为后续独立任务补录，以避免阻塞 PR。该后续任务已于 2026-07-23 完成；用户要收到新增音频仍需要包含这些资产的新 App 版本，不能仅靠仓库补录生效。

## 完成时风险评估

- **用户感知**：中（姿态丢失场景常见，有语音体验更好；缺失只是静音，不影响功能）
- **技术风险**：低（缺失安全静音，契约测试守护）
- **实际完成时间**：2026-07-23，与 `too_close` / `narrow_form` 语音同批完成

## 备注

音频资产、meta 与测试断言均已完成；后续变更应按 [`modules/voice-themes.md`](modules/voice-themes.md) 的当前规范维护。
