type SupportedLocale = "zh" | "en";

export const androidReleaseManifest = {
  versionCode: 21,
  versionName: "0.3.18",
  releaseNotes: {
    zh: [
      "姿态丢失时清晰提示“姿势已中断”并保留已完成计数",
      "姿态重新出现时平稳回到训练，准备态与训练态切换更稳定",
      "修复会员管理台在 Access 浏览器下写入失败的问题",
      "新增会员运营管理台，受 Cloudflare Access 保护",
    ],
    en: [
      "Clear “pose lost” prompt now preserves your completed count",
      "Smoother recovery and transitions between preparation and training states",
      "Fixed membership admin write failures under Access-authenticated browsers",
      "Added a membership operations dashboard, protected by Cloudflare Access",
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
