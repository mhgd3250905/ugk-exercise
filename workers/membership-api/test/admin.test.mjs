import assert from "node:assert/strict";
import test from "node:test";

import { generateKeyPair, SignJWT } from "jose";

import {
  handleAvatarAdmin,
  verifyAccessJwt,
} from "../.tmp-test/admin.js";
import worker from "../.tmp-test/index.js";
import {
  createD1FromSchema,
  seedMembership,
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
    REVENUECAT_SECRET_API_KEY: "unit-test-revenuecat-secret-api-key",
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

function adminRequest(
  path,
  {
    method = "GET",
    body,
    origin = "https://worker.test",
    includeOrigin = true,
  } = {},
) {
  return new Request(`https://worker.test${path}`, {
    method,
    headers: {
      "cf-access-jwt-assertion": "unit-test-token",
      // `origin === null` exercises the opaque-origin compatibility path.
      // It is accepted only when Access identifies the actor and CSRF is bound to it.
      ...(includeOrigin
        ? origin === null
          ? { origin: "null" }
          : { origin }
        : {}),
      ...(body === undefined
        ? {}
        : { "content-type": "application/x-www-form-urlencoded" }),
    },
    ...(body === undefined ? {} : { body: new URLSearchParams(body) }),
  });
}

async function csrfTokenFor(
  env,
  { path = "/admin/members", verify = allowAdmin } = {},
) {
  const response = await handleAvatarAdmin(adminRequest(path), env, verify);
  assert.equal(response.status, 200);
  const html = await response.text();
  const match = html.match(
    /<input type="hidden" name="csrfToken" value="([0-9a-f]{64})">/,
  );
  assert.ok(match, `missing CSRF token in ${path}`);
  return match[1];
}

function postForms(html) {
  return [...html.matchAll(/<form method="post"[\s\S]*?<\/form>/g)].map(
    (match) => match[0],
  );
}

function assertAdminHtmlSecurity(response) {
  assert.match(response.headers.get("content-type"), /^text\/html/);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(
    response.headers.get("content-security-policy"),
    "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  );
  assert.equal(response.headers.get("referrer-policy"), "no-referrer");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
}

async function action(env, reportId, actionName, origin) {
  const csrfToken = await csrfTokenFor(env);
  return handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      body: { reportId, action: actionName, csrfToken },
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
  const warnings = [];
  const originalWarn = console.warn;
  console.warn = (...args) => warnings.push(args);
  try {
    const missing = new Request("https://worker.test/admin/avatar-reports");
    assert.equal((await handleAvatarAdmin(missing, env, allowAdmin)).status, 403);

    const invalid = await handleAvatarAdmin(
      adminRequest("/admin/avatar-reports"),
      env,
      async () => {
        const error = new Error("sensitive validation details");
        error.code = "ERR_JWT_CLAIM_VALIDATION_FAILED";
        throw error;
      },
    );
    assert.equal(invalid.status, 403);
  } finally {
    console.warn = originalWarn;
  }

  assert.deepEqual(warnings, [
    ["UGK_ADMIN_ACCESS_DENIED", { reason: "missing_assertion" }],
    [
      "UGK_ADMIN_ACCESS_DENIED",
      { reason: "ERR_JWT_CLAIM_VALIDATION_FAILED" },
    ],
  ]);
});

test("worker routes the membership admin through Access protection", async () => {
  const env = await setup();
  const response = await worker.fetch(
    new Request("https://worker.test/admin/members"),
    env,
  );
  assert.equal(response.status, 403);
});

test("admin root redirects authenticated operators to the member dashboard", async () => {
  const env = await setup();
  const response = await handleAvatarAdmin(
    adminRequest("/admin"),
    env,
    allowAdmin,
  );

  assert.equal(response.status, 303);
  assert.equal(response.headers.get("location"), "/admin/members");
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
  assertAdminHtmlSecurity(response);
  assert.match(html, /href="\/admin\/members"/);
  assert.match(html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(html, /<script>alert\(1\)<\/script>/);
});

test("admin GET pages render a CSRF token in every POST form", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter", { displayName: "Reporter" });
  await addReport(env, "report-csrf-form");
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: "premium:monthly",
  });

  const memberships = await handleAvatarAdmin(
    adminRequest("/admin/members?member=reported"),
    env,
    allowAdmin,
  );
  const membershipHtml = await memberships.text();
  const membershipForms = postForms(membershipHtml);
  assert.equal(membershipForms.length, 2);

  const reports = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports"),
    env,
    allowAdmin,
  );
  const reportHtml = await reports.text();
  const reportForms = postForms(reportHtml);
  assert.ok(reportForms.length > 0);

  const tokens = [];
  for (const form of [...membershipForms, ...reportForms]) {
    const match = form.match(
      /<input type="hidden" name="csrfToken" value="([0-9a-f]{64})">/,
    );
    assert.ok(match, `POST form is missing CSRF token: ${form}`);
    tokens.push(match[1]);
  }
  assert.equal(new Set(tokens).size, 1);
});

