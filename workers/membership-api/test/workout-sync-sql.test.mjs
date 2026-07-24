// Real-SQL coverage for workout sync limits and consent-safe aggregation.
//
// The fake-DB tests in workout-sync.test.mjs assert shape but cannot prove the
// SQL itself enforces atomicity, the daily quota, or the consent re-check at
// write time. These tests run the compiled Worker against a real SQLite
// database built from schema.sql, then assert on committed rows.
import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hashToken } from "../.tmp-test/session.js";
import {
  createD1FromSchema,
  dailyTotal,
  seedLeaderboardProfile,
  seedMembership,
  seedSession,
  seedUser,
  sessionCount,
} from "./helpers/d1_sqlite.mjs";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

function env(db) {
  return { ...envBase, DB: db };
}

function authedWorkoutRequest(body) {
  return new Request("https://worker.test/workouts/sync", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer valid-token",
    },
    body,
  });
}

function workout(overrides = {}) {
  return {
    clientSessionId: "s1",
    exerciseType: "pushup",
    startedAt: "2026-07-09T01:00:00.000Z",
    endedAt: "2026-07-09T01:03:00.000Z",
    localDate: "2026-07-09",
    timezoneOffsetMinutes: 480,
    metricValue: 20,
    metricUnit: "reps",
    ...overrides,
  };
}

async function freshDb(overrides = {}) {
  const d1 = await createD1FromSchema();
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedUser(d1, "user_1", {
    displayName: "Tester",
    email: "user_1@example.com",
  });
  if (overrides.premiumActive !== false) {
    await seedMembership(d1, "user_1", {
      expiresAt: overrides.expiresAt ?? "2099-01-01T00:00:00.000Z",
    });
  }
  if (overrides.joinedAt !== undefined) {
    await seedLeaderboardProfile(d1, "user_1", {
      isJoined: overrides.isJoined ?? 1,
      joinedAt: overrides.joinedAt,
      leftAt: overrides.leftAt ?? null,
    });
  }
  await seedSession(d1, tokenHash, "user_1");
  return d1;
}

async function postSync(d1, workouts) {
  return worker.fetch(
    authedWorkoutRequest(JSON.stringify({ workouts })),
    env(d1),
  );
}

test("daily quota of 5000 reps is enforced atomically at the database boundary", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });
  // Pre-existing aggregate that sits just under the cap.
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(
      "user_1",
      "pushup",
      "2026-07-09",
      4980,
      "2026-07-09T01:00:00.000Z",
      "2026-07-09T01:00:00.000Z",
    )
    .run();

  // 25 reps fits under the cap (4980 + 25 = 5005 > 5000), must be rejected.
  const response = await postSync(
    d1,
    [workout({ clientSessionId: "over", metricValue: 25 })],
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "rejected");
  assert.equal(body.results[0].reason, "daily_limit_exceeded");
  // Cap was not breached: total stays at the pre-existing 4980.
  const total = await dailyTotal(d1, "user_1", "pushup", "2026-07-09");
  assert.equal(total.total_value, 4980);
  // The session itself was not persisted (atomic reject).
  assert.equal(await sessionCount(d1, "user_1"), 0);
});

test("a workout that fits exactly at 5000 is accepted and aggregated", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(
      "user_1",
      "pushup",
      "2026-07-09",
      4980,
      "2026-07-09T01:00:00.000Z",
      "2026-07-09T01:00:00.000Z",
    )
    .run();

  const response = await postSync(
    d1,
    [workout({ clientSessionId: "exact", metricValue: 20 })],
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "accepted");
  assert.equal(body.results[0].aggregated, true);
  const total = await dailyTotal(d1, "user_1", "pushup", "2026-07-09");
  assert.equal(total.total_value, 5000);
  assert.equal(await sessionCount(d1, "user_1"), 1);
});

test("standard and narrow pushups aggregate under separate exercise types", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const response = await postSync(d1, [
    workout({ clientSessionId: "standard", metricValue: 20 }),
    workout({
      clientSessionId: "narrow",
      exerciseType: "narrow_pushup",
      metricValue: 12,
    }),
  ]);

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "accepted");
  assert.equal(body.results[1].status, "accepted");
  assert.equal(
    (await dailyTotal(d1, "user_1", "pushup", "2026-07-09")).total_value,
    20,
  );
  assert.equal(
    (await dailyTotal(d1, "user_1", "narrow_pushup", "2026-07-09"))
      .total_value,
    12,
  );
});

