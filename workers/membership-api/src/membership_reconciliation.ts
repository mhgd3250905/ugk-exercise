import type { Env } from "./types.js";
import { membershipIsActive } from "./membership_state.js";

const revenueCatBaseUrl = "https://api.revenuecat.com/v1/subscribers";
const verifiedCacheTtlMs = 5 * 60 * 1000;

type ReconciliationEnv = Pick<Env, "DB" | "REVENUECAT_SECRET_API_KEY">;

export interface MembershipSnapshot {
  entitlement: "premium";
  isActive: boolean;
  expiresAt: string | null;
  source: string;
  verifiedAt: string;
}

interface CachedMembershipSnapshot {
  snapshot: MembershipSnapshot;
  wasActiveWhenVerified: boolean;
}

interface PremiumObservation {
  isActive: boolean;
  expiresAt: string | null;
  hasEntitlement: boolean;
  productIdentifier: string | null;
  purchaseAt: string | null;
  originalPurchaseAt: string | null;
  periodType: string | null;
  store: string | null;
  isSandbox: boolean | null;
  ownershipType: string | null;
  unsubscribeDetectedAt: string | null;
  billingIssueDetectedAt: string | null;
}

export interface ReconciliationOptions {
  fetcher?: typeof fetch;
  now?: Date;
  eventAt?: string | null;
}

export class MembershipReconciliationError extends Error {
  readonly code = "membership_sync_unavailable";

  constructor(options?: ErrorOptions) {
    super("RevenueCat membership reconciliation failed", options);
    this.name = "MembershipReconciliationError";
  }
}

export async function getAuthoritativeMembership(
  env: ReconciliationEnv,
  userId: string,
  options: ReconciliationOptions = {},
): Promise<MembershipSnapshot> {
  const now = options.now ?? new Date();
  const cached = await readSnapshot(env, userId, now.getTime());
  if (
    cached !== null &&
    cacheIsFresh(cached.snapshot.verifiedAt, now.getTime()) &&
    // A previously active entitlement reaching its recorded expiry can no
    // longer prove current state because RevenueCat may already have renewed it.
    (!cached.wasActiveWhenVerified || cached.snapshot.isActive)
  ) {
    return cached.snapshot;
  }
  return reconcileMembership(env, userId, { ...options, now });
}

export async function reconcileMembership(
  env: ReconciliationEnv,
  userId: string,
  options: ReconciliationOptions = {},
): Promise<MembershipSnapshot> {
  const now = options.now ?? new Date();
  const verifiedAt = now.toISOString();
  const fetcher = options.fetcher ?? fetch;
  let payload: unknown;

  try {
    const response = await fetcher(
      `${revenueCatBaseUrl}/${encodeURIComponent(userId)}`,
      {
        method: "GET",
        headers: {
          accept: "application/json",
          authorization: `Bearer ${env.REVENUECAT_SECRET_API_KEY}`,
        },
      },
    );
    if (!response.ok) throw new Error(`RevenueCat returned ${response.status}`);
    payload = await response.json();
  } catch (error) {
    throw new MembershipReconciliationError({ cause: error });
  }

  let current: PremiumObservation;
  try {
    current = currentPremiumEntitlement(payload, now.getTime());
  } catch (error) {
    throw new MembershipReconciliationError({ cause: error });
  }

  await env.DB.prepare(
    "INSERT INTO membership_snapshots (user_id, entitlement, is_active, expires_at, source, revenuecat_app_user_id, last_event_at, updated_at, verified_at, has_entitlement, product_identifier, purchase_at, original_purchase_at, period_type, store, is_sandbox, ownership_type, unsubscribe_detected_at, billing_issue_detected_at) VALUES (?, 'premium', ?, ?, 'revenuecat_verified', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET entitlement = excluded.entitlement, is_active = excluded.is_active, expires_at = excluded.expires_at, source = excluded.source, revenuecat_app_user_id = excluded.revenuecat_app_user_id, last_event_at = CASE WHEN excluded.last_event_at IS NULL THEN membership_snapshots.last_event_at WHEN membership_snapshots.last_event_at IS NULL OR excluded.last_event_at >= membership_snapshots.last_event_at THEN excluded.last_event_at ELSE membership_snapshots.last_event_at END, updated_at = excluded.updated_at, verified_at = excluded.verified_at, has_entitlement = MAX(membership_snapshots.has_entitlement, excluded.has_entitlement), product_identifier = COALESCE(excluded.product_identifier, membership_snapshots.product_identifier), purchase_at = COALESCE(excluded.purchase_at, membership_snapshots.purchase_at), original_purchase_at = COALESCE(excluded.original_purchase_at, membership_snapshots.original_purchase_at), period_type = COALESCE(excluded.period_type, membership_snapshots.period_type), store = COALESCE(excluded.store, membership_snapshots.store), is_sandbox = COALESCE(excluded.is_sandbox, membership_snapshots.is_sandbox), ownership_type = COALESCE(excluded.ownership_type, membership_snapshots.ownership_type), unsubscribe_detected_at = CASE WHEN excluded.has_entitlement = 1 THEN excluded.unsubscribe_detected_at ELSE membership_snapshots.unsubscribe_detected_at END, billing_issue_detected_at = CASE WHEN excluded.has_entitlement = 1 THEN excluded.billing_issue_detected_at ELSE membership_snapshots.billing_issue_detected_at END WHERE membership_snapshots.verified_at IS NULL OR excluded.verified_at >= membership_snapshots.verified_at",
  )
    .bind(
      userId,
      current.isActive ? 1 : 0,
      current.expiresAt,
      userId,
      options.eventAt ?? null,
      verifiedAt,
      verifiedAt,
      current.hasEntitlement ? 1 : 0,
      current.productIdentifier,
      current.purchaseAt,
      current.originalPurchaseAt,
      current.periodType,
      current.store,
      current.isSandbox === null ? null : current.isSandbox ? 1 : 0,
      current.ownershipType,
      current.unsubscribeDetectedAt,
      current.billingIssueDetectedAt,
    )
    .run();

  const stored = await env.DB.prepare(
    "SELECT entitlement, is_active, expires_at, source, verified_at FROM membership_snapshots WHERE user_id = ?",
  )
    .bind(userId)
    .first<{
      entitlement: string;
      is_active: number;
      expires_at: string | null;
      source: string;
      verified_at: string;
    }>();
  if (!stored || stored.verified_at === null) {
    throw new MembershipReconciliationError();
  }
  return {
    entitlement: "premium",
    isActive: stored.is_active === 1,
    expiresAt: stored.expires_at,
    source: stored.source,
    verifiedAt: stored.verified_at,
  };
}