test("membership admin lists protected member status and escapes account content", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    isActive: 1,
    expiresAt: "2026-08-15T00:00:00.000Z",
    verifiedAt: "2026-07-21T12:00:00.000Z",
  });
  await env.DB.prepare(
    "UPDATE users SET display_name = ?, email = ? WHERE id = 'reported'",
  )
    .bind("<script>owner</script>", "member@example.com")
    .run();

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members"),
    env,
    allowAdmin,
  );
  const html = await response.text();

  assert.equal(response.status, 200);
  assertAdminHtmlSecurity(response);
  assert.match(html, /会员管理/);
  assert.match(html, /data-stat="unidentified"[^>]*>1</);
  assert.match(html, /补齐最多 10 条待识别会员/);
  assert.match(html, /member@example\.com/);
  assert.match(html, /2026-08-15/);
  assert.match(html, /&lt;script&gt;owner&lt;\/script&gt;/);
  assert.doesNotMatch(html, /<script>owner<\/script>/);
});

test("membership admin summarizes buyers and applies status, plan, and search filters", async () => {
  const env = await setup();
  await seedUser(env.DB, "annual-expired", {
    displayName: "Annual Former",
    email: "annual@example.com",
  });
  await seedUser(env.DB, "never-member", {
    displayName: "Free User",
    email: "free@example.com",
  });
  await seedMembership(env.DB, "reported", {
    isActive: 1,
    expiresAt: "2099-08-15T00:00:00.000Z",
    hasEntitlement: 1,
    productIdentifier: "premium:monthly",
    periodType: "trial",
    store: "play_store",
    isSandbox: false,
  });
  await seedMembership(env.DB, "annual-expired", {
    isActive: 0,
    expiresAt: "2026-07-01T00:00:00.000Z",
    hasEntitlement: 1,
    productIdentifier: "premium:annual",
    periodType: "normal",
    store: "play_store",
    isSandbox: true,
  });
  await seedMembership(env.DB, "never-member", {
    isActive: 0,
    expiresAt: null,
    hasEntitlement: 0,
  });

  const response = await handleAvatarAdmin(
    adminRequest(
      "/admin/members?status=active&plan=monthly&q=reported%40example.com",
    ),
    env,
    allowAdmin,
  );
  const html = await response.text();

  assert.equal(response.status, 200);
  assert.match(html, /data-stat="members"[^>]*>2</);
  assert.match(html, /data-stat="active"[^>]*>1</);
  assert.match(html, /reported@example\.com/);
  assert.match(html, /月卡/);
  assert.match(html, /试用/);
  assert.doesNotMatch(html, /annual@example\.com/);
  assert.doesNotMatch(html, /free@example\.com/);
});

