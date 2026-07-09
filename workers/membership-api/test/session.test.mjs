import assert from "node:assert/strict";
import test from "node:test";

import { hashToken, requireSession } from "../.tmp-test/session.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

class SessionDb {
  constructor(rows = new Map()) {
    this.rows = rows;
    this.deletedHashes = [];
  }

  prepare(sql) {
    return new SessionStatement(this, sql);
  }
}

class SessionStatement {
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
      return this.db.rows.get(this.args[0]) ?? null;
    }
    return null;
  }

  async run() {
    if (this.sql.includes("DELETE FROM sessions WHERE token_hash = ?")) {
      this.db.deletedHashes.push(this.args[0]);
      this.db.rows.delete(this.args[0]);
    }
    return { meta: { changes: 1 } };
  }
}

function sessionRequest(token) {
  return new Request("https://worker.test/me", {
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

test("requireSession rejects a missing bearer token", async () => {
  const result = await requireSession(
    { ...envBase, DB: new SessionDb() },
    sessionRequest(null),
  );

  assert.equal(result instanceof Response, true);
  assert.equal(result.status, 401);
});

test("requireSession deletes an expired session row before rejecting it", async () => {
  const token = "expired-token";
  const tokenHash = await hashToken(envBase, token);
  const db = new SessionDb(
    new Map([
      [
        tokenHash,
        {
          user_id: "user_1",
          app_user_id: "user_1",
          expires_at: "2026-07-08T00:00:00.000Z",
        },
      ],
    ]),
  );

  const result = await requireSession(
    { ...envBase, DB: db },
    sessionRequest(token),
  );

  assert.equal(result instanceof Response, true);
  assert.equal(result.status, 401);
  assert.deepEqual(db.deletedHashes, [tokenHash]);
});

test("requireSession accepts an unexpired session row", async () => {
  const token = "valid-token";
  const tokenHash = await hashToken(envBase, token);
  const db = new SessionDb(
    new Map([
      [
        tokenHash,
        {
          user_id: "user_1",
          app_user_id: "user_1",
          expires_at: "2099-01-01T00:00:00.000Z",
        },
      ],
    ]),
  );

  const result = await requireSession(
    { ...envBase, DB: db },
    sessionRequest(token),
  );

  assert.deepEqual(result, { userId: "user_1", appUserId: "user_1" });
  assert.deepEqual(db.deletedHashes, []);
});
