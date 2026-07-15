import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hashToken } from "../.tmp-test/session.js";
import {
  createD1FromSchema,
  seedMembership,
  seedSession,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  REVENUECAT_SECRET_API_KEY: "unit-test-secret-api-key",
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
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function staleMemberDb() {
  const db = await createD1FromSchema();
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedUser(db, "member");
  await seedMembership(db, "member", {
    isActive: 0,
    expiresAt: "2026-07-14T00:00:00.000Z",
    verifiedAt: null,
  });
  await seedSession(db, tokenHash, "member");
  return db;
}

async function withRevenueCat(fetcher, action) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = fetcher;
  try {
    return await action();
  } finally {
    globalThis.fetch = originalFetch;
  }
}

function activeRevenueCatResponse() {
  return new Response(
    JSON.stringify({
      subscriber: {
        entitlements: {
          premium: { expires_date: "2099-01-01T00:00:00.000Z" },
        },
      },
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

test("POST /membership/reconcile repairs stale D1 and every member route sees the same authority", async () => {
  const db = await staleMemberDb();
  let fetchCalls = 0;

  await withRevenueCat(
    async () => {
      fetchCalls += 1;
      return activeRevenueCatResponse();
    },
    async () => {
      const reconciled = await worker.fetch(
        authedRequest("/membership/reconcile", "POST"),
        env(db),
      );
      assert.equal(reconciled.status, 200);
      assert.equal((await reconciled.json()).isActive, true);

      const leaderboard = await worker.fetch(
        authedRequest("/leaderboard?period=day&exerciseType=pushup"),
        env(db),
      );
      assert.equal(leaderboard.status, 200);
      assert.equal((await leaderboard.json()).canJoin, true);

      const joined = await worker.fetch(
        authedRequest("/leaderboard/join", "POST"),
        env(db),
      );
      assert.equal(joined.status, 200);

      const synced = await worker.fetch(
        authedRequest("/workouts/sync", "POST", {
          workouts: [
            {
              clientSessionId: "authority-route-1",
              exerciseType: "pushup",
              startedAt: "2026-07-15T01:00:00.000Z",
              endedAt: "2026-07-15T01:03:00.000Z",
              localDate: "2026-07-15",
              timezoneOffsetMinutes: 480,
              metricValue: 20,
              metricUnit: "reps",
            },
          ],
        }),
        env(db),
      );
      assert.equal(synced.status, 200);
      assert.equal((await synced.json()).results[0].status, "accepted");
    },
  );

  assert.equal(fetchCalls, 1);
});

test("failed reconciliation returns a distinct 503 and leaves the stale snapshot untouched", async () => {
  const db = await staleMemberDb();

  await withRevenueCat(
    async () => new Response("unavailable", { status: 503 }),
    async () => {
      const response = await worker.fetch(
        authedRequest("/membership/reconcile", "POST"),
        env(db),
      );
      assert.equal(response.status, 503);
      assert.deepEqual(await response.json(), {
        error: "membership_sync_unavailable",
      });
    },
  );

  const stored = await db
    .prepare(
      "SELECT is_active, expires_at, verified_at FROM membership_snapshots WHERE user_id = ?",
    )
    .bind("member")
    .first();
  assert.deepEqual({ ...stored }, {
    is_active: 0,
    expires_at: "2026-07-14T00:00:00.000Z",
    verified_at: null,
  });
});
