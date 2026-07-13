# Leaderboard Pagination Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Preload and cache day/week leaderboards, switch without network requests, refresh both boards on pull, and load 20 additional rows through an opaque server cursor near the list bottom.

**Architecture:** Extend the existing `/leaderboard` response with nullable `nextCursor`; keep the cursor opaque to Flutter and page inside the Worker without a D1 schema change. `LeaderboardController` owns independent day/week snapshots and pagination state; `LeaderboardPage` only selects cached state, triggers refresh-all, and requests the next page from its existing scrollable.

**Tech Stack:** Flutter/Dart, package:http, ChangeNotifier, Cloudflare Workers TypeScript, D1, Node test runner.

---

### Task 1: Worker cursor contract

**Files:**
- Modify: `workers/membership-api/src/leaderboard.ts`
- Test: `workers/membership-api/test/leaderboard.test.mjs`
- Test: `workers/membership-api/test/leaderboard-sql.test.mjs`

**Step 1: Write the failing tests**

- Assert the first response contains ranks 1–20 and a non-null `nextCursor` when at least 21 users rank.
- Request the returned cursor and assert the next response starts at rank 21 without duplicates.
- Assert the last page returns `nextCursor: null`.
- Assert malformed or period-mismatched cursors return `invalid_leaderboard_query` with HTTP 400.

**Step 2: Verify RED**

Run: `cd workers/membership-api && npm test`

Expected: FAIL because `/leaderboard` still returns up to 100 rows and has no cursor contract.

**Step 3: Implement the minimum Worker behavior**

- Add a fixed page size of 20.
- Encode the last row's ordering tuple (`totalValue`, `userId`) plus period/exercise type as URL-safe base64 JSON.
- Decode and validate the optional `cursor` query parameter.
- Select the next 20 ranked rows after the cursor and include `nextCursor` in the JSON response.
- Preserve `me`, identity, membership, and privacy behavior on every page.
- Keep the cursor API opaque so D1 keyset pagination can replace the initial in-memory ranking later without changing Flutter.

**Step 4: Verify GREEN**

Run: `cd workers/membership-api && npm test`

Expected: all Worker tests pass.

**Step 5: Commit**

Explicitly stage only the Worker source/tests and commit `feat: paginate leaderboard API`.

### Task 2: Flutter response model and API client

**Files:**
- Modify: `lib/product/leaderboard_models.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Test: `test/membership_api_client_test.dart`

**Step 1: Write the failing tests**

- Parse nullable `nextCursor` from a leaderboard response.
- Assert a provided cursor is sent as the `cursor` query parameter.
- Preserve compatibility when older fixtures omit `nextCursor`.

**Step 2: Verify RED**

Run: `flutter test test/membership_api_client_test.dart`

Expected: FAIL because the model/client do not expose a cursor.

**Step 3: Implement the minimum client behavior**

- Add `String? nextCursor` to `LeaderboardSnapshot`, defaulting to null.
- Add an optional `cursor` named argument to `MembershipApiClient.leaderboard` and include it only when non-null.

**Step 4: Verify GREEN**

Run: `flutter test test/membership_api_client_test.dart`

Expected: all client tests pass.

**Step 5: Commit**

Explicitly stage the two production files and one test file; commit `feat: support leaderboard cursors`.

### Task 3: Controller dual-cache and pagination state

**Files:**
- Modify: `lib/control/leaderboard_controller.dart`
- Modify: `lib/main.dart`
- Test: `test/leaderboard_controller_test.dart`

**Step 1: Write the failing tests**

- `refreshAll()` requests day and week once and stores both snapshots.
- Selecting a cached period performs no request.
- Refresh replaces both first pages.
- `loadMore(period)` sends that period's cursor, appends unique rows, and updates `nextCursor`.
- Duplicate load-more calls, absent cursors, stale account results, and refresh races do not append stale data.
- Load-more failure preserves rows and exposes retryable per-period state.
- Join/update/leave refresh both cached first pages.

**Step 2: Verify RED**

Run: `flutter test test/leaderboard_controller_test.dart`

Expected: FAIL because the controller currently stores only one snapshot.

**Step 3: Implement the minimum controller behavior**

- Keep snapshots and errors keyed by `LeaderboardPeriod`.
- Add `snapshotFor`, `errorFor`, `refreshAll`, `loadMore`, `isLoadingMore`, and `loadMoreErrorFor`.
- Keep the existing first-page loader for compatibility; add an optional cursor loader used only by `loadMore`.
- Preserve session token/app user guards after every await.
- Wire the cursor loader in `lib/main.dart`.

**Step 4: Verify GREEN**

Run: `flutter test test/leaderboard_controller_test.dart`

Expected: all controller tests pass.

**Step 5: Commit**

Explicitly stage controller, main wiring, and tests; commit `feat: cache leaderboard periods`.

### Task 4: Cached switching, refresh-all, and infinite list UI

**Files:**
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Test: `test/leaderboard_page_test.dart`

**Step 1: Write the failing tests**

- Entering the page triggers one day and one week request.
- Tapping the segment renders cached rows without another request or loading spinner.
- Pull-to-refresh requests both first pages.
- Near-bottom scrolling requests the selected period's next page once.
- Footer shows loading and retry states without hiding existing rows.
- Appended rows animate while existing rows remain stable.

**Step 2: Verify RED**

Run: `flutter test test/leaderboard_page_test.dart`

Expected: FAIL because switching currently calls `load(period)` and no load-more trigger exists.

**Step 3: Implement the minimum UI behavior**

- Call `refreshAll()` once after the page mounts.
- Read `snapshotFor(_period)` and change only local `_period` on segment taps.
- Make `RefreshIndicator.onRefresh` call `refreshAll()`.
- Reuse the page ListView with one ScrollController; when `extentAfter < 240`, call `loadMore(_period)`.
- Append a compact footer spinner/retry button.
- Reset scroll to top when switching periods.

**Step 4: Verify GREEN**

Run: `flutter test test/leaderboard_page_test.dart`

Expected: all page tests pass.

**Step 5: Commit**

Explicitly stage the page and widget test; commit `feat: add leaderboard infinite scroll`.

### Task 5: Full verification and deployment

**Files:**
- Update after deployment: protected local ledger and `E:/AII/pushup-ai-info` snapshots only as required by project policy.

**Step 1: Run all local checks**

Run:

```powershell
cd workers/membership-api
npm test
cd ../..
flutter analyze
flutter test
git diff --check
```

Expected: Worker and all Flutter tests pass; replay baselines remain 5/5/3.

**Step 2: Deploy the compatible Worker change**

Run: `cd workers/membership-api && npm run deploy`

Expected: Wrangler reports a successful deployment. No D1 migration or manual data write is performed.

**Step 3: Smoke-check the deployed route**

- Confirm unauthenticated `/leaderboard` still rejects access.
- Use the configured Debug App for the authenticated day/week, refresh, and next-page path; do not expose tokens.

**Step 4: Build and install the real App**

Run: `flutter build apk --debug --dart-define-from-file=<protected local config>` and install with `adb install -r`.

Expected: installation succeeds without uninstalling or clearing App data.

**Step 5: Record and commit**

- Record deployment date/version, tests, compatibility order, and rollback command in the protected ledger/info snapshot without secret values.
- Confirm the info repository has no remote and passes its sensitive scan.
- Commit local ledger snapshots separately; do not push.
