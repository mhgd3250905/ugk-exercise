import 'package:test/test.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/premium_plan.dart';

void main() {
  test(
    'fake revenuecat service can toggle premium for controller tests',
    () async {
      final service = FakeRevenueCatService(isPremium: false);

      expect(await service.refreshPremium(), isFalse);

      service.isPremium = true;
      expect(await service.refreshPremium(), isTrue);
    },
  );

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
