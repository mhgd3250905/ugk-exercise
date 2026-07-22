type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 22,
  versionName: "0.3.19",
  releaseNotes: {
    zh: [
      "训练启停与切相机更稳定，修复快速操作导致的相机或资源泄漏",
      "会员与排行榜网络请求增加超时保护，弱网下不再无限等待",
      "强化管理台写入安全，所有操作需独立意图校验",
    ],
    en: [
      "Workout start, stop, and camera switch are more robust, fixing leaks from rapid taps",
      "Membership and leaderboard requests now time out instead of waiting forever on weak networks",
      "Hardened admin write safety with independent intent verification on every action",
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
