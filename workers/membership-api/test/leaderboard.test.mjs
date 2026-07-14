import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import {
  rowsForLeaderboardForTest,
  weekRangeForShanghai,
} from "../.tmp-test/leaderboard.js";
import { hashToken } from "../.tmp-test/session.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

test("weekRangeForShanghai returns current Monday through Sunday", () => {
  assert.deepEqual(weekRangeForShanghai("2026-07-09T12:00:00.000Z"), {
    start: "2026-07-06",
    end: "2026-07-12",
  });
});

test("leaderboard rows include top rows and my rank outside top list", () => {
  const rows = rowsForLeaderboardForTest({
    totals: [
      { userId: "u1", total: 100 },
      { userId: "u2", total: 90 },
      { userId: "me", total: 10 },
    ],
    me: "me",
    limit: 2,
  });

  assert.deepEqual(
    rows.top.map((row) => row.userId),
    ["u1", "u2"],
  );
  assert.equal(rows.me.userId, "me");
  assert.equal(rows.me.rank, 3);
});

class LeaderboardDb {
  constructor(tokenHash, options = {}) {
    this.sessions = new Map([
      [
        tokenHash,
        {
          user_id: "me",
          app_user_id: "me",
          expires_at: "2099-01-01T00:00:00.000Z",
        },
      ],
    ]);
    this.membership = options.membership ?? {
      is_active: 1,
      expires_at: "2099-01-01T00:00:00.000Z",
    };
    this.joinProfiles = new Map(
      (options.joinProfiles ?? []).map((row) => [row.user_id, row]),
    );
    this.users = new Map(
      [
        { id: "u1", nickname: "Alpha", avatar_key: "ring-green" },
        { id: "u2", nickname: "Beta", avatar_key: "ring-lime" },
        { id: "me", nickname: "Me", avatar_key: "ring-sky" },
      ].map((row) => [row.id, row]),
    );
    this.dayRows = options.dayRows ?? [
      {
        user_id: "u1",
        total_value: 100,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-green",
        display_name: "Alpha Google",
        avatar_url: null,
        nickname: "Alpha",
        avatar_key: "ring-green",
      },
      {
        user_id: "u2",
        total_value: 90,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-lime",
        display_name: "Beta Google",
        avatar_url: null,
        nickname: "Beta",
        avatar_key: "ring-lime",
      },
      {
        user_id: "me",
        total_value: 10,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-sky",
        display_name: "Me Google",
        avatar_url: null,
        nickname: "Me",
        avatar_key: "ring-sky",
      },
    ];
    this.weekRows = options.weekRows ?? [
      {
        user_id: "u2",
        total_value: 110,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-lime",
        display_name: "Beta Google",
        avatar_url: null,
        nickname: "Beta",
        avatar_key: "ring-lime",
      },
      {
        user_id: "me",
        total_value: 50,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-sky",
        display_name: "Me Google",
        avatar_url: null,
        nickname: "Me",
        avatar_key: "ring-sky",
      },
      {
        user_id: "u1",
        total_value: 40,
        identity_mode: "profile",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-green",
        display_name: "Alpha Google",
        avatar_url: null,
        nickname: "Alpha",
        avatar_key: "ring-green",
      },
    ];
    this.lastJoinWrite = null;
    this.lastLeaveWrite = null;
    this.lastAggregateClear = null;
    this.beforeIdentityUpdate = options.beforeIdentityUpdate ?? null;
  }

  prepare(sql) {
    return new LeaderboardStatement(this, sql);
  }

  // joinLeaderboard now batches the profile upsert with an aggregate clear; run
  // them in sequence so the fake observes both writes.
  async batch(statements) {
    const results = [];
    for (const statement of statements) {
      results.push(await statement.run());
    }
    return results;
  }
}

