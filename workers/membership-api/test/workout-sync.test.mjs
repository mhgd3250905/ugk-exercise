import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hashToken } from "../.tmp-test/session.js";
import { syncWorkoutsForTest } from "../.tmp-test/workouts.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

class WorkoutDb {
  constructor(tokenHash, options = {}) {
    this.sessions = new Map([
      [
        tokenHash,
        {
          user_id: "user_1",
          app_user_id: "user_1",
          expires_at: "2099-01-01T00:00:00.000Z",
        },
      ],
    ]);
    this.membershipSnapshots = new Map(
      options.premiumActive === false
        ? []
        : [
            [
              "user_1",
              {
                is_active: 1,
                expires_at: "2099-01-01T00:00:00.000Z",
              },
            ],
          ],
    );
    this.leaderboardProfiles = new Map(
      options.joinedAt === undefined
        ? []
        : [
            [
              "user_1",
              {
                is_joined: 1,
                joined_at: options.joinedAt,
              },
            ],
          ],
    );
    this.workoutSessions = new Map();
    this.cloudWorkoutRows = options.cloudWorkoutRows ?? [];
    this.dailyTotals = new Map();
    this.failDailyUpsert = options.failDailyUpsert ?? false;
    this.batchCalls = 0;
  }

  prepare(sql) {
    return new WorkoutStatement(this, sql);
  }

  async batch(statements) {
    this.batchCalls += 1;
    const workoutSessions = new Map(this.workoutSessions);
    const dailyTotals = new Map(this.dailyTotals);
    try {
      const results = [];
      for (const statement of statements) {
        results.push(await statement.run());
      }
      return results;
    } catch (error) {
      this.workoutSessions = workoutSessions;
      this.dailyTotals = dailyTotals;
      throw error;
    }
  }
}

class WorkoutStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql;
    this.args = [];
  }

  bind(...args) {
    this.args = args;
    return this;
  }

  async first() {
    if (this.sql.includes("FROM sessions WHERE token_hash = ?")) {
      return this.db.sessions.get(this.args[0]) ?? null;
    }
    if (this.sql.includes("FROM membership_snapshots WHERE user_id = ?")) {
      const snapshot = this.db.membershipSnapshots.get(this.args[0]) ?? null;
      return snapshot === null
        ? null
        : {
            entitlement: "premium",
            source: "revenuecat_verified",
            verified_at: new Date().toISOString(),
            ...snapshot,
          };
    }
    if (this.sql.includes("FROM leaderboard_profiles WHERE user_id = ?")) {
      return this.db.leaderboardProfiles.get(this.args[0]) ?? null;
    }
    // Dedup probe used by writeWorkout: "SELECT 1 FROM workout_sessions WHERE
    // user_id = ? AND client_session_id = ?".
    if (
      this.sql.includes("FROM workout_sessions") &&
      this.sql.includes("client_session_id = ?")
    ) {
      const key = `${this.args[0]}:${this.args[1]}`;
      return this.db.workoutSessions.has(key) ? { "1": 1 } : null;
    }
    return null;
  }

  async all() {
    if (
      this.sql.includes("FROM workout_sessions") &&
      this.sql.includes("local_date >= ?") &&
      this.sql.includes("local_date < ?")
    ) {
      const [userId, startMonth, nextMonth] = this.args;
      return {
        results: this.db.cloudWorkoutRows.filter(
          (row) =>
            row.user_id === userId &&
            row.local_date >= startMonth &&
            row.local_date < nextMonth,
        ),
      };
    }
    return { results: [] };
  }

  async run() {
    if (this.sql.includes("INSERT OR IGNORE INTO workout_sessions")) {
      const userId = this.args[1];
      const clientSessionId = this.args[2];
      const key = `${userId}:${clientSessionId}`;
      if (this.db.workoutSessions.has(key)) {
        return { meta: { changes: 0 } };
      }
      this.db.workoutSessions.set(key, {
        id: this.args[0],
        user_id: userId,
        client_session_id: clientSessionId,
      });
      return { meta: { changes: 1 } };
    }
    // Quota-gated insert path (aggregate=true). Same positional shape, but the
    // real SQL also guards on the daily cap; that guard is covered by the
    // real-D1 tests, so here we only model dedup.
    if (
      this.sql.startsWith("INSERT INTO workout_sessions") &&
      this.sql.includes("NOT EXISTS")
    ) {
      const userId = this.args[1];
      const clientSessionId = this.args[2];
      const key = `${userId}:${clientSessionId}`;
      if (this.db.workoutSessions.has(key)) {
        return { meta: { changes: 0 } };
      }
      this.db.workoutSessions.set(key, {
        id: this.args[0],
        user_id: userId,
        client_session_id: clientSessionId,
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.includes("INSERT INTO leaderboard_daily_totals")) {
      if (this.db.failDailyUpsert) {
        throw new Error("daily upsert failed");
      }
      // New aggregation SQL binds:
      // [0]=userId [1]=exerciseType [2]=rankingDate [3]=metricValue
      // [4]=endedAt [5]=now [6]=workoutId [7]=userId [8]=endedAt(joined_at<=?)
      // [9]=userId [10]=exerciseType [11]=rankingDate [12]=metricValue [13]=limit
      const userId = this.args[0];
      const exerciseType = this.args[1];
      const rankingDate = this.args[2];
      const metricValue = this.args[3];
      const endedAt = this.args[4];
      const workoutId = this.args[6];
      // The real SQL rechecks consent and quota via WHERE/EXISTS; this fake
      // models the workout-existence guard and leaves consent/quota coverage
      // to the real-D1 tests in workout-sync-sql.test.mjs.
      const dependsOnInsertedWorkout =
        this.sql.includes("FROM workout_sessions");
      const insertedWorkoutExists = Array.from(
        this.db.workoutSessions.values(),
      ).some((session) => session.id === workoutId);
      if (dependsOnInsertedWorkout && !insertedWorkoutExists) {
        return { meta: { changes: 0 } };
      }
      const key = `${userId}:${exerciseType}:${rankingDate}`;
      const current = this.db.dailyTotals.get(key);
      this.db.dailyTotals.set(key, {
        total_value: (current?.total_value ?? 0) + metricValue,
        last_session_at:
          current && current.last_session_at > endedAt
            ? current.last_session_at
            : endedAt,
      });
      return { meta: { changes: 1 } };
    }
    return { meta: { changes: 1 } };
  }
}

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

function authedCloudWorkoutsRequest(month) {
  return new Request(`https://worker.test/workouts?month=${month}`, {
    method: "GET",
    headers: {
      authorization: "Bearer valid-token",
    },
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

async function routeDb(options = {}) {
  return new WorkoutDb(await hashToken(envBase, "valid-token"), options);
}

async function postSync(db, workouts) {
  return worker.fetch(
    authedWorkoutRequest(JSON.stringify({ workouts })),
    env(db),
  );
}

async function getWorkouts(db, month) {
  return worker.fetch(authedCloudWorkoutsRequest(month), env(db));
}

test("sync rejects non-premium accounts", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: false,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [
      {
        clientSessionId: "s1",
        exerciseType: "pushup",
        startedAt: "2026-07-09T01:00:00.000Z",
        endedAt: "2026-07-09T01:03:00.000Z",
        localDate: "2026-07-09",
        timezoneOffsetMinutes: 480,
        metricValue: 20,
        metricUnit: "reps",
      },
    ],
  });

  assert.deepEqual(result, [
    {
      clientSessionId: "s1",
      status: "rejected",
      reason: "premium_required",
    },
  ]);
});

test("POST /workouts/sync accepts premium workouts and aggregates joined users", async () => {
  const db = await routeDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const response = await postSync(db, [workout()]);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    results: [{ clientSessionId: "s1", status: "accepted", aggregated: true }],
  });
  assert.equal(db.workoutSessions.size, 1);
  assert.equal(db.dailyTotals.get("user_1:pushup:2026-07-09").total_value, 20);
  assert.equal(db.batchCalls, 1);
});

