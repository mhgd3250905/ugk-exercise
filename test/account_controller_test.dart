import 'dart:async';

import 'package:test/test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/membership_status.dart';

void main() {
  test('signIn saves session and configures RevenueCat', () async {
    final store = MemoryAccountSessionStore();
    final api = _FakeMembershipApiClient();
    final revenueCat = FakeRevenueCatService(isPremium: true);
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );

    await controller.signIn();

    expect(controller.signedIn, isTrue);
    expect(controller.premium, isTrue);
    expect((await store.load())?.sessionToken, 'session_1');
    expect(revenueCat.configuredAppUserId, 'user_1');
  });

  test('restore loads existing session', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(sessionToken: 'session_1', appUserId: 'user_1'),
    );
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => null,
    );

    await controller.restore();

    expect(controller.signedIn, isTrue);
    expect(controller.premium, isFalse);
  });

  test('signOut clears session', () async {
    final store = MemoryAccountSessionStore();
    final revenueCat = FakeRevenueCatService(isPremium: true);
    var googleSignedOut = false;
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      googleSignOut: () async => googleSignedOut = true,
    );
    await controller.signIn();

    await controller.signOut();

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(revenueCat.configuredAppUserId, isNull);
    expect(googleSignedOut, isTrue);
    expect(controller.currentSession, isNull);
  });

  test('signOut clears local session when RevenueCat logout fails', () async {
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _ThrowingLogOutRevenueCatService(),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.signOut();

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(await store.load(), isNull);
  });

  test('restore clears expired local session', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(sessionToken: 'expired', appUserId: 'user_1'),
    );
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ExpiredSessionMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => null,
    );

    await controller.restore();

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(controller.error, isNull);
    expect(controller.currentSession, isNull);
  });

  test('purchase cancellation does not show an error', () async {
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _CancelRevenueCatService(),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.purchasePremium();

    expect(controller.error, isNull);
    expect(controller.premium, isFalse);
  });

  test('purchase failure shows a short user message', () async {
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _FailRevenueCatService(),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.purchasePremium();

    expect(controller.error, AccountErrorCode.purchaseFailed);
    expect(controller.error, isNot(contains('PlatformException')));
  });

  test(
    'purchase refreshes server membership when sdk result is not active',
    () async {
      final api = _FakeMembershipApiClient();
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();
      api.membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        source: 'revenuecat_google_play',
      );

      await controller.purchasePremium();

      expect(controller.premium, isTrue);
    },
  );

  test('sdk active membership ignores stale server expiry', () async {
    final api = _FakeMembershipApiClient()
      ..membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'revenuecat_google_play',
      );
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: true),
      googleSignIn: () async => 'google-token',
    );

    await controller.signIn();

    expect(controller.premium, isTrue);
  });

  test(
    'currentSession exposes saved token and appUserId after sign in',
    () async {
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: _FakeMembershipApiClient(),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );

      await controller.signIn();

      expect(
        controller.currentSession,
        const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
      );
    },
  );

  test('updateProfile refreshes current user', () async {
    final api = _FakeMembershipApiClient();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.updateProfile(nickname: '训练者 01', avatarKey: 'ring-green');

    expect(controller.user?.publicDisplayName, '训练者 01');
    expect(controller.user?.avatarKey, 'ring-green');
  });

  test('updateProfile ignores stale result after signOut', () async {
    final api = _FakeMembershipApiClient()..delayProfileUpdate = true;
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    final updateFuture = controller.updateProfile(
      nickname: '训练者 01',
      avatarKey: 'ring-green',
    );
    await Future<void>.delayed(Duration.zero);

    await controller.signOut();
    api.completeProfileUpdate();
    await updateFuture;

    expect(controller.signedIn, isFalse);
    expect(controller.user, isNull);
  });

  test('signOut wins while signIn is waiting for Google', () async {
    final googleStarted = Completer<void>();
    final googleResult = Completer<String?>();
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () {
        googleStarted.complete();
        return googleResult.future;
      },
    );

    final signIn = controller.signIn();
    await googleStarted.future;
    await controller.signOut();
    googleResult.complete('google-token');
    await signIn;

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut wins while signIn is waiting for the auth API', () async {
    final api = _ControlledMembershipApiClient();
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );

    final signIn = controller.signIn();
    await api.authStarted.future;
    await controller.signOut();
    api.authResult.complete(_snapshot('user-a', 'token-a'));
    await signIn;

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut clears a signIn blocked in secure session save', () async {
    final store = _ControlledAccountSessionStore()
      ..saveGate = Completer<void>();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );

    final signIn = controller.signIn();
    await store.saveStarted.future;
    final signOut = controller.signOut();
    store.saveGate!.complete();
    await Future.wait([signIn, signOut]);

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut logs out RevenueCat after stale configure completes', () async {
    final store = MemoryAccountSessionStore();
    final revenueCat = _ControlledRevenueCatService()
      ..configureGate = Completer<void>();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );

    final signIn = controller.signIn();
    await revenueCat.configureStarted.future;
    final signOut = controller.signOut();
    revenueCat.configureGate!.complete();
    await Future.wait([signIn, signOut]);

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test('new signIn wins over an older restore', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(
        sessionToken: 'old-token',
        appUserId: 'old-user',
      ),
    );
    final api = _ControlledMembershipApiClient()
      ..immediateAuthSnapshot = _snapshot('new-user', 'new-token');
    final revenueCat = FakeRevenueCatService(isPremium: false);
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );

    final restore = controller.restore();
    await api.meStarted.future;
    await controller.signIn();
    api.meResult.complete(_snapshot('old-user', 'old-token'));
    await restore;

    expect(controller.currentSession?.appUserId, 'new-user');
    expect((await store.load())?.appUserId, 'new-user');
    expect(revenueCat.configuredAppUserId, 'new-user');
  });

  test('signOut invalidates a pending purchase result', () async {
    final revenueCat = _ControlledRevenueCatService();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();
    revenueCat.purchaseResult = Completer<bool>();

    final purchase = controller.purchasePremium();
    await revenueCat.purchaseStarted.future;
    final signOut = controller.signOut();
    revenueCat.purchaseResult!.complete(true);
    await Future.wait([purchase, signOut]);

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test('signOut invalidates a pending restore purchases result', () async {
    final revenueCat = _ControlledRevenueCatService();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();
    revenueCat.restoreResult = Completer<bool>();

    final restore = controller.restorePurchases();
    await revenueCat.restoreStarted.future;
    final signOut = controller.signOut();
    revenueCat.restoreResult!.complete(true);
    await Future.wait([restore, signOut]);

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test(
    'later profile update wins when the older request finishes last',
    () async {
      final api = _ProfileRaceMembershipApiClient();
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();

      final slow = controller.updateProfile(
        nickname: 'slow',
        avatarKey: 'ring-green',
      );
      await api.started['slow']!.future;
      final fast = controller.updateProfile(
        nickname: 'fast',
        avatarKey: 'ring-lime',
      );
      await api.started['fast']!.future;
      api.results['fast']!.complete(_user('fast', 'ring-lime'));
      await fast;
      api.results['slow']!.complete(_user('slow', 'ring-green'));
      await slow;

      expect(controller.user?.nickname, 'fast');
      expect(controller.user?.avatarKey, 'ring-lime');
    },
  );
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  MembershipStatus membership = MembershipStatus.none;
  bool delayProfileUpdate = false;
  AppUser user = const AppUser(
    id: 'user_1',
    displayName: '训练者',
    email: 'a@example.com',
    avatarUrl: null,
  );
  Completer<void>? _profileUpdateCompleter;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return _snapshot(sessionToken: 'session_1');
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    return _snapshot(sessionToken: sessionToken);
  }

  @override
  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) async {
    if (delayProfileUpdate) {
      _profileUpdateCompleter ??= Completer<void>();
      await _profileUpdateCompleter!.future;
    }
    user = AppUser(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      avatarUrl: user.avatarUrl,
      nickname: nickname,
      avatarKey: avatarKey,
    );
    return user;
  }

  void completeProfileUpdate() {
    _profileUpdateCompleter?.complete();
  }

  AccountSnapshot _snapshot({required String sessionToken}) {
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: 'user_1',
      user: user,
      membership: membership,
    );
  }
}

