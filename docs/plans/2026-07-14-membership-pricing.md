# Membership Pricing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a custom two-plan Premium paywall that defaults to annual, shows store-localized prices, and purchases the explicitly selected RevenueCat Package.

**Architecture:** Keep one `premium` entitlement and introduce only a pure-Dart plan value used across product, control, and UI. RevenueCat owns Package discovery and purchase; the controller preserves account guards; the custom sheet owns selection and retry UI. Worker/D1 remain unchanged.

**Tech Stack:** Flutter, Dart, `purchases_flutter`, Flutter Widget tests.

---

### Task 1: Premium plan contract and RevenueCat mapping

**Files:**
- Create: `lib/product/premium_plan.dart`
- Modify: `lib/platform/revenuecat_service.dart`
- Test: `test/revenuecat_service_test.dart`

**Step 1: Write the failing test**

Add tests that inject a current Offering with monthly and annual Packages, then expect `loadPremiumPlans()` to return their store-formatted prices and `purchasePremium(PremiumPlanId.monthly)` to pass the monthly Package to the purchase callback.

**Step 2: Run test to verify it fails**

Run: `flutter test test/revenuecat_service_test.dart`

Expected: FAIL because `PremiumPlanId`, `loadPremiumPlans`, and the selected-plan purchase API do not exist.

**Step 3: Write minimal implementation**

Create:

```dart
enum PremiumPlanId { monthly, annual }

class PremiumPlan {
  const PremiumPlan({required this.id, required this.price});
  final PremiumPlanId id;
  final String price;
}
```

Change the service contract to load plans and purchase by `PremiumPlanId`. Map only `offering.monthly` and `offering.annual`, cache those Packages, and return `false` when the selected Package is unavailable.

**Step 4: Run test to verify it passes**

Run: `flutter test test/revenuecat_service_test.dart`

Expected: PASS.

### Task 2: Controller selection and session guard

**Files:**
- Modify: `lib/control/account_controller.dart`
- Test: `test/account_controller_test.dart`

**Step 1: Write the failing tests**

Expect the controller to return RevenueCat plans for the current account, pass the selected ID to purchase, and discard a plan load that completes after sign-out.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/account_controller_test.dart`

Expected: FAIL because controller plan loading and selected purchase do not exist.

**Step 3: Write minimal implementation**

Add `loadPremiumPlans()` with generation/account checks around the RevenueCat await. Change `purchasePremium` to require `PremiumPlanId` and retain the existing serialized identity mutation and post-await account checks.

**Step 4: Run tests to verify they pass**

Run: `flutter test test/account_controller_test.dart`

Expected: PASS.

### Task 3: Two-plan custom paywall

**Files:**
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`
- Test: `test/profile_page_test.dart`

**Step 1: Write the failing Widget tests**

Cover annual default selection, switching to monthly before continuing, one-plan fallback, and retry when loading returns no plans.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/profile_page_test.dart`

Expected: FAIL because the sheet has no plan cards or loading state.

**Step 3: Write minimal implementation**

Make the sheet stateful, load plans once, select annual when available, render only returned plans with their localized store prices, and return the selected `PremiumPlanId`. Show a localized unavailable message and retry button when no plans load.

**Step 4: Regenerate localization**

Run: `flutter gen-l10n`

**Step 5: Run tests to verify they pass**

Run: `flutter test test/profile_page_test.dart`

Expected: PASS.

### Task 4: Full verification

**Files:**
- Verify only.

**Step 1: Run static analysis**

Run: `flutter analyze`

Expected: no issues.

**Step 2: Run full Flutter suite**

Run: `flutter test`

Expected: all tests pass and replay baselines remain 5/5/3.

**Step 3: Check the patch**

Run: `git diff --check`

Expected: no whitespace errors; only membership pricing files and generated l10n output changed.
