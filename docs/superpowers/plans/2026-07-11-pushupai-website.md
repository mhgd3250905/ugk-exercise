# PushupAI Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished, responsive, deployable static product website for PushupAI / AI俯卧撑 with real App screenshots and future Google Play and App Store download links.

**Architecture:** Add an isolated `website/` static site that does not depend on or modify the Flutter application. Semantic HTML contains all essential content, CSS owns the visual system and responsive layout, and small ES modules own store-link configuration and progressive enhancement. Node's built-in test runner verifies content, assets, and download-link behavior without adding runtime dependencies.

**Tech Stack:** HTML5, modern CSS, vanilla JavaScript ES modules, Node.js built-in `node:test`, Python static HTTP server, Playwright/Chromium browser QA, built-in `imagegen` for one raster background asset.

---

## File map

- Create `website/index.html`: complete semantic landing-page content and metadata.
- Create `website/styles.css`: tokens, layout, phone mockups, interaction states, responsive behavior, reduced-motion behavior.
- Create `website/store-links.js`: the only place future store URLs are configured, plus pure URL-state validation.
- Create `website/main.js`: mobile navigation, store-link enhancement, reveal behavior, and copyright year.
- Create `website/tests/website.test.mjs`: dependency-free structural and behavior tests.
- Create `website/README.md`: local preview, verification, deployment, and store-link update instructions.
- Create `website/assets/app-home.png`: copied real App home screenshot.
- Create `website/assets/app-workout.png`: copied real App workout screenshot.
- Create `website/assets/app-records.png`: copied real App records screenshot.
- Create `website/assets/pushup-motion-bg.webp`: generated abstract background with no product UI or text.
- Create `website/assets/favicon.svg`: deterministic code-native brand mark.

### Task 1: Establish structural tests and project assets

**Files:**
- Create: `website/tests/website.test.mjs`
- Create: `website/assets/app-home.png`
- Create: `website/assets/app-workout.png`
- Create: `website/assets/app-records.png`

- [ ] **Step 1: Write the failing structure and asset tests**

Create `website/tests/website.test.mjs` with Node built-ins only:

```js
import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const websiteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('landing page contains the approved brand, claims, sections, and store controls', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const expected of [
    'PushupAI', 'AI俯卧撑', '架好手机，专心做好每一次。',
    '端侧 AI', '视频帧不上传', 'data-store="googlePlay"',
    'data-store="appStore"', 'id="features"', 'id="how-it-works"',
    'id="download"',
  ]) {
    assert.match(html, new RegExp(expected));
  }
});

test('all real app screenshots are project-local assets', async () => {
  for (const asset of ['app-home.png', 'app-workout.png', 'app-records.png']) {
    await access(path.join(websiteRoot, 'assets', asset));
  }
});
```

- [ ] **Step 2: Run the tests to verify they fail before the site exists**

Run: `node --test website/tests/website.test.mjs`  
Expected: FAIL because `website/index.html` does not exist.

- [ ] **Step 3: Copy the approved real App screenshots into the website boundary**

Run:

```bash
mkdir -p website/assets website/tests
cp docs/design/assets/ui-v1-home.png website/assets/app-home.png
cp docs/design/assets/ui-v1-workout.png website/assets/app-workout.png
cp docs/design/assets/ui-v1-records.png website/assets/app-records.png
```

- [ ] **Step 4: Confirm copied assets are byte-identical**

Run:

```bash
cmp docs/design/assets/ui-v1-home.png website/assets/app-home.png
cmp docs/design/assets/ui-v1-workout.png website/assets/app-workout.png
cmp docs/design/assets/ui-v1-records.png website/assets/app-records.png
```

Expected: all commands exit 0 with no output.

### Task 2: Build the semantic landing page and favicon

**Files:**
- Create: `website/index.html`
- Create: `website/assets/favicon.svg`
- Test: `website/tests/website.test.mjs`

- [ ] **Step 1: Create the HTML document with complete no-JavaScript content**

Create `website/index.html` with:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f3faf2">
  <meta name="description" content="PushupAI 使用端侧 AI 实时识别俯卧撑动作，自动计数、中文语音播报并记录训练。">
  <title>PushupAI · AI俯卧撑</title>
  <link rel="icon" href="assets/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="styles.css">
  <script type="module" src="main.js"></script>
