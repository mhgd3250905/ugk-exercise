import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const websiteRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

test('landing page contains the approved brand, claims, sections, and store controls', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const expected of [
    'PushupAI',
    'AI俯卧撑',
    '架好手机，专心做好每一次。',
    '端侧 AI',
    '视频帧不上传',
    'data-store="googlePlay"',
    'data-store="appStore"',
    'id="features"',
    'id="ecosystem"',
    'id="how-it-works"',
    'id="faq"',
    'id="download"',
    'href="#ecosystem"',
    'href="#faq"',
    '不只记住这一次，也陪你坚持下一次。',
    '训练记录与云端同步',
    '运动广场',
    '一个账号，恢复权益',
    '跟随你的设备',
  ]) {
    assert.match(html, new RegExp(expected));
  }
});

test('landing page uses the approved six-region editorial structure', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const regions = [...html.matchAll(/data-region="([^"]+)"/g)].map(
    (match) => match[1],
  );

  assert.deepEqual(regions, [
    'hero',
    'capabilities',
    'product-story',
    'ecosystem',
    'support',
    'download',
  ]);

  const support = html.match(
    /<section[^>]*data-region="support"[^>]*>([\s\S]*?)<\/section>/,
  )?.[1];
  assert.ok(support);
  const stepsIndex = support.indexOf('id="how-it-works"');
  const faqIndex = support.indexOf('id="faq"');
  assert.ok(stepsIndex >= 0);
  assert.ok(faqIndex > stepsIndex);
});

test('all real app screenshots are project-local assets', async () => {
  for (const asset of [
    'app-home.png',
    'app-workout.png',
    'app-records.png',
  ]) {
    await access(path.join(websiteRoot, 'assets', asset));
  }
});

test('all supporting brand assets are project-local', async () => {
  for (const asset of ['favicon.svg', 'pushup-motion-bg.webp']) {
    await access(path.join(websiteRoot, 'assets', asset));
  }
});