test("GET /workouts returns current user's sessions for month without premium", async () => {
  const db = await routeDb({
    premiumActive: false,
    cloudWorkoutRows: [
      {
        user_id: "user_1",
        client_session_id: "s1",
        exercise_type: "pushup",
        started_at: "2026-07-09T01:00:00.000Z",
        ended_at: "2026-07-09T01:03:00.000Z",
        metric_value: 20,
        metric_unit: "reps",
        local_date: "2026-07-09",
      },
      {
        user_id: "user_1",
        client_session_id: "other-month",
        exercise_type: "pushup",
        started_at: "2026-08-09T01:00:00.000Z",
        ended_at: "2026-08-09T01:03:00.000Z",
        metric_value: 30,
        metric_unit: "reps",
        local_date: "2026-08-09",
      },
      {
        user_id: "user_2",
        client_session_id: "other-user",
        exercise_type: "pushup",
        started_at: "2026-07-09T01:00:00.000Z",
        ended_at: "2026-07-09T01:03:00.000Z",
        metric_value: 40,
        metric_unit: "reps",
        local_date: "2026-07-09",
      },
    ],
  });

  const response = await getWorkouts(db, "2026-07");

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    workouts: [
      {
        clientSessionId: "s1",
        exerciseType: "pushup",
        startedAt: "2026-07-09T01:00:00.000Z",
        endedAt: "2026-07-09T01:03:00.000Z",
        localDate: "2026-07-09",
        metricValue: 20,
        metricUnit: "reps",
      },
    ],
  });
});

test("GET /workouts handles December month range", async () => {
  const db = await routeDb({
    cloudWorkoutRows: [
      {
        user_id: "user_1",
        client_session_id: "dec",
        exercise_type: "pushup",
        started_at: "2026-12-31T01:00:00.000Z",
        ended_at: "2026-12-31T01:03:00.000Z",
        metric_value: 20,
        metric_unit: "reps",
        local_date: "2026-12-31",
      },
      {
        user_id: "user_1",
        client_session_id: "jan",
        exercise_type: "pushup",
        started_at: "2027-01-01T01:00:00.000Z",
        ended_at: "2027-01-01T01:03:00.000Z",
        metric_value: 30,
        metric_unit: "reps",
        local_date: "2027-01-01",
      },
    ],
  });

  const response = await getWorkouts(db, "2026-12");

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    workouts: [
      {
        clientSessionId: "dec",
        exerciseType: "pushup",
        startedAt: "2026-12-31T01:00:00.000Z",
        endedAt: "2026-12-31T01:03:00.000Z",
        localDate: "2026-12-31",
        metricValue: 20,
        metricUnit: "reps",
      },
    ],
  });
});

test("GET /workouts rejects invalid month", async () => {
  const db = await routeDb();

  const response = await getWorkouts(db, "2026-13");

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_month" });
});

test("POST /workouts/sync does not aggregate duplicate workouts", async () => {
  const db = await routeDb({ joinedAt: "2026-07-09T00:00:00.000Z" });
  await postSync(db, [workout()]);

  const response = await postSync(db, [workout()]);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    results: [{ clientSessionId: "s1", status: "duplicate" }],
  });
  assert.equal(db.workoutSessions.size, 1);
  assert.equal(db.dailyTotals.get("user_1:pushup:2026-07-09").total_value, 20);
});

test("POST /workouts/sync does not aggregate workouts before leaderboard join", async () => {
  const db = await routeDb({ joinedAt: "2026-07-09T02:00:00.000Z" });

  const response = await postSync(db, [workout()]);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    results: [{ clientSessionId: "s1", status: "accepted", aggregated: false }],
  });
  assert.equal(db.workoutSessions.size, 1);
  assert.equal(db.dailyTotals.size, 0);
});

test("POST /workouts/sync rejects invalid body", async () => {
  const db = await routeDb();

  const missing = await worker.fetch(
    authedWorkoutRequest(JSON.stringify({})),
    env(db),
  );
  const nonArray = await worker.fetch(
    authedWorkoutRequest(JSON.stringify({ workouts: "nope" })),
    env(db),
  );

  assert.equal(missing.status, 400);
  assert.deepEqual(await missing.json(), { error: "invalid_body" });
  assert.equal(nonArray.status, 400);
  assert.deepEqual(await nonArray.json(), { error: "invalid_body" });
});

test("POST /workouts/sync rejects invalid local date and timezone per item", async () => {
  const db = await routeDb({ joinedAt: "2026-07-09T00:00:00.000Z" });

  const response = await postSync(db, [
    workout({ clientSessionId: "bad-date", localDate: "2026-02-30" }),
    workout({ clientSessionId: "bad-zone", timezoneOffsetMinutes: 841 }),
  ]);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    results: [
      {
        clientSessionId: "bad-date",
        status: "rejected",
        reason: "invalid_local_date",
      },
      {
        clientSessionId: "bad-zone",
        status: "rejected",
        reason: "invalid_timezone",
      },
    ],
  });
  assert.equal(db.workoutSessions.size, 0);
  assert.equal(db.dailyTotals.size, 0);
});

