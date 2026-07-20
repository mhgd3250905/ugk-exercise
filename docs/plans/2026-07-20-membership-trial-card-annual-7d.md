# Membership Trial Cards and Annual 7-Day Trial Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Premium purchase sheet lead with an eligible monthly three-day trial while clearly supporting an eligible annual seven-day trial, using only current RevenueCat Offering data.

**Architecture:** Keep trial eligibility and billing lifecycle in Google Play/RevenueCat. Add exact fail-closed trial mapping in the existing RevenueCat adapter, keep `PremiumPlan` as the pure-Dart UI value, and replace the paywall's ChoiceChips with local full-width plan cards whose CTA and renewal disclosure derive only from the selected plan. Worker, D1, entitlement and controller contracts remain unchanged.

**Tech Stack:** Flutter/Dart, `purchases_flutter`, ARB/gen-l10n, `flutter_test`, Node Worker tests.

---

## Success criteria

- Monthly advertises a trial only for a complete `P3D` default option; annual only for a complete `P7D` default option.
- Default priority is monthly trial → annual trial → annual base plan → first available plan.
- Both trial cards remain visible when both are eligible, while monthly is selected and visually dominant.
- Selecting either plan updates the CTA, free period, localized post-trial price, renewal period and cancellation disclosure.
- Unsupported/incomplete phases fail closed to ordinary plan rendering.
- The selected plan ID is the exact Package purchased.
- Chinese/English, light/dark and a 320×640 viewport render without overflow.
- No remote/platform write occurs without a separate authorization.

### Task 1: Lock exact RevenueCat trial mapping

**Files:**

- Modify: `lib/platform/revenuecat_service.dart`
- Modify: `test/revenuecat_service_test.dart`

**Step 1: Write failing adapter tests**

Add focused tests that build realistic monthly/annual Packages and assert:

```dart
expect(
  premiumPlanFromPackage(
    PremiumPlanId.monthly,
    packageFor(PremiumPlanId.monthly, freeTrialDays: 3),
  ).freeTrialDays,
  3,
);
expect(
  premiumPlanFromPackage(
    PremiumPlanId.annual,
    packageFor(PremiumPlanId.annual, freeTrialDays: 7),
  ).freeTrialDays,
  7,
);
```

Also assert `null` for monthly 5 days, annual 3 days, week-based phases, missing full-price phase, empty formatted renewal price and missing default option.

**Step 2: Verify RED**

Run:

```powershell
flutter test test/revenuecat_service_test.dart
```

Expected: FAIL because annual trials are currently always rejected, monthly accepts any positive day count, and incomplete phases can fall back to a product price while still advertising a trial.

**Step 3: Implement the minimum fail-closed mapping**

In `premiumPlanFromPackage`, choose the expected duration by plan ID (`3` monthly, `7` annual). Set `freeTrialDays` only when the default option has that exact positive day period and a complete non-empty full-price phase. Keep ordinary `price` fallback for non-trial plans.

**Step 4: Verify GREEN**

Run the same test file and expect all tests to pass.

**Step 5: Commit**

Explicitly stage only the adapter and its test, then commit with a membership-scoped message. Do not push.

### Task 2: Lock the four Offering combinations and selection rules

**Files:**

- Modify: `test/profile_page_test.dart`
- Modify: `lib/ui/pages/profile_page.dart`

**Step 1: Write failing Widget tests**

Add one test per matrix row:

1. monthly 3 + annual 7 → monthly selected;
2. monthly 3 only → monthly selected;
3. annual 7 only → annual selected;
4. no trials → annual selected.

For the both-trial case, tap annual and assert the CTA changes from the three-day monthly trial to the seven-day annual trial, the disclosure changes from monthly to annual, and the purchase callback receives `PremiumPlanId.annual`.

**Step 2: Verify RED**

Run:

```powershell
flutter test test/profile_page_test.dart --plain-name "paywall prioritizes monthly trial while exposing annual trial"
flutter test test/profile_page_test.dart --plain-name "paywall defaults to the only eligible annual trial"
```

Expected: FAIL because the current selection logic ignores annual trials and the renewal disclosure is hard-coded to monthly.

**Step 3: Implement minimum selection logic**

Change `_loadPlans()` to select monthly when it has an eligible trial, otherwise annual when it has an eligible trial, otherwise preserve annual-first fallback. Make selected trial days come only from the selected plan.

