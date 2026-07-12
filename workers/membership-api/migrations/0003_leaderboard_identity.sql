ALTER TABLE leaderboard_profiles ADD COLUMN identity_mode TEXT NOT NULL DEFAULT 'anonymous';
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_nickname TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_nickname_key TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN leaderboard_avatar_key TEXT;
ALTER TABLE leaderboard_profiles ADD COLUMN anonymous_avatar_key TEXT NOT NULL DEFAULT 'ring-green';

UPDATE leaderboard_profiles
SET anonymous_avatar_key = CASE ABS(rowid) % 5
  WHEN 0 THEN 'ring-green'
  WHEN 1 THEN 'ring-lime'
  WHEN 2 THEN 'ring-sky'
  WHEN 3 THEN 'ring-yellow'
  ELSE 'ring-coral'
END;

CREATE UNIQUE INDEX IF NOT EXISTS leaderboard_profiles_nickname_key_idx
ON leaderboard_profiles(leaderboard_nickname_key)
WHERE leaderboard_nickname_key IS NOT NULL;
