import assert from "node:assert/strict";
import test from "node:test";

import {
  constantTimeEqual,
  hmacSha256Hex,
  verifyRevenueCatBodySignature,
  verifyRevenueCatSignature,
} from "../.tmp-test/webhook_auth.js";

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

test("RevenueCat webhook signature accepts a matching HMAC", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const timestamp = "1783616400";
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

test("legacy X-RC-Signature style raw body HMAC is supported", async () => {
  const body = '{"event":{"id":"evt_1"}}';
  const signature = await hmacSha256Hex("unit-test-secret", body);

  assert.equal(
    await verifyRevenueCatBodySignature("unit-test-secret", body, signature),
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
