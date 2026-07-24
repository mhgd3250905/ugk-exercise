// Real-SQL coverage for atomic Google account creation.
//
// `authGoogle` creates a user and its `auth_identities` row. They MUST be
// written atomically: a concurrent login for the same Google subject can
// complete one insert and then fail the other on the UNIQUE(provider,
// provider_subject) constraint. If the two inserts are not in one transaction,
// the failed path leaves an orphan `users` row that can never be logged into
// and occupies the email — breaking the one-account-per-identity invariant.
//
// These tests run against a real SQLite database built from schema.sql and
// prove the production write path (a single D1 batch) rolls back completely
// when the identity insert is rejected, leaving no orphan user.
import assert from "node:assert/strict";
import test from "node:test";

import { createD1FromSchema } from "./helpers/d1_sqlite.mjs";

function newIdentityStmts(d1, userId, subject, email, now) {
  return [
    d1.prepare(
      "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    ).bind(userId, "n", email, null, now, now),
    d1.prepare(
      "INSERT INTO auth_identities (id, user_id, provider, provider_subject, email, email_verified, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ).bind(crypto.randomUUID(), userId, "google", subject, email, 1, now),
  ];
}

async function orphanCount(d1) {
  const row = await d1
    .prepare(
      "SELECT COUNT(*) AS n FROM users u WHERE NOT EXISTS (SELECT 1 FROM auth_identities ai WHERE ai.user_id = u.id)",
    )
    .first();
  return row?.n ?? 0;
}

test("atomic batch leaves no orphan user when the identity insert is rejected", async () => {
  const d1 = await createD1FromSchema();
  const now = new Date().toISOString();
  const subject = "google-sub-atomic";
  const email = "atomic@example.com";

  // A first, fully-successful creation commits both rows.
  const firstUserId = crypto.randomUUID();
  await d1.batch(newIdentityStmts(d1, firstUserId, subject, email, now));

  // A racing creation for the SAME subject must fail the auth_identities
  // insert (UNIQUE constraint) and roll back its already-applied users insert.
  const racingUserId = crypto.randomUUID();
  await assert.rejects(
    () => d1.batch(newIdentityStmts(d1, racingUserId, subject, email, now)),
    // SQLite surfaces a UNIQUE violation as a generic error.
    (error) => error instanceof Error,
  );

  const users = await d1
    .prepare("SELECT id FROM users WHERE email = ?")
    .bind(email)
    .all();
  const identities = await d1
    .prepare("SELECT user_id FROM auth_identities WHERE provider = 'google' AND provider_subject = ?")
    .bind(subject)
    .all();

  // Exactly one user row survived (the first one); the racer was rolled back.
  assert.equal(users.results.length, 1);
  assert.equal(users.results[0].id, firstUserId);
  assert.equal(identities.results.length, 1);
  assert.equal(identities.results[0].user_id, firstUserId);
  assert.equal(await orphanCount(d1), 0);
});

test("two distinct Google identities each create exactly one non-orphan user", async () => {
  const d1 = await createD1FromSchema();
  const now = new Date().toISOString();

  const a = crypto.randomUUID();
  const b = crypto.randomUUID();
  await d1.batch(newIdentityStmts(d1, a, "sub-a", "a@example.com", now));
  await d1.batch(newIdentityStmts(d1, b, "sub-b", "b@example.com", now));

  const users = await d1.prepare("SELECT COUNT(*) AS n FROM users").first();
  const identities = await d1
    .prepare("SELECT COUNT(*) AS n FROM auth_identities WHERE provider = 'google'")
    .first();
  assert.equal(users?.n, 2);
  assert.equal(identities?.n, 2);
  assert.equal(await orphanCount(d1), 0);
});
