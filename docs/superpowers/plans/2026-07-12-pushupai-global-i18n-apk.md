# PushupAI Global Website Localization and APK Download Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the PushupAI website to match the latest App facts, support eight switchable website languages, and add an explicitly unavailable Android APK QR-style download placeholder.

**Architecture:** Keep the current no-build static site and Chinese no-JavaScript fallback. Add a focused `locales.js` module containing locale metadata, complete translation dictionaries, and pure locale helpers; annotate the existing DOM with stable translation keys; let `main.js` apply translations, persistence, and shareable `?lang=` state without rebuilding interactive nodes. Extend only the existing download section with a non-interactive APK card and preserve current store-link security boundaries.

**Tech Stack:** Static HTML5, CSS, JavaScript ES modules, Node.js built-in test runner, local Chromium QA, Flutter regression commands.

---

## File responsibility map

| File | Responsibility |
|---|---|
| `website/locales.js` | Supported locale metadata, eight complete dictionaries, normalization, priority resolution, lookup, and locale URL helper. No DOM access. |
| `website/index.html` | Chinese fallback content, stable `data-i18n`/`data-i18n-attr` hooks, language selector, latest App copy, privacy links, and APK placeholder markup. |
| `website/main.js` | Existing menu/store/reveal behavior plus DOM translation application, safe storage access, initial locale selection, selector binding, and URL synchronization. |
| `website/styles.css` | Existing visual system plus language selector, long-copy resilience, three-channel download hub, and non-interactive QR-style APK placeholder. |
| `website/tests/website.test.mjs` | Locale contract, pure helper tests, DOM/runtime fakes, content truth boundaries, APK non-interactivity, resource checks, and no-JS progressive enhancement. |
| `website/README.md` | Supported website languages, selection precedence, translation maintenance, and future safe APK activation boundary. |
| `docs/superpowers/plans/2026-07-12-pushupai-global-i18n-apk.md` | Execution checklist and verification record. |

## Canonical translation key inventory

Every locale must contain the same flat key set. Use dot-separated names grouped below; all values are non-empty strings. English is the structural reference, Chinese values match the fallback HTML, and the other six languages must be idiomatic translations rather than word-for-word fragments.

```text
meta.title
meta.description
meta.ogTitle
meta.ogDescription
meta.ogLocale
skip.main
brand.home
brand.productName
menu.open
nav.label
nav.features
nav.ecosystem
nav.how
nav.faq
nav.download
header.status
language.label
hero.eyebrow
hero.titleAria
hero.titleLine1
hero.titleLine2
hero.titleLine3
hero.lede
download.channelsLabel
store.googleStatus
store.appleStatus
store.available
privacy.short
hero.previewLabel
hero.poseRecognized
hero.sessionLabel
hero.repsUnit
features.eyebrow
features.titleLine1
features.titleLine2
features.intro
features.countTitle
features.countBody
features.privacyTitle
features.privacyBody
features.recordsTitle
features.recordsBody
showcase.eyebrow
showcase.title
showcase.intro
showcase.galleryLabel
showcase.homeAlt
showcase.workoutAlt
showcase.recordsAlt
showcase.start
showcase.recognize
showcase.record
ecosystem.eyebrow
ecosystem.titleAria
ecosystem.titleLine1
ecosystem.titleLine2
ecosystem.intro
ecosystem.recordKicker
ecosystem.syncTitle
ecosystem.syncBody
ecosystem.synced
ecosystem.plazaKicker
ecosystem.rankingTitle
ecosystem.rankingBody
ecosystem.accountKicker
ecosystem.accountTitle
ecosystem.accountBody
ecosystem.interfaceKicker
ecosystem.interfaceTitle
ecosystem.interfaceBody
steps.eyebrow
steps.title
steps.intro
steps.fixTitle
steps.fixBody
steps.noticeTitle
steps.noticeBody
steps.trainTitle
steps.trainBody
steps.scope
faq.eyebrow
faq.title
faq.intro
faq.positionQuestion
faq.positionAnswer
faq.privacyQuestion
faq.privacyAnswerBefore
faq.privacyPolicy
faq.privacyAnswerMiddle
faq.accountDeletion
faq.privacyAnswerAfter
faq.actionsQuestion
faq.actionsAnswer
faq.syncQuestion
faq.syncAnswer
faq.downloadQuestion
faq.downloadAnswer
download.eyebrow
download.titleLine1
download.titleLine2
download.intro
apk.kicker
apk.title
apk.body
apk.status
apk.placeholder
footer.top
footer.summary
footer.privacySummary
footer.linksLabel
footer.privacyPolicy
footer.accountDeletion
```

