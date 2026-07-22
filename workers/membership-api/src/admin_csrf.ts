const tokenPrefix = "admin-csrf:v1:";
const tokenPattern = /^[0-9a-f]{64}$/;
const encoder = new TextEncoder();

export async function createAdminCsrfToken(
  secret: string,
  actor: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${tokenPrefix}${actor}`),
  );
  return Array.from(new Uint8Array(signature), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

export async function verifyAdminCsrfToken(
  secret: string,
  actor: string,
  token: string,
): Promise<boolean> {
  if (!tokenPattern.test(token)) return false;
  const expected = await createAdminCsrfToken(secret, actor);
  let difference = 0;
  for (let index = 0; index < expected.length; index += 1) {
    difference |= expected.charCodeAt(index) ^ token.charCodeAt(index);
  }
  return difference === 0;
}
