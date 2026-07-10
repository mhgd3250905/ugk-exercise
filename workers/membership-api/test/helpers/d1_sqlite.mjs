// Minimal D1-compatible facade over node:sqlite, used only by tests to prove
// real SQL behaviour (atomic limits, migrations). Not shipped to the Worker.
//
// Cloudflare D1 exposes:
//   prepare(sql) -> { bind(...args), first<T>(), all<T>(), run(), raw<T>() }
//   batch(statements) -> Promise<results[]>
// This adapter mirrors that contract against a real on-disk/in-memory SQLite
// database so tests can exercise the exact SQL the Worker emits.
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const schemaRoot = join(here, "..", "..");

export class D1Statement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql;
    this.args = [];
  }

  bind(...args) {
    this.args = args;
    return this;
  }

  #stmt() {
    // node:sqlite caches prepared statements per-connection, but a given
    // statement object is single-use for binding; create fresh each call.
    return this.db.prepare(this.sql);
  }

  async first() {
    const row = this.#stmt().get(...this.args) ?? null;
    return row;
  }

  async all() {
    const rows = this.#stmt().all(...this.args);
    return { results: rows, success: true, meta: { changes: 0 } };
  }

  async run() {
    const info = this.#stmt().run(...this.args);
    return { success: true, meta: { changes: info.changes } };
  }

  async raw() {
    return this.#stmt().all(...this.args);
  }
}

export class D1Sqlite {
  constructor(db) {
    this.db = db;
  }

  prepare(sql) {
    return new D1Statement(this.db, sql);
  }

  // D1 batches are atomic: either every statement commits or none do.
  // Mirror that with an explicit SQLite transaction so tests that rely on
  // rollback (e.g. insert-then-aggregate failure) observe real SQL behaviour.
  async batch(statements) {
    this.db.exec("BEGIN");
    const results = [];
    try {
      for (const statement of statements) {
        results.push(await statement.run());
      }
      this.db.exec("COMMIT");
      return results;
    } catch (error) {
      this.db.exec("ROLLBACK");
      throw error;
    }
  }
}

export async function createD1FromFile(path) {
  const db = new DatabaseSync(path);
  db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
  `);
  return new D1Sqlite(db);
}

export async function createD1FromSchema({
  path = ":memory:",
  schemaSql = join(schemaRoot, "schema.sql"),
} = {}) {
  const d1 = await createD1FromFile(path);
  const sql = readFileSync(schemaSql, "utf8");
  d1.db.exec(sql);
  return d1;
}

// Seed helpers used by multiple test files. Keep them D1-agnostic and explicit
// so tests remain readable.
export async function seedUser(d1, userId, overrides = {}) {
  const now = new Date().toISOString();
  await d1
    .prepare(
      "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at, nickname, nickname_key, avatar_key, nickname_updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(
      userId,
      overrides.displayName ?? "Tester",
      overrides.email ?? `${userId}@example.com`,
      overrides.avatarUrl ?? null,
      overrides.createdAt ?? now,
      overrides.updatedAt ?? now,
      overrides.nickname ?? null,
      overrides.nicknameKey ?? null,
      overrides.avatarKey ?? null,
      overrides.nicknameUpdatedAt ?? null,
    )
    .run();
}

export async function seedMembership(d1, userId, overrides = {}) {
  const now = new Date().toISOString();
  await d1
    .prepare(
      "INSERT INTO membership_snapshots (user_id, entitlement, is_active, expires_at, source, revenuecat_app_user_id, last_event_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(
      userId,
      overrides.entitlement ?? "premium",
      overrides.isActive ?? 1,
      overrides.expiresAt ?? "2099-01-01T00:00:00.000Z",
      overrides.source ?? "revenuecat_google_play",
      overrides.revenuecatAppUserId ?? userId,
      overrides.lastEventAt ?? now,
      overrides.updatedAt ?? now,
    )
    .run();
}

export async function seedSession(d1, tokenHash, userId) {
  const now = new Date().toISOString();
  await d1
    .prepare(
      "INSERT INTO sessions (token_hash, user_id, app_user_id, expires_at, created_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(
      tokenHash,
      userId,
      userId,
      "2099-01-01T00:00:00.000Z",
      now,
    )
    .run();
}

export async function seedLeaderboardProfile(d1, userId, overrides = {}) {
  const now = new Date().toISOString();
  await d1
    .prepare(
      "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(
      userId,
      overrides.isJoined ?? 1,
      overrides.joinedAt ?? now,
      overrides.leftAt ?? null,
      overrides.updatedAt ?? now,
    )
    .run();
}

export async function dailyTotal(d1, userId, exerciseType, rankingDate) {
  return d1
    .prepare(
      "SELECT total_value FROM leaderboard_daily_totals WHERE user_id = ? AND exercise_type = ? AND ranking_date = ?",
    )
    .bind(userId, exerciseType, rankingDate)
    .first();
}

export async function sessionCount(d1, userId) {
  const row = await d1
    .prepare("SELECT COUNT(*) AS n FROM workout_sessions WHERE user_id = ?")
    .bind(userId)
    .first();
  return row?.n ?? 0;
}