Use these exact locale-specific product terms consistently:

| Concept | zh-CN | en | es | fr | de | pt-BR | ja | ko |
|---|---|---|---|---|---|---|---|---|
| Push-up | 俯卧撑 | push-up | flexión | pompe | Liegestütz | flexão | 腕立て伏せ | 푸시업 |
| On-device | 设备端 | on-device | en el dispositivo | sur l’appareil | auf dem Gerät | no dispositivo | デバイス上 | 기기 내 |
| Sports Plaza | 运动广场 | Sports Plaza | Plaza deportiva | Espace sportif | Sportplatz | Praça esportiva | スポーツ広場 | 운동 광장 |
| Premium | Premium 会员 | Premium | Premium | Premium | Premium | Premium | Premium | Premium |

The App-language sentence must explicitly state that the **App interface** supports only Chinese and English in every locale.

---

### Task 1: Locale data model and pure selection logic

**Files:**
- Create: `website/locales.js`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add failing locale metadata and parity tests**

Append imports and tests that define the public module contract:

```js
const {
  DEFAULT_LOCALE,
  LOCALE_STORAGE_KEY,
  LOCALES,
  TRANSLATIONS,
  normalizeLocale,
  resolveLocale,
  translate,
  urlWithLocale,
} = await import('../locales.js');

test('website supports the approved eight locales with complete dictionaries', () => {
  assert.equal(DEFAULT_LOCALE, 'en');
  assert.equal(LOCALE_STORAGE_KEY, 'pushupai.locale');
  assert.deepEqual(
    LOCALES.map(({ code }) => code),
    ['zh-CN', 'en', 'es', 'fr', 'de', 'pt-BR', 'ja', 'ko'],
  );
  const englishKeys = Object.keys(TRANSLATIONS.en).sort();
  assert.ok(englishKeys.length >= 100);
  for (const { code } of LOCALES) {
    assert.deepEqual(Object.keys(TRANSLATIONS[code]).sort(), englishKeys);
    assert.ok(
      Object.values(TRANSLATIONS[code]).every(
        (value) => typeof value === 'string' && value.trim().length > 0,
      ),
    );
  }
});

test('locale normalization accepts supported regional variants', () => {
  assert.equal(normalizeLocale('zh-SG'), 'zh-CN');
  assert.equal(normalizeLocale('pt'), 'pt-BR');
  assert.equal(normalizeLocale('fr-CA'), 'fr');
  assert.equal(normalizeLocale('JA-jp'), 'ja');
  assert.equal(normalizeLocale('ar'), null);
  assert.equal(normalizeLocale(''), null);
});

test('locale resolution follows URL, storage, browser, then English priority', () => {
  assert.equal(
    resolveLocale({
      urlLocale: 'de',
      storedLocale: 'fr',
      browserLocales: ['es-MX'],
    }),
    'de',
  );
  assert.equal(
    resolveLocale({
      urlLocale: 'invalid',
      storedLocale: 'fr',
      browserLocales: ['es-MX'],
    }),
    'fr',
  );
  assert.equal(
    resolveLocale({ storedLocale: '', browserLocales: ['es-MX', 'en-US'] }),
    'es',
  );
  assert.equal(resolveLocale({ browserLocales: ['ar-SA'] }), 'en');
});

test('translation lookup falls back to English without accepting unknown keys', () => {
  assert.equal(translate('de', 'nav.download'), TRANSLATIONS.de['nav.download']);
  assert.equal(translate('ar', 'nav.download'), TRANSLATIONS.en['nav.download']);
  assert.equal(translate('es', 'missing.key'), '');
});

test('locale URLs preserve existing query values and anchors', () => {
  assert.equal(
    urlWithLocale('https://pushup.ai/?ref=home#faq', 'pt-BR'),
    'https://pushup.ai/?ref=home&lang=pt-BR#faq',
  );
});
```

- [ ] **Step 2: Run the tests and verify the module contract is red**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL because `website/locales.js` does not exist.

- [ ] **Step 3: Create the pure locale module**

Create the module with this public shape and exact normalization behavior:

