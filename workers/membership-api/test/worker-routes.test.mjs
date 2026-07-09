import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hmacSha256Hex } from "../.tmp-test/webhook_auth.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

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
    if (this.sql.includes("INSERT INTO membership_snapshots")) {
      const lastEventAt = this.args[6];
      const canWrite =
        this.db.snapshot === null ||
        this.db.snapshot.last_event_at === null ||
        lastEventAt >= this.db.snapshot.last_event_at;
      if (!canWrite) {
        return { meta: { changes: 0 } };
      }
      this.db.snapshot = {
        user_id: this.args[0],
        entitlement: this.args[1],
        is_active: this.args[2],
        expires_at: this.args[3],
        source: this.args[4],
        revenuecat_app_user_id: this.args[5],
        last_event_at: lastEventAt,
        updated_at: this.args[7],
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
  const timestamp = "1783616400";
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

test("webhook accepts a good RevenueCat HMAC signature", async () => {
  const db = new MembershipDb();
  const body = revenueCatPayload({
    id: "evt_good_sig",
    eventTime: "2026-07-09T09:00:00.000Z",
  });

  const response = await postSignedWebhook(db, body);

  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), { ok: true });
  assert.equal(db.snapshot.is_active, 1);
  assert.equal(db.snapshot.last_event_at, "2026-07-09T09:00:00.000Z");
});

test("webhook duplicate event id is idempotent", async () => {
  const db = new MembershipDb();
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

test("older webhook event cannot overwrite a newer snapshot", async () => {
  const db = new MembershipDb();
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
  assert.deepEqual(await responseJson(response), {
    ok: true,
    ignored: "older_event",
  });
  assert.equal(db.snapshot.is_active, 1);
  assert.equal(db.snapshot.last_event_at, "2026-07-09T10:00:00.000Z");
  assert.equal(db.snapshotWrites, 1);
});

test("concurrent duplicate webhook submissions process one snapshot write", async () => {
  const db = new MembershipDb();
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
