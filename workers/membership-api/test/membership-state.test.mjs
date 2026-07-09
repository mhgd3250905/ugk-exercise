import assert from "node:assert/strict";
import test from "node:test";

import {
  eventTimeIso,
  membershipIsActive,
  shouldApplyMembershipEvent,
} from "../.tmp-test/membership_state.js";

test("expired membership snapshot is not active", () => {
  assert.equal(
    membershipIsActive(1, "2026-07-09T00:00:00.000Z", Date.parse("2026-07-10T00:00:00.000Z")),
    false,
  );
});

test("membership snapshot without expiry can be active", () => {
  assert.equal(membershipIsActive(1, null, Date.now()), true);
});

test("webhook event time uses RevenueCat event timestamp", () => {
  assert.equal(
    eventTimeIso({ event_timestamp_ms: Date.parse("2026-07-09T08:00:00.000Z") }, "2026-07-09T09:00:00.000Z"),
    "2026-07-09T08:00:00.000Z",
  );
});

test("older webhook event cannot overwrite newer membership snapshot", () => {
  assert.equal(
    shouldApplyMembershipEvent(
      "2026-07-09T08:00:00.000Z",
      "2026-07-09T09:00:00.000Z",
    ),
    false,
  );
  assert.equal(
    shouldApplyMembershipEvent(
      "2026-07-09T10:00:00.000Z",
      "2026-07-09T09:00:00.000Z",
    ),
    true,
  );
});
