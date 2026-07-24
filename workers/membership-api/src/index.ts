import { verifyGoogleIdToken } from "./google.js";
import { appUpdate } from "./app_update.js";
import { accountPayload, membershipPayload } from "./account.js";
import {
  acceptAvatarPolicy,
  deleteAvatar,
  getAvatar,
  uploadAvatar,
} from "./avatar.js";
import {
  listUserBlocks,
  reportLeaderboardUser,
  updateUserBlock,
} from "./avatar_moderation.js";
import { handleAvatarAdmin } from "./admin.js";
import { eventTimeIso } from "./membership_state.js";
import {
  MembershipReconciliationError,
  reconcileMembership,
} from "./membership_reconciliation.js";
import {
  getLeaderboard,
  joinLeaderboard,
  leaveLeaderboard,
  updateLeaderboardIdentity,
} from "./leaderboard.js";
import { updateProfile } from "./profile.js";
import { createSession, json, requireSession } from "./session.js";
import type { Env, GoogleUser } from "./types.js";
import { verifyRevenueCatSignature } from "./webhook_auth.js";
import { getWorkouts, syncWorkouts } from "./workouts.js";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return await routeRequest(request, env);
    } catch (error) {
      if (error instanceof MembershipReconciliationError) {
        return json({ error: error.code }, 503);
      }
      throw error;
    }
  },
};

async function routeRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname === "/app-update") {
    return appUpdate(request);
  }
  if (
    url.pathname === "/admin" ||
    url.pathname === "/admin/members" ||
    url.pathname === "/admin/members/action" ||
    url.pathname === "/admin/avatar-reports" ||
    url.pathname === "/admin/avatar-reports/action"
  ) {
    return handleAvatarAdmin(request, env);
  }
    if (request.method === "POST" && url.pathname === "/auth/google") {
      return authGoogle(request, env);
    }
    if (request.method === "GET" && url.pathname === "/me") {
      return me(request, env);
    }
    if (request.method === "PATCH" && url.pathname === "/me/profile") {
      return updateProfile(request, env);
    }
    if (
      request.method === "POST" &&
      url.pathname === "/me/avatar-policy/accept"
    ) {
      return acceptAvatarPolicy(request, env);
    }
    if (request.method === "PUT" && url.pathname === "/me/avatar") {
      return uploadAvatar(request, env);
    }
    if (request.method === "DELETE" && url.pathname === "/me/avatar") {
      return deleteAvatar(request, env);
    }
    const avatarMatch = url.pathname.match(
      /^\/avatars\/([0-9a-f]{8}-[0-9a-f-]{27})\.jpg$/,
    );
    if (request.method === "GET" && avatarMatch) {
      return getAvatar(request, env, avatarMatch[1]);
    }
    if (request.method === "GET" && url.pathname === "/membership") {
      return membership(request, env);
    }
    if (
      request.method === "POST" &&
      url.pathname === "/membership/reconcile"
    ) {
      return reconcileMembershipRoute(request, env);
    }
    if (request.method === "POST" && url.pathname === "/webhooks/revenuecat") {
      return revenueCatWebhook(request, env);
    }
    if (request.method === "POST" && url.pathname === "/workouts/sync") {
      return syncWorkouts(request, env);
    }
    if (request.method === "GET" && url.pathname === "/workouts") {
      return getWorkouts(request, env);
    }
    if (request.method === "POST" && url.pathname === "/leaderboard/join") {
      return joinLeaderboard(request, env);
    }
    if (request.method === "POST" && url.pathname === "/leaderboard/leave") {
      return leaveLeaderboard(request, env);
    }
    if (
      request.method === "PATCH" &&
      url.pathname === "/leaderboard/identity"
    ) {
      return updateLeaderboardIdentity(request, env);
    }
    if (request.method === "GET" && url.pathname === "/leaderboard") {
      return getLeaderboard(request, env);
    }
    if (request.method === "GET" && url.pathname === "/me/blocks") {
      return listUserBlocks(request, env);
    }
    const reportMatch = url.pathname.match(
      /^\/leaderboard\/users\/([^/]+)\/report$/,
    );
    if (request.method === "POST" && reportMatch) {
      return reportLeaderboardUser(request, env, decodeURIComponent(reportMatch[1]));
    }
    const blockMatch = url.pathname.match(/^\/me\/blocks\/([^/]+)$/);
    if (
      blockMatch &&
      (request.method === "PUT" || request.method === "DELETE")
    ) {
      return updateUserBlock(
        request,
        env,
        decodeURIComponent(blockMatch[1]),
        request.method === "PUT",
      );
    }
  return json({ error: "not_found" }, 404);
}

