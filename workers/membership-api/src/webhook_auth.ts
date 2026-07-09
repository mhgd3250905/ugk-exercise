const encoder = new TextEncoder();
const hmacSha256HexLength = 64;
// RevenueCat t= uses Unix seconds. Five minutes covers normal clock skew and
// delivery latency while keeping captured webhook requests from replaying later.
const revenueCatSignatureToleranceSeconds = 5 * 60;

export async function verifyRevenueCatSignature(
  secret: string,
  body: string,
  signatureHeader: string,
): Promise<boolean> {
  const signature = parseRevenueCatSignature(signatureHeader);
  if (!secret || signature === null) {
    return false;
  }
  if (!isFreshTimestamp(signature.timestamp)) {
    return false;
  }
  const expected = await hmacSha256Hex(
    secret,
    `${signature.timestamp}.${body}`,
  );
  return constantTimeEqual(signature.value, expected);
}

export async function hmacSha256Hex(
  secret: string,
  body: string,
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
    encoder.encode(body),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function constantTimeEqual(left: string, right: string): boolean {
  let diff = left.length ^ hmacSha256HexLength;
  diff |= right.length ^ hmacSha256HexLength;
  for (let index = 0; index < hmacSha256HexLength; index += 1) {
    const leftCode = index < left.length ? left.charCodeAt(index) : 0;
    const rightCode = index < right.length ? right.charCodeAt(index) : 0;
    diff |= leftCode ^ rightCode;
  }
  return diff === 0;
}

function parseRevenueCatSignature(
  signature: string,
): { timestamp: string; value: string } | null {
  const fields = new Map(
    signature.split(",").map((part) => {
      const [key, value] = part.split("=", 2);
      return [key?.trim() ?? "", value?.trim() ?? ""];
    }),
  );
  const timestamp = fields.get("t") ?? "";
  const value = fields.get("v1") ?? "";
  return timestamp && value ? { timestamp, value } : null;
}

function isFreshTimestamp(timestamp: string): boolean {
  const timestampSeconds = Number(timestamp);
  if (!Number.isInteger(timestampSeconds)) {
    return false;
  }
  const nowSeconds = Math.floor(Date.now() / 1000);
  return (
    Math.abs(nowSeconds - timestampSeconds) <=
    revenueCatSignatureToleranceSeconds
  );
}