class LeaderboardStatement {
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
      return this.db.membership;
    }
    if (this.sql.includes("FROM leaderboard_profiles WHERE user_id = ?")) {
      return this.db.joinProfiles.get(this.args[0]) ?? null;
    }
    return null;
  }

  async all() {
    if (this.sql.includes("leaderboard_daily_totals")) {
      assert.match(this.sql, /FROM leaderboard_profiles AS profiles/i);
      assert.match(this.sql, /profiles\.is_joined = 1/i);
      assert.match(this.sql, /LEFT JOIN[^]*leaderboard_daily_totals/i);
      assert.match(this.sql, /COALESCE\(totals\.total_value, 0\)/i);
      assert.match(this.sql, /INNER JOIN users ON users\.id = profiles\.user_id/i);
      assert.match(this.sql, /profiles\.identity_mode/i);
      assert.doesNotMatch(this.sql, /profiles\.leaderboard_nickname/i);
      assert.doesNotMatch(this.sql, /profiles\.leaderboard_avatar_key/i);
      assert.match(this.sql, /profiles\.anonymous_avatar_key/i);
      assert.match(this.sql, /users\.display_name/i);
      assert.match(this.sql, /users\.avatar_url/i);
      // Membership must be re-checked at query time: only currently-active,
      // unexpired members may rank, regardless of historical aggregate rows.
      assert.match(
        this.sql,
        /INNER JOIN membership_snapshots[^]*membership\.user_id = profiles\.user_id[^]*is_active\s*=\s*1/i,
      );
      if (this.sql.includes("BETWEEN ? AND ?")) {
        assert.match(this.sql, /SUM\(total_value\) AS total_value/i);
        assert.match(this.sql, /GROUP BY user_id/i);
      }
      const rows = this.sql.includes("BETWEEN ? AND ?")
        ? this.db.weekRows
        : this.db.dayRows;
      return { results: rows };
    }
    throw new Error(`unexpected all sql: ${this.sql}`);
  }

  async run() {
    if (this.sql.includes("UPDATE leaderboard_profiles SET identity_mode")) {
      const userId = this.args.at(-1);
      if (this.db.beforeIdentityUpdate) {
        const hook = this.db.beforeIdentityUpdate;
        this.db.beforeIdentityUpdate = null;
        hook(this.db, userId);
      }
      const current = this.db.joinProfiles.get(userId) ?? null;
      if (current?.is_joined !== 1) {
        return { meta: { changes: 0 } };
      }
      this.db.joinProfiles.set(userId, {
        ...current,
        identity_mode: this.args[0],
        updated_at: this.args[1],
      });
      return { meta: { changes: 1 } };
    }
    if (this.sql.includes("INSERT INTO leaderboard_profiles")) {
      const isJoin = this.sql.includes("VALUES (?, 1");
      if (isJoin) {
        const existing = this.db.joinProfiles.get(this.args[0]) ?? null;
        const keepExistingJoinedAt =
          /leaderboard_profiles\.is_joined = 1/i.test(this.sql) &&
          /leaderboard_profiles\.joined_at IS NOT NULL/i.test(this.sql);
        const joinedAt =
          keepExistingJoinedAt &&
          existing?.is_joined === 1 &&
          existing.joined_at !== null
            ? existing.joined_at
            : this.args[1];
        this.db.lastJoinWrite = {
          user_id: this.args[0],
          joined_at: joinedAt,
          updated_at: this.args[2],
          previous: existing,
        };
        this.db.joinProfiles.set(this.args[0], {
          user_id: this.args[0],
          is_joined: 1,
          joined_at: joinedAt,
          left_at: null,
          updated_at: this.args[2],
          identity_mode: this.args[3],
          anonymous_avatar_key:
            existing?.anonymous_avatar_key ?? this.args[4],
        });
      } else {
        this.db.lastLeaveWrite = {
          user_id: this.args[0],
          left_at: this.args[1],
          updated_at: this.args[2],
        };
        this.db.joinProfiles.set(this.args[0], {
          user_id: this.args[0],
          is_joined: 0,
          joined_at: null,
          left_at: this.args[1],
          updated_at: this.args[2],
        });
      }
      return { meta: { changes: 1 } };
    }
    if (this.sql.includes("DELETE FROM leaderboard_daily_totals")) {
      // Rejoin-after-leave clears the user's current Shanghai-week aggregates.
      const [userId, weekStart, weekEnd] = this.args;
      this.db.lastAggregateClear = { user_id: userId, weekStart, weekEnd };
      return { meta: { changes: 1 } };
    }
    throw new Error(`unexpected run sql: ${this.sql}`);
  }
}

