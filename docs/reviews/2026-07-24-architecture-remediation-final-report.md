# 架构整改最终报告（2026-07-24）

## 1. 结论

本轮以 `main@ca1bb464f55e502f5a465bef9eb95bcd118d1cfd` 为固定基线，在独立分支
`fix/architecture-remediation-2026-07-24` 完成原审查确认的 8 项整改（0 P0 / 3 P1 /
5 P2）。最终代码候选为 `19cb78737e383b2b0c54951db8ae18f09bca739d`；
本报告是其后的纯文档提交，不作为代码候选 SHA。

独立只读审查经过两轮“发现问题 → 主线程修复 → 原审查线程复验”后给出：

> **PASS：六维审查通过，无修复清单。**

项目原有的 domain、计数管线、Worker 会员权威入口和 D1 migration 设计继续保持；
本轮主要收口了 App/Worker 同步合同、账号状态收敛、product/platform 依赖边界、
本地历史数据保全和排行榜查询的内存边界。未生成、安装或上传 APK/AAB，未执行部署、
D1/平台写入、push 或其他远程操作。

## 2. 问题与整改结果

| 原问题 | 最终状态 | 核心整改 |
|---|---|---|
| P1-01 被动账号刷新吞掉 401 | 已关闭 | 当前账号 401 清内存与安全存储；generation/account 守卫防止旧请求误清新账号；会员到期定时复核路径同样收敛 |
| P1-02 丢弃逐条 `rejected.reason` | 已关闭 | 端到端保留 reason；拆分 `rejected`、`blockedOnPremium`、可重试和 `protocolError`；零次保持 `localOnly`，缺元数据终止普通重试 |
| P1-03 App 无界批量与 Worker 200 上限不一致 | 已关闭 | 按最多 200 条分块排空；块间重验账号、Premium 和 generation；部分完成只写回仍属于该账号的结果 |
| P2-04 product 层包含文件 I/O 与音频插件 | 已关闭 | product 只保留模型、规则、`WorkoutSessionRepository` 和 `VoicePromptPort`；文件与 `audioplayers` 实现迁至 platform 并由 control 注入 |
| P2-05 排行榜分页仍把全榜加载到 Worker | 已关闭 | D1 window rank + keyset 条件 + `LIMIT 21`；屏蔽在 SQL 页查询中过滤且不重排名次；本人名次独立单行查询 |
| P2-06 源码字符串/顺序架构测试脆弱 | 已关闭 | 删除依赖私有方法名和精确 await 顺序的脆弱断言；生命周期由受控 fake 行为测试负责；分层 import 使用 analyzer AST 守护 |
| P2-07 recognition 权威阈值仍写 1.25 | 已关闭 | 权威识别文档与生产代码/边界测试统一为包含边界 1.5 |
| P2-08 损坏训练历史可能被覆盖或抛异常 | 已关闭 | 区分损坏类型、逐项恢复、保留原始 `.bak`；备份先写唯一临时位置、逐字节验证后原子 rename；任何备份失败或残缺同名备份都会阻止 mutation |

## 3. 架构边界现状

### 3.1 Flutter App

- `pushup_domain.dart` 仍为纯 Dart 算法地基。
- `product/` 现在承载纯规则、模型和 port，不再拥有 `dart:io`、Flutter、插件或 platform
  实现。`architecture_layer_test.dart` 使用 analyzer AST 读取 import/export 及所有
  conditional URI，并按导入文件规范化目标路径，防止路径穿越或注释制造假守护。
- `platform/` 承载文件系统、`path_provider` 和音频插件适配器。
- `control/` 负责账号、训练和同步编排；关键异步状态以 generation/account/session
  所有权收敛。
- UI 继续消费 controller 和 product port，不持有第二份账号或同步真源。

### 3.2 App / Worker 合同

- `WorkoutSyncResult.reason` 已成为客户端协议模型的一部分。
- 逐条业务拒绝与请求级网络/5xx 失败不再共享一个模糊状态。
- 客户端请求上限与 Worker `MAX_BATCH_SIZE=200` 对齐。
- Worker 将未来时钟偏差拆为 `future_ended_at`，不再与确定性
  `invalid_duration` 混为同一重试语义。

