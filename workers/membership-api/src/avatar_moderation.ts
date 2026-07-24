import {
  publicLeaderboardIdentity,
  type PublicLeaderboardIdentityRow,
} from "./leaderboard.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

const reportReasons = new Set([
  "nudity",
  "violence",
  "hate",
  "spam",
  "impersonation",
  "other",
]);

// Per-reporter sliding-window cap. Reports are deduplicated per
// (reporter, reported, report_type, avatar_source, object), but a single
// premium account can still flood distinct targets with open reports. That
// unbounded growth directly DoSes the admin moderation console (renderQueue
// renders every open report into one HTML page). The window/threshold below
// are generous enough for any honest reporter and tight enough to stop a
// scripted flood before it can overwhelm moderation.
const REPORT_WINDOW_HOURS = 1;
const REPORT_MAX_PER_WINDOW = 20;

export async function reportLeaderboardUser(
  request: Request,
  env: Env,
  reportedUserId: string,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  if (session.userId === reportedUserId) {
    return json({ error: "cannot_report_self" }, 400);
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "invalid_json" }, 400);
  }
  const input = body as Record<string, unknown>;
  const details = typeof input.details === "string" ? input.details.trim() : "";
  if (
    (input.reportType !== "avatar" && input.reportType !== "user") ||
    typeof input.reason !== "string" ||
    !reportReasons.has(input.reason) ||
    details.length > 200
  ) {
    return json({ error: "invalid_report" }, 400);
  }
  // Rate-limit the reporter: count reports this account created inside the
  // sliding window. The dedupe index only collapses repeat reports against the
  // SAME target; without this cap a single account can open reports against
  // arbitrarily many distinct users and starve the moderation queue.
  //
  // This is a soft flood brake, not a hard security bound. The count-then-
  // insert sequence is not atomic across concurrent requests, so two requests
  // racing at the threshold can each pass and overshoot by the request
  // concurrency (bounded by Worker request limits). That is acceptable here
  // because the goal is to stop unbounded scripted flooding of the moderation
  // queue, which renderQueue's LIMIT 100 backstops; a few extra reports do not
  // change the outcome. The COUNT is served by avatar_reports_reporter_created_idx
  // (migrations/0007) so the rate-limit check itself cannot become a scan DoS.
  const since = new Date(Date.now() - REPORT_WINDOW_HOURS * 60 * 60 * 1000).toISOString();
  const recent = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM avatar_reports WHERE reporter_user_id = ? AND created_at >= ?",
  )
    .bind(session.userId, since)
    .first<{ n: number }>();
  if ((recent?.n ?? 0) >= REPORT_MAX_PER_WINDOW) {
    return json({ error: "rate_limited" }, 429);
  }
  const target = await env.DB.prepare(
    "SELECT profiles.identity_mode, users.avatar_url, users.avatar_key, users.custom_avatar_object_id, users.public_avatar_hidden_at, avatar_objects.status AS custom_avatar_status FROM users INNER JOIN leaderboard_profiles AS profiles ON profiles.user_id = users.id AND profiles.is_joined = 1 LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id WHERE users.id = ?",
  )
    .bind(reportedUserId)
    .first<{
      identity_mode: string;
      avatar_url: string | null;
      avatar_key: string | null;
      custom_avatar_object_id: string | null;
      public_avatar_hidden_at: string | null;
      custom_avatar_status: string | null;
    }>();
  if (!target) return json({ error: "report_target_not_found" }, 404);

  const avatar = reportableAvatar(target);
  if (input.reportType === "avatar" && avatar.source === "none") {
    return json({ error: "invalid_report_target" }, 400);
  }
  const now = new Date().toISOString();
  await env.DB.batch([
    env.DB.prepare(
      "INSERT OR IGNORE INTO avatar_reports (id, reporter_user_id, reported_user_id, report_type, avatar_object_id, avatar_source, reason, details, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'open', ?)",
    ).bind(
      crypto.randomUUID(),
      session.userId,
      reportedUserId,
      input.reportType,
      avatar.objectId,
      avatar.source,
      input.reason,
      details || null,
      now,
    ),
    env.DB.prepare(
      "INSERT OR IGNORE INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)",
    ).bind(session.userId, reportedUserId, now),
  ]);
  return json({ ok: true });
}

export async function updateUserBlock(
  request: Request,
  env: Env,
  blockedUserId: string,
  blocked: boolean,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  if (session.userId === blockedUserId) {
    return json({ error: "cannot_block_self" }, 400);
  }
  const target = await env.DB.prepare("SELECT id FROM users WHERE id = ?")
    .bind(blockedUserId)
    .first<{ id: string }>();
  if (!target) return json({ error: "block_target_not_found" }, 404);
  if (blocked) {
    await env.DB.prepare(
      "INSERT OR IGNORE INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)",
    )
      .bind(session.userId, blockedUserId, new Date().toISOString())
      .run();
  } else {
    await env.DB.prepare(
      "DELETE FROM user_blocks WHERE blocker_user_id = ? AND blocked_user_id = ?",
    )
      .bind(session.userId, blockedUserId)
      .run();
  }
  return json({ ok: true });
}

export async function listUserBlocks(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const result = await env.DB.prepare(
    "SELECT blocks.blocked_user_id AS user_id, CASE WHEN profiles.is_joined = 1 THEN profiles.identity_mode ELSE 'anonymous' END AS identity_mode, COALESCE(profiles.anonymous_avatar_key, 'ring-green') AS anonymous_avatar_key, users.display_name, users.avatar_url, users.nickname, users.avatar_key, users.custom_avatar_object_id, users.public_avatar_hidden_at, avatar_objects.status AS custom_avatar_status FROM user_blocks AS blocks INNER JOIN users ON users.id = blocks.blocked_user_id LEFT JOIN leaderboard_profiles AS profiles ON profiles.user_id = blocks.blocked_user_id LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id WHERE blocks.blocker_user_id = ? ORDER BY blocks.created_at DESC, blocks.blocked_user_id ASC",
  )
    .bind(session.userId)
    .all<PublicLeaderboardIdentityRow & { user_id: string }>();
  return json({
    blocks: result.results.map((row) => ({
      userId: row.user_id,
      ...publicLeaderboardIdentity(row, request.url),
    })),
  });
}

function reportableAvatar(target: {
  identity_mode: string;
  avatar_url: string | null;
  avatar_key: string | null;
  custom_avatar_object_id: string | null;
  public_avatar_hidden_at: string | null;
  custom_avatar_status: string | null;
}): { source: "custom" | "google" | "none"; objectId: string | null } {
  if (target.identity_mode !== "profile" || target.public_avatar_hidden_at) {
    return { source: "none", objectId: null };
  }
  if (
    target.custom_avatar_object_id &&
    target.custom_avatar_status === "active"
  ) {
    return { source: "custom", objectId: target.custom_avatar_object_id };
  }
  if (target.avatar_key?.trim()) return { source: "none", objectId: null };
  return target.avatar_url?.trim()
    ? { source: "google", objectId: null }
    : { source: "none", objectId: null };
}
