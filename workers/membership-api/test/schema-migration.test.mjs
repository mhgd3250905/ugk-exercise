// Canonical D1 migration chain: prove `wrangler d1 migrations apply` is the
// single deploy path for BOTH fresh and legacy databases, is safe to run
// twice, and preserves existing rows.
//
// These tests shell out to the REAL wrangler CLI with `--local --persist-to`
// against a throwaway directory, then open the resulting SQLite file with
// node:sqlite to assert on schema and rows. They do NOT use DatabaseSync.exec
// on the migration SQL, because that would not exercise Wrangler's migration
// recording (d1_migrations table) which is what makes a second apply a no-op.
//
// No remote access: --local only.
import assert from "node:assert/strict";
import test from "node:test";
import { spawnSync } from "node:child_process";
import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  rmSync,
  existsSync,
  readFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
// Miniflare names the local D1 data file after a content-derived hash that is
// stable across runs for the same binding. Seed the legacy DB at this path so
// wrangler opens and upgrades the same file.
const D1_DATA_HASH =
  "eac2588b8504ebd6552125d568547c7fffbeb1d781cabe547cde3567b8cecf81";

// Wrangler (miniflare) stores the local D1 sqlite under
// <persist>/v3/d1/miniflare-D1DatabaseObject/<hash>.sqlite plus a metadata.sqlite.
// The hash is content-derived, not the database id, so locate the data file by
// looking for the one that actually contains our schema (has a `users` table),
// excluding metadata.sqlite.
function d1FilePath(persistDir) {
  const dir = join(persistDir, "v3", "d1", "miniflare-D1DatabaseObject");
  assert.ok(existsSync(dir), `expected miniflare d1 dir at ${dir}`);
  for (const name of readdirSync(dir)) {
    if (!name.endsWith(".sqlite") || name === "metadata.sqlite") continue;
    const candidate = join(dir, name);
    try {
      const probe = new DatabaseSync(candidate);
      const row = probe
        .prepare(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'",
        )
        .get();
      probe.close();
      if (row !== undefined) return candidate;
    } catch {
      // not a usable sqlite file; skip
    }
  }
  throw new Error(`no d1 data sqlite with a users table found under ${dir}`);
}

// Run the supported deploy command against a throwaway local persistence dir.
// Returns nothing; throws on non-zero exit so a failed apply fails the test.
// Uses shell:true because npx is a .cmd shim on Windows that cannot be spawned
// directly without a shell.
function applyMigrations(persistDir) {
  const args = [
    "wrangler",
    "d1",
    "migrations",
    "apply",
    "ugk-membership",
    "--local",
    "--persist-to",
    persistDir,
  ];
  const result = spawnSync("npx", args, {
    cwd: root,
    shell: true,
    env: { ...process.env, CI: "1" },
  });
  if (result.status !== 0) {
    const out = (result.stdout ?? "").toString();
    const err = (result.stderr ?? "").toString();
    throw new Error(
      `wrangler d1 migrations apply exited ${result.status}\nstdout:\n${out}\nstderr:\n${err}`,
    );
  }
}

// Seed a legacy pre-account database directly into the persist dir so that a
// subsequent migrations apply exercises the upgrade path (0001 no-op, 0002
// adds columns/tables) without losing rows.
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

function seedLegacyDb(persistDir) {
  const dir = join(persistDir, "v3", "d1", "miniflare-D1DatabaseObject");
  mkdirSync(dir, { recursive: true });
  const db = new DatabaseSync(join(dir, `${D1_DATA_HASH}.sqlite`));
  db.exec(LEGACY_SCHEMA);
  db.prepare(
    "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
  ).run(
    "u_legacy",
    "Legacy",
    "legacy@example.com",
    null,
    "2026-01-01T00:00:00.000Z",
    "2026-01-01T00:00:00.000Z",
  );
  db.prepare(
    "INSERT INTO membership_snapshots (user_id, entitlement, is_active, expires_at, source, revenuecat_app_user_id, last_event_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
  ).run(
    "u_legacy",
    "premium",
    1,
    "2099-01-01T00:00:00.000Z",
    "revenuecat_google_play",
    "u_legacy",
    "2026-01-01T00:00:00.000Z",
    "2026-01-01T00:00:00.000Z",
  );
  db.close();
}

function openDb(persistDir) {
  const path = d1FilePath(persistDir);
  assert.ok(existsSync(path), `expected d1 sqlite at ${path}`);
  const db = new DatabaseSync(path);
  db.exec("PRAGMA foreign_keys = ON;");
  return db;
}

function columnsOf(db, table) {
  return new Set(
    db.prepare(`PRAGMA table_info(${table})`).all().map((r) => r.name),
  );
}

function indexNames(db) {
  return new Set(
    db
      .prepare(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'",
      )
      .all()
      .map((r) => r.name),
  );
}

function tableNames(db) {
  return new Set(
    db
      .prepare(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .all()
      .map((r) => r.name),
  );
}

function assertFullSchema(db) {
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
    "d1_migrations",
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
}

test("schema.sql snapshot must not be a migration entry point (no bare ALTER)", () => {
  const sql = readFileSync(join(root, "schema.sql"), "utf8");
  assert.equal(
    /ALTER\s+TABLE\s+users\s+ADD\s+COLUMN/i.test(sql),
    false,
    "schema.sql must not contain a bare ALTER TABLE users ADD COLUMN",
  );
});

test("migrations apply to a fresh empty database and produce the full schema", () => {
  const dir = mkdtempSync(join(tmpdir(), "d1-fresh-"));
  try {
    applyMigrations(dir);
    const db = openDb(dir);
    assertFullSchema(db);
    db.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("a second migrations apply is a safe no-op (exit 0, no changes)", () => {
  const dir = mkdtempSync(join(tmpdir(), "d1-double-"));
  try {
    applyMigrations(dir);
    // Second apply must succeed (exit 0) and leave the schema intact.
    applyMigrations(dir);
    const db = openDb(dir);
    assertFullSchema(db);
    db.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("migrations upgrade a legacy membership database without losing rows", () => {
  const dir = mkdtempSync(join(tmpdir(), "d1-legacy-"));
  try {
    seedLegacyDb(dir);
    applyMigrations(dir);
    const db = openDb(dir);
    assertFullSchema(db);

    // Legacy rows are preserved.
    const user = db
      .prepare("SELECT display_name, email FROM users WHERE id = ?")
      .get("u_legacy");
    assert.equal(user.display_name, "Legacy");
    assert.equal(user.email, "legacy@example.com");
    const membership = db
      .prepare("SELECT entitlement, is_active FROM membership_snapshots WHERE user_id = ?")
      .get("u_legacy");
    assert.equal(membership.entitlement, "premium");
    assert.equal(membership.is_active, 1);

    // Second apply is still safe on the upgraded legacy db.
    db.close();
    applyMigrations(dir);
    const db2 = openDb(dir);
    assertFullSchema(db2);
    const user2 = db2.prepare("SELECT email FROM users WHERE id = ?").get("u_legacy");
    assert.equal(user2.email, "legacy@example.com");
    db2.close();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
