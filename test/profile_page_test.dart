import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/ui/pages/profile_page.dart';

void main() {
  testWidgets('shows sign in button when signed out', (tester) async {
    final controller = _FakeAccountController();

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(controller: controller)),
    );

    expect(find.text('使用 Google 登录'), findsOneWidget);
    expect(find.text('开通会员'), findsNothing);
  });

  testWidgets('shows premium actions when signed in', (tester) async {
    final controller = _FakeAccountController();
    await controller.signIn();

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(controller: controller)),
    );

    expect(find.text('训练者'), findsOneWidget);
    expect(find.text('开通会员'), findsOneWidget);
    expect(find.text('恢复购买'), findsOneWidget);
  });

  testWidgets('hides purchase button when already premium', (tester) async {
    final controller = _FakeAccountController(isPremium: true);
    await controller.signIn();

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(controller: controller)),
    );

    expect(find.text('会员已开通。高级功能会在本账号下生效。'), findsOneWidget);
    expect(find.text('开通会员'), findsNothing);
    expect(find.text('恢复购买'), findsOneWidget);
  });

  testWidgets('shows branded paywall before starting purchase', (tester) async {
    final controller = _FakeAccountController();
    await controller.signIn();

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(controller: controller)),
    );

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.text('UGK Premium'), findsOneWidget);
    expect(controller.purchaseCalls, 0);

    await tester.tap(find.text('继续开通'));
    await tester.pumpAndSettle();

    expect(controller.purchaseCalls, 1);
  });
}

class _FakeAccountController extends AccountController {
  _FakeAccountController({bool isPremium = false})
    : super(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: _FakeMembershipApiClient(isPremium: isPremium),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );

  var purchaseCalls = 0;

  @override
  Future<void> purchasePremium() async {
    purchaseCalls += 1;
  }
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient({required this.isPremium})
    : super(baseUrl: 'https://api.example.com');

  final bool isPremium;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
      ),
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_google_play' : 'none',
      ),
    );
  }
}