```js
export const DEFAULT_LOCALE = 'en';
export const LOCALE_STORAGE_KEY = 'pushupai.locale';

export const LOCALES = Object.freeze([
  Object.freeze({ code: 'zh-CN', label: '简体中文', htmlLang: 'zh-CN' }),
  Object.freeze({ code: 'en', label: 'English', htmlLang: 'en' }),
  Object.freeze({ code: 'es', label: 'Español', htmlLang: 'es' }),
  Object.freeze({ code: 'fr', label: 'Français', htmlLang: 'fr' }),
  Object.freeze({ code: 'de', label: 'Deutsch', htmlLang: 'de' }),
  Object.freeze({ code: 'pt-BR', label: 'Português (Brasil)', htmlLang: 'pt-BR' }),
  Object.freeze({ code: 'ja', label: '日本語', htmlLang: 'ja' }),
  Object.freeze({ code: 'ko', label: '한국어', htmlLang: 'ko' }),
]);

const aliases = Object.freeze({
  zh: 'zh-CN',
  en: 'en',
  es: 'es',
  fr: 'fr',
  de: 'de',
  pt: 'pt-BR',
  ja: 'ja',
  ko: 'ko',
});

export function normalizeLocale(value) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const candidate = value.trim();
  const exact = LOCALES.find(
    ({ code }) => code.toLowerCase() === candidate.toLowerCase(),
  );
  if (exact) return exact.code;
  return aliases[candidate.toLowerCase().split('-')[0]] ?? null;
}

export function resolveLocale({
  urlLocale,
  storedLocale,
  browserLocales = [],
} = {}) {
  for (const candidate of [urlLocale, storedLocale, ...browserLocales]) {
    const locale = normalizeLocale(candidate);
    if (locale) return locale;
  }
  return DEFAULT_LOCALE;
}

export function urlWithLocale(href, locale) {
  const url = new URL(href);
  url.searchParams.set('lang', normalizeLocale(locale) ?? DEFAULT_LOCALE);
  return url.href;
}
```

Add `TRANSLATIONS` as a deeply immutable object with the complete canonical key inventory. Use English as the fallback reference, preserve the exact current Chinese fallback meaning, and supply idiomatic Spanish, French, German, Brazilian Portuguese, Japanese, and Korean values. Implement lookup as:

```js
export function translate(locale, key) {
  const normalized = normalizeLocale(locale) ?? DEFAULT_LOCALE;
  return TRANSLATIONS[normalized]?.[key] ?? TRANSLATIONS.en[key] ?? '';
}
```

Freeze every locale dictionary and the outer dictionary. Do not include HTML, URLs, store IDs, or executable strings in translations.

- [ ] **Step 4: Run locale tests and syntax check**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/locales.js
```

Expected: all existing tests plus the five new locale tests PASS.

- [ ] **Step 5: Commit the locale foundation**

```bash
git add website/locales.js website/tests/website.test.mjs
git commit -m "feat: add website locale foundation"
```

---

### Task 2: Latest App copy, translation hooks, privacy links, and APK structure

**Files:**
- Modify: `website/index.html`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add failing structural and product-truth tests**

Add tests that require the new HTML contract:

```js
test('markup exposes locale controls and every translation key exists', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  assert.match(html, /<select[^>]*data-language-select/);
  for (const locale of LOCALES) {
    assert.match(html, new RegExp(`<option value="${locale.code}"`));
  }
  const textKeys = [...html.matchAll(/data-i18n="([^"]+)"/g)].map(
    (match) => match[1],
  );
  const attributeKeys = [
    ...html.matchAll(/data-i18n-attr="([^"]+)"/g),
  ].flatMap((match) =>
    match[1].split(';').map((entry) => entry.split(':').slice(1).join(':')),
  );
  for (const key of [...textKeys, ...attributeKeys]) {
    assert.ok(TRANSLATIONS.en[key], `missing translation key: ${key}`);
  }
});

test('latest product facts and privacy routes are represented truthfully', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const expected of [
    'Alpha 封闭测试',
    '周、月、年',
    '匿名展示',
    '训练开始前',
    '近距离',
    '应用内当前支持中文和英文',
  ]) {
    assert.match(html, new RegExp(expected));
  }
  assert.match(
    html,
    /href="https:\/\/pushupai-privacy\.pages\.dev\/"[^>]*target="_blank"[^>]*rel="noreferrer"/,
  );
  assert.match(
    html,
    /href="https:\/\/pushupai-privacy\.pages\.dev\/#account-deletion"[^>]*target="_blank"[^>]*rel="noreferrer"/,
  );
});

