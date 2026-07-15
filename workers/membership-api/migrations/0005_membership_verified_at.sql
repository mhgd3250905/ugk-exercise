-- Membership snapshots are a rebuildable cache of a RevenueCat observation.
-- NULL marks legacy rows that have not yet been verified by the reconciliation
-- path and therefore must be refreshed before they can grant access.

ALTER TABLE membership_snapshots ADD COLUMN verified_at TEXT;
