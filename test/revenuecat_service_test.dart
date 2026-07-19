import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:test/test.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/premium_plan.dart';

void main() {
  group('premiumPlanFromPackage', () {
    test('maps an eligible three-day trial and its renewal price', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _monthlyPackage(freeTrialDays: 3),
      );

      expect(plan.freeTrialDays, 3);
      expect(plan.price, r'$2.99');
    });

    test('does not advertise a trial when Play returns only the base plan', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _monthlyPackage(),
      );

      expect(plan.freeTrialDays, isNull);
      expect(plan.price, r'$2.99');
    });

    test('ignores a non-day free phase that the paywall cannot describe', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.monthly,
        _monthlyPackage(freeTrialWeeks: 1),
      );

      expect(plan.freeTrialDays, isNull);
    });

    test('never advertises a trial on the annual plan', () {
      final plan = premiumPlanFromPackage(
        PremiumPlanId.annual,
        _monthlyPackage(freeTrialDays: 3),
      );

      expect(plan.freeTrialDays, isNull);
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

Package _monthlyPackage({int? freeTrialDays, int? freeTrialWeeks}) {
  const context = PresentedOfferingContext('default', null, null);
  const monthlyPeriod = Period(PeriodUnit.month, 1, 'P1M');
  const fullPrice = PricingPhase(
    monthlyPeriod,
    RecurrenceMode.infiniteRecurring,
    null,
    Price(r'$2.99', 2990000, 'USD'),
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
    freePhase == null ? 'monthly' : 'trial',
    'premium:monthly',
    'premium',
    [if (freePhase != null) freePhase, fullPrice],
    const [],
    freePhase == null,
    monthlyPeriod,
    false,
    fullPrice,
    freePhase,
    null,
    context,
    null,
  );
  final product = StoreProduct(
    'premium:monthly',
    'PushupAI Premium monthly subscription',
    'Monthly membership',
    2.99,
    r'$9.99',
    'USD',
    productCategory: ProductCategory.subscription,
    defaultOption: option,
    subscriptionOptions: [option],
    presentedOfferingContext: context,
    subscriptionPeriod: 'P1M',
  );
  return Package(r'$rc_monthly', PackageType.monthly, product, context);
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
