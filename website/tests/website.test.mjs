import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const websiteRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

function relativeLuminance(hex) {
  const channels = hex
    .slice(1)
    .match(/.{2}/g)
    .map((channel) => Number.parseInt(channel, 16) / 255)
    .map((channel) =>
      channel <= 0.04045
        ? channel / 12.92
        : ((channel + 0.055) / 1.055) ** 2.4,
    );
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrastRatio(first, second) {
  const [lighter, darker] = [
    relativeLuminance(first),
    relativeLuminance(second),
  ].sort((left, right) => right - left);
  return (lighter + 0.05) / (darker + 0.05);
}

test('landing page contains the approved brand, claims, sections, and store controls', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  for (const expected of [
    'PushupAI',
    'AI俯卧撑',
    '来做俯卧撑吧！',
    'AI 帮你数，放心去练。',
    'AI 看懂动作，你的训练画面，只属于你。',
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
    '换一台设备，进步还在',
    '运动广场',
    '一个账号，一直陪着你',
    '顺着你的习惯来',
  ]) {
    assert.match(html, new RegExp(expected));
  }
});

test('landing page uses the approved five-region editorial structure', async () => {
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
  ]);

  const supportStart = html.indexOf('data-region="support"');
  const supportEnd = html.indexOf('</main>');
  assert.ok(supportStart >= 0);
  assert.ok(supportEnd > supportStart);
  const support = html.slice(supportStart, supportEnd);
  const stepsIndex = support.indexOf('id="how-it-works"');
  const faqIndex = support.indexOf('id="faq"');
  assert.ok(stepsIndex >= 0);
  assert.ok(faqIndex > stepsIndex);
});

test('support region preserves named landmarks and existing style hooks', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.match(html, /<div class="section support" data-region="support">/);
  assert.match(
    html,
    /<section id="how-it-works" class="support-steps steps" aria-labelledby="steps-title">/,
  );
  assert.match(
    html,
    /<section id="faq" class="support-faq faq" aria-labelledby="faq-title">/,
  );
  assert.match(css, /\.steps\s*\{[^}]*display:\s*grid/s);
  assert.match(css, /\.faq summary\s*\{/);
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
  for (const asset of ['app-icon.png', 'pushup-motion-bg.webp']) {
    await access(path.join(websiteRoot, 'assets', asset));
  }
});

test('the app logo is the website brand icon everywhere', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const brandIcons = html.match(/<img\s+class="brand-mark"[\s\S]*?>/g) ?? [];

  assert.match(
    html,
    /<link rel="icon" href="assets\/app-icon\.png" type="image\/png">/,
  );
  assert.equal(brandIcons.length, 2);
  for (const icon of brandIcons) {
    assert.match(icon, /src="assets\/app-icon\.png"/);
  }
  assert.doesNotMatch(html, /<span class="brand-mark"[^>]*>P<\/span>/);
});

test('hero centers the real app identity on desktop and mobile', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  await access(path.join(websiteRoot, 'assets', 'app-icon.png'));
  assert.match(
    html,
    /<div class="hero-app-lockup">[\s\S]*?src="assets\/app-icon\.png"[\s\S]*?<strong>PushupAI<\/strong>[\s\S]*?data-i18n="brand\.productName">AI俯卧撑<\/span>[\s\S]*?<\/div>/,
  );
  assert.match(
    html,
    /<h1[^>]*data-i18n="hero\.titleAria"[^>]*>来做俯卧撑吧！<\/h1>/,
  );
  assert.match(
    css,
    /\.hero-copy\s*\{[^}]*display:\s*grid[^}]*justify-items:\s*center[^}]*text-align:\s*center/s,
  );
  assert.match(css, /\.hero-app-icon\s*\{[^}]*width:\s*clamp\(/s);
});