test("membership admin reconciliation requires same-origin POST and writes an audit record", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: null,
  });
  let reconciliations = 0;
  const reconcile = async (_env, userId) => {
    reconciliations += 1;
    assert.equal(userId, "reported");
  };
  const csrfToken = await csrfTokenFor(env);

  const forbidden = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile", userId: "reported", csrfToken },
      origin: "https://evil.example",
    }),
    env,
    allowAdmin,
    reconcile,
  );
  assert.equal(forbidden.status, 403);
  assert.equal(reconciliations, 0);

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    env,
    allowAdmin,
    reconcile,
  );
  assert.equal(response.status, 303);
  assert.equal(reconciliations, 1);
  const audit = await env.DB.prepare(
    "SELECT actor_subject, target_user_id, action, result FROM membership_admin_actions",
  ).first();
  assert.deepEqual({ ...audit }, {
    actor_subject: "admin@example.com",
    target_user_id: "reported",
    action: "reconcile",
    result: "applied",
  });
});

test("membership admin backfills at most ten unidentified buyers and audits each attempt", async () => {
  const env = await setup();
  const reconciled = [];
  for (let index = 0; index < 12; index += 1) {
    const id = `missing-${String(index).padStart(2, "0")}`;
    await seedUser(env.DB, id, { email: `${id}@example.com` });
    await seedMembership(env.DB, id, {
      hasEntitlement: 1,
      productIdentifier: null,
    });
  }
  await seedUser(env.DB, "known", { email: "known@example.com" });
  await seedMembership(env.DB, "known", {
    hasEntitlement: 1,
    productIdentifier: "premium:annual",
  });
  const csrfToken = await csrfTokenFor(env);

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile_missing", csrfToken },
    }),
    env,
    allowAdmin,
    async (_env, userId) => reconciled.push(userId),
  );

  assert.equal(response.status, 303);
  assert.equal(response.headers.get("location"), "/admin/members?backfilled=10&failed=0");
  assert.equal(reconciled.length, 10);
  assert.doesNotMatch(reconciled.join(","), /known/);
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM membership_admin_actions WHERE result = 'applied'",
  ).first();
  assert.equal(audit.count, 10);
});

test("membership admin records failed RevenueCat reconciliations without changing the member", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: null,
  });
  const csrfToken = await csrfTokenFor(env);

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    env,
    allowAdmin,
    async () => {
      throw new Error("RevenueCat unavailable");
    },
  );

  assert.equal(response.status, 503);
  const audit = await env.DB.prepare(
    "SELECT target_user_id, result FROM membership_admin_actions",
  ).first();
  assert.deepEqual({ ...audit }, {
    target_user_id: "reported",
    result: "failed",
  });
});

test("membership admin batch backfill continues after individual failures", async () => {
  const env = await setup();
  for (const id of ["batch-a", "batch-b"]) {
    await seedUser(env.DB, id, { email: `${id}@example.com` });
    await seedMembership(env.DB, id, {
      hasEntitlement: 1,
      productIdentifier: null,
    });
  }
  const csrfToken = await csrfTokenFor(env);

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile_missing", csrfToken },
    }),
    env,
    allowAdmin,
    async (_env, userId) => {
      if (userId === "batch-a") throw new Error("temporary failure");
    },
  );

  assert.equal(response.status, 303);
  assert.equal(response.headers.get("location"), "/admin/members?backfilled=1&failed=1");
  const audits = await env.DB.prepare(
    "SELECT result, COUNT(*) AS count FROM membership_admin_actions GROUP BY result ORDER BY result",
  ).all();
  assert.deepEqual(audits.results.map((row) => ({ ...row })), [
    { result: "applied", count: 1 },
    { result: "failed", count: 1 },
  ]);
});