test('APK download card is explicit, local, and non-interactive', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const card = html.match(
    /<article[^>]*data-apk-placeholder[\s\S]*?<\/article>/,
  )?.[0];
  assert.ok(card);
  assert.match(card, /Android APK/);
  assert.match(card, /data-qr-placeholder[^>]*aria-hidden="true"/);
  assert.doesNotMatch(card, /<a\b|href=|data:|\.apk\b|https?:\/\//);
});
```

Update the previous approved-copy assertions so they expect the latest wording rather than the old generic store-preparation sentence.

- [ ] **Step 2: Run tests and confirm the new markup requirements fail**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL for missing selector, latest product copy, privacy links, and APK card.

- [ ] **Step 3: Add translation hooks to the document shell and header**

Implement these exact structural rules:

```html
<html lang="zh-CN">
  <head>
    <meta
      name="description"
      content="PushupAI 使用端侧 AI 实时识别俯卧撑动作，自动计数、中文语音播报并记录训练。"
      data-i18n-attr="content:meta.description"
    >
    <meta property="og:title" content="PushupAI · AI俯卧撑" data-i18n-attr="content:meta.ogTitle">
    <meta property="og:description" content="架好手机，专心做好每一次。" data-i18n-attr="content:meta.ogDescription">
    <meta property="og:locale" content="zh_CN" data-i18n-attr="content:meta.ogLocale">
    <title data-i18n="meta.title">PushupAI · AI俯卧撑</title>
  </head>
```

Add text and attribute hooks to the skip link, brand labels, menu button, nav links, and CTA. Place exactly one language selector as the final child of `#site-nav`:

```html
<label class="language-picker" data-language-picker>
  <span class="sr-only" data-i18n="language.label">选择语言</span>
  <svg viewBox="0 0 24 24" aria-hidden="true">
    <circle cx="12" cy="12" r="9"></circle>
    <path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"></path>
  </svg>
  <select data-language-select aria-label="选择语言" data-i18n-attr="aria-label:language.label">
    <option value="zh-CN">简体中文</option>
    <option value="en">English</option>
    <option value="es">Español</option>
    <option value="fr">Français</option>
    <option value="de">Deutsch</option>
    <option value="pt-BR">Português (Brasil)</option>
    <option value="ja">日本語</option>
    <option value="ko">한국어</option>
  </select>
</label>
```

- [ ] **Step 4: Annotate every remaining visible and accessible string**

Use only keys from the canonical inventory. For plain nodes add `data-i18n`. For multiline headings keep explicit line spans:

```html
<h1 id="hero-title" data-i18n-attr="aria-label:hero.titleAria">
  <span data-i18n="hero.titleLine1">架好手机，</span><br>
  <span data-i18n="hero.titleLine2">专心做好</span><br>
  <span data-i18n="hero.titleLine3">每一次。</span>
</h1>
```

For images and labelled containers use the approved attribute syntax:

```html
<div class="phone-gallery" aria-label="App 页面展示" data-i18n-attr="aria-label:showcase.galleryLabel">
<img src="assets/app-home.png" alt="AI俯卧撑首页" data-i18n-attr="alt:showcase.homeAlt">
```

Do not place translation hooks on brand names, numbers, `Google Play`, `App Store`, `Android APK`, `PushupAI`, or copyright year unless their surrounding status text is translated separately.

- [ ] **Step 5: Update existing sections to the latest truthful App copy**

Change the Chinese fallback content according to the design spec:

- Counting card: count on full return to the top and tolerate short elbow/wrist/arm dropouts at close range; retain fixed-front-camera limitations.
- Records card: explicitly say week, month, and year views.
- Sports Plaza: explicitly say public rows are anonymous.
- Interface card: say the **App interface currently supports Chinese and English**.
- Step 2: mention the on-device camera notice is confirmed before training starts.
- Privacy FAQ: state original frames are not uploaded, then include the two safe external links.
- Download FAQ and download section: Google Play Alpha closed testing, App Store preparation, APK placeholder.

Keep all Premium boundaries and avoid efficacy, download-count, user-count, pricing, trial, or availability claims.

- [ ] **Step 6: Add the non-interactive APK card**

Inside the download section, wrap current content in `.download-layout` and add:

```html
<article class="apk-card reveal" data-apk-placeholder>
  <div class="apk-card-copy">
    <span class="apk-kicker" data-i18n="apk.kicker">Android 直接安装</span>
    <div class="apk-title-row">
      <svg viewBox="0 0 48 48" aria-hidden="true">
        <path d="M14 17h20v18a4 4 0 0 1-4 4H18a4 4 0 0 1-4-4V17Zm4-7-3-5m15 5 3-5M17 14h14a7 7 0 0 0-14 0Z"></path>
        <circle cx="21" cy="14" r="1"></circle>
        <circle cx="27" cy="14" r="1"></circle>
      </svg>
      <h3 data-i18n="apk.title">Android APK</h3>
    </div>
    <p data-i18n="apk.body">未来可用 Android 手机扫码下载并直接安装。</p>
    <span class="apk-status" data-i18n="apk.status">APK 即将提供</span>
  </div>
  <div
    class="qr-placeholder"
    data-qr-placeholder
    aria-hidden="true"
  >
    <span class="qr-corner qr-corner-one"></span>
    <span class="qr-corner qr-corner-two"></span>
    <span class="qr-corner qr-corner-three"></span>
    <span class="qr-noise qr-noise-one"></span>
    <span class="qr-noise qr-noise-two"></span>
    <strong>APK</strong>
  </div>
  <p class="apk-placeholder-note" data-i18n="apk.placeholder">当前无可扫描下载</p>
</article>
```

