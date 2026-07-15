import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";
import {
  parseJpegDimensions,
  readAvatarBytes,
} from "../.tmp-test/avatar.js";
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
  SESSION_SECRET: "unit-test-session-secret",
};

class FakeR2Bucket {
  constructor() {
    this.objects = new Map();
    this.failPut = false;
    this.failDeleteKeys = new Set();
  }

  async put(key, value) {
    if (this.failPut) throw new Error("R2 put failed");
    const bytes = new Uint8Array(value);
    this.objects.set(key, bytes);
    return { key, httpEtag: `\"${bytes.byteLength}\"` };
  }

  async get(key) {
    const bytes = this.objects.get(key);
    if (!bytes) return null;
    return {
      key,
      body: bytes,
      httpEtag: `\"${bytes.byteLength}\"`,
      writeHttpMetadata(headers) {
        headers.set("content-type", "image/jpeg");
      },
    };
  }

  async delete(key) {
    if (this.failDeleteKeys.has(key)) throw new Error("R2 delete failed");
    this.objects.delete(key);
  }
}

function jpeg(width = 512, height = 512) {
  return Uint8Array.from([
    0xff,
    0xd8,
    0xff,
    0xc0,
    0x00,
    0x11,
    0x08,
    (height >> 8) & 0xff,
    height & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    0x03,
    0x01,
    0x11,
    0x00,
    0x02,
    0x11,
    0x00,
    0x03,
    0x11,
    0x00,
    0xff,
    0xd9,
  ]);
}

async function avatarEnv({ suspended = false } = {}) {
  const db = await createD1FromSchema();
  await seedUser(db, "me");
  await seedMembership(db, "me");
  const tokenHash = await hashToken(envBase, "valid-token");
  await seedSession(db, tokenHash, "me");
  if (suspended) {
    await db
      .prepare("UPDATE users SET avatar_upload_suspended_at = ? WHERE id = ?")
      .bind("2026-07-14T00:00:00.000Z", "me")
      .run();
  }
  return { ...envBase, DB: db, AVATAR_BUCKET: new FakeR2Bucket() };
}

function request(path, { method = "GET", body, contentType } = {}) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      authorization: "Bearer valid-token",
      ...(contentType ? { "content-type": contentType } : {}),
    },
    ...(body === undefined ? {} : { body }),
  });
}

async function acceptPolicy(env) {
  const response = await worker.fetch(
    request("/me/avatar-policy/accept", {
      method: "POST",
      contentType: "application/json",
      body: JSON.stringify({ policyVersion: "2026-07-14" }),
    }),
    env,
  );
  assert.equal(response.status, 200);
}

test("JPEG parser returns SOF dimensions and rejects truncated data", () => {
  assert.deepEqual(parseJpegDimensions(jpeg(320, 320)), {
    width: 320,
    height: 320,
  });
  assert.equal(parseJpegDimensions(jpeg().slice(0, -1)), null);
  assert.equal(parseJpegDimensions(Uint8Array.from([0x89, 0x50])), null);
});

test("bounded reader counts streamed bytes instead of trusting length", async () => {
  const response = new Request("https://worker.test/me/avatar", {
    method: "PUT",
    body: new Uint8Array(9),
  });
  const withinLimit = response.clone();
  await assert.rejects(() => readAvatarBytes(response, 8), /avatar_too_large/);
  assert.equal((await readAvatarBytes(withinLimit, 9)).byteLength, 9);
});

test("avatar upload requires the current policy acceptance", async () => {
  const env = await avatarEnv();
  const response = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    env,
  );
  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "avatar_policy_required" });
});

test("policy acceptance rejects an unknown version", async () => {
  const env = await avatarEnv();
  const response = await worker.fetch(
    request("/me/avatar-policy/accept", {
      method: "POST",
      contentType: "application/json",
      body: JSON.stringify({ policyVersion: "old" }),
    }),
    env,
  );
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_policy_version" });
});

test("upload validates JPEG type, size, and square dimensions", async () => {
  const env = await avatarEnv();
  await acceptPolicy(env);
  const cases = [
    ["image/png", jpeg(), "invalid_avatar_format"],
    ["image/jpeg", jpeg(512, 400), "invalid_avatar_dimensions"],
    ["image/jpeg", jpeg(513, 513), "invalid_avatar_dimensions"],
    ["image/jpeg", Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]), "invalid_avatar_format"],
  ];
  for (const [contentType, body, error] of cases) {
    const response = await worker.fetch(
      request("/me/avatar", { method: "PUT", contentType, body }),
      env,
    );
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error });
  }
});