test("membership admin shows an operational detail view without raw webhook payloads", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    isActive: 1,
    expiresAt: "2026-08-15T00:00:00.000Z",
    hasEntitlement: 1,
    productIdentifier: "premium:monthly",
    purchaseAt: "2026-07-21T12:00:00.000Z",
    originalPurchaseAt: "2026-07-18T12:00:00.000Z",
    periodType: "normal",
    store: "play_store",
    isSandbox: false,
    ownershipType: "PURCHASED",
    unsubscribeDetectedAt: "2026-07-22T12:00:00.000Z",
  });

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members?member=reported"),
    env,
    allowAdmin,
  );
  const html = await response.text();

  assert.equal(response.status, 200);
  assert.match(html, /会员详情/);
  assert.match(html, /premium:monthly/);
  assert.match(html, /首次购买/);
  assert.match(html, /2026-07-18/);
  assert.match(html, /已取消续费/);
  assert.match(html, /action="\/admin\/members\/action"/);
  assert.doesNotMatch(html, /payload_json/);
});

test("membership admin filters environment, sorts purchases, and paginates", async () => {
  const env = await setup();
  for (const [id, email, isSandbox, purchaseAt] of [
    ["prod-old", "prod-old@example.com", false, "2026-07-01T00:00:00.000Z"],
    ["prod-new", "prod-new@example.com", false, "2026-07-20T00:00:00.000Z"],
    ["sandbox", "sandbox@example.com", true, "2026-07-21T00:00:00.000Z"],
  ]) {
    await seedUser(env.DB, id, { displayName: id, email });
    await seedMembership(env.DB, id, {
      expiresAt: "2099-01-01T00:00:00.000Z",
      hasEntitlement: 1,
      productIdentifier: "premium:monthly",
      purchaseAt,
      isSandbox,
    });
  }

  const sandboxResponse = await handleAvatarAdmin(
    adminRequest("/admin/members?environment=sandbox"),
    env,
    allowAdmin,
  );
  const sandboxHtml = await sandboxResponse.text();
  assert.match(sandboxHtml, /sandbox@example\.com/);
  assert.doesNotMatch(sandboxHtml, /prod-old@example\.com/);

  const sortedResponse = await handleAvatarAdmin(
    adminRequest("/admin/members?environment=production&sort=purchase_desc"),
    env,
    allowAdmin,
  );
  const sortedHtml = await sortedResponse.text();
  assert.ok(
    sortedHtml.indexOf("prod-new@example.com") <
      sortedHtml.indexOf("prod-old@example.com"),
  );
  assert.doesNotMatch(sortedHtml, /sandbox@example\.com/);

  const pagedEnv = await setup();
  for (let index = 0; index < 27; index += 1) {
    const id = `buyer-${String(index).padStart(2, "0")}`;
    await seedUser(pagedEnv.DB, id, { email: `${id}@example.com` });
    await seedMembership(pagedEnv.DB, id, {
      expiresAt: new Date(Date.UTC(2099, 0, index + 1)).toISOString(),
      hasEntitlement: 1,
    });
  }
  const pageResponse = await handleAvatarAdmin(
    adminRequest("/admin/members?page=2"),
    pagedEnv,
    allowAdmin,
  );
  const pageHtml = await pageResponse.text();
  assert.match(pageHtml, /buyer-25@example\.com/);
  assert.match(pageHtml, /buyer-26@example\.com/);
  assert.doesNotMatch(pageHtml, /buyer-00@example\.com/);
  assert.match(pageHtml, /第 2 \/ 2 页/);
});

