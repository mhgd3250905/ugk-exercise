type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 19,
  versionName: "0.3.16",
  releaseNotes: {
    zh: [
      "训练历史下载后会保存在本机，再次打开记录页可立即显示",
      "会员到期后仍可查看已下载记录，但不再刷新云端",
      "优化训练状态提示条的宽度、居中与运行状态颜色",
      "优化会员到期续订核验，避免短暂显示为非会员",
    ],
    en: [
      "Downloaded workout history is now cached and shown immediately when Records reopens",
      "Downloaded history remains available after Premium expires, while cloud refresh stops",
      "Improved workout status labels with adaptive width, centered content, and active colors",
      "Improved renewal verification at expiry to avoid briefly showing Premium as inactive",
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
