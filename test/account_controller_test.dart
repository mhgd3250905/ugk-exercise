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
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.signOut();

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(revenueCat.configuredAppUserId, isNull);
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
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient() : super(baseUrl: 'https://api.example.com');

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
      membership: MembershipStatus.none,
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
