# PushupAI Performance Editorial Website Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the existing PushupAI static website into the approved six-section Performance Editorial experience, add a project-owned generated motion asset, and eliminate multilingual vertical-text and mobile-length defects without changing product truth or download safety.

**Architecture:** Keep the current no-build HTML/CSS/ES-module architecture and complete Chinese no-JavaScript fallback. Recompose `index.html` into six visual regions while reusing the current translation dictionaries and store-link runtime, narrow decorative CSS selectors so translated text cannot inherit dot styles, and replace the current reveal dependency with content-visible progressive motion. Add one generated WebP background asset used only as a low-contrast visual layer.

**Tech Stack:** Semantic HTML5, CSS3, vanilla ES modules, Node.js built-in test runner, agent-browser, built-in image generation tool, local image conversion tools.

---

## File map

| File | Responsibility |
|---|---|
| `website/index.html` | Six-region semantic structure, stable translation hooks, dedicated decorative-node classes, real App screenshots, safe download markup. |
| `website/styles.css` | Performance Editorial tokens, responsive grids, typography, card hierarchy, compact mobile layout, visible-by-default motion. |
| `website/main.js` | Existing locale/menu/store behavior; remove the content-hiding reveal dependency while retaining progressive enhancement. |
| `website/locales.js` | Existing eight-language truth source; only update keys if markup copy changes. |
| `website/assets/pushup-performance-motion-v2.webp` | New no-text, no-face generated motion backdrop used by Hero and download close. |
| `website/tests/website.test.mjs` | Six-region contract, decorative selector boundary, asset existence, responsive typography, motion visibility, existing locale/download safety regression coverage. |
| `website/README.md` | New generated asset provenance and visual maintenance rules. |

---

### Task 1: Lock and fix multilingual decorative-selector defects

**Files:**
- Modify: `website/tests/website.test.mjs`
- Modify: `website/index.html`
- Modify: `website/styles.css`

- [x] **Step 1: Add failing selector-boundary tests**

Add a test that requires dedicated decoration classes and rejects selectors that target all descendant spans:

```js
test('translated labels cannot inherit decorative dot styles', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.match(html, /class="eyebrow-dot" aria-hidden="true"/);
  assert.match(html, /class="motion-dot" aria-hidden="true"/);
  assert.match(html, /class="privacy-dot" aria-hidden="true"/);
  assert.doesNotMatch(css, /\.eyebrow\s*>\s*span\s*\{/);
  assert.doesNotMatch(css, /\.motion-label\s+span\s*\{/);
  assert.doesNotMatch(css, /\.privacy-note\s+span\s*\{/);
});
```

- [x] **Step 2: Run the test and verify it fails**

Run:

```bash
node --test website/tests/website.test.mjs
```

Expected: FAIL because the HTML lacks dedicated dot classes and CSS still uses broad `span` selectors.

- [x] **Step 3: Give decorative nodes explicit classes**

Update all eyebrow dots and the Hero status dots:

```html
<p class="eyebrow">
  <span class="eyebrow-dot" aria-hidden="true"></span>
  <span data-i18n="features.eyebrow">专注训练本身</span>
</p>

<div class="motion-label motion-label-top" aria-hidden="true">
  <span class="motion-dot"></span>
  <span data-i18n="hero.poseRecognized">姿态已识别</span>
</div>

<p class="privacy-note">
  <span class="privacy-dot" aria-hidden="true">●</span>
  <span data-i18n="privacy.short">姿态识别在设备端完成 · 原始视频帧不上传</span>
</p>
```

- [x] **Step 4: Narrow CSS to the explicit decoration classes**

Replace broad selectors with:

```css
.eyebrow-dot {
  width: 7px;
  height: 7px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--signal);
  box-shadow: 0 0 0 5px rgb(42 199 109 / 13%);
}

.motion-dot {
  width: 8px;
  height: 8px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--signal);
}

.privacy-dot {
  flex: 0 0 auto;
  color: var(--signal);
  font-size: 8px;
}
```

- [x] **Step 5: Run tests and commit the defect fix**

Run:

```bash
node --test website/tests/website.test.mjs
git diff --check
```

Expected: all tests PASS and no whitespace errors.

Commit:

```bash
git add website/index.html website/styles.css website/tests/website.test.mjs
git commit -m "fix: prevent translated labels from stacking vertically"
```

---

### Task 2: Recompose the page into six visual regions

**Files:**
- Modify: `website/tests/website.test.mjs`
- Modify: `website/index.html`

- [x] **Step 1: Add a failing six-region structure test**

