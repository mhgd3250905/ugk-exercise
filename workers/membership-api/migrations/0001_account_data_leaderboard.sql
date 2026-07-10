-- One-time migration: upgrade a pre-account database (users without the
-- nickname/avatar columns, and no workout/leaderboard tables) to the current
-- schema. Applied once via `wrangler d1 migrations apply`. Wrangler records it
-- in the d1_migrations table so it never re-runs.
--
-- New databases do NOT run this file; they are created from schema.sql which
-- already defines these columns inline. This migration is additive only: it
-- preserves all existing users / membership data.

-- Account profile columns on users.
ALTER TABLE users ADD COLUMN nickname TEXT;
ALTER TABLE users ADD COLUMN nickname_key TEXT;
ALTER TABLE users ADD COLUMN avatar_key TEXT;
ALTER TABLE users ADD COLUMN nickname_updated_at TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_key_idx
ON users(nickname_key)
WHERE nickname_key IS NOT NULL;

-- Cloud workout history.
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

-- Public leaderboard opt-in state.
CREATE TABLE IF NOT EXISTS leaderboard_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  is_joined INTEGER NOT NULL,
  joined_at TEXT,
  left_at TEXT,
  updated_at TEXT NOT NULL
);

-- Materialized per-day ranking totals.
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