The card must remain an `<article>`, not a link or button.

- [ ] **Step 7: Add privacy links to the footer and run structural tests**

Use the exact published URLs and attributes:

```html
<nav class="footer-links" aria-label="隐私与账号" data-i18n-attr="aria-label:footer.linksLabel">
  <a href="https://pushupai-privacy.pages.dev/" target="_blank" rel="noreferrer" data-i18n="footer.privacyPolicy">隐私政策</a>
  <a href="https://pushupai-privacy.pages.dev/#account-deletion" target="_blank" rel="noreferrer" data-i18n="footer.accountDeletion">账号删除</a>
</nav>
```

Run:

```bash
node --test website/tests/website.test.mjs
git diff --check
```

Expected: structural, product-truth, privacy-link, and APK tests PASS. Runtime locale tests may remain red until Task 3.

- [ ] **Step 8: Commit the translated document contract**

```bash
git add website/index.html website/tests/website.test.mjs
git commit -m "feat: update global website content"
```

---

### Task 3: Runtime locale application, persistence, and shareable state

**Files:**
- Modify: `website/main.js`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add failing translation application tests with lightweight DOM fakes**

Extend the `main.js` import and add focused tests:

```js
const {
  applyLocale,
  getInitialLocale,
  readStoredLocale,
  writeStoredLocale,
} = await import('../main.js');

test('locale application updates text, approved attributes, lang, and selector', () => {
  const textNode = {
    dataset: { i18n: 'nav.download' },
    value: '',
    replaceChildren(value) { this.value = value; },
  };
  const attributeNode = {
    dataset: { i18nAttr: 'aria-label:language.label' },
    values: new Map(),
    setAttribute(name, value) { this.values.set(name, value); },
  };
  const selector = { value: '' };
  const root = {
    documentElement: { lang: '' },
    querySelectorAll(query) {
      if (query === '[data-i18n]') return [textNode];
      if (query === '[data-i18n-attr]') return [attributeNode];
      return [];
    },
    querySelector(query) {
      return query === '[data-language-select]' ? selector : null;
    },
  };

  applyLocale(root, 'es');

  assert.equal(root.documentElement.lang, 'es');
  assert.equal(textNode.value, TRANSLATIONS.es['nav.download']);
  assert.equal(
    attributeNode.values.get('aria-label'),
    TRANSLATIONS.es['language.label'],
  );
  assert.equal(selector.value, 'es');
});

test('storage helpers tolerate unavailable browser storage', () => {
  const brokenStorage = {
    getItem() { throw new Error('blocked'); },
    setItem() { throw new Error('blocked'); },
  };
  assert.equal(readStoredLocale(brokenStorage), null);
  assert.equal(writeStoredLocale(brokenStorage, 'fr'), false);
});

test('initial locale reads URL before storage and browser preferences', () => {
  const storage = { getItem: () => 'fr' };
  assert.equal(
    getInitialLocale({
      href: 'https://pushup.ai/?lang=ja',
      storage,
      browserLocales: ['de-DE'],
    }),
    'ja',
  );
});
```

- [ ] **Step 2: Run tests and confirm runtime functions are red**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL because the four runtime exports do not exist.

- [ ] **Step 3: Implement safe storage and initial resolution**

At the top of `main.js`, import locale helpers:

```js
import {
  LOCALE_STORAGE_KEY,
  LOCALES,
  resolveLocale,
  translate,
  urlWithLocale,
} from './locales.js';
```

Implement:

```js
export function readStoredLocale(storage) {
  try {
    return storage?.getItem(LOCALE_STORAGE_KEY) ?? null;
  } catch {
    return null;
  }
}

export function writeStoredLocale(storage, locale) {
  try {
    storage?.setItem(LOCALE_STORAGE_KEY, locale);
    return true;
  } catch {
    return false;
  }
}

export function getInitialLocale({ href, storage, browserLocales = [] }) {
  let urlLocale = null;
  try {
    urlLocale = new URL(href).searchParams.get('lang');
  } catch {
    urlLocale = null;
  }
  return resolveLocale({
    urlLocale,
    storedLocale: readStoredLocale(storage),
    browserLocales,
  });
}
```