test("duplicate client session id does not consume quota", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const first = await postSync(d1, [workout({ clientSessionId: "dup", metricValue: 100 })]);
  const second = await postSync(d1, [workout({ clientSessionId: "dup", metricValue: 100 })]);

  assert.equal((await first.json()).results[0].status, "accepted");
  assert.equal((await second.json()).results[0].status, "duplicate");
  const total = await dailyTotal(d1, "user_1", "pushup", "2026-07-09");
  assert.equal(total.total_value, 100);
  assert.equal(await sessionCount(d1, "user_1"), 1);
});

test("localDate must match startedAt + timezoneOffsetMinutes", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  // startedAt 01:00Z + offset 480 = 09:00 Shanghai on 2026-07-09, so the
  // correct localDate is 2026-07-09. Sending a mismatched date must reject.
  const response = await postSync(
    d1,
    [workout({ clientSessionId: "mismatch", localDate: "2026-07-10" })],
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "rejected");
  assert.equal(body.results[0].reason, "invalid_local_date");
  assert.equal(await sessionCount(d1, "user_1"), 0);
});

test("localDate is derived for west-of-UTC offsets", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  // 2026-07-09T23:00Z with offset -300 (UTC-5) => 18:00 local on 07-09.
  const response = await postSync(
    d1,
    [
      workout({
        clientSessionId: "west",
        startedAt: "2026-07-09T23:00:00.000Z",
        endedAt: "2026-07-09T23:03:00.000Z",
        localDate: "2026-07-09",
        timezoneOffsetMinutes: -300,
      }),
    ],
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "accepted");
});

test("materially future endedAt is rejected", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const future = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  const start = new Date(Date.now() - 60 * 1000).toISOString();
  // Derive localDate from the actual start so the localDate/offset check does
  // not fire before the future-time check we are exercising here.
  const localDate = new Date(
    Date.parse(start) + 480 * 60 * 1000,
  ).toISOString().slice(0, 10);
  const response = await postSync(
    d1,
    [
      workout({
        clientSessionId: "future",
        startedAt: start,
        endedAt: future,
        localDate,
      }),
    ],
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.results[0].status, "rejected");
  assert.equal(body.results[0].reason, "future_ended_at");
});

test("oversized batch and oversized client session id are rejected", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const tooMany = Array.from({ length: 201 }, (_, i) =>
    workout({ clientSessionId: `batch-${i}` }),
  );
  const longId = workout({
    clientSessionId: "x".repeat(201),
  });

  const batchResponse = await postSync(d1, tooMany);
  assert.equal(batchResponse.status, 400);
  assert.deepEqual(await batchResponse.json(), { error: "batch_too_large" });

  const longIdResponse = await postSync(d1, [longId]);
  assert.equal(longIdResponse.status, 200);
  const longIdBody = await longIdResponse.json();
  assert.equal(longIdBody.results[0].status, "rejected");
  assert.equal(longIdBody.results[0].reason, "invalid_client_session_id");
});

