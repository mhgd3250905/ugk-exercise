# ugk-post

Android 俯卧撑计数 App（Flutter）。手机固定正前方 → 相机实时姿态识别（MoveNet TFLite）→ 俯卧撑计数 → 中文语音播报 → 本地记录日历。

端侧推理，视频帧不上传。

当前还包括 Google 登录、会员订阅、云端记录、运动广场、资料头像、中英文界面和浅/深色主题；基础本地训练无需登录。

## 快速开始

```bash
flutter pub get
flutter analyze
flutter test             # 以实际输出为准；必须包含回放基线 5/5/3
flutter build apk --debug
```

> 测试夹具在 `test/fixtures/`（脱敏标量信号，已纳入 git），干净 checkout 可直接复现绿测。
> Release/AAB 需要本机受保护配置和上传签名，按 [发布配置台账](docs/release-configuration.md#64-google-play-aab-标准打包-sop) 操作。

## 架构

```
pushup_domain.dart     纯算法，零 Flutter 依赖（地基）
product/               产品规则（计数管线/门控/存储/语音）
control/               编排（WorkoutController / AccountController）
ui/pages/              纯展示
inference/ pipeline/ platform/   基础设施（推理/帧处理/相机/平台服务）
workers/membership-api/          Cloudflare Worker（账号/会员/记录/榜单）
```

依赖只向上指。详见 [AGENTS.md](AGENTS.md) 和 [docs/](docs/)。

## 识别算法

核心原则：**准备态严格确认支撑和尺度，运动态用头肩轨迹判断完整下压与回升。**

- 动作信号 = `torsoY`（头与双肩的置信度加权轨迹）
- 双腕在准备态分别确认支撑位置和动作尺度，不做左右平均
- 运动态允许肘腕暂时离屏；可靠可见的抬手、直臂或固定弯肘只作为反证
- 完成“下压 → 推起到顶”后计数，回放硬基线为 5/5/3

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
