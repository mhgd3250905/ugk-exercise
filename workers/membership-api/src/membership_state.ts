export function membershipIsActive(
  isActive: number,
  expiresAt: string | null,
  nowMs = Date.now(),
): boolean {
  return isActive === 1 && (expiresAt === null || Date.parse(expiresAt) > nowMs);
}

export function eventTimeIso(
  event: Record<string, unknown>,
  receivedAtIso: string,
): string {
  return typeof event.event_timestamp_ms === "number"
    ? new Date(event.event_timestamp_ms).toISOString()
    : receivedAtIso;
}

export function shouldApplyMembershipEvent(
  eventTime: string,
  currentLastEventAt: string | null,
): boolean {
  return currentLastEventAt === null || eventTime >= currentLastEventAt;
}
