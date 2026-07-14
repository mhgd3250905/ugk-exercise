# Custom Avatar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add one account-level custom avatar with gallery/camera cropping, highest-priority display, public leaderboard reporting/blocking, and a protected moderation surface, while removing the retired leaderboard-only identity.

**Architecture:** Keep Flutter presentation thin over `MembershipApiClient` and `AccountController`; put image acquisition/cropping behind a small platform adapter. Keep D1 as avatar metadata and moderation authority, R2 as private object storage, and the Worker as the only upload/read boundary. Resolve public identity on the Worker; anonymous identity is the only exception to the shared account avatar.

**Tech Stack:** Flutter/Dart, `image_picker`, `image_cropper`, package:http, Cloudflare Workers TypeScript, D1, private R2 binding, `jose`, Node test runner.

---

### Task 1: D1 schema and migration contract

**Files:**
- Create: `workers/membership-api/migrations/0004_custom_avatar_ugc.sql`
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/test/schema-migration.test.mjs`

**Step 1: Write the failing tests**

- Assert the migration chain and fresh `schema.sql` expose the same avatar columns, tables, indexes, foreign keys, and constraints.
- Seed an old `identity_mode = 'custom'` profile and assert migration changes it to `profile` and clears the retired nickname/avatar fields.
- Assert policy acceptances, reports, blocks, and moderation actions enforce their uniqueness and controlled status values.

**Step 2: Verify RED**

Run: `cd workers/membership-api; npm test -- --test-name-pattern="schema|migration"`

Expected: FAIL because migration `0004` and avatar governance tables do not exist.

**Step 3: Implement the minimum schema**

- Add the three user columns and the five tables from the approved design.
- Retain retired leaderboard columns physically, but migrate `custom` rows to `profile` and clear them.
- Add only indexes required by current lookups: active object, open reports, and block filtering.
- Mirror the final schema in `schema.sql`.

**Step 4: Verify GREEN**

Run: `cd workers/membership-api; npm test -- --test-name-pattern="schema|migration"`

Expected: schema and migration tests pass.

**Step 5: Commit**

Explicitly stage the migration, schema snapshot, and migration test; commit `feat: add avatar governance schema`.

### Task 2: Retire leaderboard-only identity

**Files:**
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify: `lib/product/leaderboard_models.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `test/leaderboard_page_test.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

**Step 1: Write the failing tests**

- Assert Worker join/update accept only `profile` and `anonymous`; `custom` returns 400.
- Assert leaderboard rows no longer query or resolve retired custom fields.
- Assert Dart parsing rejects `custom`, and identity serialization contains only `mode`.
- Assert the identity sheet renders exactly profile and anonymous choices, with no custom nickname/avatar controls.

**Step 2: Verify RED**

Run: `cd workers/membership-api; npm test; cd ../..; flutter test test/membership_api_client_test.dart test/leaderboard_page_test.dart`

Expected: FAIL because the custom identity branch still exists.

**Step 3: Implement the minimum removal**

- Reduce identity types to `profile | anonymous` in Worker and Dart.
- Stop reading/writing retired custom fields; preserve anonymous avatar assignment.
- Delete the custom identity card, nickname field, avatar grid, and unused localized copy.
- Keep profile preview wired to the unified account avatar added later; until then preserve current account fields.

**Step 4: Verify GREEN**

Run the same Worker and targeted Flutter tests; expect all pass.

**Step 5: Commit**

Explicitly stage only listed source/tests/localization files; commit `refactor: unify leaderboard identity with profile`.

### Task 3: Worker avatar validation, storage, and account payload

**Files:**
- Create: `workers/membership-api/src/avatar.ts`
- Create: `workers/membership-api/test/avatar.test.mjs`
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/src/types.ts`
- Modify: `workers/membership-api/wrangler.toml`
- Modify: `workers/membership-api/test/worker-routes.test.mjs`

**Step 1: Write the failing tests**

