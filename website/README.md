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

## 配置下载渠道

编辑 `website/store-links.js` 中的 `STORE_LINKS.googlePlay` 与
`STORE_LINKS.appStore`。只接受完整的 HTTPS URL；留空时页面继续显示
“即将上架”，并且不会产生空跳转。

```js
export const STORE_LINKS = Object.freeze({
  googlePlay: 'https://play.google.com/store/apps/details?id=你的应用ID',
  appStore: 'https://apps.apple.com/app/id你的应用ID',
});
```

## 启用 Android APK 下载

当前 Android APK 卡片只是不可扫描、不可点击的视觉占位，不包含下载地址。只有
以下条件全部满足后，才能添加链接和真实二维码：

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

- `app-home.png`、`app-workout.png`、`app-records.png`：项目真实 App 截图
- `pushup-motion-bg.webp`：使用内置 `imagegen` 生成的无文字抽象运动背景
- `favicon.svg`：项目内代码生成的 PushupAI 品牌标记
