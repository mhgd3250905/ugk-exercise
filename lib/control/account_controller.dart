import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../platform/revenuecat_service.dart';
import '../product/membership_status.dart';
import '../product/premium_plan.dart';

typedef GoogleSignInCallback = Future<String?> Function();
typedef GoogleSignOutCallback = Future<void> Function();

class AccountErrorCode {
  const AccountErrorCode._();

  static const purchaseFailed = 'purchase_failed';
  static const requestFailed = 'account_request_failed';
  static const unexpected = 'account_unexpected_error';
}

class AccountController extends ChangeNotifier {
  AccountController({
    required AccountSessionStore sessionStore,
    required MembershipApiClient apiClient,
    required RevenueCatService revenueCat,
    required GoogleSignInCallback googleSignIn,
    GoogleSignOutCallback? googleSignOut,
    Future<void> Function()? clearAvatarImageCache,
  }) : _sessionStore = sessionStore,
       _apiClient = apiClient,
       _revenueCat = revenueCat,
       _googleSignIn = googleSignIn,
       _googleSignOut = googleSignOut ?? (() async {}),
       _clearAvatarImageCache =
           clearAvatarImageCache ?? (() => DefaultCacheManager().emptyCache());

  final AccountSessionStore _sessionStore;
  final MembershipApiClient _apiClient;
  final RevenueCatService _revenueCat;
  final GoogleSignInCallback _googleSignIn;
  final GoogleSignOutCallback _googleSignOut;
  final Future<void> Function() _clearAvatarImageCache;

  AppUser? _user;
  MembershipStatus _membership = MembershipStatus.none;
  Timer? _membershipExpiryTimer;
  String? _sessionToken;
  String? _appUserId;
  var _busy = false;
  String? _error;
  var _generation = 0;
  var _refreshRequest = 0;
  Future<void> _identityMutationQueue = Future.value();
  final _localRestoreCompleter = Completer<void>();

  AppUser? get user => _user;
  MembershipStatus get membership => _membership;
  bool get signedIn => _sessionToken != null && _appUserId != null;
  bool get premium => _membership.activeAt(DateTime.now());
  bool get busy => _busy;
  String? get error => _error;
  Future<void> get localRestoreCompleted => _localRestoreCompleter.future;
  SavedAccountSession? get currentSession {
    final token = _sessionToken;
    final appUserId = _appUserId;
    if (token == null || appUserId == null) {
      return null;
    }
    return SavedAccountSession(
      sessionToken: token,
      appUserId: appUserId,
      user: _user,
    );
  }

  Future<void> restore() async {
    await _run((generation) async {
      SavedAccountSession? saved;
      try {
        saved = await _sessionStore.load();
      } finally {
        if (!_localRestoreCompleter.isCompleted) {
          _localRestoreCompleter.complete();
        }
      }
      if (!_isCurrent(generation) || saved == null) {
        return;
      }
      _sessionToken = saved.sessionToken;
      _appUserId = saved.appUserId;
      _user = saved.user;
      notifyListeners();
      try {
        final snapshot = await _apiClient.me(
          saved.sessionToken,
          appUserId: saved.appUserId,
        );
        if (_isCurrent(generation)) {
          await _applySnapshot(snapshot, generation);
        }
      } on MembershipApiException catch (error) {
        if (error.statusCode != 401 || !_isCurrent(generation)) {
          rethrow;
        }
        _clearAccountState();
        await _serializeIdentity(() async {
          if (_isCurrent(generation)) {
            await _sessionStore.clear();
          }
        });
      }
    });
  }

  Future<void> refresh() async {
    final account = currentSession;
    if (account == null || _busy) {
      return;
    }
    final generation = _generation;
    final request = ++_refreshRequest;
    try {
      final snapshot = await _apiClient.me(
        account.sessionToken,
        appUserId: account.appUserId,
      );
      if (request != _refreshRequest ||
          !_isCurrentAccount(generation, account)) {
        return;
      }
      _user = snapshot.user;
      _setMembership(snapshot.membership);
      notifyListeners();
      await _saveAccountUser(generation, account, snapshot.user);
    } catch (_) {
      // Passive refresh failures keep the last confirmed shared snapshot.
    }
  }

