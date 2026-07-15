import assert from "node:assert/strict";
import test from "node:test";

import {
  getAuthoritativeMembership,
  MembershipReconciliationError,
  reconcileMembership,
} from "../.tmp-test/membership_reconciliation.js";
import {
  createD1FromSchema,
  seedMembership,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const userId = "u_reconcile";

async function createDb() {
  const db = await createD1FromSchema();
  await seedUser(db, userId);
  return db;
}

function revenueCatResponse(entitlement) {
  return new Response(
    JSON.stringify({
      subscriber: {
        entitlements: entitlement === undefined ? {} : { premium: entitlement },
      },
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

function envFor(db) {
  return {
    DB: db,
    REVENUECAT_SECRET_API_KEY: "test-secret-api-key",
  };
}

test("reconciliation rebuilds an expired D1 snapshot from current RevenueCat entitlement", async () => {
  const db = await createDb();
  await seedMembership(db, userId, {
    isActive: 0,
    expiresAt: "2026-07-14T00:00:00.000Z",
    verifiedAt: null,
  });

  let requestedUrl;
  let requestedAuthorization;
  const result = await reconcileMembership(envFor(db), userId, {
    now: new Date("2026-07-15T00:00:00.000Z"),
    fetcher: async (input, init) => {
      requestedUrl = String(input);
      requestedAuthorization = new Headers(init?.headers).get("authorization");
      return revenueCatResponse({ expires_date: "2026-08-15T00:00:00.000Z" });
    },
  });

  assert.equal(
    requestedUrl,
    "https://api.revenuecat.com/v1/subscribers/u_reconcile",
  );
  assert.equal(requestedAuthorization, "Bearer test-secret-api-key");
  assert.deepEqual(result, {
    entitlement: "premium",
    isActive: true,
    expiresAt: "2026-08-15T00:00:00.000Z",
    source: "revenuecat_verified",
    verifiedAt: "2026-07-15T00:00:00.000Z",
  });

  const stored = await db
    .prepare(
      "SELECT is_active, expires_at, source, verified_at FROM membership_snapshots WHERE user_id = ?",
    )
    .bind(userId)
    .first();
  assert.deepEqual({ ...stored }, {
    is_active: 1,
    expires_at: "2026-08-15T00:00:00.000Z",
    source: "revenuecat_verified",
    verified_at: "2026-07-15T00:00:00.000Z",
  });
});

test("current RevenueCat expiry overrides an old active D1 snapshot", async () => {
  const db = await createDb();
  await seedMembership(db, userId, {
    isActive: 1,
    expiresAt: "2099-01-01T00:00:00.000Z",
    verifiedAt: null,
  });

  const result = await reconcileMembership(envFor(db), userId, {
    now: new Date("2026-07-15T00:00:00.000Z"),
    fetcher: async () =>
      revenueCatResponse({ expires_date: "2026-07-14T00:00:00.000Z" }),
  });

  assert.equal(result.isActive, false);
  assert.equal(result.expiresAt, "2026-07-14T00:00:00.000Z");
});

test("missing premium entitlement is a verified inactive state", async () => {
  const db = await createDb();

  const result = await reconcileMembership(envFor(db), userId, {
    now: new Date("2026-07-15T00:00:00.000Z"),
    fetcher: async () => revenueCatResponse(undefined),
  });

  assert.deepEqual(result, {
    entitlement: "premium",
    isActive: false,
    expiresAt: null,
    source: "revenuecat_verified",
    verifiedAt: "2026-07-15T00:00:00.000Z",
  });
});

test("RevenueCat failures do not corrupt the existing snapshot", async () => {
  const db = await createDb();
  await seedMembership(db, userId, {
    isActive: 1,
    expiresAt: "2099-01-01T00:00:00.000Z",
    source: "existing",
    verifiedAt: null,
  });

  await assert.rejects(
    reconcileMembership(envFor(db), userId, {
      now: new Date("2026-07-15T00:00:00.000Z"),
      fetcher: async () => new Response("unavailable", { status: 503 }),
    }),
    (error) =>
      error instanceof MembershipReconciliationError &&
      error.code === "membership_sync_unavailable",
  );

  const stored = await db
    .prepare(
      "SELECT is_active, expires_at, source, verified_at FROM membership_snapshots WHERE user_id = ?",
    )
    .bind(userId)
    .first();
  assert.deepEqual({ ...stored }, {
    is_active: 1,
    expires_at: "2099-01-01T00:00:00.000Z",
    source: "existing",
    verified_at: null,
  });
});

test("an older observation cannot overwrite or return over a newer verified state", async () => {
  const db = await createDb();
  const env = envFor(db);

  await reconcileMembership(env, userId, {
    now: new Date("2026-07-15T00:05:00.000Z"),
    fetcher: async () =>
      revenueCatResponse({ expires_date: "2026-08-15T00:00:00.000Z" }),
  });

  const result = await reconcileMembership(env, userId, {
    now: new Date("2026-07-15T00:04:00.000Z"),
    fetcher: async () =>
      revenueCatResponse({ expires_date: "2026-07-14T00:00:00.000Z" }),
  });

  assert.equal(result.isActive, true);
  assert.equal(result.expiresAt, "2026-08-15T00:00:00.000Z");
  assert.equal(result.verifiedAt, "2026-07-15T00:05:00.000Z");
});

test("authoritative read reuses a fresh verified cache without calling RevenueCat", async () => {
  const db = await createDb();
  await seedMembership(db, userId, {
    isActive: 0,
    expiresAt: "2026-07-14T00:00:00.000Z",
    source: "revenuecat_verified",
    verifiedAt: "2026-07-15T00:04:00.000Z",
  });
  let fetchCalls = 0;

  const result = await getAuthoritativeMembership(envFor(db), userId, {
    now: new Date("2026-07-15T00:05:00.000Z"),
    fetcher: async () => {
      fetchCalls += 1;
      return revenueCatResponse({ expires_date: "2099-01-01T00:00:00.000Z" });
    },
  });

  assert.equal(fetchCalls, 0);
  assert.equal(result.isActive, false);
  assert.equal(result.verifiedAt, "2026-07-15T00:04:00.000Z");
});

test("authoritative read reconciles an unverified or stale cache", async () => {
  const db = await createDb();
  await seedMembership(db, userId, {
    isActive: 0,
    expiresAt: "2026-07-14T00:00:00.000Z",
    verifiedAt: null,
  });

  const result = await getAuthoritativeMembership(envFor(db), userId, {
    now: new Date("2026-07-15T00:05:00.000Z"),
    fetcher: async () =>
      revenueCatResponse({ expires_date: "2099-01-01T00:00:00.000Z" }),
  });

  assert.equal(result.isActive, true);
  assert.equal(result.source, "revenuecat_verified");
});
