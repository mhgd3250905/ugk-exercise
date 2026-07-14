import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "jose";

import { json } from "./session.js";
import type { Env } from "./types.js";

const actions = [
  "dismiss_report",
  "remove_custom_avatar",
  "hide_public_avatar",
  "restore_public_avatar",
  "suspend_upload",
  "restore_upload",
] as const;

type ModerationAction = (typeof actions)[number];
type AccessKey = CryptoKey | Uint8Array | JWTVerifyGetKey;
type AccessVerifier = (token: string, env: Env) => Promise<string>;

interface ReportRow {
  id: string;
  target_user_id: string;
  display_name: string;
  nickname: string | null;
  reason: string;
  details: string | null;
  avatar_source: string;
  avatar_object_id: string | null;
  current_avatar_object_id: string | null;
  avatar_upload_suspended_at: string | null;
  public_avatar_hidden_at: string | null;
  object_key: string | null;
  created_at: string;
}

const remoteKeys = new Map<string, JWTVerifyGetKey>();

export async function verifyAccessJwt(
  token: string,
  teamDomain: string,
  audience: string,
  key: AccessKey,
): Promise<string> {
  const options = { issuer: teamDomain, audience };
  const result =
    typeof key === "function"
      ? await jwtVerify(token, key, options)
      : await jwtVerify(token, key, options);
  const actor = result.payload.email ?? result.payload.sub;
  if (typeof actor !== "string" || actor.length === 0) {
    throw new Error("missing Access identity");
  }
  return actor;
}

async function verifyAccessRequest(token: string, env: Env): Promise<string> {
  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) {
    throw new Error("missing Access configuration");
  }
  const teamDomain = env.ACCESS_TEAM_DOMAIN.replace(/\/$/, "");
  let key = remoteKeys.get(teamDomain);
  if (!key) {
    key = createRemoteJWKSet(
      new URL(`${teamDomain}/cdn-cgi/access/certs`),
    );
    remoteKeys.set(teamDomain, key);
  }
  return verifyAccessJwt(token, teamDomain, env.ACCESS_AUD, key);
}

export async function handleAvatarAdmin(
  request: Request,
  env: Env,
  verify: AccessVerifier = verifyAccessRequest,
): Promise<Response> {
  const token = request.headers.get("cf-access-jwt-assertion");
  if (!token) return json({ error: "forbidden" }, 403);

  let actor: string;
  try {
    actor = await verify(token, env);
  } catch {
    return json({ error: "forbidden" }, 403);
  }

  const url = new URL(request.url);
  if (url.pathname === "/admin/avatar-reports") {
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    return renderQueue(env);
  }
  if (url.pathname === "/admin/avatar-reports/action") {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    if (request.headers.get("origin") !== url.origin) {
      return json({ error: "forbidden" }, 403);
    }
    return applyAction(request, env, actor);
  }
  return json({ error: "not_found" }, 404);
}

