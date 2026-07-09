# ugk-post

Android 俯卧撑计数 App（Flutter）。手机固定正前方 → 相机实时姿态识别（MoveNet TFLite）→ 俯卧撑计数 → 中文语音播报 → 本地记录日历。

端侧推理，视频帧不上传。

## 快速开始

```bash
flutter pub get
flutter analyze          # No issues found
flutter test             # 89 tests passed（含回放基线 5/5/3）
flutter build apk --release --split-per-abi
```

> 测试夹具在 `test/fixtures/`（脱敏标量信号，已纳入 git），干净 checkout 可直接复现绿测。

## 架构

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               产品规则（计数管线/门控/存储/语音）
control/               编排（WorkoutController）
ui/pages/              纯展示
inference/ pipeline/ platform/   基础设施（推理/帧处理/相机）
```

依赖只向上指。详见 [AGENTS.md](AGENTS.md) 和 [docs/](docs/)。

## 识别算法

核心原则：**双手腕是稳定锚点（不动），头+肩是动作（下压回升），肘角变化是确认。**

- 动作信号 = `torsoY`（头肩平均），不用手腕（手腕只做门控）
- 双门控：`handsSupported`（腕在肩下方）+ `handsStable`（腕在基线附近）
- 计数器：峰谷检测 + 自适应阈值 + 肘角确认

详见 [docs/modules/recognition.md](docs/modules/recognition.md)。

## 文档

开发准则、架构分析、模块说明都在 [docs/](docs/)。接手先读 [AGENTS.md](AGENTS.md)。

## 复现离线验证（可选）

离线回放（测试模式）需要一段俯卧撑视频。因含真实人脸，视频不入仓库：

1. 录制一段俯卧撑视频，放仓库根目录命名 `俯卧撑.mp4`
2. 在 App 测试模式 → 离线回放 → 选择视频

> ⚠️ 模型权重（`*.tflite`）已打包在 `assets/models/`，无需额外下载。

## 约束

单人 · 手机固定正前方 · 标准宽距俯卧撑 · 光线充足 · 仅判断完整上下循环计数。
