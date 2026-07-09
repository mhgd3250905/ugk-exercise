import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../platform/revenuecat_service.dart';
import '../product/membership_status.dart';

typedef GoogleSignInCallback = Future<String?> Function();

class AccountController extends ChangeNotifier {
  AccountController({
    required AccountSessionStore sessionStore,
    required MembershipApiClient apiClient,
    required RevenueCatService revenueCat,
    required GoogleSignInCallback googleSignIn,
  }) : _sessionStore = sessionStore,
       _apiClient = apiClient,
       _revenueCat = revenueCat,
       _googleSignIn = googleSignIn;

  final AccountSessionStore _sessionStore;
  final MembershipApiClient _apiClient;
  final RevenueCatService _revenueCat;
  final GoogleSignInCallback _googleSignIn;

  AppUser? _user;
  MembershipStatus _membership = MembershipStatus.none;
  String? _sessionToken;
  String? _appUserId;
  var _busy = false;
  String? _error;

  AppUser? get user => _user;
  MembershipStatus get membership => _membership;
  bool get signedIn => _sessionToken != null && _appUserId != null;
  bool get premium => _membership.activeAt(DateTime.now());
  bool get busy => _busy;
  String? get error => _error;

  Future<void> restore() async {
    await _run(() async {
      final saved = await _sessionStore.load();
      if (saved == null) {
        return;
      }
      final snapshot = await _apiClient.me(
        saved.sessionToken,
        appUserId: saved.appUserId,
      );
      await _applySnapshot(snapshot);
    });
  }

  Future<void> signIn() async {
    await _run(() async {
      final idToken = await _googleSignIn();
      if (idToken == null) {
        return;
      }
      final snapshot = await _apiClient.authGoogle(idToken);
      await _sessionStore.save(
        SavedAccountSession(
          sessionToken: snapshot.sessionToken,
          appUserId: snapshot.appUserId,
        ),
      );
      await _applySnapshot(snapshot);
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await _sessionStore.clear();
      await _revenueCat.logOut();
      _sessionToken = null;
      _appUserId = null;
      _user = null;
      _membership = MembershipStatus.none;
    });
  }

  Future<void> purchasePremium() async {
    await _run(() async {
      await _applyRevenueCatActive(await _revenueCat.purchasePremium());
    });
  }

  Future<void> restorePurchases() async {
    await _run(() async {
      await _applyRevenueCatActive(await _revenueCat.restorePurchases());
    });
  }

  Future<void> _applyRevenueCatActive(bool active) async {
    if (active) {
      _membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: _membership.expiresAt,
        source: 'revenuecat_google_play',
      );
      return;
    }
    final sessionToken = _sessionToken;
    final appUserId = _appUserId;
    if (sessionToken == null || appUserId == null) {
      return;
    }
    await _applySnapshot(
      await _apiClient.me(sessionToken, appUserId: appUserId),
    );
  }

  Future<void> _applySnapshot(AccountSnapshot snapshot) async {
    _sessionToken = snapshot.sessionToken;
    _appUserId = snapshot.appUserId;
    _user = snapshot.user;
    _membership = snapshot.membership;
    await _revenueCat.configure(appUserId: snapshot.appUserId);
    final active = await _revenueCat.refreshPremium();
    if (active && !_membership.isActive) {
      _membership = MembershipStatus(
        entitlement: _membership.entitlement,
        isActive: true,
        expiresAt: _membership.expiresAt,
        source: 'revenuecat_google_play',
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } on PurchaseCancelledException {
      // Purchase cancellation is an intentional user choice, not an error.
    } on PurchaseFailedException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
