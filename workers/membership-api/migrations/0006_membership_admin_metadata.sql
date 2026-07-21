-- Persist the latest RevenueCat membership observation needed by the
-- read-only operator dashboard. These fields remain a rebuildable cache;
-- RevenueCat is still the subscription authority.

ALTER TABLE membership_snapshots ADD COLUMN has_entitlement INTEGER NOT NULL DEFAULT 0 CHECK (has_entitlement IN (0, 1));
ALTER TABLE membership_snapshots ADD COLUMN product_identifier TEXT;
ALTER TABLE membership_snapshots ADD COLUMN purchase_at TEXT;
ALTER TABLE membership_snapshots ADD COLUMN original_purchase_at TEXT;
ALTER TABLE membership_snapshots ADD COLUMN period_type TEXT;
ALTER TABLE membership_snapshots ADD COLUMN store TEXT;
ALTER TABLE membership_snapshots ADD COLUMN is_sandbox INTEGER CHECK (is_sandbox IS NULL OR is_sandbox IN (0, 1));
ALTER TABLE membership_snapshots ADD COLUMN ownership_type TEXT;
ALTER TABLE membership_snapshots ADD COLUMN unsubscribe_detected_at TEXT;
ALTER TABLE membership_snapshots ADD COLUMN billing_issue_detected_at TEXT;

-- Existing active rows, and inactive rows with a recorded expiration, already
-- prove that this user held the premium entitlement at least once.
UPDATE membership_snapshots
SET has_entitlement = 1
WHERE is_active = 1 OR expires_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS membership_admin_actions (
  id TEXT PRIMARY KEY,
  actor_subject TEXT NOT NULL,
  target_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('reconcile')),
  result TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS membership_admin_actions_created_idx
ON membership_admin_actions(created_at DESC);
