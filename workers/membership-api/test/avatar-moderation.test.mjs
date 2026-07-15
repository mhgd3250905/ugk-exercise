import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import * as avatar from "../.tmp-test/avatar.js";
import { hashToken } from "../.tmp-test/session.js";
import {
  createD1FromSchema,
  seedLeaderboardProfile,
  seedMembership,
  seedSession,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

class FakeR2Bucket {
  constructor() {
    this.objects = new Set();
  }

  async delete(key) {
    this.objects.delete(key);
  }
}

async function setup() {
  const db = await createD1FromSchema();
  await seedUser(db, "me", { nickname: "Me" });
  await seedMembership(db, "me");
  await seedLeaderboardProfile(db, "me", { identityMode: "profile" });
  await seedSession(db, await hashToken(envBase, "valid-token"), "me");
  return { ...envBase, DB: db, AVATAR_BUCKET: new FakeR2Bucket() };
}

async function addRankedUser(env, userId, options = {}) {
  await seedUser(env.DB, userId, {
    displayName: options.displayName ?? userId,
    nickname: options.nickname ?? null,
    avatarUrl: options.avatarUrl ?? null,
    avatarKey: options.avatarKey ?? null,
  });
  await seedMembership(env.DB, userId);
  await seedLeaderboardProfile(env.DB, userId, {
    identityMode: options.identityMode ?? "profile",
    anonymousAvatarKey: options.anonymousAvatarKey ?? "ring-yellow",
  });
  if (options.total !== undefined) {
    const now = new Date().toISOString();
    const rankingDate = new Date(Date.now() + 8 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    await env.DB.prepare(
      "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, 'pushup', ?, ?, ?, ?)",
    )
      .bind(userId, rankingDate, options.total, now, now)
      .run();
  }
  if (options.customAvatarId) {
    const objectKey = `avatars/${options.customAvatarId}.jpg`;
    await env.DB.prepare(
      "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, ?, ?, 'active', ?)",
    )
      .bind(options.customAvatarId, userId, objectKey, new Date().toISOString())
      .run();
    await env.DB.prepare(
      "UPDATE users SET custom_avatar_object_id = ? WHERE id = ?",
    )
      .bind(options.customAvatarId, userId)
      .run();
    env.AVATAR_BUCKET.objects.add(objectKey);
  }
  if (options.hidden) {
    await env.DB.prepare(
      "UPDATE users SET public_avatar_hidden_at = ? WHERE id = ?",
    )
      .bind(new Date().toISOString(), userId)
      .run();
  }
}

function authed(path, { method = "GET", body } = {}) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer valid-token",
      ...(body === undefined ? {} : { "content-type": "application/json" }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

test("leaderboard resolves custom, built-in, Google, default, hidden, and anonymous avatars", async () => {
  const env = await setup();
  await addRankedUser(env, "custom", {
    nickname: "Custom",
    customAvatarId: "11111111-1111-4111-8111-111111111111",
    total: 60,
  });
  await addRankedUser(env, "built-in", {
    nickname: "Built in",
    avatarKey: "ring-lime",
    total: 50,
  });
  await addRankedUser(env, "google", {
    displayName: "Google",
    avatarUrl: "https://example.com/google.png",
    total: 40,
  });
  await addRankedUser(env, "default", { total: 30 });
  await addRankedUser(env, "hidden", {
    avatarUrl: "https://example.com/hidden.png",
    hidden: true,
    total: 20,
  });
  await addRankedUser(env, "anonymous", {
    identityMode: "anonymous",
    anonymousAvatarKey: "ring-coral",
    total: 10,
  });

  const response = await worker.fetch(
    authed("/leaderboard?period=day&exerciseType=pushup"),
    env,
  );
  const rows = new Map((await response.json()).top.map((row) => [row.userId, row]));
  assert.equal(
    rows.get("custom").avatarUrl,
    "https://worker.test/avatars/11111111-1111-4111-8111-111111111111.jpg",
  );
  assert.equal(rows.get("custom").avatarKey, null);
  assert.equal(rows.get("built-in").avatarKey, "ring-lime");
  assert.equal(rows.get("google").avatarUrl, "https://example.com/google.png");
  assert.equal(rows.get("default").avatarKey, "ring-green");
  assert.equal(rows.get("hidden").avatarKey, "ring-green");
  assert.equal(rows.get("hidden").avatarUrl, null);
  assert.equal(rows.get("anonymous").avatarKey, "ring-coral");
});

test("report is idempotent, blocks the target, and preserves global ranks", async () => {
  const env = await setup();
  await addRankedUser(env, "reported", {
    nickname: "Reported",
    customAvatarId: "22222222-2222-4222-8222-222222222222",
    total: 100,
  });
  await addRankedUser(env, "visible", {
    nickname: "Visible",
    avatarKey: "ring-lime",
    total: 90,
  });
  const body = { reportType: "avatar", reason: "nudity" };
  for (let index = 0; index < 2; index += 1) {
    const response = await worker.fetch(
      authed("/leaderboard/users/reported/report", {
        method: "POST",
        body,
      }),
      env,
    );
    assert.equal(response.status, 200);
  }
  const count = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM avatar_reports WHERE reporter_user_id = 'me' AND reported_user_id = 'reported'",
  ).first();
  assert.equal(count.count, 1);
  const blocks = await worker.fetch(authed("/me/blocks"), env);
  assert.deepEqual(
    (await blocks.json()).blocks.map((block) => block.userId),
    ["reported"],
  );

  const board = await worker.fetch(
    authed("/leaderboard?period=day&exerciseType=pushup"),
    env,
  );
  const rows = (await board.json()).top;
  assert.equal(rows.some((row) => row.userId === "reported"), false);
  assert.equal(rows.find((row) => row.userId === "visible").rank, 2);
});

test("report rejects self, invalid reasons, and avatar reports without public UGC", async () => {
  const env = await setup();
  await addRankedUser(env, "built-in", { avatarKey: "ring-green" });
  const cases = [
    ["me", { reportType: "user", reason: "spam" }, 400, "cannot_report_self"],
    ["built-in", { reportType: "user", reason: "unknown" }, 400, "invalid_report"],
    ["built-in", { reportType: "avatar", reason: "other" }, 400, "invalid_report_target"],
  ];
  for (const [userId, body, status, error] of cases) {
    const response = await worker.fetch(
      authed(`/leaderboard/users/${userId}/report`, { method: "POST", body }),
      env,
    );
    assert.equal(response.status, status);
    assert.deepEqual(await response.json(), { error });
  }
});

test("block and unblock are idempotent", async () => {
  const env = await setup();
  await addRankedUser(env, "target");
  for (let index = 0; index < 2; index += 1) {
    assert.equal(
      (
        await worker.fetch(
          authed("/me/blocks/target", { method: "PUT" }),
          env,
        )
      ).status,
      200,
    );
  }
  assert.equal(
    (
      await env.DB.prepare(
        "SELECT COUNT(*) AS count FROM user_blocks WHERE blocker_user_id = 'me'",
      ).first()
    ).count,
    1,
  );
  for (let index = 0; index < 2; index += 1) {
    assert.equal(
      (
        await worker.fetch(
          authed("/me/blocks/target", { method: "DELETE" }),
          env,
        )
      ).status,
      200,
    );
  }
});

test("blocked users list keeps anonymous identities private and reflects unblock", async () => {
  const env = await setup();
  await addRankedUser(env, "profile-target", {
    nickname: "Visible profile",
    avatarKey: "ring-lime",
  });
  await addRankedUser(env, "anonymous-target", {
    displayName: "Private account name",
    nickname: "Private nickname",
    identityMode: "anonymous",
    anonymousAvatarKey: "ring-coral",
  });
  await addRankedUser(env, "left-target", {
    nickname: "No longer public",
    avatarKey: "ring-yellow",
  });
  for (const userId of [
    "profile-target",
    "anonymous-target",
    "left-target",
  ]) {
    const response = await worker.fetch(
      authed(`/me/blocks/${userId}`, { method: "PUT" }),
      env,
    );
    assert.equal(response.status, 200);
  }
  await env.DB.prepare(
    "UPDATE leaderboard_profiles SET is_joined = 0 WHERE user_id = 'left-target'",
  ).run();

  const response = await worker.fetch(authed("/me/blocks"), env);
  assert.equal(response.status, 200);
  const blocks = new Map(
    (await response.json()).blocks.map((block) => [block.userId, block]),
  );
  assert.deepEqual(blocks.get("profile-target"), {
    userId: "profile-target",
    nickname: "Visible profile",
    avatarKey: "ring-lime",
    avatarUrl: null,
  });
  assert.deepEqual(blocks.get("anonymous-target"), {
    userId: "anonymous-target",
    nickname: null,
    avatarKey: "ring-coral",
    avatarUrl: null,
  });
  assert.deepEqual(blocks.get("left-target"), {
    userId: "left-target",
    nickname: null,
    avatarKey: "ring-yellow",
    avatarUrl: null,
  });

  await worker.fetch(
    authed("/me/blocks/profile-target", { method: "DELETE" }),
    env,
  );
  const afterUnblock = await worker.fetch(authed("/me/blocks"), env);
  assert.deepEqual(
    (await afterUnblock.json()).blocks.map((block) => block.userId),
    ["left-target", "anonymous-target"],
  );
});

test("account deletion cleanup removes every R2 avatar and clears public state", async () => {
  const env = await setup();
  const ids = [
    "33333333-3333-4333-8333-333333333333",
    "44444444-4444-4444-8444-444444444444",
  ];
  for (const [index, id] of ids.entries()) {
    const key = `avatars/${id}.jpg`;
    await env.DB.prepare(
      "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, 'me', ?, ?, ?)",
    )
      .bind(id, key, index === 0 ? "active" : "replaced", new Date().toISOString())
      .run();
    env.AVATAR_BUCKET.objects.add(key);
  }
  await env.DB.prepare(
    "UPDATE users SET custom_avatar_object_id = ? WHERE id = 'me'",
  )
    .bind(ids[0])
    .run();

  await avatar.deleteAllAvatarObjects(env, "me");

  assert.equal(env.AVATAR_BUCKET.objects.size, 0);
  const user = await env.DB.prepare(
    "SELECT custom_avatar_object_id FROM users WHERE id = 'me'",
  ).first();
  assert.equal(user.custom_avatar_object_id, null);
  const remaining = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM avatar_objects WHERE user_id = 'me' AND deleted_at IS NULL",
  ).first();
  assert.equal(remaining.count, 0);
});