test('hero store buttons stay equal when they wrap', async () => {
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.match(
    css,
    /\.hero-copy \.store-button\s*\{[^}]*width:\s*252px/s,
  );
  assert.doesNotMatch(
    css,
    /\.hero-copy \.store-row,\s*\.hero-copy \.store-button\s*\{[^}]*width:\s*100%/s,
  );
});

test('store buttons use familiar platform marks', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.equal(
    html.match(/class="store-logo store-logo-google"/g)?.length,
    1,
  );
  for (const color of ['#00d7fe', '#00f076', '#ffcd00', '#ff3a44']) {
    assert.match(html, new RegExp(`fill="${color}"`, 'i'));
  }
  assert.equal(
    html.match(/class="store-logo store-logo-apple"/g)?.length,
    1,
  );
  assert.match(css, /\.store-logo-apple\s*\{[^}]*fill:\s*#fff/s);
  assert.doesNotMatch(css, /\.store-button-light/);
});

test('store buttons keep only the platform name and download icon', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');

  assert.equal(html.match(/class="store-download-icon"/g)?.length, 2);
  assert.doesNotMatch(html, />GET IT ON</);
  assert.doesNotMatch(html, />Download on the</);
  assert.doesNotMatch(html, /data-i18n="store\.(?:googleStatus|appleStatus)"/);
});

test('performance editorial motion artwork is project-local', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  await access(
    path.join(
      websiteRoot,
      'assets',
      'pushup-performance-motion-v2.webp',
    ),
  );
  assert.match(css, /pushup-performance-motion-v2\.webp/);
  const heroVisualArtwork = css.match(
    /\.hero-visual::before\s*\{([^}]*)\}/s,
  )?.[1];
  assert.ok(heroVisualArtwork);
  assert.match(heroVisualArtwork, /var\(--performance-motion-art\)/);
  assert.doesNotMatch(
    `${html}\n${css}`,
    /https?:\/\/[^\s"']+\.(?:avif|gif|jpe?g|png|webp)(?:[?#][^\s"']*)?/i,
  );
});

test('translated labels cannot inherit decorative dot styles', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  const eyebrows = html.match(/<p class="eyebrow">[\s\S]*?<\/p>/g) ?? [];
  assert.equal(eyebrows.length, 5);
  for (const eyebrow of eyebrows) {
    assert.match(
      eyebrow,
      /<span class="eyebrow-dot" aria-hidden="true"><\/span>/,
    );
    const translatedSpan = eyebrow.match(
      /<span\b[^>]*data-i18n="[^"]+"[^>]*>/,
    )?.[0];
    assert.ok(translatedSpan);
    assert.doesNotMatch(
      translatedSpan,
      /class="[^"]*\b(?:eyebrow|motion|privacy)-dot\b[^"]*"/,
    );
  }
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
  setupApkDownload,
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

test('Chinese hero uses the approved headline and reassurance copy', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const chinese = TRANSLATIONS['zh-CN'];

  assert.equal(
    `${chinese['hero.titleLine1']}${chinese['hero.titleLine2']}${chinese['hero.titleLine3']}`,
    '来做俯卧撑吧！',
  );
  assert.equal(chinese['hero.titleAria'], '来做俯卧撑吧！');
  assert.equal(chinese['hero.lede'], 'AI 帮你数，放心去练。');
  assert.equal(chinese['privacy.short'], 'AI 看懂动作，你的训练画面，只属于你。');
  assert.match(html, /aria-label="来做俯卧撑吧！"/);
  assert.match(html, /AI 帮你数，放心去练。/);
  assert.match(html, /AI 看懂动作，你的训练画面，只属于你。/);
});

