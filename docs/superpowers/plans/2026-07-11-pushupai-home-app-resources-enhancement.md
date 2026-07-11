# PushupAI Home App Resources Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the existing PushupAI landing page with truthful App ecosystem content and an accessible FAQ derived from the repository's implemented product resources.

**Architecture:** Keep the zero-dependency static-site architecture. Add semantic ecosystem and FAQ sections to `index.html`, implement all visuals and responsive behavior in `styles.css`, and extend the existing Node built-in tests to protect content scope, navigation, FAQ count, and store-link invariants. No Flutter, Worker, store-link, or image asset changes are required.

**Tech Stack:** HTML5, modern CSS, native `<details>`/`<summary>`, vanilla JavaScript ES modules, Node.js built-in `node:test`, Chromium browser QA.

---

## File map

- Modify `website/index.html`: navigation, App ecosystem Bento section, and FAQ.
- Modify `website/styles.css`: ecosystem visuals, FAQ interaction states, responsive layouts, and earlier mobile-menu breakpoint.
- Modify `website/tests/website.test.mjs`: structural and product-boundary regression tests.
- Modify `docs/superpowers/plans/2026-07-11-pushupai-home-app-resources-enhancement.md`: mark each executed step complete.

### Task 1: Add failing content and scope tests

**Files:**
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Extend the approved content test**

Add these values to the `expected` array in the first test:

```js
'id="ecosystem"',
'id="faq"',
'href="#ecosystem"',
'href="#faq"',
'不只记住这一次，也陪你坚持下一次。',
'训练记录与云端同步',
'运动广场',
'一个账号，恢复权益',
'跟随你的设备',
```

- [ ] **Step 2: Add FAQ and marketing-boundary tests**

Append:

```js
test('FAQ covers the five approved product questions with native details', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  assert.equal((html.match(/<details/g) ?? []).length, 5);
  for (const question of [
    '手机应该放在哪里？',
    '视频会上传吗？',
    '当前支持哪些动作？',
    '训练记录如何同步？',
    '什么时候可以下载？',
  ]) {
    assert.match(html, new RegExp(question));
  }
});

test('ecosystem copy keeps premium boundaries and avoids sales claims', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const approved of [
    '登录会员后',
    '日榜和周榜',
    '恢复购买',
    '中文和英文',
    '跟随系统主题',
  ]) {
    assert.match(html, new RegExp(approved));
  }
  for (const forbidden of ['限时优惠', '免费试用', '立即开通', '会员价格']) {
    assert.doesNotMatch(html, new RegExp(forbidden));
  }
});
```

- [ ] **Step 3: Run the tests and verify the new requirements fail**

Run: `node --test website/tests/website.test.mjs`  
Expected: existing tests pass; the landing-page, FAQ, and ecosystem tests fail because the new sections do not exist.

### Task 2: Add the App ecosystem section

**Files:**
- Modify: `website/index.html`
- Test: `website/tests/website.test.mjs`

- [ ] **Step 1: Update the main navigation**

Replace the four current navigation links with:

```html
<a href="#features">产品能力</a>
<a href="#ecosystem">产品生态</a>
<a href="#how-it-works">使用方式</a>
<a href="#faq">常见问题</a>
<a href="#download">下载</a>
```

- [ ] **Step 2: Insert the ecosystem section after `#showcase`**

Add this complete section before `#how-it-works`:

```html
<section id="ecosystem" class="section ecosystem" aria-labelledby="ecosystem-title">
  <div class="section-heading reveal">
    <p class="eyebrow"><span aria-hidden="true"></span> 从训练到坚持</p>
    <h2 id="ecosystem-title">不只记住这一次，<br>也陪你坚持下一次。</h2>
    <p>训练先留在本机；需要时，再通过账号连接记录、权益和运动广场。</p>
  </div>
  <div class="ecosystem-grid">
    <article class="ecosystem-card ecosystem-sync reveal">
      <div class="ecosystem-card-copy">
        <span class="ecosystem-kicker">记录</span>
        <h3>训练记录与云端同步</h3>
        <p>本地训练始终可用。登录会员后，可同步归属当前账号的训练记录；云端暂不可用时，本地记录仍会显示。</p>
      </div>
      <div class="sync-visual" aria-hidden="true">
        <div class="sync-device"><span></span><span></span><strong>24</strong></div>
        <div class="sync-path"><i></i><i></i><i></i></div>
        <div class="sync-cloud"><span></span><strong>已同步</strong></div>
      </div>
    </article>
    <article class="ecosystem-card ecosystem-ranking reveal">
      <div class="ecosystem-card-copy">
        <span class="ecosystem-kicker">运动广场</span>
        <h3>日榜和周榜，看见自己的位置</h3>
        <p>会员可选择加入俯卧撑排行，查看个人排名与完成次数。</p>
      </div>
      <div class="ranking-visual" aria-hidden="true">
        <div><strong>01</strong><span><i style="--rank-width: 92%"></i></span></div>
        <div><strong>02</strong><span><i style="--rank-width: 72%"></i></span></div>
        <div><strong>03</strong><span><i style="--rank-width: 54%"></i></span></div>
      </div>
    </article>
    <article class="ecosystem-card ecosystem-account reveal">
      <div class="account-visual" aria-hidden="true">
        <span class="account-brand">P</span>
        <span class="account-check">✓</span>
      </div>
      <div class="ecosystem-card-copy">
        <span class="ecosystem-kicker">账号</span>
        <h3>一个账号，恢复权益</h3>
        <p>使用 Google 账号登录，会员状态与后续高级训练能力归属当前账号，并支持恢复购买。</p>
      </div>
    </article>
    <article class="ecosystem-card ecosystem-device reveal">
      <div class="ecosystem-card-copy">
        <span class="ecosystem-kicker">界面</span>
        <h3>跟随你的设备</h3>
        <p>支持中文和英文界面，也支持浅色、深色与跟随系统主题。</p>
      </div>
      <div class="device-visual" aria-hidden="true">
        <div class="language-pill"><strong>中</strong><span>EN</span></div>
        <div class="theme-orbit"><span class="theme-sun"></span><span class="theme-moon"></span></div>
      </div>
    </article>
  </div>
</section>
```

- [ ] **Step 3: Run the tests and confirm only FAQ remains red**

Run: `node --test website/tests/website.test.mjs`  
Expected: ecosystem and navigation assertions pass; FAQ test still fails with zero `<details>` elements.

### Task 3: Add the native FAQ

**Files:**
- Modify: `website/index.html`
- Test: `website/tests/website.test.mjs`

- [ ] **Step 1: Insert the FAQ before `#download`**

Add:

```html
<section id="faq" class="section faq" aria-labelledby="faq-title">
  <div class="faq-intro reveal">
    <p class="eyebrow"><span aria-hidden="true"></span> 开始之前</p>
    <h2 id="faq-title">你可能还想知道。</h2>
    <p>关于摆放、隐私、动作范围和训练记录，这里给出第一版产品的真实答案。</p>
  </div>
  <div class="faq-list reveal">
    <details>
      <summary>手机应该放在哪里？</summary>
      <p>将手机固定在身体正前方，让头、肩、肘和双手完整入镜。保持画面稳定、光线充足，再按页面提示进入准备姿态。</p>
    </details>
    <details>
      <summary>视频会上传吗？</summary>
      <p>不会。姿态识别和计数在设备端完成，视频帧不上传；训练记录只保存计数、时间等训练数据。</p>
    </details>
    <details>
      <summary>当前支持哪些动作？</summary>
      <p>当前专注单人标准宽距俯卧撑，手机需要固定在正前方。其他动作和多人场景不在第一版支持范围内。</p>
    </details>
    <details>
      <summary>训练记录如何同步？</summary>
      <p>本地训练无需登录即可使用。登录会员后，可以把归属当前账号的训练记录同步到云端；云端暂不可用时，本地记录仍会正常显示。</p>
    </details>
    <details>
      <summary>什么时候可以下载？</summary>
      <p>Google Play 与 App Store 版本正在准备中。正式上架后，本页的下载按钮会直接跳转到对应商店。</p>
    </details>
  </div>
</section>
```

- [ ] **Step 2: Run all website tests**

Run: `node --test website/tests/website.test.mjs`  
Expected: 9 tests pass.

### Task 4: Implement the ecosystem and FAQ visual system

**Files:**
- Modify: `website/styles.css`

- [ ] **Step 1: Add the ecosystem Bento layout and visual primitives**

Insert before `.steps`:

