import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/membership_config.dart';
import '../product/premium_plan.dart';
import 'ugk_log.dart';

class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

class PurchaseFailedException implements Exception {
  const PurchaseFailedException(this.message);

  final String message;
}

Map<PremiumPlanId, Package> premiumPackagesByPlan({
  Package? monthly,
  Package? annual,
}) {
  return {
    if (monthly case final package?) PremiumPlanId.monthly: package,
    if (annual case final package?) PremiumPlanId.annual: package,
  };
}

PremiumPlan premiumPlanFromPackage(PremiumPlanId id, Package package) {
  final product = package.storeProduct;
  final option = product.defaultOption;
  final freePeriod = option?.freePhase?.billingPeriod;
  final fullPrice = option?.fullPricePhase?.price.formatted;
  final expectedTrialDays = switch (id) {
    PremiumPlanId.monthly => 3,
    PremiumPlanId.annual => 7,
  };
  final freeTrialDays =
      freePeriod?.unit == PeriodUnit.day &&
          freePeriod!.value == expectedTrialDays &&
          fullPrice != null &&
          fullPrice.trim().isNotEmpty
      ? expectedTrialDays
      : null;
  return PremiumPlan(
    id: id,
    price: fullPrice == null || fullPrice.trim().isEmpty
        ? product.priceString
        : fullPrice,
    freeTrialDays: freeTrialDays,
  );
}

abstract class RevenueCatService {
  Future<void> configure({required String appUserId});
  Future<List<PremiumPlan>> loadPremiumPlans();
  Future<bool> purchasePremiumPlan(PremiumPlanId planId);
  Future<bool> restorePurchases();
  Future<void> logOut();
}

class PurchasesRevenueCatService implements RevenueCatService {
  var _configured = false;
  Map<PremiumPlanId, Package> _premiumPackages = const {};

  @override
  Future<void> configure({required String appUserId}) async {
    if (revenueCatAndroidApiKey.isEmpty) {
      return;
    }
    if (!_configured) {
      await Purchases.configure(
        PurchasesConfiguration(revenueCatAndroidApiKey)..appUserID = appUserId,
      );
      _configured = true;
      return;
    }
    await Purchases.logIn(appUserId);
  }

  @override
  Future<List<PremiumPlan>> loadPremiumPlans() async {
    if (!_configured) {
      return const [];
    }
    final offering = (await Purchases.getOfferings()).current;
    _premiumPackages = premiumPackagesByPlan(
      monthly: offering?.monthly,
      annual: offering?.annual,
    );
    return _premiumPackages.entries
        .map((entry) => premiumPlanFromPackage(entry.key, entry.value))
        .toList(growable: false);
  }

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async {
    final package = _premiumPackages[planId];
    return package == null ? false : _purchasePackage(package);
  }

  Future<bool> _purchasePackage(Package package) async {
    final PurchaseResult result;
    try {
      result = await Purchases.purchase(PurchaseParams.package(package));
    } on PlatformException catch (error) {
      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelledException();
      }
      ugkLog('purchase: failed code=${errorCode.name}');
      throw const PurchaseFailedException('购买没有完成，请稍后再试。');
    }
    return result.customerInfo.entitlements.active.containsKey(
      premiumEntitlementId,
    );
  }

  @override
  Future<bool> restorePurchases() async {
    if (!_configured) {
      return false;
    }
    final info = await Purchases.restorePurchases();
    return info.entitlements.active.containsKey(premiumEntitlementId);
  }

  @override
  Future<void> logOut() async {
    if (_configured) {
      await Purchases.logOut();
    }
  }
}

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
