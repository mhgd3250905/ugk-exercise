import { getAuthoritativeMembership } from "./membership_reconciliation.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";
import { rankingDateForShanghai } from "./workouts.js";

type LeaderboardRankRow = {
  rank: number;
  userId: string;
  totalValue: number;
};

export type PublicLeaderboardIdentityRow = {
  identity_mode: string;
  anonymous_avatar_key: string | null;
  display_name: string;
  avatar_url: string | null;
  nickname: string | null;
  avatar_key: string | null;
  custom_avatar_object_id: string | null;
  custom_avatar_status: string | null;
  public_avatar_hidden_at: string | null;
};

type LeaderboardQueryRow = PublicLeaderboardIdentityRow & {
  user_id: string;
  total_value: number;
};

type LeaderboardDecoratedRow = LeaderboardRankRow & {
  nickname: string | null;
  avatarKey: string | null;
  avatarUrl: string | null;
};

type LeaderboardProfileRow = {
  is_joined: number;
  identity_mode: string;
  anonymous_avatar_key: string;
};

export type PublicLeaderboardIdentity = {
  nickname: string | null;
  avatarKey: string | null;
  avatarUrl: string | null;
};

type LeaderboardIdentityFields = {
  mode: "profile" | "anonymous";
};

type LeaderboardCursor = {
  v: 1;
  period: "day" | "week";
  exerciseType: "pushup";
  totalValue: number;
  userId: string;
};

const leaderboardPageSize = 20;

const anonymousAvatarKeys = [
  "ring-green",
  "ring-lime",
  "ring-sky",
  "ring-yellow",
  "ring-coral",
] as const;

export function weekRangeForShanghai(
  nowIso: string,
): { start: string; end: string } {
  const shifted = new Date(Date.parse(nowIso) + 8 * 60 * 60 * 1000);
  const day = shifted.getUTCDay() || 7;
  const monday = new Date(shifted);
  monday.setUTCDate(shifted.getUTCDate() - day + 1);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);
  return {
    start: monday.toISOString().slice(0, 10),
    end: sunday.toISOString().slice(0, 10),
  };
}

export function rowsForLeaderboardForTest(input: {
  totals: Array<{ userId: string; total: number }>;
  me: string;
  limit: number;
}): { top: LeaderboardRankRow[]; me: LeaderboardRankRow | null } {
  return rankLeaderboardRows(input);
}

export function rankLeaderboardRows(input: {
  totals: Array<{ userId: string; total: number }>;
  me: string;
  limit: number;
}): { top: LeaderboardRankRow[]; me: LeaderboardRankRow | null } {
  const ranked = rankRows(input.totals);
  return {
    top: ranked.slice(0, input.limit),
    me: ranked.find((row) => row.userId === input.me) ?? null,
  };
}

function rankRows(
  totals: Array<{ userId: string; total: number }>,
): LeaderboardRankRow[] {
  return [...totals]
    .sort((left, right) =>
      right.total !== left.total
        ? right.total - left.total
        : left.userId.localeCompare(right.userId),
    )
    .map((row, index) => ({
      rank: index + 1,
      userId: row.userId,
      totalValue: row.total,
    }));
}

function encodeLeaderboardCursor(cursor: LeaderboardCursor): string {
  const bytes = new TextEncoder().encode(JSON.stringify(cursor));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/, "");
}

function decodeLeaderboardCursor(
  value: string,
  period: "day" | "week",
  exerciseType: "pushup",
): LeaderboardCursor | null {
  try {
    const base64 = value.replaceAll("-", "+").replaceAll("_", "/");
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (character) =>
      character.charCodeAt(0),
    );
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Partial<
      LeaderboardCursor
    >;
    if (
      parsed.v !== 1 ||
      parsed.period !== period ||
      parsed.exerciseType !== exerciseType ||
      !Number.isInteger(parsed.totalValue) ||
      parsed.totalValue! < 0 ||
      typeof parsed.userId !== "string" ||
      parsed.userId.length === 0
    ) {
      return null;
    }
    return parsed as LeaderboardCursor;
  } catch {
    return null;
  }
}

