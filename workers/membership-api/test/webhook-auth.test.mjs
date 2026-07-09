import assert from "node:assert/strict";
import test from "node:test";

import {
  constantTimeEqual,
  hmacSha256Hex,
  verifyRevenueCatSignature,
} from "../.tmp-test/webhook_auth.js";

async function signedRevenueCatHeader(secret, body, timestampSeconds) {
  const signature = await hmacSha256Hex(
    secret,
    `${timestampSeconds}.${body}`,
  );
  return `t=${timestampSeconds},v1=${signature}`;
}

test("RevenueCat webhook signature rejects a bad HMAC", async () => {
  assert.equal(
    await verifyRevenueCatSignature(
      "unit-test-secret",
      '{"event":{"id":"evt_1"}}',
      "t=1783616400,v1=bad-signature",
    ),
    false,
  );
});

test("RevenueCat webhook signature accepts a fresh matching HMAC", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const timestamp = Math.floor(Date.now() / 1000) - 60;

  assert.equal(
    await verifyRevenueCatSignature(
      "unit-test-secret",
      body,
      await signedRevenueCatHeader("unit-test-secret", body, timestamp),
    ),
    true,
  );
});

test("RevenueCat webhook signature rejects an expired matching HMAC", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const timestamp = Math.floor(Date.now() / 1000) - 60 * 60;

  assert.equal(
    await verifyRevenueCatSignature(
      "unit-test-secret",
      body,
      await signedRevenueCatHeader("unit-test-secret", body, timestamp),
    ),
    false,
  );
});

test("RevenueCat webhook signature rejects a future replay outside the window", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const timestamp = Math.floor(Date.now() / 1000) + 60 * 60;

  assert.equal(
    await verifyRevenueCatSignature(
      "unit-test-secret",
      body,
      await signedRevenueCatHeader("unit-test-secret", body, timestamp),
    ),
    false,
  );
});

test("RevenueCat webhook signature accepts the current timestamp", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = await hmacSha256Hex(
    "unit-test-secret",
    `${timestamp}.${body}`,
  );

  assert.equal(
    await verifyRevenueCatSignature(
      "unit-test-secret",
      body,
      `t=${timestamp},v1=${signature}`,
    ),
    true,
  );
});

test("signature comparison rejects same-prefix strings", () => {
  assert.equal(
    constantTimeEqual(
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab",
    ),
    false,
  );
});
