import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:test/test.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/premium_plan.dart';

import 'support/fake_revenuecat_service.dart';

void main() {
  test(
    'production package map preserves monthly and annual package identity',
    () {
      final monthly = _package(PremiumPlanId.monthly);
      final annual = _package(PremiumPlanId.annual);

      final packages = premiumPackagesByPlan(monthly: monthly, annual: annual);

      expect(packages[PremiumPlanId.monthly], same(monthly));
      expect(packages[PremiumPlanId.annual], same(annual));
    },
  );

  group('premiumPlanFromPackage', () {
    test('maps an eligible three-day trial and its renewal price', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _package(PremiumPlanId.monthly, freeTrialDays: 3),
      );

      expect(plan.freeTrialDays, 3);
      expect(plan.price, r'$2.99');
    });

    test('maps an eligible seven-day annual trial and renewal price', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.annual,
        _package(PremiumPlanId.annual, freeTrialDays: 7),
      );

      expect(plan.freeTrialDays, 7);
      expect(plan.price, r'$20.00');
    });

    test('does not advertise a trial when Play returns only the base plan', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _package(PremiumPlanId.monthly),
      );

      expect(plan.freeTrialDays, isNull);
      expect(plan.price, r'$2.99');
    });

    test('ignores a non-day free phase that the paywall cannot describe', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _package(PremiumPlanId.monthly, freeTrialWeeks: 1),
      );

      expect(plan.freeTrialDays, isNull);
    });

    test(
      'rejects a monthly trial whose duration is not exactly three days',
      () {
        final plan = premiumPlanFromPackage(
          PremiumPlanId.monthly,
          _package(PremiumPlanId.monthly, freeTrialDays: 5),
        );

        expect(plan.freeTrialDays, isNull);
      },
    );

    test(
      'rejects an annual trial whose duration is not exactly seven days',
      () {
        final plan = premiumPlanFromPackage(
          PremiumPlanId.annual,
          _package(PremiumPlanId.annual, freeTrialDays: 3),
        );

        expect(plan.freeTrialDays, isNull);
      },
    );

    test('rejects a trial without a complete full-price phase', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _package(
          PremiumPlanId.monthly,
          freeTrialDays: 3,
          includeFullPricePhase: false,
        ),
      );

      expect(plan.freeTrialDays, isNull);
      expect(plan.price, r'$2.99');
    });

    test('rejects a trial with an empty localized renewal price', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.annual,
        _package(
          PremiumPlanId.annual,
          freeTrialDays: 7,
          fullPriceFormatted: '',
        ),
      );

      expect(plan.freeTrialDays, isNull);
      expect(plan.price, r'$20.00');
    });

    test('falls back to the store product price without a default option', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _monthlyPackageWithoutOption(),
      );

      expect(plan.freeTrialDays, isNull);
      expect(plan.price, r'$2.99');
    });
  });

  test(
    'fake revenuecat service loads plans and purchases the selected plan',
    () async {
      const plans = [
        PremiumPlan(id: PremiumPlanId.monthly, price: r'$2.99'),
        PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
      ];
      final service = FakeRevenueCatService(
        isPremium: true,
        premiumPlans: plans,
      );

      expect(await service.loadPremiumPlans(), plans);
      expect(await service.purchasePremiumPlan(PremiumPlanId.annual), isTrue);
      expect(service.purchasedPlanId, PremiumPlanId.annual);
    },
  );
}

Package _package(
  PremiumPlanId planId, {
  int? freeTrialDays,
  int? freeTrialWeeks,
  bool includeFullPricePhase = true,
  String? fullPriceFormatted,
}) {
  const context = PresentedOfferingContext('default', null, null);
  final billingPeriod = planId == PremiumPlanId.monthly
      ? const Period(PeriodUnit.month, 1, 'P1M')
      : const Period(PeriodUnit.year, 1, 'P1Y');
  final priceString = planId == PremiumPlanId.monthly ? r'$2.99' : r'$20.00';
  final fullPrice = PricingPhase(
    billingPeriod,
    RecurrenceMode.infiniteRecurring,
    null,
    Price(fullPriceFormatted ?? priceString, 2990000, 'USD'),
    null,
  );
  final freePeriod = freeTrialDays != null
      ? Period(PeriodUnit.day, freeTrialDays, 'P${freeTrialDays}D')
      : freeTrialWeeks != null
      ? Period(PeriodUnit.week, freeTrialWeeks, 'P${freeTrialWeeks}W')
      : null;
  final freePhase = freePeriod == null
      ? null
      : PricingPhase(
          freePeriod,
          RecurrenceMode.finiteRecurring,
          1,
          const Price(r'$0.00', 0, 'USD'),
          OfferPaymentMode.freeTrial,
        );
  final option = SubscriptionOption(
    freePhase == null ? planId.name : '${planId.name}-trial',
    'premium:${planId.name}',
    planId.name,
    [if (freePhase != null) freePhase, if (includeFullPricePhase) fullPrice],
    const [],
    freePhase == null,
    billingPeriod,
    false,
    includeFullPricePhase ? fullPrice : null,
    freePhase,
    null,
    context,
    null,
  );
  final product = StoreProduct(
    'premium:${planId.name}',
    'PushupAI Premium ${planId.name} subscription',
    '${planId.name} membership',
    planId == PremiumPlanId.monthly ? 2.99 : 20,
    priceString,
    'USD',
    productCategory: ProductCategory.subscription,
    defaultOption: option,
    subscriptionOptions: [option],
    presentedOfferingContext: context,
    subscriptionPeriod: billingPeriod.iso8601,
  );
  return Package(
    planId == PremiumPlanId.monthly ? r'$rc_monthly' : r'$rc_annual',
    planId == PremiumPlanId.monthly ? PackageType.monthly : PackageType.annual,
    product,
    context,
  );
}

Package _monthlyPackageWithoutOption() {
  const context = PresentedOfferingContext('default', null, null);
  const product = StoreProduct(
    'premium:monthly',
    'PushupAI Premium monthly subscription',
    'Monthly membership',
    2.99,
    r'$2.99',
    'USD',
    productCategory: ProductCategory.subscription,
    presentedOfferingContext: context,
    subscriptionPeriod: 'P1M',
  );
  return const Package(r'$rc_monthly', PackageType.monthly, product, context);
}