</head>
<body>
  <a class="skip-link" href="#main">跳到主要内容</a>
  <header class="site-header" data-header>
    <a class="brand" href="#top" aria-label="PushupAI 首页"><span class="brand-mark" aria-hidden="true">P</span><span><strong>PushupAI</strong><small>AI俯卧撑</small></span></a>
    <button class="menu-button" type="button" aria-expanded="false" aria-controls="site-nav" data-menu-button><span class="sr-only">打开导航</span><span></span><span></span></button>
    <nav id="site-nav" class="site-nav" aria-label="主要导航" data-nav>
      <a href="#features">产品能力</a><a href="#how-it-works">使用方式</a><a href="#download">下载</a>
    </nav>
    <a class="header-cta" href="#download">即将上线</a>
  </header>
  <main id="main">
    <section id="top" class="hero" aria-labelledby="hero-title">
      <div class="hero-copy reveal"><p class="eyebrow">你的 AI 俯卧撑教练</p><h1 id="hero-title">架好手机，<br>专心做好每一次。</h1><p class="hero-lede">端侧 AI 实时识别动作，自动计数、语音播报，并为你留下每一次训练。</p><div class="store-row"><a class="store-button" data-store="googlePlay" aria-disabled="true"><span>GET IT ON</span><strong>Google Play</strong><em>即将上架</em></a><a class="store-button" data-store="appStore" aria-disabled="true"><span>Download on the</span><strong>App Store</strong><em>即将上架</em></a></div><p class="privacy-note">姿态识别在设备端完成 · 视频帧不上传</p></div>
      <div class="hero-visual reveal" aria-label="PushupAI App 界面预览"><div class="phone phone-hero"><img src="assets/app-home.png" width="922" height="2048" alt="AI俯卧撑首页，显示开始训练入口" fetchpriority="high"></div><div class="count-orbit" aria-hidden="true"><span>AI</span><strong>24</strong><small>次</small></div></div>
    </section>
    <section id="features" class="section features" aria-labelledby="features-title"><div class="section-heading reveal"><p class="eyebrow">专注训练本身</p><h2 id="features-title">少一点操作，多一次标准动作。</h2></div><div class="feature-grid"><article class="feature-card reveal"><span class="feature-index">01</span><h3>看见动作，自动计数</h3><p>MoveNet 实时识别身体姿态，在完整俯卧撑动作完成时计数。</p></article><article class="feature-card feature-card-dark reveal"><span class="feature-index">02</span><h3>训练留在你的设备</h3><p>推理在手机端完成。视频帧不上传，让镜头只为训练服务。</p></article><article class="feature-card reveal"><span class="feature-index">03</span><h3>每次进步，都有记录</h3><p>中文语音即时播报，训练日历帮你看见稳定积累。</p></article></div></section>
    <section class="section showcase" aria-labelledby="showcase-title"><div class="section-heading reveal"><p class="eyebrow">从开始到坚持</p><h2 id="showcase-title">训练过程，清楚可见。</h2></div><div class="phone-gallery"><figure class="reveal"><div class="phone"><img src="assets/app-home.png" width="922" height="2048" loading="lazy" alt="AI俯卧撑首页"></div><figcaption>一键开始</figcaption></figure><figure class="reveal featured-phone"><div class="phone"><img src="assets/app-workout.png" width="922" height="2048" loading="lazy" alt="AI俯卧撑训练计数页面"></div><figcaption>实时识别</figcaption></figure><figure class="reveal"><div class="phone"><img src="assets/app-records.png" width="922" height="2048" loading="lazy" alt="AI俯卧撑训练记录日历"></div><figcaption>留下记录</figcaption></figure></div></section>
    <section id="how-it-works" class="section steps" aria-labelledby="steps-title"><div class="section-heading reveal"><p class="eyebrow">三步开始</p><h2 id="steps-title">架好，准备，开始。</h2></div><ol class="step-list"><li class="reveal"><span>1</span><div><h3>固定手机</h3><p>将手机固定在身体正前方，保持画面稳定、光线充足。</p></div></li><li class="reveal"><span>2</span><div><h3>进入姿态</h3><p>让身体完整入镜，保持标准宽距俯卧撑准备姿态。</p></div></li><li class="reveal"><span>3</span><div><h3>专心训练</h3><p>准备完成后开始动作，计数与中文语音播报自动进行。</p></div></li></ol><p class="use-note reveal">当前适用于单人、手机固定正前方的标准宽距俯卧撑。</p></section>
    <section id="download" class="download-section" aria-labelledby="download-title"><div class="download-copy reveal"><p class="eyebrow">PushupAI · AI俯卧撑</p><h2 id="download-title">下一次训练，<br>让每一下都有数。</h2><p>Google Play 与 App Store 版本正在准备中。</p></div><div class="store-row reveal"><a class="store-button store-button-light" data-store="googlePlay" aria-disabled="true"><span>GET IT ON</span><strong>Google Play</strong><em>即将上架</em></a><a class="store-button store-button-light" data-store="appStore" aria-disabled="true"><span>Download on the</span><strong>App Store</strong><em>即将上架</em></a></div></section>
  </main>
  <footer class="site-footer"><a class="brand" href="#top"><span class="brand-mark" aria-hidden="true">P</span><span><strong>PushupAI</strong><small>AI俯卧撑</small></span></a><p>端侧 AI 俯卧撑识别与计数。</p><p>© <span data-year>2026</span> PushupAI</p></footer>