test("upload, public read, replacement, and delete use versioned objects", async () => {
  const env = await avatarEnv();
  await acceptPolicy(env);
  const first = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    env,
  );
  assert.equal(first.status, 200);
  const firstUrl = (await first.json()).user.customAvatarUrl;
  assert.match(firstUrl, /^https:\/\/worker\.test\/avatars\/[a-f0-9-]+\.jpg$/);
  const firstRead = await worker.fetch(new Request(firstUrl), env);
  assert.equal(firstRead.status, 200);
  assert.equal(firstRead.headers.get("content-type"), "image/jpeg");
  assert.equal(firstRead.headers.get("x-content-type-options"), "nosniff");
  assert.ok(firstRead.headers.get("etag"));

  const second = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(400, 400),
    }),
    env,
  );
  const secondUrl = (await second.json()).user.customAvatarUrl;
  assert.notEqual(secondUrl, firstUrl);
  assert.equal((await worker.fetch(new Request(firstUrl), env)).status, 404);
  assert.equal((await worker.fetch(new Request(secondUrl), env)).status, 200);

  const removed = await worker.fetch(
    request("/me/avatar", { method: "DELETE" }),
    env,
  );
  assert.equal(removed.status, 200);
  assert.equal((await removed.json()).user.customAvatarUrl, null);
  assert.equal((await worker.fetch(new Request(secondUrl), env)).status, 404);
  const repeated = await worker.fetch(
    request("/me/avatar", { method: "DELETE" }),
    env,
  );
  assert.equal(repeated.status, 200);
});

test("suspended account and R2 put failures preserve the current avatar", async () => {
  const suspended = await avatarEnv({ suspended: true });
  await acceptPolicy(suspended);
  const denied = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    suspended,
  );
  assert.equal(denied.status, 403);
  assert.deepEqual(await denied.json(), { error: "avatar_upload_suspended" });

  const failing = await avatarEnv();
  await acceptPolicy(failing);
  failing.AVATAR_BUCKET.failPut = true;
  const failed = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    failing,
  );
  assert.equal(failed.status, 503);
  assert.deepEqual(await failed.json(), { error: "avatar_upload_failed" });
});

test("failed old-object deletion remains traceable but not publicly readable", async () => {
  const env = await avatarEnv();
  await acceptPolicy(env);
  const first = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    env,
  );
  const firstUrl = (await first.json()).user.customAvatarUrl;
  const firstId = firstUrl.match(/\/avatars\/([a-f0-9-]+)\.jpg$/)[1];
  const firstKey = `avatars/${firstId}.jpg`;
  env.AVATAR_BUCKET.failDeleteKeys.add(firstKey);

  const replacement = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(400, 400),
    }),
    env,
  );
  assert.equal(replacement.status, 200);
  const row = await env.DB.prepare(
    "SELECT status, deleted_at FROM avatar_objects WHERE id = ?",
  )
    .bind(firstId)
    .first();
  assert.deepEqual({ ...row }, { status: "replaced", deleted_at: null });
  assert.equal(env.AVATAR_BUCKET.objects.has(firstKey), true);
  assert.equal((await worker.fetch(new Request(firstUrl), env)).status, 404);
});

test("D1 failure compensates the new R2 object", async () => {
  const env = await avatarEnv();
  await acceptPolicy(env);
  const realDb = env.DB;
  env.DB = {
    prepare: (...args) => realDb.prepare(...args),
    batch: async () => {
      throw new Error("D1 batch failed");
    },
  };
  const response = await worker.fetch(
    request("/me/avatar", {
      method: "PUT",
      contentType: "image/jpeg",
      body: jpeg(),
    }),
    env,
  );
  assert.equal(response.status, 503);
  assert.equal(env.AVATAR_BUCKET.objects.size, 0);
});

test("/me exposes avatar policy and upload state", async () => {
  const env = await avatarEnv();
  const before = await worker.fetch(request("/me"), env);
  const beforeUser = (await before.json()).user;
  assert.equal(beforeUser.customAvatarUrl, null);
  assert.equal(beforeUser.avatarPolicyVersion, "2026-07-14");
  assert.equal(beforeUser.avatarPolicyAccepted, false);
  assert.equal(beforeUser.avatarUploadSuspended, false);

  await acceptPolicy(env);
  const after = await worker.fetch(request("/me"), env);
  assert.equal((await after.json()).user.avatarPolicyAccepted, true);
});
