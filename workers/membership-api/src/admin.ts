import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "jose";

import {
  createAdminCsrfToken,
  verifyAdminCsrfToken,
} from "./admin_csrf.js";
import { json } from "./session.js";
import { reconcileMembership } from "./membership_reconciliation.js";
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
type MembershipReconciler = (env: Env, userId: string) => Promise<unknown>;

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

interface MemberRow {
  id: string;
  display_name: string;
  email: string;
  nickname: string | null;
  is_active: number;
  expires_at: string | null;
  verified_at: string | null;
  product_identifier: string | null;
  period_type: string | null;
  store: string | null;
  is_sandbox: number | null;
  unsubscribe_detected_at: string | null;
  billing_issue_detected_at: string | null;
}

interface MemberDetail extends MemberRow {
  created_at: string;
  source: string;
  last_event_at: string | null;
  purchase_at: string | null;
  original_purchase_at: string | null;
  ownership_type: string | null;
}

interface MembershipAdminActionRow {
  actor_subject: string;
  action: string;
  result: string;
  created_at: string;
}

interface MembershipStats {
  members: number;
  active: number;
  trials: number;
  expiring: number;
  attention: number;
  unidentified: number;
}

const remoteKeys = new Map<string, JWTVerifyGetKey>();

function accessFailureReason(error: unknown): string {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = (error as { code?: unknown }).code;
    if (typeof code === "string" && /^ERR_[A-Z0-9_]+$/.test(code)) {
      return code;
    }
  }
  if (error instanceof Error) {
    if (error.message === "missing Access configuration") {
      return "missing_configuration";
    }
    if (error.message === "missing Access identity") {
      return "missing_identity";
    }
  }
  return "verification_failed";
}

function reportAccessDenied(reason: string): void {
  console.warn("UGK_ADMIN_ACCESS_DENIED", { reason });
}

