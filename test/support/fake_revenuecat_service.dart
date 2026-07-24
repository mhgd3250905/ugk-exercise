import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/premium_plan.dart';

class FakeRevenueCatService implements RevenueCatService {
  FakeRevenueCatService({
    required this.isPremium,
    this.premiumPlans = const [],
  });

  bool isPremium;
  List<PremiumPlan> premiumPlans;
  String? configuredAppUserId;
  PremiumPlanId? purchasedPlanId;
  var purchaseCalls = 0;
  var restoreCalls = 0;

  @override
  Future<void> configure({required String appUserId}) async {
    configuredAppUserId = appUserId;
  }

  @override
  Future<List<PremiumPlan>> loadPremiumPlans() async => premiumPlans;

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async {
    purchaseCalls++;
    purchasedPlanId = planId;
    return isPremium;
  }

  @override
  Future<bool> restorePurchases() async {
    restoreCalls++;
    return isPremium;
  }

  @override
  Future<void> logOut() async {
    configuredAppUserId = null;
  }
}
