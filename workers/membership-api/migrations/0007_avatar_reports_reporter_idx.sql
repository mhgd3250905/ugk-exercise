-- Index backing the per-reporter sliding-window rate limit on avatar_reports.
--
-- reportLeaderboardUser counts reports a reporter created inside a recent
-- window (`WHERE reporter_user_id = ? AND created_at >= ?`). Without an index
-- on (reporter_user_id, created_at) that COUNT degrades to a full table scan
-- as the reports table grows — turning the rate limit itself into a DoS vector.
-- This compound index serves that lookup directly.
CREATE INDEX IF NOT EXISTS avatar_reports_reporter_created_idx
ON avatar_reports(reporter_user_id, created_at);
