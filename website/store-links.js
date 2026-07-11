/**
 * Replace either empty string with the final store URL after release.
 * Only absolute HTTPS URLs are activated by main.js.
 */
export const STORE_LINKS = Object.freeze({
  googlePlay: '',
  appStore: '',
});

export function getStoreLinkState(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') {
      return { available: false, href: '' };
    }
    return { available: true, href: url.href };
  } catch {
    return { available: false, href: '' };
  }
}