const adminStyles = `
:root{color-scheme:light;--ink:#102027;--muted:#657077;--paper:#f3f0e7;--surface:#fffdf7;--line:#d9d3c6;--green:#0d7557;--green-soft:#dff2e9;--amber:#9a5a00;--amber-soft:#fff0cd;--red:#a9362b;--red-soft:#fbe5e1;--nav:#0d1d24}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;font-size:14px;line-height:1.5}
a{color:var(--green);text-underline-offset:3px}.topbar{min-height:64px;padding:0 max(24px,calc((100vw - 1400px)/2));background:var(--nav);color:#f8f5ed;display:flex;align-items:center;justify-content:space-between;gap:24px}.brand{color:inherit;text-decoration:none;font-size:17px;font-weight:800;letter-spacing:.02em}.topbar nav{display:flex;align-items:center;gap:8px}.topbar nav a{color:#c8d2d3;text-decoration:none;padding:8px 12px;border-radius:6px}.topbar nav a[aria-current="page"]{background:#1c353d;color:#fff}
main{max-width:1400px;margin:auto;padding:38px 24px 56px}.hero{display:flex;align-items:end;justify-content:space-between;gap:24px;margin-bottom:28px}.eyebrow{margin:0 0 8px;color:var(--green);font-size:12px;font-weight:800;letter-spacing:.16em}.hero h1{margin:0;font-size:clamp(30px,4vw,48px);line-height:1.08;letter-spacing:-.04em}.hero p:last-child{max-width:620px;margin:10px 0 0;color:var(--muted)}
.stats{display:grid;grid-template-columns:repeat(6,minmax(130px,1fr));gap:10px;margin:0 0 24px}.stat{min-height:112px;padding:18px;background:var(--surface);border:1px solid var(--line);border-top:3px solid var(--ink);border-radius:4px}.stat--signal{border-top-color:var(--green)}.stat--risk{border-top-color:var(--amber)}.stat span{display:block;color:var(--muted);font-size:12px;font-weight:700}.stat strong{display:block;margin-top:12px;font-size:30px;line-height:1;font-variant-numeric:tabular-nums}
.notice{margin:0 0 18px;padding:12px 14px;border:1px solid #a9d5c3;background:var(--green-soft);color:#075740;border-radius:4px}.detail{margin:0 0 24px;padding:22px;background:var(--nav);color:#eef4f2;border-radius:6px;box-shadow:0 12px 30px #0d1d2418}.detail a{color:#a8e5ce}.detail h2{margin-top:0}.detail dl{display:grid;grid-template-columns:150px minmax(0,1fr);gap:8px 16px;margin:20px 0}.detail dt{color:#aab9bb}.detail dd{margin:0;overflow-wrap:anywhere}.detail ul{padding-left:20px;color:#d4dddc}.detail-actions{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.actions{display:flex;align-items:center;justify-content:space-between;gap:16px;margin-bottom:12px}.actions p{margin:0;color:var(--muted)}button,.button{appearance:none;border:1px solid var(--ink);border-radius:4px;background:var(--ink);color:white;padding:9px 13px;font:inherit;font-weight:750;cursor:pointer;text-decoration:none}button:hover,.button:hover{background:#243a42}.button--quiet{background:transparent;color:var(--ink)}button:disabled{cursor:not-allowed;opacity:.45}
.filters{display:grid;grid-template-columns:minmax(220px,1.7fr) repeat(4,minmax(130px,1fr)) auto auto;align-items:end;gap:10px;padding:14px;background:#e8e4d9;border:1px solid var(--line);border-radius:6px}.filters label{display:grid;gap:5px;color:#46545a;font-size:12px;font-weight:750}.filters input,.filters select{width:100%;height:39px;border:1px solid #b9b3a8;border-radius:4px;background:var(--surface);color:var(--ink);padding:7px 9px;font:inherit}.filters .clear{height:39px;display:grid;place-items:center;color:var(--ink);font-weight:700}
.result-count{margin:22px 0 10px;color:var(--muted)}.table-shell{overflow:auto;background:var(--surface);border:1px solid var(--line);border-radius:6px}table{width:100%;min-width:940px;border-collapse:collapse}th,td{padding:13px 14px;text-align:left;border-bottom:1px solid #e7e2d8;vertical-align:middle}th{position:sticky;top:0;background:#e9e5da;color:#526067;font-size:11px;letter-spacing:.06em;text-transform:uppercase}tbody tr:hover{background:#f8f6ef}tbody tr:last-child td{border-bottom:0}td small{color:var(--muted)}td strong{color:var(--ink)}.status{display:inline-flex;border-radius:99px;padding:3px 8px;font-size:12px;font-weight:800;white-space:nowrap}.status--ok{background:var(--green-soft);color:var(--green)}.status--warn{background:var(--amber-soft);color:var(--amber)}.status--danger{background:var(--red-soft);color:var(--red)}
.reports{display:grid;gap:14px}.report{padding:20px;background:var(--surface);border:1px solid var(--line);border-left:4px solid var(--amber);border-radius:4px}.report h2{margin-top:0}.report form{display:inline-block;margin:5px 6px 0 0}.report p{margin:6px 0;color:#48565c}
.pagination{display:flex;align-items:center;justify-content:center;gap:18px;padding:20px}.pagination a{font-weight:750}.pagination span{color:var(--muted);font-variant-numeric:tabular-nums}code{font-family:ui-monospace,SFMono-Regular,Consolas,monospace;font-size:.9em}
:focus-visible{outline:3px solid #56b895;outline-offset:2px}@media(max-width:1100px){.stats{grid-template-columns:repeat(3,1fr)}.filters{grid-template-columns:repeat(3,1fr)}.filters label:first-child{grid-column:span 2}}@media(max-width:680px){.topbar{padding:10px 16px;align-items:flex-start;flex-direction:column;gap:2px}.topbar nav{width:100%;overflow:auto}.topbar nav a{white-space:nowrap}main{padding:26px 14px 40px}.hero{align-items:start;flex-direction:column}.stats{grid-template-columns:repeat(2,1fr)}.filters{grid-template-columns:1fr}.filters label:first-child{grid-column:auto}.actions{align-items:flex-start;flex-direction:column}.detail dl{grid-template-columns:1fr}.detail dd{margin-bottom:8px}}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}
`;

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

/**
 * Same-origin guard for admin POST requests.
 *
 * Browsers emit `Origin: "null"` (the literal string) when a document has an
 * opaque origin — for example a form POST issued after a Cloudflare Access
 * redirect chain under our `referrer-policy: no-referrer` / sandboxed CSP.
 * Real admins always carry a verified Access JWT (checked above), and every
 * accepted POST also proves intent with an actor-bound CSRF token. Accepting
 * the `null` origin preserves that legitimate browser flow while foreign and
 * missing origins remain blocked as a second layer.
 */
function isSameOriginPost(request: Request, url: URL): boolean {
  const origin = request.headers.get("origin");
  return origin === url.origin || origin === "null";
}