export async function joinLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  if (!(await membershipActiveForUser(env, session.userId))) {
    return json({ error: "premium_required" }, 403);
  }
  const identity = await prepareLeaderboardIdentity(request, true);
  if (identity instanceof Response) return identity;
  const now = new Date().toISOString();
  const week = weekRangeForShanghai(now);
  // Atomically (one D1 batch, DELETE before upsert so it reads the PRE-write
  // profile state):
  //   1. Clear this user's CURRENT Shanghai-week aggregates ONLY when the
  //      stored profile is currently left (is_joined = 0). This is the genuine
  //      rejoin-after-leave path: stale pre-leave scores must not revive. A
  //      first join has no profile row (no-op) and a repeat join while already
  //      joined keeps is_joined = 1 (no-op), so totals survive an idempotent
  //      repeat join — preserving Task 5's "repeated join keeps totals".
  //   2. Mark joined, preserving joined_at for an already-joined user and
  //      writing a fresh joined_at for a rejoin-after-leave.
  await env.DB.batch([
    env.DB.prepare(
      "DELETE FROM leaderboard_daily_totals WHERE user_id = ? AND ranking_date BETWEEN ? AND ? AND EXISTS (SELECT 1 FROM leaderboard_profiles WHERE user_id = ? AND is_joined = 0)",
    ).bind(session.userId, week.start, week.end, session.userId),
    env.DB.prepare(
      "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at, identity_mode, anonymous_avatar_key) VALUES (?, 1, ?, NULL, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET is_joined = 1, joined_at = CASE WHEN leaderboard_profiles.is_joined = 1 AND leaderboard_profiles.joined_at IS NOT NULL THEN leaderboard_profiles.joined_at ELSE excluded.joined_at END, left_at = NULL, updated_at = excluded.updated_at, identity_mode = excluded.identity_mode, anonymous_avatar_key = leaderboard_profiles.anonymous_avatar_key",
    ).bind(
      session.userId,
      now,
      now,
      identity.mode,
      anonymousAvatarKeyForUser(session.userId),
    ),
  ]);
  const profile = await env.DB.prepare(
    "SELECT joined_at FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(session.userId)
    .first<{ joined_at: string | null }>();
  return json({ ok: true, joinedAt: profile?.joined_at ?? now });
}

export async function updateLeaderboardIdentity(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  if (!(await membershipActiveForUser(env, session.userId))) {
    return json({ error: "premium_required" }, 403);
  }
  const profile = await env.DB.prepare(
    "SELECT is_joined FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(session.userId)
    .first<LeaderboardProfileRow>();
  if (profile?.is_joined !== 1) {
    return json({ error: "leaderboard_not_joined" }, 409);
  }
  const identity = await prepareLeaderboardIdentity(request, false);
  if (identity instanceof Response) return identity;

  const result = await env.DB.prepare(
    "UPDATE leaderboard_profiles SET identity_mode = ?, updated_at = ? WHERE user_id = ? AND is_joined = 1",
  )
    .bind(identity.mode, new Date().toISOString(), session.userId)
    .run();
  if (result.meta.changes === 0) {
    return json({ error: "leaderboard_not_joined" }, 409);
  }
  return json({ ok: true });
}

export async function leaveLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const now = new Date().toISOString();
  await env.DB.prepare(
    "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, 0, NULL, ?, ?) ON CONFLICT(user_id) DO UPDATE SET is_joined = 0, left_at = excluded.left_at, updated_at = excluded.updated_at",
  )
    .bind(session.userId, now, now)
    .run();
  return json({ ok: true });
}

