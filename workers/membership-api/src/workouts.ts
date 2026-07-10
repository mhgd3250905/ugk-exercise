import { membershipIsActive } from "./membership_state.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

type WorkoutInput = {
  clientSessionId: string;
  exerciseType: string;
  startedAt: string;
  endedAt: string;
  localDate: string;
  timezoneOffsetMinutes: number;
  metricValue: number;
  metricUnit: string;
};

type WorkoutRow = {
  client_session_id: string;
  exercise_type: string;
  started_at: string;
  ended_at: string;
  local_date: string;
  metric_value: number;
  metric_unit: string;
};

export type SyncResult =
  | { clientSessionId: string; status: "accepted"; aggregated: boolean }
  | { clientSessionId: string; status: "duplicate" }
  | { clientSessionId: string; status: "rejected"; reason: string };

export function rankingDateForShanghai(endedAt: string): string {
  const value = Date.parse(endedAt);
  const shifted = new Date(value + 8 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

// Generous per-Shanghai-ranking-day cap. Calibration constant, not a
// per-request limit; enforced atomically with insertion so concurrent uploads
// cannot collectively breach it.
export const DAILY_RANKING_LIMIT = 5000;

// Soft ceiling on a single batch. Real batches are one day's sessions; 200 is
// well above any legitimate use and keeps the request body bounded.
const MAX_BATCH_SIZE = 200;
const MAX_CLIENT_SESSION_ID_LENGTH = 200;
// A clock may run slightly ahead, and clients round to seconds; tolerate a
// short window before treating endedAt as materially in the future.
const FUTURE_ENDED_AT_TOLERANCE_MS = 60 * 1000;

export function validateWorkout(input: WorkoutInput): string | null {
  if (input.clientSessionId.length === 0 || input.clientSessionId.length > MAX_CLIENT_SESSION_ID_LENGTH) {
    return "invalid_client_session_id";
  }
  if (input.exerciseType !== "pushup") return "invalid_exercise_type";
  if (input.metricUnit !== "reps") return "invalid_metric";
  if (!Number.isInteger(input.metricValue) || input.metricValue <= 0) {
    return "invalid_metric";
  }
  if (input.metricValue > 1000) return "session_limit_exceeded";
  if (!isValidLocalDate(input.localDate)) return "invalid_local_date";
  if (
    !Number.isInteger(input.timezoneOffsetMinutes) ||
    input.timezoneOffsetMinutes < -840 ||
    input.timezoneOffsetMinutes > 840
  ) {
    return "invalid_timezone";
  }
  const started = Date.parse(input.startedAt);
  const ended = Date.parse(input.endedAt);
  if (!Number.isFinite(started) || !Number.isFinite(ended) || ended <= started) {
    return "invalid_duration";
  }
  if ((ended - started) / 1000 > 3 * 60 * 60) return "invalid_duration";
  // localDate must be the calendar day the user trained in, derived from the
  // persisted UTC start plus their offset (Dart convention: positive = east of
  // UTC). Reject mismatches so ranking date cannot be moved by a lying client.
  if (localDateFromStarted(started, input.timezoneOffsetMinutes) !== input.localDate) {
    return "invalid_local_date";
  }
  // Reject materially-future endedAt. A legitimate upload lands within the
  // tolerance; anything beyond is either a broken clock or an attempt to game
  // future ranking days.
  if (ended - Date.now() > FUTURE_ENDED_AT_TOLERANCE_MS) {
    return "invalid_duration";
  }
  return null;
}

export function localDateFromStarted(
  startedMs: number,
  timezoneOffsetMinutes: number,
): string {
  const shifted = new Date(startedMs + timezoneOffsetMinutes * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

export async function syncWorkouts(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "invalid_json" }, 400);
  }

  if (!Array.isArray((body as { workouts?: unknown }).workouts)) {
    return json({ error: "invalid_body" }, 400);
  }
  const rawWorkouts = (body as { workouts: unknown[] }).workouts;
  if (rawWorkouts.length > MAX_BATCH_SIZE) {
    return json({ error: "batch_too_large" }, 400);
  }
  const premium = await membershipActiveForUser(env, session.userId);
  const joined = await leaderboardProfile(env, session.userId);
  const results: SyncResult[] = [];

  for (const rawWorkout of rawWorkouts) {
    const result = await syncOneWorkout({
      rawWorkout,
      premiumActive: premium,
      joinedAt:
        joined?.is_joined === 1 && joined.joined_at !== null
          ? joined.joined_at
          : null,
      writeWorkout: (workout, aggregate) =>
        writeWorkout(env, session.userId, workout, aggregate),
    });
    results.push(result);
  }

  return json({ results });
}

export async function getWorkouts(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;

  const month = new URL(request.url).searchParams.get("month") ?? "";
  if (!isValidMonth(month)) {
    return json({ error: "invalid_month" }, 400);
  }

  const rows = await env.DB.prepare(
    "SELECT client_session_id, exercise_type, started_at, ended_at, local_date, metric_value, metric_unit FROM workout_sessions WHERE user_id = ? AND local_date >= ? AND local_date < ? ORDER BY started_at DESC",
  )
    .bind(session.userId, `${month}-01`, `${nextMonth(month)}-01`)
    .all<WorkoutRow>();

  return json({
    workouts: rows.results.map((row) => ({
      clientSessionId: row.client_session_id,
      exerciseType: row.exercise_type,
      startedAt: row.started_at,
      endedAt: row.ended_at,
      localDate: row.local_date,
      metricValue: row.metric_value,
      metricUnit: row.metric_unit,
    })),
  });
}

type WriteOutcome = {
  inserted: boolean;
  aggregated: boolean;
  quotaExceeded?: boolean;
  duplicate?: boolean;
};

export async function syncWorkoutsForTest(input: {
  premiumActive: boolean;
  joinedAt: string | null;
  existingSessionIds: Set<string>;
  workouts: unknown[];
}): Promise<SyncResult[]> {
  const sessionIds = new Set(input.existingSessionIds);
  const results: SyncResult[] = [];
  for (const rawWorkout of input.workouts) {
    results.push(
      await syncOneWorkout({
        rawWorkout,
        premiumActive: input.premiumActive,
        joinedAt: input.joinedAt,
        writeWorkout: (workout, aggregate) => {
          if (sessionIds.has(workout.clientSessionId)) {
            return Promise.resolve({ inserted: false, aggregated: false });
          }
          sessionIds.add(workout.clientSessionId);
          return Promise.resolve({ inserted: true, aggregated: aggregate });
        },
      }),
    );
  }
  return results;
}

async function syncOneWorkout(input: {
  rawWorkout: unknown;
  premiumActive: boolean;
  joinedAt: string | null;
  writeWorkout: (workout: WorkoutInput, aggregate: boolean) => Promise<WriteOutcome>;
}): Promise<SyncResult> {
  const clientSessionId = resultClientSessionId(input.rawWorkout);
  if (!input.premiumActive) {
    return {
      clientSessionId,
      status: "rejected",
      reason: "premium_required",
    };
  }

  const workout = asWorkoutInput(input.rawWorkout);
  if (workout === null) {
    return { clientSessionId, status: "rejected", reason: "invalid_workout" };
  }

  const invalid = validateWorkout(workout);
  if (invalid) {
    return {
      clientSessionId: workout.clientSessionId,
      status: "rejected",
      reason: invalid,
    };
  }

  const wantAggregate = shouldAggregate(input.joinedAt, workout.endedAt);
  const outcome = await input.writeWorkout(workout, wantAggregate);
  // A quota breach is reported before the duplicate fallback, because a failed
  // quota-gated insert is indistinguishable from a duplicate until the re-check
  // resolves which guard rejected it.
  if (wantAggregate && outcome.quotaExceeded && !outcome.duplicate) {
    return {
      clientSessionId: workout.clientSessionId,
      status: "rejected",
      reason: "daily_limit_exceeded",
    };
  }
  if (!outcome.inserted) {
    return { clientSessionId: workout.clientSessionId, status: "duplicate" };
  }

  return {
    clientSessionId: workout.clientSessionId,
    status: "accepted",
    aggregated: outcome.aggregated,
  };
}

function asWorkoutInput(input: unknown): WorkoutInput | null {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    return null;
  }
  const value = input as Record<string, unknown>;
  if (
    typeof value.clientSessionId !== "string" ||
    value.clientSessionId.length === 0 ||
    typeof value.exerciseType !== "string" ||
    typeof value.startedAt !== "string" ||
    typeof value.endedAt !== "string" ||
    typeof value.localDate !== "string" ||
    typeof value.timezoneOffsetMinutes !== "number" ||
    typeof value.metricValue !== "number" ||
    typeof value.metricUnit !== "string"
  ) {
    return null;
  }
  return {
    clientSessionId: value.clientSessionId,
    exerciseType: value.exerciseType,
    startedAt: value.startedAt,
    endedAt: value.endedAt,
    localDate: value.localDate,
    timezoneOffsetMinutes: value.timezoneOffsetMinutes,
    metricValue: value.metricValue,
    metricUnit: value.metricUnit,
  };
}

