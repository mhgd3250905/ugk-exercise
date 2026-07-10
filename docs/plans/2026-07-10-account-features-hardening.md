# Account Features Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Make account profile sync, workout cloud sync, history backfill, leaderboard participation, and D1 deployment safe under account switching, retries, time-zone changes, and adversarial input.

**Architecture:** Preserve local-first workout storage. Persist immutable workout facts and an optional account owner locally, upload only records owned by the captured account, and require explicit confirmation before claiming legacy ownerless history. Keep Worker writes idempotent and enforce membership, consent-window, and daily-limit rules at the database boundary.

**Tech Stack:** Flutter/Dart, ChangeNotifier controllers, local JSON store, Cloudflare Workers TypeScript, D1, Node test runner.

---

### Task 1: Immutable Local Workout Facts And Ownership

**Files:**
- Modify: `lib/product/workout_session_store.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `test/workout_session_store_test.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/workout_page_test.dart`

**Requirements:**
- Persist `startedAt`/`endedAt` as UTC instants, plus training-time `localDate` and `timezoneOffsetMinutes`.
- Add nullable immutable `ownerAppUserId`; legacy JSON remains readable with `ownerAppUserId == null`.
- New signed-in workouts receive the current account owner even when the account is free.
- Cloud requests use persisted facts and never derive them from the current device time zone.
- Same-ID merge keeps the local session; cloud-only sessions are appended.
- Serialize local store mutations so concurrent append/status updates cannot lose sessions.

**RED:** Add focused tests proving UTC/local metadata round-trips, persisted metadata drives `WorkoutSyncRequest`, A-owned pending records are not returned for B, concurrent writes retain both records, and local wins a same-ID merge. Run:

```powershell
flutter test test/workout_session_store_test.dart test/membership_api_client_test.dart test/workout_page_test.dart
```

Expected: new tests fail because ownership, offset persistence, mutation serialization, and local-priority merge are absent.

**GREEN:** Add only the model/store/request/page changes required by the failing tests. Do not claim legacy ownerless history.

**Verify:** Re-run the command; then run `flutter analyze`.

**Commit:** Explicitly stage only the six files above and commit `fix: bind local workouts to immutable facts`.

---

### Task 2: Account-Safe Background Sync And Explicit Legacy Claim

**Files:**
- Modify: `lib/control/workout_sync_controller.dart`
- Modify: `lib/control/account_controller.dart`
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated `lib/l10n/app_localizations*.dart`
- Modify: `test/workout_sync_controller_test.dart`
- Modify: `test/account_controller_test.dart`
- Modify: `test/profile_page_test.dart`

**Requirements:**
- `syncBatch` receives the captured account/token instead of rereading global account state.
- Filter pending records by `ownerAppUserId`; verify account identity after every asynchronous boundary before local status writes.
- Use one in-flight sync future to coalesce concurrent triggers.
- Trigger upload after a premium workout is queued and after restore/sign-in/premium activation; failures remain local and retry opportunistically.
- Legacy ownerless records are never auto-claimed. Profile UI shows an explicit premium-only confirmation action; confirmation assigns owner and queues those records.
- Add generation/session guards so stale `restore`, `signIn`, profile update, or RevenueCat work cannot resurrect/overwrite a signed-out or newer account.

**RED:** Add tests for A pending → B sync, account switch while network is suspended, concurrent `syncPending`, sign-in suspended → sign-out, restore racing sign-in, production trigger behavior, and explicit legacy claim only after confirmation.

```powershell
flutter test test/workout_sync_controller_test.dart test/account_controller_test.dart test/profile_page_test.dart
```

Expected: tests fail on missing owner filtering, post-await guards, trigger wiring, and claim UI.

**GREEN:** Implement the smallest controller APIs and wiring that satisfy these cases. No timer, background plugin, or new dependency.

**Verify:** Re-run focused tests and `flutter analyze`.

**Commit:** Explicitly stage touched files and commit `fix: make workout sync account safe`.

---

### Task 3: Profile Contract, Validation, And Diagnosable Errors

**Files:**
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/src/profile.ts`
- Modify: `workers/membership-api/test/profile.test.mjs`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/control/account_controller.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated `lib/l10n/app_localizations*.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/account_controller_test.dart`
- Modify: `test/profile_page_test.dart`

**Requirements:**
- `/auth/google` and `/me` return `nickname` and `avatarKey`.
- Allow letters, numbers, CJK characters, spaces, `_`, and `-`; reject control/punctuation-only input and reserved normalized names `admin`, `administrator`, `official`, `system`, `support`, `ugk`.
- Apply the 30-day cooldown and update `nickname_updated_at` only when normalized nickname changes; avatar-only changes remain allowed.
- Preserve Worker error codes in `MembershipApiException` and map known profile errors to localized UI text; never show raw exception strings.

**RED:** Add route/client/controller/widget tests for restored public profile, avatar-only update during cooldown, invalid/reserved nicknames, and localized `nickname_taken` / `nickname_change_too_soon` errors.

```powershell
Set-Location workers/membership-api; npm test -- test/profile.test.mjs
Set-Location ../..; flutter test test/membership_api_client_test.dart test/account_controller_test.dart test/profile_page_test.dart
```

**GREEN:** Implement the contract and narrow validation/error mapping.

**Verify:** Re-run focused tests, full Worker tests, and `flutter analyze`.

