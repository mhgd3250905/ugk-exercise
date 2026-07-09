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

    expect(controller.error, '购买没有完成，请稍后再试。');
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
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  MembershipStatus membership = MembershipStatus.none;

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

  AccountSnapshot _snapshot({required String sessionToken}) {
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: 'user_1',
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
      ),
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
