# UI Surface Refinement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the home, records, leaderboard, and profile interfaces feel like one high-quality PushupAI product by using tonal surfaces, elevation, and restrained semantic accents instead of prominent outlines.

**Architecture:** This is UI-only work. Add a very small set of semantic surface tokens in `lib/ui/app_theme.dart`, then use them from the existing page-local helpers. Keep all controllers, routing, data aggregation, contracts, localization, semantics, and SafeAreas unchanged.

**Tech Stack:** Flutter Material 3, Dart Widget tests, `AppLocalizations`, existing `ThemeData`.

---

## Approved visual direction

- Light: warm white, sage, and mint/cyan value steps; decorative card frames removed; hierarchy comes from surface value, spacing, and soft elevation.
- Dark: forest/deep-teal steps with restrained glow/shadow; no bright rank-colored outer frame.
- Gold, silver, and bronze remain small medal/icon/score accents, never a thick row border.
- Do not add images, dependencies, purple/blue tech styling, black-gold styling, or product features.

## Scope and non-negotiable boundaries

### In scope

1. Home top-right training-record entry, Sports Plaza entry, and light exercise-card contrast.
2. Records cloud-status chip and bottom period-summary card.
3. Leaderboard period selector, rule banner, ranked rows, all state panels, and current-user panel in both themes.
4. Profile account hero, VIP stamp, membership status, and fixed sign-in/sign-out action.
5. Theme documentation and Widget coverage.

### Never change

- Recognition, `WorkoutController`, exercise routing, storage, statistics, points formula, Worker/D1, membership, or cloud-sync logic.
- `pushup_points_v1`, standard ×1/narrow ×2, pagination, join/leave, frozen-score, moderation, or the current-user-only privacy of `myExerciseCounts`.
- Existing l10n phrases, whole-card tap behavior, long-press semantics/haptics, reduced-motion behavior, SafeAreas, sign-out confirmation, or the current-day calendar outline.

## Baseline and worktree safety

- Branch: `codex/home-card-compact`.
- The current worktree intentionally contains the approved but uncommitted light exercise-card refinement in `lib/ui/app_theme.dart`, `lib/ui/pages/home_page.dart`, `test/home_page_test.dart`, and `docs/design/app-ui-v1.md`. Treat it as the baseline; never reset, discard, or overwrite it.
- Before every commit inspect `git status --short --branch`; explicitly stage only current-task files. Never use `git add -A`.
- Do not push, merge, deploy, touch Worker/D1, alter credentials, uninstall, or clear App data.

## Task 1: Establish restrained semantic surface tokens

**Files:** `lib/ui/app_theme.dart`, `docs/design/app-ui-v1.md`, the four affected page test files.

1. Write failing page-level tests that assert light feature surfaces have no decorative `Border`/outlined shell, use distinct tonal fills plus soft shadow, and dark surfaces use a tonal step rather than a bright outer stroke. Assert actual page decorations, not token declarations.
2. Run the targeted tests with `flutter test <test file> --plain-name "<test name>"`; each must fail for the old outline-driven treatment.
3. Add only reusable semantic values: raised light surface, sage/mint light surfaces, dark raised/muted surfaces, and restrained card shadows. Reuse existing `green`, `greenDark`, `sky`, `lime`, `ink`, and dark equivalents for accents; keep one-off colors local.
4. Update `docs/design/app-ui-v1.md` to state that decorative outlines are replaced by tonal layers, while stateful outlines such as the current calendar day remain.
5. Re-run each changed focused test and verify green before moving on.

## Task 2: Refine home controls and exercise-card distinction

**Files:** `lib/ui/pages/home_page.dart:279-620`; `test/home_page_test.dart:89-116,354-520`.

1. Write failing tests for `_TodayButton`: no explicit light-mode `BorderSide`, a distinct calendar tile, same tap target, light/dark coverage.
2. Write failing tests for `_SportsPlazaCard`: no decorative light outer border, separate header/status tonal levels, one whole-card `InkWell`, and all four existing signed-out/free/premium/joined states unchanged.
3. Keep the existing light exercise-card no-outline test and add the requested stronger sage-versus-mint light contrast contract; assert deep forest/deep-teal remains unchanged.
4. Add a 320px Chinese/English top-and-bottom-inset test that asserts no overflow or exception.
5. Verify RED with focused tests. Rewrite only the visual portions of the existing quiet-today-control and light-Sports-Plaza tests so they fail on styling, not routing/state.
6. Implement minimally: `_TodayButton` becomes a raised tonal control; `_SportsPlazaCard` uses header surface, icon tile, score/status inset, spacing, and soft elevation. Retain all keys, resolver logic, l10n, routes, and tap behavior.
7. Tune existing exercise-card light contrast/shadow only after shared tokens exist; never alter height, text/number location, CTA, or `ExerciseType` routing.
8. Verify GREEN with `flutter test test/home_page_test.dart`.

