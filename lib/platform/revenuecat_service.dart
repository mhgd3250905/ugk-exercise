import 'package:purchases_flutter/purchases_flutter.dart';

import '../ui/app_theme.dart';

abstract class RevenueCatService {
  Future<void> configure({required String appUserId});
  Future<bool> refreshPremium();
  Future<bool> purchasePremium();
  Future<bool> restorePurchases();
  Future<void> logOut();
}

class PurchasesRevenueCatService implements RevenueCatService {
  var _configured = false;

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
  Future<bool> refreshPremium() async {
    if (!_configured) {
      return false;
    }
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(premiumEntitlementId);
  }

  @override
  Future<bool> purchasePremium() async {
    if (!_configured) {
      return false;
    }
    final offerings = await Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const [];
    if (packages.isEmpty) {
      return false;
    }
    final result = await Purchases.purchase(
      PurchaseParams.package(packages.first),
    );
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
  FakeRevenueCatService({required this.isPremium});

  bool isPremium;
  String? configuredAppUserId;
  var purchaseCalls = 0;
  var restoreCalls = 0;

  @override
  Future<void> configure({required String appUserId}) async {
    configuredAppUserId = appUserId;
  }

  @override
  Future<bool> refreshPremium() async => isPremium;

  @override
  Future<bool> purchasePremium() async {
    purchaseCalls++;
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