- Test bounded reads against missing/false `Content-Length`, oversized bodies, truncated JPEGs, bad magic, unsupported dimensions, and non-square images.
- Test policy required, upload suspension, first upload, replacement, idempotent delete, and public versioned GET.
- Test R2 put failure leaves D1 untouched; D1 failure deletes the new object and preserves the old pointer; old R2 delete failure leaves a traceable replaced record.
- Assert `/me` returns `customAvatarUrl`, current policy version/acceptance, and upload suspension without changing Google `avatarUrl` semantics.

**Step 2: Verify RED**

Run: `cd workers/membership-api; npm test -- --test-name-pattern="avatar|worker routes"`

Expected: FAIL because avatar routes and R2 binding do not exist.

**Step 3: Implement the minimum Worker path**

- Add pure JPEG SOF parsing and a bounded byte reader; accept only JPEG, square images, dimensions up to 512×512, and the central byte limit.
- Add policy accept, upload, delete, and public read handlers using `crypto.randomUUID()`.
- Write R2 first, switch metadata in a D1 batch, compensate on D1 failure, then delete/mark the old object.
- Check active D1 ownership before streaming R2; return ETag and a bounded public cache header.
- Add the local R2 binding `AVATAR_BUCKET` with bucket name `ugk-profile-avatars`; do not create or mutate remote resources.
- Centralize account-user serialization so auth, `/me`, profile update, and avatar responses share the same fields.

**Step 4: Verify GREEN**

Run: `cd workers/membership-api; npm test`

Expected: all Worker tests pass.

**Step 5: Commit**

Explicitly stage the Worker source/config/tests; commit `feat: add private avatar storage API`.

### Task 4: Report, block, public resolution, and account deletion cleanup

