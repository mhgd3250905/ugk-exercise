# Workout History Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Persist successfully downloaded, account-scoped cloud workout history so records render immediately on later visits and remain readable after membership expires, while expired members make no cloud-history request.

**Architecture:** Reuse `WorkoutSessionStore` as the single persisted workout collection. Add one serialized, idempotent cache mutation that assigns the captured owner and `synced` status to cloud-only sessions; wrap the existing Home cloud loader so a successful response is cached before it is returned to `RecordsPage`. Existing owner filtering and Premium request gating remain authoritative.

**Tech Stack:** Flutter/Dart, JSON file persistence, `ChangeNotifier` account state, Dart unit tests, Flutter Widget tests.

---

### Task 1: Persist account-scoped cloud-only workouts

**Files:**
- Modify: `test/workout_session_store_test.dart`
- Modify: `lib/product/workout_session_store.dart`

**Step 1: Write the failing persistence test**

Create a store in the test temp directory, cache a cloud-only `WorkoutSession`, construct a second store for the same directory, and assert:

```dart
final restored = (await secondStore.loadForOwner('user-a')).single;
expect(restored.id, 'cloud-only');
expect(restored.ownerAppUserId, 'user-a');
expect(restored.syncStatus, WorkoutSyncStatus.synced);
```

**Step 2: Write failing idempotency and isolation tests**

Cover all of these cases:

- caching the same list twice stores one record;
- a same-owner local `pending` record with the same ID wins over the cloud copy;
- different owners may cache the same session ID without collision;
- a cloud object already owned by another account is rejected rather than reassigned.

**Step 3: Run tests to verify RED**

Run:

```powershell
flutter test test/workout_session_store_test.dart --plain-name "cloud history cache persists for its owner"
```

Expected: FAIL because `cacheCloudHistoryForOwner` does not exist.

**Step 4: Implement the minimal serialized mutation**

Add this public seam to `WorkoutSessionStore`:

```dart
Future<void> cacheCloudHistoryForOwner(
  String ownerAppUserId,
  List<WorkoutSession> sessions,
)
```

Inside `_serializeMutation`, load the shared list and index stored records by `(ownerAppUserId, id)`. Validate that every incoming record is ownerless or already owned by the requested owner. Preserve existing entries, append only missing records with `ownerAppUserId` and `WorkoutSyncStatus.synced`, and call `_write` only if at least one record was appended. Do not alter the schema version or introduce a second file.

**Step 5: Run tests to verify GREEN**

Run:

```powershell
flutter test test/workout_session_store_test.dart
```

Expected: every workout store test passes.

**Step 6: Commit the store slice**

Explicitly stage only:

```powershell
git add -- lib/product/workout_session_store.dart test/workout_session_store_test.dart
git commit -m "feat(records): cache account cloud history"
```

### Task 2: Cache successful Premium history responses

**Files:**
- Modify: `test/home_page_test.dart`
- Modify: `lib/ui/pages/home_page.dart`

**Step 1: Write a failing Premium caching Widget test**

Use a fake Premium account, a recording/memory `WorkoutSessionStore`, and a loader returning one cloud-only session. Open `home-today-summary`, settle the response, and assert that the store received that session for `user_1` with synced state. Recreate the page/store view and prove the record contributes to the calendar or monthly total before any later cloud Future completes.

**Step 2: Write a failing expired-member cache test**

Prepopulate the store with a synced record owned by `user_1`, sign in with Worker-confirmed non-Premium membership, open records, and assert:

```dart
expect(cloudLoads, 0);
expect(find.text('<cached count> 个'), findsWidgets);
```

Also preserve the existing test that a free member without cache never calls the loader.

**Step 3: Write the account-switch isolation test**

Prepopulate records for `user-a` and `user-b`, open records as `user-b`, and assert only user B's total is visible. This protects both downloaded cache and locally created workouts through the same owner seam.

**Step 4: Run focused tests to verify RED**

Run:

```powershell
flutter test test/home_page_test.dart --name "cloud history"
```

Expected: the successful-response persistence assertion fails against the current direct loader.

**Step 5: Implement the minimum Home orchestration**

In `_HomePageState._cloudSessionsFuture()`:

