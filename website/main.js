import { getStoreLinkState, STORE_LINKS } from './store-links.js';

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
  if (key === 'Escape') {
    closeMenu();
    menuButton?.focus();
  }
});

for (const link of document.querySelectorAll('[data-store]')) {
  const state = getStoreLinkState(STORE_LINKS[link.dataset.store]);
  if (!state.available) {
    link.addEventListener('click', (event) => event.preventDefault());
    continue;
  }

  link.href = state.href;
  link.target = '_blank';
  link.rel = 'noreferrer';
  link.removeAttribute('aria-disabled');
  link.querySelector('em')?.replaceChildren('立即下载');
}

document
  .querySelector('[data-year]')
  ?.replaceChildren(String(new Date().getFullYear()));

const reduceMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)',
).matches;

if ('IntersectionObserver' in window && !reduceMotion) {
  document.documentElement.classList.add('has-reveal');
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) {
          continue;
        }
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    },
    { threshold: 0.12 },
  );

  document
    .querySelectorAll('.reveal')
    .forEach((element) => observer.observe(element));
}