**Step 4: Verify GREEN**

Run all four matrix tests, then the full `test/profile_page_test.dart`.

### Task 3: Redesign plan choice cards and localize dual-period terms

**Files:**

- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Modify: `test/profile_page_test.dart`

**Step 1: Write failing presentation tests**

Assert full-card keys and semantics, direct trial copy (`免费 3 天` / `免费 7 天`, `3 days free` / `7 days free`), post-trial price labels, selected state, the annual secondary recommendation marker, and no `ChoiceChip` usage within the two plan cards.

Add light/dark assertions against the active `ColorScheme`, plus a 320×640 English test that scrolls to the annual CTA and verifies `tester.takeException()` is null.

**Step 2: Verify RED**

Run the new presentation tests. Expected: FAIL because the current UI uses ChoiceChips, subdued trial text, monthly-only renewal copy and no annual trial CTA.

**Step 3: Add ARB messages and regenerate l10n**

Add localized messages for direct trial value, post-trial monthly/annual card price and separate monthly/annual trial renewal disclosure. Preserve the existing ordinary renewal message.

Run:

```powershell
flutter gen-l10n
```

**Step 4: Implement `_PremiumPlanCard`**

Create a page-local private widget using `Semantics`, `Material`, `InkWell` and an animated themed container. Keep the whole card clickable, expose a selected icon and render trial/recommendation badges as secondary metadata. Use only `Theme.of(context).colorScheme` and existing palette constants.

**Step 5: Verify GREEN**

Run:

```powershell
flutter test test/profile_page_test.dart
```

Expected: all profile tests pass with no overflow/exceptions.

### Task 4: Update stable product and testing contracts

**Files:**

- Modify: `docs/modules/membership.md`
- Modify: `docs/design/app-ui-v1.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/release-configuration.md`
- Keep: `docs/plans/2026-07-20-membership-trial-card-annual-7d-design.md`
- Keep: `docs/plans/2026-07-20-membership-trial-card-annual-7d.md`

**Step 1: Update contracts**

Replace the monthly-only trial contract with exact monthly 3-day and annual 7-day client behavior, the four local Offering combinations and truthful failure fallback. Mark the annual Play Offer as planned/not configured unless separate remote authorization and evidence are later supplied. Preserve the existing monthly Sandbox evidence and incomplete cancellation/history matrix status.

**Step 2: Verify documentation consistency**

Run focused `rg` searches for stale statements such as “年卡不提供试用” and monthly-only paywall rules. Any remaining occurrence must be explicitly historical.

### Task 5: Run local gates

**Files:** no new production files.

**Step 1: Targeted tests**

```powershell
flutter test test/revenuecat_service_test.dart
flutter test test/profile_page_test.dart
```

**Step 2: Required full gates**

```powershell
flutter analyze
flutter test
cd workers/membership-api
npm test
```

**Step 3: Replay and diff integrity**

Run the replay suite that reports step0/v3/v4 and confirm `5/5/3`, then:

```powershell
git diff --check
git status --short --branch
```

Record exact pass counts from this session only.

### Task 6: Independent six-dimension review and repair loop

**Files:** review-only agent must not modify any file.

**Step 1: Dispatch one independent reviewer**

Give it the design, implementation plan, base SHA, final SHA/diff and actual command output. Require separate findings for:

1. requirement completeness;
2. logic correctness;
3. edge cases;
4. code quality;
5. test coverage;
6. actual run results.

Require a prioritized repair list with file/line evidence, or an explicit PASS for each dimension. The agent may run read-only tests but may not edit, stage, commit, push or mutate remote state.

**Step 2: Repair in the main thread**

For every valid finding, write or strengthen a failing regression test first, verify RED, apply the minimum fix and verify GREEN. Re-run proportionate gates.

**Step 3: Reuse the same reviewer**

Send the same agent the new diff and test evidence. Repeat until it returns overall PASS or names an external blocker that cannot be resolved within authorization.

### Task 7: Local handoff

Explicitly stage only files from this feature and create local commits required by the implementation workflow. Do not push. Report code changes, exact tests, remaining Play/RevenueCat runtime gaps, and confirm that no AAB/upload/track/Worker/D1/Secret/Sandbox cancellation action occurred.
