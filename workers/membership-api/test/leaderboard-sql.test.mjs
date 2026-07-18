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

function authedRequest(path, method = "GET", body) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer valid-token",
      ...(body === undefined ? {} : { "content-type": "application/json" }),
    },
    ...(body === undefined
      ? {}
      : { body: typeof body === "string" ? body : JSON.stringify(body) }),
  });
}

async function leaderboardIdentity(d1) {
  return d1
    .prepare(
      "SELECT identity_mode, leaderboard_nickname, leaderboard_nickname_key, leaderboard_avatar_key, anonymous_avatar_key FROM leaderboard_profiles WHERE user_id = ?",
    )
    .bind("me")
    .first();
}

async function seedRankedUser(d1, userId, options = {}) {
  await seedUser(d1, userId, {
    displayName: options.displayName ?? userId,
    nickname:
      options.nickname === undefined
        ? options.displayName ?? userId
        : options.nickname,
    avatarUrl: options.avatarUrl ?? null,
    avatarKey: options.avatarKey ?? null,
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
      identityMode: options.identityMode ?? "anonymous",
      leaderboardNickname: options.leaderboardNickname ?? null,
      leaderboardNicknameKey: options.leaderboardNicknameKey ?? null,
      leaderboardAvatarKey: options.leaderboardAvatarKey ?? null,
      anonymousAvatarKey: options.anonymousAvatarKey ?? "ring-green",
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
  await seedUser(d1, "me", {
    displayName: options.meDisplayName ?? "Me",
    nickname: options.meNickname === undefined ? "Me" : options.meNickname,
    avatarUrl: options.meAvatarUrl ?? null,
    avatarKey: options.meAvatarKey ?? null,
  });
  await seedMembership(d1, "me", {
    isActive: options.meIsActive ?? 1,
    expiresAt: options.meExpiresAt ?? "2099-01-01T00:00:00.000Z",
  });
  await seedLeaderboardProfile(d1, "me", {
    isJoined: options.meJoined === false ? 0 : 1,
    joinedAt: "2026-07-01T00:00:00.000Z",
    identityMode: options.meIdentityMode ?? "anonymous",
    leaderboardNickname: options.meLeaderboardNickname ?? null,
    leaderboardNicknameKey: options.meLeaderboardNicknameKey ?? null,
    leaderboardAvatarKey: options.meLeaderboardAvatarKey ?? null,
    anonymousAvatarKey: options.meAnonymousAvatarKey ?? "ring-green",
  });
  await seedSession(d1, tokenHash, "me");
  return d1;
}

test("old join without a body saves anonymous identity", async () => {
  const d1 = await freshDbForMe();
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET identity_mode = 'custom', leaderboard_nickname = '旧昵称', leaderboard_nickname_key = '旧昵称', leaderboard_avatar_key = 'ring-lime', anonymous_avatar_key = 'ring-yellow' WHERE user_id = 'me'",
    )
    .run();

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(d1),
  );

  assert.equal(response.status, 200);
  assert.deepEqual({ ...(await leaderboardIdentity(d1)) }, {
    identity_mode: "anonymous",
    leaderboard_nickname: "旧昵称",
    leaderboard_nickname_key: "旧昵称",
    leaderboard_avatar_key: "ring-lime",
    anonymous_avatar_key: "ring-yellow",
  });
});

test("new anonymous join persists a stable avatar derived from the user id", async () => {
  const d1 = await createD1FromSchema();
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedUser(d1, "member-42");
  await seedMembership(d1, "member-42");
  await seedSession(d1, tokenHash, "member-42");

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(d1),
  );
  assert.equal(response.status, 200);

  const identity = await d1
    .prepare(
      "SELECT identity_mode, anonymous_avatar_key FROM leaderboard_profiles WHERE user_id = ?",
    )
    .bind("member-42")
    .first();
  assert.deepEqual({ ...identity }, {
    identity_mode: "anonymous",
    anonymous_avatar_key: "ring-coral",
  });
});