async function readSnapshot(
  env: ReconciliationEnv,
  userId: string,
  nowMs: number,
): Promise<CachedMembershipSnapshot | null> {
  const row = await env.DB.prepare(
    "SELECT entitlement, is_active, expires_at, source, verified_at FROM membership_snapshots WHERE user_id = ?",
  )
    .bind(userId)
    .first<{
      entitlement: string;
      is_active: number;
      expires_at: string | null;
      source: string;
      verified_at: string | null;
  }>();
  if (row === null || row.verified_at === null) return null;
  return {
    snapshot: {
      entitlement: "premium",
      isActive: membershipIsActive(row.is_active, row.expires_at, nowMs),
      expiresAt: row.expires_at,
      source: row.source,
      verifiedAt: row.verified_at,
    },
    wasActiveWhenVerified: row.is_active === 1,
  };
}

function cacheIsFresh(verifiedAt: string, nowMs: number): boolean {
  const verifiedMs = Date.parse(verifiedAt);
  if (!Number.isFinite(verifiedMs)) return false;
  const ageMs = nowMs - verifiedMs;
  return ageMs >= -60 * 1000 && ageMs <= verifiedCacheTtlMs;
}

function currentPremiumEntitlement(
  payload: unknown,
  nowMs: number,
): PremiumObservation {
  const root = asRecord(payload);
  const subscriber = asRecord(root.subscriber);
  const entitlements = asRecord(subscriber.entitlements);
  const premium = entitlements.premium;
  if (premium === undefined || premium === null) {
    return emptyObservation();
  }

  const fields = asRecord(premium);
  const expiresAt = isoOrNull(fields.expires_date, "expires_date");
  const gracePeriodExpiresAt = optionalIsoOrNull(
    fields.grace_period_expires_date,
    "grace_period_expires_date",
  );
  const productIdentifier = optionalString(fields.product_identifier);
  const subscriptions = optionalRecord(subscriber.subscriptions);
  const subscription =
    productIdentifier === null
      ? null
      : optionalRecord(subscriptions?.[productIdentifier]);
  const metadata = {
    hasEntitlement: true,
    productIdentifier,
    purchaseAt:
      optionalIso(subscription?.purchase_date) ?? optionalIso(fields.purchase_date),
    originalPurchaseAt: optionalIso(subscription?.original_purchase_date),
    periodType: optionalString(subscription?.period_type),
    store: optionalString(subscription?.store),
    isSandbox: optionalBoolean(subscription?.is_sandbox),
    ownershipType: optionalString(subscription?.ownership_type),
    unsubscribeDetectedAt: optionalIso(subscription?.unsubscribe_detected_at),
    billingIssueDetectedAt: optionalIso(
      subscription?.billing_issues_detected_at,
    ),
  };
  if (expiresAt === null) {
    return { isActive: true, expiresAt: null, ...metadata };
  }
  const effectiveExpiry = laterExpiry(expiresAt, gracePeriodExpiresAt);
  return {
    isActive: Date.parse(effectiveExpiry) > nowMs,
    expiresAt: effectiveExpiry,
    ...metadata,
  };
}

function emptyObservation(): PremiumObservation {
  return {
    isActive: false,
    expiresAt: null,
    hasEntitlement: false,
    productIdentifier: null,
    purchaseAt: null,
    originalPurchaseAt: null,
    periodType: null,
    store: null,
    isSandbox: null,
    ownershipType: null,
    unsubscribeDetectedAt: null,
    billingIssueDetectedAt: null,
  };
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("RevenueCat response has an invalid shape");
  }
  return value as Record<string, unknown>;
}

function optionalRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function optionalBoolean(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function optionalIso(value: unknown): string | null {
  return typeof value === "string" && Number.isFinite(Date.parse(value))
    ? new Date(value).toISOString()
    : null;
}

function isoOrNull(value: unknown, field: string): string | null {
  if (value === null) return null;
  if (typeof value !== "string" || !Number.isFinite(Date.parse(value))) {
    throw new Error(`RevenueCat ${field} is invalid`);
  }
  return new Date(value).toISOString();
}

function optionalIsoOrNull(value: unknown, field: string): string | null {
  if (value === undefined || value === null) return null;
  return isoOrNull(value, field);
}

function laterExpiry(first: string, second: string | null): string {
  if (second === null) return first;
  return Date.parse(second) > Date.parse(first) ? second : first;
}
