import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import { hashToken } from "../.tmp-test/session.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

class ProfileDb {
  constructor(tokenHash, options = {}) {
    this.sessions = new Map([
      [
        tokenHash,
        {
          user_id: "user_1",
          app_user_id: "user_1",
          expires_at: "2099-01-01T00:00:00.000Z",
        },
      ],
    ]);
    this.users = new Map([
      [
        "user_1",
        {
          id: "user_1",
          display_name: "Google Name",
          email: "a@example.com",
          avatar_url: "https://example.com/google.png",
          nickname: null,
          nickname_key: null,
          avatar_key: null,
          nickname_updated_at: options.nicknameUpdatedAt ?? null,
        },
      ],
    ]);
    this.nicknameKeys = new Set(["taken"]);
    this.updateError = options.updateError ?? null;
    this.updatedUser = null;
  }

  prepare(sql) {
    return new ProfileStatement(this, sql);
  }
}

class ProfileStatement {
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
    if (this.sql.includes("FROM users WHERE nickname_key = ?")) {
      const key = this.args[0];
      return this.db.nicknameKeys.has(key) ? { id: "other_user" } : null;
    }
    if (this.sql.includes("SELECT nickname_updated_at FROM users")) {
      return this.db.users.get(this.args[0]);
    }
    return null;
  }

  async run() {
    if (this.sql.includes("UPDATE users SET nickname")) {
      if (this.db.updateError) {
        throw this.db.updateError;
      }
      this.db.updatedUser = {
        nickname: this.args[0],
        nickname_key: this.args[1],
        avatar_key: this.args[2],
        user_id: this.args[5],
      };
    }
    return { meta: { changes: 1 } };
  }
}

function env(db) {
  return { ...envBase, DB: db };
}

async function profileDb(options = {}) {
  return new ProfileDb(await hashToken(envBase, "valid-token"), options);
}

function authedRequest(body) {
  return authedRawRequest(JSON.stringify(body));
}

function authedRawRequest(body) {
  return new Request("https://worker.test/me/profile", {
    method: "PATCH",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer valid-token",
    },
    body,
  });
}

test("profile update saves normalized unique nickname and avatar key", async () => {
  const db = await profileDb();

  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 01", avatarKey: "ring-green" }),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.equal(db.updatedUser.nickname, "训练者 01");
  assert.equal(db.updatedUser.nickname_key, "训练者01");
  assert.equal(db.updatedUser.avatar_key, "ring-green");
});

test("profile update rejects duplicate nickname", async () => {
  const response = await worker.fetch(
    authedRequest({ nickname: "taken", avatarKey: "ring-green" }),
    env(await profileDb()),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "nickname_taken" });
});

test("profile update rejects unknown avatar key", async () => {
  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 02", avatarKey: "remote-url" }),
    env(await profileDb()),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_avatar_key" });
});

test("profile update rejects nickname changes within 30 days", async () => {
  const db = await profileDb({
    nicknameUpdatedAt: new Date(
      Date.now() - 29 * 24 * 60 * 60 * 1000,
    ).toISOString(),
  });

  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 03", avatarKey: "ring-green" }),
    env(db),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), {
    error: "nickname_change_too_soon",
  });
  assert.equal(db.updatedUser, null);
});

test("profile update maps update unique nickname conflicts to duplicate nickname", async () => {
  const response = await worker.fetch(
    authedRequest({ nickname: "race", avatarKey: "ring-green" }),
    env(
      await profileDb({
        updateError: new Error("UNIQUE constraint failed: users.nickname_key"),
      }),
    ),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "nickname_taken" });
});

test("profile update does not map schema nickname key errors to duplicate nickname", async () => {
  const db = await profileDb({
    updateError: new Error("no such column: nickname_key"),
  });

  await assert.rejects(
    () =>
      worker.fetch(
        authedRequest({ nickname: "race", avatarKey: "ring-green" }),
        env(db),
      ),
    /no such column: nickname_key/,
  );
});

test("profile update rejects invalid JSON", async () => {
  const response = await worker.fetch(
    authedRawRequest("{"),
    env(await profileDb()),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_json" });
});

test("profile update rejects null JSON body", async () => {
  const response = await worker.fetch(
    authedRawRequest("null"),
    env(await profileDb()),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_json" });
});