**Files:**
- Create: `workers/membership-api/src/avatar_moderation.ts`
- Create: `workers/membership-api/test/avatar-moderation.test.mjs`
- Modify: `workers/membership-api/src/leaderboard.ts`
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/test/leaderboard.test.mjs`
- Modify: `workers/membership-api/test/leaderboard-sql.test.mjs`
- Modify account-deletion route/test files found by `rg -n "delete.*account|account.*delete" workers/membership-api`

**Step 1: Write the failing tests**

- Assert custom → built-in → Google → safe default public resolution, with anonymous and admin-hidden exceptions.
- Assert report validation, self-report rejection, per-version idempotency, automatic block, unblock, and blocked-row filtering without rank renumbering.
- Assert replacing a reported avatar makes the old report stale and cannot remove the new avatar.
- Assert account deletion enumerates and deletes every owned R2 object before/with D1 cleanup; if no deletion API exists, add the cleanup service behind the existing deletion workflow rather than inventing a second user-facing endpoint.

**Step 2: Verify RED**

Run: `cd workers/membership-api; npm test -- --test-name-pattern="avatar|leaderboard|block|report|delete"`

Expected: FAIL because governance endpoints and filtering are absent.

**Step 3: Implement the minimum governance behavior**

- Add report and block/unblock routes with controlled reason values and current-avatar snapshots.
- Filter blocked users in the ranked result after global ranks are calculated.
- Resolve the account custom avatar URL on the Worker for profile identities.
- Add reusable object cleanup for account deletion; if the external deletion workflow is outside this repository, expose and test the internal cleanup function and document the remaining integration point.

**Step 4: Verify GREEN**

Run: `cd workers/membership-api; npm test`

Expected: all Worker tests pass.

**Step 5: Commit**

Explicitly stage only governance source/tests; commit `feat: add avatar reporting and blocking`.

### Task 5: Access-protected moderation page

**Files:**
- Create: `workers/membership-api/src/admin.ts`
- Create: `workers/membership-api/test/admin.test.mjs`
- Modify: `workers/membership-api/src/index.ts`
- Modify: `workers/membership-api/src/types.ts`

**Step 1: Write the failing tests**

- Assert missing/invalid Access JWT is rejected; issuer and audience are checked.
- Assert the queue HTML escapes user content and mutation endpoints accept only same-origin POST.
- Assert dismiss, stale protection, remove custom avatar, hide/restore public network avatar, suspend/restore upload, and audit logging.

**Step 2: Verify RED**

Run: `cd workers/membership-api; npm test -- --test-name-pattern="admin|Access|moderation"`

Expected: FAIL because admin routes do not exist.

**Step 3: Implement the minimum page**

- Verify `Cf-Access-Jwt-Assertion` with `jose` against configured team issuer/audience and cached remote JWKS.
- Render one dependency-free server HTML queue; use same-origin forms only.
- Re-check the reported avatar version inside each action and write an audit row.
- Read team domain/audience from runtime bindings; do not place real values or identities in git.

**Step 4: Verify GREEN**

Run: `cd workers/membership-api; npm test`

Expected: all Worker tests pass.

**Step 5: Commit**

Explicitly stage the admin source/tests; commit `feat: add protected avatar moderation page`.

### Task 6: Flutter avatar domain, API, and controller

**Files:**
- Modify: `lib/product/membership_status.dart`
- Modify: `lib/product/leaderboard_models.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/control/account_controller.dart`
- Modify: `test/membership_status_test.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/account_controller_test.dart`

**Step 1: Write the failing tests**

- Parse/cache `customAvatarUrl`, policy acceptance/version, and upload suspension while preserving older cached JSON.
- Assert accept sends JSON, upload sends raw JPEG with `image/jpeg`, delete/report/block routes and server error codes are mapped.
- Assert avatar accept/upload/delete update the account only for the same generation/account; sign-out and newer mutations win every race.

**Step 2: Verify RED**

Run: `flutter test test/membership_status_test.dart test/membership_api_client_test.dart test/account_controller_test.dart`

Expected: FAIL because the avatar contract is absent.

**Step 3: Implement the minimum client behavior**

- Extend `AppUser` without repurposing Google `avatarUrl`.
- Add API methods for policy, raw JPEG upload, delete, report, block, and unblock.
- Add focused controller methods with existing generation/account guards after every `await`; preserve the last valid avatar on failure.

**Step 4: Verify GREEN**

Run the same targeted tests; expect all pass.

**Step 5: Commit**

Explicitly stage the listed Dart source/tests; commit `feat: add custom avatar account contract`.

### Task 7: Image selection/cropping adapter and shared avatar widget

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/platform/avatar_image_service.dart`
- Create: `lib/ui/user_avatar.dart`
- Create: `test/avatar_image_service_test.dart`
- Create: `test/user_avatar_test.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Write the failing tests**

- Assert gallery/camera selection cancellation and crop cancellation return null without an upload.
- Assert the crop request is 1:1, max 512×512, JPEG, and configured quality.
- Assert the shared widget resolves custom → built-in → Google → default and handles network failure.

**Step 2: Verify RED**

Run: `flutter test test/avatar_image_service_test.dart test/user_avatar_test.dart`

Expected: FAIL because packages, adapter, and shared widget do not exist.

**Step 3: Implement the minimum adapter/widget**

- Add `image_picker` and `image_cropper` at compatible current stable versions.
- Wrap plugin calls behind injectable functions so tests do not need platform channels.
- Configure Android crop activity required by the package; add no broad media/storage permission.
- Make one `UserAvatar` widget serve profile, preview, and leaderboard row sizes.

**Step 4: Verify GREEN**

Run: `flutter pub get; flutter test test/avatar_image_service_test.dart test/user_avatar_test.dart`

Expected: both test files pass and the merged manifest has no broad media permission.

**Step 5: Commit**

Explicitly stage dependency, adapter/widget, Android manifest, and tests; commit `feat: add avatar picker and cropper`.

### Task 8: Profile and leaderboard UI

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated `lib/l10n/app_localizations*.dart`
- Modify: `test/profile_page_test.dart`
- Modify: `test/leaderboard_page_test.dart`

**Step 1: Write the failing tests**

- Assert profile exposes gallery/camera, first-upload policy acceptance, local busy state, replace, delete, cancellation, retry, and built-in/Google fallback.
- Assert profile preview and leaderboard rows use `UserAvatar`, while anonymous preview never uses account fields.
- Assert non-self rows expose report/block actions, successful actions remove the row locally, and failures remain retryable.
- Cover Chinese/English labels and light/dark rendering where existing page harnesses support them.

**Step 2: Verify RED**

Run: `flutter test test/profile_page_test.dart test/leaderboard_page_test.dart`

Expected: FAIL because the UI actions and shared avatar are not wired.

**Step 3: Implement the minimum UI**

- Inject `AvatarImageService` from `main.dart` into profile UI.
- Add the two source actions, policy dialog, replace/delete state, and clarify that built-in avatars are fallbacks.
- Use `UserAvatar` in all three account/public locations.
- Add a compact row menu with controlled report reasons and block confirmation; refresh cached leaderboard data after success.
- Keep all visible strings in ARB and regenerate localization files.

**Step 4: Verify GREEN**

Run: `flutter gen-l10n; flutter test test/profile_page_test.dart test/leaderboard_page_test.dart`

Expected: targeted widget tests pass.

**Step 5: Commit**

Explicitly stage app wiring, pages, ARB/generated files, and widget tests; commit `feat: add custom avatar and safety controls`.

### Task 9: Compliance and operations documentation

**Files:**
- Create: `docs/policies/user-content-policy.md`
- Modify: `docs/modules/membership.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/release-configuration.md`
- Modify the existing website privacy/account-deletion source only if it is present in this worktree.

**Step 1: Write the acceptance checklist first**

- Record the exact policy version used by Worker/App.
- Document public storage/display, retention, report/block behavior, moderation SLA/steps, account deletion, and Data safety/content-rating review.
- Record the separately authorized rollout order and rollback checks without secrets.

**Step 2: Verify documentation links/config names**

Run: `rg -n "AVATAR_BUCKET|avatar-policy|用户内容|custom avatar|Data safety" docs workers/membership-api/src workers/membership-api/wrangler.toml`

Expected: every runtime/config/policy identifier is explained once in an authority document.

**Step 3: Implement the minimum documentation changes**

- Add the versioned user-content rules and link them from membership/release/test docs.
- Describe the local moderation page and Access/JWT requirements.
- Mark R2 creation, D1 migration, Access configuration, Worker/website deployment, Play declarations, artifact upload, and track promotion as separate future authorization points.

**Step 4: Verify formatting**

Run: `git diff --check`

Expected: no whitespace errors or broken relative links introduced by this task.

**Step 5: Commit**

Explicitly stage documentation only; commit `docs: add avatar ugc operations policy`.

### Task 10: Full local verification and deployment handoff

**Files:**
- Update only test-generated files required by established project workflows.
- Do not change protected local ledgers unless a separately authorized remote operation occurs.

**Step 1: Run all Worker checks**

Run: `cd workers/membership-api; npm test`

Expected: TypeScript and all Worker/D1 tests pass.

**Step 2: Run all Flutter checks**

Run: `cd ../..; flutter analyze; flutter test`

Expected: zero analyzer issues, all Flutter tests pass, replay baselines remain step0=5, v3=5, v4=3.

**Step 3: Validate native permissions and diff hygiene**

Run:

```powershell
rg -n "READ_MEDIA_IMAGES|READ_MEDIA_VIDEO|READ_EXTERNAL_STORAGE" android
git diff --check
git status --short
```

Expected: no broad media/storage permission, no whitespace errors, and only intentional files changed.

**Step 4: Build without publishing**

Run: `flutter build apk --release --split-per-abi`

Expected: local release APKs build successfully; no upload or install occurs.

**Step 5: Stop at the remote boundary**

- Report local commits, tests, unresolved true-device checks, and exact remote steps.
- Request separate authorization before each R2 creation, D1 production migration, Access change, Worker/website deployment, Play declaration, artifact upload, and track promotion.