```js
test('landing page uses the approved six-region editorial structure', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const region of [
    'data-region="hero"',
    'data-region="capabilities"',
    'data-region="product-story"',
    'data-region="ecosystem"',
    'data-region="support"',
    'data-region="download"',
  ]) {
    assert.match(html, new RegExp(region));
  }
  assert.equal((html.match(/data-region=/g) ?? []).length, 6);
  assert.match(html, /id="how-it-works"[\s\S]*id="faq"/);
});
```

- [x] **Step 2: Run the test and verify it fails**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL because the current markup has no `data-region` contract and uses separate steps/FAQ visual sections.

- [x] **Step 3: Mark the six regions and combine support content**

Use this semantic outline:

```html
<section id="top" class="hero" data-region="hero">...</section>
<section id="features" class="section capabilities" data-region="capabilities">...</section>
<section id="showcase" class="section product-story" data-region="product-story">...</section>
<section id="ecosystem" class="section ecosystem" data-region="ecosystem">...</section>
<section class="section support" data-region="support">
  <div id="how-it-works" class="support-steps">...</div>
  <div id="faq" class="support-faq">...</div>
</section>
<section id="download" class="download-section" data-region="download">...</section>
```

Keep every existing `data-i18n` key, privacy URL, store control, screenshot, FAQ answer, and APK safety attribute. Remove only duplicated wrapper headings or repeated explanatory paragraphs; do not remove product facts.

- [x] **Step 4: Make the product story explicit**

Add editorial sequence metadata without new translation keys:

```html
<figure class="story-device story-device-start">...</figure>
<figure class="story-device story-device-train">...</figure>
<figure class="story-device story-device-record">...</figure>
```

The visible captions continue using `showcase.start`, `showcase.recognize`, and `showcase.record`.