export async function getLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const url = new URL(request.url);
  const period = url.searchParams.get("period") ?? "day";
  const exerciseType = url.searchParams.get("exerciseType") ?? "pushup";
  if (exerciseType !== "pushup" || (period !== "day" && period !== "week")) {
    return json({ error: "invalid_leaderboard_query" }, 400);
  }
  const cursorValue = url.searchParams.get("cursor");
  const cursor = cursorValue
    ? decodeLeaderboardCursor(cursorValue, period, exerciseType)
    : null;
  if (cursorValue !== null && cursor === null) {
    return json({ error: "invalid_leaderboard_query" }, 400);
  }
  const profile = await env.DB.prepare(
    "SELECT is_joined, identity_mode, anonymous_avatar_key FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(session.userId)
    .first<LeaderboardProfileRow>();
  const isJoined = profile?.is_joined === 1;
  const membershipActive = await membershipActiveForUser(env, session.userId);
  const canJoin = !isJoined && membershipActive;
  const now = new Date().toISOString();
  const rows =
    period === "day"
      ? await dayRows(env, exerciseType, rankingDateForShanghai(now))
      : await weekRows(env, exerciseType, weekRangeForShanghai(now));
  // ponytail: rank in memory to preserve the existing me/identity query; move
  // the opaque cursor behind D1 keyset pagination if leaderboard latency grows.
  const rankedRows = rankRows(
    rows.map((row) => ({ userId: row.user_id, total: row.total_value })),
  );
  const blocks = await env.DB.prepare(
    "SELECT blocked_user_id FROM user_blocks WHERE blocker_user_id = ?",
  )
    .bind(session.userId)
    .all<{ blocked_user_id: string }>();
  const blockedUserIds = new Set(
    blocks.results.map((row) => row.blocked_user_id),
  );
  const visibleRows = rankedRows.filter(
    (row) => !blockedUserIds.has(row.userId),
  );
  const remaining = cursor
    ? visibleRows.filter(
        (row) =>
          row.totalValue < cursor.totalValue ||
          (row.totalValue === cursor.totalValue &&
            row.userId.localeCompare(cursor.userId) > 0),
      )
    : visibleRows;
  const page = remaining.slice(0, leaderboardPageSize);
  const lastRow = page.at(-1);
  const nextCursor =
    remaining.length > leaderboardPageSize && lastRow
      ? encodeLeaderboardCursor({
          v: 1,
          period,
          exerciseType,
          totalValue: lastRow.totalValue,
          userId: lastRow.userId,
        })
      : null;
  const me = rankedRows.find((row) => row.userId === session.userId) ?? null;
  const frozenTotalValue =
    isJoined && !membershipActive ? (me?.totalValue ?? 0) : null;
  const metadata = new Map(
    rows.map((row) => [
      row.user_id,
      publicLeaderboardIdentity(row, request.url),
    ]),
  );
  return json({
    period,
    exerciseType,
    isJoined,
    canJoin,
    anonymousAvatarKey:
      profile?.anonymous_avatar_key ??
      anonymousAvatarKeyForUser(session.userId),
    identity: isJoined ? editableIdentity(profile) : null,
    nextCursor,
    top: page.map((row) => decorateRankedRow(row, metadata)),
    me: me ? decorateRankedRow(me, metadata) : null,
    ...(frozenTotalValue === null ? {} : { frozenTotalValue }),
  });
}

function decorateRankedRow(
  row: LeaderboardRankRow,
  metadata: Map<string, PublicLeaderboardIdentity>,
): LeaderboardDecoratedRow {
  const profile = metadata.get(row.userId) ?? {
    nickname: null,
    avatarKey: null,
    avatarUrl: null,
  };
  return {
    ...row,
    nickname: profile.nickname,
    avatarKey: profile.avatarKey,
    avatarUrl: profile.avatarUrl,
  };
}

export function publicLeaderboardIdentity(
  row: PublicLeaderboardIdentityRow,
  requestUrl: string,
): PublicLeaderboardIdentity {
  if (row.identity_mode === "profile") {
    if (row.public_avatar_hidden_at) {
      return {
        nickname: nonBlank(row.nickname) ?? nonBlank(row.display_name),
        avatarKey: "ring-green",
        avatarUrl: null,
      };
    }
    if (
      row.custom_avatar_object_id &&
      row.custom_avatar_status === "active"
    ) {
      return {
        nickname: nonBlank(row.nickname) ?? nonBlank(row.display_name),
        avatarKey: null,
        avatarUrl: new URL(
          `/avatars/${row.custom_avatar_object_id}.jpg`,
          requestUrl,
        ).toString(),
      };
    }
    const avatarKey = nonBlank(row.avatar_key);
    return {
      nickname: nonBlank(row.nickname) ?? nonBlank(row.display_name),
      avatarKey: avatarKey ?? (nonBlank(row.avatar_url) ? null : "ring-green"),
      avatarUrl: avatarKey ? null : nonBlank(row.avatar_url),
    };
  }
  return {
    nickname: null,
    avatarKey: row.anonymous_avatar_key,
    avatarUrl: null,
  };
}