class _CancelRevenueCatService extends FakeRevenueCatService {
  _CancelRevenueCatService() : super(isPremium: false);

  @override
  Future<bool> purchasePremium() async {
    throw const PurchaseCancelledException();
  }
}

class _FailRevenueCatService extends FakeRevenueCatService {
  _FailRevenueCatService() : super(isPremium: false);

  @override
  Future<bool> purchasePremium() async {
    throw const PurchaseFailedException('购买没有完成，请稍后再试。');
  }
}

class _ThrowingLogOutRevenueCatService extends FakeRevenueCatService {
  _ThrowingLogOutRevenueCatService() : super(isPremium: true);

  @override
  Future<void> logOut() async {
    throw Exception('logout failed');
  }
}

class _ExpiredSessionMembershipApiClient extends _FakeMembershipApiClient {
  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    throw const MembershipApiException('HTTP 401', statusCode: 401);
  }
}

AccountSnapshot _snapshot(String appUserId, String sessionToken) {
  return AccountSnapshot(
    sessionToken: sessionToken,
    appUserId: appUserId,
    user: AppUser(
      id: appUserId,
      displayName: appUserId,
      email: '$appUserId@example.com',
      avatarUrl: null,
    ),
    membership: MembershipStatus.none,
  );
}

AppUser _user(String nickname, String avatarKey) {
  return AppUser(
    id: 'user-a',
    displayName: 'User A',
    email: 'a@example.com',
    avatarUrl: null,
    nickname: nickname,
    avatarKey: avatarKey,
  );
}