</body>
</html>
```

- [ ] **Step 2: Create the deterministic SVG favicon**

Create `website/assets/favicon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="18" fill="#17261f"/><path d="M20 17h15c9 0 14 5 14 13S43 43 34 43h-6v7h-8V17Zm8 7v12h6c4 0 7-2 7-6s-3-6-7-6h-6Z" fill="#b7ea4c"/></svg>
```

- [ ] **Step 3: Run the structure tests**

Run: `node --test website/tests/website.test.mjs`  
Expected: 2 tests pass.

### Task 3: Add store-link behavior and progressive enhancement

**Files:**
- Create: `website/store-links.js`
- Create: `website/main.js`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add failing tests for store URL validation**

Append to `website/tests/website.test.mjs`:

```js
const { getStoreLinkState, STORE_LINKS } = await import('../store-links.js');

test('store links default to unavailable until real URLs are configured', () => {
  assert.deepEqual(STORE_LINKS, { googlePlay: '', appStore: '' });
  assert.deepEqual(getStoreLinkState(''), { available: false, href: '' });
});

test('store links accept only absolute HTTPS URLs', () => {
  assert.deepEqual(getStoreLinkState('https://play.google.com/store/apps/details?id=app'), {
    available: true,
    href: 'https://play.google.com/store/apps/details?id=app',
  });
  assert.deepEqual(getStoreLinkState('/download'), { available: false, href: '' });
  assert.deepEqual(getStoreLinkState('javascript:alert(1)'), { available: false, href: '' });
});
```

- [ ] **Step 2: Run tests to verify the missing module fails**

Run: `node --test website/tests/website.test.mjs`  
Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `store-links.js`.

- [ ] **Step 3: Implement the store-link configuration module**

Create `website/store-links.js`:

```js
export const STORE_LINKS = Object.freeze({ googlePlay: '', appStore: '' });

export function getStoreLinkState(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return { available: false, href: '' };
    return { available: true, href: url.href };
  } catch {
    return { available: false, href: '' };
  }
}
```

- [ ] **Step 4: Implement progressive enhancement**

Create `website/main.js`:

```js
import { getStoreLinkState, STORE_LINKS } from './store-links.js';

const menuButton = document.querySelector('[data-menu-button]');
const nav = document.querySelector('[data-nav]');
menuButton?.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  nav?.toggleAttribute('data-open', open);
});
nav?.addEventListener('click', ({ target }) => {
  if (target instanceof HTMLAnchorElement) {
    menuButton?.setAttribute('aria-expanded', 'false');
    nav.removeAttribute('data-open');
  }
});

for (const link of document.querySelectorAll('[data-store]')) {
  const key = link.dataset.store;
  const state = getStoreLinkState(STORE_LINKS[key]);
  if (!state.available) continue;
  link.href = state.href;
  link.target = '_blank';
  link.rel = 'noreferrer';
  link.removeAttribute('aria-disabled');
  link.querySelector('em')?.replaceChildren('立即下载');
}

document.querySelector('[data-year]')?.replaceChildren(String(new Date().getFullYear()));