function nonBlank(value: string | null): string | null {
  return value?.trim() || null;
}

function editableIdentity(profile: LeaderboardProfileRow): {
  mode: "profile" | "anonymous";
} {
  if (profile.identity_mode === "profile") return { mode: "profile" };
  return { mode: "anonymous" };
}

async function prepareLeaderboardIdentity(
  request: Request,
  allowEmptyBody: boolean,
): Promise<LeaderboardIdentityFields | Response> {
  let body: unknown;
  if (request.body === null) {
    if (!allowEmptyBody) {
      return json({ error: "invalid_json" }, 400);
    }
    body = { mode: "anonymous" };
  } else {
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "invalid_json" }, 400);
  }

  const input = body as Record<string, unknown>;
  if (input.mode === "profile" || input.mode === "anonymous") {
    return { mode: input.mode };
  }
  return json({ error: "invalid_identity_mode" }, 400);
}

function anonymousAvatarKeyForUser(
  userId: string,
): (typeof anonymousAvatarKeys)[number] {
  let hash = 0;
  for (let index = 0; index < userId.length; index += 1) {
    hash = (hash * 31 + userId.charCodeAt(index)) >>> 0;
  }
  return anonymousAvatarKeys[hash % anonymousAvatarKeys.length];
}

async function membershipActiveForUser(
  env: Env,
  userId: string,
): Promise<boolean> {
  return (await getAuthoritativeMembership(env, userId)).isActive;
}

async function dayRows(
  env: Env,
  exerciseType: string,
  rankingDate: string,
): Promise<LeaderboardQueryRow[]> {
  const result = await env.DB.prepare(
    "SELECT profiles.user_id, COALESCE(totals.total_value, 0) AS total_value, profiles.identity_mode, profiles.anonymous_avatar_key, users.display_name, users.avatar_url, users.nickname, users.avatar_key, users.custom_avatar_object_id, users.public_avatar_hidden_at, avatar_objects.status AS custom_avatar_status FROM leaderboard_profiles AS profiles INNER JOIN users ON users.id = profiles.user_id LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id LEFT JOIN leaderboard_daily_totals AS totals ON totals.user_id = profiles.user_id AND totals.exercise_type = ? AND totals.ranking_date = ? WHERE profiles.is_joined = 1 ORDER BY total_value DESC, profiles.user_id ASC",
  )
    .bind(exerciseType, rankingDate)
    .all<LeaderboardQueryRow>();
  return result.results;
}

async function weekRows(
  env: Env,
  exerciseType: string,
  range: { start: string; end: string },
): Promise<LeaderboardQueryRow[]> {
  const result = await env.DB.prepare(
    "SELECT profiles.user_id, COALESCE(totals.total_value, 0) AS total_value, profiles.identity_mode, profiles.anonymous_avatar_key, users.display_name, users.avatar_url, users.nickname, users.avatar_key, users.custom_avatar_object_id, users.public_avatar_hidden_at, avatar_objects.status AS custom_avatar_status FROM leaderboard_profiles AS profiles LEFT JOIN (SELECT user_id, SUM(total_value) AS total_value FROM leaderboard_daily_totals WHERE exercise_type = ? AND ranking_date BETWEEN ? AND ? GROUP BY user_id) AS totals ON totals.user_id = profiles.user_id INNER JOIN users ON users.id = profiles.user_id LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id WHERE profiles.is_joined = 1 ORDER BY total_value DESC, profiles.user_id ASC",
  )
    .bind(exerciseType, range.start, range.end)
    .all<LeaderboardQueryRow>();
  return result.results;
}