export async function handleAvatarAdmin(
  request: Request,
  env: Env,
  verify: AccessVerifier = verifyAccessRequest,
  reconcile: MembershipReconciler = reconcileMembership,
): Promise<Response> {
  const token = request.headers.get("cf-access-jwt-assertion");
  if (!token) {
    reportAccessDenied("missing_assertion");
    return json({ error: "forbidden" }, 403);
  }

  let actor: string;
  try {
    actor = await verify(token, env);
  } catch (error) {
    reportAccessDenied(accessFailureReason(error));
    return json({ error: "forbidden" }, 403);
  }

  const url = new URL(request.url);
  if (url.pathname === "/admin") {
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    return new Response(null, {
      status: 303,
      headers: { location: "/admin/members" },
    });
  }
  if (url.pathname === "/admin/members") {
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    const csrfToken = await createAdminCsrfToken(env.SESSION_SECRET, actor);
    return renderMemberships(env, url, csrfToken);
  }
  if (url.pathname === "/admin/members/action") {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    if (!isSameOriginPost(request, url)) {
      return json({ error: "forbidden" }, 403);
    }
    const form = await request.formData();
    const csrfToken = form.get("csrfToken");
    if (
      typeof csrfToken !== "string" ||
      !(await verifyAdminCsrfToken(env.SESSION_SECRET, actor, csrfToken))
    ) {
      return json({ error: "forbidden" }, 403);
    }
    return applyMembershipAction(form, request.url, env, actor, reconcile);
  }
  if (url.pathname === "/admin/avatar-reports") {
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    const csrfToken = await createAdminCsrfToken(env.SESSION_SECRET, actor);
    return renderQueue(env, csrfToken);
  }
  if (url.pathname === "/admin/avatar-reports/action") {
    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    if (!isSameOriginPost(request, url)) {
      return json({ error: "forbidden" }, 403);
    }
    const form = await request.formData();
    const csrfToken = form.get("csrfToken");
    if (
      typeof csrfToken !== "string" ||
      !(await verifyAdminCsrfToken(env.SESSION_SECRET, actor, csrfToken))
    ) {
      return json({ error: "forbidden" }, 403);
    }
    return applyAction(form, request.url, env, actor);
  }
  return json({ error: "not_found" }, 404);
}

async function applyMembershipAction(
  form: FormData,
  requestUrl: string,
  env: Env,
  actor: string,
  reconcile: MembershipReconciler,
): Promise<Response> {
  const action = form.get("action");
  const userId = form.get("userId");
  if (action === "reconcile_missing") {
    return reconcileMissingMemberships(requestUrl, env, actor, reconcile);
  }
  if (
    action !== "reconcile" ||
    typeof userId !== "string" ||
    userId.length === 0 ||
    userId.length > 128
  ) {
    return json({ error: "invalid_action" }, 400);
  }
  const member = await env.DB.prepare(
    "SELECT user_id FROM membership_snapshots WHERE user_id = ? AND has_entitlement = 1",
  )
    .bind(userId)
    .first<{ user_id: string }>();
  if (!member) return json({ error: "member_not_found" }, 404);

  const now = new Date().toISOString();
  try {
    await reconcile(env, userId);
    await recordMembershipAdminAction(env, actor, userId, "applied", now);
  } catch {
    await recordMembershipAdminAction(env, actor, userId, "failed", now);
    return json({ error: "membership_sync_unavailable" }, 503);
  }
  const location = new URL("/admin/members", requestUrl);
  location.searchParams.set("member", userId);
  location.searchParams.set("synced", "1");
  return new Response(null, {
    status: 303,
    headers: { location: `${location.pathname}${location.search}` },
  });
}

async function reconcileMissingMemberships(
  requestUrl: string,
  env: Env,
  actor: string,
  reconcile: MembershipReconciler,
): Promise<Response> {
  const candidates = await env.DB.prepare(
    "SELECT user_id FROM membership_snapshots WHERE has_entitlement = 1 AND product_identifier IS NULL ORDER BY verified_at, updated_at LIMIT 10",
  ).all<{ user_id: string }>();
  let applied = 0;
  let failed = 0;
  for (const candidate of candidates.results) {
    const now = new Date().toISOString();
    try {
      await reconcile(env, candidate.user_id);
      await recordMembershipAdminAction(
        env,
        actor,
        candidate.user_id,
        "applied",
        now,
      );
      applied += 1;
    } catch {
      await recordMembershipAdminAction(
        env,
        actor,
        candidate.user_id,
        "failed",
        now,
      );
      failed += 1;
    }
  }
  const location = new URL("/admin/members", requestUrl);
  location.searchParams.set("backfilled", String(applied));
  location.searchParams.set("failed", String(failed));
  return new Response(null, {
    status: 303,
    headers: { location: `${location.pathname}${location.search}` },
  });
}