  Future<void> signIn() async {
    await _run((generation) async {
      final idToken = await _googleSignIn();
      if (!_isCurrent(generation) || idToken == null) {
        return;
      }
      final snapshot = await _apiClient.authGoogle(idToken);
      if (!_isCurrent(generation)) {
        return;
      }
      await _serializeIdentity(() async {
        if (_isCurrent(generation)) {
          await _sessionStore.save(
            SavedAccountSession(
              sessionToken: snapshot.sessionToken,
              appUserId: snapshot.appUserId,
              user: snapshot.user,
            ),
          );
        }
      });
      if (_isCurrent(generation)) {
        await _applySnapshot(snapshot, generation, persistSession: false);
      }
    });
  }

  Future<void> signOut() async {
    await _run((generation) async {
      _clearAccountState();
      try {
        await _serializeIdentity(() async {
          if (!_isCurrent(generation)) {
            return;
          }
          await _sessionStore.clear();
          try {
            await _clearAvatarImageCache();
          } finally {
            if (_isCurrent(generation)) {
              await _revenueCat.logOut();
            }
          }
        });
      } finally {
        if (_isCurrent(generation)) {
          await _googleSignOut();
        }
      }
    });
  }

  Future<List<PremiumPlan>> loadPremiumPlans() async {
    final generation = _generation;
    final account = currentSession;
    if (account == null) {
      return const [];
    }
    final plans = await _serializeIdentity(() async {
      if (!_isCurrentAccount(generation, account)) {
        return const <PremiumPlan>[];
      }
      final result = await _revenueCat.loadPremiumPlans();
      return _isCurrentAccount(generation, account)
          ? result
          : const <PremiumPlan>[];
    });
    return _isCurrentAccount(generation, account)
        ? plans
        : const <PremiumPlan>[];
  }