```css
.ecosystem { position: relative; }
.ecosystem-grid { display:grid; grid-template-columns:repeat(12,minmax(0,1fr)); gap:18px; }
.ecosystem-card { position:relative; display:flex; min-height:360px; flex-direction:column; justify-content:space-between; gap:30px; padding:32px; overflow:hidden; border:1px solid var(--line); border-radius:var(--radius); background:rgb(255 255 255 / 84%); }
.ecosystem-card h3 { max-width:500px; margin:8px 0 12px; font-size:clamp(24px,3vw,34px); }
.ecosystem-card p { max-width:570px; margin:0; color:var(--muted); font-size:14px; line-height:1.7; }
.ecosystem-kicker { color:var(--green-dark); font-size:11px; font-weight:900; letter-spacing:.14em; }
.ecosystem-sync { grid-column:span 7; }
.ecosystem-ranking { grid-column:span 5; color:white; background:var(--ink); border-color:var(--ink); }
.ecosystem-ranking p { color:#b8c8bf; }
.ecosystem-ranking .ecosystem-kicker { color:var(--lime); }
.ecosystem-account { grid-column:span 5; }
.ecosystem-device { grid-column:span 7; }
.sync-visual { display:grid; grid-template-columns:auto 1fr auto; align-items:center; gap:18px; }
.sync-device { width:92px; height:142px; padding:16px 12px; border:6px solid var(--ink); border-radius:24px; background:var(--canvas); }
.sync-device span { display:block; height:5px; margin-bottom:8px; border-radius:99px; background:var(--line); }
.sync-device strong { display:block; margin-top:28px; font-size:34px; text-align:center; }
.sync-path { display:flex; align-items:center; justify-content:center; gap:10px; }
.sync-path i { width:8px; height:8px; border-radius:50%; background:var(--green); }
.sync-path i:nth-child(2) { opacity:.62; }
.sync-path i:nth-child(3) { opacity:.3; }
.sync-cloud { display:grid; min-width:118px; min-height:82px; place-content:center; border-radius:44px; background:var(--lime); text-align:center; }
.sync-cloud span { width:38px; height:14px; margin:0 auto 7px; border-radius:20px 20px 8px 8px; background:var(--ink); opacity:.88; }
.sync-cloud strong { font-size:11px; }
.ranking-visual { display:grid; gap:10px; }
.ranking-visual>div { display:grid; grid-template-columns:34px 1fr; align-items:center; gap:12px; }
.ranking-visual strong { color:var(--lime); font-size:12px; }
.ranking-visual span { height:46px; padding:6px; border-radius:14px; background:rgb(255 255 255 / 7%); }
.ranking-visual i { display:block; width:var(--rank-width); height:100%; border-radius:10px; background:linear-gradient(90deg,var(--green),var(--lime)); opacity:.72; }
.account-visual { position:relative; display:grid; width:128px; aspect-ratio:1; place-items:center; border-radius:34px; background:var(--canvas-deep); }
.account-brand { display:grid; width:70px; aspect-ratio:1; place-items:center; border-radius:24px; color:var(--lime); background:var(--ink); font-size:34px; font-weight:950; }
.account-check { position:absolute; right:4px; bottom:4px; display:grid; width:38px; aspect-ratio:1; place-items:center; border:4px solid white; border-radius:50%; color:white; background:var(--green-dark); font-weight:900; }
.ecosystem-account { flex-direction:row; align-items:flex-end; }
.ecosystem-device { flex-direction:row; align-items:flex-end; }
.device-visual { display:flex; align-items:center; gap:18px; }
.language-pill { display:flex; padding:8px; border:1px solid var(--line); border-radius:999px; background:white; }
.language-pill strong,.language-pill span { display:grid; width:50px; height:42px; place-items:center; border-radius:999px; }
.language-pill strong { color:white; background:var(--ink); }
.language-pill span { color:var(--muted); font-weight:850; }
.theme-orbit { position:relative; width:104px; aspect-ratio:1; border-radius:50%; background:var(--ink); }
.theme-sun,.theme-moon { position:absolute; border-radius:50%; }
.theme-sun { top:17px; left:18px; width:28px; aspect-ratio:1; background:var(--yellow); box-shadow:0 0 0 7px rgb(255 216 77 / 12%); }
.theme-moon { right:17px; bottom:16px; width:33px; aspect-ratio:1; background:var(--lime); box-shadow:-9px -5px 0 var(--ink) inset; }
```

- [ ] **Step 2: Add FAQ layout and native interaction states**

Insert before `.download-section`:

```css
.faq { display:grid; grid-template-columns:.78fr 1.22fr; align-items:start; gap:clamp(55px,9vw,130px); }
.faq-intro { position:sticky; top:120px; }
.faq-intro>p:last-child { max-width:470px; color:var(--muted); line-height:1.7; }
.faq-list { border-top:1px solid var(--line); }
.faq details { border-bottom:1px solid var(--line); }
.faq summary { position:relative; padding:28px 58px 28px 0; cursor:pointer; list-style:none; font-size:19px; font-weight:850; }
.faq summary::-webkit-details-marker { display:none; }
.faq summary::after { position:absolute; top:50%; right:2px; display:grid; width:34px; aspect-ratio:1; place-items:center; border-radius:50%; color:var(--green-dark); background:rgb(66 201 107 / 12%); content:"+"; transform:translateY(-50%); transition:transform 180ms ease,background 180ms ease; }
.faq summary:hover::after { background:rgb(66 201 107 / 22%); }
.faq summary:active::after { transform:translateY(-50%) scale(.92); }
.faq details[open] summary::after { content:"−"; transform:translateY(-50%) rotate(180deg); }
.faq details p { max-width:680px; padding:0 58px 26px 0; margin:0; color:var(--muted); font-size:14px; line-height:1.75; }
```

