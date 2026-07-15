-- Full current schema snapshot, for reference and ad-hoc local resets ONLY.
-- Every statement is CREATE ... IF NOT EXISTS, so this file is safe to apply
-- repeatedly to an empty database.
--
-- THIS IS NOT THE DEPLOYMENT ENTRY POINT. Production databases (fresh or
-- legacy) are created/upgraded exclusively through `wrangler d1 migrations
-- apply` (npm run migrate), which runs migrations/0001_membership_baseline.sql
-- through migrations/0004_custom_avatar_ugc.sql and records them so they
-- never re-run. Do NOT apply schema.sql and then run migrations: that would
-- double-apply the account columns (0002 ALTERs them onto users) and fail with
-- "duplicate column name".
--
-- Never add a bare `ALTER TABLE ... ADD COLUMN` here: it is not idempotent.

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
  nickname_updated_at TEXT,
  custom_avatar_object_id TEXT,
  public_avatar_hidden_at TEXT,
  avatar_upload_suspended_at TEXT
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
  updated_at TEXT NOT NULL,
  identity_mode TEXT NOT NULL DEFAULT 'anonymous',
  leaderboard_nickname TEXT,
  leaderboard_nickname_key TEXT,
  leaderboard_avatar_key TEXT,
  anonymous_avatar_key TEXT NOT NULL DEFAULT 'ring-green'
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

CREATE TABLE IF NOT EXISTS avatar_objects (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL CHECK (status IN ('active', 'replaced', 'removed')),
  created_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE TABLE IF NOT EXISTS avatar_policy_acceptances (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  policy_version TEXT NOT NULL,
  accepted_at TEXT NOT NULL,
  PRIMARY KEY (user_id, policy_version)
);

CREATE TABLE IF NOT EXISTS avatar_reports (
  id TEXT PRIMARY KEY,
  reporter_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL CHECK (report_type IN ('avatar', 'user')),
  avatar_object_id TEXT REFERENCES avatar_objects(id) ON DELETE SET NULL,
  avatar_source TEXT NOT NULL CHECK (avatar_source IN ('custom', 'google', 'none')),
  reason TEXT NOT NULL CHECK (reason IN ('nudity', 'violence', 'hate', 'spam', 'impersonation', 'other')),
  details TEXT,
  status TEXT NOT NULL CHECK (status IN ('open', 'dismissed', 'actioned', 'stale')),
  created_at TEXT NOT NULL,
  resolved_at TEXT,
  resolved_by TEXT,
  resolution TEXT,
  CHECK (reporter_user_id <> reported_user_id)
);

CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker_user_id, blocked_user_id),
  CHECK (blocker_user_id <> blocked_user_id)
);

CREATE TABLE IF NOT EXISTS avatar_moderation_actions (
  id TEXT PRIMARY KEY,
  actor_subject TEXT NOT NULL,
  target_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  avatar_object_id TEXT REFERENCES avatar_objects(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (action IN (
    'dismiss_report',
    'remove_custom_avatar',
    'hide_public_avatar',
    'restore_public_avatar',
    'suspend_upload',
    'restore_upload'
  )),
  result TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS workout_sessions_user_month_idx
ON workout_sessions(user_id, local_date);

CREATE INDEX IF NOT EXISTS leaderboard_daily_totals_query_idx
ON leaderboard_daily_totals(exercise_type, ranking_date, total_value DESC);

CREATE INDEX IF NOT EXISTS avatar_objects_user_status_idx
ON avatar_objects(user_id, status);

CREATE INDEX IF NOT EXISTS avatar_reports_status_created_idx
ON avatar_reports(status, created_at);

CREATE UNIQUE INDEX IF NOT EXISTS avatar_reports_dedupe_idx
ON avatar_reports(
  reporter_user_id,
  reported_user_id,
  report_type,
  avatar_source,
  COALESCE(avatar_object_id, '')
);

CREATE INDEX IF NOT EXISTS user_blocks_blocked_user_idx
ON user_blocks(blocked_user_id);
