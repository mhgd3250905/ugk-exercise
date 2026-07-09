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
        nickname: "Alpha",
        avatar_key: "ring-green",
      },
      {
        user_id: "u2",
        total_value: 90,
        nickname: "Beta",
        avatar_key: "ring-lime",
      },
      {
        user_id: "me",
        total_value: 10,
        nickname: "Me",
        avatar_key: "ring-sky",
      },
    ];
    this.weekRows = options.weekRows ?? [
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
      {
        user_id: "u1",
        total_value: 40,
        nickname: "Alpha",
        avatar_key: "ring-green",
      },
    ];
    this.lastJoinWrite = null;
    this.lastLeaveWrite = null;
  }

  prepare(sql) {
    return new LeaderboardStatement(this, sql);
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
    if (this.sql.includes("FROM leaderboard_daily_totals")) {
      assert.match(this.sql, /INNER JOIN leaderboard_profiles AS profiles/i);
      assert.match(this.sql, /profiles\.is_joined = 1/i);
      assert.match(this.sql, /INNER JOIN users ON users\.id = totals\.user_id/i);
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
    throw new Error(`unexpected run sql: ${this.sql}`);
  }
}

function env(db) {
  return { ...envBase, DB: db };
}

async function leaderboardDb(options = {}) {
  return new LeaderboardDb(await hashToken(envBase, "valid-token"), options);
}

function authedRequest(path, method = "GET") {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer valid-token",
    },
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
    top: [
      {
        rank: 1,
        userId: "u1",
        totalValue: 100,
        nickname: "Alpha",
        avatarKey: "ring-green",
      },
      {
        rank: 2,
        userId: "u2",
        totalValue: 90,
        nickname: "Beta",
        avatarKey: "ring-lime",
      },
      {
        rank: 3,
        userId: "me",
        totalValue: 10,
        nickname: "Me",
        avatarKey: "ring-sky",
      },
    ],
    me: {
      rank: 3,
      userId: "me",
      totalValue: 10,
      nickname: "Me",
      avatarKey: "ring-sky",
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
    top: [],
    me: null,
  });
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