- [ ] **Step 4: Implement the restricted DOM translation writer**

Allow only the four approved attributes and never write translated values to URLs:

```js
const translatedAttributes = new Set([
  'aria-label',
  'alt',
  'content',
  'title',
]);

export function applyLocale(root, locale) {
  const metadata = LOCALES.find(({ code }) => code === locale) ?? LOCALES[1];
  root.documentElement.lang = metadata.htmlLang;

  for (const node of root.querySelectorAll('[data-i18n]')) {
    const value = translate(locale, node.dataset.i18n);
    if (value) node.replaceChildren(value);
  }

  for (const node of root.querySelectorAll('[data-i18n-attr]')) {
    for (const mapping of node.dataset.i18nAttr.split(';')) {
      const separator = mapping.indexOf(':');
      if (separator < 1) continue;
      const attribute = mapping.slice(0, separator);
      const key = mapping.slice(separator + 1);
      if (!translatedAttributes.has(attribute)) continue;
      const value = translate(locale, key);
      if (value) node.setAttribute(attribute, value);
    }
  }

  const selector = root.querySelector('[data-language-select]');
  if (selector) selector.value = metadata.code;
  return metadata.code;
}
```

- [ ] **Step 5: Bind initial selection and user changes without rebuilding nodes**

Add `setupLocale(root, browserWindow)` and call it near the start of `setupPage()`:

```js
export function setupLocale(root, browserWindow) {
  const locale = getInitialLocale({
    href: browserWindow.location.href,
    storage: browserWindow.localStorage,
    browserLocales: browserWindow.navigator.languages?.length
      ? browserWindow.navigator.languages
      : [browserWindow.navigator.language],
  });
  applyLocale(root, locale);

  root.querySelector('[data-language-select]')?.addEventListener(
    'change',
    ({ currentTarget }) => {
      const nextLocale = applyLocale(root, currentTarget.value);
      writeStoredLocale(browserWindow.localStorage, nextLocale);
      const nextUrl = urlWithLocale(browserWindow.location.href, nextLocale);
      browserWindow.history.replaceState(null, '', nextUrl);
    },
  );
}
```

Keep `setupPage()` browser-only and preserve existing menu, store-link, year, reveal, Escape, and reduced-motion behavior. Remove the hardcoded `立即下载` replacement from `enhanceStoreLinks`; the localized `<em data-i18n="store.available">` text is now controlled by `applyLocale`.