test("profile join stores only the unified profile identity", async () => {
  const d1 = await freshDbForMe();
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET identity_mode = 'custom', leaderboard_nickname = '旧昵称', leaderboard_nickname_key = '旧昵称', leaderboard_avatar_key = 'ring-lime' WHERE user_id = 'me'",
    )
    .run();

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST", { mode: "profile" }),
    env(d1),
  );

  assert.equal(response.status, 200);
  const identity = await leaderboardIdentity(d1);
  assert.equal(identity.identity_mode, "profile");
});

test("anonymous identity update keeps its stable avatar", async () => {
  const d1 = await freshDbForMe();
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET identity_mode = 'custom', leaderboard_nickname = '旧昵称', leaderboard_nickname_key = '旧昵称', leaderboard_avatar_key = 'ring-lime', anonymous_avatar_key = 'ring-coral' WHERE user_id = 'me'",
    )
    .run();

  const response = await worker.fetch(
    authedRequest("/leaderboard/identity", "PATCH", { mode: "anonymous" }),
    env(d1),
  );

  assert.equal(response.status, 200);
  assert.deepEqual({ ...(await leaderboardIdentity(d1)) }, {
    identity_mode: "anonymous",
    leaderboard_nickname: "旧昵称",
    leaderboard_nickname_key: "旧昵称",
    leaderboard_avatar_key: "ring-lime",
    anonymous_avatar_key: "ring-coral",
  });
});

test("identity update rejects an empty body without changing identity", async () => {
  const d1 = await freshDbForMe();
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET identity_mode = 'custom', leaderboard_nickname = '保留昵称', leaderboard_nickname_key = '保留昵称', leaderboard_avatar_key = 'ring-sky' WHERE user_id = 'me'",
    )
    .run();

  const response = await worker.fetch(
    authedRequest("/leaderboard/identity", "PATCH"),
    env(d1),
  );

  assert.deepEqual(
    {
      status: response.status,
      body: await response.json(),
      identity: { ...(await leaderboardIdentity(d1)) },
    },
    {
      status: 400,
      body: { error: "invalid_json" },
      identity: {
        identity_mode: "custom",
        leaderboard_nickname: "保留昵称",
        leaderboard_nickname_key: "保留昵称",
        leaderboard_avatar_key: "ring-sky",
        anonymous_avatar_key: "ring-green",
      },
    },
  );
});

test("identity update requires an active premium membership", async () => {
  const d1 = await freshDbForMe({ meIsActive: 0 });

  const response = await worker.fetch(
    authedRequest("/leaderboard/identity", "PATCH", { mode: "profile" }),
    env(d1),
  );

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: "premium_required" });
});

test("identity update requires a currently joined profile", async () => {
  const d1 = await freshDbForMe({ meJoined: false });

  const response = await worker.fetch(
    authedRequest("/leaderboard/identity", "PATCH", { mode: "profile" }),
    env(d1),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "leaderboard_not_joined" });
});

test("leaderboard identity rejects invalid JSON and retired modes", async () => {
  const cases = [
    ["{", 400, "invalid_json"],
    ["[]", 400, "invalid_json"],
    [{ mode: "public" }, 400, "invalid_identity_mode"],
    [
      { mode: "custom", nickname: "旧榜单名", avatarKey: "ring-green" },
      400,
      "invalid_identity_mode",
    ],
  ];

  for (const [body, status, error] of cases) {
    const response = await worker.fetch(
      authedRequest("/leaderboard/identity", "PATCH", body),
      env(await freshDbForMe()),
    );
    assert.equal(response.status, status, JSON.stringify(body));
    assert.deepEqual(await response.json(), { error }, JSON.stringify(body));
  }
});

