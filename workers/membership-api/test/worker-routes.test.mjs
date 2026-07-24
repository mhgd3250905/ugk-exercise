import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hmacSha256Hex } from "../.tmp-test/webhook_auth.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  REVENUECAT_SECRET_API_KEY: "unit-test-secret-api-key",
  SESSION_SECRET: "unit-test-session-secret",
};

let revenueCatStatus = 200;
let revenueCatEntitlement = {
  expires_date: "2099-01-01T00:00:00.000Z",
};
globalThis.fetch = async () =>
  revenueCatStatus === 200
    ? new Response(
        JSON.stringify({
          subscriber: {
            entitlements:
              revenueCatEntitlement === null
                ? {}
                : { premium: revenueCatEntitlement },
          },
        }),
        { status: 200 },
      )
    : new Response("unavailable", { status: revenueCatStatus });

class MembershipDb {
  constructor() {
    this.users = new Set(["user_1"]);
    this.webhookEventIds = new Set();
    this.snapshot = null;
    this.snapshotWrites = 0;
  }

  prepare(sql) {
    return new MembershipStatement(this, sql);
  }

  // D1 batches are atomic: either every statement commits or none do. The
  // in-memory mock has no real constraints to enforce, so mirror the
  // all-or-nothing shape by running each statement's run() in order and
  // rolling back the in-memory state on the first failure.
  async batch(statements) {
    const results = [];
    // Snapshot enough mutable state to emulate rollback on failure.
    const snapshotUsers = new Set(this.users);
    const snapshotEventIds = new Set(this.webhookEventIds);
    const snapshotSnapshot = this.snapshot;
    try {
      for (const statement of statements) {
        results.push(await statement.run());
      }
      return results;
    } catch (error) {
      this.users = snapshotUsers;
      this.webhookEventIds = snapshotEventIds;
      this.snapshot = snapshotSnapshot;
      throw error;
    }
  }
}

class MembershipStatement {
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
    if (this.sql.includes("FROM users WHERE id = ?")) {
      const userId = this.args[0];
      return this.db.users.has(userId) ? { id: userId } : null;
    }
    if (this.sql.includes("FROM webhook_events WHERE provider = ?")) {
      return this.db.webhookEventIds.has(this.args[1])
        ? { processed_at: "2026-07-15T00:00:00.000Z" }
        : null;
    }
    if (this.sql.includes("FROM membership_snapshots WHERE user_id = ?")) {
      return this.db.snapshot;
    }
    return null;
  }

  async run() {
    if (this.sql.includes("INSERT OR IGNORE INTO webhook_events")) {
      const eventId = this.args[2];
      if (this.db.webhookEventIds.has(eventId)) {
        return { meta: { changes: 0 } };
      }
      this.db.webhookEventIds.add(eventId);
      return { meta: { changes: 1 } };
    }
    if (this.sql.includes("DELETE FROM webhook_events")) {
      // Release a claimed event id so a failed reconciliation stays retryable.
      const eventId = this.args[1];
      const had = this.db.webhookEventIds.delete(eventId);
      return { meta: { changes: had ? 1 : 0 } };
    }
    if (this.sql.includes("INSERT INTO membership_snapshots")) {
      const reconciled = this.sql.includes("verified_at");
      const lastEventAt = reconciled ? this.args[4] : this.args[6];
      const verifiedAt = reconciled ? this.args[6] : null;
      const canWrite =
        this.db.snapshot === null ||
        (reconciled
          ? this.db.snapshot.verified_at === null ||
            verifiedAt >= this.db.snapshot.verified_at
          : this.db.snapshot.last_event_at === null ||
            lastEventAt >= this.db.snapshot.last_event_at);
      if (!canWrite) {
        return { meta: { changes: 0 } };
      }
      this.db.snapshot = reconciled
        ? {
            user_id: this.args[0],
            entitlement: "premium",
            is_active: this.args[1],
            expires_at: this.args[2],
            source: "revenuecat_verified",
            revenuecat_app_user_id: this.args[3],
            last_event_at:
              this.db.snapshot?.last_event_at === null ||
              this.db.snapshot?.last_event_at === undefined ||
              lastEventAt >= this.db.snapshot.last_event_at
                ? lastEventAt
                : this.db.snapshot.last_event_at,
            updated_at: this.args[5],
            verified_at: verifiedAt,
          }
        : {
            user_id: this.args[0],
            entitlement: this.args[1],
            is_active: this.args[2],
            expires_at: this.args[3],
            source: this.args[4],
            revenuecat_app_user_id: this.args[5],
            last_event_at: lastEventAt,
            updated_at: this.args[7],
            verified_at: null,
          };
      this.db.snapshotWrites += 1;
      return { meta: { changes: 1 } };
    }
    return { meta: { changes: 1 } };
  }
}