- [ ] **Step 6: Run all website tests and syntax checks**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
git diff --check
```

Expected: all tests PASS and all syntax checks exit 0.

- [ ] **Step 7: Commit locale runtime**

```bash
git add website/main.js website/tests/website.test.mjs
git commit -m "feat: add website language switching"
```

---

### Task 4: Language selector and APK download-hub styling

**Files:**
- Modify: `website/styles.css`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add failing static CSS-contract tests**

Add:

```js
test('global controls and APK hub have responsive progressive styles', async () => {
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  for (const selector of [
    '.language-picker',
    '.has-js .language-picker',
    '.download-layout',
    '.apk-card',
    '.qr-placeholder',
    '.apk-status',
    '.footer-links',
  ]) {
    assert.match(css, new RegExp(selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
  assert.match(css, /@media \(max-width:900px\)[\s\S]*\.language-picker/);
  assert.match(css, /@media \(max-width:640px\)[\s\S]*\.apk-card/);
});
```

- [ ] **Step 2: Run tests and confirm missing styles fail**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL for missing language/APK selectors.

- [ ] **Step 3: Style the progressive language picker**

Add base rules near the header/nav styles:

```css
.language-picker {
  display: none;
  position: relative;
  align-items: center;
  min-height: 44px;
  color: var(--ink);
}

.has-js .language-picker { display: inline-flex; }
.language-picker svg {
  position: absolute;
  left: 12px;
  width: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 1.7;
  pointer-events: none;
}
.language-picker select {
  min-height: 44px;
  max-width: 180px;
  padding: 0 34px 0 38px;
  border: 1px solid var(--line);
  border-radius: 999px;
  background: var(--surface);
  color: var(--ink);
  font: inherit;
  font-size: 13px;
  font-weight: 760;
  cursor: pointer;
}
.language-picker select:focus-visible {
  outline: 3px solid color-mix(in srgb, var(--green) 65%, transparent);
  outline-offset: 2px;
}
```

At `max-width:900px`, make the picker full-width inside the expanded nav and keep the select width at 100%. Do not display it when `.has-js` is absent.

- [ ] **Step 4: Convert the download section to a responsive two-column hub**

Add:

```css
.download-layout {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(320px, 0.72fr);
  gap: clamp(32px, 6vw, 88px);
  align-items: center;
  width: min(1180px, calc(100% - 48px));
  margin-inline: auto;
}
.download-primary { min-width: 0; }
.apk-card {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 176px;
  gap: 24px;
  align-items: center;
  padding: clamp(24px, 4vw, 40px);
  border: 1px solid color-mix(in srgb, var(--lime) 35%, transparent);
  border-radius: 28px;
  background: color-mix(in srgb, var(--ink) 88%, transparent);
  color: var(--paper);
  box-shadow: 0 28px 70px rgba(0, 0, 0, 0.24);
}
.apk-title-row { display: flex; align-items: center; gap: 12px; }
.apk-title-row svg {
  width: 34px;
  fill: none;
  stroke: var(--lime);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.apk-kicker,
.apk-status {
  display: inline-flex;
  width: fit-content;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 850;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.apk-status { padding: 9px 12px; background: var(--lime); color: var(--ink); }
.qr-placeholder {
  position: relative;
  width: 176px;
  aspect-ratio: 1;
  border-radius: 18px;
  background: var(--paper);
  overflow: hidden;
}
.qr-placeholder strong {
  position: absolute;
  inset: 50% auto auto 50%;
  transform: translate(-50%, -50%);
  display: grid;
  place-items: center;
  width: 72px;
  aspect-ratio: 1;
  border-radius: 20px;
  background: var(--lime);
  color: var(--ink);
  font-size: 20px;
}
```

Style the three intentionally incomplete QR corners/noise elements as large geometric blocks without a standards-compliant QR finder pattern. Place `.apk-placeholder-note` beneath the visual with centered high-contrast text.

- [ ] **Step 5: Add tablet, phone, landscape, footer, and long-copy rules**

- At `max-width:1020px`, stack `.download-layout` and cap `.apk-card` width at 720px.
- At `max-width:900px`, let the expanded nav wrap long German/French labels and put `.language-picker` last at full width.
- At `max-width:640px`, make `.apk-card` one column, center the QR placeholder, set store buttons to full width, and reduce card padding without shrinking body text below 16px.
- Add `overflow-wrap:anywhere` only to long status/body/link text, not headings globally.
- Add `.footer-links` flex/wrap styles with visible hover/focus states.
- Preserve the existing reduced-motion block and do not animate the QR placeholder.

- [ ] **Step 6: Run tests and inspect CSS for selector collisions**

Run:

```bash
node --test website/tests/website.test.mjs
git diff --check
rg -n "language-picker|download-layout|apk-card|qr-placeholder|footer-links" website/styles.css
```

Expected: tests PASS; every new selector has one base definition plus intentional media overrides.

- [ ] **Step 7: Commit global responsive styles**

```bash
git add website/styles.css website/tests/website.test.mjs
git commit -m "feat: style global download experience"
```

---

### Task 5: Maintenance documentation and automated completion gate

**Files:**
- Modify: `website/README.md`
- Modify: `website/tests/website.test.mjs`

- [ ] **Step 1: Add README requirements to the production-resource test**

Require the README to mention the locale module, eight locale codes, URL precedence, no-JS Chinese fallback, and the disabled APK boundary:

```js
test('website maintenance guide documents locales and APK activation boundary', async () => {
  const readme = await readFile(path.join(websiteRoot, 'README.md'), 'utf8');
  for (const expected of [
    'locales.js',
    'zh-CN',
    'pt-BR',
    '?lang=',
    'localStorage',
    'JavaScript',
    'Android APK',
    'SHA-256',
  ]) {
    assert.match(readme, new RegExp(expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
});
```

- [ ] **Step 2: Run tests and confirm documentation coverage fails**

Run: `node --test website/tests/website.test.mjs`

Expected: FAIL because the README does not yet document locale/APK behavior.

- [ ] **Step 3: Document locale maintenance**

Add a section that states:

- supported locale codes and native selector labels;
- precedence: `?lang=` → `pushupai.locale` in `localStorage` → browser languages → English;
- Chinese HTML remains the complete no-JavaScript fallback;
- every dictionary must keep exact key parity with English;
- website locale count does not change the App’s Chinese/English interface support;
- new locales require automated parity tests and 360/768/1440px browser QA.

- [ ] **Step 4: Document future APK activation safety**

State that activation requires all of these before any link or real QR is added:

1. signed release APK from the authorized release workflow;
2. stable HTTPS URL controlled by the project;
3. visible version name/version code;
4. published SHA-256 checksum;
5. replacement of the non-scannable placeholder with a QR generated from that exact HTTPS URL;
6. browser and Android-device verification.

Explicitly prohibit committing APK binaries or placeholder/fake URLs to this repository.

- [ ] **Step 5: Run the complete website gate**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
git diff --check
```

Expected: all tests PASS, all syntax checks exit 0, and `git diff --check` has no output.

- [ ] **Step 6: Commit documentation**

```bash
git add website/README.md website/tests/website.test.mjs
git commit -m "docs: explain website locales and APK releases"
```

---

### Task 6: Browser QA, App regression, review, and branch handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-12-pushupai-global-i18n-apk.md`

- [ ] **Step 1: Start a local HTTP server**

Run:

```bash
python3 -m http.server 4173 --bind 127.0.0.1 --directory website
```

Expected: `http://127.0.0.1:4173/` returns the production website and ES modules load without CORS/file restrictions.

- [ ] **Step 2: Verify every locale and selection priority**

For each of `zh-CN`, `en`, `es`, `fr`, `de`, `pt-BR`, `ja`, and `ko`:

- open `/?lang=<locale>`;
- assert `<html lang>` and selector value;
- assert translated title, nav, hero, FAQ, download text, privacy links, and APK status;
- switch to another locale and assert URL/localStorage update without reload;
- reload and confirm URL wins over stored locale;
- open without `?lang=` and confirm stored locale wins;
- clear storage and emulate a supported browser locale;
- emulate an unsupported browser locale and confirm English.

Expected: all priority and translation assertions pass; console/page errors remain empty.

- [ ] **Step 3: Verify responsive and accessible behavior**

At 360px, 768px, 1440px, and a phone-landscape viewport:

- assert `document.documentElement.scrollWidth === window.innerWidth`;
- open/close the mobile menu and verify all five links plus language selector;
- verify Escape closes menu and restores focus;
- use keyboard to change the native select and open the first FAQ detail;
- inspect German, French, and Brazilian Portuguese for clipping or illegible shrinkage;
- confirm language and menu touch targets are at least 44px high;
- confirm APK card is an article with no link/button role and QR visual is `aria-hidden`;
- emulate reduced motion and confirm no content remains hidden.

Capture full-page desktop and mobile screenshots under `/tmp/pushupai-global-qa/` for visual inspection; do not add them to Git.

- [ ] **Step 4: Verify no-JavaScript fallback**

Block `main.js` at 768px and assert:

- `document.documentElement.classList` lacks `has-js`;
- Chinese content is complete;
- all five nav links are visible;
- the language selector is hidden;
- store controls remain disabled;
- APK card remains visible and non-interactive;
- no horizontal overflow.

- [ ] **Step 5: Run fresh automated and App regression commands**

Run:

```bash
node --test website/tests/website.test.mjs
node --check website/main.js
node --check website/locales.js
node --check website/store-links.js
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check analyze
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter --no-version-check test
git diff --check
```

Expected: website tests and analyze pass. For Flutter tests, record the exact result; if the known `premium workout is queued and starts sync without waiting for network` race appears, rerun that exact test to document its pre-existing timing behavior without modifying App code.

- [ ] **Step 6: Request a focused code review**

Ask the reviewer to compare the implementation with:

- `docs/superpowers/specs/2026-07-12-pushupai-global-i18n-apk-design.md`
- this implementation plan;
- `origin/main...HEAD`.

Review priorities: missing translations, content truth, DOM injection boundaries, URL/storage error handling, accessibility, no-JS degradation, fake QR safety, responsive long-copy layout, and accidental App/Worker scope changes.

- [ ] **Step 7: Address Critical/Important findings and rerun the relevant gates**

Make only findings-backed changes. Add regression tests for every behavioral fix and rerun the complete website gate plus browser scenario affected by the finding.

- [ ] **Step 8: Mark every completed checkbox and inspect final scope**

Update this plan from `[ ]` to `[x]` only for executed steps, then run:

```bash
git status --short
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
git diff --check origin/main...HEAD
```

Expected: scope contains website files and the two design/plan documents only; no Flutter, Worker, secret, APK, video, or CSV files.

- [ ] **Step 9: Commit the completed plan record**

```bash
git add docs/superpowers/plans/2026-07-12-pushupai-global-i18n-apk.md
git commit -m "docs: complete global website implementation plan"
```

Keep `codex/pushupai-website` as the active branch. Do not merge, push, or delete the branch without explicit user authorization.