- [x] **Step 5: Run structural, locale, and safety tests**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
git diff --check
```

Expected: all checks PASS; eight dictionaries retain exact key parity; APK card contains no interactive element.

- [x] **Step 6: Commit the editorial document structure**

```bash
git add website/index.html website/tests/website.test.mjs
git commit -m "feat: recompose website into six editorial regions"
```

---

### Task 3: Generate and integrate the Performance Motion asset

**Files:**
- Create: `website/assets/pushup-performance-motion-v2.webp`
- Modify: `website/tests/website.test.mjs`
- Modify: `website/styles.css`
- Modify: `website/README.md`

- [x] **Step 1: Add a failing asset contract**

```js
test('performance editorial motion artwork is project-local', async () => {
  const asset = path.join(
    websiteRoot,
    'assets',
    'pushup-performance-motion-v2.webp',
  );
  await access(asset);
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  assert.match(css, /pushup-performance-motion-v2\.webp/);
  assert.doesNotMatch(html, /https?:\/\/[^"']+\.(?:png|jpe?g|webp)/i);
});
```

- [x] **Step 2: Run the test and verify the asset is missing**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL with `ENOENT` for `pushup-performance-motion-v2.webp`.

- [x] **Step 3: Generate one source image with the built-in image tool**

Use this final prompt:

```text
Use case: stylized-concept
Asset type: wide landing-page hero and closing-section background
Primary request: Create an abstract editorial visualization of push-up motion for a premium AI fitness brand.
Scene/backdrop: warm chalk off-white field with deep ink-green geometry and restrained acid-lime motion trails.
Subject: a non-identifiable human push-up movement represented only by elegant geometric ribbons, joint arcs, and layered motion contours; no face and no photoreal person.
Style/medium: high-end sports editorial art direction, clean 3D paper-cut forms mixed with subtle translucent motion lines, sophisticated and minimal.
Composition/framing: wide landscape; visual mass centered to the right; generous calm negative space on the left for website copy; crop-safe at desktop and mobile.
Lighting/mood: soft directional studio light, crisp depth, energetic but controlled.
Color palette: #14231B, #F5F6F0, #C6FF55, small accents of #2AC76D.
Constraints: no text, no logo, no watermark, no gym equipment, no recognizable face, no anatomical diagram, no extra limbs, no dark full-frame background.
Avoid: neon cyberpunk, stock-photo fitness imagery, loud gradients, glossy plastic, clutter.
```

- [x] **Step 4: Inspect, persist, and optimize the selected output**

Copy the selected generated source into a local intermediate path, inspect it with the image viewer, then convert it to WebP:

```bash
cwebp -quiet -q 82 <selected-generated-image> \
  -o website/assets/pushup-performance-motion-v2.webp
```

If `cwebp` is unavailable, use the bundled workspace Python runtime with Pillow to convert without changing dimensions. Verify:

```bash
file website/assets/pushup-performance-motion-v2.webp
du -h website/assets/pushup-performance-motion-v2.webp
```

Expected: valid WebP, visually clean, no text/face/watermark, project-local, and reasonably sized for a static landing page.

Register the project-local URL immediately so the Task 3 asset contract is complete before the full visual rewrite:

```css
:root {
  --performance-motion-art: url("assets/pushup-performance-motion-v2.webp");
}
```

- [x] **Step 5: Document asset provenance**

Add to `website/README.md`:

```markdown
- `pushup-performance-motion-v2.webp`: generated with the built-in image tool from the approved Performance Editorial no-text/no-face motion brief; used as a low-contrast decorative background.
```

- [x] **Step 6: Run the asset contract and commit**

```bash
node --test website/tests/website.test.mjs
git add website/assets/pushup-performance-motion-v2.webp website/README.md website/styles.css website/tests/website.test.mjs
git commit -m "feat: add performance editorial motion artwork"
```

---

### Task 4: Replace the visual system and responsive layout

**Files:**
- Modify: `website/tests/website.test.mjs`
- Modify: `website/styles.css`

- [x] **Step 1: Add failing visual-system CSS contracts**

```js
test('performance editorial visual tokens and mobile readability are enforced', async () => {
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  for (const token of [
    '--ink: #14231b',
    '--acid: #c6ff55',
    '--signal: #2ac76d',
    '--chalk: #f5f6f0',
    '--surface: #ffffff',
  ]) {
    assert.match(css.toLowerCase(), new RegExp(token.replace('#', '\\#')));
  }
  assert.match(css, /@media \(max-width: 767px\)[\s\S]*?body\s*\{[^}]*font-size:\s*16px/s);
  assert.match(css, /\.support\s*\{[^}]*grid-template-columns:/s);
  assert.match(css, /\.product-story/);
});
```

- [x] **Step 2: Run tests and confirm the old visual system fails**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL for missing tokens, support grid, and mobile base-size contract.

- [x] **Step 3: Define the Performance Editorial tokens**

Replace the root palette and establish a small spacing/elevation system:

```css
:root {
  --ink: #14231b;
  --ink-soft: #24372d;
  --acid: #c6ff55;
  --signal: #2ac76d;
  --chalk: #f5f6f0;
  --surface: #ffffff;
  --muted: #5e6d64;
  --line: #dce6df;
  --space-1: 8px;
  --space-2: 16px;
  --space-3: 24px;
  --space-4: 32px;
  --space-5: 48px;
  --shadow-card: 0 18px 48px rgb(20 35 27 / 8%);
  --shadow-device: 0 34px 90px rgb(20 35 27 / 18%);
}
```

- [x] **Step 4: Rebuild Hero and capabilities**

Use a strong 12-column Hero, the generated image as a decorative pseudo-layer, one dominant device, and three cards with one deep-ink card. Ensure the Hero heading wraps naturally and no translated node receives fixed width/height.

Key contracts:

```css
.hero {
  display: grid;
  grid-template-columns: minmax(0, 1.02fr) minmax(420px, .98fr);
  min-height: min(820px, calc(100svh - 88px));
}

.hero::before {
  background: url("assets/pushup-performance-motion-v2.webp") center / cover no-repeat;
  opacity: .24;
}

.capabilities-grid {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
}
```

- [x] **Step 5: Rebuild product story and ecosystem**

Give the three screenshots an editorial sequence, use consistent device frames, and reduce the ecosystem to a two-row bento with only three radius sizes and three elevation levels. Do not change screenshot files or product claims.

- [x] **Step 6: Build the combined support and download layouts**

Desktop support uses `minmax(280px, .78fr) minmax(0, 1.22fr)`. Mobile support is one column. The download close uses the same generated background at low opacity, retains all store buttons and APK markup, and keeps the real privacy links in the footer.

- [x] **Step 7: Add systematic responsive rules**

Use these breakpoints and guarantees:

```css
@media (max-width: 1023px) { /* tablet grids */ }
@media (max-width: 767px) {
  body { font-size: 16px; }
  .hero,
  .support,
  .download-layout { grid-template-columns: 1fr; }
  .section { padding-block: 88px; }
}
@media (max-width: 390px) { /* compact gutters only */ }
@media (max-height: 500px) and (orientation: landscape) { /* compact Hero */ }
```

Do not hide product content at any breakpoint. Keep nav/select/FAQ controls at least `44px` tall and preserve horizontal screenshot scrolling only inside the product-story gallery.

- [x] **Step 8: Run tests and commit the visual system**

```bash
node --test website/tests/website.test.mjs
git diff --check
git add website/styles.css website/tests/website.test.mjs
git commit -m "feat: apply performance editorial website system"
```

---

### Task 5: Make content visible by default and keep interaction progressive

**Files:**
- Modify: `website/tests/website.test.mjs`
- Modify: `website/main.js`
- Modify: `website/styles.css`

- [x] **Step 1: Add a failing no-hidden-content test**

```js
test('scroll enhancement never makes production content invisible by default', async () => {
  const main = await readFile(path.join(websiteRoot, 'main.js'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  assert.doesNotMatch(css, /\.has-reveal\s+\.reveal\s*\{[^}]*opacity:\s*0/s);
  assert.doesNotMatch(main, /classList\.add\('has-reveal'\)/);
});
```

- [x] **Step 2: Run tests and verify the current reveal dependency fails**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL because `main.js` adds `has-reveal` and CSS sets reveal content to `opacity: 0`.

- [x] **Step 3: Remove the IntersectionObserver content-hiding branch**

Delete the `has-reveal` class and observer setup from `setupPage()`. Keep menu, store links, locale setup, current year, deep-link restore, and reduced-motion CSS unchanged.

Use visible-by-default polish instead:

```css
.reveal {
  transition:
    transform 240ms ease,
    box-shadow 240ms ease,
    opacity 240ms ease;
}
```

- [x] **Step 4: Run runtime and reduced-motion checks**

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
git diff --check
```

Expected: all PASS; no content requires JavaScript or intersection to become visible.

- [x] **Step 5: Commit the progressive-motion simplification**

```bash
git add website/main.js website/styles.css website/tests/website.test.mjs
git commit -m "fix: keep website content visible during fast scrolling"
```

---

### Task 6: Browser QA, review, and branch handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-12-pushupai-performance-editorial-redesign.md`

- [x] **Step 1: Start or reuse the local static server**

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory website
```

Expected: `http://127.0.0.1:4173/` returns HTTP 200 and all local assets load.

- [x] **Step 2: Run the complete automated website gate**

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
git diff --check
```

Expected: all website tests PASS, syntax checks exit 0, and no whitespace errors.

- [x] **Step 3: Run App regression gates**

```bash
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check analyze
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check test
```

Expected: analyze has no issues. Record the exact Flutter test result; if the known `premium workout is queued and starts sync without waiting for network` timing race appears, rerun that exact test and report it without changing App code.

- [x] **Step 4: Verify browser layouts and defects**

Use agent-browser at `360×800`, `390×844`, `768×1024`, `1024×768`, `1440×1000`, and `844×390`.

For `zh-CN`, `en`, `de`, `pt-BR`, `ja`, and `ko`, assert with browser evaluation:

```js
({
  overflow: document.documentElement.scrollWidth - window.innerWidth,
  hiddenContent: [...document.querySelectorAll('.reveal')]
    .filter((node) => getComputedStyle(node).opacity === '0').length,
  verticalText: [...document.querySelectorAll('[data-i18n]')]
    .filter((node) => node.getBoundingClientRect().width < 16 && node.textContent.trim().length > 3)
    .length,
  apkActions: document.querySelector('[data-apk-placeholder]')
    .querySelectorAll('a,button').length,
})
```

Expected: all four values are `0` for overflow, hidden content, vertical text, and APK actions.

- [x] **Step 5: Inspect typography and touch targets**

At mobile widths, assert:

- body and section copy computed font size is at least `16px`;
- menu button, language select, nav links, FAQ summaries are at least `44px` tall;
- product-story horizontal scrolling is contained inside its gallery;
- direct `?lang=de#download` lands on the download region;
- no-JavaScript mode retains complete Chinese content and hides only the non-functional selector.

- [x] **Step 6: Capture and inspect final screenshots**

Capture full-page screenshots under `/tmp/pushupai-performance-editorial-qa/` for:

- Chinese desktop `1440×1000`;
- German mobile `390×844`;
- Brazilian Portuguese tablet `768×1024`;
- Japanese phone landscape `844×390`.

Scroll through once before each full-page capture only if needed for lazy-loaded screenshots; final content itself must already be visible.

- [x] **Step 7: Request focused review**

Ask the reviewer to compare `origin/main...HEAD` against:

- `docs/superpowers/specs/2026-07-12-pushupai-website-performance-editorial-redesign.md`;
- this plan.

Review priorities: remaining broad span selectors, missing/incorrect translations, content truth, accessibility, generated-asset safety, page length, no-JS behavior, responsive clipping, APK non-interactivity, and accidental App/Worker changes.

- [x] **Step 8: Address Critical/Important findings and rerun affected gates**

Add a regression test for every behavioral fix. Do not modify App/Worker code for website-only findings.

- [x] **Step 9: Mark completed checkboxes and inspect final scope**

```bash
git status --short
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
git diff --check origin/main...HEAD
```

Expected: only website assets/code/tests/readme and the redesign spec/plan are changed; no secret, APK, video, CSV, Flutter, or Worker files appear.

- [x] **Step 10: Commit the completed plan record**

```bash
git add docs/superpowers/plans/2026-07-12-pushupai-performance-editorial-redesign.md
git commit -m "docs: complete performance editorial redesign plan"
```

Keep `codex/pushupai-website` active. Do not merge, push, or delete the branch without explicit user authorization.