async function authGoogle(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { idToken?: string };
  if (!body.idToken) {
    return json({ error: "missing_id_token" }, 400);
  }
  let googleUser: GoogleUser;
  try {
    googleUser = await verifyGoogleIdToken(env, body.idToken);
  } catch {
    return json({ error: "invalid_google_token" }, 401);
  }

  const now = new Date().toISOString();
  const existing = await env.DB.prepare(
    "SELECT user_id FROM auth_identities WHERE provider = ? AND provider_subject = ?",
  )
    .bind("google", googleUser.sub)
    .first<{ user_id: string }>();

  const userId = existing?.user_id ?? crypto.randomUUID();
  if (!existing) {
    // Create the user and its auth identity ATOMICALLY. The previous code ran
    // two independent `.run()` statements outside a transaction: a concurrent
    // login for the same Google subject could complete its `users` INSERT but
    // then fail the `auth_identities` INSERT on the UNIQUE(provider,
    // provider_subject) constraint, leaving an orphan `users` row that can
    // never be logged into (occupies the email and breaks the one-account-per-
    // identity invariant). A single D1 batch is one transaction: either both
    // inserts commit or both roll back.
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
      ).bind(
        userId,
        googleUser.name,
        googleUser.email,
        googleUser.picture ?? null,
        now,
        now,
      ),
      env.DB.prepare(
        "INSERT INTO auth_identities (id, user_id, provider, provider_subject, email, email_verified, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      ).bind(
        crypto.randomUUID(),
        userId,
        "google",
        googleUser.sub,
        googleUser.email,
        googleUser.emailVerified ? 1 : 0,
        now,
      ),
    ]);
  }

  const sessionToken = await createSession(env, userId);
  return json(await accountPayload(env, userId, sessionToken, request.url));
}

async function me(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }
  return json(await accountPayload(env, session.userId, null, request.url));
}

async function membership(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }
  const snapshot = await membershipPayload(env, session.userId);
  return json(snapshot);
}

async function reconcileMembershipRoute(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }
  const snapshot = await reconcileMembership(env, session.userId);
  return json({
    entitlement: snapshot.entitlement,
    isActive: snapshot.isActive,
    expiresAt: snapshot.expiresAt,
    source: snapshot.source,
  });
}

async function revenueCatWebhook(
  request: Request,
  env: Env,
): Promise<Response> {
  const bodyText = await request.text();
  const revenueCatSignature = request.headers.get(
    "x-revenuecat-webhook-signature",
  );
  const isSigned = await verifyRevenueCatSignature(
    env.REVENUECAT_WEBHOOK_SECRET,
    bodyText,
    revenueCatSignature ?? "",
  );
  if (!isSigned) {
    return json({ error: "unauthorized" }, 401);
  }
  let payload: { event?: Record<string, unknown> };
  try {
    payload = JSON.parse(bodyText) as { event?: Record<string, unknown> };
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const event = payload.event ?? {};
  if (typeof event.id !== "string" || event.id.length === 0) {
    return json({ ok: true, ignored: "missing_event_id" });
  }
  const eventId = event.id;
  const eventType = String(event.type ?? "UNKNOWN");
  const appUserId = String(event.app_user_id ?? "");
  if (!appUserId) {
    return json({ ok: true });
  }

  // Claim the event id BEFORE doing any external work. The previous code read
  // `processed_at`, then called reconcileMembership (an external RevenueCat
  // request plus a snapshot write), and only then inserted the idempotency
  // record. Two concurrent webhooks for the same event.id both passed the read
  // check and both performed the external work. Claiming first with
  // INSERT OR IGNORE turns the idempotency check into the single source of
  // truth: only the request that wins the insert proceeds to reconcile, the
  // loser returns duplicate without touching RevenueCat or the snapshot.
  const user = await env.DB.prepare("SELECT id FROM users WHERE id = ?")
    .bind(appUserId)
    .first<{ id: string }>();
  if (!user) {
    return json({ ok: true });
  }

  const now = new Date().toISOString();
  const claim = await env.DB.prepare(
    "INSERT OR IGNORE INTO webhook_events (id, provider, event_id, event_type, received_at, processed_at, payload_json) VALUES (?, ?, ?, ?, ?, ?, ?)",
  )
    .bind(
      crypto.randomUUID(),
      "revenuecat",
      eventId,
      eventType,
      now,
      now,
      JSON.stringify(payload),
    )
    .run();
  if (claim.meta.changes === 0) {
    // Another request already claimed this event id; do not duplicate the
    // external RevenueCat call or the snapshot write.
    return json({ ok: true, duplicate: true });
  }

  const lastEventAt = eventTimeIso(event, now);
  try {
    await reconcileMembership(env, appUserId, { eventAt: lastEventAt });
  } catch (error) {
    // Reconciliation failed (e.g. RevenueCat returned 5xx). Release the claim
    // so RevenueCat can retry the same event id and re-drive reconciliation,
    // then surface the failure as a retryable 503. Holding the claim would
    // permanently mask a transient downstream outage as "already processed".
    await env.DB.prepare(
      "DELETE FROM webhook_events WHERE provider = ? AND event_id = ?",
    )
      .bind("revenuecat", eventId)
      .run();
    throw error;
  }

  return json({ ok: true });
}