## Task 3: Refine records status and period summary

**Files:** `lib/ui/pages/records_page.dart:509-537,812-887`; `test/records_page_test.dart`.

1. Write failing tests that cloud/pending chips are tonal fills without decorative frames, retain icon/text/Wrap behavior, and remain above the legend.
2. Write failing tests that `_PeriodSummaryCard` is an elevated tonal surface without external border in light/dark; centre total has strongest hierarchy while all values remain readable.
3. Add 320px Chinese/English bottom-inset coverage for calendar, status, legend, and summary without overflow.
4. Verify RED. Preserve existing tests for period navigation, heatmap/watermark values, cloud placement, and today's stateful outline.
5. Implement minimally: `_StatusChip` uses tonal fill; `_PeriodSummaryCard` uses warm/sage light and dark forest surfaces with spacing or low-contrast internal separation rather than hard lines; `_SummaryValue` promotes only centre total through type/value treatment.
6. Verify GREEN with `flutter test test/records_page_test.dart`.

## Task 4: Rebuild Sports Plaza hierarchy around surfaces, not rank frames

**Files:** `lib/ui/pages/leaderboard_page.dart:328-472,474-575,674-1362,1586-1815` as needed; `test/leaderboard_page_test.dart:65-360` plus existing behavior tests.

1. Replace the old `leaderboard rows emphasize medal borders and score` contract with failing tests: ranks 1/2/3/ordinary have no thick color frame in either theme; rank 1 remains strongest through surface/medal/score/elevation; 2/3 retain metal accents without full borders.
2. Add failing contracts for one-layer day/week selection with preserved `Semantics(selected: ...)` and reduced-motion behavior; rule banner must be a supporting strip, not a competing card.
3. Add visual contracts for current-user, frozen, joined-no-rank, premium, join, empty, error, and identity panels while preserving their current state/content. Preserve the existing 320px English private-exercise-count test and privacy boundary.
4. Verify RED; failures must be caused by current border-driven selectors/rows.
5. Implement in units: `_LeaderboardPeriodPill`, `_PointsRuleBanner`, `_LeaderboardRowTile`, then personal/state panels. Use rank-aware tonal backgrounds, low-alpha glow/shadow, medal treatment, and score accent. Preserve keys, avatars, transforms, long press/actions, and all semantics.
6. Verify GREEN with `flutter test test/leaderboard_page_test.dart`; all cached-period, refresh, pagination, membership, join/leave, long-press moderation, and privacy tests must remain green.

## Task 5: Refine profile identity, membership, and exit surfaces

**Files:** `lib/ui/pages/profile_page.dart:118-180,1079-1113,1554-1665`, fixed action near `276`; `test/profile_page_test.dart:70-110,216-310,402-505,835-870,1665-1705`.

1. Write failing tests that signed-in account hero has no decorative light outer border, an elevated tonal layer in both themes, and retained avatar/medal, identity truncation, VIP/sync, and settings action.
2. Write failing tests that `_VipStamp` is theme-aware rather than a fixed light-only combination; membership becomes a semantic success/status surface; fixed sign-in/sign-out stays above system insets and retains click/confirmation behavior without relying on a long outline.
3. Add 320px Chinese/English no-overflow coverage for hero, membership, and fixed action.
4. Verify RED.
5. Implement minimally: account hero gets page-local tonal surface/elevation; VIP derives colors from brightness/theme; membership gets a small tonal icon base and restrained success layer; fixed exit becomes a low-emphasis tonal action. Keep `CustomScrollView`, refresh, settings sheet, identity source, entitlement conditions, 48dp target, SafeArea, and dialogs unchanged.
6. Verify GREEN with `flutter test test/profile_page_test.dart`.

## Task 6: Cross-page QA, device pass, and handoff

1. Across every changed page, cover Chinese/English, light/dark, 320px width with top/bottom insets, no overflow/test exception, and existing tap/long-press semantics. Prefer focused Widget tests and existing fakes; do not add test-only production APIs.
2. Run `flutter analyze`, `flutter test`, and `git diff --check`. Expected: analyzer has 0 issues; all tests pass with replay step0=5/v3=5/v4=3; diff check is clean.
3. Only after Widget tests are green, build the Debug APK using the protected existing local configuration and update the connected device with `adb install -r -t`. Do not uninstall or clear data. Verify the four page families in light/dark mode. This is UI validation only, not a Play/OAuth/Billing/production-backend release test.
4. Present page-by-page results and untouched business boundaries for user acceptance. Keep changes unpushed. After acceptance, explicitly stage changed files and create the requested branch commit for main review; do not merge or deploy.
