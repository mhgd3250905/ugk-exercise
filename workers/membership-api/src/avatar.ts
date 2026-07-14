import {
  avatarPolicyVersion,
  userPayload,
} from "./account.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

const maxAvatarBytes = 1024 * 1024;
const maxAvatarDimension = 512;

class AvatarReadError extends Error {}

export async function readAvatarBytes(
  request: Request,
  limit = maxAvatarBytes,
): Promise<Uint8Array> {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > limit) {
      void reader.cancel().catch(() => {});
      throw new AvatarReadError("avatar_too_large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

export function parseJpegDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  if (
    bytes.length < 6 ||
    bytes[0] !== 0xff ||
    bytes[1] !== 0xd8 ||
    bytes.at(-2) !== 0xff ||
    bytes.at(-1) !== 0xd9
  ) {
    return null;
  }
  const sofMarkers = new Set([
    0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce,
    0xcf,
  ]);
  let offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    while (offset < bytes.length && bytes[offset] === 0xff) offset += 1;
    const marker = bytes[offset];
    if (marker === 0xd9) break;
    offset += 1;
    if (offset + 1 >= bytes.length) return null;
    const segmentLength = (bytes[offset] << 8) | bytes[offset + 1];
    if (segmentLength < 2 || offset + segmentLength > bytes.length) {
      return null;
    }
    if (sofMarkers.has(marker)) {
      if (segmentLength < 7) return null;
      return {
        height: (bytes[offset + 3] << 8) | bytes[offset + 4],
        width: (bytes[offset + 5] << 8) | bytes[offset + 6],
      };
    }
    offset += segmentLength;
  }
  return null;
}

export async function acceptAvatarPolicy(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (
    body === null ||
    typeof body !== "object" ||
    Array.isArray(body) ||
    (body as Record<string, unknown>).policyVersion !== avatarPolicyVersion
  ) {
    return json({ error: "invalid_policy_version" }, 400);
  }
  await env.DB.prepare(
    "INSERT OR IGNORE INTO avatar_policy_acceptances (user_id, policy_version, accepted_at) VALUES (?, ?, ?)",
  )
    .bind(session.userId, avatarPolicyVersion, new Date().toISOString())
    .run();
  return json({ ok: true, policyVersion: avatarPolicyVersion });
}

export async function uploadAvatar(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const state = await env.DB.prepare(
    "SELECT custom_avatar_object_id, avatar_upload_suspended_at, EXISTS(SELECT 1 FROM avatar_policy_acceptances WHERE user_id = ? AND policy_version = ?) AS policy_accepted FROM users WHERE id = ?",
  )
    .bind(session.userId, avatarPolicyVersion, session.userId)
    .first<{
      custom_avatar_object_id: string | null;
      avatar_upload_suspended_at: string | null;
      policy_accepted: number;
    }>();
  if (!state) return json({ error: "user_not_found" }, 404);
  if (state.policy_accepted !== 1) {
    return json({ error: "avatar_policy_required" }, 409);
  }
  if (state.avatar_upload_suspended_at !== null) {
    return json({ error: "avatar_upload_suspended" }, 403);
  }
  if (request.headers.get("content-type")?.split(";", 1)[0] !== "image/jpeg") {
    return json({ error: "invalid_avatar_format" }, 400);
  }

  let bytes: Uint8Array;
  try {
    bytes = await readAvatarBytes(request);
  } catch (error) {
    if (error instanceof AvatarReadError) {
      return json({ error: error.message }, 413);
    }
    throw error;
  }
  const dimensions = parseJpegDimensions(bytes);
  if (!dimensions) return json({ error: "invalid_avatar_format" }, 400);
  if (
    dimensions.width !== dimensions.height ||
    dimensions.width < 1 ||
    dimensions.width > maxAvatarDimension
  ) {
    return json({ error: "invalid_avatar_dimensions" }, 400);
  }

  const objectId = crypto.randomUUID();
  const objectKey = `avatars/${objectId}.jpg`;
  try {
    await env.AVATAR_BUCKET.put(objectKey, bytes, {
      httpMetadata: { contentType: "image/jpeg" },
    });
  } catch {
    return json({ error: "avatar_upload_failed" }, 503);
  }

  const now = new Date().toISOString();
  try {
    const statements = [
      env.DB.prepare(
        "INSERT INTO avatar_objects (id, user_id, object_key, status, created_at) VALUES (?, ?, ?, 'active', ?)",
      ).bind(objectId, session.userId, objectKey, now),
      env.DB.prepare(
        "UPDATE users SET custom_avatar_object_id = ?, updated_at = ? WHERE id = ?",
      ).bind(objectId, now, session.userId),
    ];
    if (state.custom_avatar_object_id) {
      statements.push(
        env.DB.prepare(
          "UPDATE avatar_objects SET status = 'replaced' WHERE id = ? AND user_id = ? AND status = 'active'",
        ).bind(state.custom_avatar_object_id, session.userId),
      );
    }
    await env.DB.batch(statements);
  } catch {
    try {
      await env.AVATAR_BUCKET.delete(objectKey);
    } catch {
      // The unregistered random key is not publicly readable and can be swept.
    }
    return json({ error: "avatar_upload_failed" }, 503);
  }

  if (state.custom_avatar_object_id) {
    await deleteStoredObject(env, state.custom_avatar_object_id, now);
  }
  const user = await userPayload(env, session.userId, request.url);
  return json({ user });
}

