# 分支审核报告：codex/home-card-compact

> 目标分支：`main`
>
> 审核分支：`codex/home-card-compact`
>
> 对齐基线：`origin/main @ 465f0c7`
>
> 主线对齐提交：`532d9db`
>
> 独立审查修复提交：`6039a92`
>
> 日期：2026-07-19

## 1. 结论

本分支已合入最新 `origin/main` 的英文语音本地化，并完成一次独立只读六维审查、主线程 TDD 修复和同一审查线程复验。最终结论：

- P0：无；
- P1：无；
- P2：无；
- 建议进入 `main` 侧代码审核。

本轮没有 force push、部署 Worker、修改 D1、合并 `main`、上传商店产物或改动远程平台。最终只按用户授权普通推送功能分支。

## 2. 分支范围

### 2.1 双运动类型与首页

- 保留标准俯卧撑和窄距俯卧撑两条独立路由、存储类型、今日分类统计和窄距形态门控。
- 首页两张卡只显示难度、标题、当日分类计数和开始训练行动区，不显示重复的 AI 能力说明与“今日已完成”摘要。
- 标准卡与窄距卡在浅色模式使用不同低饱和色阶，在深色模式分别使用森林绿和深青层次。
- 首页今日记录入口、运动广场入口、整卡点击、中文/英文、小屏与安全区行为保持。

### 2.2 运动广场积分与本人明细

- 指标固定为 `pushup_points_v1`：标准俯卧撑每次 1 分，窄距俯卧撑每次 2 分。
- 日榜和周榜使用同一聚合公式；历史分类型训练记录可直接回算，不新增积分表或 D1 migration。
- 本人卡可选显示“标准 N 次 · 窄距 M 次”；分类次数只在响应根级返回给当前用户，其他公开榜单行不携带该明细。
- 旧 App 的次数请求、旧 v1 游标、分页、加入/退出、会员冻结、屏蔽后全局名次和审核链路保持兼容。

### 2.3 UI 色阶统一

- 首页：今日记录入口、两张训练卡、运动广场入口。
- 训练记录：云端状态与底部周期统计。
- 运动广场：日/周选择、计分规则、前三/普通榜单行、空态/错误/加入/冻结/身份面板、本人卡。
- 个人信息：账号 Hero、VIP、会员状态和固定登录/退出入口。
- 浅色层级由暖白、鼠尾草绿、薄荷青色阶与柔影建立；深色榜单移除厚彩色外框，只保留小面积排名语义色。

### 2.4 最新 main 集成

`origin/main` 在本分支开发期间新增英文语音资产与语言选择。为避免改写已存在的远端分支历史，本分支使用普通 merge 对齐：

- 标准与窄距两条首页路由都向 `WorkoutPage` 传入同一个 `AppSettingsController`；
- `WorkoutPage` 同时保留 `ExerciseType` 和语言对应语音目录；
- 窄距门控、保存类型和英文语音选择在同一控制器创建路径共存；
- 合并冲突后的首页、训练页、控制器和语音相关聚焦测试为 89/89。

## 3. 独立审查闭环

独立线程严格只读，审查 `origin/main...HEAD` 的完整分支差异，从需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖和实际运行结果六个方面验证。

### 3.1 首轮发现

1. P2：`_JoinedNoRankPanel` 在浅色模式仍固定使用深色 `ink` 卡面，计划要求的防御状态主题合同未完成。
2. P2：`WorkoutPage` 只用 `assert` 检查注入 Controller 与页面请求运动类型是否一致；Release 会移除该守卫。

### 3.2 TDD 修复

- 先扩展 joined-no-rank Widget 测试，旧实现因浅色渐变为空而失败；随后实现浅色本人色阶、柔影和深色文字/绿色动作色，深色卡面保持原森林锚点。
- 先把类型错配测试改为期望运行时 `ArgumentError`，旧实现实际抛 `AssertionError`；随后将构造守卫改为所有构建模式都生效的运行时检查。
- 两条聚焦测试转绿；`leaderboard_page_test.dart + workout_page_test.dart` 为 59/59。

### 3.3 复验结论

同一独立审查线程在 `6039a92` 上复验通过，确认两项 P2 均关闭，未发现新的 P0/P1/P2。

## 4. 最终验证

以下结果均在主线对齐和审查修复之后重新运行：

| 验证 | 结果 |
|---|---|
| `flutter analyze` | 0 issue |
| `flutter test` | 530/530 |
| 回放筛选测试 | 3/3；step0=5、v3=5、v4=3 |
| `workers/membership-api npm test` | 142/142，含 TypeScript check/build:test |
| `git diff --check origin/main...HEAD` | 通过 |
| 独立审查 | PASS，无 P0/P1/P2 |

独立审查线程也分别复现了相同的 Flutter、Worker、回放和差异检查结果。

## 5. 边界与未执行事项

- 本次集成审核没有重新安装当前最终 HEAD。UI 视觉版本在对齐 main 前已由用户通过真机截图验收；当前 HEAD 的自动化覆盖了合并后的语言、路由、主题、小屏、安全区和交互合同，但不把历史真机结果冒充为本轮新运行。
- 本次没有改识别阈值、计数公式以外的算法行为、会员授权逻辑或云同步权限。
- 本次没有执行 D1 migration、Worker 部署、Cloudflare/RevenueCat/Google Play 写入或生产探针。
- 真实视频、CSV、诊断日志、构建配置、设备标识和用户数据均未进入 Git。

## 6. main 侧审核入口

建议从以下文件和合同开始：

| 领域 | 主要文件 | 审核重点 |
|---|---|---|
| 窄距门控 | `lib/product/narrow_pushup_form_gate.dart`、`lib/control/workout_controller.dart` | 仅窄距启用；标准默认 allow；session 守卫保留 |
| 类型存储 | `lib/product/exercise_type.dart`、`lib/product/workout_session_store.dart` | 两种类型持久化与按类型统计 |
| 积分合同 | `workers/membership-api/src/leaderboard.ts`、`lib/product/leaderboard_models.dart` | ×1/×2 日周一致、旧请求/游标兼容、本人明细隐私 |
| 首页 | `lib/ui/pages/home_page.dart`、`test/home_page_test.dart` | 双卡路由、今日分类计数、浅深色和整卡点击 |
| 运动广场 | `lib/ui/pages/leaderboard_page.dart`、`test/leaderboard_page_test.dart` | 所有状态卡主题、本人明细、分页/会员/审核行为 |
| 记录与个人页 | `lib/ui/pages/records_page.dart`、`lib/ui/pages/profile_page.dart` | 色阶美化不改变统计、同步和账号行为 |
| main 集成 | `lib/ui/pages/workout_page.dart`、`test/workout_page_test.dart` | 语言语音与 ExerciseType 共存、Release 类型错配守卫 |

main 审核建议复跑：

```powershell
flutter analyze
flutter test
cd workers/membership-api
npm test
git diff --check origin/main...origin/codex/home-card-compact
```

若 `main` 在审核期间继续前进，应先重新对齐功能分支，再复跑以上门禁。审核通过后由 `main` 侧决定合并；本分支不自行合并或部署。
