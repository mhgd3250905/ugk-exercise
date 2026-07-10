import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/pages/profile_page.dart';

void main() {
  testWidgets('shows sign in button when signed out', (tester) async {
    final controller = _buildController();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('使用 Google 登录'), findsOneWidget);
    expect(find.text('开通会员'), findsNothing);
  });

  testWidgets('shows premium actions when signed in', (tester) async {
    final controller = _buildController();
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('训练者'), findsOneWidget);
    expect(find.text('开通会员'), findsOneWidget);
    expect(find.text('恢复购买'), findsOneWidget);
  });

  testWidgets('signed in profile shows public name and edit profile action', (
    tester,
  ) async {
    final controller = _buildController(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: null,
        nickname: '训练者 01',
        avatarKey: 'ring-green',
      ),
    );
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('训练者 01'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
  });

  testWidgets('edit profile sheet saves nickname and avatar key', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: null,
        nickname: '训练者 01',
        avatarKey: 'ring-green',
      ),
    );
    final controller = _buildController(apiClient: api);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '训练者 02');
    await tester.tap(find.byKey(const ValueKey('avatar-ring-lime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.updatedNickname, '训练者 02');
    expect(api.updatedAvatarKey, 'ring-lime');
    expect(controller.user?.publicDisplayName, '训练者 02');
    expect(controller.user?.avatarKey, 'ring-lime');
    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('训练者 02'), findsOneWidget);
  });

  testWidgets('edit profile sheet stays open when save fails', (tester) async {
    final api =
        _FakeMembershipApiClient(
            user: const AppUser(
              id: 'user_1',
              displayName: 'Google Name',
              email: 'a@example.com',
              avatarUrl: null,
              nickname: '训练者 01',
              avatarKey: 'ring-green',
            ),
          )
          ..updateProfileError = const MembershipApiException(
            'HTTP 409: internal detail must stay hidden',
            statusCode: 409,
            errorCode: 'nickname_taken',
            responseBody: '{"error":"nickname_taken"}',
          );
    final controller = _buildController(apiClient: api);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '训练者 03');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('编辑资料'), findsWidgets);
    expect(find.text('该昵称已被使用，请换一个。'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
  });

  testWidgets('edit profile sheet disables controls while saving', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: null,
        nickname: '训练者 01',
        avatarKey: 'ring-green',
      ),
    )..updateProfileCompleter = Completer<void>();
    final controller = _buildController(apiClient: api);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '训练者 04');
    await tester.tap(find.byKey(const ValueKey('avatar-ring-lime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(api.updateProfileCalls, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('avatar-ring-sky')));
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(api.updateProfileCalls, 1);

    api.updateProfileCompleter!.complete();
    await tester.pumpAndSettle();

    expect(api.updatedAvatarKey, 'ring-lime');
  });

  testWidgets('hides purchase button when already premium', (tester) async {
    final controller = _buildController(isPremium: true);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('会员已开通。高级功能会在本账号下生效。'), findsOneWidget);
    expect(find.text('开通会员'), findsNothing);
    expect(find.text('恢复购买'), findsOneWidget);
  });

  testWidgets('shows local history sync only for premium accounts', (
    tester,
  ) async {
    final freeController = _buildController();
    await freeController.signIn();
    final syncController = _TrackingWorkoutSyncController();

    await tester.pumpWidget(_buildApp(freeController, syncController));
    expect(find.text('同步本机历史'), findsNothing);

    final premiumController = _buildController(isPremium: true);
    await premiumController.signIn();
    await tester.pumpWidget(_buildApp(premiumController, syncController));

    expect(find.text('同步本机历史'), findsOneWidget);
  });

  testWidgets('shows branded paywall before starting purchase', (tester) async {
    final controller = _PurchaseTrackingAccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.text('UGK Premium'), findsOneWidget);
    expect(controller.purchaseCalls, 0);

    await tester.tap(find.text('继续开通'));
    await tester.pumpAndSettle();

    expect(controller.purchaseCalls, 1);
  });

  testWidgets('cancelling local history confirmation does not claim records', (
    tester,
  ) async {
    final controller = _buildController(isPremium: true);
    await controller.signIn();
    final syncController = _TrackingWorkoutSyncController();

    await tester.pumpWidget(_buildApp(controller, syncController));
    await tester.tap(find.text('同步本机历史'));
    await tester.pumpAndSettle();
    expect(find.textContaining('绑定到当前账号'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(syncController.claimCalls, 0);
  });

  testWidgets('confirming local history claims records for current account', (
    tester,
  ) async {
    final controller = _buildController(isPremium: true);
    await controller.signIn();
    final syncController = _TrackingWorkoutSyncController();

    await tester.pumpWidget(_buildApp(controller, syncController));
    await tester.tap(find.text('同步本机历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认同步'));
    await tester.pumpAndSettle();

    expect(syncController.claimCalls, 1);
  });

  testWidgets(
    'local history confirmation stays bound to account that opened it',
    (tester) async {
      final controller = _buildController(isPremium: true);
      await controller.signIn();
      final syncController = _TrackingWorkoutSyncController();

      await tester.pumpWidget(_buildApp(controller, syncController));
      await tester.tap(find.text('同步本机历史'));
      await tester.pumpAndSettle();
      syncController.currentOwnerAppUserId = 'user-b';
      await tester.tap(find.text('确认同步'));
      await tester.pumpAndSettle();

      expect(syncController.requestedOwners, ['user_1']);
      expect(syncController.claimCalls, 0);
    },
  );

  testWidgets('profile leaderboard status shows joined and leave opts out', (
    tester,
  ) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    var leaveCalls = 0;
    // After leave, the next load returns not-joined.
    var joined = true;
    final leaderboard = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: joined,
        top: [],
        me: null,
      ),
      join: (_) async {},
      leave: (_) async {
        leaveCalls++;
        joined = false;
      },
    );
    await leaderboard.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(account, null, leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('已加入运动广场'), findsOneWidget);
    await tester.tap(find.text('退出榜单'));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
    // C2: after a successful leave, the status must reflect not-joined and the
    // leave action must disappear (no stale joined snapshot).
    expect(find.text('未加入运动广场'), findsOneWidget);
    expect(find.text('退出榜单'), findsNothing);
  });
}

