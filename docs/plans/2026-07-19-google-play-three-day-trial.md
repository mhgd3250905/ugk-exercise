# Google Play Three-Day Trial Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Google Play-managed, one-time three-day free trial to the existing monthly Premium subscription while preserving Worker-authoritative membership.

**Architecture:** Google Play remains the source of trial eligibility and billing lifecycle, RevenueCat exposes eligible subscription options and the active `premium` entitlement, and the Worker remains the only App authorization authority. Flutter adds only store-derived trial metadata, truthful paywall rendering, and a Google Play subscription-management link; Worker and D1 remain unchanged.

**Tech Stack:** Flutter/Dart, `purchases_flutter 10.4.1`, Flutter l10n ARB, Google Play Billing, RevenueCat, Cloudflare Worker/D1.

---

> Git note: this worktree requires separate user authorization before committing. The commit checkpoints below describe intended boundaries but must not be executed automatically.

### Task 1: Represent store-derived trial metadata

**Files:**
- Modify: `lib/product/premium_plan.dart`
- Modify: `lib/platform/revenuecat_service.dart:45-63`
- Test: `test/revenuecat_service_test.dart`

**Step 1: Write the failing mapping test**

Construct a RevenueCat monthly `Package` whose `defaultOption` contains a `P3D` free phase and a full-price phase. Assert that the mapped `PremiumPlan` contains `freeTrialDays == 3` and the full-price formatted string.

```dart
final plan = premiumPlanFromPackage(PremiumPlanId.monthly, package);
expect(plan.freeTrialDays, 3);
expect(plan.price, r'$2.99');
```

Add a second case whose default option is the base plan and assert `freeTrialDays` is null.

**Step 2: Run the test and verify RED**

Run `flutter test test/revenuecat_service_test.dart`.

Expected: FAIL because `freeTrialDays` and the RevenueCat package mapper do not exist.

**Step 3: Implement the minimal product model**

```dart
class PremiumPlan {
  const PremiumPlan({
    required this.id,
    required this.price,
    this.freeTrialDays,
  });

  final PremiumPlanId id;
  final String price;
  final int? freeTrialDays;

  bool get hasFreeTrial => freeTrialDays != null;
}
```

**Step 4: Implement the minimal RevenueCat mapper**

Map only a positive day-based `defaultOption.freePhase.billingPeriod` to `freeTrialDays`. Use `defaultOption.fullPricePhase?.price.formatted` for the post-trial price and fall back to `storeProduct.priceString`.

**Step 5: Run the focused test and verify GREEN**

Run `flutter test test/revenuecat_service_test.dart`.

Expected: all tests in the file pass.

**Step 6: Commit checkpoint (authorization required)**

```powershell
git add lib/product/premium_plan.dart lib/platform/revenuecat_service.dart test/revenuecat_service_test.dart
git commit -m "feat(membership): expose eligible Play trial terms"
```

### Task 2: Make the paywall trial-aware

**Files:**
- Modify: `test/profile_page_test.dart:1076-1230`
- Modify: `lib/ui/pages/profile_page.dart:1711-1942`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`

**Step 1: Write the failing eligible-user Widget test**

Provide monthly and annual plans, with `freeTrialDays: 3` only on monthly. Open the paywall and assert:

- monthly is selected by default;
- “免费试用 3 天” is visible;
- the disclosure includes the localized monthly renewal price;
- the CTA is “开始 3 天免费试用”;
- tapping the CTA purchases `PremiumPlanId.monthly`.

**Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/profile_page_test.dart --plain-name "paywall defaults to an eligible three-day monthly trial"
```

Expected: FAIL because the current paywall defaults to annual and renders no trial text.

**Step 3: Add localized trial messages and regenerate l10n**

Add ARB messages for the trial badge, post-trial renewal disclosure and trial CTA in Chinese and English, with typed `days` and `price` placeholders. Run `flutter gen-l10n`.

**Step 4: Implement dynamic paywall selection and disclosure**

- Select eligible monthly trial first; otherwise preserve annual-first behavior.
- Derive all trial rendering from the currently selected `PremiumPlan`.
- When annual is selected, remove trial CTA/disclosure immediately.
- Keep price strings store-localized and avoid hard-coded currency.
- Use a two-line or wrapping layout so English and 320dp-wide screens do not overflow.

**Step 5: Add ineligible and switching tests**

Cover monthly without trial, annual switching, only-monthly eligible plans, English copy and a narrow viewport without overflow.

**Step 6: Run `flutter test test/profile_page_test.dart` and verify GREEN**

Expected: all profile Widget tests pass with no overflow exceptions.

**Step 7: Commit checkpoint (authorization required)**

```powershell
git add lib/ui/pages/profile_page.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart test/profile_page_test.dart
git commit -m "feat(membership): present three-day trial terms"
```

### Task 3: Add the Google Play subscription-management entry

**Files:**
- Modify: `test/profile_page_test.dart`
- Modify: `lib/ui/pages/profile_page.dart:24-32,397-451,592-710`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`

**Step 1: Write the failing navigation test**

Open settings for a signed-in user, tap `settings-manage-subscription`, and assert the injected external launcher receives the Google Play subscriptions-center URI.

**Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/profile_page_test.dart --plain-name "signed-in settings open Google Play subscription management"
```

Expected: FAIL because the settings tile does not exist.

**Step 3: Implement the minimal settings entry**

