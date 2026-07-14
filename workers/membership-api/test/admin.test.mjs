import assert from "node:assert/strict";
import test from "node:test";

import { generateKeyPair, SignJWT } from "jose";

import {
  handleAvatarAdmin,
  verifyAccessJwt,
} from "../.tmp-test/admin.js";
import {
  createD1FromSchema,
  seedUser,
} from "./helpers/d1_sqlite.mjs";

const teamDomain = "https://unit-test.cloudflareaccess.com";
const audience = "unit-test-admin-aud";

class FakeR2Bucket {
  constructor() {
    this.objects = new Set();
  }

  async delete(key) {
    this.objects.delete(key);
  }
}

async function setup() {
  const DB = await createD1FromSchema();
  await seedUser(DB, "reported", {
    displayName: "Reported",
    avatarUrl: "https://example.com/google.png",
  });
  return {
    DB,
    AVATAR_BUCKET: new FakeR2Bucket(),
    GOOGLE_CLIENT_ID: "unit-test-google-client-id",
    REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
    SESSION_SECRET: "unit-test-session-secret",
    ACCESS_TEAM_DOMAIN: teamDomain,
    ACCESS_AUD: audience,
  };
}

async function addCustomAvatar(env, objectId) {
  const key = `avatars/${objectId}.jpg`;
  await env.DB.prepare(
    "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, 'reported', ?, 'active', ?)",
  )
    .bind(objectId, key, new Date().toISOString())
    .run();
  await env.DB.prepare(
    "UPDATE users SET custom_avatar_object_id = ? WHERE id = 'reported'",
  )
    .bind(objectId)
    .run();
  env.AVATAR_BUCKET.objects.add(key);
}

async function addReport(env, id, { avatarObjectId = null, source = "google" } = {}) {
  await env.DB.prepare(
    "INSERT INTO avatar_reports (id, reporter_user_id, reported_user_id, report_type, avatar_object_id, avatar_source, reason, status, created_at) VALUES (?, 'reporter', 'reported', 'avatar', ?, ?, 'other', 'open', ?)",
  )
    .bind(id, avatarObjectId, source, new Date().toISOString())
    .run();
}

const allowAdmin = async () => "admin@example.com";

function adminRequest(path, { method = "GET", body, origin = "https://worker.test" } = {}) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      "cf-access-jwt-assertion": "unit-test-token",
      ...(origin === null ? {} : { origin }),
      ...(body === undefined
        ? {}
        : { "content-type": "application/x-www-form-urlencoded" }),
    },
    ...(body === undefined ? {} : { body: new URLSearchParams(body) }),
  });
}

async function action(env, reportId, actionName, origin) {
  return handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      body: { reportId, action: actionName },
      ...(origin === undefined ? {} : { origin }),
    }),
    env,
    allowAdmin,
  );
}

test("Access JWT validation checks signature, issuer, and audience", async () => {
  const { privateKey, publicKey } = await generateKeyPair("RS256");
  const token = await new SignJWT({ email: "admin@example.com" })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(teamDomain)
    .setAudience(audience)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);

  assert.equal(
    await verifyAccessJwt(token, teamDomain, audience, publicKey),
    "admin@example.com",
  );
  await assert.rejects(
    () => verifyAccessJwt(token, "https://wrong.example", audience, publicKey),
    /unexpected.*iss|issuer/i,
  );
  await assert.rejects(
    () => verifyAccessJwt(token, teamDomain, "wrong-aud", publicKey),
    /unexpected.*aud|audience/i,
  );
});

test("admin requests reject missing or invalid Access JWTs", async () => {
  const env = await setup();
  const missing = new Request("https://worker.test/admin/avatar-reports");
  assert.equal((await handleAvatarAdmin(missing, env, allowAdmin)).status, 403);

  const invalid = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports"),
    env,
    async () => {
      throw new Error("bad token");
    },
  );
  assert.equal(invalid.status, 403);
});

test("moderation queue escapes user-controlled content", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter", { displayName: "Reporter" });
  await env.DB.prepare(
    "UPDATE users SET display_name = ?, nickname = ? WHERE id = 'reported'",
  )
    .bind("A&B", "<script>alert(1)</script>")
    .run();
  await addReport(env, "report-html");

  const response = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports"),
    env,
    allowAdmin,
  );
  const html = await response.text();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /^text\/html/);
  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(html, /<script>alert\(1\)<\/script>/);
});

test("moderation actions accept only same-origin POST", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");
  await addReport(env, "report-origin");

  assert.equal((await action(env, "report-origin", "dismiss_report", null)).status, 403);
  assert.equal(
    (await action(env, "report-origin", "dismiss_report", "https://evil.example"))
      .status,
    403,
  );
  assert.equal(
    (
      await handleAvatarAdmin(
        adminRequest("/admin/avatar-reports/action"),
        env,
        allowAdmin,
      )
    ).status,
    405,
  );
});

test("moderation actions protect stale versions and audit dismiss, remove, hide, suspend, and restore", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");

  await addReport(env, "report-dismiss");
  assert.equal((await action(env, "report-dismiss", "dismiss_report")).status, 303);

  const oldId = "11111111-1111-4111-8111-111111111111";
  const newId = "22222222-2222-4222-8222-222222222222";
  await addCustomAvatar(env, oldId);
  await addReport(env, "report-stale", { avatarObjectId: oldId, source: "custom" });
  await env.DB.prepare(
    "UPDATE avatar_objects SET status = 'replaced' WHERE id = ?",
  )
    .bind(oldId)
    .run();
  await addCustomAvatar(env, newId);
  assert.equal((await action(env, "report-stale", "remove_custom_avatar")).status, 409);
  assert.equal(
    (
      await env.DB.prepare(
        "SELECT custom_avatar_object_id FROM users WHERE id = 'reported'",
      ).first()
    ).custom_avatar_object_id,
    newId,
  );
  assert.equal(
    (
      await env.DB.prepare(
        "SELECT status FROM avatar_reports WHERE id = 'report-stale'",
      ).first()
    ).status,
    "stale",
  );

  await addReport(env, "report-remove", { avatarObjectId: newId, source: "custom" });
  assert.equal((await action(env, "report-remove", "remove_custom_avatar")).status, 303);
  assert.equal(env.AVATAR_BUCKET.objects.has(`avatars/${newId}.jpg`), false);
  assert.equal(
    (
      await env.DB.prepare(
        "SELECT custom_avatar_object_id FROM users WHERE id = 'reported'",
      ).first()
    ).custom_avatar_object_id,
    null,
  );

  for (const actionName of [
    "hide_public_avatar",
    "restore_public_avatar",
    "suspend_upload",
    "restore_upload",
  ]) {
    assert.equal((await action(env, "report-dismiss", actionName)).status, 303);
  }
  const user = await env.DB.prepare(
    "SELECT public_avatar_hidden_at, avatar_upload_suspended_at FROM users WHERE id = 'reported'",
  ).first();
  assert.equal(user.public_avatar_hidden_at, null);
  assert.equal(user.avatar_upload_suspended_at, null);

  const audits = await env.DB.prepare(
    "SELECT action, result FROM avatar_moderation_actions ORDER BY created_at, rowid",
  ).all();
  assert.deepEqual(
    audits.results.map((row) => [row.action, row.result]),
    [
      ["dismiss_report", "applied"],
      ["remove_custom_avatar", "stale"],
      ["remove_custom_avatar", "applied"],
      ["hide_public_avatar", "applied"],
      ["restore_public_avatar", "applied"],
      ["suspend_upload", "applied"],
      ["restore_upload", "applied"],
    ],
  );
});
