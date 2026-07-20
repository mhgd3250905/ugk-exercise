# PushupAI 官网

`PushupAI / AI俯卧撑` 的零依赖静态产品官网。

## 本地预览

从仓库根目录运行：

```bash
python3 -m http.server 4173 --directory website
```

然后访问 [http://127.0.0.1:4173/](http://127.0.0.1:4173/)。

## 验证

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
```

## 多语言维护

网站支持 8 种语言：`zh-CN`、`en`、`es`、`fr`、`de`、`pt-BR`、`ja`、
`ko`。语言选择器始终使用各语言的原生名称。翻译数据和 locale 解析函数位于
`website/locales.js`。

首次访问时按以下优先级选择语言：URL 的 `?lang=` 参数 → `localStorage`
中的 `pushupai.locale` → 浏览器语言 → English。用户手动切换后会同步更新 URL
与本地记录，便于刷新、收藏和分享。

`website/index.html` 保留完整中文内容，作为没有 JavaScript 时的可用回退页面；
语言选择器仅在 JavaScript 成功启动后显示。维护翻译时，每种语言的 key 必须与
English 字典完全一致，测试会检查 key parity。新增语言前必须补齐自动化测试，
并在 360px、768px、1440px 浏览器宽度下完成视觉 QA。

注意：官网支持 8 种语言不代表 App 界面支持 8 种语言；App 当前仍只支持中文和
English。

## 隐私与素材边界

真实 App 展示只允许使用用户明确授权公开的截图。默认应排除头像、昵称、账号标识
和原始影像；若截图含此类信息，必须取得针对具体文件和具体发布用途的明确授权。
未经单独筛选或授权的截图、录屏和用户素材不得复制进 `website/`、Git、Issue 或聊天记录。

## 配置下载渠道

编辑 `website/store-links.js` 中的 `STORE_LINKS.googlePlay`、
`STORE_LINKS.appStore` 与 `STORE_LINKS.apk`。只接受完整的 HTTPS URL；留空时页面继续显示
“即将上架”，并且不会产生空跳转。

```js
export const STORE_LINKS = Object.freeze({
  googlePlay: 'https://play.google.com/store/apps/details?id=你的应用ID',
  appStore: 'https://apps.apple.com/app/id你的应用ID',
  apk: 'https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk',
});
```

## 启用 Android APK 下载

首页应用商店按钮下方提供 Android APK 入口。桌面端悬浮或点击会展示真实二维码，
移动端点击会弹出下载确认。`STORE_LINKS.apk` 留空时不会产生下载；填入真实 HTTPS
地址后，移动端弹窗中的“继续下载”才会启用。

当前发布：

- `versionName 0.3.4`、`versionCode 5`、文件大小 `317226209` 字节；
- 下载地址：`https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk`；
- SHA-256：`1F45FFD3AD5F7E59D3FF8FEC6DD5A900E6980B3F4B1AE2E342CA0CEA1B8499E7`；
- 二维码：`website/assets/pushup-ai-0.3.4-qr.png`，内容为上述下载地址；
- 已完成 R2 回下载大小与 SHA-256 核验；用户于 2026-07-14 报告 Android 真机下载、安装和使用正常。

后续版本必须重复以下发布门禁：

1. 从授权发布流程取得已签名的 release APK；
2. 使用由项目控制的稳定 HTTPS URL；
3. 在页面明确展示 version name 和 version code；
4. 发布对应文件的 SHA-256 checksum；
5. 用该 HTTPS URL 生成真实二维码，替换当前不可扫描的占位图；
6. 完成桌面/移动浏览器和 Android 真机下载、安装验证。

不要把 APK 二进制文件提交到本仓库，也不要加入占位 URL、虚假 URL 或无法验证
来源的下载地址。

## 部署

将 `website/` 作为静态站点根目录部署。无需安装依赖或执行构建命令，
发布目录也是 `website/`。

- Cloudflare Pages：Build command 留空，Build output directory 填 `website`
- GitHub Pages：将 `website/` 内容发布为站点根目录
- 其他静态托管：上传 `website/` 内全部文件并保留目录结构

## 素材来源

- `app-home-2026-07-20.webp`、`app-plaza-2026-07-20.webp`：用户针对对应的两个原始
  截图文件明确授权官网公开；网页文件仅做 960px WebP 体积优化，授权包含画面中的
  本人头像、昵称和榜单展示，不构成对其他个人素材的概括授权
- `app-records-2026-07-20.jpg`、`app-settings-2026-07-20.jpg`：用户明确授权官网公开的
  当前 App 实机截图；画面不含真人头像、昵称或其他账号资料
- `app-icon.png`：复用 Android App 的真实启动图标，用于页面品牌标识与 favicon
- `pushup-motion-bg.webp`：使用内置 `imagegen` 生成的无文字抽象运动背景
- `pushup-performance-motion-v2.webp`：使用 built-in image tool 按经批准的
  Performance Editorial no-text/no-face motion brief 生成，作为低对比装饰背景
