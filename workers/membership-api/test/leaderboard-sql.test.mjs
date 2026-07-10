// Real-SQL coverage for leaderboard membership validity and rejoin semantics.
//
// The fake-DB tests assert SQL shape but cannot prove that membership snapshots
// are filtered at query time, or that a rejoin after leave clears the current
// Shanghai-week aggregates atomically. These tests run the compiled Worker
// against a real SQLite database built from schema.sql.
import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { weekRangeForShanghai } from "../.tmp-test/leaderboard.js";
import { hashToken } from "../.tmp-test/session.js";
import { rankingDateForShanghai } from "../.tmp-test/workouts.js";
import {
  createD1FromSchema,
  dailyTotal,
  seedLeaderboardProfile,
  seedMembership,
  seedSession,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

function env(db) {
  return { ...envBase, DB: db };
}

function authedRequest(path, method = "GET") {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: { authorization: "Bearer valid-token" },
  });
}

async function seedRankedUser(d1, userId, options = {}) {
  await seedUser(d1, userId, {
    displayName: options.displayName ?? userId,
    nickname: options.displayName ?? userId,
  });
  if (options.premiumActive !== false) {
    await seedMembership(d1, userId, {
      isActive: options.isActive ?? 1,
      expiresAt: options.expiresAt ?? "2099-01-01T00:00:00.000Z",
    });
  }
  if (options.joined !== false) {
    await seedLeaderboardProfile(d1, userId, {
      isJoined: options.isJoined ?? 1,
      joinedAt: options.joinedAt ?? "2026-07-01T00:00:00.000Z",
    });
  }
  if (options.total !== undefined) {
    await d1
      .prepare(
        "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
      )
      .bind(
        userId,
        "pushup",
        options.rankingDate ?? "2026-07-09",
        options.total,
        options.lastSessionAt ?? "2026-07-09T01:00:00.000Z",
        options.updatedAt ?? "2026-07-09T01:00:00.000Z",
      )
      .run();
  }
}

async function freshDbForMe(options = {}) {
  const d1 = await createD1FromSchema();
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedUser(d1, "me", { displayName: "Me", nickname: "Me" });
  await seedMembership(d1, "me", {
    isActive: options.meIsActive ?? 1,
    expiresAt: options.meExpiresAt ?? "2099-01-01T00:00:00.000Z",
  });
  await seedLeaderboardProfile(d1, "me", {
    isJoined: options.meJoined === false ? 0 : 1,
    joinedAt: "2026-07-01T00:00:00.000Z",
  });
  await seedSession(d1, tokenHash, "me");
  return d1;
}

test("day leaderboard excludes a joined user whose membership has expired", async () => {
  const d1 = await freshDbForMe();
  const today = rankingDateForShanghai(new Date().toISOString());
  // u1 is joined and has totals but membership is expired.
  await seedRankedUser(d1, "u1", {
    displayName: "Expired",
    isActive: 1,
    expiresAt: "2020-01-01T00:00:00.000Z", // expired
    total: 100,
    rankingDate: today,
  });
  // u2 is joined, active, with totals.
  await seedRankedUser(d1, "u2", {
    displayName: "Active",
    total: 90,
    rankingDate: today,
  });
  // me is joined, active, with totals.
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind("me", "pushup", today, 10, "2026-07-09T01:00:00.000Z", "2026-07-09T01:00:00.000Z")
    .run();

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  // Expired member u1 must NOT appear even though joined with totals.
  const ids = body.top.map((row) => row.userId);
  assert.ok(!ids.includes("u1"), "expired member must not rank");
  assert.deepEqual(ids, ["u2", "me"]);
});