function env(db) {
  return { ...envBase, DB: db };
}

function revenueCatPayload({
  id,
  eventTime,
  entitlementIds = ["premium"],
  expirationMs = Date.parse("2099-01-01T00:00:00.000Z"),
}) {
  return JSON.stringify({
    event: {
      id,
      type: "INITIAL_PURCHASE",
      app_user_id: "user_1",
      entitlement_ids: entitlementIds,
      expiration_at_ms: expirationMs,
      event_timestamp_ms: Date.parse(eventTime),
    },
  });
}

async function signedWebhookRequest(body, signatureHeader) {
  return new Request("https://worker.test/webhooks/revenuecat", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-revenuecat-webhook-signature": signatureHeader,
    },
    body,
  });
}

async function postSignedWebhook(db, body) {
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = await hmacSha256Hex(
    envBase.REVENUECAT_WEBHOOK_SECRET,
    `${timestamp}.${body}`,
  );
  return worker.fetch(
    await signedWebhookRequest(body, `t=${timestamp},v1=${signature}`),
    env(db),
  );
}

async function responseJson(response) {
  return JSON.parse(await response.text());
}

test("webhook rejects a bad RevenueCat HMAC signature", async () => {
  const db = new MembershipDb();
  const body = revenueCatPayload({
    id: "evt_bad_sig",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const response = await worker.fetch(
    await signedWebhookRequest(body, "t=1783616400,v1=bad-signature"),
    env(db),
  );

  assert.equal(response.status, 401);
  assert.equal(db.webhookEventIds.size, 0);
  assert.equal(db.snapshotWrites, 0);
});

test("webhook rejects legacy X-RC-Signature without timestamp", async () => {
  const db = new MembershipDb();
  const body = revenueCatPayload({
    id: "evt_legacy_sig",
    eventTime: "2026-07-09T09:00:00.000Z",
  });
  const signature = await hmacSha256Hex(
    envBase.REVENUECAT_WEBHOOK_SECRET,
    body,
  );

  const response = await worker.fetch(
    new Request("https://worker.test/webhooks/revenuecat", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-rc-signature": signature,
      },
      body,
    }),
    env(db),
  );

  assert.equal(response.status, 401);
  assert.equal(db.webhookEventIds.size, 0);
  assert.equal(db.snapshotWrites, 0);
});

test("webhook accepts a good RevenueCat HMAC signature", async () => {
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const body = revenueCatPayload({
    id: "evt_good_sig",
    eventTime: "2026-07-09T09:00:00.000Z",
    entitlementIds: [],
    expirationMs: Date.parse("2026-07-08T00:00:00.000Z"),
  });

  const response = await postSignedWebhook(db, body);

  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), { ok: true });
  assert.equal(db.snapshot.is_active, 1);
  assert.equal(db.snapshot.last_event_at, "2026-07-09T09:00:00.000Z");
});

