# 合并审核报告：feat/algo-opt-2026-07

> 目标分支：`main`
>
> 审核分支：`feat/algo-opt-2026-07`
>
> 审核基线：`origin/main @ cbcb0a5`
>
> 实现提交：`0bbe930 feat(recognition): improve counting and add diagnostic export`
>
> 日期：2026-07-18

## 1. 结论摘要

本分支解决两类真机识别问题，并保留可供商店版本排障的本地诊断能力：

1. 小尺度人物使用准备态画面尺度计算最低下压摆幅，不再完全受固定 80px 地板限制；
2. 快速动作时允许鼻或单侧肩膀置信度轻微降至 0.25，同时继续要求双肩平均置信度达到 0.30；
3. 运动测试日志改为 Release 可主动开启、默认关闭、本地留存并由用户手动导出；
4. 设置页明确展示日志开关的开启/关闭状态。

分支已 rebase 到最新 `main`，main 的新页面转场与排行榜交互均保留。自动化、硬回放、独立审查和三组真机快速动作复验均通过。建议 main 侧按第 8 节重点复核后合并。

## 2. 改动边界

### 2.1 识别算法

- `PushupPipeline` 在完成 ready 标定后使用：

  ```text
  max(50px, min(80px, 50% × readyGroundSpan))
  ```

  作为本次会话的最低摆幅地板。
- 未经过 ready 标定的历史 CSV 回放仍使用 80px，不改变既有基线定义。
- `motionPoseUsable` 调整为：
  - 鼻、左肩、右肩分别 `>= 0.25`；
  - 双肩平均 `>= 0.30`；
  - 高置信可见手腕抬到肩上方仍按 `0.30` 作为反证。
- 没有重新引入腕坐标平均、腕漂移硬门控或肘部必须可见规则。

算法依据、真机证据和回滚索引见：

- `docs/modules/recognition.md`
- `docs/pushup-algorithm-remediation-2026-07-14.md`
- `docs/modules/pushup-pipeline.md`

### 2.2 运动测试日志与导出

- 所有构建类型均可使用，但默认关闭，只有用户主动开启后才从下一次训练开始记录。
- 只保存姿态关键点、置信度、门控、计数状态和性能指标；不保存照片、视频或音频。
- 日志只写 App 私有目录，不自动上传。
- 活跃会话先写 `.jsonl.part`，正常关闭后原子改名为 `.jsonl`；导出只读取完整文件。
- 默认保留最近 20 次训练，并设置三层容量限制：
  - 单会话 12 MiB；
  - 本地日志总量 24 MiB；
  - 单次导出 25 MiB。
- 导出文件为 JSONL，包含 manifest 和会话边界，通过 Android 系统保存界面由用户选择位置。
- 设置写入串行化；失败时回滚可见开关状态，不允许“界面显示关闭、重启后仍采集”。

设计与实施细节见：

- `docs/plans/2026-07-18-release-recognition-trace-export-design.md`
- `docs/plans/2026-07-18-release-recognition-trace-export.md`
- `docs/testing-release-playbook.md`

### 2.3 UI 与 main 对齐

- 设置页日志开关增加“已开启/已关闭”状态徽标、明确轨道/滑块颜色、边框和勾/叉图标。
- 保留 main 新增的 `pushWithoutShadow` 页面转场。
- 首页进入训练页时，在 main 的新转场调用中继续传递本次会话的日志开关快照。

## 3. 第一性原则与阈值依据

### 3.1 小尺度人物

准备态已经获得头肩到腕部地面线的屏幕高度 `readyGroundSpan`。人物在画面中变小时，真实动作的像素位移会同比减小，因此最低正式下压应随本次画面尺度变化。

50px 是已观察 MoveNet 噪声摆幅的保守下限；80px 保留为未标定回放和大尺度会话的历史地板。测试同时覆盖：

- 小尺度人物达到 60% ready-relative 深度：计数；
- 只达到 45%：不计；
- 极小尺度下约 25px 往返抖动：不计。

### 3.2 快速动作

首轮三次真机日志中，旧门控回放为 5/8/10。第二、三组漏计空档主要出现鼻或单肩置信度短暂跌破 0.30；进入 counter 的完整 `down → up` 均成功计数，因此根因在 counter 之前的逐点 0.30 AND 门控。

离线使用生产代码回放同一批日志得到 5/9/12，第一组不增计。新增测试锁定 0.25 与 0.30 的包含边界，并继续拒绝明显核心点丢失和高置信抬腕。

修正包覆盖安装后的三组新真机训练均计为 10，最快相邻计数约 0.73 秒，没有漏计、误计或隐藏第 11 个完整循环候选。

## 4. 隐私与安全检查