test("week leaderboard excludes expired members the same as day", async () => {
  const d1 = await freshDbForMe();
  const today = rankingDateForShanghai(new Date().toISOString());
  await seedRankedUser(d1, "u1", {
    displayName: "Expired",
    expiresAt: "2020-01-01T00:00:00.000Z",
    total: 100,
    rankingDate: today,
  });
  await seedRankedUser(d1, "u2", {
    displayName: "Active",
    total: 90,
    rankingDate: today,
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=week&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  const ids = body.top.map((row) => row.userId);
  assert.ok(!ids.includes("u1"));
});

test("rejoin after leave clears the user's current Shanghai-week aggregates", async () => {
  // freshDbForMe seeds "me" as joined + active by default.
  const d1 = await freshDbForMe();
  // A ranking date inside the current Shanghai week so the rejoin clear hits it.
  const weekDate = weekRangeForShanghai(new Date().toISOString()).start;
  // A total in the current week.
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind("me", "pushup", weekDate, 50, "2026-07-09T01:00:00.000Z", "2026-07-09T01:00:00.000Z")
    .run();

  // Leave.
  await worker.fetch(authedRequest("/leaderboard/leave", "POST"), env(d1));
  assert.equal((await dailyTotal(d1, "me", "pushup", weekDate)).total_value, 50);

  // Rejoin: must clear the current Shanghai-week aggregate for this user.
  const response = await worker.fetch(authedRequest("/leaderboard/join", "POST"), env(d1));
  assert.equal(response.status, 200);

  const total = await dailyTotal(d1, "me", "pushup", weekDate);
  assert.equal(total, null, "current-week aggregate must be cleared on rejoin");
});

test("post-rejoin workouts aggregate, and pre-rejoin uploads do not revive", async () => {
  // freshDbForMe seeds "me" as joined + active by default.
  const d1 = await freshDbForMe();
  const weekDate = weekRangeForShanghai(new Date().toISOString()).start;
  // An aggregate from the current Shanghai week (pre-rejoin legacy score).
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind("me", "pushup", weekDate, 40, "2026-07-09T00:30:00.000Z", "2026-07-09T00:30:00.000Z")
    .run();

  // Leave then rejoin -> clears the 40.
  await worker.fetch(authedRequest("/leaderboard/leave", "POST"), env(d1));
  await worker.fetch(authedRequest("/leaderboard/join", "POST"), env(d1));
  const joinBody = await (await worker.fetch(authedRequest("/leaderboard/join", "POST"), env(d1))).json();
  const newJoinedAt = joinBody.joinedAt;

  // A NEW workout after rejoin aggregates normally. endedAt is at or just after
  // joinedAt (>= for shouldAggregate) but within the future-tolerance window.
  const startedAtMs = Date.parse(newJoinedAt) - 30 * 1000;
  const endedAtMs = Date.parse(newJoinedAt) + 5 * 1000;
  const workoutRankingDate = rankingDateForShanghai(new Date(endedAtMs).toISOString());
  const localDate = new Date(startedAtMs + 480 * 60 * 1000).toISOString().slice(0, 10);
  const workout = {
    clientSessionId: "post-rejoin",
    exerciseType: "pushup",
    startedAt: new Date(startedAtMs).toISOString(),
    endedAt: new Date(endedAtMs).toISOString(),
    localDate,
    timezoneOffsetMinutes: 480,
    metricValue: 15,
    metricUnit: "reps",
  };
  const syncRes = await worker.fetch(
    new Request("https://worker.test/workouts/sync", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: "Bearer valid-token",
      },
      body: JSON.stringify({ workouts: [workout] }),
    }),
    env(d1),
  );
  const syncBody = await syncRes.json();
  assert.equal(syncBody.results[0].status, "accepted");
  assert.equal(syncBody.results[0].aggregated, true);

  // The post-rejoin workout landed on its own ranking day; the cleared legacy
  // score on weekDate did not revive.
  assert.equal(
    (await dailyTotal(d1, "me", "pushup", weekDate)),
    null,
    "cleared legacy score stays cleared",
  );
  const postTotal = await dailyTotal(d1, "me", "pushup", workoutRankingDate);
  assert.equal(postTotal.total_value, 15, "only the post-rejoin workout counts");
});
