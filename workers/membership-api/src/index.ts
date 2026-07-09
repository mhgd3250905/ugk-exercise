import { verifyGoogleIdToken } from "./google.js";
import {
  eventTimeIso,
  membershipIsActive,
} from "./membership_state.js";
import { createSession, json, requireSession } from "./session.js";
import type { Env, GoogleUser } from "./types.js";
import {
  verifyRevenueCatBodySignature,
  verifyRevenueCatSignature,
} from "./webhook_auth.js";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/auth/google") {
      return authGoogle(request, env);
    }
    if (request.method === "GET" && url.pathname === "/me") {
      return me(request, env);
    }
    if (request.method === "GET" && url.pathname === "/membership") {
      return membership(request, env);
    }
    if (request.method === "POST" && url.pathname === "/webhooks/revenuecat") {
      return revenueCatWebhook(request, env);
    }
    return json({ error: "not_found" }, 404);
  },
};

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
    await env.DB.prepare(
      "INSERT INTO users (id, display_name, email, avatar_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
    )
      .bind(
        userId,
        googleUser.name,
        googleUser.email,
        googleUser.picture ?? null,
        now,
        now,
      )
      .run();
    await env.DB.prepare(
      "INSERT INTO auth_identities (id, user_id, provider, provider_subject, email, email_verified, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
      .bind(
        crypto.randomUUID(),
        userId,
        "google",
        googleUser.sub,
        googleUser.email,
        googleUser.emailVerified ? 1 : 0,
        now,
      )
      .run();
  }

  const sessionToken = await createSession(env, userId);
  return json(await accountPayload(env, userId, sessionToken));
}

async function me(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }
  return json(await accountPayload(env, session.userId, null));
}

async function membership(request: Request, env: Env): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }
  const snapshot = await membershipPayload(env, session.userId);
  return json(snapshot);
}

async function revenueCatWebhook(
  request: Request,
  env: Env,
): Promise<Response> {
  const bodyText = await request.text();
  const revenueCatSignature = request.headers.get(
    "x-revenuecat-webhook-signature",
  );
  const rcSignature = request.headers.get("x-rc-signature");
  const isSigned = revenueCatSignature
    ? await verifyRevenueCatSignature(
        env.REVENUECAT_WEBHOOK_SECRET,
        bodyText,
        revenueCatSignature,
      )
    : await verifyRevenueCatBodySignature(
        env.REVENUECAT_WEBHOOK_SECRET,
        bodyText,
        rcSignature ?? "",
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

  const now = new Date().toISOString();
  const inserted = await env.DB.prepare(
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
  if (inserted.meta.changes === 0) {
    return json({ ok: true, duplicate: true });
  }

  const user = await env.DB.prepare("SELECT id FROM users WHERE id = ?")
    .bind(appUserId)
    .first<{ id: string }>();
  if (!user) {
    return json({ ok: true });
  }

  const entitlementIds = Array.isArray(event.entitlement_ids)
    ? event.entitlement_ids.map(String)
    : [];
  const expiresAtMs =
    typeof event.expiration_at_ms === "number" ? event.expiration_at_ms : null;
  const lastEventAt = eventTimeIso(event, now);
  const isActive =
    entitlementIds.includes("premium") &&
    (expiresAtMs === null || expiresAtMs > Date.now());
  const written = await env.DB.prepare(
    "INSERT INTO membership_snapshots (user_id, entitlement, is_active, expires_at, source, revenuecat_app_user_id, last_event_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET entitlement = excluded.entitlement, is_active = excluded.is_active, expires_at = excluded.expires_at, source = excluded.source, revenuecat_app_user_id = excluded.revenuecat_app_user_id, last_event_at = excluded.last_event_at, updated_at = excluded.updated_at WHERE membership_snapshots.last_event_at IS NULL OR excluded.last_event_at >= membership_snapshots.last_event_at",
  )
    .bind(
      appUserId,
      "premium",
      isActive ? 1 : 0,
      expiresAtMs === null ? null : new Date(expiresAtMs).toISOString(),
      "revenuecat_google_play",
      appUserId,
      lastEventAt,
      now,
    )
    .run();
  if (written.meta.changes === 0) {
    return json({ ok: true, ignored: "older_event" });
  }

  return json({ ok: true });
}

async function accountPayload(
  env: Env,
  userId: string,
  sessionToken: string | null,
): Promise<Record<string, unknown>> {
  const user = await env.DB.prepare(
    "SELECT id, display_name, email, avatar_url FROM users WHERE id = ?",
  )
    .bind(userId)
    .first<{
      id: string;
      display_name: string;
      email: string;
      avatar_url: string | null;
    }>();
  if (!user) {
    return { error: "user_not_found" };
  }
  return {
    ...(sessionToken === null ? {} : { sessionToken }),
    appUserId: user.id,
    user: {
      id: user.id,
      displayName: user.display_name,
      email: user.email,
      avatarUrl: user.avatar_url,
    },
    membership: await membershipPayload(env, userId),
  };
}

async function membershipPayload(env: Env, userId: string) {
  const snapshot = await env.DB.prepare(
    "SELECT entitlement, is_active, expires_at, source FROM membership_snapshots WHERE user_id = ?",
  )
    .bind(userId)
    .first<{
      entitlement: string;
      is_active: number;
      expires_at: string | null;
      source: string;
    }>();
  return {
    entitlement: snapshot?.entitlement ?? "premium",
    isActive: snapshot
      ? membershipIsActive(snapshot.is_active, snapshot.expires_at)
      : false,
    expiresAt: snapshot?.expires_at ?? null,
    source: snapshot?.source ?? "none",
  };
}