test('translated labels cannot inherit decorative dot styles', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.equal(
    (html.match(/class="eyebrow-dot" aria-hidden="true"/g) ?? []).length,
    6,
  );
  const translatedSpans =
    html.match(/<span\b[^>]*data-i18n="[^"]+"[^>]*>/g) ?? [];
  assert.ok(translatedSpans.length > 0);
  for (const span of translatedSpans) {
    assert.doesNotMatch(
      span,
      /class="[^"]*\b(?:eyebrow|motion|privacy)-dot\b[^"]*"/,
    );
  }
  assert.match(html, /class="motion-dot" aria-hidden="true"/);
  assert.match(html, /class="privacy-dot" aria-hidden="true"/);
  assert.doesNotMatch(css, /\.eyebrow\s*(?:>\s*)?span\s*\{/);
  assert.doesNotMatch(css, /\.motion-label\s*(?:>\s*)?span\s*\{/);
  assert.doesNotMatch(css, /\.privacy-note\s*(?:>\s*)?span\s*\{/);
});

const { getStoreLinkState, STORE_LINKS } = await import('../store-links.js');
const mainModule = await import('../main.js');
const {
  applyLocale,
  enhanceStoreLinks,
  getInitialLocale,
  readStoredLocale,
  restoreHashTarget,
  writeStoredLocale,
} = mainModule;
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

test('locale runtime resolves URL, storage, and browser preferences', () => {
  const storage = {
    getItem(key) {
      assert.equal(key, LOCALE_STORAGE_KEY);
      return 'fr';
    },
  };
  assert.equal(
    getInitialLocale({
      location: { href: 'https://pushup.ai/?lang=de#faq' },
      localStorage: storage,
      navigator: { languages: ['es-MX'] },
    }),
    'de',
  );
  assert.equal(
    getInitialLocale({
      location: { href: 'https://pushup.ai/' },
      localStorage: storage,
      navigator: { languages: ['es-MX'] },
    }),
    'fr',
  );
  assert.equal(
    getInitialLocale({
      location: { href: 'https://pushup.ai/' },
      navigator: { languages: [], language: 'ja-JP' },
    }),
    'ja',
  );
});

test('locale storage helpers tolerate unavailable browser storage', () => {
  const values = new Map();
  const storage = {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
  writeStoredLocale(storage, 'pt-BR');
  assert.equal(readStoredLocale(storage), 'pt-BR');
  assert.equal(readStoredLocale({ getItem: () => { throw new Error('denied'); } }), null);
  assert.doesNotThrow(() =>
    writeStoredLocale({ setItem: () => { throw new Error('denied'); } }, 'ja'),
  );
  const storageDeniedWindow = {
    location: { href: 'https://pushup.ai/' },
    navigator: { languages: ['en-US'] },
    get localStorage() {
      throw new DOMException('denied', 'SecurityError');
    },
  };
  assert.doesNotThrow(() => getInitialLocale(storageDeniedWindow));
  assert.equal(getInitialLocale(storageDeniedWindow), 'en');
});

test('locale application updates text and only approved attributes', () => {
  const textNode = { dataset: { i18n: 'nav.download' }, replaceChildren(value) { this.text = value; } };
  const attributeNode = {
    dataset: { i18nAttr: 'aria-label:language.label;href:nav.download;content:meta.description' },
    attributes: new Map(),
    setAttribute(name, value) { this.attributes.set(name, value); },
  };
  const selector = { value: '' };
  const root = {
    documentElement: { lang: '' },
    querySelectorAll(selectorValue) {
      if (selectorValue === '[data-i18n]') return [textNode];
      if (selectorValue === '[data-i18n-attr]') return [attributeNode];
      return [];
    },
    querySelector(selectorValue) {
      return selectorValue === '[data-language-select]' ? selector : null;
    },
  };

  applyLocale(root, 'de');

  assert.equal(root.documentElement.lang, 'de');
  assert.equal(selector.value, 'de');
  assert.equal(textNode.text, TRANSLATIONS.de['nav.download']);
  assert.equal(attributeNode.attributes.get('aria-label'), TRANSLATIONS.de['language.label']);
  assert.equal(attributeNode.attributes.get('content'), TRANSLATIONS.de['meta.description']);
  assert.equal(attributeNode.attributes.has('href'), false);
});

test('localized deep links restore their hash target after translation', () => {
  let frameCallback;
  let scrolled = false;
  const root = {
    getElementById(id) {
      assert.equal(id, 'download');
      return { scrollIntoView() { scrolled = true; } };
    },
  };
  const windowLike = {
    location: { href: 'https://pushup.ai/?lang=de#download' },
    requestAnimationFrame(callback) { frameCallback = callback; },
  };

  restoreHashTarget(root, windowLike);
  assert.equal(scrolled, false);
  frameCallback();
  assert.equal(scrolled, true);
});

test('store links default to unavailable until real URLs are configured', () => {
  assert.deepEqual(STORE_LINKS, { googlePlay: '', appStore: '' });
  assert.deepEqual(getStoreLinkState(''), { available: false, href: '' });
});

test('store links accept only absolute HTTPS URLs', () => {
  assert.deepEqual(
    getStoreLinkState(
      'https://play.google.com/store/apps/details?id=app',
    ),
    {
      available: true,
      href: 'https://play.google.com/store/apps/details?id=app',
    },
  );
  assert.deepEqual(getStoreLinkState('/download'), {
    available: false,
    href: '',
  });
  assert.deepEqual(getStoreLinkState('javascript:alert(1)'), {
    available: false,
    href: '',
  });
});

test('configured store URLs activate the rendered store control', () => {
  const label = {
    dataset: {},
    text: '即将上架',
    replaceChildren(value) {
      this.text = value;
    },
  };
  const attributes = new Map([['aria-disabled', 'true']]);
  const link = {
    dataset: { store: 'googlePlay' },
    href: '',
    target: '',
    rel: '',
    addEventListener() {},
    removeAttribute(name) {
      attributes.delete(name);
    },
    querySelector(selector) {
      return selector === 'em' ? label : null;
    },
  };
  const root = {
    querySelectorAll(selector) {
      return selector === '[data-store]' ? [link] : [];
    },
  };

  enhanceStoreLinks(root, {
    googlePlay: 'https://play.google.com/store/apps/details?id=ai.pushup',
    appStore: '',
  });

  assert.equal(
    link.href,
    'https://play.google.com/store/apps/details?id=ai.pushup',
  );
  assert.equal(link.target, '_blank');
  assert.equal(link.rel, 'noreferrer');
  assert.equal(attributes.has('aria-disabled'), false);
  assert.equal(label.dataset.i18n, 'store.available');
});

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
    assert.match(html, new RegExp(`<summary[^>]*>${question}</summary>`));
  }
});

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
    'App 界面当前支持中文和英文',
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