export async function deleteAvatar(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const current = await env.DB.prepare(
    "SELECT users.custom_avatar_object_id, avatar_objects.object_key FROM users LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id WHERE users.id = ?",
  )
    .bind(session.userId)
    .first<{
      custom_avatar_object_id: string | null;
      object_key: string | null;
    }>();
  if (!current) return json({ error: "user_not_found" }, 404);
  if (current.custom_avatar_object_id) {
    const now = new Date().toISOString();
    await env.DB.batch([
      env.DB.prepare(
        "UPDATE users SET custom_avatar_object_id = NULL, updated_at = ? WHERE id = ?",
      ).bind(now, session.userId),
      env.DB.prepare(
        "UPDATE avatar_objects SET status = 'removed' WHERE id = ? AND user_id = ?",
      ).bind(current.custom_avatar_object_id, session.userId),
    ]);
    if (current.object_key) {
      try {
        await env.AVATAR_BUCKET.delete(current.object_key);
        await env.DB.prepare(
          "UPDATE avatar_objects SET deleted_at = ? WHERE id = ?",
        )
          .bind(now, current.custom_avatar_object_id)
          .run();
      } catch {
        // The D1 state already prevents reads; a later sweep can retry deletion.
      }
    }
  }
  return json({ user: await userPayload(env, session.userId, request.url) });
}

export async function getAvatar(
  request: Request,
  env: Env,
  objectId: string,
): Promise<Response> {
  const row = await env.DB.prepare(
    "SELECT avatar_objects.object_key FROM avatar_objects INNER JOIN users ON users.id = avatar_objects.user_id AND users.custom_avatar_object_id = avatar_objects.id WHERE avatar_objects.id = ? AND avatar_objects.status = 'active' AND users.public_avatar_hidden_at IS NULL",
  )
    .bind(objectId)
    .first<{ object_key: string }>();
  if (!row) return json({ error: "not_found" }, 404);
  const object = await env.AVATAR_BUCKET.get(row.object_key);
  if (!object) return json({ error: "not_found" }, 404);
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("content-type", "image/jpeg");
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", "public, max-age=300");
  return new Response(object.body, { headers });
}

async function deleteStoredObject(
  env: Env,
  objectId: string,
  deletedAt: string,
): Promise<void> {
  const object = await env.DB.prepare(
    "SELECT object_key FROM avatar_objects WHERE id = ?",
  )
    .bind(objectId)
    .first<{ object_key: string }>();
  if (!object) return;
  try {
    await env.AVATAR_BUCKET.delete(object.object_key);
    await env.DB.prepare(
      "UPDATE avatar_objects SET deleted_at = ? WHERE id = ?",
    )
      .bind(deletedAt, objectId)
      .run();
  } catch {
    // A replaced object is no longer readable; retain it for cleanup retry.
  }
}

export async function deleteAllAvatarObjects(
  env: Env,
  userId: string,
): Promise<void> {
  const result = await env.DB.prepare(
    "SELECT id, object_key FROM avatar_objects WHERE user_id = ? AND deleted_at IS NULL",
  )
    .bind(userId)
    .all<{ id: string; object_key: string }>();
  const now = new Date().toISOString();
  await env.DB.batch([
    env.DB.prepare(
      "UPDATE users SET custom_avatar_object_id = NULL, public_avatar_hidden_at = ?, updated_at = ? WHERE id = ?",
    ).bind(now, now, userId),
    env.DB.prepare(
      "UPDATE avatar_objects SET status = 'removed' WHERE user_id = ? AND deleted_at IS NULL",
    ).bind(userId),
  ]);
  let failed = false;
  for (const object of result.results) {
    try {
      await env.AVATAR_BUCKET.delete(object.object_key);
      await env.DB.prepare(
        "UPDATE avatar_objects SET deleted_at = ? WHERE id = ?",
      )
        .bind(now, object.id)
        .run();
    } catch {
      failed = true;
    }
  }
  if (failed) throw new Error("avatar_cleanup_failed");
}
