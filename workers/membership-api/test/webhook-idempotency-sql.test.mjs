// Real-SQL coverage for webhook idempotency under concurrency.
//
// worker-routes.test.mjs mocks the D1 facade with synchronous in-memory state,
// so its "concurrent duplicate" test cannot truly interleave the two requests
// at the critical read→reconcile→insert region (the mock never yields there).
// That test therefore passes against the OLD code too and does not guard the
// fix. This file drives the compiled webhook handler against a REAL SQLite
// database (createD1FromSchema) and asserts that two webhooks for the same
// event.id cause exactly one RevenueCat fetch / snapshot write — the behaviour
// the claim-before-reconcile ordering guarantees.
import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hashToken } from "../.tmp-test/session.js";
import { hmacSha256Hex } from "../.tmp-test/webhook_auth.js";
import {
  createD1FromSchema,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  REVENUECAT_SECRET_API_KEY: "unit-test-secret-api-key",
  SESSION_SECRET: "unit-test-session-secret",
};

async function buildEnv() {
  const db = await createD1FromSchema();
  await seedUser(db, "user_sql");
  return { ...envBase, DB: db };
}

function webhookBody(eventId) {
  const now = Date.now();
  return JSON.stringify({
    event: {
      id: eventId,
      type: "INITIAL_PURCHASE",
      app_user_id: "user_sql",
      entitlement_ids: ["premium"],
      expiration_at_ms: now + 365 * 24 * 60 * 60 * 1000,
      event_timestamp_ms: now,
    },
  });
}

async function signedRequest(body) {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = await hmacSha256Hex(
    envBase.REVENUECAT_WEBHOOK_SECRET,
    `${timestamp}.${body}`,
  );
  // RevenueCat signature header format parsed by webhook_auth: "t=<ts>, v1=<sig>".
  const header = `t=${timestamp}, v1=${signature}`;
  return new Request("https://worker.test/webhooks/revenuecat", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-revenuecat-webhook-signature": header,
    },
    body,
  });
}

test("two webhooks for the same event id fetch RevenueCat and write the snapshot exactly once", async () => {
  const env = await buildEnv();
  let revenueCatFetches = 0;
  // Count external RevenueCat calls made by reconcileMembership.
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = typeof input === "string" ? input : input?.url ?? "";
    if (url.startsWith("https://api.revenuecat.com/")) {
      revenueCatFetches += 1;
      return new Response(
        JSON.stringify({
          subscriber: {
            entitlements: {
              premium: { expires_date: "2099-01-01T00:00:00.000Z" },
            },
          },
        }),
        { status: 200 },
      );
    }
    return originalFetch(input);
  };

  try {
    const body = webhookBody("evt_sql_dup");
    // Fire both; the loser must short-circuit at the claim without touching
    // RevenueCat.
    const [a, b] = await Promise.all([
      worker.fetch(await signedRequest(body), env),
      worker.fetch(await signedRequest(body), env),
    ]);
    assert.equal(a.status, 200);
    assert.equal(b.status, 200);

    const bodies = await Promise.all([a.json(), b.json()]);
    const duplicates = bodies.filter((value) => value?.duplicate === true);
    assert.equal(duplicates.length, 1);

    // The core guarantee: reconciliation (external fetch + snapshot write)
    // happened exactly once for two concurrent submissions.
    assert.equal(revenueCatFetches, 1);
    const writes = await env.DB
      .prepare(
        "SELECT COUNT(*) AS n FROM webhook_events WHERE provider = 'revenuecat' AND event_id = ?",
      )
      .bind("evt_sql_dup")
      .first();
    assert.equal(writes?.n, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("a failed reconciliation releases the claim so the event stays retryable", async () => {
  const env = await buildEnv();
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = typeof input === "string" ? input : input?.url ?? "";
    if (url.startsWith("https://api.revenuecat.com/")) {
      return new Response("unavailable", { status: 503 });
    }
    return originalFetch(input);
  };

  try {
    const body = webhookBody("evt_sql_retry");
    const failed = await worker.fetch(await signedRequest(body), env);
    assert.equal(failed.status, 503);
    // Claim released so a later retry can re-process the same event id.
    const claimed = await env.DB
      .prepare(
        "SELECT COUNT(*) AS n FROM webhook_events WHERE provider = 'revenuecat' AND event_id = ?",
      )
      .bind("evt_sql_retry")
      .first();
    assert.equal(claimed?.n, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