test('global navigation and download hub have responsive styles', async () => {
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
    assert.match(css, new RegExp(selector.replaceAll('.', '\\.') + '\\s*\\{'));
  }
  assert.match(css, /@media \(max-width: 1020px\)[\s\S]*?\.download-layout\s*\{/);
  assert.match(css, /@media \(max-width: 900px\)[\s\S]*?\.language-picker\s*\{/);
  assert.match(css, /overflow-wrap:\s*anywhere/);
  assert.match(css, /\.has-js \.language-picker\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.language-picker select\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.qr-placeholder\s*\{[^}]*width:\s*152px/s);
  assert.match(
    css,
    /@media \(max-width: 640px\)[\s\S]*?\.apk-card\s*\{[^}]*grid-template-columns:\s*1fr/s,
  );
  assert.match(
    css,
    /@media \(max-width: 640px\)[\s\S]*?\.apk-card p\s*\{[^}]*font-size:\s*16px/s,
  );
});

test('Korean positioning copy uses the correct word for torso', () => {
  const korean = Object.values(TRANSLATIONS.ko).join('\n');
  assert.doesNotMatch(korean, /못통/);
  assert.match(korean, /몸통/);
});

test('ecosystem copy keeps premium boundaries and avoids sales claims', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const approved of [
    '登录 Premium 会员后',
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

test('navigation and ecosystem keep the approved semantic structure', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const navigation = html.match(/<nav[^>]*id="site-nav"[\s\S]*?<\/nav>/)?.[0];
  assert.ok(navigation);
  assert.equal((navigation.match(/<a /g) ?? []).length, 5);
  assert.equal(
    (html.match(/<article class="ecosystem-card/g) ?? []).length,
    4,
  );
  for (const visual of [
    'sync-visual',
    'ranking-visual',
    'account-visual',
    'device-visual',
  ]) {
    assert.match(
      html,
      new RegExp(`class="${visual}" aria-hidden="true"`),
    );
  }
});

test('mobile navigation preserves its links when JavaScript is unavailable', async () => {
  const main = await readFile(path.join(websiteRoot, 'main.js'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  assert.match(main, /classList\.add\('has-js'\)/);
  assert.match(css, /html:not\(\.has-js\) \.site-nav/);
});

test('local resources exist and production markup has no placeholders or trackers', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  const htmlReferences = [...html.matchAll(/(?:src|href)="([^"]+)"/g)]
    .map((match) => match[1])
    .filter((value) => !value.startsWith('#') && !value.startsWith('http'));
  const cssReferences = [...css.matchAll(/url\("([^"]+)"\)/g)].map(
    (match) => match[1],
  );

  for (const reference of [...htmlReferences, ...cssReferences]) {
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
    assert.match(
      readme,
      new RegExp(expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
    );
  }
});