test("day and week public identity resolves profile and anonymous privacy", async () => {
  const today = rankingDateForShanghai(new Date().toISOString());
  const d1 = await freshDbForMe({
    meDisplayName: "Private Google Me",
    meNickname: "Private App Me",
    meAvatarUrl: "https://private.test/me-google.png",
    meAvatarKey: "ring-yellow",
    meIdentityMode: "profile",
    meLeaderboardNickname: "Public Me",
    meLeaderboardNicknameKey: "publicme",
    meLeaderboardAvatarKey: "ring-sky",
    meAnonymousAvatarKey: "ring-coral",
  });
  await seedRankedUser(d1, "profile-app", {
    displayName: "Google Alpha",
    nickname: "App Alpha",
    avatarUrl: "https://private.test/alpha-google.png",
    avatarKey: "ring-lime",
    identityMode: "profile",
    total: 60,
    rankingDate: today,
  });
  await seedRankedUser(d1, "profile-google", {
    displayName: "Google Beta",
    nickname: "   ",
    avatarUrl: "https://public.test/beta-google.png",
    avatarKey: "   ",
    identityMode: "profile",
    total: 50,
    rankingDate: today,
  });
  await seedRankedUser(d1, "anonymous", {
    displayName: "Private Google Anonymous",
    nickname: "Private App Anonymous",
    avatarUrl: "https://private.test/anonymous-google.png",
    avatarKey: "ring-lime",
    identityMode: "anonymous",
    anonymousAvatarKey: "ring-yellow",
    total: 30,
    rankingDate: today,
  });
  await seedRankedUser(d1, "legacy", {
    displayName: "Private Legacy",
    anonymousAvatarKey: "ring-lime",
  });
  await seedRankedUser(d1, "unknown", {
    displayName: "Private Unknown",
    nickname: "Private App Unknown",
    avatarUrl: "https://private.test/unknown-google.png",
    avatarKey: "ring-sky",
    anonymousAvatarKey: "ring-coral",
  });
  await d1
    .prepare(
      "UPDATE leaderboard_profiles SET identity_mode = 'future-mode' WHERE user_id = 'unknown'",
    )
    .run();

  for (const period of ["day", "week"]) {
    const response = await worker.fetch(
      authedRequest(`/leaderboard?period=${period}&exerciseType=pushup`),
      env(d1),
    );
    assert.equal(response.status, 200, period);
    const body = await response.json();
    const rows = new Map(body.top.map((row) => [row.userId, row]));

    assert.deepEqual(body.identity, { mode: "profile" });
    assert.equal(body.anonymousAvatarKey, "ring-coral");
    assert.deepEqual(rows.get("profile-app"), {
      rank: 1,
      userId: "profile-app",
      totalValue: 60,
      nickname: "App Alpha",
      avatarKey: "ring-lime",
      avatarUrl: null,
    });
    assert.deepEqual(rows.get("profile-google"), {
      rank: 2,
      userId: "profile-google",
      totalValue: 50,
      nickname: "Google Beta",
      avatarKey: null,
      avatarUrl: "https://public.test/beta-google.png",
    });
    assert.deepEqual(rows.get("anonymous"), {
      rank: 3,
      userId: "anonymous",
      totalValue: 30,
      nickname: null,
      avatarKey: "ring-yellow",
      avatarUrl: null,
    });
    assert.deepEqual(rows.get("legacy"), {
      rank: 4,
      userId: "legacy",
      totalValue: 0,
      nickname: null,
      avatarKey: "ring-lime",
      avatarUrl: null,
    });
    assert.deepEqual(rows.get("unknown"), {
      rank: 6,
      userId: "unknown",
      totalValue: 0,
      nickname: null,
      avatarKey: "ring-coral",
      avatarUrl: null,
    });
    assert.deepEqual(rows.get("me"), {
      rank: 5,
      userId: "me",
      totalValue: 0,
      nickname: "Private App Me",
      avatarKey: "ring-yellow",
      avatarUrl: null,
    });
  }
});

test("leaderboard returns a deterministic private anonymous avatar without a profile", async () => {
  const d1 = await createD1FromSchema();
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedUser(d1, "user-without-profile");
  await seedMembership(d1, "user-without-profile", {
    isActive: 1,
    expiresAt: "2099-01-01T00:00:00.000Z",
  });
  await seedSession(d1, tokenHash, "user-without-profile");

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.identity, null);
  assert.equal(body.anonymousAvatarKey, "ring-sky");
  assert.equal(body.top.length, 0);
});

test("profile public identity normalizes blank App and Google fields to null", async () => {
  const d1 = await freshDbForMe({
    meDisplayName: "   ",
    meNickname: "   ",
    meAvatarUrl: "   ",
    meAvatarKey: "   ",
    meIdentityMode: "profile",
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).me, {
    rank: 1,
    userId: "me",
    totalValue: 0,
    nickname: null,
    avatarKey: "ring-green",
    avatarUrl: null,
  });
});

