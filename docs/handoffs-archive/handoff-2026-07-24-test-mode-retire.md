# 交接：refactor/test-mode-retire-2026-07-24 测试模式工具链退休（L2+T2+ffmpeg）

> 日期：2026-07-24
> 工作树：`D:/Git/AII/ugk-post-test-mode-retire-2026-07-24`
> 分支：`refactor/test-mode-retire-2026-07-24`（基于 `main@5f20e0d`）
> 本机 Flutter：`3.44.7`
> 派发者：main reviewer
> 任务来源：`docs/reviews/2026-07-24-staleness-audit-full-report.md` §4 L2 + §5 T2

## 你的任务（用户已决策：退休整套测试模式工具链）

用户已决定**退休**早期离线视频回放/性能诊断的测试模式工具链（当前从 App 入口已不可达）。删除这整套不可达的开发工具 + 对应测试 + FFmpeg 依赖。

**先读任务来源**：报告 §4 L2（11 个不可达文件清单+证据）+ §5 T2（对应测试）。

### 要删的 11 个 lib 文件（报告 L2 核实：生产不可达，互引）

```
lib/ui/pages/test_mode_page.dart
lib/control/replay_control.dart
lib/inference/keypoint_log.dart
lib/perf/performance_meter.dart
lib/platform/ffmpeg_kit_runner.dart
lib/platform/replay_utils.dart
lib/platform/report_directory.dart
lib/platform/video_replay_service.dart
lib/report/performance_report.dart
lib/ui/overlay_renderer.dart
lib/ui/perf_panel.dart
```
- 生产代码只有它们互相引用，`main.dart` 无 import。
- `ffmpeg_kit_flutter_new` 依赖的唯一 lib import 在 `ffmpeg_kit_runner.dart`，删文件后可从 `pubspec.yaml` 移除该依赖。

### 要删的测试（报告 T2）

```
test/replay_control_test.dart
test/keypoint_log_test.dart
test/performance_meter_test.dart
test/performance_report_test.dart
test/report_directory_test.dart
test/video_replay_service_test.dart
```
+ `test/architecture_contract_test.dart` 中**针对 test_mode_page/replay_utils 的断言**（只删相关断言，**不能删整个 architecture_contract_test.dart**——它还守护其他契约）。

### ⚠️ 必须保留的（报告明确标保留，删错会坏 CLI）

- ✅ `lib/report/golden_frame_report.dart` —— **活跃 CLI**，`tool/golden_frame_report.dart` import 它
- ✅ `test/golden_frame_report_test.dart` + `test/golden_frame_tool_test.dart` —— golden_frame CLI 测试
- ✅ `tool/golden_frame_report.dart` —— CLI wrapper

## 关键纪律

1. **L2 + T2 + ffmpeg 同批清理**（报告要求同一批次）。
2. **golden_frame 绝不能删**：它虽在 App import 图不可达，但 `tool/` 活跃调用——删了会坏 CLI。
3. **architecture_contract_test.dart 只删相关断言**：该文件还守护 ChangeNotifier/ARB/层级等大量契约，不能整删。删 test_mode 相关断言后确保其余仍通过。
4. **删 ffmpeg 依赖前确认无其他引用**：`grep -rn ffmpeg lib/ tool/` 确认只剩要删的文件用。
5. **README 同步**：`README.md:49/54` 的"App 测试模式"步骤（报告 D5）需一并改为可执行步骤或删除（注：D5 文档修复在另一分支 docs/doc-truth-fix，但本分支删了功能后 README 引用会彻底失效，建议本分支至少把 README 那段改为"已移除"或链接到 fixture 回放命令，避免指向不存在的功能）。
6. **不用 `git add -A`**：显式 stage 删除的文件（`git rm`）+ 改动的文件。

## 完成后验证（必须全过）

```bash
cd D:/Git/AII/ugk-post-test-mode-retire-2026-07-24
flutter analyze                                        # 0 issue（删引用后无悬空 import）
flutter test                                           # 全绿（golden_frame 测试必须仍过）
flutter test test/domain_self_check_test.dart          # 回放 5/5/3 不受影响
flutter test test/architecture_contract_test.dart      # 契约测试删断言后仍全绿
flutter test test/golden_frame_report_test.dart test/golden_frame_tool_test.dart  # CLI 测试仍过
grep -rn "test_mode_page\|replay_control\|ffmpeg" lib/ # 确认 lib 无残留（golden_frame_report 除外）
git diff --check
```

⚠️ 若 golden_frame 测试失败，说明误删了 `golden_frame_report.dart`——立即恢复。

提交后等 main reviewer 审核。

## 建议开场白

```
已读完交接。我在 refactor/test-mode-retire-2026-07-24，基于 main@5f20e0d。
任务：退休测试模式工具链（11 lib 文件 + 6 测试 + ffmpeg 依赖 + 契约断言），用户已决策退休。
我会严守 golden_frame 不可删、architecture_contract_test 只删相关断言。
```