async function renderQueue(env: Env): Promise<Response> {
  const reports = await env.DB.prepare(
    "SELECT avatar_reports.id, avatar_reports.reported_user_id AS target_user_id, users.display_name, users.nickname, avatar_reports.reason, avatar_reports.details, avatar_reports.avatar_source, avatar_reports.avatar_object_id, users.custom_avatar_object_id AS current_avatar_object_id, users.avatar_upload_suspended_at, users.public_avatar_hidden_at, avatar_objects.object_key, avatar_reports.created_at FROM avatar_reports INNER JOIN users ON users.id = avatar_reports.reported_user_id LEFT JOIN avatar_objects ON avatar_objects.id = avatar_reports.avatar_object_id WHERE avatar_reports.status = 'open' ORDER BY avatar_reports.created_at",
  ).all<ReportRow>();
  const rows = reports.results.map(renderReport).join("");
  const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>头像举报审核</title></head>
<body><main><h1>头像举报审核</h1>${rows || "<p>暂无待审核举报</p>"}</main></body></html>`;
  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "content-security-policy": "default-src 'none'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
      "x-content-type-options": "nosniff",
    },
  });
}

function renderReport(report: ReportRow): string {
  const stale =
    report.avatar_source === "custom" &&
    report.avatar_object_id !== report.current_avatar_object_id;
  const buttons: Array<[ModerationAction, string]> = [
    ["dismiss_report", "驳回"],
    ...(report.avatar_source === "custom" && !stale
      ? ([["remove_custom_avatar", "下架自定义头像"]] as Array<[
          ModerationAction,
          string,
        ]>)
      : []),
    ...(report.avatar_source === "google"
      ? ([["hide_public_avatar", "隐藏公开头像"]] as Array<[
          ModerationAction,
          string,
        ]>)
      : []),
    ["restore_public_avatar", "恢复公开头像"],
    [
      report.avatar_upload_suspended_at ? "restore_upload" : "suspend_upload",
      report.avatar_upload_suspended_at ? "恢复上传" : "暂停上传",
    ],
  ];
  const forms = buttons
    .map(
      ([action, label]) =>
        `<form method="post" action="/admin/avatar-reports/action"><input type="hidden" name="reportId" value="${escapeHtml(report.id)}"><input type="hidden" name="action" value="${action}"><button type="submit">${label}</button></form>`,
    )
    .join("");
  return `<section><h2>${escapeHtml(report.nickname ?? report.display_name)}</h2><p>账号：${escapeHtml(report.target_user_id)}</p><p>举报时间：${escapeHtml(report.created_at)}</p><p>原因：${escapeHtml(report.reason)}</p><p>说明：${escapeHtml(report.details ?? "-")}</p><p>头像来源：${escapeHtml(report.avatar_source)}</p><p>头像版本：${escapeHtml(report.avatar_object_id ?? "-")}${stale ? "（已过期）" : ""}</p>${forms}</section>`;
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      })[character]!,
  );
}

async function applyAction(
  request: Request,
  env: Env,
  actor: string,
): Promise<Response> {
  const form = await request.formData();
  const reportId = form.get("reportId");
  const action = form.get("action");
  if (
    typeof reportId !== "string" ||
    typeof action !== "string" ||
    !actions.includes(action as ModerationAction)
  ) {
    return json({ error: "invalid_action" }, 400);
  }
  const moderationAction = action as ModerationAction;
  const report = await env.DB.prepare(
    "SELECT avatar_reports.id, avatar_reports.reported_user_id AS target_user_id, users.display_name, users.nickname, avatar_reports.reason, avatar_reports.details, avatar_reports.avatar_source, avatar_reports.avatar_object_id, users.custom_avatar_object_id AS current_avatar_object_id, users.avatar_upload_suspended_at, users.public_avatar_hidden_at, avatar_objects.object_key, avatar_reports.created_at FROM avatar_reports INNER JOIN users ON users.id = avatar_reports.reported_user_id LEFT JOIN avatar_objects ON avatar_objects.id = avatar_reports.avatar_object_id WHERE avatar_reports.id = ?",
  )
    .bind(reportId)
    .first<ReportRow>();
  if (!report) return json({ error: "report_not_found" }, 404);

  const now = new Date().toISOString();
  if (action === "remove_custom_avatar") {
    return removeCustomAvatar(env, report, actor, now);
  }

  const fieldUpdate =
    action === "hide_public_avatar"
      ? "UPDATE users SET public_avatar_hidden_at = ?, updated_at = ? WHERE id = ?"
      : action === "restore_public_avatar"
        ? "UPDATE users SET public_avatar_hidden_at = NULL, updated_at = ? WHERE id = ?"
        : action === "suspend_upload"
          ? "UPDATE users SET avatar_upload_suspended_at = ?, updated_at = ? WHERE id = ?"
          : action === "restore_upload"
            ? "UPDATE users SET avatar_upload_suspended_at = NULL, updated_at = ? WHERE id = ?"
            : null;
  const statements: D1PreparedStatement[] = [];
  if (fieldUpdate) {
    statements.push(
      env.DB.prepare(fieldUpdate).bind(
        ...(action === "hide_public_avatar" || action === "suspend_upload"
          ? [now, now, report.target_user_id]
          : [now, report.target_user_id]),
      ),
    );
  }
  statements.push(
    resolveReport(env, report.id, actor, moderationAction, now),
    audit(env, report, actor, moderationAction, "applied", now),
  );
  await env.DB.batch(statements);
  return redirectToQueue(request.url);
}

async function removeCustomAvatar(
  env: Env,
  report: ReportRow,
  actor: string,
  now: string,
): Promise<Response> {
  if (!report.avatar_object_id || report.avatar_source !== "custom") {
    return json({ error: "invalid_action" }, 400);
  }
  if (report.current_avatar_object_id !== report.avatar_object_id) {
    await markStale(env, report, actor, now);
    return json({ error: "stale_avatar_report" }, 409);
  }
  const cleared = await env.DB.prepare(
    "UPDATE users SET custom_avatar_object_id = NULL, updated_at = ? WHERE id = ? AND custom_avatar_object_id = ?",
  )
    .bind(now, report.target_user_id, report.avatar_object_id)
    .run();
  if (cleared.meta.changes !== 1) {
    await markStale(env, report, actor, now);
    return json({ error: "stale_avatar_report" }, 409);
  }
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE avatar_objects SET status = 'removed' WHERE id = ? AND user_id = ?",
    ).bind(report.avatar_object_id, report.target_user_id),
    resolveReport(
      env,
      report.id,
      actor,
      "remove_custom_avatar",
      now,
    ),
    audit(env, report, actor, "remove_custom_avatar", "applied", now),
  ]);
  if (report.object_key) {
    try {
      await env.AVATAR_BUCKET.delete(report.object_key);
      await env.DB.prepare(
        "UPDATE avatar_objects SET deleted_at = ? WHERE id = ?",
      )
        .bind(now, report.avatar_object_id)
        .run();
    } catch {
      // D1 already prevents public reads; object cleanup can be retried later.
    }
  }
  return new Response(null, {
    status: 303,
    headers: { location: "/admin/avatar-reports" },
  });
}

async function markStale(
  env: Env,
  report: ReportRow,
  actor: string,
  now: string,
): Promise<void> {
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE avatar_reports SET status = 'stale', resolved_at = ?, resolved_by = ?, resolution = 'stale_avatar_version' WHERE id = ?",
    ).bind(now, actor, report.id),
    audit(env, report, actor, "remove_custom_avatar", "stale", now),
  ]);
}

function resolveReport(
  env: Env,
  reportId: string,
  actor: string,
  action: ModerationAction,
  now: string,
): D1PreparedStatement {
  return env.DB.prepare(
    "UPDATE avatar_reports SET status = ?, resolved_at = ?, resolved_by = ?, resolution = ? WHERE id = ?",
  ).bind(
    action === "dismiss_report" ? "dismissed" : "actioned",
    now,
    actor,
    action,
    reportId,
  );
}

function audit(
  env: Env,
  report: ReportRow,
  actor: string,
  action: ModerationAction,
  result: string,
  now: string,
): D1PreparedStatement {
  return env.DB.prepare(
    "INSERT INTO avatar_moderation_actions (id, actor_subject, target_user_id, avatar_object_id, action, result, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
  ).bind(
    crypto.randomUUID(),
    actor,
    report.target_user_id,
    report.avatar_object_id,
    action,
    result,
    now,
  );
}

function redirectToQueue(requestUrl: string): Response {
  return new Response(null, {
    status: 303,
    headers: { location: new URL("/admin/avatar-reports", requestUrl).pathname },
  });
}