function env(db) {
  return { ...envBase, DB: db };
}

async function leaderboardDb(options = {}) {
  return new LeaderboardDb(await hashToken(envBase, "valid-token"), options);
}

function authedRequest(path, method = "GET", body) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer valid-token",
      ...(body === undefined ? {} : { "content-type": "application/json" }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

test("POST /leaderboard/join rejects non-premium users", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(
      await leaderboardDb({
        membership: {
          is_active: 0,
          expires_at: "2026-07-08T00:00:00.000Z",
        },
      }),
    ),
  );

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: "premium_required" });
});

test("POST /leaderboard/join writes joined profile for premium user", async () => {
  const db = await leaderboardDb();

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.equal(typeof body.joinedAt, "string");
  assert.equal(db.lastJoinWrite.user_id, "me");
  assert.equal(db.lastJoinWrite.joined_at, body.joinedAt);
});

test("POST /leaderboard/join keeps existing joined_at for joined user", async () => {
  const joinedAt = "2026-07-01T00:00:00.000Z";
  const db = await leaderboardDb({
    joinProfiles: [
      {
        user_id: "me",
        is_joined: 1,
        joined_at: joinedAt,
        left_at: null,
        updated_at: joinedAt,
      },
    ],
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, joinedAt });
  assert.equal(db.joinProfiles.get("me").joined_at, joinedAt);
});