  Future<void> purchasePremiumPlan(PremiumPlanId planId) async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      await _serializeIdentity(() async {
        if (!_isCurrentAccount(generation, account)) {
          return;
        }
        await _revenueCat.purchasePremiumPlan(planId);
      });
      if (_isCurrentAccount(generation, account)) {
        await _reconcileMembership(generation, account);
      }
    });
  }

  Future<void> restorePurchases() async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      await _serializeIdentity(() async {
        if (!_isCurrentAccount(generation, account)) {
          return;
        }
        await _revenueCat.restorePurchases();
      });
      if (_isCurrentAccount(generation, account)) {
        await _reconcileMembership(generation, account);
      }
    });
  }

  Future<void> updateProfile({
    required String nickname,
    required String avatarKey,
  }) async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      final updatedUser = await _apiClient.updateProfile(
        account.sessionToken,
        nickname: nickname,
        avatarKey: avatarKey,
      );
      if (_isCurrentAccount(generation, account)) {
        _user = updatedUser;
        await _saveAccountUser(generation, account, updatedUser);
      }
    });
  }

  Future<void> acceptAvatarPolicy(String policyVersion) async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      await _apiClient.acceptAvatarPolicy(
        account.sessionToken,
        policyVersion: policyVersion,
      );
      if (!_isCurrentAccount(generation, account)) {
        return;
      }
      final snapshot = await _apiClient.me(
        account.sessionToken,
        appUserId: account.appUserId,
      );
      if (_isCurrentAccount(generation, account)) {
        _user = snapshot.user;
        await _saveAccountUser(generation, account, snapshot.user);
      }
    });
  }

  Future<void> uploadAvatar(Uint8List jpegBytes) async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      final updatedUser = await _apiClient.uploadAvatar(
        account.sessionToken,
        jpegBytes,
      );
      if (_isCurrentAccount(generation, account)) {
        _user = updatedUser;
        await _saveAccountUser(generation, account, updatedUser);
      }
    });
  }

  Future<void> deleteAvatar() async {
    await _run((generation) async {
      final account = currentSession;
      if (account == null) {
        return;
      }
      final updatedUser = await _apiClient.deleteAvatar(account.sessionToken);
      if (_isCurrentAccount(generation, account)) {
        _user = updatedUser;
        await _saveAccountUser(generation, account, updatedUser);
      }
    });
  }

  Future<void> _reconcileMembership(
    int generation,
    SavedAccountSession account,
  ) async {
    final membership = await _apiClient.reconcileMembership(
      account.sessionToken,
    );
    if (_isCurrentAccount(generation, account)) {
      _setMembership(membership);
    }
  }

  Future<void> _applySnapshot(
    AccountSnapshot snapshot,
    int generation, {
    bool persistSession = true,
  }) async {
    if (!_isCurrent(generation)) {
      return;
    }
    _sessionToken = snapshot.sessionToken;
    _appUserId = snapshot.appUserId;
    _user = snapshot.user;
    _setMembership(snapshot.membership);
    final account = SavedAccountSession(
      sessionToken: snapshot.sessionToken,
      appUserId: snapshot.appUserId,
    );
    notifyListeners();
    if (persistSession) {
      await _saveAccountUser(generation, account, snapshot.user);
    }
    if (!_isCurrentAccount(generation, account)) {
      return;
    }
    await _serializeIdentity(() async {
      if (!_isCurrent(generation)) {
        return;
      }
      await _revenueCat.configure(appUserId: snapshot.appUserId);
    });
  }

  Future<void> _saveAccountUser(
    int generation,
    SavedAccountSession account,
    AppUser user,
  ) async {
    await _serializeIdentity(() async {
      if (_isCurrentAccount(generation, account)) {
        await _sessionStore.save(
          SavedAccountSession(
            sessionToken: account.sessionToken,
            appUserId: account.appUserId,
            user: user,
          ),
        );
      }
    });
  }

  void _clearAccountState() {
    _sessionToken = null;
    _appUserId = null;
    _user = null;
    _setMembership(MembershipStatus.none);
  }

  void _setMembership(MembershipStatus membership) {
    _membershipExpiryTimer?.cancel();
    _membershipExpiryTimer = null;
    _membership = membership;
    final expiry = membership.expiresAt;
    if (!membership.isActive || expiry == null) {
      return;
    }
    final delay = expiry.difference(DateTime.now());
    if (delay <= Duration.zero) {
      return;
    }
    _membershipExpiryTimer = Timer(delay, () {
      _membershipExpiryTimer = null;
      if (identical(_membership, membership)) {
        notifyListeners();
      }
    });
  }

  bool _isCurrent(int generation) => generation == _generation;

  bool _isCurrentAccount(int generation, SavedAccountSession account) {
    final current = currentSession;
    return _isCurrent(generation) &&
        current?.sessionToken == account.sessionToken &&
        current?.appUserId == account.appUserId;
  }

  Future<T> _serializeIdentity<T>(Future<T> Function() mutation) {
    final result = Completer<T>();
    _identityMutationQueue = _identityMutationQueue.then((_) async {
      try {
        result.complete(await mutation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _run(Future<void> Function(int generation) action) async {
    final generation = ++_generation;
    _busy = true;
    _error = null;
    notifyListeners();
    String? errorMessage;
    try {
      await action(generation);
    } on PurchaseCancelledException {
      // Purchase cancellation is an intentional user choice, not an error.
    } on PurchaseFailedException {
      errorMessage = AccountErrorCode.purchaseFailed;
    } on MembershipApiException catch (error) {
      errorMessage = error.errorCode ?? AccountErrorCode.requestFailed;
    } catch (_) {
      errorMessage = AccountErrorCode.unexpected;
    } finally {
      if (_isCurrent(generation)) {
        _error = errorMessage;
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _membershipExpiryTimer?.cancel();
    super.dispose();
  }
}
