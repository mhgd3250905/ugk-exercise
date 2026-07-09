import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

const avatarKeys = new Set([
  "ring-green",
  "ring-lime",
  "ring-sky",
  "ring-yellow",
  "ring-coral",
  "bolt-green",
  "bolt-lime",
  "bolt-sky",
]);

export async function updateProfile(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }

  let body: {
    nickname?: unknown;
    avatarKey?: unknown;
  };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "invalid_json" }, 400);
  }
  if (typeof body.nickname !== "string") {
    return json({ error: "invalid_nickname" }, 400);
  }
  if (typeof body.avatarKey !== "string" || !avatarKeys.has(body.avatarKey)) {
    return json({ error: "invalid_avatar_key" }, 400);
  }

  const nickname = body.nickname.trim();
  const nicknameKey = normalizeNickname(nickname);
  if (nickname.length < 2 || nickname.length > 16 || nicknameKey.length < 2) {
    return json({ error: "invalid_nickname" }, 400);
  }

  const existing = await env.DB.prepare(
    "SELECT id FROM users WHERE nickname_key = ? AND id <> ?",
  )
    .bind(nicknameKey, session.userId)
    .first<{ id: string }>();
  if (existing) {
    return json({ error: "nickname_taken" }, 409);
  }

  const current = await env.DB.prepare(
    "SELECT display_name, email, avatar_url, nickname_updated_at FROM users WHERE id = ?",
  )
    .bind(session.userId)
    .first<{
      display_name: string;
      email: string;
      avatar_url: string | null;
      nickname_updated_at: string | null;
    }>();
  if (!current) {
    return json({ error: "user_not_found" }, 404);
  }
  const now = new Date();
  if (
    current.nickname_updated_at &&
    now.getTime() - Date.parse(current.nickname_updated_at) <
      30 * 24 * 60 * 60 * 1000
  ) {
    return json({ error: "nickname_change_too_soon" }, 409);
  }

  const nowIso = now.toISOString();
  try {
    await env.DB.prepare(
      "UPDATE users SET nickname = ?, nickname_key = ?, avatar_key = ?, nickname_updated_at = ?, updated_at = ? WHERE id = ?",
    )
      .bind(
        nickname,
        nicknameKey,
        body.avatarKey,
        nowIso,
        nowIso,
        session.userId,
      )
      .run();
  } catch (error) {
    if (isNicknameKeyConflict(error)) {
      return json({ error: "nickname_taken" }, 409);
    }
    throw error;
  }

  return json({
    user: {
      id: session.userId,
      displayName: current.display_name,
      email: current.email,
      avatarUrl: current.avatar_url,
      nickname,
      avatarKey: body.avatarKey,
    },
  });
}

export function normalizeNickname(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, "");
}

function isNicknameKeyConflict(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return (
    /unique constraint|constraint failed/i.test(message) &&
    /users\.nickname_key|nickname_key|users_nickname_key_idx/.test(message)
  );
}
