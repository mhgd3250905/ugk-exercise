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
}

class _FakeAccountController extends AccountController {
  _FakeAccountController()
    : super(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: _FakeMembershipApiClient(),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return const AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
      ),
      membership: MembershipStatus.none,
    );
  }
}
