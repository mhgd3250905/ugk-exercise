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
          nickname: options.nickname ?? null,
          nickname_key: options.nicknameKey ?? null,
          avatar_key: options.avatarKey ?? null,
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
    if (
      this.sql.includes("FROM users LEFT JOIN avatar_objects")
    ) {
      const user = this.db.users.get(this.args.at(-1));
      return user
        ? {
            ...user,
            avatar_upload_suspended_at: null,
            custom_avatar_id: null,
            custom_avatar_status: null,
            avatar_policy_accepted: 0,
          }
        : null;
    }
    if (this.sql.includes("nickname_updated_at FROM users")) {
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
        nickname_updated_at: this.sql.includes("nickname_updated_at = ?")
          ? this.args[3]
          : this.db.users.get(this.args.at(-1)).nickname_updated_at,
        user_id: this.args.at(-1),
      };
      Object.assign(this.db.users.get(this.args.at(-1)), {
        nickname: this.args[0],
        nickname_key: this.args[1],
        avatar_key: this.args[2],
      });
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
  assert.deepEqual(await response.json(), {
    user: {
      id: "user_1",
      displayName: "Google Name",
      email: "a@example.com",
      avatarUrl: "https://example.com/google.png",
      nickname: "训练者 01",
      avatarKey: "ring-green",
      customAvatarUrl: null,
      avatarPolicyVersion: "2026-07-14",
      avatarPolicyAccepted: false,
      avatarUploadSuspended: false,
    },
  });
});

test("/me restores saved nickname and avatar key", async () => {
  const db = await profileDb({
    nickname: "训练者 01",
    nicknameKey: "训练者01",
    avatarKey: "ring-green",
  });

  const response = await worker.fetch(
    new Request("https://worker.test/me", {
      headers: { authorization: "Bearer valid-token" },
    }),
    env(db),
  );

  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.user.nickname, "训练者 01");
  assert.equal(payload.user.avatarKey, "ring-green");
});

test("profile update accepts only letters numbers CJK spaces underscores and hyphens", async () => {
  const valid = await worker.fetch(
    authedRequest({ nickname: "A_中-9", avatarKey: "ring-green" }),
    env(await profileDb()),
  );
  assert.equal(valid.status, 200);

  for (const nickname of [
    "admin",
    "Administrator",
    "official",
    "system",
    "support",
    "UGK",
    "a-d-m-i-n",
    "u_g_k",
    "--",
    "__",
    "训练者!",
    "a\nb",
  ]) {
    const response = await worker.fetch(
      authedRequest({ nickname, avatarKey: "ring-green" }),
      env(await profileDb()),
    );
    assert.equal(response.status, 400, nickname);
    assert.deepEqual(await response.json(), { error: "invalid_nickname" });
  }
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

test("profile update allows avatar-only changes during nickname cooldown", async () => {
  const nicknameUpdatedAt = new Date(
    Date.now() - 1 * 24 * 60 * 60 * 1000,
  ).toISOString();
  const db = await profileDb({
    nickname: "训练者 01",
    nicknameKey: "训练者01",
    avatarKey: "ring-green",
    nicknameUpdatedAt,
  });

  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 01", avatarKey: "ring-lime" }),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.equal(db.updatedUser.avatar_key, "ring-lime");
  assert.equal(db.updatedUser.nickname_updated_at, nicknameUpdatedAt);
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