function resultClientSessionId(input: unknown): string {
  if (input === null || typeof input !== "object" || Array.isArray(input)) {
    return "";
  }
  const clientSessionId = (input as Record<string, unknown>).clientSessionId;
  return typeof clientSessionId === "string" ? clientSessionId : "";
}

function shouldAggregate(joinedAt: string | null, endedAt: string): boolean {
  if (joinedAt === null) return false;
  const joined = Date.parse(joinedAt);
  const ended = Date.parse(endedAt);
  return Number.isFinite(joined) && Number.isFinite(ended) && ended >= joined;
}

function isValidLocalDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

function isValidMonth(value: string): boolean {
  const match = /^(\d{4})-(\d{2})$/.exec(value);
  if (!match) return false;
  const month = Number(match[2]);
  return month >= 1 && month <= 12;
}

function nextMonth(value: string): string {
  const year = Number(value.slice(0, 4));
  const month = Number(value.slice(5, 7));
  if (month === 12) return `${year + 1}-01`;
  return `${year.toString().padStart(4, "0")}-${(month + 1)
    .toString()
    .padStart(2, "0")}`;
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

async function leaderboardProfile(
  env: Env,
  userId: string,
): Promise<{ is_joined: number; joined_at: string | null } | null> {
  return env.DB.prepare(
    "SELECT is_joined, joined_at FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(userId)
    .first<{ is_joined: number; joined_at: string | null }>();
}

async function writeWorkout(
  env: Env,
  userId: string,
  workout: WorkoutInput,
  aggregate: boolean,
): Promise<WriteOutcome> {
  // Distinguish a duplicate client_session_id from a quota breach up front: a
  // duplicate is reported as "duplicate" and consumes neither storage nor
  // quota, while a quota breach is "daily_limit_exceeded". The actual insert
  // re-checks dedup in SQL (NOT EXISTS) so a racing duplicate request cannot
  // double-insert even if this read misses it.
  const existing = await env.DB.prepare(
    "SELECT 1 FROM workout_sessions WHERE user_id = ? AND client_session_id = ?",
  )
    .bind(userId, workout.clientSessionId)
    .first();
  if (existing) {
    return { inserted: false, aggregated: false, duplicate: true };
  }

  const workoutId = crypto.randomUUID();
  const now = new Date().toISOString();
  const started = Date.parse(workout.startedAt);
  const ended = Date.parse(workout.endedAt);
  const rankingDate = rankingDateForShanghai(workout.endedAt);
  // For ranking-eligible workouts (aggregate=true), the insert itself is gated
  // on the daily cap so the whole operation is atomic within one D1 batch
  // transaction: two concurrent requests cannot both squeeze past the cap, and
  // a session that would breach it is not persisted (so it cannot be retried
  // into the totals). Non-aggregated sessions (user not joined) are never
  // ranked and so are not subject to the ranking-day cap.
  const statements = [];
  if (aggregate) {
    statements.push(
      env.DB.prepare(
        "INSERT INTO workout_sessions (id, user_id, client_session_id, exercise_type, started_at, ended_at, duration_seconds, local_date, timezone_offset_minutes, ranking_date, metric_value, metric_unit, created_at) SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? WHERE NOT EXISTS (SELECT 1 FROM workout_sessions WHERE user_id = ? AND client_session_id = ?) AND NOT EXISTS (SELECT 1 FROM leaderboard_daily_totals WHERE user_id = ? AND exercise_type = ? AND ranking_date = ? AND total_value + ? > ?)",
      ).bind(
        workoutId,
        userId,
        workout.clientSessionId,
        workout.exerciseType,
        workout.startedAt,
        workout.endedAt,
        Math.floor((ended - started) / 1000),
        workout.localDate,
        workout.timezoneOffsetMinutes,
        rankingDate,
        workout.metricValue,
        workout.metricUnit,
        now,
        userId,
        workout.clientSessionId,
        userId,
        workout.exerciseType,
        rankingDate,
        workout.metricValue,
        DAILY_RANKING_LIMIT,
      ),
    );
  } else {
    statements.push(
      env.DB.prepare(
        "INSERT OR IGNORE INTO workout_sessions (id, user_id, client_session_id, exercise_type, started_at, ended_at, duration_seconds, local_date, timezone_offset_minutes, ranking_date, metric_value, metric_unit, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      ).bind(
        workoutId,
        userId,
        workout.clientSessionId,
        workout.exerciseType,
        workout.startedAt,
        workout.endedAt,
        Math.floor((ended - started) / 1000),
        workout.localDate,
        workout.timezoneOffsetMinutes,
        rankingDate,
        workout.metricValue,
        workout.metricUnit,
        now,
      ),
    );
  }
  if (aggregate) {
    // Aggregate atomically with the insert. The SELECT yields a row only when:
    //   - the just-inserted session exists (dedup / rollback guard),
    //   - the user is CURRENTLY joined with joined_at <= workout.endedAt
    //     (write-time consent recheck, so a leave-then-rejoin that moves
    //     joined_at past the workout's end cannot be scored from a
    //     request-start snapshot),
    //   - adding this session's value would not breach the per-ranking-day cap.
    // Because the whole batch is one D1 transaction, the insert and the quota
    // guard commit or roll back together.
    statements.push(
      env.DB.prepare(
        "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM workout_sessions WHERE id = ?) AND EXISTS (SELECT 1 FROM leaderboard_profiles WHERE user_id = ? AND is_joined = 1 AND joined_at IS NOT NULL AND joined_at <= ?) AND (SELECT COALESCE(MAX(total_value), 0) FROM leaderboard_daily_totals WHERE user_id = ? AND exercise_type = ? AND ranking_date = ?) + ? <= ? ON CONFLICT(user_id, exercise_type, ranking_date) DO UPDATE SET total_value = leaderboard_daily_totals.total_value + excluded.total_value, last_session_at = CASE WHEN excluded.last_session_at > leaderboard_daily_totals.last_session_at THEN excluded.last_session_at ELSE leaderboard_daily_totals.last_session_at END, updated_at = excluded.updated_at",
      ).bind(
        userId,
        workout.exerciseType,
        rankingDate,
        workout.metricValue,
        workout.endedAt,
        now,
        workoutId,
        userId,
        workout.endedAt,
        userId,
        workout.exerciseType,
        rankingDate,
        workout.metricValue,
        DAILY_RANKING_LIMIT,
      ),
    );
  }
  const [written, aggregatedWrite] = await env.DB.batch(statements);
  const inserted = written.meta.changes === 1;
  // The pre-check missed a duplicate that lost a race (or was replayed) and the
  // SQL NOT EXISTS guard caught it: re-check to distinguish duplicate from
  // quota breach, so a replay reports "duplicate" and an over-cap upload
  // reports "daily_limit_exceeded".
  if (!inserted) {
    const raced = await env.DB.prepare(
      "SELECT 1 FROM workout_sessions WHERE user_id = ? AND client_session_id = ?",
    )
      .bind(userId, workout.clientSessionId)
      .first();
    return {
      inserted: false,
      aggregated: false,
      duplicate: raced !== null,
      quotaExceeded: raced === null,
    };
  }
  const aggregated = aggregate && aggregatedWrite.meta.changes === 1;
  return {
    inserted: true,
    aggregated,
    // A successful insert with a failed aggregate (when aggregate was wanted)
    // means the write-time consent window (is_joined/joined_at) excluded this
    // workout — NOT a quota breach. Quota is enforced at the insert boundary
    // above; once the session is persisted, an un-aggregated result is simply
    // "accepted, not ranked". Leave quotaExceeded false here so the caller does
    // not turn a consent-excluded workout into a daily_limit_exceeded reject.
    quotaExceeded: false,
  };
}
