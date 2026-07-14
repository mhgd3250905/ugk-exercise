# `codex/alpha-0.3.5` → `main` 审核报告

- 日期：2026-07-15
- 功能分支：`codex/alpha-0.3.5`
- 目标分支：`main`
- 审核基线：`a2b75d90f52f235b40b6ec76db253cb60fb654c9`
- 功能与台账截止提交：`5066c3cbbd429fb9fe362d5dbb439adb381bfcf9`
- AAB 源码提交：`19bdbec732df547a204866a3b62fe02e66225fbb`

## 1. 结论先行

本分支把已合入 `main` 的会员月度/年度功能准备为 `0.3.5 (6)` 内部测试候选，并完成 Google Play Billing Sandbox 与 Play 内部测试安装冒烟。候选的自动化、AAB、月度/年度测试购买、RevenueCat 权益、Webhook→D1 和 Play 安装版会员恢复均有证据，可以进入 `main` 审核。

本分支没有新增业务逻辑：相对审核基线只修改版本号和发布/测试台账。完整购买发生在 Google 官方支持的 License Tester 侧载 Debug 包；Play 安装版验证的是商店分发、Google 登录和已有会员恢复，不能写成 Play 安装版再次购买成功。

## 2. 分支改动

### 2.1 发布候选

- `pubspec.yaml`：`0.3.4+5` → `0.3.5+6`。
- 构建并校验 release AAB，产物对应提交 `19bdbec`。
- AAB 大小：`184824887` 字节。
- AAB SHA-256：`118C249CC8D3F4C0C478B0CA312AFD2124E18953C5A8963E5191EB438ED910B2`。
- 包名、SDK、release 不可调试、上传签名和禁止权限检查均通过，详情见 `docs/release-configuration.md`。

### 2.2 测试手册与台账

- 明确 License Tester 可以使用同包名侧载 Debug 包验证 Google Play Billing。
- 明确该方式不能替代 Play App Signing 安装、更新和 Play 签名 OAuth 冒烟。
- 记录 RevenueCat Customer Profile 必须开启 `Show sandbox data` 才显示测试权益。
- 记录月度/年度购买、续订、过期、会员恢复及 Webhook→D1 证据。
- 记录内部测试安装版 `0.3.5 (6)` 的版本、安装来源、登录和会员恢复结果。

## 3. Google Play Billing Sandbox 结果

前提均已满足：License Testing 名单生效，购买页显示 Google 测试卡和测试订阅声明，没有使用真实付款方式。

### 月度方案

- 商品：`premium:monthly`。
- 商店显示：`$2.99`，Sandbox 加速周期约 5 分钟。
- 首次购买成功，随后产生加速续订。
- 取消/计费失败/过期事件到达 RevenueCat 和 Worker。
- 过期后重启 App，账号恢复为非会员。

### 年度方案

- 商品：`premium:annual`。
- Play Sandbox 实际显示并记录为 `$19.99`；控制台目标基准价记录为 `$20.00`，App 始终使用商店返回的本地化价格。
- 首次购买成功，RevenueCat Sandbox `premium` entitlement 为 Active。
- App 重启后会员仍保持。

### 后端同步

- RevenueCat 服务凭据显示有效，月度/年度商品均关联 `premium` entitlement 和 `default` Offering。
- 只读 D1 核验确认年度 `INITIAL_PURCHASE`、月度 `RENEWAL`、`CANCELLATION`、`EXPIRATION` 已处理。
- `membership_snapshots` 已出现 `premium / active`。
- 远端 `/membership` 鉴权响应没有被单独抓取；不得把 D1 查询扩写成该接口已独立验证。

## 4. Play 内部测试安装冒烟

- 从 Google Play 的 `Internal Early Access` 商店页安装。
- 安装版本：`0.3.5 (6)`。
- Android 安装器：`com.android.vending`。
- 包不含 `DEBUGGABLE` 标志，不是此前侧载的本地 Debug 包。
- Google 登录成功。
- 已有年度 Sandbox 会员自动恢复。
- 强制停止并重启 App 后，会员状态仍保持。
- 活跃会员不会再次展示购买弹窗，因此没有在 Play 安装版重复购买。

## 5. 验证证据

发布候选全量验证（之后只有文档改动）：

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | PASS，0 issue |
| `flutter test` | PASS，346/346 |
| 回放基线 | PASS，Step0=5 / video3=5 / video4=3 |
| Worker `npm test` | PASS，108/108 |
| `git diff --check` | PASS |
| 新增内容敏感扫描 | PASS，0 命中 |

## 6. `main` 审核重点

1. `pubspec.yaml` 的 `0.3.5+6` 是否符合当前 Play 版本序列。
2. 台账是否准确区分“Debug Sandbox 购买”和“Play 安装版恢复”。
3. 是否接受年度目标价 `$20.00`、商店实际显示 `$19.99`，并继续以商店本地化价格为准。
4. AAB 是否明确绑定源码提交 `19bdbec`，没有把后续纯文档提交误写为产物源码。
5. 文档中没有凭据值、个人账号、Customer ID 或设备序列号。

## 7. 合入后建议

1. 本分支通过 `main` 审核后合并；无需为纯文档提交重新构建候选。
2. 是否把同一 AAB 推进 Alpha 需用户单独授权，不在本次审核范围内。
3. Cloudflare Token 轮换、线上 Worker/Secret 核对和 `canJoin` 部署是现有独立待办，不应与本分支一起顺手处理。

## 8. 明确未执行

- 未 push、未合并到 `main`、未创建 PR。
- 未推进 Alpha 或 Production。
- 未部署 Worker、未修改 Secret、未手工写 D1。
- Sandbox 交易触发了正常的 RevenueCat Webhook→D1 写入；未发生真实扣款。
- 未重新发起购买、退款或订阅变更。
- 用户未跟踪文件 `docs/handoff-2026-07-14-membership-explore.md` 未修改、未暂存、未提交。

## 9. 审核命令

```powershell
git diff --stat a2b75d90f52f235b40b6ec76db253cb60fb654c9..codex/alpha-0.3.5
git diff --check a2b75d90f52f235b40b6ec76db253cb60fb654c9..codex/alpha-0.3.5
flutter analyze
flutter test
cd workers/membership-api
npm test
```

## 10. 分支提交

- `19bdbec` `build: prepare 0.3.5 internal candidate`
- `c7f3841` `docs: record 0.3.5 internal candidate`
- `3b2ec06` `docs: record Google Play sandbox membership validation`
- `af55c91` `docs: clarify membership sandbox validation boundary`
- `5066c3c` `docs: record Play install membership smoke`
