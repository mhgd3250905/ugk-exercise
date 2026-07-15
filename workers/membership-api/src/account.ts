import { getAuthoritativeMembership } from "./membership_reconciliation.js";
import type { Env } from "./types.js";

export const avatarPolicyVersion = "2026-07-14";

export async function userPayload(
  env: Env,
  userId: string,
  requestUrl: string,
): Promise<Record<string, unknown> | null> {
  const user = await env.DB.prepare(
    "SELECT users.id, users.display_name, users.email, users.avatar_url, users.nickname, users.avatar_key, users.avatar_upload_suspended_at, avatar_objects.id AS custom_avatar_id, avatar_objects.status AS custom_avatar_status, EXISTS(SELECT 1 FROM avatar_policy_acceptances WHERE user_id = users.id AND policy_version = ?) AS avatar_policy_accepted FROM users LEFT JOIN avatar_objects ON avatar_objects.id = users.custom_avatar_object_id WHERE users.id = ?",
  )
    .bind(avatarPolicyVersion, userId)
    .first<{
      id: string;
      display_name: string;
      email: string;
      avatar_url: string | null;
      nickname: string | null;
      avatar_key: string | null;
      avatar_upload_suspended_at: string | null;
      custom_avatar_id: string | null;
      custom_avatar_status: string | null;
      avatar_policy_accepted: number;
    }>();
  if (!user) return null;
  const customAvatarUrl =
    user.custom_avatar_id && user.custom_avatar_status === "active"
      ? new URL(`/avatars/${user.custom_avatar_id}.jpg`, requestUrl).toString()
      : null;
  return {
    id: user.id,
    displayName: user.display_name,
    email: user.email,
    avatarUrl: user.avatar_url,
    nickname: user.nickname,
    avatarKey: user.avatar_key,
    customAvatarUrl,
    avatarPolicyVersion,
    avatarPolicyAccepted: user.avatar_policy_accepted === 1,
    avatarUploadSuspended: user.avatar_upload_suspended_at !== null,
  };
}

export async function accountPayload(
  env: Env,
  userId: string,
  sessionToken: string | null,
  requestUrl: string,
): Promise<Record<string, unknown>> {
  const user = await userPayload(env, userId, requestUrl);
  if (!user) return { error: "user_not_found" };
  return {
    ...(sessionToken === null ? {} : { sessionToken }),
    appUserId: userId,
    user,
    membership: await membershipPayload(env, userId),
  };
}

export async function membershipPayload(env: Env, userId: string) {
  const snapshot = await getAuthoritativeMembership(env, userId);
  return {
    entitlement: snapshot.entitlement,
    isActive: snapshot.isActive,
    expiresAt: snapshot.expiresAt,
    source: snapshot.source,
  };
}