- Add the public Google Play subscriptions-center URI next to the existing Play Store URL.
- Show the entry for every signed-in user, independent of current Premium status.
- Close the settings sheet before launching.
- Reuse the injected launcher seam and external application mode.
- On failure, show a localized SnackBar without changing membership state.

**Step 4: Add failure and signed-out tests**

Assert that launch failure shows the local error and that signed-out settings do not expose account subscription management.

**Step 5: Run `flutter test test/profile_page_test.dart` and verify GREEN**

Expected: all tests pass.

**Step 6: Commit checkpoint (authorization required)**

```powershell
git add lib/ui/pages/profile_page.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart test/profile_page_test.dart
git commit -m "feat(membership): link Play subscription management"
```

### Task 4: Update authoritative public contracts

**Files:**
- Modify: `docs/modules/membership.md`
- Modify: `docs/design/app-ui-v1.md`
- Modify: `docs/testing-release-playbook.md`
- Modify: `docs/release-configuration.md`
- Keep: `docs/plans/2026-07-19-google-play-three-day-trial-design.md`
- Keep: `docs/plans/2026-07-19-google-play-three-day-trial.md`

**Step 1: Document the stable contract**

Record that trial eligibility and duration come from Google Play, RevenueCat returns eligible options, trial users receive the existing `premium` entitlement, and Worker/D1 remain unchanged.

**Step 2: Document the platform configuration without claiming completion**

Add the intended Play Console Offer settings and explicitly mark the remote Offer as not configured/activated until independently verified. Do not write account identifiers or secrets.

**Step 3: Add the Play Billing Sandbox matrix**

Cover fresh eligible tester, prior subscriber, trial cancellation, automatic conversion, restore, RTDN/Webhook/Worker/D1 convergence, and management-link behavior. State that RevenueCat Test Store cannot prove Play eligibility.

**Step 4: Run `git diff --check`**

Expected: no whitespace errors.

**Step 5: Commit checkpoint (authorization required)**

```powershell
git add docs/modules/membership.md docs/design/app-ui-v1.md docs/testing-release-playbook.md docs/release-configuration.md docs/plans/2026-07-19-google-play-three-day-trial-design.md docs/plans/2026-07-19-google-play-three-day-trial.md
git commit -m "docs(membership): define Play trial rollout"
```

### Task 5: Full local verification

**Step 1: Run focused membership tests**

```powershell
flutter test test/revenuecat_service_test.dart test/account_controller_test.dart test/profile_page_test.dart test/membership_api_client_test.dart
```

Expected: all focused tests pass.

**Step 2: Run `flutter analyze`**

Expected: no issues.

**Step 3: Run `flutter test`**

Expected: all tests pass and replay baselines remain step0=5, v3=5, v4=3.

**Step 4: Check final scope**

```powershell
git diff --check
git status --short --branch
```

Expected: only scoped feature and documentation files are modified; no generated artifacts, secrets or user files are included.

### Task 6: Independent review and repair loop

**Step 1:** Start one read-only review agent with the approved design, implementation plan, full diff and actual verification output. Require review of exactly six axes: requirement completeness, logical correctness, edge cases, code quality, test coverage and actual runtime results.

**Step 2:** Convert findings into a repair checklist with severity, file/line, evidence and required verification.

**Step 3:** Repair every behavioral defect with a failing regression test first, then the smallest fix and focused/full verification.

**Step 4:** Ask the same review agent to re-verify the updated diff and test output. Repeat until pass or an external platform dependency is the only remaining blocker.

### Task 7: Platform activation after separate authorization

**Step 1:** Under the existing monthly auto-renewing base plan, create a three-day free-trial Offer with “new customer acquisition / never had any subscription in this app” eligibility. Confirm regions and activate only after explicit authorization.

**Step 2:** Use a fresh License Tester and confirm the current RevenueCat Offering returns a monthly default option with a three-day free phase and the correct full-price phase.

**Step 3:** Test start, cancel, conversion, ineligible fallback, app restart, restore, RTDN, RevenueCat Webhook, Worker reconciliation and D1 status. Never use a real payment method.

**Step 4:** Build a higher-versionCode AAB from committed source, verify signing/config/manifest/hash, upload Internal only with explicit authorization, then advance the same AAB to Alpha only after Internal passes and a new authorization is given.

**Execution checkpoint — 2026-07-19:**

- Step 1 complete: Play Offer `monthly-3d-trial` is active under `premium:monthly`, with a three-day free phase, new-customer acquisition eligibility scoped to users who have never had any subscription in this app, and 174/174 regions inherited from the monthly base plan.
- RevenueCat configuration check complete: the current `default` Offering, `$rc_monthly → premium:monthly`, `$rc_annual → premium:annual`, Published monthly product, and `premium` entitlement association remain intact; no dashboard mutation was needed.
- Steps 2–3 blocked before purchase: the connected device has multiple Google accounts and none matches the enabled License Tester list. The purchase sheet was not opened, no payment was attempted, and no device Google account was signed out, removed, or modified. Prefer a user-prepared dedicated test device or a dedicated Android user/work profile containing only one eligible License Tester; any agent action that signs out or removes an existing account requires separate explicit authorization plus a data/sync/recovery check. Then execute the full §6.6 matrix.
- A configured Debug APK was built but not installed. Step 4 remains unauthorized and untouched: no AAB was built/uploaded, no track was advanced, and no code was committed or pushed.