1. Capture `currentSession` once and keep the existing `premium`/loader guards.
2. Request the current `yyyy-MM` through the injected loader.
3. On success, call `_store.cacheCloudHistoryForOwner(account.appUserId, sessions)`.
4. Return the downloaded sessions for the current page's existing `mergeWorkoutSessions` path.

Do not call the loader or cache mutation for a non-Premium account. Do not derive the cache owner after the await. Keep `RecordsPage` presentation-only and do not move network or persistence logic into the Widget calendar.

**Step 6: Define cache-write failure behavior explicitly**

The current page must still be allowed to display a successfully downloaded response if local cache persistence fails. Catch only the cache-write failure around the persistence step, leave the server response intact, and use the project's safe diagnostic logging without tokens, user IDs, response bodies, or session contents. Do not turn a disk error into a cloud-history error.

**Step 7: Run focused tests to verify GREEN**

Run:

```powershell
flutter test test/home_page_test.dart
flutter test test/records_page_test.dart
```

Expected: all Home and records Widget tests pass; cached records are visible immediately, while the existing loading/merged/unavailable status semantics remain unchanged.

**Step 8: Commit the orchestration slice**

Explicitly stage only:

```powershell
git add -- lib/ui/pages/home_page.dart test/home_page_test.dart test/records_page_test.dart
git commit -m "fix(records): retain downloaded history"
```

### Task 3: Document the stable cache contract

**Files:**
- Modify: `docs/modules/membership.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/plans/README.md`

**Step 1: Update module behavior**

Document that downloaded workout history is an account-scoped local display cache, not a membership grant or Worker authority. Expired members retain read access to cached/local records but cannot fetch new cloud history or upload pending records.

**Step 2: Update testing guidance and plan index**

Add cache persistence, account switching, failure preservation and expired-member no-request behavior to the local records test matrix. Link the design and implementation plan from `docs/plans/README.md`.

**Step 3: Verify documentation diff**

Run `git diff --check` and confirm no secret values, tokens, real user identifiers, screenshots, logs or APKs are tracked.

**Step 4: Commit documentation**

```powershell
git add -- docs/modules/membership.md docs/testing-release-playbook.md docs/plans/README.md
git commit -m "docs(records): define cloud history cache"
```

### Task 4: Run the project gates

**Files:**
- Verify only; do not add unrelated files.

**Step 1: Run static analysis**

```powershell
flutter analyze
```

Expected: 0 issues.

**Step 2: Run all Flutter tests**

```powershell
flutter test
```

Expected: every test passes. Report the exact count from this run.

**Step 3: Re-run replay baselines explicitly**

```powershell
flutter test test/domain_self_check_test.dart --name "replays"
```

Expected: step0=5, video3=5, video4=3.

**Step 4: Check the final diff and tree**

```powershell
git diff --check
git status --short --branch
```

Expected: no whitespace errors and no unrelated/user-owned files included.

**Step 5: Respect delivery boundaries**

Do not install/uninstall the App, clear device data, push, merge, rebase, deploy Worker, write D1, alter secrets or change Google/RevenueCat/Play configuration without a new explicit authorization. No Worker test is required unless Worker files change.

### Task 5: Independent read-only review and repair loop

**Files:**
- Review the complete implementation range from the planning commit through implementation HEAD.
- Do not edit files in the review task.

**Step 1: Start an independent review task**

The implementation task must create a separate Codex review task/agent after all implementation commits and local gates complete. The reviewer receives the design, this plan, the exact base commit and implementation HEAD.

**Step 2: Review six dimensions**

The reviewer checks and reports evidence for:

1. requirements completeness;
2. logical correctness;
3. edge cases and account/session races;
4. code quality and architectural fit;
5. test coverage and whether RED/GREEN evidence is meaningful;
6. actual commands/results, including exact test count and replay 5/5/3.

The reviewer must not modify code. Findings must include severity, file/line, reproduction or reasoning, and a concrete repair checklist. If no findings remain, it must explicitly return PASS for all six dimensions.

**Step 3: Repair only from the checklist**

The implementation task applies surgical fixes, adds a failing regression test for each behavioral defect, reruns focused and full gates, and commits fixes separately. It then sends the new HEAD and results back to the same reviewer.

**Step 4: Repeat until terminal**

Continue review → checklist → repair → re-review until the reviewer returns PASS or a genuine blocker cannot be resolved safely. Report the blocker precisely rather than declaring success early.

