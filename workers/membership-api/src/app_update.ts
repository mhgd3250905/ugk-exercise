type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 26,
  versionName: "0.4.0",
  releaseNotes: {
    zh: [
      "同步：训练记录按原因分类处理，零次和无效记录不再反复上传",
      "账号：登录过期会自动退出并清除本地缓存，不再卡在失效状态",
      "排行榜：翻页查询性能优化，大数据量下更稳定",
      "稳定性：本地训练历史损坏时自动备份，不再丢失",
    ],
    en: [
      "Sync: workout records are classified by reason; zero-count and invalid entries no longer retry endlessly",
      "Account: expired sessions now auto-sign-out and clear cache instead of getting stuck",
      "Leaderboard: paginated query performance improved for large datasets",
      "Stability: corrupted local history is backed up instead of being lost",
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