if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
  document.documentElement.classList.add('has-reveal');
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) if (entry.isIntersecting) {
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    }
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));
}
```

- [ ] **Step 5: Run the complete test file**

Run: `node --test website/tests/website.test.mjs`  
Expected: 4 tests pass.

### Task 4: Implement the product-editorial visual system

**Files:**
- Create: `website/styles.css`

- [ ] **Step 1: Add the global tokens, accessibility primitives, and typography**

Create `website/styles.css` beginning with:

```css
:root { --ink:#17261f; --muted:#64756b; --canvas:#f3faf2; --paper:#fff; --line:#dcebdf; --green:#42c96b; --green-dark:#118c4f; --lime:#b7ea4c; --radius:28px; --shadow:0 24px 70px rgb(23 38 31 / .12); color-scheme:light; }
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body { margin:0; color:var(--ink); background:var(--canvas); font-family:Inter,"SF Pro Display","PingFang SC","Noto Sans SC",system-ui,sans-serif; -webkit-font-smoothing:antialiased; }
img { display:block; max-width:100%; }
a { color:inherit; }
.sr-only { position:absolute; width:1px; height:1px; padding:0; margin:-1px; overflow:hidden; clip:rect(0,0,0,0); white-space:nowrap; border:0; }
.skip-link { position:fixed; z-index:100; top:8px; left:8px; padding:12px 16px; background:var(--ink); color:white; transform:translateY(-150%); }
.skip-link:focus { transform:none; }
:focus-visible { outline:3px solid var(--green); outline-offset:4px; }
```

- [ ] **Step 2: Add the header, Hero, phone frame, cards, gallery, steps, download section, and footer rules**

Continue the same file with explicit selectors for every class used by `index.html`. Use a centered `min(1180px, calc(100% - 40px))` content width, a two-column desktop Hero, 62px rounded store controls, 46px phone corner radius, three-column feature/gallery grids, a dark ink download panel, and reveal states:

```css
.site-header,.hero,.section,.download-section,.site-footer { width:min(1180px,calc(100% - 40px)); margin-inline:auto; }
.site-header { min-height:82px; display:flex; align-items:center; gap:32px; position:relative; z-index:20; }
.brand { display:inline-flex; align-items:center; gap:11px; text-decoration:none; }
.brand-mark { width:42px; aspect-ratio:1; display:grid; place-items:center; border-radius:14px; background:var(--ink); color:var(--lime); font-weight:950; }
.brand strong,.brand small { display:block; } .brand small { color:var(--muted); font-size:11px; letter-spacing:.08em; }
.site-nav { margin-left:auto; display:flex; gap:28px; } .site-nav a { text-decoration:none; font-weight:700; }
.header-cta { padding:12px 18px; border-radius:999px; background:var(--ink); color:white; text-decoration:none; font-weight:800; }
.menu-button { display:none; }
.hero { min-height:720px; display:grid; grid-template-columns:1.02fr .98fr; align-items:center; gap:80px; padding-block:70px 100px; }
.eyebrow { color:var(--green-dark); font-size:13px; font-weight:900; letter-spacing:.12em; text-transform:uppercase; }
h1,h2,h3,p { margin-top:0; } h1 { margin-bottom:28px; font-size:clamp(50px,6vw,86px); line-height:.98; letter-spacing:-.055em; } h2 { font-size:clamp(38px,5vw,66px); line-height:1.05; letter-spacing:-.045em; }
.hero-lede { max-width:580px; color:var(--muted); font-size:19px; line-height:1.7; }
.store-row { display:flex; flex-wrap:wrap; gap:12px; margin-top:32px; }
.store-button { min-width:190px; min-height:66px; display:grid; grid-template-columns:1fr auto; padding:11px 16px; border-radius:18px; background:var(--ink); color:white; text-decoration:none; cursor:default; }
.store-button span,.store-button strong { grid-column:1; } .store-button span { font-size:9px; letter-spacing:.1em; opacity:.65; } .store-button strong { font-size:17px; } .store-button em { grid-column:2; grid-row:1/3; align-self:center; font-size:11px; font-style:normal; color:var(--lime); }
.privacy-note { margin-top:18px; color:var(--muted); font-size:13px; }
.hero-visual { position:relative; min-height:610px; display:grid; place-items:center; isolation:isolate; }
.hero-visual::before { content:""; position:absolute; inset:3% -7%; z-index:-2; border-radius:50%; background:url("assets/pushup-motion-bg.webp") center/cover no-repeat,linear-gradient(135deg,#e4f7e7,#edf8dc); opacity:.8; }
.phone { overflow:hidden; padding:8px; border:1px solid rgb(255 255 255 / .65); border-radius:48px; background:#111b16; box-shadow:var(--shadow); } .phone img { width:100%; border-radius:40px; }
.phone-hero { width:min(340px,78vw); transform:rotate(2.5deg); }
.count-orbit { position:absolute; right:1%; bottom:14%; width:132px; aspect-ratio:1; display:grid; place-content:center; text-align:center; border-radius:50%; background:var(--lime); box-shadow:0 18px 50px rgb(23 38 31 / .18); } .count-orbit span,.count-orbit small { font-size:10px; font-weight:900; } .count-orbit strong { font-size:50px; line-height:.9; }
.section { padding-block:120px; } .section-heading { max-width:760px; margin-bottom:55px; }
.feature-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:18px; } .feature-card { min-height:330px; padding:30px; display:flex; flex-direction:column; border:1px solid var(--line); border-radius:var(--radius); background:var(--paper); } .feature-card-dark { color:white; background:var(--ink); } .feature-index { margin-bottom:auto; font-size:13px; font-weight:900; color:var(--green-dark); } .feature-card-dark .feature-index { color:var(--lime); } .feature-card h3 { font-size:26px; } .feature-card p { color:var(--muted); line-height:1.65; } .feature-card-dark p { color:#b8c8bf; }
.showcase { overflow:hidden; } .phone-gallery { display:grid; grid-template-columns:repeat(3,1fr); align-items:center; gap:42px; } .phone-gallery figure { margin:0; text-align:center; } .phone-gallery .phone { max-width:300px; margin:auto; } .featured-phone { transform:translateY(-32px); } figcaption { margin-top:20px; font-weight:850; }
.step-list { list-style:none; margin:0; padding:0; border-top:1px solid var(--line); } .step-list li { display:grid; grid-template-columns:80px 1fr; gap:24px; padding:30px 0; border-bottom:1px solid var(--line); } .step-list li>span { width:48px; aspect-ratio:1; display:grid; place-items:center; border-radius:50%; background:var(--lime); font-weight:950; } .step-list h3 { margin-bottom:8px; font-size:24px; } .step-list p,.use-note { color:var(--muted); line-height:1.6; }
.download-section { min-height:470px; padding:70px; display:grid; grid-template-columns:1fr auto; align-items:end; gap:50px; border-radius:40px; background:var(--ink); color:white; } .download-section .eyebrow { color:var(--lime); } .download-section h2 { margin-bottom:20px; } .download-section p { color:#b8c8bf; } .store-button-light { background:white; color:var(--ink); } .store-button-light em { color:var(--green-dark); }
.site-footer { min-height:220px; display:grid; grid-template-columns:1fr auto auto; align-items:center; gap:40px; color:var(--muted); }
.has-reveal .reveal { opacity:0; transform:translateY(18px); transition:opacity .7s ease,transform .7s ease; } .has-reveal .reveal.is-visible { opacity:1; transform:none; }
```

- [ ] **Step 3: Add tablet and mobile behavior without horizontal overflow**

Finish the stylesheet with:

```css
@media (max-width:900px) { .hero { grid-template-columns:1fr; gap:30px; } .feature-grid { grid-template-columns:1fr 1fr; } .phone-gallery { gap:18px; } .download-section { grid-template-columns:1fr; } .site-footer { grid-template-columns:1fr; padding-block:70px; gap:18px; } }
@media (max-width:640px) { .site-header { min-height:72px; } .header-cta { display:none; } .menu-button { margin-left:auto; width:44px; height:44px; display:grid; place-content:center; gap:6px; border:1px solid var(--line); border-radius:14px; background:white; } .menu-button span:not(.sr-only) { width:20px; height:2px; background:var(--ink); } .site-nav { display:none; position:absolute; top:68px; inset-inline:0; padding:18px; flex-direction:column; border:1px solid var(--line); border-radius:20px; background:white; box-shadow:var(--shadow); } .site-nav[data-open] { display:flex; } .hero { padding-block:48px 70px; } h1 { font-size:clamp(46px,14vw,66px); } .hero-lede { font-size:17px; } .store-row,.store-button { width:100%; } .hero-visual { min-height:530px; } .count-orbit { right:0; } .section { padding-block:82px; } .feature-grid { grid-template-columns:1fr; } .phone-gallery { width:calc(100vw - 20px); margin-left:-10px; padding:20px; grid-template-columns:repeat(3,78vw); overflow-x:auto; scroll-snap-type:x mandatory; } .phone-gallery figure { scroll-snap-align:center; } .featured-phone { transform:none; } .download-section { width:calc(100% - 24px); padding:52px 24px; border-radius:30px; } }
@media (prefers-reduced-motion:reduce) { html { scroll-behavior:auto; } *,*::before,*::after { animation-duration:.01ms!important; transition-duration:.01ms!important; } }
```

- [ ] **Step 4: Run syntax-oriented checks**

Run:

```bash
node --check website/main.js
node --check website/store-links.js
node --test website/tests/website.test.mjs
```

Expected: both checks exit 0 and all tests pass.

### Task 5: Generate and integrate the branded background asset

**Files:**
- Create: `website/assets/pushup-motion-bg.webp`

- [ ] **Step 1: Generate the project-bound raster asset with the built-in image tool**

Use this final prompt:

```text
Use case: stylized-concept
Asset type: subtle landing-page Hero background for PushupAI / AI俯卧撑
Primary request: create a premium abstract visual inspired by the downward-and-upward motion path of one push-up, expressed only through broad flowing arcs, soft geometric fields, and restrained motion trails
Scene/backdrop: airy warm off-white background with generous negative space
Style/medium: refined editorial 3D-paper and soft translucent-layer aesthetic, minimal and mature
Composition/framing: landscape composition, visual energy concentrated around the center and lower-right, edges calm enough to crop responsively
Lighting/mood: soft daylight, optimistic, focused, quiet confidence
Color palette: pale mint, fresh green, deep forest green accents, a small amount of lime, warm off-white
Constraints: no people, no anatomy, no phone, no app interface, no logo, no letters, no numbers, no text, no watermark; background must remain subtle behind a phone mockup
Avoid: gym photography, neon cyberpunk, purple, black-gold luxury, busy patterns, hard contrast
```

- [ ] **Step 2: Copy the selected generated output into the project**

Copy the generated file from `$CODEX_HOME/generated_images/` to `website/assets/pushup-motion-bg.webp`. Do not leave a project reference pointing outside the repository.

- [ ] **Step 3: Validate the image**

Run an image metadata inspection and confirm:

- format is WebP or convert losslessly to WebP;
- width is at least 1400px;
- no text, logo, watermark, people, phones, or UI appears;
- file size is suitable for web delivery; resize/compress if it exceeds approximately 800 KB without visible benefit.

### Task 6: Document operation and verify in a browser

**Files:**
- Create: `website/README.md`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add tests for local resource references and forbidden placeholders**

Append to `website/tests/website.test.mjs`:

```js
test('local page resources exist and production markup contains no placeholders or trackers', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const references = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map((match) => match[1])
    .filter((value) => !value.startsWith('#') && !value.startsWith('http'));

  for (const reference of references) {
    await access(path.join(websiteRoot, reference));
  }

  for (const forbidden of [
    'TODO',
    'TBD',
    'href="#"',
    'fonts.googleapis.com',
    'googletagmanager',
    'analytics',
    'OPENAI_API_KEY',
  ]) {
    assert.doesNotMatch(html, new RegExp(forbidden));
  }
});
```

- [ ] **Step 2: Add the website operations guide**

Create `website/README.md` with these exact sections:

```markdown
# PushupAI 官网

## 本地预览

从仓库根目录运行 `python3 -m http.server 4173 --directory website`，然后访问 `http://127.0.0.1:4173/`。

## 验证

运行 `node --test website/tests/website.test.mjs`、`node --check website/main.js` 和 `node --check website/store-links.js`。

## 配置下载渠道

编辑 `website/store-links.js` 中的 `STORE_LINKS.googlePlay` 与 `STORE_LINKS.appStore`。只接受完整的 HTTPS URL；留空时页面继续显示“即将上架”。

## 部署

将 `website/` 作为静态站点根目录部署。无需构建命令，输出目录也是 `website/`。
```

- [ ] **Step 3: Run the complete automated verification**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/store-links.js
git diff --check
```

Expected: all tests pass, syntax checks exit 0, and `git diff --check` has no output.

- [ ] **Step 4: Serve the site and perform browser QA**

Run: `python3 -m http.server 4173 --directory website`.

Open the site in Chromium and capture screenshots at widths 360px, 768px, and 1440px. At every width verify:

- no horizontal page overflow;
- Hero title, real phone screenshots, feature cards, steps, and download section render;
- mobile menu opens and closes at 360px;
- both stores visibly say “即将上架” and do not navigate;
- keyboard focus is visible;
- browser console has no errors;
- reduced-motion mode leaves all content visible.

- [ ] **Step 5: Inspect the final changed-file scope**

Run: `git status --short` and `git diff --stat`.  
Expected: only the implementation plan and `website/` files are new or modified; Flutter and Worker files remain untouched.