- [ ] **Step 3: Move the mobile-menu breakpoint to 900px**

Move the menu-button, mobile nav panel, and hamburger animation rules currently inside `@media (max-width:640px)` into a new `@media (max-width:900px)`. Keep only phone-specific width, spacing, typography, gallery, and download rules under 640px. The 900px block must include:

```css
@media (max-width:900px) {
  .header-cta { display:none; }
  .menu-button { display:grid; width:44px; height:44px; place-content:center; gap:6px; margin-left:auto; padding:0; border:1px solid var(--line); border-radius:14px; background:rgb(255 255 255 / 85%); box-shadow:0 7px 20px rgb(23 38 31 / 7%); }
  .menu-button span:not(.sr-only) { width:20px; height:2px; border-radius:2px; background:var(--ink); transition:transform 180ms ease,opacity 180ms ease; }
  .menu-button[aria-expanded="true"] span:nth-last-child(2) { transform:translateY(4px) rotate(45deg); }
  .menu-button[aria-expanded="true"] span:last-child { transform:translateY(-4px) rotate(-45deg); }
  .menu-button:active { background:var(--canvas-deep); transform:scale(.96); }
  .site-nav { position:absolute; top:68px; right:0; left:0; display:none; flex-direction:column; align-items:stretch; gap:0; padding:10px; border:1px solid var(--line); border-radius:20px; background:rgb(255 255 255 / 96%); box-shadow:var(--shadow); backdrop-filter:blur(18px); }
  .site-nav[data-open] { display:flex; }
  .site-nav a { padding:13px 12px; border-radius:10px; }
  .site-nav a:hover { background:var(--canvas); }
  .site-nav a::after { display:none; }
}
```

- [ ] **Step 4: Add ecosystem and FAQ responsive rules**

Inside `@media (max-width:1020px)` add:

```css
.ecosystem-card { grid-column:span 6; }
.ecosystem-account,.ecosystem-device { flex-direction:column; align-items:flex-start; }
```

Inside `@media (max-width:780px)` add:

```css
.ecosystem-card { grid-column:1 / -1; }
.faq { grid-template-columns:1fr; gap:42px; }
.faq-intro { position:static; }
```

Inside `@media (max-width:640px)` add:

```css
.ecosystem-card { min-height:330px; padding:25px; }
.ecosystem-sync,.ecosystem-account,.ecosystem-device { flex-direction:column; align-items:stretch; }
.sync-visual { grid-template-columns:auto 1fr auto; gap:10px; }
.sync-device { width:74px; height:118px; }
.sync-cloud { min-width:94px; }
.device-visual { justify-content:space-between; }
.faq summary { padding-block:24px; font-size:17px; }
```

- [ ] **Step 5: Run syntax and website tests**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/store-links.js
git diff --check
```

Expected: 9 tests pass, syntax checks exit 0, and `git diff --check` prints nothing.

### Task 5: Browser and project verification

**Files:**
- Modify: `docs/superpowers/plans/2026-07-11-pushupai-home-app-resources-enhancement.md`

- [ ] **Step 1: Serve the website**

Run: `python3 -m http.server 4173 --bind 127.0.0.1 --directory website`.

- [ ] **Step 2: Verify 360px, 768px, and 1440px Chromium layouts**

At each viewport verify with browser evaluation:

```js
({
  overflow: document.documentElement.scrollWidth > innerWidth,
  ecosystemCards: document.querySelectorAll('.ecosystem-card').length,
  faqItems: document.querySelectorAll('.faq details').length,
  storesDisabled: [...document.querySelectorAll('[data-store]')]
    .every((link) => !link.hasAttribute('href') && link.getAttribute('aria-disabled') === 'true'),
})
```

Expected: `overflow=false`, `ecosystemCards=4`, `faqItems=5`, `storesDisabled=true`.

- [ ] **Step 3: Verify mobile menu and FAQ interaction**

At 360px:

- open the menu and confirm all five navigation links appear;
- press Escape and confirm focus returns to the menu button;
- focus the first FAQ summary with keyboard and press Enter;
- confirm the first `<details>` receives the `open` attribute;
- confirm browser console and page errors are empty.

- [ ] **Step 4: Run App regression verification**

Run:

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check analyze
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check test
```

Expected: analyze reports no issues and all Flutter tests pass.

- [ ] **Step 5: Mark plan steps complete and inspect scope**

Change every executed checkbox in this plan to `[x]`, then run:

```bash
git diff --check
git status --short
git diff --name-only HEAD
```

Expected changed files: this plan, `website/index.html`, `website/styles.css`, and `website/tests/website.test.mjs` only.
