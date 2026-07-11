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
node --check website/store-links.js
```

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
