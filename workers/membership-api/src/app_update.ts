type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 24,
  versionName: "0.3.21",
  releaseNotes: {
    zh: [
      "稳定性：本地记录损坏不再导致所有训练页面无法打开，单条异常训练也不再阻塞云端同步",
      "账号：登录不再因购买服务瞬时网络错误而误报失败，购买/恢复会自动重试连接",
      "体验：训练姿态剪影更清晰，排行榜积分明细改为水印式展开",
    ],
    en: [
      "Stability: corrupted local records no longer block all workout screens, and one malformed session no longer stalls cloud sync",
      "Account: sign-in no longer reports failure when the purchase service hits a brief network blip; purchase/restore now retries the link",
      "Experience: clearer pose silhouette overlay and a watermark-style leaderboard points breakdown",
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
