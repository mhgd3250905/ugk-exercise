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
  var _membershipVerificationPending = false;
  var _membershipExpiryVerificationQueued = false;
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
  bool get membershipVerificationPending => _membershipVerificationPending;
  String? get error => _error;

  /// Clears a stale error left by a previous operation.
  ///
  /// [_error] is only reset inside [_run], so a passive [refresh] failure
  /// (which is swallowed) leaves a sticky error on this app-scoped controller.
  /// Pages call this when re-entering so the user does not see an outdated
  /// error banner unrelated to the current view.
  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

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
      _membershipVerificationPending = true;
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
      _acceptUserAndMembership(snapshot);
      await _saveAccountUser(generation, account, snapshot.user);
    } on MembershipApiException catch (error) {
      if (error.statusCode == 401 &&
          request == _refreshRequest &&
          _isCurrentAccount(generation, account)) {
        _refreshRequest++;
        _clearAccountState();
        notifyListeners();
        await _serializeIdentity(() async {
          if (_isCurrent(generation) && currentSession == null) {
            await _sessionStore.clear();
          }
        });
      }
      // Passive non-auth failures keep the last confirmed shared snapshot.
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
        await _ensureRevenueCatConfigured(account);
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
        await _ensureRevenueCatConfigured(account);
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
        _acceptUserAndMembership(snapshot);
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
    _acceptUserAndMembership(snapshot, notify: false);
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
    // RevenueCat.configure associates the app user id with the local purchase
    // SDK for later membership reconciliation. It is an auxiliary step: by the
    // time we get here the snapshot (session + user + membership) is already
    // applied from the server, so a configure failure (typically a transient
    // network error) must NOT fail the whole sign-in/restore and surface a
    // scary "operation failed" banner on top of a successful login. Swallow it
    // here. NOTE: configure is only invoked from this path, so a swallowed
    // failure leaves the SDK unconfigured for the rest of the session until the
    // next full signIn/restore runs _applySnapshot again — purchase/restore
    // re-attempt the linkage first via _ensureRevenueCatConfigured to avoid a
    // silent dead purchase path after a single network blip.
    await _serializeIdentity(() async {
      if (!_isCurrent(generation)) {
        return;
      }
      try {
        await _revenueCat.configure(appUserId: snapshot.appUserId);
      } catch (_) {
        // Auxiliary SDK wiring failed; the authoritative account snapshot is
        // already applied above, so keep the session intact.
      }
    });
  }

  // Best-effort RevenueCat wiring before a purchase/restore. configure() runs
  // once during _applySnapshot; if that call failed (transient network error)
  // the SDK stays unconfigured and purchase/restore would silently no-op for
  // the rest of the session. Retry it here, swallowing any failure so a broken
  // SDK linkage never blocks or fails an otherwise-valid action.
  Future<void> _ensureRevenueCatConfigured(SavedAccountSession account) async {
    try {
      await _revenueCat.configure(appUserId: account.appUserId);
    } catch (_) {
      // Still unconfigured; the purchase/restore call below will report its own
      // outcome and the snapshot remains the source of truth.
    }
  }

  void _acceptUserAndMembership(
    AccountSnapshot snapshot, {
    bool notify = true,
  }) {
    _user = snapshot.user;
    _setMembership(snapshot.membership);
    _membershipExpiryVerificationQueued = false;
    _membershipVerificationPending = false;
    if (notify) {
      notifyListeners();
    }
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
    _membershipExpiryVerificationQueued = false;
    _membershipVerificationPending = false;
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
        _queueMembershipExpiryVerification();
      }
    });
  }

  void _queueMembershipExpiryVerification() {
    if (!signedIn) {
      notifyListeners();
      return;
    }
    _membershipVerificationPending = true;
    _membershipExpiryVerificationQueued = true;
    notifyListeners();
    _drainMembershipExpiryVerification();
  }

  void _drainMembershipExpiryVerification() {
    if (!_membershipExpiryVerificationQueued || _busy) {
      return;
    }
    _membershipExpiryVerificationQueued = false;
    if (!signedIn || _membership.activeAt(DateTime.now())) {
      if (_membershipVerificationPending) {
        _membershipVerificationPending = false;
        notifyListeners();
      }
      return;
    }
    unawaited(refresh());
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
    if (_membershipVerificationPending &&
        _membership.isActive &&
        !_membership.activeAt(DateTime.now())) {
      _membershipExpiryVerificationQueued = true;
    }
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
        _drainMembershipExpiryVerification();
      }
    }
  }

  @override
  void dispose() {
    _membershipExpiryTimer?.cancel();
    super.dispose();
  }
}