async function recordMembershipAdminAction(
  env: Env,
  actor: string,
  userId: string,
  result: "applied" | "failed",
  now: string,
): Promise<void> {
  await env.DB.prepare(
    "INSERT INTO membership_admin_actions (id, actor_subject, target_user_id, action, result, created_at) VALUES (?, ?, ?, 'reconcile', ?, ?)",
  )
    .bind(crypto.randomUUID(), actor, userId, result, now)
    .run();
}

async function renderMemberships(
  env: Env,
  url: URL,
  csrfToken: string,
): Promise<Response> {
  const now = new Date();
  const nowIso = now.toISOString();
  const expiringIso = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const stats = await env.DB.prepare(
    "SELECT COUNT(*) AS members, COALESCE(SUM(CASE WHEN is_active = 1 AND (expires_at IS NULL OR expires_at > ?) THEN 1 ELSE 0 END), 0) AS active, COALESCE(SUM(CASE WHEN is_active = 1 AND (expires_at IS NULL OR expires_at > ?) AND period_type = 'trial' THEN 1 ELSE 0 END), 0) AS trials, COALESCE(SUM(CASE WHEN is_active = 1 AND expires_at > ? AND expires_at <= ? THEN 1 ELSE 0 END), 0) AS expiring, COALESCE(SUM(CASE WHEN is_active = 1 AND (expires_at IS NULL OR expires_at > ?) AND (unsubscribe_detected_at IS NOT NULL OR billing_issue_detected_at IS NOT NULL) THEN 1 ELSE 0 END), 0) AS attention, COALESCE(SUM(CASE WHEN product_identifier IS NULL THEN 1 ELSE 0 END), 0) AS unidentified FROM membership_snapshots WHERE has_entitlement = 1",
  )
    .bind(nowIso, nowIso, nowIso, expiringIso, nowIso)
    .first<MembershipStats>();

  const query = (url.searchParams.get("q") ?? "").trim().slice(0, 120);
  const status = url.searchParams.get("status") ?? "all";
  const plan = url.searchParams.get("plan") ?? "all";
  const environment = url.searchParams.get("environment") ?? "all";
  const sort = url.searchParams.get("sort") ?? "expires_asc";
  const where = ["membership_snapshots.has_entitlement = 1"];
  const bindings: unknown[] = [];
  if (query) {
    where.push(
      "(instr(lower(users.id), lower(?)) > 0 OR instr(lower(users.display_name), lower(?)) > 0 OR instr(lower(users.email), lower(?)) > 0 OR instr(lower(COALESCE(users.nickname, '')), lower(?)) > 0)",
    );
    bindings.push(query, query, query, query);
  }
  addStatusFilter(where, bindings, status, nowIso, expiringIso);
  addPlanFilter(where, plan);
  addEnvironmentFilter(where, environment);
  const order = membershipOrder(sort, nowIso);

  const pageSize = 25;
  const page = positiveInteger(url.searchParams.get("page")) ?? 1;
  const count = await env.DB.prepare(
    `SELECT COUNT(*) AS count FROM membership_snapshots INNER JOIN users ON users.id = membership_snapshots.user_id WHERE ${where.join(" AND ")}`,
  )
    .bind(...bindings)
    .first<{ count: number }>();
  const total = count?.count ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, pageCount);
  const memberships = await env.DB.prepare(
    `SELECT users.id, users.display_name, users.email, users.nickname, membership_snapshots.is_active, membership_snapshots.expires_at, membership_snapshots.verified_at, membership_snapshots.product_identifier, membership_snapshots.period_type, membership_snapshots.store, membership_snapshots.is_sandbox, membership_snapshots.unsubscribe_detected_at, membership_snapshots.billing_issue_detected_at FROM membership_snapshots INNER JOIN users ON users.id = membership_snapshots.user_id WHERE ${where.join(" AND ")} ORDER BY ${order.sql} LIMIT ? OFFSET ?`,
  )
    .bind(
      ...bindings,
      ...order.bindings,
      pageSize,
      (currentPage - 1) * pageSize,
    )
    .all<MemberRow>();
  const requestedMemberId = url.searchParams.get("member");
  const detail =
    requestedMemberId !== null && requestedMemberId.length <= 128
      ? await loadMemberDetail(
          env,
          requestedMemberId,
          now.getTime(),
          csrfToken,
        )
      : "";
  const rows = memberships.results
    .map(
      (member) => `<tr><td><a href="${memberDetailHref(url.searchParams, member.id)}"><strong>${escapeHtml(member.nickname ?? member.display_name)}</strong></a><br><small>${escapeHtml(member.email)}</small></td><td>${planLabel(member)}</td><td>${periodLabel(member.period_type)}</td><td>${statusLabel(member, now.getTime())}</td><td>${formatDateTime(member.expires_at)}</td><td>${environmentLabel(member.is_sandbox)}</td><td>${formatDateTime(member.verified_at)}</td></tr>`,
    )
    .join("");
  const search = new URLSearchParams(url.searchParams);
  search.delete("page");
  const previous = currentPage > 1 ? pageLink(search, currentPage - 1, "上一页") : "";
  const next = currentPage < pageCount ? pageLink(search, currentPage + 1, "下一页") : "";
  const unidentified = stats?.unidentified ?? 0;
  const notice = membershipFeedback(url.searchParams);
  const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="robots" content="noindex,nofollow"><title>会员运营 · PushupAI</title><style>${adminStyles}</style></head>