test("POST /leaderboard/join writes new joined_at when rejoining after leave", async () => {
  const oldJoinedAt = "2026-07-01T00:00:00.000Z";
  const leftAt = "2026-07-02T00:00:00.000Z";
  const db = await leaderboardDb({
    joinProfiles: [
      {
        user_id: "me",
        is_joined: 0,
        joined_at: oldJoinedAt,
        left_at: leftAt,
        updated_at: leftAt,
      },
    ],
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.ok, true);
  assert.notEqual(body.joinedAt, oldJoinedAt);
  assert.equal(db.joinProfiles.get("me").joined_at, body.joinedAt);
});

test("POST /leaderboard/join clears current Shanghai-week aggregates on rejoin", async () => {
  const db = await leaderboardDb({
    joinProfiles: [
      {
        user_id: "me",
        is_joined: 0,
        joined_at: "2026-07-01T00:00:00.000Z",
        left_at: "2026-07-02T00:00:00.000Z",
        updated_at: "2026-07-02T00:00:00.000Z",
      },
    ],
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.ok(db.lastAggregateClear, "rejoin must clear aggregates");
  assert.equal(db.lastAggregateClear.user_id, "me");
  // Clear scoped to a week range (current Shanghai week), not all-time.
  assert.ok(db.lastAggregateClear.weekStart);
  assert.ok(db.lastAggregateClear.weekEnd);
});

test("POST /leaderboard/join repeated while joined keeps joined_at and still clears nothing material", async () => {
  const joinedAt = "2026-07-01T00:00:00.000Z";
  const db = await leaderboardDb({
    joinProfiles: [
      {
        user_id: "me",
        is_joined: 1,
        joined_at: joinedAt,
        left_at: null,
        updated_at: joinedAt,
      },
    ],
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard/join", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true, joinedAt });
  assert.equal(db.joinProfiles.get("me").joined_at, joinedAt);
});

test("POST /leaderboard/leave marks profile as left", async () => {
  const db = await leaderboardDb();

  const response = await worker.fetch(
    authedRequest("/leaderboard/leave", "POST"),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(db.lastLeaveWrite.user_id, "me");
  assert.equal(typeof db.lastLeaveWrite.left_at, "string");
});

test("PATCH /leaderboard/identity rejects a leave after the joined check", async () => {
  const joinedAt = "2026-07-01T00:00:00.000Z";
  const db = await leaderboardDb({
    joinProfiles: [
      {
        user_id: "me",
        is_joined: 1,
        joined_at: joinedAt,
        left_at: null,
        updated_at: joinedAt,
        identity_mode: "custom",
        leaderboard_nickname: "保留昵称",
        leaderboard_nickname_key: "保留昵称",
        leaderboard_avatar_key: "ring-sky",
      },
    ],
    beforeIdentityUpdate: (database, userId) => {
      const current = database.joinProfiles.get(userId);
      database.joinProfiles.set(userId, {
        ...current,
        is_joined: 0,
        left_at: "2026-07-02T00:00:00.000Z",
        updated_at: "2026-07-02T00:00:00.000Z",
      });
    },
  });

  const response = await worker.fetch(
    authedRequest("/leaderboard/identity", "PATCH", { mode: "anonymous" }),
    env(db),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "leaderboard_not_joined" });
  assert.equal(db.joinProfiles.get("me").is_joined, 0);
  assert.equal(db.joinProfiles.get("me").identity_mode, "custom");
});

test("GET /leaderboard returns day ranking with joined current user", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(
      await leaderboardDb({
        joinProfiles: [
          {
            user_id: "me",
            is_joined: 1,
            joined_at: "2026-07-01T00:00:00.000Z",
            left_at: null,
            updated_at: "2026-07-01T00:00:00.000Z",
            identity_mode: "profile",
            leaderboard_nickname: null,
            leaderboard_avatar_key: null,
          },
        ],
      }),
    ),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    period: "day",
    exerciseType: "pushup",
    isJoined: true,
    canJoin: false,
    anonymousAvatarKey: "ring-green",
    identity: { mode: "profile" },
    nextCursor: null,
    top: [
      {
        rank: 1,
        userId: "u1",
        totalValue: 100,
        nickname: "Alpha",
        avatarKey: "ring-green",
        avatarUrl: null,
      },
      {
        rank: 2,
        userId: "u2",
        totalValue: 90,
        nickname: "Beta",
        avatarKey: "ring-lime",
        avatarUrl: null,
      },
      {
        rank: 3,
        userId: "me",
        totalValue: 10,
        nickname: "Me",
        avatarKey: "ring-sky",
        avatarUrl: null,
      },
    ],
    me: {
      rank: 3,
      userId: "me",
      totalValue: 10,
      nickname: "Me",
      avatarKey: "ring-sky",
      avatarUrl: null,
    },
  });
});

test("GET /leaderboard returns false isJoined without profile", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(await leaderboardDb({ dayRows: [] })),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    period: "day",
    exerciseType: "pushup",
    isJoined: false,
    canJoin: true,
    anonymousAvatarKey: "ring-green",
    identity: null,
    nextCursor: null,
    top: [],
    me: null,
  });
});

test("GET /leaderboard prevents join for inactive membership", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(
      await leaderboardDb({
        membership: {
          is_active: 0,
          expires_at: "2026-07-08T00:00:00.000Z",
        },
        dayRows: [],
      }),
    ),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.isJoined, false);
  assert.equal(body.canJoin, false);
});

test("GET /leaderboard returns false isJoined for left profile", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    env(
      await leaderboardDb({
        joinProfiles: [
          {
            user_id: "me",
            is_joined: 0,
            joined_at: "2026-07-01T00:00:00.000Z",
            left_at: "2026-07-02T00:00:00.000Z",
            updated_at: "2026-07-02T00:00:00.000Z",
          },
        ],
        dayRows: [],
      }),
    ),
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).isJoined, false);
});

