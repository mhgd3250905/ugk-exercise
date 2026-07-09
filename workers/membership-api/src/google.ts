import { createRemoteJWKSet, jwtVerify } from "jose";

import type { Env, GoogleUser } from "./types.js";

const jwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

export async function verifyGoogleIdToken(
  env: Env,
  idToken: string,
): Promise<GoogleUser> {
  const { payload } = await jwtVerify(idToken, jwks, {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    audience: env.GOOGLE_CLIENT_ID,
  });
  const sub = payload.sub;
  const email = payload.email;
  if (!sub || typeof email !== "string") {
    throw new Error("invalid_google_payload");
  }
  return {
    sub,
    email,
    emailVerified: payload.email_verified === true,
    name: typeof payload.name === "string" ? payload.name : "训练者",
    picture: typeof payload.picture === "string" ? payload.picture : undefined,
  };
}
