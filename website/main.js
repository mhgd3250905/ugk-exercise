import { getStoreLinkState, STORE_LINKS } from './store-links.js';
import {
  LOCALE_STORAGE_KEY,
  resolveLocale,
  translate,
  urlWithLocale,
} from './locales.js';

const TRANSLATABLE_ATTRIBUTES = new Set([
  'alt',
  'aria-label',
  'content',
  'title',
]);

function getLocalStorage(windowLike) {
  try {
    return windowLike.localStorage;
  } catch {
    return null;
  }
}

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
  } catch {
    // The website still works when storage is blocked or unavailable.
  }
}

export function getInitialLocale(windowLike) {
  let urlLocale = null;
  try {
    urlLocale = new URL(windowLike.location.href).searchParams.get('lang');
  } catch {
    // A malformed location falls through to stored and browser preferences.
  }

  const preferredLanguages = windowLike.navigator?.languages;

  return resolveLocale({
    urlLocale,
    storedLocale: readStoredLocale(getLocalStorage(windowLike)),
    browserLocales: preferredLanguages?.length
      ? preferredLanguages
      : [windowLike.navigator?.language].filter(Boolean),
  });
}

export function applyLocale(root, locale) {
  root.documentElement.lang = locale;

  for (const element of root.querySelectorAll('[data-i18n]')) {
    element.replaceChildren(translate(locale, element.dataset.i18n));
  }

  for (const element of root.querySelectorAll('[data-i18n-attr]')) {
    for (const binding of element.dataset.i18nAttr.split(';')) {
      const separator = binding.indexOf(':');
      if (separator === -1) continue;
      const attribute = binding.slice(0, separator).trim();
      const key = binding.slice(separator + 1).trim();
      if (!TRANSLATABLE_ATTRIBUTES.has(attribute)) continue;
      element.setAttribute(attribute, translate(locale, key));
    }
  }

  const selector = root.querySelector('[data-language-select]');
  if (selector) selector.value = locale;
}

export function restoreHashTarget(root, windowLike) {
  let targetId;
  try {
    targetId = decodeURIComponent(
      new URL(windowLike.location.href).hash.slice(1),
    );
  } catch {
    return;
  }
  if (!targetId) return;

  const scrollToTarget = () => root.getElementById(targetId)?.scrollIntoView();
  if (typeof windowLike.requestAnimationFrame === 'function') {
    windowLike.requestAnimationFrame(scrollToTarget);
  } else {
    scrollToTarget();
  }
}

export function setupLocale(root, windowLike) {
  const initialLocale = getInitialLocale(windowLike);
  applyLocale(root, initialLocale);
  restoreHashTarget(root, windowLike);

  root
    .querySelector('[data-language-select]')
    ?.addEventListener('change', ({ currentTarget }) => {
      const locale = resolveLocale({ urlLocale: currentTarget.value });
      applyLocale(root, locale);
      writeStoredLocale(getLocalStorage(windowLike), locale);
      const localizedUrl = urlWithLocale(windowLike.location.href, locale);
      windowLike.history?.replaceState(null, '', localizedUrl);
      restoreHashTarget(root, windowLike);
    });
}

export function enhanceStoreLinks(root, storeLinks = STORE_LINKS) {
  for (const link of root.querySelectorAll('[data-store]')) {
    const state = getStoreLinkState(storeLinks[link.dataset.store]);
    if (!state.available) {
      link.addEventListener('click', (event) => event.preventDefault());
      continue;
    }

    link.href = state.href;
    link.target = '_blank';
    link.rel = 'noreferrer';
    link.removeAttribute('aria-disabled');
    const status = link.querySelector('em');
    if (status) status.dataset.i18n = 'store.available';
  }
}

function setupPage() {
  const menuButton = document.querySelector('[data-menu-button]');
  const nav = document.querySelector('[data-nav]');

  function closeMenu() {
    menuButton?.setAttribute('aria-expanded', 'false');
    nav?.removeAttribute('data-open');
  }

  menuButton?.addEventListener('click', () => {
    const open = menuButton.getAttribute('aria-expanded') !== 'true';
    menuButton.setAttribute('aria-expanded', String(open));
    nav?.toggleAttribute('data-open', open);
  });

  nav?.addEventListener('click', ({ target }) => {
    if (target instanceof HTMLAnchorElement) {
      closeMenu();
    }
  });

  document.addEventListener('keydown', ({ key }) => {
    if (
      key === 'Escape' &&
      menuButton?.getAttribute('aria-expanded') === 'true'
    ) {
      closeMenu();
      menuButton.focus();
    }
  });

  enhanceStoreLinks(document);
  setupLocale(document, window);

  document
    .querySelector('[data-year]')
    ?.replaceChildren(String(new Date().getFullYear()));
}

if (typeof document !== 'undefined') {
  document.documentElement.classList.add('has-js');
  setupPage();
}
