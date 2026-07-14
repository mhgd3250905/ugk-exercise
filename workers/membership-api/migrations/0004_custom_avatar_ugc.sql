ALTER TABLE users ADD COLUMN custom_avatar_object_id TEXT;
ALTER TABLE users ADD COLUMN public_avatar_hidden_at TEXT;
ALTER TABLE users ADD COLUMN avatar_upload_suspended_at TEXT;

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

UPDATE leaderboard_profiles
SET identity_mode = 'profile',
    leaderboard_nickname = NULL,
    leaderboard_nickname_key = NULL,
    leaderboard_avatar_key = NULL
WHERE identity_mode = 'custom';

DROP INDEX IF EXISTS leaderboard_profiles_nickname_key_idx;
