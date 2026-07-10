-- Fresh-database schema. Fully idempotent: every statement is CREATE ... IF NOT
-- EXISTS, so this file is safe to apply repeatedly (e.g. for local resets or a
-- brand-new D1 database). It defines ALL current columns inline.
--
-- Upgrading an EXISTING pre-account database is a one-time operation handled by
-- migrations/0001_account_data_leaderboard.sql. Never add a bare
-- `ALTER TABLE ... ADD COLUMN` here: it is not idempotent and will fail on the
-- second run because the column already exists.

CREATE TABLE IF NOT EXISTS users (
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

CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_key_idx
ON users(nickname_key)
WHERE nickname_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS workout_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  client_session_id TEXT NOT NULL,
  exercise_type TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  local_date TEXT NOT NULL,
  timezone_offset_minutes INTEGER NOT NULL,
  ranking_date TEXT NOT NULL,
  metric_value INTEGER NOT NULL,
  metric_unit TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(user_id, client_session_id)
);

CREATE TABLE IF NOT EXISTS leaderboard_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  is_joined INTEGER NOT NULL,
  joined_at TEXT,
  left_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS leaderboard_daily_totals (
  user_id TEXT NOT NULL REFERENCES users(id),
  exercise_type TEXT NOT NULL,
  ranking_date TEXT NOT NULL,
  total_value INTEGER NOT NULL,
  last_session_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(user_id, exercise_type, ranking_date)
);

CREATE INDEX IF NOT EXISTS workout_sessions_user_month_idx
ON workout_sessions(user_id, local_date);

CREATE INDEX IF NOT EXISTS leaderboard_daily_totals_query_idx
ON leaderboard_daily_totals(exercise_type, ranking_date, total_value DESC);