class _ImmediateMembershipApiClient extends MembershipApiClient {
  _ImmediateMembershipApiClient(this.snapshot)
    : super(baseUrl: 'https://api.example.com');

  final AccountSnapshot snapshot;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async => snapshot;

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async => snapshot;
}

class _ControlledMembershipApiClient extends MembershipApiClient {
  _ControlledMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  final authStarted = Completer<void>();
  final authResult = Completer<AccountSnapshot>();
  final meStarted = Completer<void>();
  final meResult = Completer<AccountSnapshot>();
  AccountSnapshot? immediateAuthSnapshot;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    if (!authStarted.isCompleted) {
      authStarted.complete();
    }
    return immediateAuthSnapshot ?? await authResult.future;
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    if (!meStarted.isCompleted) {
      meStarted.complete();
    }
    return meResult.future;
  }
}

class _ControlledAccountSessionStore implements AccountSessionStore {
  SavedAccountSession? session;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();

  @override
  Future<SavedAccountSession?> load() async => session;

  @override
  Future<void> save(SavedAccountSession value) async {
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    await saveGate?.future;
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _ControlledRevenueCatService implements RevenueCatService {
  String? configuredAppUserId;
  Completer<void>? configureGate;
  Completer<bool>? purchaseResult;
  Completer<bool>? restoreResult;
  var configureStarted = Completer<void>();
  var purchaseStarted = Completer<void>();
  var restoreStarted = Completer<void>();

  @override
  Future<void> configure({required String appUserId}) async {
    if (!configureStarted.isCompleted) {
      configureStarted.complete();
    }
    await configureGate?.future;
    configuredAppUserId = appUserId;
  }

  @override
  Future<bool> refreshPremium() async => false;

  @override
  Future<bool> purchasePremium() async {
    purchaseStarted.complete();
    return purchaseResult?.future ?? Future.value(false);
  }

  @override
  Future<bool> restorePurchases() async {
    restoreStarted.complete();
    return restoreResult?.future ?? Future.value(false);
  }

  @override
  Future<void> logOut() async {
    configuredAppUserId = null;
  }
}

class _ProfileRaceMembershipApiClient extends _ImmediateMembershipApiClient {
  _ProfileRaceMembershipApiClient() : super(_snapshot('user-a', 'token-a'));

  final started = <String, Completer<void>>{};
  final results = <String, Completer<AppUser>>{};

  @override
  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) {
    started[nickname] = Completer<void>()..complete();
    return (results[nickname] = Completer<AppUser>()).future;
  }
}
