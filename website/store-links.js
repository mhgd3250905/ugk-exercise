/**
 * Replace either empty string with the final store URL after release.
 * Only absolute HTTPS URLs are activated by main.js.
 */
export const STORE_LINKS = Object.freeze({
  googlePlay: '',
  appStore: '',
  apk: 'https://pub-cde8dfa84b5843b1b05dc2a7bad99a49.r2.dev/releases/pushup-ai-0.3.4.apk',
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