test("CSRF token preserves null-origin membership POST for the same Access actor", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: "premium:monthly",
  });
  const csrfToken = await csrfTokenFor(env);
  let reconciliations = 0;
  const reconcile = async () => {
    reconciliations += 1;
  };

  const valid = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    env,
    allowAdmin,
    reconcile,
  );
  assert.equal(valid.status, 303);
  assert.equal(reconciliations, 1);

  const invalidRequests = [
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported" },
    }),
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: {
        action: "reconcile",
        userId: "reported",
        csrfToken: `${csrfToken.slice(0, -1)}${csrfToken.endsWith("0") ? "1" : "0"}`,
      },
    }),
  ];
  for (const request of invalidRequests) {
    const response = await handleAvatarAdmin(
      request,
      env,
      allowAdmin,
      reconcile,
    );
    assert.equal(response.status, 403);
  }

  const otherActor = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    env,
    async () => "other-admin@example.com",
    reconcile,
  );
  assert.equal(otherActor.status, 403);

  for (const request of [
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: "https://evil.example",
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    adminRequest("/admin/members/action", {
      method: "POST",
      includeOrigin: false,
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
  ]) {
    const response = await handleAvatarAdmin(
      request,
      env,
      allowAdmin,
      reconcile,
    );
    assert.equal(response.status, 403);
  }
  assert.equal(reconciliations, 1);
});

test("CSRF failures do not write moderation actions", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");
  await addReport(env, "report-csrf-rejected");
  const csrfToken = await csrfTokenFor(env);

  const missing = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: null,
      body: {
        reportId: "report-csrf-rejected",
        action: "dismiss_report",
      },
    }),
    env,
    allowAdmin,
  );
  assert.equal(missing.status, 403);

  const otherActor = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: null,
      body: {
        reportId: "report-csrf-rejected",
        action: "dismiss_report",
        csrfToken,
      },
    }),
    env,
    async () => "other-admin@example.com",
  );
  assert.equal(otherActor.status, 403);

  const report = await env.DB.prepare(
    "SELECT status FROM avatar_reports WHERE id = 'report-csrf-rejected'",
  ).first();
  assert.equal(report.status, "open");
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM avatar_moderation_actions",
  ).first();
  assert.equal(audit.count, 0);
});

test("rejected membership admin POSTs leave reconciliation and audit unchanged", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: null,
  });
  const csrfToken = await csrfTokenFor(env);
  const tamperedToken = `${csrfToken.slice(0, -1)}${csrfToken.endsWith("0") ? "1" : "0"}`;
  let reconciliations = 0;
  const reconcile = async () => {
    reconciliations += 1;
  };
  const snapshotBefore = await env.DB.prepare(
    "SELECT is_active, product_identifier, verified_at FROM membership_snapshots WHERE user_id = 'reported'",
  ).first();

  for (const request of [
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: "https://evil.example",
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported" },
    }),
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported", csrfToken: tamperedToken },
    }),
  ]) {
    const response = await handleAvatarAdmin(request, env, allowAdmin, reconcile);
    assert.equal(response.status, 403);
  }
  const actorMismatch = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      origin: null,
      body: { action: "reconcile", userId: "reported", csrfToken },
    }),
    env,
    async () => "other-admin@example.com",
    reconcile,
  );
  assert.equal(actorMismatch.status, 403);

  assert.equal(reconciliations, 0);
  const snapshotAfter = await env.DB.prepare(
    "SELECT is_active, product_identifier, verified_at FROM membership_snapshots WHERE user_id = 'reported'",
  ).first();
  assert.deepEqual({ ...snapshotAfter }, { ...snapshotBefore });
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM membership_admin_actions",
  ).first();
  assert.equal(audit.count, 0);
});

test("missing-Origin membership admin POST leaves snapshot, audit, and reconciliation unchanged", async () => {
  const env = await setup();
  await seedMembership(env.DB, "reported", {
    hasEntitlement: 1,
    productIdentifier: "premium:monthly",
  });
  const csrfToken = await csrfTokenFor(env);
  let reconciliations = 0;
  const reconcile = async () => {
    reconciliations += 1;
  };
  const snapshotBefore = await env.DB.prepare(
    "SELECT * FROM membership_snapshots WHERE user_id = 'reported'",
  ).first();

  const response = await handleAvatarAdmin(
    adminRequest("/admin/members/action", {
      method: "POST",
      body: { action: "reconcile", userId: "reported", csrfToken },
      includeOrigin: false,
    }),
    env,
    allowAdmin,
    reconcile,
  );

  assert.equal(response.status, 403);
  assert.equal(reconciliations, 0);
  const snapshotAfter = await env.DB.prepare(
    "SELECT * FROM membership_snapshots WHERE user_id = 'reported'",
  ).first();
  assert.deepEqual({ ...snapshotAfter }, { ...snapshotBefore });
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM membership_admin_actions",
  ).first();
  assert.equal(audit.count, 0);
});