test("GET /leaderboard returns week ranking and keeps deterministic order", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=week&exerciseType=pushup"),
    env(
      await leaderboardDb({
        weekRows: [
          {
            user_id: "u1",
            total_value: 110,
            nickname: "Alpha",
            avatar_key: "ring-green",
          },
          {
            user_id: "u2",
            total_value: 110,
            nickname: "Beta",
            avatar_key: "ring-lime",
          },
          {
            user_id: "me",
            total_value: 50,
            nickname: "Me",
            avatar_key: "ring-sky",
          },
        ],
      }),
    ),
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(
    body.top.map((row) => row.userId),
    ["u1", "u2", "me"],
  );
  assert.equal(body.me.rank, 3);
});

test("GET /leaderboard pages twenty rows through an opaque cursor", async () => {
  const dayRows = Array.from({ length: 25 }, (_, index) => ({
    user_id: `u${String(index + 1).padStart(2, "0")}`,
    total_value: 1000 - index,
    identity_mode: "anonymous",
    leaderboard_nickname: null,
    leaderboard_avatar_key: null,
    anonymous_avatar_key: "ring-green",
    display_name: null,
    avatar_url: null,
    nickname: null,
    avatar_key: null,
  }));
  const database = env(await leaderboardDb({ dayRows }));

  const firstResponse = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    database,
  );
  const first = await firstResponse.json();

  assert.equal(first.top.length, 20);
  assert.deepEqual(
    first.top.map((row) => row.rank),
    Array.from({ length: 20 }, (_, index) => index + 1),
  );
  assert.equal(typeof first.nextCursor, "string");

  const secondResponse = await worker.fetch(
    authedRequest(
      `/leaderboard?period=day&exerciseType=pushup&cursor=${encodeURIComponent(first.nextCursor)}`,
    ),
    database,
  );
  const second = await secondResponse.json();

  assert.deepEqual(
    second.top.map((row) => row.rank),
    [21, 22, 23, 24, 25],
  );
  assert.equal(second.nextCursor, null);
  assert.equal(
    new Set([...first.top, ...second.top].map((row) => row.userId)).size,
    25,
  );
});

test("GET /leaderboard rejects malformed and mismatched cursors", async () => {
  const database = env(
    await leaderboardDb({
      dayRows: Array.from({ length: 21 }, (_, index) => ({
        user_id: `u${index + 1}`,
        total_value: 100 - index,
        identity_mode: "anonymous",
        leaderboard_nickname: null,
        leaderboard_avatar_key: null,
        anonymous_avatar_key: "ring-green",
        display_name: null,
        avatar_url: null,
        nickname: null,
        avatar_key: null,
      })),
    }),
  );
  const malformed = await worker.fetch(
    authedRequest(
      "/leaderboard?period=day&exerciseType=pushup&cursor=not-a-cursor",
    ),
    database,
  );
  assert.equal(malformed.status, 400);
  assert.deepEqual(await malformed.json(), {
    error: "invalid_leaderboard_query",
  });

  const first = await worker.fetch(
    authedRequest("/leaderboard?period=day&exerciseType=pushup"),
    database,
  );
  const body = await first.json();
  assert.equal(typeof body.nextCursor, "string");
  const mismatched = await worker.fetch(
    authedRequest(
      `/leaderboard?period=week&exerciseType=pushup&cursor=${encodeURIComponent(body.nextCursor)}`,
    ),
    database,
  );
  assert.equal(mismatched.status, 400);
  assert.deepEqual(await mismatched.json(), {
    error: "invalid_leaderboard_query",
  });
});

test("GET /leaderboard rejects invalid query", async () => {
  const response = await worker.fetch(
    authedRequest("/leaderboard?period=month&exerciseType=squat"),
    env(await leaderboardDb()),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: "invalid_leaderboard_query",
  });
});
