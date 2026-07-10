-- Migration 0002: account profile, cloud workouts, and leaderboard.
-- Runs after 0001_membership_baseline. Adds the account columns to users and
-- creates the workout/leaderboard tables. On a fresh database 0001 created
-- users WITHOUT these columns, so the ALTERs here add them; on the legacy
-- remote they are likewise absent, so the same migration upgrades both.
-- SQLite does not support ADD COLUMN IF NOT EXISTS, so do not re-run this file
-- manually — rely on `wrangler d1 migrations apply`, which records it.

ALTER TABLE users ADD COLUMN nickname TEXT;
ALTER TABLE users ADD COLUMN nickname_key TEXT;
ALTER TABLE users ADD COLUMN avatar_key TEXT;
ALTER TABLE users ADD COLUMN nickname_updated_at TEXT;

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