test('every locale uses the approved action-first hero voice', () => {
  const expected = {
    'zh-CN': ['来做俯卧撑吧！', 'AI 帮你数，放心去练。', 'AI 看懂动作，你的训练画面，只属于你。'],
    en: ["Let's do some push-ups!", 'AI counts. You just keep moving.', 'AI understands your movement. Your workout stays yours.'],
    es: ['¡Vamos a hacer flexiones!', 'La IA cuenta. Tú solo sigue entrenando.', 'La IA entiende tus movimientos. Tu entrenamiento es solo tuyo.'],
    fr: ['C’est parti pour les pompes !', 'L’IA compte. Vous n’avez plus qu’à bouger.', 'L’IA comprend vos mouvements. Votre entraînement reste à vous.'],
    de: ["Los geht's mit Liegestützen!", 'Die KI zählt. Du konzentrierst dich aufs Training.', 'Die KI versteht deine Bewegung. Dein Training bleibt deins.'],
    'pt-BR': ['Vamos fazer flexões!', 'A IA conta. Você só precisa treinar.', 'A IA entende seus movimentos. Seu treino continua sendo só seu.'],
    ja: ['さあ、腕立て伏せを始めよう！', 'カウントはAIにおまかせ。あなたは動くだけ。', 'AIが動きを見守る。トレーニング映像は、あなただけのもの。'],
    ko: ['자, 푸시업을 시작해요!', '카운트는 AI에게 맡기고, 운동에만 집중하세요.', 'AI가 동작을 이해해요. 당신의 운동 영상은 오직 당신의 것.'],
  };

  for (const [locale, [title, lede, privacy]] of Object.entries(expected)) {
    const copy = TRANSLATIONS[locale];
    const lines = [1, 2, 3].map((line) => copy[`hero.titleLine${line}`]);
    assert.ok(lines.every((line) => line.trim().length > 0), locale);
    assert.equal(lines.join('').replaceAll(' ', ''), title.replaceAll(' ', ''), locale);
    assert.equal(copy['hero.titleAria'], title, locale);
    assert.equal(copy['hero.lede'], lede, locale);
    assert.equal(copy['privacy.short'], privacy, locale);
  }
});

