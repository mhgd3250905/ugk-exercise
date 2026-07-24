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
  mkdtempSync,
  readdirSync,
  rmSync,
  existsSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const wranglerPath = join(root, "node_modules", "wrangler", "bin", "wrangler.js");

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

// Run the installed Wrangler directly, without a shell. Throws on non-zero.
function runWrangler(args) {
  const result = spawnSync(process.execPath, [wranglerPath, ...args], {
    cwd: root,
    env: { ...process.env, CI: "1" },
  });
  if (result.status !== 0) {
    const out = (result.stdout ?? "").toString();
    const err = (result.stderr ?? "").toString();
    throw new Error(
      `wrangler exited ${result.status}\nstdout:\n${out}\nstderr:\n${err}`,
    );
  }
}

function applyMigrations(persistDir) {
  runWrangler([
    "d1",
    "migrations",
    "apply",
    "ugk-membership",
    "--local",
    "--persist-to",
    persistDir,
  ]);
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
CREATE TABLE IF NOT EXISTS leaderboard_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  is_joined INTEGER NOT NULL,
  joined_at TEXT,
  left_at TEXT,
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_app_user_id_idx ON sessions(app_user_id);
`;

function seedLegacyDb(persistDir) {
  const seedPath = join(persistDir, "legacy.sql");
  writeFileSync(seedPath, LEGACY_SCHEMA);
  runWrangler([
    "d1",
    "execute",
    "ugk-membership",
    "--local",
    "--persist-to",
    persistDir,
    "--file",
    seedPath,
  ]);
  const db = openDb(persistDir);
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
  db.prepare(
    "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, ?, ?, ?, ?)",
  ).run(
    "u_legacy",
    1,
    "2026-01-01T00:00:00.000Z",
    null,
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
    "custom_avatar_object_id",
    "public_avatar_hidden_at",
    "avatar_upload_suspended_at",
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
    "avatar_objects",
    "avatar_policy_acceptances",
    "avatar_reports",
    "user_blocks",
    "avatar_moderation_actions",
    "membership_admin_actions",
    "d1_migrations",
  ]) {
    assert.ok(tables.has(t), `table ${t} must exist`);
  }
  const membershipCols = columnsOf(db, "membership_snapshots");
  assert.ok(
    membershipCols.has("verified_at"),
    "membership_snapshots must have column verified_at",
  );
  for (const col of [
    "has_entitlement",
    "product_identifier",
    "purchase_at",
    "original_purchase_at",
    "period_type",
    "store",
    "is_sandbox",
    "ownership_type",
    "unsubscribe_detected_at",
    "billing_issue_detected_at",
  ]) {
    assert.ok(
      membershipCols.has(col),
      `membership_snapshots must have column ${col}`,
    );
  }
  const leaderboardProfileCols = columnsOf(db, "leaderboard_profiles");
  for (const col of [
    "identity_mode",
    "leaderboard_nickname",
    "leaderboard_nickname_key",
    "leaderboard_avatar_key",
    "anonymous_avatar_key",
  ]) {
    assert.ok(
      leaderboardProfileCols.has(col),
      `leaderboard_profiles must have column ${col}`,
    );
  }
  const leaderboardProfileInfo = new Map(
    db
      .prepare("PRAGMA table_info(leaderboard_profiles)")
      .all()
      .map((row) => [row.name, row]),
  );
  assert.equal(leaderboardProfileInfo.get("identity_mode").notnull, 1);
  assert.equal(
    leaderboardProfileInfo.get("identity_mode").dflt_value,
    "'anonymous'",
  );
  assert.equal(
    leaderboardProfileInfo.get("anonymous_avatar_key").notnull,
    1,
  );
  assert.equal(
    leaderboardProfileInfo.get("anonymous_avatar_key").dflt_value,
    "'ring-green'",
  );
  const indexes = indexNames(db);
  for (const idx of [
    "sessions_user_id_idx",
    "sessions_app_user_id_idx",
    "users_nickname_key_idx",
    "workout_sessions_user_month_idx",
    "leaderboard_daily_totals_query_idx",
    "avatar_objects_user_status_idx",
    "avatar_reports_status_created_idx",
    "avatar_reports_reporter_created_idx",
    "user_blocks_blocked_user_idx",
    "membership_admin_actions_created_idx",
  ]) {
    assert.ok(indexes.has(idx), `index ${idx} must exist`);
  }
  assert.equal(indexes.has("leaderboard_profiles_nickname_key_idx"), false);
}

test("avatar migration retires custom leaderboard identities", () => {
  const db = new DatabaseSync(":memory:");
  try {
    db.exec(`
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        email TEXT NOT NULL,
        avatar_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        nickname TEXT,
        nickname_key TEXT,
        avatar_key TEXT,
        nickname_updated_at TEXT
      );
      CREATE TABLE leaderboard_profiles (
        user_id TEXT PRIMARY KEY REFERENCES users(id),
        is_joined INTEGER NOT NULL,
        joined_at TEXT,
        left_at TEXT,
        updated_at TEXT NOT NULL,
        identity_mode TEXT NOT NULL DEFAULT 'anonymous',
        leaderboard_nickname TEXT,
        leaderboard_nickname_key TEXT,
        leaderboard_avatar_key TEXT,
        anonymous_avatar_key TEXT NOT NULL DEFAULT 'ring-green'
      );
      INSERT INTO users VALUES (
        'u_custom', 'User', 'u@example.com', NULL,
        '2026-07-14T00:00:00.000Z', '2026-07-14T00:00:00.000Z',
        NULL, NULL, NULL, NULL
      );
      INSERT INTO leaderboard_profiles VALUES (
        'u_custom', 1, '2026-07-14T00:00:00.000Z', NULL,
        '2026-07-14T00:00:00.000Z', 'custom', '榜单昵称',
        'leaderboard-name', 'ring-coral', 'ring-green'
      );
    `);
    db.exec(
      readFileSync(
        join(root, "migrations", "0004_custom_avatar_ugc.sql"),
        "utf8",
      ),
    );

    const row = db
      .prepare(
        "SELECT identity_mode, leaderboard_nickname, leaderboard_nickname_key, leaderboard_avatar_key FROM leaderboard_profiles WHERE user_id = ?",
      )
      .get("u_custom");
    assert.equal(row.identity_mode, "profile");
    assert.equal(row.leaderboard_nickname, null);
    assert.equal(row.leaderboard_nickname_key, null);
    assert.equal(row.leaderboard_avatar_key, null);
  } finally {
    db.close();
  }
});

test("avatar governance schema enforces controlled values and uniqueness", () => {
  const dir = mkdtempSync(join(tmpdir(), "d1-avatar-constraints-"));
  try {
    applyMigrations(dir);
    const db = openDb(dir);
    try {
      const now = "2026-07-14T00:00:00.000Z";
      db.prepare(
        "INSERT INTO users (id, display_name, email, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
      ).run("reporter", "Reporter", "reporter@example.com", now, now);
      db.prepare(
        "INSERT INTO users (id, display_name, email, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
      ).run("target", "Target", "target@example.com", now, now);
      db.prepare(
        "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, ?, ?, ?, ?)",
      ).run("avatar-1", "target", "avatars/avatar-1.jpg", "active", now);

      assert.throws(() =>
        db.prepare(
          "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, ?, ?, ?, ?)",
        ).run("avatar-2", "target", "avatars/avatar-1.jpg", "active", now),
      );
      assert.throws(() =>
        db.prepare(
          "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, ?, ?, ?, ?)",
        ).run("avatar-3", "target", "avatars/avatar-3.jpg", "pending", now),
      );

      db.prepare(
        "INSERT INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)",
      ).run("reporter", "target", now);
      assert.throws(() =>
        db.prepare(
          "INSERT INTO user_blocks (blocker_user_id, blocked_user_id, created_at) VALUES (?, ?, ?)",
        ).run("reporter", "target", now),
      );
      assert.throws(() =>
        db.prepare(
          "INSERT INTO avatar_reports (id, reporter_user_id, reported_user_id, report_type, avatar_source, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ).run(
          "report-1",
          "reporter",
          "target",
          "comment",
          "custom",
          "other",
          "open",
          now,
        ),
      );
    } finally {
      db.close();
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("schema.sql snapshot must not be a migration entry point (no bare ALTER)", () => {
  const sql = readFileSync(join(root, "schema.sql"), "utf8");
  assert.equal(
    /ALTER\s+TABLE\s+users\s+ADD\s+COLUMN/i.test(sql),
    false,
    "schema.sql must not contain a bare ALTER TABLE users ADD COLUMN",
  );
});

test("production migration entry point explicitly targets remote D1", () => {
  const packageJson = JSON.parse(
    readFileSync(join(root, "package.json"), "utf8"),
  );
  assert.match(packageJson.scripts.migrate, /(?:^|\s)--remote(?:\s|$)/);
});

test("migration tests do not hardcode Miniflare's internal D1 hash", () => {
  const source = readFileSync(fileURLToPath(import.meta.url), "utf8");
  const constantName = ["D1", "DATA", "HASH"].join("_");
  const sixtyFourHexChars = new RegExp("[a-f0-9]" + "{64}");
  assert.equal(source.includes(constantName), false);
  assert.doesNotMatch(source, sixtyFourHexChars);
});

test("migrations apply to a fresh empty database and produce the full schema", () => {
  const dir = mkdtempSync(join(tmpdir(), "d1-fresh-"));
  try {
    applyMigrations(dir);
    const db = openDb(dir);
    try {
      assertFullSchema(db);
    } finally {
      db.close();
    }
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
    try {
      assertFullSchema(db);
    } finally {
      db.close();
    }
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
    try {
      assertFullSchema(db);

      // Legacy rows are preserved.
      const user = db
        .prepare("SELECT display_name, email FROM users WHERE id = ?")
        .get("u_legacy");
      assert.equal(user.display_name, "Legacy");
      assert.equal(user.email, "legacy@example.com");
      const membership = db
        .prepare("SELECT entitlement, is_active, verified_at, has_entitlement FROM membership_snapshots WHERE user_id = ?")
        .get("u_legacy");
      assert.equal(membership.entitlement, "premium");
      assert.equal(membership.is_active, 1);
      assert.equal(membership.verified_at, null);
      assert.equal(membership.has_entitlement, 1);
      const leaderboardProfile = db
        .prepare(
          "SELECT is_joined, joined_at, left_at, updated_at, identity_mode, anonymous_avatar_key FROM leaderboard_profiles WHERE user_id = ?",
        )
        .get("u_legacy");
      assert.equal(leaderboardProfile.is_joined, 1);
      assert.equal(
        leaderboardProfile.joined_at,
        "2026-01-01T00:00:00.000Z",
      );
      assert.equal(leaderboardProfile.left_at, null);
      assert.equal(
        leaderboardProfile.updated_at,
        "2026-01-01T00:00:00.000Z",
      );
      assert.equal(leaderboardProfile.identity_mode, "anonymous");
      assert.ok(
        [
          "ring-green",
          "ring-lime",
          "ring-sky",
          "ring-yellow",
          "ring-coral",
        ].includes(leaderboardProfile.anonymous_avatar_key),
      );
    } finally {
      db.close();
    }

    // Second apply is still safe on the upgraded legacy db.
    applyMigrations(dir);
    const db2 = openDb(dir);
    try {
      assertFullSchema(db2);
      const user2 = db2
        .prepare("SELECT email FROM users WHERE id = ?")
        .get("u_legacy");
      assert.equal(user2.email, "legacy@example.com");
    } finally {
      db2.close();
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
