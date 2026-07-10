import { membershipIsActive } from "./membership_state.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";
import { rankingDateForShanghai } from "./workouts.js";

type LeaderboardRankRow = {
  rank: number;
  userId: string;
  totalValue: number;
};

type LeaderboardQueryRow = {
  user_id: string;
  total_value: number;
  nickname: string | null;
  avatar_key: string | null;
};

type LeaderboardDecoratedRow = LeaderboardRankRow & {
  nickname: string | null;
  avatarKey: string | null;
};

type LeaderboardProfileRow = {
  is_joined: number;
};

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
  const ranked = [...input.totals]
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
  return {
    top: ranked.slice(0, input.limit),
    me: ranked.find((row) => row.userId === input.me) ?? null,
  };
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
      "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, 1, ?, NULL, ?) ON CONFLICT(user_id) DO UPDATE SET is_joined = 1, joined_at = CASE WHEN leaderboard_profiles.is_joined = 1 AND leaderboard_profiles.joined_at IS NOT NULL THEN leaderboard_profiles.joined_at ELSE excluded.joined_at END, left_at = NULL, updated_at = excluded.updated_at",
    ).bind(session.userId, now, now),
  ]);
  const profile = await env.DB.prepare(
    "SELECT joined_at FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(session.userId)
    .first<{ joined_at: string | null }>();
  return json({ ok: true, joinedAt: profile?.joined_at ?? now });
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
  const profile = await env.DB.prepare(
    "SELECT is_joined FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(session.userId)
    .first<LeaderboardProfileRow>();
  const now = new Date().toISOString();
  const rows =
    period === "day"
      ? await dayRows(env, exerciseType, rankingDateForShanghai(now), now)
      : await weekRows(env, exerciseType, weekRangeForShanghai(now), now);
  const ranked = rankLeaderboardRows({
    totals: rows.map((row) => ({ userId: row.user_id, total: row.total_value })),
    me: session.userId,
    limit: 100,
  });
  const metadata = new Map(
    rows.map((row) => [
      row.user_id,
      {
        nickname: row.nickname,
        avatarKey: row.avatar_key,
      },
    ]),
  );
  return json({
    period,
    exerciseType,
    isJoined: profile?.is_joined === 1,
    top: ranked.top.map((row) => decorateRankedRow(row, metadata)),
    me: ranked.me ? decorateRankedRow(ranked.me, metadata) : null,
  });
}

function decorateRankedRow(
  row: LeaderboardRankRow,
  metadata: Map<string, { nickname: string | null; avatarKey: string | null }>,
): LeaderboardDecoratedRow {
  const profile = metadata.get(row.userId) ?? {
    nickname: null,
    avatarKey: null,
  };
  return {
    ...row,
    nickname: profile.nickname,
    avatarKey: profile.avatarKey,
  };
}

async function membershipActiveForUser(
  env: Env,
  userId: string,
): Promise<boolean> {
  const snapshot = await env.DB.prepare(
    "SELECT is_active, expires_at FROM membership_snapshots WHERE user_id = ?",
  )
    .bind(userId)
    .first<{ is_active: number; expires_at: string | null }>();
  return snapshot
    ? membershipIsActive(snapshot.is_active, snapshot.expires_at)
    : false;
}

async function dayRows(
  env: Env,
  exerciseType: string,
  rankingDate: string,
  nowIso: string,
): Promise<LeaderboardQueryRow[]> {
  // Membership is re-checked at query time: only users whose snapshot is
  // currently active AND unexpired may rank, even if they have historical
  // aggregate rows or is_joined = 1. This prevents expired/lapsed members from
  // appearing after their entitlement ends.
  const result = await env.DB.prepare(
    "SELECT totals.user_id, totals.total_value, users.nickname, users.avatar_key FROM leaderboard_daily_totals AS totals INNER JOIN leaderboard_profiles AS profiles ON profiles.user_id = totals.user_id AND profiles.is_joined = 1 INNER JOIN membership_snapshots AS membership ON membership.user_id = totals.user_id AND membership.is_active = 1 AND (membership.expires_at IS NULL OR membership.expires_at > ?) INNER JOIN users ON users.id = totals.user_id WHERE totals.exercise_type = ? AND totals.ranking_date = ? ORDER BY totals.total_value DESC, totals.user_id ASC",
  )
    .bind(nowIso, exerciseType, rankingDate)
    .all<LeaderboardQueryRow>();
  return result.results;
}

async function weekRows(
  env: Env,
  exerciseType: string,
  range: { start: string; end: string },
  nowIso: string,
): Promise<LeaderboardQueryRow[]> {
  const result = await env.DB.prepare(
    "SELECT totals.user_id, totals.total_value, users.nickname, users.avatar_key FROM (SELECT user_id, SUM(total_value) AS total_value FROM leaderboard_daily_totals WHERE exercise_type = ? AND ranking_date BETWEEN ? AND ? GROUP BY user_id) AS totals INNER JOIN leaderboard_profiles AS profiles ON profiles.user_id = totals.user_id AND profiles.is_joined = 1 INNER JOIN membership_snapshots AS membership ON membership.user_id = totals.user_id AND membership.is_active = 1 AND (membership.expires_at IS NULL OR membership.expires_at > ?) INNER JOIN users ON users.id = totals.user_id ORDER BY totals.total_value DESC, totals.user_id ASC",
  )
    .bind(exerciseType, range.start, range.end, nowIso)
    .all<LeaderboardQueryRow>();
  return result.results;
}