test("rejected moderation POSTs leave report state and audit unchanged", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");
  await addReport(env, "report-post-rejected");
  const csrfToken = await csrfTokenFor(env, {
    path: "/admin/avatar-reports",
  });
  const tamperedToken = `${csrfToken.slice(0, -1)}${csrfToken.endsWith("0") ? "1" : "0"}`;
  const form = { reportId: "report-post-rejected", action: "dismiss_report" };

  for (const request of [
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: "https://evil.example",
      body: { ...form, csrfToken },
    }),
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: null,
      body: form,
    }),
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: null,
      body: { ...form, csrfToken: tamperedToken },
    }),
  ]) {
    const response = await handleAvatarAdmin(request, env, allowAdmin);
    assert.equal(response.status, 403);
  }
  const actorMismatch = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      origin: null,
      body: { ...form, csrfToken },
    }),
    env,
    async () => "other-admin@example.com",
  );
  assert.equal(actorMismatch.status, 403);

  const report = await env.DB.prepare(
    "SELECT status FROM avatar_reports WHERE id = 'report-post-rejected'",
  ).first();
  assert.equal(report.status, "open");
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM avatar_moderation_actions",
  ).first();
  assert.equal(audit.count, 0);
});

test("missing-Origin moderation POST leaves report state and audit unchanged", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");
  await addReport(env, "report-missing-origin");
  const csrfToken = await csrfTokenFor(env, {
    path: "/admin/avatar-reports",
  });
  const reportBefore = await env.DB.prepare(
    "SELECT * FROM avatar_reports WHERE id = 'report-missing-origin'",
  ).first();

  const response = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      body: {
        reportId: "report-missing-origin",
        action: "dismiss_report",
        csrfToken,
      },
      includeOrigin: false,
    }),
    env,
    allowAdmin,
  );

  assert.equal(response.status, 403);
  const reportAfter = await env.DB.prepare(
    "SELECT * FROM avatar_reports WHERE id = 'report-missing-origin'",
  ).first();
  assert.deepEqual({ ...reportAfter }, { ...reportBefore });
  const audit = await env.DB.prepare(
    "SELECT COUNT(*) AS count FROM avatar_moderation_actions",
  ).first();
  assert.equal(audit.count, 0);
});

test("moderation actions accept CSRF-protected same-origin POST and reject foreign or missing origin", async () => {
  const env = await setup();
  await seedUser(env.DB, "reporter");
  await addReport(env, "report-origin");

  // `Origin: "null"` is accepted only with verified Access identity and an
  // actor-bound CSRF token; Access authentication alone does not prove intent.
  assert.equal(
    (await action(env, "report-origin", "dismiss_report", null)).status,
    303,
  );
  // Foreign origin is still blocked.
  assert.equal(
    (await action(env, "report-origin", "dismiss_report", "https://evil.example"))
      .status,
    403,
  );
  // A POST with no Origin header at all is treated as a CSRF attempt and blocked.
  const csrfToken = await csrfTokenFor(env);
  const noOrigin = await handleAvatarAdmin(
    adminRequest("/admin/avatar-reports/action", {
      method: "POST",
      body: {
        reportId: "report-origin",
        action: "dismiss_report",
        csrfToken,
      },
      includeOrigin: false,
    }),
    env,
    allowAdmin,
  );
  assert.equal(noOrigin.status, 403);
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
