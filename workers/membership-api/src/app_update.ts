type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 23,
  versionName: "0.3.20",
  releaseNotes: {
    zh: [
      "近距离识别优化：距离过近时提示退后，减少俯卧撑底部漏记",
      "训练排行榜：点击有分用户可展开查看标准/窄距次数明细，训练后积分即时刷新",
      "体验修复：英文语音播报速率、本地记录存储稳定性改进",
    ],
    en: [
      "Closer-range recognition: prompts you to step back when too close, reducing missed reps at the bottom of a pushup",
      "Leaderboard: tap a ranked user to see their standard vs narrow rep breakdown; points refresh right after a workout",
      "Fixes: English voice playback rate and local record storage stability",
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