test("POST /workouts/sync rolls back workout insert when aggregation fails", async () => {
  const db = await routeDb({
    joinedAt: "2026-07-09T00:00:00.000Z",
    failDailyUpsert: true,
  });

  await assert.rejects(() => postSync(db, [workout()]), /daily upsert failed/);

  assert.equal(db.workoutSessions.size, 0);
  assert.equal(db.dailyTotals.size, 0);
});

test("sync accepts first upload and ignores duplicate for aggregation", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: "2026-07-09T00:00:00.000Z",
    existingSessionIds: new Set(["s1"]),
    workouts: [
      {
        clientSessionId: "s1",
        exerciseType: "pushup",
        startedAt: "2026-07-09T01:00:00.000Z",
        endedAt: "2026-07-09T01:03:00.000Z",
        localDate: "2026-07-09",
        timezoneOffsetMinutes: 480,
        metricValue: 20,
        metricUnit: "reps",
      },
    ],
  });

  assert.deepEqual(result, [{ clientSessionId: "s1", status: "duplicate" }]);
});

test("sync accepts narrow pushups and still rejects unknown exercise types", async () => {
  const results = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [
      workout({ clientSessionId: "narrow", exerciseType: "narrow_pushup" }),
      workout({ clientSessionId: "unknown", exerciseType: "squat" }),
    ],
  });

  assert.deepEqual(results, [
    { clientSessionId: "narrow", status: "accepted", aggregated: false },
    {
      clientSessionId: "unknown",
      status: "rejected",
      reason: "invalid_exercise_type",
    },
  ]);
});

test("sync marks duplicate client session ids within the same batch", async () => {
  const workout = {
    clientSessionId: "s1",
    exerciseType: "pushup",
    startedAt: "2026-07-09T01:00:00.000Z",
    endedAt: "2026-07-09T01:03:00.000Z",
    localDate: "2026-07-09",
    timezoneOffsetMinutes: 480,
    metricValue: 20,
    metricUnit: "reps",
  };

  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: "2026-07-09T00:00:00.000Z",
    existingSessionIds: new Set(),
    workouts: [workout, workout],
  });

  assert.deepEqual(result, [
    { clientSessionId: "s1", status: "accepted", aggregated: true },
    { clientSessionId: "s1", status: "duplicate" },
  ]);
});

test("sync does not aggregate workouts before leaderboard join", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: "2026-07-09T02:00:00.000Z",
    existingSessionIds: new Set(),
    workouts: [
      {
        clientSessionId: "s1",
        exerciseType: "pushup",
        startedAt: "2026-07-09T01:00:00.000Z",
        endedAt: "2026-07-09T01:03:00.000Z",
        localDate: "2026-07-09",
        timezoneOffsetMinutes: 480,
        metricValue: 20,
        metricUnit: "reps",
      },
    ],
  });

  assert.equal(result[0].status, "accepted");
  assert.equal(result[0].aggregated, false);
});

test("sync rejects malformed workout entries without crashing", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [null],
  });

  assert.deepEqual(result, [
    { clientSessionId: "", status: "rejected", reason: "invalid_workout" },
  ]);
});

test("sync rejects oversized workout sessions", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [workout({ metricValue: 1001 })],
  });

  assert.deepEqual(result, [
    {
      clientSessionId: "s1",
      status: "rejected",
      reason: "session_limit_exceeded",
    },
  ]);
});

test("POST /workouts/sync rejects invalid JSON", async () => {
  const tokenHash = await hashToken(envBase, "valid-token");

  const response = await worker.fetch(
    authedWorkoutRequest("{"),
    env(new WorkoutDb(tokenHash)),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_json" });
});

test("sync rejects localDate that does not match startedAt plus offset", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [
      workout({
        clientSessionId: "bad-local",
        // startedAt 01:00Z + 480 = 2026-07-09 Shanghai, not 07-10
        localDate: "2026-07-10",
      }),
    ],
  });

  assert.deepEqual(result, [
    {
      clientSessionId: "bad-local",
      status: "rejected",
      reason: "invalid_local_date",
    },
  ]);
});

test("sync rejects a client session id that is too long", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [workout({ clientSessionId: "x".repeat(201) })],
  });

  assert.deepEqual(result, [
    {
      clientSessionId: "x".repeat(201),
      status: "rejected",
      reason: "invalid_client_session_id",
    },
  ]);
});
