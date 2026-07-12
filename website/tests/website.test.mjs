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

const { getStoreLinkState, STORE_LINKS } = await import('../store-links.js');
const { enhanceStoreLinks } = await import('../main.js');
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
  assert.equal(label.text, '立即下载');
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
    assert.match(html, new RegExp(`<summary>${question}</summary>`));
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
