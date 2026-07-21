type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 20,
  versionName: "0.3.17",
  releaseNotes: {
    zh: [
      "适配 Android 15 无边框显示，内容会避开系统栏和手势区域",
      "优化平板、折叠屏和横屏布局，宽屏训练采用双栏显示",
      "移除大屏方向与尺寸限制，支持自由旋转和窗口调整",
      "升级 Android 构建基础，提高新系统兼容性",
    ],
    en: [
      "Added Android 15 edge-to-edge support with safe system and gesture insets",
      "Improved tablet, foldable, and landscape layouts with a two-pane wide workout view",
      "Removed large-screen orientation and resize restrictions for adaptive windows",
      "Updated the Android build foundation for newer platform compatibility",
    ],
  },
} as const;

export function appUpdate(request: Request): Response {
  if (request.method !== "GET") {
    return response({ error: "method_not_allowed" }, 405, { allow: "GET" });
  }

  const url = new URL(request.url);
  if (url.searchParams.get("platform") !== "android") {
    return response({ error: "unsupported_platform" }, 400);
  }

  const locale = supportedLocale(url.searchParams.get("locale"));
  return response({
    schemaVersion: 1,
    platform: "android",
    locale,
    latest: {
      versionCode: androidReleaseManifest.versionCode,
      versionName: androidReleaseManifest.versionName,
      releaseNotes: androidReleaseManifest.releaseNotes[locale],
    },
  });
}

function supportedLocale(value: string | null): SupportedLocale {
  return value?.trim().toLowerCase().split("-")[0] === "zh" ? "zh" : "en";
}

function response(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "cache-control": "no-store",
      "content-type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}