test('primary marketing copy keeps implementation details in the FAQ', () => {
  const primaryKeys = [
    'meta.description',
    'meta.ogDescription',
    'hero.lede',
    'privacy.short',
    'features.countBody',
    'features.privacyBody',
    'ecosystem.intro',
    'ecosystem.syncBody',
    'ecosystem.rankingBody',
    'ecosystem.accountBody',
    'steps.noticeTitle',
    'steps.noticeBody',
    'steps.trainBody',
    'download.intro',
    'apk.body',
    'footer.summary',
    'footer.privacySummary',
  ];
  const technicalTerms = {
    'zh-CN': /MoveNet|端侧|推理|原始视频帧|归属当前账号|云端暂不可用|APK/,
    en: /MoveNet|on-device|inference|video frames|current account|cloud is unavailable|APK/i,
    es: /MoveNet|en el dispositivo|inferencia|fotogramas|cuenta actual|nube no está disponible|APK/i,
    fr: /MoveNet|sur l’appareil|analyse s’effectue|images originales|compte actuel|cloud est indisponible|APK/i,
    de: /MoveNet|auf dem Gerät|Analyse läuft|Videobilder|aktuellen Kontos|ohne Cloud|APK/i,
    'pt-BR': /MoveNet|no dispositivo|inferência|quadros originais|conta atual|nuvem estiver indisponível|APK/i,
    ja: /MoveNet|デバイス上|推論|映像フレーム|現在のアカウント|クラウドが使えない|APK/i,
    ko: /MoveNet|기기 내|추론|원본 영상 프레임|현재 계정|클라우드를 사용할 수 없을 때|APK/i,
  };

  for (const { code } of LOCALES) {
    const primaryCopy = primaryKeys.map((key) => TRANSLATIONS[code][key]).join('\n');
    assert.doesNotMatch(primaryCopy, technicalTerms[code], code);
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

test('store links keep unreleased stores disabled and expose the verified APK', () => {
  const apkUrl =
    'https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk';

  assert.deepEqual(STORE_LINKS, {
    googlePlay: '',
    appStore: '',
    apk: apkUrl,
  });
  assert.deepEqual(getStoreLinkState(''), { available: false, href: '' });
  assert.deepEqual(getStoreLinkState(STORE_LINKS.apk), {
    available: true,
    href: apkUrl,
  });
});

test('APK entry opens a mobile dialog and keeps an empty URL non-interactive', () => {
  let clickHandler;
  let dialogOpened = false;
  const attributes = new Map();
  const container = {
    toggleAttribute(name, enabled) {
      if (enabled) attributes.set(name, '');
      else attributes.delete(name);
    },
  };
  const trigger = {
    addEventListener(type, handler) {
      if (type === 'click') clickHandler = handler;
    },
    setAttribute(name, value) {
      attributes.set(name, value);
    },
  };
  const dialog = {
    showModal() {
      dialogOpened = true;
    },
  };
  const confirm = {
    hidden: false,
    removeAttribute(name) {
      attributes.delete(`confirm-${name}`);
    },
  };
  const elements = new Map([
    ['[data-apk-download]', container],
    ['[data-apk-trigger]', trigger],
    ['[data-apk-dialog]', dialog],
    ['[data-apk-confirm]', confirm],
  ]);

  setupApkDownload(
    { querySelector: (selector) => elements.get(selector) ?? null },
    { matchMedia: () => ({ matches: true }) },
    '',
  );
  clickHandler();

  assert.equal(dialogOpened, true);
  assert.equal(confirm.hidden, true);
  assert.equal(attributes.has('data-apk-available'), false);
});

test('configured APK URL activates mobile download confirmation', () => {
  let clickHandler;
  const attributes = new Map();
  const confirm = {
    hidden: true,
    href: '',
    setAttribute(name, value) {
      attributes.set(`confirm-${name}`, value);
    },
  };
  const elements = new Map([
    ['[data-apk-download]', {
      toggleAttribute(name, enabled) {
        if (enabled) attributes.set(name, '');
      },
    }],
    ['[data-apk-trigger]', {
      addEventListener(type, handler) {
        if (type === 'click') clickHandler = handler;
      },
      setAttribute() {},
    }],
    ['[data-apk-dialog]', { showModal() {} }],
    ['[data-apk-confirm]', confirm],
  ]);

  setupApkDownload(
    { querySelector: (selector) => elements.get(selector) ?? null },
    { matchMedia: () => ({ matches: true }) },
    'https://download.example.com/pushupai.apk',
  );

  assert.equal(typeof clickHandler, 'function');
  assert.equal(confirm.hidden, false);
  assert.equal(confirm.href, 'https://download.example.com/pushupai.apk');
  assert.equal(attributes.get('confirm-rel'), 'noreferrer');
  assert.equal(attributes.has('data-apk-available'), true);
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
    '不会上传原始视频帧',
    '近距离',
    '中文和英文',
    '跟随系统主题',
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

test('hero exposes the verified APK release and the duplicate download section is removed', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const entry = html.match(
    /<div[^>]*id="download"[^>]*data-apk-download[\s\S]*?<\/div>\s*<dialog/,
  )?.[0];

  assert.ok(entry);
  assert.equal((html.match(/id="download"/g) ?? []).length, 1);
  assert.match(entry, /data-apk-trigger/);
  assert.match(entry, /点击下载安装包/);
  assert.match(entry, /assets\/pushup-ai-0\.3\.4-qr\.png/);
  assert.match(entry, /versionName 0\.3\.4/);
  assert.match(entry, /versionCode 5/);
  assert.match(entry, /317 MB/);
  assert.match(
    entry,
    /1F45FFD3AD5F7E59D3FF8FEC6DD5A900E6980B3F4B1AE2E342CA0CEA1B8499E7/,
  );
  assert.doesNotMatch(entry, /data-qr-placeholder/);
  assert.match(html, /data-apk-dialog/);
  assert.match(html, /data-apk-confirm/);
  assert.doesNotMatch(html, /class="download-section"|data-region="download"/);
});

test('every locale states that APK 0.3.4 is available', () => {
  for (const { code } of LOCALES) {
    assert.match(translate(code, 'faq.downloadAnswer'), /0\.3\.4/);
    assert.match(translate(code, 'apk.status'), /0\.3\.4/);
  }

  assert.equal(translate('zh-CN', 'apk.body'), '用 Android 手机扫码即可安装。');
  assert.equal(translate('en', 'apk.body'), 'Scan with your Android phone to install.');
});

test('performance editorial visual tokens and mobile readability are enforced', async () => {
  const html = await readFile(path.join(websiteRoot, 'index.html'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.match(
    html.toLowerCase(),
    /<meta\s+name="theme-color"\s+content="#f5f6f0">/,
  );

  for (const [token, value] of [
    ['ink', '#14231b'],
    ['acid', '#c6ff55'],
    ['signal', '#2ac76d'],
    ['signal-strong', '#0b6b3a'],
    ['chalk', '#f5f6f0'],
    ['surface', '#ffffff'],
  ]) {
    assert.match(css, new RegExp(`--${token}:\\s*${value}`, 'i'));
  }

  for (const selector of [
    '.language-picker',
    '.has-js .language-picker',
    '.product-story',
    '.support',
    '.apk-inline',
    '.apk-qr-popover',
    '.apk-dialog',
    '.qr-placeholder',
    '.footer-links',
  ]) {
    assert.match(css, new RegExp(selector.replaceAll('.', '\\.') + '\\s*\\{'));
  }
  assert.match(
    css,
    /\.support\s*\{[^}]*display:\s*grid[^}]*grid-template-columns:\s*minmax\(280px,\s*\.78fr\)\s+minmax\(0,\s*1\.22fr\)/s,
  );
  assert.match(css, /@media \(max-width: 1023px\)\s*\{/);
  const mobile = css.match(
    /@media \(max-width: 767px\)\s*\{([\s\S]*?)(?=\n@media \(max-width: 390px\))/,
  )?.[1];
  assert.ok(mobile);
  assert.match(mobile, /body\s*\{[^}]*font-size:\s*16px/s);
  for (const selector of ['.hero', '.support']) {
    assert.match(
      mobile,
      new RegExp(`${selector.replaceAll('.', '\\.')}\\s*\\{[^}]*grid-template-columns:\\s*1fr`, 's'),
    );
  }
  assert.match(
    mobile,
    /\.phone-gallery\s*\{[^}]*overflow-x:\s*auto[^}]*scroll-snap-type:\s*x\s+mandatory/s,
  );
  assert.match(css, /@media \(max-width: 390px\)\s*\{/);
  assert.match(
    css,
    /@media \(max-height: 500px\) and \(orientation: landscape\)\s*\{/,
  );
  assert.match(css, /overflow-wrap:\s*anywhere/);
  assert.match(css, /\.has-js \.language-picker\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.language-picker select\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.site-nav a\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.faq summary\s*\{[^}]*min-height:\s*44px/s);
  assert.match(css, /\.qr-placeholder\s*\{[^}]*width:\s*132px/s);
  assert.match(
    css,
    /\.apk-qr-popover\s*\{[^}]*top:\s*0[^}]*left:\s*calc\(100% \+ 12px\)[^}]*transform:\s*translateX\(8px\)/s,
  );
  assert.match(
    css,
    /\.apk-inline:hover \.apk-qr-popover,[\s\S]*?\.apk-inline\[data-open\] \.apk-qr-popover\s*\{[^}]*opacity:\s*1/s,
  );
  assert.match(
    css,
    /@media \(max-width: 767px\)[\s\S]*?\.apk-qr-popover\s*\{[^}]*display:\s*none/s,
  );
});

test('editorial accent text and focus meet contrast requirements', async () => {
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');
  const token = (name) =>
    css.match(new RegExp(`--${name}:\\s*(#[0-9a-f]{6})`, 'i'))?.[1];
  const signalStrong = token('signal-strong');
  assert.ok(signalStrong);
  assert.ok(contrastRatio(signalStrong, token('chalk')) >= 4.5);
  assert.ok(contrastRatio(signalStrong, token('surface')) >= 4.5);
  assert.ok(contrastRatio(token('muted'), token('chalk')) >= 4.5);
  assert.ok(contrastRatio(token('muted'), token('surface')) >= 4.5);
  assert.ok(contrastRatio(token('acid'), token('ink')) >= 3);

  assert.match(css, /--focus-ring:\s*var\(--signal-strong\)/);

  assert.match(
    css,
    /:focus-visible\s*\{[^}]*outline:\s*3px solid var\(--focus-ring\)/s,
  );
  assert.match(
    css,
    /\.language-picker select:focus-visible\s*\{[^}]*outline:\s*3px solid var\(--focus-ring\)/s,
  );
  for (const selector of ['eyebrow', 'feature-index', 'ecosystem-kicker']) {
    assert.match(
      css,
      new RegExp(`\\.${selector}\\s*\\{[^}]*color:\\s*var\\(--signal-strong\\)`, 's'),
    );
  }
  assert.match(
    css,
    /\.feature-card-dark \.feature-index\s*\{[^}]*color:\s*var\(--signal\)/s,
  );
  assert.match(
    css,
    /\.product-story \.eyebrow\s*\{[^}]*color:\s*var\(--acid\)/s,
  );
  assert.match(
    css,
    /\.ecosystem-ranking \.ecosystem-kicker\s*\{[^}]*color:\s*var\(--acid\)/s,
  );
  assert.match(css, /\.privacy-note\s*\{[^}]*color:\s*var\(--muted\)/s);
  assert.match(css, /\.faq details p\s*\{[^}]*color:\s*var\(--muted\)/s);
});

test('editorial typography, focus, touch targets, and mobile density are exact', async () => {
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.match(css, /h1\s*\{[^}]*font-size:\s*clamp\(52px,\s*7vw,\s*104px\)/s);
  assert.match(css, /\.feature-card p\s*\{[^}]*font-size:\s*17px/s);
  assert.match(css, /\.ecosystem-card p\s*\{[^}]*font-size:\s*17px/s);
  assert.match(
    css,
    /\.step-list p,\s*\.use-note\s*\{[^}]*font-size:\s*17px/s,
  );
  assert.match(css, /\.faq details p\s*\{[^}]*font-size:\s*17px/s);
  assert.match(css, /\.apk-dialog p\s*\{[^}]*font-size:\s*17px/s);

  const languageSelect = css.match(
    /\.language-picker select\s*\{([^}]*)\}/s,
  )?.[1];
  assert.ok(languageSelect);
  assert.match(languageSelect, /min-height:\s*44px/);
  assert.doesNotMatch(languageSelect, /outline:\s*(?:0|none)\b/);
  assert.match(
    css,
    /\.language-picker select:focus-visible\s*\{[^}]*outline:\s*3px solid var\(--focus-ring\)[^}]*outline-offset:\s*2px/s,
  );
  assert.match(
    css,
    /\.footer-links a\s*\{[^}]*display:\s*inline-flex[^}]*min-height:\s*44px[^}]*align-items:\s*center/s,
  );
  assert.match(
    css,
    /\.faq details p a\s*\{[^}]*display:\s*inline-flex[^}]*min-height:\s*44px[^}]*align-items:\s*center[^}]*padding-inline:\s*4px/s,
  );
  const supportStepsIntro = css.match(
    /\.support-steps \.steps-intro\s*\{([^}]*)\}/s,
  )?.[1];
  assert.ok(supportStepsIntro);
  assert.match(supportStepsIntro, /position:\s*static/);
  assert.doesNotMatch(supportStepsIntro, /position:\s*sticky/);

  const mobile = css.match(
    /@media \(max-width: 767px\)\s*\{([\s\S]*?)(?=\n@media \(max-width: 390px\))/,
  )?.[1];
  assert.ok(mobile);
  assert.match(mobile, /\.hero\s*\{[^}]*gap:\s*24px[^}]*padding-block:\s*36px 56px/s);
  assert.match(mobile, /\.hero-visual\s*\{[^}]*min-height:\s*410px/s);
  assert.match(mobile, /\.section\s*\{[^}]*padding-block:\s*44px/s);
  assert.match(
    mobile,
    /\.feature-card,\s*\.feature-card:last-child\s*\{[^}]*min-height:\s*0[^}]*padding:\s*20px/s,
  );
  assert.match(
    mobile,
    /\.ecosystem-card\s*\{[^}]*min-height:\s*0[^}]*padding:\s*20px/s,
  );
  assert.match(
    mobile,
    /\.support\s*\{[^}]*gap:\s*32px[^}]*padding-block:\s*44px/s,
  );
  assert.match(mobile, /\.steps,\s*\.faq\s*\{[^}]*gap:\s*20px/s);
  assert.match(
    mobile,
    /\.phone-gallery\s*\{[^}]*grid-template-columns:\s*repeat\(3,\s*min\(60vw,\s*250px\)\)/s,
  );
  assert.match(
    mobile,
    /\.feature-visual,\s*\.privacy-visual,\s*\.record-visual\s*\{[^}]*margin-block:\s*24px 18px/s,
  );
  assert.match(mobile, /\.step-list li\s*\{[^}]*padding-block:\s*16px/s);
  assert.match(
    mobile,
    /\.site-footer\s*\{[^}]*min-height:\s*0[^}]*gap:\s*10px[^}]*padding-block:\s*24px/s,
  );

  const compact = css.match(
    /@media \(max-width: 390px\)\s*\{([\s\S]*?)(?=\n@media \(max-height: 500px\))/,
  )?.[1];
  assert.ok(compact);
  assert.match(compact, /h1\s*\{[^}]*font-size:\s*42px/s);
  assert.match(compact, /h2\s*\{[^}]*font-size:\s*34px/s);
  assert.match(
    compact,
    /\.feature-visual,\s*\.privacy-visual,\s*\.record-visual\s*\{[^}]*height:\s*80px[^}]*margin-block:\s*18px 12px/s,
  );
  assert.match(compact, /\.ecosystem-card\s*\{[^}]*gap:\s*12px/s);
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
    'Premium 会员可以加入日榜和周榜',
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
  assert.equal((navigation.match(/<a /g) ?? []).length, 4);
  assert.doesNotMatch(navigation, /href="#download"/);
  assert.match(html, /class="header-cta" href="#download"/);
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