Widget _buildApp(
  AccountController controller, [
  WorkoutSyncController? syncController,
  LeaderboardController? leaderboardController,
]) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProfilePage(
      controller: controller,
      syncController: syncController,
      leaderboardController: leaderboardController,
    ),
  );
}

AccountController _buildController({
  bool isPremium = false,
  MembershipApiClient? apiClient,
  AppUser? user,
}) {
  return AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient:
        apiClient ?? _FakeMembershipApiClient(isPremium: isPremium, user: user),
    revenueCat: FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
  );
}

class _TrackingWorkoutSyncController extends WorkoutSyncController {
  _TrackingWorkoutSyncController()
    : super(
        store: WorkoutSessionStore(),
        sessionProvider: () => null,
        premiumProvider: () => false,
        syncBatch: (account, workouts) async => const [],
      );

  var claimCalls = 0;
  @override
  var currentOwnerAppUserId = 'user_1';
  final requestedOwners = <String>[];

  @override
  Future<int> claimLegacyForOwner(String expectedOwnerAppUserId) async {
    requestedOwners.add(expectedOwnerAppUserId);
    if (currentOwnerAppUserId != expectedOwnerAppUserId) {
      return 0;
    }
    claimCalls++;
    return 1;
  }
}

class _PurchaseTrackingAccountController extends AccountController {
  _PurchaseTrackingAccountController({
    required super.sessionStore,
    required super.apiClient,
    required super.revenueCat,
    required super.googleSignIn,
  });

  var purchaseCalls = 0;

  @override
  Future<void> purchasePremium() async {
    purchaseCalls += 1;
  }
}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient({this.isPremium = false, AppUser? user})
    : user =
          user ??
          const AppUser(
            id: 'user_1',
            displayName: '训练者',
            email: 'a@example.com',
            avatarUrl: null,
          ),
      super(baseUrl: 'https://api.example.com');

  final bool isPremium;
  AppUser user;
  String? updatedNickname;
  String? updatedAvatarKey;
  var updateProfileCalls = 0;
  MembershipApiException? updateProfileError;
  Completer<void>? updateProfileCompleter;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: user,
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_google_play' : 'none',
      ),
    );
  }

  @override
  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) async {
    updateProfileCalls += 1;
    updatedNickname = nickname;
    updatedAvatarKey = avatarKey;
    if (updateProfileCompleter != null) {
      await updateProfileCompleter!.future;
    }
    final error = updateProfileError;
    if (error != null) {
      throw error;
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
}
