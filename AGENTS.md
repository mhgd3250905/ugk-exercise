# AGENTS.md — 接手必读

> 这个文件是给任何接手本项目的 AI agent / 开发者的**第一入口**。
> 请先读完本文件，再开始任何改动。

## 这是什么项目

ugk-post：Android 俯卧撑计数 App（Flutter）。手机固定正前方 → 相机实时姿态识别（MoveNet TFLite）→ 俯卧撑计数 → 中文语音播报 → 本地记录。

## ⚠️ 开发前必读

**先读 [docs/development-guide.md](docs/development-guide.md)** —— 它告诉你在这个架构里怎么分块开发一个功能、代码放哪、按什么顺序写。

核心一句话：**先判断"心脏"在哪层，从最底层开始写，每层写完立刻测，上层只是薄薄地调用下层。** 依赖只能向上指。

## 架构分层（依赖只向上）

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               产品规则（计数管线/门控/存储/语音），只依赖 domain
control/               编排（WorkoutController 串起 product + 基础设施）
ui/pages/ ui/          纯展示，监听 ChangeNotifier 渲染
inference/ pipeline/ platform/   基础设施（推理/帧处理/相机），依赖 domain
```

## 跑起来 & 验证

```bash
flutter analyze          # 必须无 issue
flutter test             # 必须全绿（89 测试，含回放基线 5/5/3）
flutter build apk --release --split-per-abi
```

- 测试夹具在 `test/fixtures/`（脱敏标量信号，已纳入 git，干净 checkout 可复现）
- 回放基线 **step0=5 / v3=5 / v4=3** 是硬约束，改了信号源必须重验

## 关键纪律（违反会埋坑）

1. **不在 `pushup_domain.dart` 加 Flutter/platform import** —— 破坏纯 dart 地基
2. **不在 domain/product 里平均两个手腕坐标** —— 这是历史 bug 根源（见 `docs/modules/recognition.md`）
3. **WorkoutController 的异步方法保留 session 守卫** —— 每个 await 后校验 `session != _session`
4. **不用 `git add -A`** —— 显式 stage 代码文件，根目录有未跟踪临时文件（截图/apk/step0）
5. **真实视频/csv 不进 git**（含人脸隐私）—— 测试只用 `test/fixtures/` 的脱敏数据

## 真机调试日志

```bash
adb -s <device> logcat -s flutter | grep UGK
```

UGK tag 覆盖：session 生命周期 / ready 标定 / lost-pose / stable 翻转 / count 计数。

## 文档地图

| 文档 | 内容 |
|------|------|
| [docs/development-guide.md](docs/development-guide.md) | **开发准则：怎么分块开发一个功能** |
| [docs/modules/recognition.md](docs/modules/recognition.md) | 识别算法第一性原则、数据流、门控、阈值 |
| [docs/architecture-analysis.md](docs/architecture-analysis.md) | 架构现状 + 债务清单 |
| [docs/architecture-plan.md](docs/architecture-plan.md) | 目标分层 + 重构路线图 |
| [docs/modules/](docs/modules/) | 各模块需求说明（pipeline/anchor/gate/controller） |
| [docs/refactor-report.md](docs/refactor-report.md) | 重构复盘 + 审查记录 |
| docs/archive/ | 历史交接文档（已过时，仅供参考） |

## 版本基线（git tag）

```
v0.4-reproducible       可复现（当前推荐起点）
v0.3-review-fixed       审查修复后
v0.2-refactor-complete  重构完成
v0.1-architecture-baseline  重构前算法稳定版
```

回退：`git checkout v0.4-reproducible`
