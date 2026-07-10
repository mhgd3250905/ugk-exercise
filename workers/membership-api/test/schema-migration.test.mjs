// Repeatable D1 deployment: prove the schema path is safe to run more than
// once and that a legacy database upgrades without losing rows.
//
// Root cause being fixed: schema.sql historically mixed CREATE TABLE IF NOT
// EXISTS (repeatable) with bare `ALTER TABLE users ADD COLUMN ...` (fails on
// the second run because the column already exists). This test creates real
// SQLite databases, applies the baseline and the migration, and asserts on
// columns, tables, indexes, and row preservation.
import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { DatabaseSync } from "node:sqlite";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const freshSchemaPath = join(root, "schema.sql");
const migrationPath = join(root, "migrations", "0001_account_data_leaderboard.sql");

// The "old" schema is the pre-account baseline: users without the account
// columns, and none of the workout/leaderboard tables. This mirrors the
// database shape before this feature shipped.
const LEGACY_SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS auth_identities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  provider TEXT NOT NULL,
  provider_subject TEXT NOT NULL,
  email TEXT NOT NULL,
  email_verified INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(provider, provider_subject)
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  app_user_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS membership_snapshots (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  entitlement TEXT NOT NULL,
  is_active INTEGER NOT NULL,
  expires_at TEXT,
  source TEXT NOT NULL,
  revenuecat_app_user_id TEXT NOT NULL,
  last_event_at TEXT,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  event_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  received_at TEXT NOT NULL,
  processed_at TEXT,
  payload_json TEXT NOT NULL,
  UNIQUE(provider, event_id)
);
CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_app_user_id_idx ON sessions(app_user_id);
`;

function freshDb() {
  const db = new DatabaseSync(":memory:");
  db.exec("PRAGMA foreign_keys = ON;");
  return db;
}

function columnsOf(db, table) {
  const rows = db.prepare(`PRAGMA table_info(${table})`).all();
  return new Set(rows.map((row) => row.name));
}

function indexNames(db) {
  const rows = db.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'",
  ).all();
  return new Set(rows.map((row) => row.name));
}

function tableNames(db) {
  const rows = db.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
  ).all();
  return new Set(rows.map((row) => row.name));
}

test("schema.sql must not contain a bare ALTER TABLE in the repeatable baseline", () => {
  // A bare ALTER TABLE ADD COLUMN is not idempotent and breaks a second run.
  // The fresh schema must define all columns inline.
  const sql = readFileSync(freshSchemaPath, "utf8");
  assert.equal(
    /ALTER\s+TABLE\s+users\s+ADD\s+COLUMN/i.test(sql),
    false,
    "schema.sql must not contain a bare ALTER TABLE users ADD COLUMN",
  );
});

test("fresh schema creates all required columns, tables, and indexes", () => {
  const db = freshDb();
  db.exec(readFileSync(freshSchemaPath, "utf8"));

  const userCols = columnsOf(db, "users");
  for (const col of [
    "id",
    "display_name",
    "email",
    "avatar_url",
    "created_at",
    "updated_at",
    "nickname",
    "nickname_key",
    "avatar_key",
    "nickname_updated_at",
  ]) {
    assert.ok(userCols.has(col), `users must have column ${col}`);
  }

  const tables = tableNames(db);
  for (const t of [
    "users",
    "auth_identities",
    "sessions",
    "membership_snapshots",
    "webhook_events",
    "workout_sessions",
    "leaderboard_profiles",
    "leaderboard_daily_totals",
  ]) {
    assert.ok(tables.has(t), `table ${t} must exist`);
  }

  const indexes = indexNames(db);
  for (const idx of [
    "sessions_user_id_idx",
    "sessions_app_user_id_idx",
    "users_nickname_key_idx",
    "workout_sessions_user_month_idx",
    "leaderboard_daily_totals_query_idx",
  ]) {
    assert.ok(indexes.has(idx), `index ${idx} must exist`);
  }
});

test("re-running the fresh schema is safe (no errors, no duplicate columns)", () => {
  const db = freshDb();
  db.exec(readFileSync(freshSchemaPath, "utf8"));
  // A second application must not throw.
  assert.doesNotThrow(() => db.exec(readFileSync(freshSchemaPath, "utf8")));
});

test("migration upgrades a legacy database and preserves existing rows", () => {
  const db = freshDb();
  // Build the pre-account baseline and seed real rows that must survive.
  db.exec(LEGACY_SCHEMA);
  db.prepare(
    "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
  ).run("u_legacy", "Legacy", "legacy@example.com", null, "2026-01-01T00:00:00.000Z", "2026-01-01T00:00:00.000Z");
  db.prepare(
    "INSERT INTO membership_snapshots (user_id, entitlement, is_active, expires_at, source, revenuecat_app_user_id, last_event_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
  ).run("u_legacy", "premium", 1, "2099-01-01T00:00:00.000Z", "revenuecat_google_play", "u_legacy", "2026-01-01T00:00:00.000Z", "2026-01-01T00:00:00.000Z");

  // Apply the one-time migration.
  db.exec(readFileSync(migrationPath, "utf8"));

  // Legacy user columns were added.
  const userCols = columnsOf(db, "users");
  assert.ok(userCols.has("nickname"));
  assert.ok(userCols.has("nickname_key"));
  assert.ok(userCols.has("avatar_key"));
  assert.ok(userCols.has("nickname_updated_at"));

  // New tables exist.
  const tables = tableNames(db);
  assert.ok(tables.has("workout_sessions"));
  assert.ok(tables.has("leaderboard_profiles"));
  assert.ok(tables.has("leaderboard_daily_totals"));

  // Existing data is preserved (node:sqlite returns null-prototype rows, so
  // assert on fields rather than deepEqual).
  const user = db.prepare("SELECT display_name, email FROM users WHERE id = ?").get("u_legacy");
  assert.equal(user.display_name, "Legacy");
  assert.equal(user.email, "legacy@example.com");
  const membership = db
    .prepare("SELECT entitlement, is_active FROM membership_snapshots WHERE user_id = ?")
    .get("u_legacy");
  assert.equal(membership.entitlement, "premium");
  assert.equal(membership.is_active, 1);
});

test("the unique nickname index exists after migration", () => {
  const db = freshDb();
  db.exec(LEGACY_SCHEMA);
  db.exec(readFileSync(migrationPath, "utf8"));
  assert.ok(indexNames(db).has("users_nickname_key_idx"));
});