### 3.3 排行榜

- 榜单页查询最多返回 21 行，self 另作最多 1 行的独立查询；Worker 不再将全榜结果载入内存后排序/切片。
- window rank 为保持精确全局名次仍需在 D1 内对已加入集合计算排名；本轮解决的是
  Worker 结果集、内存和分页合同问题。生产用户量增大后仍应持续观测 D1 rows read、
  CPU 和延迟，必要时再引入物化排名或聚合快照。

### 3.4 本地训练历史

- 缺文件返回空；损坏文件返回受控降级信息。
- 合法列表中的坏元素被隔离，有效元素继续可读。
- mutation 前必须存在与原文件逐字节一致的备份；残缺、冲突或无法创建备份时，
  append、云缓存及状态写入均不得覆盖原始文件。

## 4. 独立审查循环

独立审查任务：`019f9395-8b41-70e1-b9e6-743e305085be`。

1. 首轮审查 `ca1bb46..f264ce1`：
   - 发现 product import 判定会误放行 `dart:io/ui`；
   - 发现 WorkoutController 权威文档仍描述已删除的源码顺序断言；
   - 发现“备份失败不得覆盖”缺少自动化故障测试。
2. 主线程提交 `7a5f2ed` 后复验：
   - 继续发现相对 URI 路径穿越/正则注释分号绕过；
   - 继续发现残缺同名 `.bak` 可能被误判为有效备份。
3. 主线程提交 `19cb787` 后复验：
   - analyzer AST、规范化路径判定、临时备份、逐字节验证和原子 rename 均通过反证；
   - 定向测试 43/43、`flutter analyze` 0 issue、`git diff --check` 通过；
   - 最终结论为 PASS，无剩余修复清单。

审查任务全程保持 detached、干净工作树，未修改、stage、commit、push 或部署。

## 5. 最终验证

| 执行方 / 目标 | 门禁 | 结果 |
|---|---|---|
| 主线程 / `19cb787` | `flutter analyze` | 0 issue |
| 主线程 / `19cb787` | `flutter test` | 743/743（包含 `pushup_session_replay_test.dart`） |
| 主线程 / `f264ce1` | `flutter test test/domain_self_check_test.dart` | 25/25，step0=5 / v3=5 / v4=3 |
| 主线程 / `f264ce1` | `flutter test test/pushup_session_replay_test.dart` | 6/6 |
| 主线程与独立首轮审查 / `f264ce1` | `workers/membership-api npm test` | 171/171 |
| 独立首轮审查 / `f264ce1` | `flutter test`、回放、`flutter analyze` | 737/737、5/5/3、0 issue |
| 独立最终复验 / `19cb787` | 架构/损坏恢复定向测试、`flutter analyze` | 43/43、0 issue |
| 主线程与独立审查 / 各目标 diff | `git diff --check` | clean |

后续 `d7b656c` 及报告修订仅改 Markdown；未据此重复宣称代码门禁。

## 6. 整改代码提交序列

1. `798a23e` `fix: converge account and workout sync state`
2. `ef321af` `refactor: isolate product ports from platform adapters`
3. `237b8d6` `perf: bound leaderboard page queries`
4. `f264ce1` `test: enforce clean architecture boundaries`
5. `7a5f2ed` `test: close architecture review gaps`
6. `19cb787` `test: harden architecture and recovery guards`

## 7. 非阻断后续验证

- 本轮未生成、安装或上传 APK/AAB；候选包构建和真机安装应在进入发布流程后单独执行。
- 真机 camera、TFLite、语音播放和本地文件异常提示仍需候选包验收。
- Google OAuth、RevenueCat、Google Play 和生产 Worker/D1 未在本轮本地只读审查中连接或写入。
- 排行榜应以生产规模继续观测 D1 rows read、CPU、内存和 page1/page2 延迟。
- 本分支尚未合并、push 或部署；进入 main 前应按项目流程再核对目标基线和其他并行分支冲突。
