import type { Env } from "./types";

const encoder = new TextEncoder();

export async function createSession(env: Env, userId: string): Promise<string> {
  const raw = crypto.randomUUID() + "." + crypto.randomUUID();
  const tokenHash = await hashToken(env, raw);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 1000 * 60 * 60 * 24 * 30);
  await env.DB.prepare(
    "INSERT INTO sessions (token_hash, user_id, app_user_id, expires_at, created_at) VALUES (?, ?, ?, ?, ?)",
  )
    .bind(tokenHash, userId, userId, expiresAt.toISOString(), now.toISOString())
    .run();
  return raw;
}

export async function requireSession(
  env: Env,
  request: Request,
): Promise<{ userId: string; appUserId: string } | Response> {
  const header = request.headers.get("authorization") ?? "";
  const token = header.startsWith("Bearer ")
    ? header.slice("Bearer ".length)
    : "";
  if (!token) {
    return json({ error: "missing_token" }, 401);
  }
  const tokenHash = await hashToken(env, token);
  const row = await env.DB.prepare(
    "SELECT user_id, app_user_id, expires_at FROM sessions WHERE token_hash = ?",
  )
    .bind(tokenHash)
    .first<{ user_id: string; app_user_id: string; expires_at: string }>();
  if (!row || new Date(row.expires_at).getTime() <= Date.now()) {
    return json({ error: "invalid_token" }, 401);
  }
  return { userId: row.user_id, appUserId: row.app_user_id };
}

export async function hashToken(env: Env, token: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(env.SESSION_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(token));
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
