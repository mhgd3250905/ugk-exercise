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
    'id="how-it-works"',
    'id="download"',
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