<body><header class="topbar"><a class="brand" href="/admin/members">PUSHUPAI / OPS</a><nav aria-label="管理台导航"><a href="/admin/members" aria-current="page">会员运营</a><a href="/admin/avatar-reports">头像审核</a></nav></header><main><section class="hero"><div><p class="eyebrow">MEMBERSHIP OPERATIONS</p><h1>会员管理</h1><p>购买、续费与风险状态一屏掌握。页面读取 D1 运营快照，手动同步时由 RevenueCat 返回权威结果。</p></div></section>${notice}<section class="stats" aria-label="会员概览"><article class="stat"><span>在册会员</span><strong data-stat="members">${stats?.members ?? 0}</strong></article><article class="stat stat--signal"><span>当前有效</span><strong data-stat="active">${stats?.active ?? 0}</strong></article><article class="stat"><span>试用中</span><strong data-stat="trials">${stats?.trials ?? 0}</strong></article><article class="stat stat--risk"><span>7 天内到期</span><strong data-stat="expiring">${stats?.expiring ?? 0}</strong></article><article class="stat stat--risk"><span>续费风险</span><strong data-stat="attention">${stats?.attention ?? 0}</strong></article><article class="stat"><span>待识别</span><strong data-stat="unidentified">${unidentified}</strong></article></section>${detail}<section class="actions" aria-label="数据操作"><p>敏感的退款、取消和权益调整仍在 RevenueCat / Google Play 操作。</p><form method="post" action="/admin/members/action"><input type="hidden" name="csrfToken" value="${csrfToken}"><input type="hidden" name="action" value="reconcile_missing"><button type="submit"${unidentified === 0 ? " disabled" : ""}>补齐最多 10 条待识别会员</button></form></section><form class="filters" method="get"><label>搜索<input name="q" value="${escapeHtml(query)}" placeholder="用户 ID、姓名或邮箱"></label><label>状态<select name="status">${options(status, [["all", "全部"], ["active", "有效"], ["trial", "试用"], ["expiring", "7 天内到期"], ["canceling", "已取消续费"], ["billing_issue", "账单异常"], ["expired", "已失效"]])}</select></label><label>类型<select name="plan">${options(plan, [["all", "全部"], ["monthly", "月卡"], ["annual", "年卡"], ["promotional", "赠送"], ["other", "其他"], ["unknown", "待识别"]])}</select></label><label>环境<select name="environment">${options(environment, [["all", "全部"], ["production", "正式"], ["sandbox", "沙盒"], ["unknown", "待识别"]])}</select></label><label>排序<select name="sort">${options(sort, [["expires_asc", "即将到期优先"], ["expires_desc", "最晚到期优先"], ["purchase_desc", "最近购买优先"], ["purchase_asc", "最早购买优先"], ["verified_desc", "最近同步优先"]])}</select></label><button type="submit">应用筛选</button><a class="clear" href="/admin/members">清除</a></form><p class="result-count">找到 ${total} 条记录</p><div class="table-shell"><table><thead><tr><th scope="col">用户</th><th scope="col">会员类型</th><th scope="col">阶段</th><th scope="col">状态</th><th scope="col">到期时间</th><th scope="col">环境</th><th scope="col">最后同步</th></tr></thead><tbody>${rows || '<tr><td colspan="7">暂无匹配会员</td></tr>'}</tbody></table></div><footer class="pagination">${previous}<span>第 ${currentPage} / ${pageCount} 页</span>${next}</footer></main></body></html>`;
  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
    },
  });
}

async function loadMemberDetail(
  env: Env,
  userId: string,
  nowMs: number,
  csrfToken: string,
): Promise<string> {
  const member = await env.DB.prepare(
    "SELECT users.id, users.display_name, users.email, users.nickname, users.created_at, membership_snapshots.is_active, membership_snapshots.expires_at, membership_snapshots.verified_at, membership_snapshots.product_identifier, membership_snapshots.period_type, membership_snapshots.store, membership_snapshots.is_sandbox, membership_snapshots.unsubscribe_detected_at, membership_snapshots.billing_issue_detected_at, membership_snapshots.source, membership_snapshots.last_event_at, membership_snapshots.purchase_at, membership_snapshots.original_purchase_at, membership_snapshots.ownership_type FROM membership_snapshots INNER JOIN users ON users.id = membership_snapshots.user_id WHERE membership_snapshots.user_id = ? AND membership_snapshots.has_entitlement = 1",
  )
    .bind(userId)
    .first<MemberDetail>();
  if (!member) {
    return '<aside class="detail"><h2 id="member-detail-title">会员详情</h2><p>未找到该会员。</p></aside>';
  }
  const actions = await env.DB.prepare(
    "SELECT actor_subject, action, result, created_at FROM membership_admin_actions WHERE target_user_id = ? ORDER BY created_at DESC LIMIT 5",
  )
    .bind(userId)
    .all<MembershipAdminActionRow>();
  const actionRows = actions.results
    .map(
      (action) => `<li>${formatDateTime(action.created_at)} · ${action.action === "reconcile" ? "权威同步" : escapeHtml(action.action)} · ${action.result === "applied" ? "成功" : "失败"} · ${escapeHtml(action.actor_subject)}</li>`,
    )
    .join("");
  return `<aside class="detail" aria-labelledby="member-detail-title"><h2 id="member-detail-title">会员详情</h2><p><strong>${escapeHtml(member.nickname ?? member.display_name)}</strong><br>${escapeHtml(member.email)}</p><dl><dt>用户 ID</dt><dd><code>${escapeHtml(member.id)}</code></dd><dt>会员类型</dt><dd>${planLabel(member)} · ${periodLabel(member.period_type)}</dd><dt>产品标识</dt><dd><code>${escapeHtml(member.product_identifier ?? "待识别")}</code></dd><dt>当前状态</dt><dd>${statusLabel(member, nowMs)}</dd><dt>到期时间</dt><dd>${formatDateTime(member.expires_at)}</dd><dt>本期购买</dt><dd>${formatDateTime(member.purchase_at)}</dd><dt>首次购买</dt><dd>${formatDateTime(member.original_purchase_at)}</dd><dt>商店 / 环境</dt><dd>${escapeHtml(member.store ?? "待识别")} / ${environmentLabel(member.is_sandbox)}</dd><dt>所有权</dt><dd>${escapeHtml(member.ownership_type ?? "-")}</dd><dt>最后事件</dt><dd>${formatDateTime(member.last_event_at)}</dd><dt>最后权威同步</dt><dd>${formatDateTime(member.verified_at)}</dd><dt>快照来源</dt><dd>${escapeHtml(member.source)}</dd></dl><div class="detail-actions"><form method="post" action="/admin/members/action"><input type="hidden" name="csrfToken" value="${csrfToken}"><input type="hidden" name="action" value="reconcile"><input type="hidden" name="userId" value="${escapeHtml(member.id)}"><button type="submit">立即同步 RevenueCat 状态</button></form><a href="/admin/members">关闭详情</a></div>${actionRows ? `<h3>最近管理操作</h3><ul>${actionRows}</ul>` : ""}</aside>`;
}

function addStatusFilter(
  where: string[],
  bindings: unknown[],
  status: string,
  nowIso: string,
  expiringIso: string,
): void {
  const active = "membership_snapshots.is_active = 1 AND (membership_snapshots.expires_at IS NULL OR membership_snapshots.expires_at > ?)";
  if (status === "active") {
    where.push(`(${active})`);
    bindings.push(nowIso);
  } else if (status === "trial") {
    where.push(`(${active})`, "membership_snapshots.period_type = 'trial'");
    bindings.push(nowIso);
  } else if (status === "expiring") {
    where.push(
      "membership_snapshots.is_active = 1 AND membership_snapshots.expires_at > ? AND membership_snapshots.expires_at <= ?",
    );
    bindings.push(nowIso, expiringIso);
  } else if (status === "canceling") {
    where.push(`(${active})`, "membership_snapshots.unsubscribe_detected_at IS NOT NULL");
    bindings.push(nowIso);
  } else if (status === "billing_issue") {
    where.push(`(${active})`, "membership_snapshots.billing_issue_detected_at IS NOT NULL");
    bindings.push(nowIso);
  } else if (status === "expired") {
    where.push(
      "NOT (membership_snapshots.is_active = 1 AND (membership_snapshots.expires_at IS NULL OR membership_snapshots.expires_at > ?))",
    );
    bindings.push(nowIso);
  }
}

function addPlanFilter(where: string[], plan: string): void {
  if (plan === "monthly") {
    where.push("membership_snapshots.product_identifier IN ('premium:monthly', 'monthly')");
  } else if (plan === "annual") {
    where.push("membership_snapshots.product_identifier IN ('premium:annual', 'annual')");
  } else if (plan === "promotional") {
    where.push("membership_snapshots.store = 'promotional'");
  } else if (plan === "other") {
    where.push("membership_snapshots.product_identifier IS NOT NULL AND membership_snapshots.product_identifier NOT IN ('premium:monthly', 'monthly', 'premium:annual', 'annual') AND COALESCE(membership_snapshots.store, '') <> 'promotional'");
  } else if (plan === "unknown") {
    where.push("membership_snapshots.product_identifier IS NULL");
  }
}

function addEnvironmentFilter(where: string[], environment: string): void {
  if (environment === "production") {
    where.push("membership_snapshots.is_sandbox = 0");
  } else if (environment === "sandbox") {
    where.push("membership_snapshots.is_sandbox = 1");
  } else if (environment === "unknown") {
    where.push("membership_snapshots.is_sandbox IS NULL");
  }
}

function membershipOrder(
  sort: string,
  nowIso: string,
): { sql: string; bindings: unknown[] } {
  if (sort === "expires_desc") {
    return {
      sql: "CASE WHEN membership_snapshots.expires_at IS NULL THEN 1 ELSE 0 END, membership_snapshots.expires_at DESC, users.created_at DESC",
      bindings: [],
    };
  }
  if (sort === "purchase_desc") {
    return {
      sql: "CASE WHEN membership_snapshots.purchase_at IS NULL THEN 1 ELSE 0 END, membership_snapshots.purchase_at DESC, users.created_at DESC",
      bindings: [],
    };
  }
  if (sort === "purchase_asc") {
    return {
      sql: "CASE WHEN membership_snapshots.purchase_at IS NULL THEN 1 ELSE 0 END, membership_snapshots.purchase_at, users.created_at DESC",
      bindings: [],
    };
  }
  if (sort === "verified_desc") {
    return {
      sql: "CASE WHEN membership_snapshots.verified_at IS NULL THEN 1 ELSE 0 END, membership_snapshots.verified_at DESC, users.created_at DESC",
      bindings: [],
    };
  }
  return {
    sql: "CASE WHEN membership_snapshots.is_active = 1 AND (membership_snapshots.expires_at IS NULL OR membership_snapshots.expires_at > ?) THEN 0 ELSE 1 END, CASE WHEN membership_snapshots.expires_at IS NULL THEN 1 ELSE 0 END, membership_snapshots.expires_at, users.created_at DESC",
    bindings: [nowIso],
  };
}

function positiveInteger(value: string | null): number | null {
  if (value === null || !/^\d+$/.test(value)) return null;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function planLabel(member: MemberRow): string {
  if (member.store === "promotional") return "赠送";
  if (["premium:monthly", "monthly"].includes(member.product_identifier ?? "")) {
    return "月卡";
  }
  if (["premium:annual", "annual"].includes(member.product_identifier ?? "")) {
    return "年卡";
  }
  return member.product_identifier === null
    ? "待识别"
    : escapeHtml(member.product_identifier);
}

function periodLabel(periodType: string | null): string {
  return periodType === "trial"
    ? "试用"
    : periodType === "intro"
      ? "优惠期"
      : periodType === "normal"
        ? "常规"
        : "-";
}

function statusLabel(member: MemberRow, nowMs: number): string {
  const active =
    member.is_active === 1 &&
    (member.expires_at === null || Date.parse(member.expires_at) > nowMs);
  if (!active) return '<span class="status status--danger">已失效</span>';
  if (member.billing_issue_detected_at !== null) {
    return '<span class="status status--danger">账单异常</span>';
  }
  if (member.unsubscribe_detected_at !== null) {
    return '<span class="status status--warn">已取消续费</span>';
  }
  return '<span class="status status--ok">有效</span>';
}

function environmentLabel(isSandbox: number | null): string {
  return isSandbox === 1 ? "沙盒" : isSandbox === 0 ? "正式" : "待识别";
}

function formatDateTime(value: string | null): string {
  if (value === null) return "-";
  const date = new Date(value);
  return Number.isFinite(date.getTime())
    ? escapeHtml(date.toISOString().replace("T", " ").replace(".000Z", " UTC"))
    : "-";
}

function options(
  selected: string,
  values: Array<[string, string]>,
): string {
  return values
    .map(
      ([value, label]) =>
        `<option value="${value}"${selected === value ? " selected" : ""}>${label}</option>`,
    )
    .join("");
}

function pageLink(params: URLSearchParams, page: number, label: string): string {
  const next = new URLSearchParams(params);
  next.set("page", String(page));
  return `<a href="?${escapeHtml(next.toString())}">${label}</a>`;
}

function memberDetailHref(params: URLSearchParams, userId: string): string {
  const next = new URLSearchParams(params);
  next.set("member", userId);
  return `?${escapeHtml(next.toString())}`;
}

function membershipFeedback(params: URLSearchParams): string {
  if (params.get("synced") === "1") {
    return '<p class="notice" role="status">会员状态已从 RevenueCat 同步并写入审计记录。</p>';
  }
  const applied = boundedCount(params.get("backfilled"));
  const failed = boundedCount(params.get("failed"));
  if (applied === null || failed === null) return "";
  return `<p class="notice" role="status">批量补齐完成：成功 ${applied} 条，失败 ${failed} 条。失败项已记录，可稍后重试。</p>`;
}

function boundedCount(value: string | null): number | null {
  if (value === null || !/^\d{1,2}$/.test(value)) return null;
  const parsed = Number(value);
  return parsed <= 10 ? parsed : null;
}

async function renderQueue(env: Env, csrfToken: string): Promise<Response> {
  const reports = await env.DB.prepare(
    "SELECT avatar_reports.id, avatar_reports.reported_user_id AS target_user_id, users.display_name, users.nickname, avatar_reports.reason, avatar_reports.details, avatar_reports.avatar_source, avatar_reports.avatar_object_id, users.custom_avatar_object_id AS current_avatar_object_id, users.avatar_upload_suspended_at, users.public_avatar_hidden_at, avatar_objects.object_key, avatar_reports.created_at FROM avatar_reports INNER JOIN users ON users.id = avatar_reports.reported_user_id LEFT JOIN avatar_objects ON avatar_objects.id = avatar_reports.avatar_object_id WHERE avatar_reports.status = 'open' ORDER BY avatar_reports.created_at",
  ).all<ReportRow>();
  const rows = reports.results
    .map((report) => renderReport(report, csrfToken))
    .join("");
  const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="robots" content="noindex,nofollow"><title>头像举报审核 · PushupAI</title><style>${adminStyles}</style></head>
<body><header class="topbar"><a class="brand" href="/admin/members">PUSHUPAI / OPS</a><nav aria-label="管理台导航"><a href="/admin/members">会员运营</a><a href="/admin/avatar-reports" aria-current="page">头像审核</a></nav></header><main><section class="hero"><div><p class="eyebrow">TRUST &amp; SAFETY</p><h1>头像举报审核</h1><p>处理公开头像举报、隐藏违规内容或暂停上传权限；所有操作保留审计记录。</p></div></section><div class="reports">${rows || "<p>暂无待审核举报</p>"}</div></main></body></html>`;
  return new Response(html, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
    },
  });
}

function renderReport(report: ReportRow, csrfToken: string): string {
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
        `<form method="post" action="/admin/avatar-reports/action"><input type="hidden" name="csrfToken" value="${csrfToken}"><input type="hidden" name="reportId" value="${escapeHtml(report.id)}"><input type="hidden" name="action" value="${action}"><button type="submit">${label}</button></form>`,
    )
    .join("");
  return `<section class="report"><h2>${escapeHtml(report.nickname ?? report.display_name)}</h2><p>账号：${escapeHtml(report.target_user_id)}</p><p>举报时间：${escapeHtml(report.created_at)}</p><p>原因：${escapeHtml(report.reason)}</p><p>说明：${escapeHtml(report.details ?? "-")}</p><p>头像来源：${escapeHtml(report.avatar_source)}</p><p>头像版本：${escapeHtml(report.avatar_object_id ?? "-")}${stale ? "（已过期）" : ""}</p>${forms}</section>`;
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
  form: FormData,
  requestUrl: string,
  env: Env,
  actor: string,
): Promise<Response> {
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
  return redirectToQueue(requestUrl);
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
