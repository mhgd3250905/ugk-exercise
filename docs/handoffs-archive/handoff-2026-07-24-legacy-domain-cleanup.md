# 交接：refactor/legacy-domain-cleanup-2026-07-24 旧 domain 路径清理（L1+T1）

> 日期：2026-07-24
> 工作树：`D:/Git/AII/ugk-post-legacy-domain-cleanup-2026-07-24`
> 分支：`refactor/legacy-domain-cleanup-2026-07-24`（基于 `main@5f20e0d`）
> 本机 Flutter：`3.44.7`
> 派发者：main reviewer
> 任务来源：`docs/reviews/2026-07-24-staleness-audit-full-report.md` §4 L1 + §5 T1

## ⚠️ 这是高风险清理（碰算法地基 pushup_domain.dart）

删除重构前算法的惰性残留。**必须极其谨慎**——`pushup_domain.dart` 是纯 dart 地基，碰它要保回放基线 5/5/3。

## 你的任务（L1 + T1 必须同一提交）

删除已退出生产管线的旧 `SignalFilter + pressDepthY + elbowLateral` 路径，及唯一守护它的测试。

**先读任务来源**：报告 §4 L1（位置+证据）+ §5 T1（对应测试）。

### 要删的（报告 L1 核实：生产无读取方）

| 位置 | 内容 | 为何可删 |
|---|---|---|
| `lib/pushup_domain.dart:46` | `pressDepthY` 字段（`FrameSignals`） | 生产无读取方（`wrist_anchor.dart:11` 仅注释引用） |
| `lib/pushup_domain.dart:172/213/317` | `SignalFilter` 类 + shoulder/pressDepth/torso 移动平均 | 生产无实例化，唯一实例在测试 |
| `lib/pushup_domain.dart:317` 附近 | extractor 的 `wristY` 双腕平均（生成 pressDepthY 用） | ⚠️ **这是历史 bug 根源**，AGENTS.md 纪律#2 明禁平均双腕 |
| `elbowLateral` | 只在 extractor 赋值 + copyWith 传播 + 1 条测试断言 | 无生产读取方 |

### 要删的测试（报告 T1）

| 位置 | 内容 |
|---|---|
| `test/domain_self_check_test.dart:155-163` | `SignalFilter smooths jitter and holds through NaN`（唯一实例化 SignalFilter 的测试） |

### 必须保留的（报告明确标保留）

- ✅ `shoulderY` / `headY`（仍被诊断日志使用）
- ✅ `domain_self_check_test.dart` 其余 25 条 + 5/5/3 fixture 回放
- ✅ `PushupPipeline` 的单次中值滤波（这是当前生产的平滑路径）

## 关键纪律（碰 domain，最高约束）

1. **`pushup_domain.dart` 保持纯 dart**：删除后该文件不得有任何 `package:flutter`/`dart:io` import（AGENTS.md 纪律#1）。
2. **不平均双腕坐标**：删 `wristY` 平均是**强化**这条纪律（AGENTS.md 纪律#2），别引入新的平均。
3. **L1 + T1 同一提交**：不能先删代码留无契约旧类，也不能先删测试留无测试的旧类。
4. **回放基线 5/5/3 是硬约束**：删完必须 `flutter test test/domain_self_check_test.dart` 全绿（step0=5/v3=5/v4=3）。
5. **同步清理引用**：删 `pressDepthY` 后，搜全仓所有 `pressDepthY`/`elbowLateral`/`SignalFilter`/`wristY`（domain 内）引用，确保无残留编译错误。
6. **不动生产管线**：`PushupPipeline`/`PushupCounter`/`WorkoutController` 的当前路径不动，只删惰性残留。

## 完成后验证（必须全过）

```bash
cd D:/Git/AII/ugk-post-legacy-domain-cleanup-2026-07-24
flutter analyze                                        # 0 issue
flutter test                                           # 全绿（应仍 ~744，少 1 条 SignalFilter 测试）
flutter test test/domain_self_check_test.dart          # 回放硬基线 5/5/3 ⚠️ 必须全绿
git diff --check
grep -rn "SignalFilter\|pressDepthY\|elbowLateral" lib/  # 确认无残留（除注释）
```

⚠️ 若 5/5/3 回归，**立即停止**——说明删多了或删错了，回退重来。回放基线是硬约束，不能为通过而改 fixture。

提交后等 main reviewer 审核（会重点查 5/5/3 + domain 纯 dart）。

## 建议开场白

```
已读完交接。我在 refactor/legacy-domain-cleanup-2026-07-24，基于 main@5f20e0d。
任务：删旧 SignalFilter/pressDepthY/elbowLateral + 对应测试（L1+T1 同提交）。
我理解这是碰算法地基的高风险清理，会严守 5/5/3 回放基线和 domain 纯 dart 纪律。
```
