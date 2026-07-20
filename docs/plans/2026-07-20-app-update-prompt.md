# App Startup Update Prompt Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a non-blocking cold-start update check backed by the existing Cloudflare Worker, with a themed optional update dialog and reuse of the existing Google Play product-page launcher.

**Architecture:** The Worker exposes a localized, unauthenticated Android release manifest. Flutter parses that manifest into a pure product model, a control-layer checker compares integer build codes and confirms availability with Google Play, and a UI host mounted after the startup gate presents at most one optional dialog. All failures fail closed without blocking startup.

**Tech Stack:** Flutter/Dart, Material 3, Flutter l10n, `http`, `package_info_plus`, `in_app_update`, `url_launcher`, Cloudflare Workers TypeScript, Node test runner.

---

### Task 1: Add the Worker release manifest contract

**Files:**
- Create: `workers/membership-api/src/app_update.ts`
- Modify: `workers/membership-api/src/index.ts`
- Create: `workers/membership-api/test/app-update.test.mjs`

1. Write failing Node tests for `GET /app-update?platform=android&locale=zh`, English/fallback localization, unsupported platform, non-GET methods, response headers, and manifest version parity with `pubspec.yaml`.
2. Run `npm test -- --test-name-pattern app-update` from `workers/membership-api`; verify failure is caused by the missing route/module.
3. Add the minimal versioned manifest and route handler. Keep the endpoint public, D1-free and Secret-free.
4. Run the targeted Worker tests and confirm green.
5. Run full `npm test` and keep existing routes green.

### Task 2: Add the pure App release model and API parsing

**Files:**
- Create: `lib/product/app_update.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `test/membership_api_client_test.dart`

1. Write failing tests that assert the exact GET URL, successful strict parsing, locale forwarding, and rejection of malformed schema/version/notes.
2. Run the named tests and verify failure because `latestAppRelease` and `AppReleaseInfo` do not exist.
3. Implement the minimal pure model and client method. Log only status/error metadata on parse failure; never log response content.
4. Run the named tests and confirm green.

### Task 3: Add update decision orchestration

**Files:**
- Modify: `lib/platform/app_version_service.dart`
- Create: `lib/control/app_update_checker.dart`
- Create: `test/app_version_service_test.dart`
- Create: `test/app_update_checker_test.dart`

1. Write failing tests for installed integer build loading and for the checker returning a release only when the manifest build is newer and Google Play confirms availability.
2. Cover equal/older builds, Play unavailable, dependency failure and timeout; assert Play is not queried when the manifest is not newer.
3. Run both test files and observe the expected missing-API failures.
4. Implement `installedBuildNumber` and the small injected checker with a bounded timeout and fail-closed result.
5. Run both test files and confirm green.

### Task 4: Extract and reuse the Google Play launcher

**Files:**
- Create: `lib/platform/play_store_service.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Create: `test/play_store_service_test.dart`
- Verify: `test/profile_page_test.dart`

1. Write failing tests for native success, native failure with HTTPS fallback, and exceptions falling back safely.
2. Run the new test and verify the service is missing.
3. Implement the service using the existing MethodChannel name/method and pinned Google Play web URL.
4. Replace the profile page's private duplicate launcher with the service while retaining its injected URL launcher used by Widget tests.
5. Run the launcher tests and the two existing version-entry Widget tests.

### Task 5: Build the themed optional update prompt

**Files:**
- Create: `lib/ui/app_update_prompt.dart`
- Create: `test/app_update_prompt_test.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Generate: `lib/l10n/app_localizations*.dart`

1. Add ARB messages for the title, version label, release-notes heading, later action and update action; run `flutter gen-l10n`.
2. Write failing Widget tests for showing version/notes, later dismissal, update launch, launch failure SnackBar, no-update silence, one check per mount, and English/dark/320×640 rendering.
3. Run the test file and verify failure because the prompt widget is missing.
4. Implement the post-frame one-shot host and rounded Material 3 dialog. Skip presentation if its route is no longer current.
5. Run the Widget tests and confirm green with no overflow or pending timer.

### Task 6: Wire the check after the startup gate

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/architecture_contract_test.dart`

1. Add a failing architecture test asserting production wiring uses the API client, version service, checker, Play Store service and mounts the prompt inside the completed startup home.
2. Run the named architecture test and verify it fails on missing wiring.
3. Construct dependencies in `_runUgkApp`, pass callbacks into `UgkExerciseApp`, and wrap `HomePage` with the prompt host beneath `AppStartupGate`.
4. Run the architecture and startup tests.

### Task 7: Document the release gate

**Files:**
- Modify: `docs/design/app-ui-v1.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/release-configuration.md`

1. Record the cold-start behavior, non-blocking/fail-closed rules and themed dialog contract.
2. Add the mandatory release-manifest synchronization check and precise Play/Worker rollout order.
3. State that local tests do not prove a Play-track update; final validation requires a lower Play-installed build and a higher published build.

### Task 8: Run gates and prepare review

1. Run `dart format` on changed Dart files and `flutter gen-l10n`.
2. Run all targeted Flutter and Worker tests.
3. Run `flutter analyze`, full `flutter test`, Worker `npm test`, and `git diff --check`.
4. Inspect `git status` and `git diff`; explicitly stage only task files and create a local feature commit.
5. Start the user-requested independent read-only review agent with the requirements, design, diff and actual test results.
6. Apply review fixes in the main thread using a failing test for each behavioral defect, rerun proportionate gates, and send the same reviewer back for verification until it passes or reports a concrete blocker.