- 仓库没有加入任何真实 JSONL、视频、照片、CSV、设备标识或生产配置。
- 导出必须由用户主动操作，不存在后台上传或远程端点。
- 原始关键点日志可能还原人体姿态，因此仍视为私密诊断数据；只允许私下分析，不得提交到 Git 或公开 Issue。
- `pushup_domain.dart` 保持纯 Dart，未增加 Flutter/platform 依赖。
- domain/product 没有平均左右手腕坐标。
- WorkoutController 的异步 session 守卫没有被删除或绕过。

## 5. 验证结果

### 5.1 rebase 后最终自动化

- `flutter analyze`：0 issue。
- `flutter test`：467 项全部通过。
- 硬回放：step0=5、v3=5、v4=3。
- 首页与个人页聚焦 Widget 测试：80 项通过。
- `git diff --check main...HEAD`：通过。
- 分支关系：`origin/main...HEAD = 0 / 1`（实现提交时）。

### 5.2 独立审查

实现完成后启动独立只读审查线程，从需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果六个方面复核。首轮提出三个 P2（阈值参数语义、精确边界测试、Release 文档措辞），主线程修复后复验通过。

最终清单：

- P0：无
- P1：无
- P2：无

### 5.3 真机验证

- 使用带本机构建配置的 Debug APK 覆盖安装，未卸载、未清数据。
- 冷启动成功，无 Flutter/FATAL 启动异常。
- 日志开关、三次完整日志留存和电脑侧只读分析链路已验证。
- 快速动作修正后三组新训练均计为 10；最快约 0.73 秒一次。

## 6. 主要审核入口

| 领域 | 文件 | 建议审核点 |
|---|---|---|
| 计数地基 | `lib/pushup_domain.dart` | 标定摆幅地板下限、历史回放默认值是否保持 |
| 管线装配 | `lib/product/pushup_pipeline.dart` | readyGroundSpan 是否只影响标定会话；双腕是否仍分别处理 |
| 运动态门控 | `lib/product/motion_pose_gate.dart` | 0.25 单点地板、0.30 双肩平均和抬腕反证边界 |
| 日志写入 | `lib/platform/recognition_trace_log.dart` | `.part` 原子完成、12/24 MiB、最近 20 次、故障隔离 |
| 日志导出 | `lib/platform/recognition_trace_export.dart` | 完整 JSONL 校验、25 MiB 预检、取消/失败语义 |
| 设置状态 | `lib/ui/app_settings.dart`、`lib/platform/app_settings_store.dart` | 串行持久化和失败回滚 |
| UI | `lib/ui/pages/profile_page.dart`、`lib/ui/pages/home_page.dart` | 关闭态可见性、main 新转场与日志快照共存 |
| 会话接线 | `lib/ui/pages/workout_page.dart` | 每次训练按开关快照创建日志实例 |

关键测试：

- `test/pushup_pipeline_test.dart`
- `test/pushup_session_replay_test.dart`
- `test/recognition_trace_log_test.dart`
- `test/recognition_trace_export_test.dart`
- `test/app_settings_test.dart`
- `test/profile_page_test.dart`
- `test/home_page_test.dart`
- `test/domain_self_check_test.dart`

## 7. 已知边界与未包含事项

- 小朋友本人已离场，尚未完成儿童真实动作复验；当前依据是 ready-relative 原理、合成正负例和成人不同节奏真机数据。
- 当前安装和真机验证是 Debug 包，不等同于 Google Play Release/Alpha 验收。
- 本 worktree 缺少受保护的 Release 签名配置，因此本分支没有生成或上传商店 AAB。
- 单目 2D 姿态无法证明手掌真实接触地面；准备态几何条件仍是替代判断。
- 日志模块不解决 MoveNet 完全看不到人体的情况；连续丢失核心点仍会按既有规则退出 ready。
- 本分支没有部署 Worker、修改 D1、改动 OAuth/RevenueCat/Google Play 配置，也没有执行远端平台写入。

## 8. main 侧审核清单

- [ ] 核对 `main...feat/algo-opt-2026-07` 只包含本报告列出的算法、日志、设置、UI 和测试改动。
- [ ] 重点审查 0.25/0.30 门控是否符合“运动态宽容、准备态严格”的原则。
- [ ] 核对小尺度摆幅地板仍有 50px 噪声下限，未影响未标定 5/5/3 回放。
- [ ] 核对 Release 日志默认关闭、无自动上传、仅导出完整会话。
- [ ] 复跑 `flutter analyze`、`flutter test`、`git diff --check`。
- [ ] 如准备进入商店测试，再单独按发布手册完成签名 Release/Alpha 真机验收。

## 9. 合并与回滚

审核通过后，从 `main` 合并 `feat/algo-opt-2026-07`。若 `main` 在审核期间继续前进，应先重新对齐并复跑全量门禁。

算法、日志与 UI 实现集中在提交 `0bbe930`。如合并后需要整体回滚，可 revert 该实现提交；真实诊断日志未进入 Git，不需要仓库侧数据清理。