test("leaderboard identity is null when the current user is not joined", async () => {
  const d1 = await freshDbForMe({
    meJoined: false,
    meIdentityMode: "custom",
    meLeaderboardNickname: "Hidden Me",
    meLeaderboardNicknameKey: "hiddenme",
    meLeaderboardAvatarKey: "ring-green",
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).identity, null);
});

test("day leaderboard includes active joined users with zero total", async () => {
  const d1 = await freshDbForMe();
  const today = rankingDateForShanghai(new Date().toISOString());
  await seedRankedUser(d1, "u1", {
    displayName: "Active",
    total: 12,
    rankingDate: today,
  });
  await seedRankedUser(d1, "u2", { displayName: "Zero" });

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(
    body.top.map((row) => [row.userId, row.totalValue]),
    [
      ["u1", 12],
      ["me", 0],
      ["u2", 0],
    ],
  );
  assert.equal(body.me.rank, 2);
  assert.equal(body.me.totalValue, 0);
});

test("week leaderboard includes active joined users with zero total", async () => {
  const d1 = await freshDbForMe();
  const today = rankingDateForShanghai(new Date().toISOString());
  await seedRankedUser(d1, "u1", {
    displayName: "Active",
    total: 12,
    rankingDate: today,
  });
  await seedRankedUser(d1, "u2", { displayName: "Zero" });

  const response = await worker.fetch(
    authedRequest("/leaderboard?period=week&exerciseType=pushup"),
    env(d1),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(
    body.top.map((row) => [row.userId, row.totalValue]),
    [
      ["u1", 12],
      ["me", 0],
      ["u2", 0],
    ],
  );
  assert.equal(body.me.rank, 2);
  assert.equal(body.me.totalValue, 0);
});

test("points v1 combines standard and narrow totals for day and week", async () => {
  const d1 = await freshDbForMe();
  const today = rankingDateForShanghai(new Date().toISOString());
  const timestamp = new Date().toISOString();
  await seedRankedUser(d1, "standard-only", {
    displayName: "Standard only",
    total: 67,
    rankingDate: today,
  });
  for (const [exerciseType, total] of [
    ["pushup", 56],
    ["narrow_pushup", 6],
  ]) {
    await d1
      .prepare(
        "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
      )
      .bind("me", exerciseType, today, total, timestamp, timestamp)
      .run();
  }

  for (const period of ["day", "week"]) {
    const response = await worker.fetch(
      authedRequest(
        `/leaderboard?period=${period}&metric=pushup_points_v1`,
      ),
      env(d1),
    );

    assert.equal(response.status, 200, period);
    const body = await response.json();
    assert.equal(body.metric, "pushup_points_v1");
    assert.equal(body.metricUnit, "points");
    assert.equal(body.exerciseType, undefined);
    assert.deepEqual(
      body.top.map((row) => [row.userId, row.totalValue]),
      [
        ["me", 68],
        ["standard-only", 67],
      ],
    );
    assert.equal(body.me.rank, 1);
    assert.equal(body.me.totalValue, 68);
  }
});

test("day leaderboard keeps a joined user at their frozen score after membership expires", async () => {
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
  const ids = body.top.map((row) => row.userId);
  assert.deepEqual(ids, ["u1", "u2", "me"]);
  assert.equal(body.top[0].totalValue, 100);
});

test("week leaderboard keeps expired joined users the same as day", async () => {
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
  assert.deepEqual(ids, ["u1", "u2", "me"]);
  assert.equal(body.top[0].totalValue, 100);
});

test("expired current member stays ranked with their frozen day and week score", async () => {
  const d1 = await freshDbForMe({
    meIsActive: 0,
    meExpiresAt: "2020-01-01T00:00:00.000Z",
  });
  const today = rankingDateForShanghai(new Date().toISOString());
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind("me", "pushup", today, 42, new Date().toISOString(), new Date().toISOString())
    .run();

  for (const period of ["day", "week"]) {
    const response = await worker.fetch(
      authedRequest(`/leaderboard?period=${period}&exerciseType=pushup`),
      env(d1),
    );

    assert.equal(response.status, 200);
    const body = await response.json();
    assert.deepEqual(
      body.top.map((row) => [row.userId, row.totalValue]),
      [["me", 42]],
    );
    assert.equal(body.me.userId, "me");
    assert.equal(body.me.rank, 1);
    assert.equal(body.me.totalValue, 42);
    assert.equal(body.frozenTotalValue, 42);
  }
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
  const postLocalDate = new Date(startedAtMs + 480 * 60 * 1000).toISOString().slice(0, 10);
  const postWorkout = {
    clientSessionId: "post-rejoin",
    exerciseType: "pushup",
    startedAt: new Date(startedAtMs).toISOString(),
    endedAt: new Date(endedAtMs).toISOString(),
    localDate: postLocalDate,
    timezoneOffsetMinutes: 480,
    metricValue: 15,
    metricUnit: "reps",
  };
  // A PRE-rejoin workout that genuinely ended before the new joined_at. Even
  // though the profile is now joined, it must not aggregate because the
  // consent window (joined_at <= endedAt) excludes it.
  const preEndedAtMs = Date.parse(newJoinedAt) - 10 * 60 * 1000;
  const preStartedAtMs = preEndedAtMs - 3 * 60 * 1000;
  const preLocalDate = new Date(preStartedAtMs + 480 * 60 * 1000).toISOString().slice(0, 10);
  const preWorkout = {
    clientSessionId: "pre-rejoin",
    exerciseType: "pushup",
    startedAt: new Date(preStartedAtMs).toISOString(),
    endedAt: new Date(preEndedAtMs).toISOString(),
    localDate: preLocalDate,
    timezoneOffsetMinutes: 480,
    metricValue: 7,
    metricUnit: "reps",
  };
  const syncRes = await worker.fetch(
    new Request("https://worker.test/workouts/sync", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: "Bearer valid-token",
      },
      body: JSON.stringify({ workouts: [postWorkout, preWorkout] }),
    }),
    env(d1),
  );
  const syncBody = await syncRes.json();
  const byId = new Map(syncBody.results.map((r) => [r.clientSessionId, r]));
  assert.equal(byId.get("post-rejoin").status, "accepted");
  assert.equal(byId.get("post-rejoin").aggregated, true);
  // The pre-rejoin workout is persisted as history but NOT aggregated.
  assert.equal(byId.get("pre-rejoin").status, "accepted");
  assert.equal(byId.get("pre-rejoin").aggregated, false);

  // At a Shanghai-week boundary the post-rejoin workout may land on weekDate
  // itself. Either way, the cleared legacy 40 must never revive.
  const clearedDayTotal = await dailyTotal(d1, "me", "pushup", weekDate);
  assert.equal(
    clearedDayTotal?.total_value ?? null,
    workoutRankingDate === weekDate ? 15 : null,
    "cleared legacy score stays cleared",
  );
  const postTotal = await dailyTotal(d1, "me", "pushup", workoutRankingDate);
  assert.equal(postTotal.total_value, 15, "only the post-rejoin workout counts");
});

test("repeated join while already joined preserves joined_at and totals", async () => {
  // A1 RED: a join posted while already joined must be idempotent. The current
  // code runs an unconditional DELETE of current-week aggregates, so the total
  // drops from 50 to null even though the user never left.
  const d1 = await freshDbForMe();
  const weekDate = weekRangeForShanghai(new Date().toISOString()).start;
  await d1
    .prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind("me", "pushup", weekDate, 50, "2026-07-09T01:00:00.000Z", "2026-07-09T01:00:00.000Z")
    .run();

  const beforeProfile = await d1
    .prepare("SELECT joined_at FROM leaderboard_profiles WHERE user_id = ?")
    .bind("me")
    .first();

  // Re-post join while already joined.
  const response = await worker.fetch(authedRequest("/leaderboard/join", "POST"), env(d1));
  assert.equal(response.status, 200);
  const body = await response.json();

  // joined_at must be unchanged (idempotent).
  assert.equal(body.joinedAt, beforeProfile.joined_at);
  // Total must survive the repeated join.
  const total = await dailyTotal(d1, "me", "pushup", weekDate);
  assert.equal(total.total_value, 50, "totals must not be cleared by a repeated join");
});