**Commit:** Explicitly stage touched files and commit `fix: complete public profile sync contract`.

---

### Task 4: Atomic Workout Limits And Consent-Safe Aggregation

**Files:**
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/src/workouts.ts`
- Modify: `workers/membership-api/test/workout-sync.test.mjs`

**Requirements:**
- Bound batch length and client session ID length.
- Validate `localDate` against `startedAt + timezoneOffsetMinutes`; reject materially future `endedAt`.
- Keep per-session max at 1000 reps and enforce a generous calibration constant of 5000 reps per Shanghai ranking day.
- Enforce the daily limit atomically with workout insertion so concurrent requests cannot exceed it; duplicates do not consume quota.
- Recheck current leaderboard join state and `joined_at` inside the aggregation SQL/batch instead of trusting a request-start snapshot.

**RED:** Add tests for per-batch cumulative overflow, duplicate quota behavior, invalid local date, future time, oversized batch/ID, and leave racing aggregation. Prefer real local D1 coverage where practical; fake tests must still validate SQL behavior explicitly.

```powershell
Set-Location workers/membership-api
npm test -- test/workout-sync.test.mjs
```

**GREEN:** Implement conditional database writes with no new service/dependency.

**Verify:** Run focused and full Worker tests.

**Commit:** Explicitly stage the three files and commit `fix: enforce atomic workout sync limits`.

---

### Task 5: Leaderboard Membership And Rejoin Semantics

**Files:**
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`

**Requirements:**
- Day/week queries include only joined users whose membership snapshot is currently active and unexpired.
- Repeated join while already joined preserves `joined_at` and totals.
- Rejoin after leave atomically writes a new `joined_at` and clears that user's current Shanghai week aggregates.
- New workouts after rejoin aggregate normally; prior/current-week old scores never revive.

**RED:** Add tests for expired members, idempotent repeated join, leave→rejoin clearing, and post-rejoin scoring.

```powershell
Set-Location workers/membership-api
npm test -- test/leaderboard.test.mjs
```

**GREEN:** Update the queries and join transaction only.

**Verify:** Run focused and full Worker tests.

**Commit:** Explicitly stage both files and commit `fix: enforce leaderboard eligibility windows`.

---

### Task 6: Repeatable D1 Deployment

**Files:**
- Modify: `workers/membership-api/schema.sql`
- Create: `workers/membership-api/migrations/0001_account_data_leaderboard.sql`
- Modify: `workers/membership-api/wrangler.toml` only if Wrangler requires a migrations directory setting
- Modify: `workers/membership-api/package.json`
- Create: `workers/membership-api/test/schema-migration.test.mjs`

**Requirements:**
- Fresh local D1 creation succeeds from `schema.sql`.
- An existing membership database upgrades through the migration without losing rows.
- Re-running the supported deployment command is safe; no bare `ALTER TABLE` remains in the repeatedly executed baseline path.
- Test verifies required user columns, workout/leaderboard tables, and indexes against real local SQLite/D1 state.

**RED:** Add the migration test and run it twice; confirm current schema fails on duplicate columns.

```powershell
Set-Location workers/membership-api
npm test -- test/schema-migration.test.mjs
```

**GREEN:** Separate fresh schema from one-time migration and add the smallest script needed to test it.

**Verify:** Run the migration test twice and full Worker tests.

**Commit:** Explicitly stage only migration-related files and commit `fix: add repeatable d1 migrations`.

---

### Task 7: Consent Controls And Stateful Leaderboard UI

**Files:**
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/main.dart`
- Modify: `lib/control/leaderboard_controller.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated `lib/l10n/app_localizations*.dart`
- Modify: `test/leaderboard_page_test.dart`
- Modify: `test/profile_page_test.dart`
- Create or modify: `test/home_page_test.dart`

**Requirements:**
- Home card distinguishes signed-out, free, premium-not-joined, and premium-joined states; joined state shows current day rank/count when available.
- Joined users can leave even with zero current-period score.
- Profile page exposes current public leaderboard state and a leave action.
- Period switches never display stale rows; account changes clear stale snapshots/errors.
- Known API errors are localized; raw exception strings are not rendered.

**RED:** Add widget/controller tests for all four home states, zero-score leave, profile opt-out, account switch clearing, and stale-period protection.

```powershell
flutter test test/home_page_test.dart test/leaderboard_page_test.dart test/leaderboard_controller_test.dart test/profile_page_test.dart
```

**GREEN:** Reuse existing controllers/models/widgets; do not add a new state-management dependency.

**Verify:** Run focused tests and `flutter analyze`.

**Commit:** Explicitly stage touched files and commit `fix: complete leaderboard consent ui`.

---

### Final Verification And Adversarial Review

Run:

```powershell
flutter analyze
flutter test
flutter build apk --release --split-per-abi
Set-Location workers/membership-api
npm test
Set-Location ../..
git diff --check c52eeba...HEAD
git status --short --branch
```

Required evidence:
- Flutter full suite passes and replay baselines remain `5/5/3`.
- Worker full suite, TypeScript check, build, and real migration test pass.
- Release APK builds.
- No recognition files, fixtures, credentials, or unrelated files changed.
- `docs/handoff-account-features.md` remains untracked and unstaged.
- Final fresh adversarial reviewer finds no Critical or Important issue.