test('production content does not depend on reveal observer timing', async () => {
  const main = await readFile(path.join(websiteRoot, 'main.js'), 'utf8');
  const css = await readFile(path.join(websiteRoot, 'styles.css'), 'utf8');

  assert.doesNotMatch(main, /classList\.add\('has-reveal'\)/);
  assert.doesNotMatch(main, /IntersectionObserver/);
  assert.doesNotMatch(
    css,
    /\.has-reveal \.reveal\s*\{[^}]*opacity:\s*0/s,
  );
  const reveal = css.match(/\.reveal\s*\{([^}]*)\}/s)?.[1];
  assert.ok(reveal);
  assert.match(reveal, /opacity:\s*1/);
  assert.match(reveal, /transform:\s*none/);
  const transition = reveal.match(/transition:\s*([^;]+)/)?.[1];
  assert.ok(transition);
  for (const property of ['opacity', 'transform', 'box-shadow']) {
    assert.match(transition, new RegExp(`\\b${property}\\s+240ms\\b`));
  }
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
    '0.3.4',
    'https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk',
    '1F45FFD3AD5F7E59D3FF8FEC6DD5A900E6980B3F4B1AE2E342CA0CEA1B8499E7',
  ]) {
    assert.match(
      readme,
      new RegExp(expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
    );
  }
  assert.doesNotMatch(readme, /当前二维码仍是不可扫描/);
});
