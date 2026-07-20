type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 17,
  versionName: "0.3.14",
  releaseNotes: {
    zh: [
      "月卡 3 天与年卡 7 天试用信息更清晰",
      "优化无试用资格时的套餐展示",
      "新增 Google Play 订阅管理入口",
    ],
    en: [
      "Clearer 3-day monthly and 7-day annual trial details",
      "Improved plan display when a free trial is unavailable",
      "Added a Google Play subscription management shortcut",
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