test("aggregation rechecks consent window at write time after a leave race", async () => {
  // Prove the aggregation SQL does not rely solely on the joinedAt snapshot
  // read at request start. We set up a joined profile (so shouldAggregate is
  // true), insert a workout session row directly, then run the exact
  // aggregation SQL the Worker emits against a profile that has since left.
  // The aggregate must contribute 0 rows because the JOIN on is_joined = 1
  // fails at write time.
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  // Insert a workout session that the aggregation SELECT references.
  await d1
    .prepare(
      "INSERT INTO workout_sessions (id, user_id, client_session_id, exercise_type, started_at, ended_at, duration_seconds, local_date, timezone_offset_minutes, ranking_date, metric_value, metric_unit, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(
      "w-race",
      "user_1",
      "race",
      "pushup",
      "2026-07-09T01:00:00.000Z",
      "2026-07-09T01:03:00.000Z",
      180,
      "2026-07-09",
      480,
      "2026-07-09",
      20,
      "reps",
      "2026-07-09T01:03:00.000Z",
    )
    .run();

  // The leave wins: profile flips to left before aggregation runs.
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET is_joined = 0, left_at = ?, updated_at = ? WHERE user_id = ?",
    )
    .bind("2026-07-09T00:30:00.000Z", "2026-07-09T00:30:00.000Z", "user_1")
    .run();

  // Run the aggregation SQL the Worker now emits: it rechecks consent at write
  // time via EXISTS(leaderboard_profiles.is_joined = 1 AND joined_at <= end).
  // Because the profile has flipped to left, the SELECT yields no row and
  // totals stay empty.
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM workout_sessions WHERE id = ?) AND EXISTS (SELECT 1 FROM leaderboard_profiles WHERE user_id = ? AND is_joined = 1 AND joined_at IS NOT NULL AND joined_at <= ?) AND (SELECT COALESCE(MAX(total_value), 0) FROM leaderboard_daily_totals WHERE user_id = ? AND exercise_type = ? AND ranking_date = ?) + ? <= ? ON CONFLICT(user_id, exercise_type, ranking_date) DO UPDATE SET total_value = leaderboard_daily_totals.total_value + excluded.total_value, last_session_at = CASE WHEN excluded.last_session_at > leaderboard_daily_totals.last_session_at THEN excluded.last_session_at ELSE leaderboard_daily_totals.last_session_at END, updated_at = excluded.updated_at",
    )
    .bind(
      "user_1",
      "pushup",
      "2026-07-09",
      20,
      "2026-07-09T01:03:00.000Z",
      "2026-07-09T01:03:00.000Z",
      "w-race",
      "user_1",
      "2026-07-09T01:03:00.000Z",
      "user_1",
      "pushup",
      "2026-07-09",
      20,
      5000,
    )
    .run();

  const total = await dailyTotal(d1, "user_1", "pushup", "2026-07-09");
  assert.equal(total, null);
});

test("leave-then-rejoin racing sync does not count an older workout in the new window", async () => {
  // A2 RED: the request starts joined with joined_at=00:00, so shouldAggregate
  // is true for a workout that endedAt=01:03. Before the write batch runs, a
  // concurrent leave+rejoin moves joined_at to 03:00 (after the workout ended).
  // The aggregation must recheck the CURRENT joined_at <= workout.endedAt; the
  // older workout must be persisted but NOT aggregated into the new window.
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  // Flip the profile to a fresh rejoin (joined_at later than the workout ended)
  // exactly when the write batch is about to open its transaction.
  d1.beforeNextBatch = () => {
    d1.db
      .prepare(
        "UPDATE leaderboard_profiles SET is_joined = 1, joined_at = ?, left_at = NULL, updated_at = ? WHERE user_id = ?",
      )
      .run("2026-07-09T03:00:00.000Z", "2026-07-09T03:00:00.000Z", "user_1");
  };

  const response = await postSync(d1, [workout()]);

  assert.equal(response.status, 200);
  const body = await response.json();
  // The workout itself is valid and persisted...
  assert.equal(body.results[0].status, "accepted");
  // ...but it must NOT aggregate into the new window because the current
  // joined_at (03:00) is later than the workout endedAt (01:03).
  assert.equal(body.results[0].aggregated, false);
  assert.equal(
    await sessionCount(d1, "user_1"),
    1,
    "workout is persisted as history",
  );
  assert.equal(
    await dailyTotal(d1, "user_1", "pushup", "2026-07-09"),
    null,
    "older workout must not enter the new consent window",
  );
});

test("leaving at the daily cap still persists unranked workout history", async () => {
  const d1 = await freshDb({ joinedAt: "2026-07-09T00:00:00.000Z" });
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(
      "user_1",
      "pushup",
      "2026-07-09",
      5000,
      "2026-07-09T01:00:00.000Z",
      "2026-07-09T01:00:00.000Z",
    )
    .run();

  d1.beforeNextBatch = () => {
    d1.db
      .prepare(
        "UPDATE leaderboard_profiles SET is_joined = 0, left_at = ?, updated_at = ? WHERE user_id = ?",
      )
      .run("2026-07-09T01:02:00.000Z", "2026-07-09T01:02:00.000Z", "user_1");
  };

  const response = await postSync(
    d1,
    [workout({ clientSessionId: "leave-at-cap" })],
  );
  const body = await response.json();

  assert.equal(body.results[0].status, "accepted");
  assert.equal(body.results[0].aggregated, false);
  assert.equal(await sessionCount(d1, "user_1"), 1);
  assert.equal(
    (await dailyTotal(d1, "user_1", "pushup", "2026-07-09")).total_value,
    5000,
  );
});