test("webhook event cannot grant membership when current RevenueCat entitlement is expired", async () => {
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2026-07-08T00:00:00.000Z",
  };
  const body = revenueCatPayload({
    id: "evt_current_expired",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const response = await postSignedWebhook(db, body);

  assert.equal(response.status, 200);
  assert.equal(db.snapshot.is_active, 0);
});

test("webhook duplicate event id is idempotent", async () => {
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const body = revenueCatPayload({
    id: "evt_duplicate",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const first = await postSignedWebhook(db, body);
  const second = await postSignedWebhook(db, body);

  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.deepEqual(await responseJson(second), { ok: true, duplicate: true });
  assert.equal(db.webhookEventIds.size, 1);
  assert.equal(db.snapshotWrites, 1);
});

test("concurrent duplicate event id performs reconciliation once", async () => {
  // Before the fix the idempotency record was written AFTER reconciliation,
  // so two interleaved webhooks for the same event.id both passed the read
  // check and both drove RevenueCat + a snapshot write. Claiming first means
  // only the winning request performs the external work; the loser short-
  // circuits to { ok: true, duplicate: true }.
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const body = revenueCatPayload({
    id: "evt_concurrent",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const [a, b] = await Promise.all([
    postSignedWebhook(db, body),
    postSignedWebhook(db, body),
  ]);

  assert.equal(a.status, 200);
  assert.equal(b.status, 200);
  const bodies = await Promise.all([responseJson(a), responseJson(b)]);
  // Exactly one of the two responses is the duplicate short-circuit.
  const duplicates = bodies.filter((value) => value?.duplicate === true);
  assert.equal(duplicates.length, 1);
  assert.equal(db.webhookEventIds.size, 1);
  // Reconciliation (snapshot write) happened exactly once.
  assert.equal(db.snapshotWrites, 1);
});

test("older webhook event cannot overwrite a newer snapshot", async () => {
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const newer = revenueCatPayload({
    id: "evt_newer",
    eventTime: "2026-07-09T10:00:00.000Z",
  });
  const older = revenueCatPayload({
    id: "evt_older",
    eventTime: "2026-07-09T09:00:00.000Z",
    entitlementIds: [],
    expirationMs: Date.parse("2026-07-08T00:00:00.000Z"),
  });

  await postSignedWebhook(db, newer);
  const response = await postSignedWebhook(db, older);

  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), { ok: true });
  assert.equal(db.snapshot.is_active, 1);
  assert.equal(db.snapshot.last_event_at, "2026-07-09T10:00:00.000Z");
  assert.equal(db.snapshotWrites, 2);
});

test("concurrent duplicate webhook submissions process one snapshot write", async () => {
  const db = new MembershipDb();
  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const body = revenueCatPayload({
    id: "evt_concurrent",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const [first, second] = await Promise.all([
    postSignedWebhook(db, body),
    postSignedWebhook(db, body),
  ]);

  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(db.webhookEventIds.size, 1);
  assert.equal(db.snapshotWrites, 1);
});

test("failed current-state lookup leaves the webhook retryable", async () => {
  const db = new MembershipDb();
  const body = revenueCatPayload({
    id: "evt_retry_after_failure",
    eventTime: "2026-07-09T09:00:00.000Z",
  });
  revenueCatStatus = 503;

  const failed = await postSignedWebhook(db, body);

  assert.equal(failed.status, 503);
  assert.equal(db.webhookEventIds.size, 0);
  assert.equal(db.snapshotWrites, 0);

  revenueCatStatus = 200;
  revenueCatEntitlement = {
    expires_date: "2099-01-01T00:00:00.000Z",
  };
  const retried = await postSignedWebhook(db, body);
  assert.equal(retried.status, 200);
  assert.equal(db.webhookEventIds.size, 1);
  assert.equal(db.snapshot.is_active, 1);
});

test("/auth/google rejects a missing id token", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/auth/google", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    }),
    env(new MembershipDb()),
  );

  assert.equal(response.status, 400);
});

test("/auth/google rejects an invalid id token", async () => {
  const response = await worker.fetch(
    new Request("https://worker.test/auth/google", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken: "not-a-jwt" }),
    }),
    env(new MembershipDb()),
  );

  assert.equal(response.status, 401);
});
