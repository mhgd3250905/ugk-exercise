import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/app_settings.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/pages/profile_page.dart';

void main() {
  testWidgets('shows sign in button when signed out', (tester) async {
    final controller = _buildController();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('使用 Google 登录'), findsOneWidget);
    expect(find.text('开通会员'), findsNothing);
  });

  testWidgets('signed-out header shows a neutral logged-out identity', (
    tester,
  ) async {
    final controller = _buildController();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('您尚未登录'), findsOneWidget);
    expect(find.text('登录后使用账号与会员功能'), findsOneWidget);
    expect(find.text('训练者'), findsNothing);
    final avatarFinder = find.byKey(const ValueKey('signed-out-avatar'));
    final avatar = tester.widget<CircleAvatar>(avatarFinder);
    expect(
      avatar.backgroundColor,
      Theme.of(
        tester.element(avatarFinder),
      ).colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('signed-out profile hides membership and leaderboard cards', (
    tester,
  ) async {
    final controller = _buildController();
    final leaderboard = LeaderboardController(
      sessionProvider: () => null,
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
      join: (_) async {},
      leave: (_) async {},
    );

    await tester.pumpWidget(_buildApp(controller, null, leaderboard));

    expect(find.text('当前未开通会员。本机训练仍可正常使用。'), findsNothing);
    expect(find.text('登录并开通会员后可加入'), findsNothing);
  });

  testWidgets('signed-out sign-in action stays at the bottom safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _buildController();

    await tester.pumpWidget(_buildApp(controller));

    final button = find.byKey(const ValueKey('profile-sign-in-button'));
    expect(button, findsOneWidget);
    expect(tester.getRect(button).bottom, greaterThan(800));
  });

  testWidgets('shows sign-in progress until account authentication completes', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient()
      ..authGoogleCompleter = Completer<void>();
    final controller = _buildController(apiClient: api);
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.byKey(const ValueKey('profile-sign-in-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile-sign-in-progress')),
      findsOneWidget,
    );
    expect(find.text('正在登录…'), findsWidgets);
    expect(find.text('正在验证账号与会员状态，请稍候。'), findsOne);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-sign-in-button')),
          )
          .onPressed,
      isNull,
    );

    api.authGoogleCompleter!.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-sign-in-progress')),
      findsNothing,
    );
    expect(find.text('训练者'), findsOne);
  });

  testWidgets('sign-in failure restores retry action and shows an error', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient()
      ..authGoogleCompleter = Completer<void>()
      ..authGoogleError = const MembershipApiException(
        'HTTP 503',
        statusCode: 503,
      );
    final controller = _buildController(apiClient: api);
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.byKey(const ValueKey('profile-sign-in-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('profile-sign-in-progress')),
      findsOneWidget,
    );

    api.authGoogleCompleter!.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-sign-in-progress')),
      findsNothing,
    );
    expect(find.text('服务暂时不可用，请稍后再试。'), findsOne);
    expect(find.text('使用 Google 登录'), findsOne);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-sign-in-button')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('sign-out never shows sign-in progress', (tester) async {
    final signOutCompleter = Completer<void>();
    final controller = _buildController(
      googleSignOut: () => signOutCompleter.future,
    );
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.byKey(const ValueKey('profile-sign-out-button')));
    await tester.pump();

    expect(controller.busy, isTrue);
    expect(
      find.byKey(const ValueKey('profile-sign-in-progress')),
      findsNothing,
    );
    expect(find.text('正在登录…'), findsNothing);
    expect(find.text('使用 Google 登录'), findsOneWidget);

    signOutCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('signed-out identity is localized in English', (tester) async {
    final controller = _buildController();
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setLanguage(AppLanguage.en);

    await tester.pumpWidget(_buildApp(controller, null, null, null, settings));

    expect(find.text("You're not signed in"), findsOneWidget);
    expect(
      find.text('Sign in to use account and membership features'),
      findsOneWidget,
    );
  });

  testWidgets('shows premium actions when signed in', (tester) async {
    final controller = _buildController();
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('训练者'), findsOneWidget);
    expect(find.text('开通会员'), findsOneWidget);
    expect(find.text('当前未开通会员。本机训练仍可正常使用。'), findsNothing);
    expect(find.text('恢复会员权益'), findsNothing);
  });

  testWidgets('signed in profile moves account actions into settings', (
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
    expect(find.text('编辑资料'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('账号'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('恢复会员权益'), findsOneWidget);
    expect(find.text('重装或换设备后找回已购买会员'), findsOneWidget);
    final accountCard = find.byKey(const ValueKey('settings-account-card'));
    final colors = Theme.of(tester.element(accountCard)).colorScheme;
    expect(
      tester.widget<Material>(accountCard).color,
      colors.surfaceContainerHighest,
    );
    expect(
      (tester.widget<Material>(accountCard).shape! as RoundedRectangleBorder)
          .side,
      BorderSide.none,
    );
  });

  testWidgets('signed-in sign-out action stays at the bottom safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _buildController();
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    final button = find.byKey(const ValueKey('profile-sign-out-button'));
    expect(button, findsOneWidget);
    expect(tester.getRect(button).bottom, greaterThan(800));
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

    await _openEditProfileSheet(tester);

    await tester.enterText(find.byType(TextField), '训练者 02');
    await tester.tap(find.byKey(const ValueKey('avatar-ring-lime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(api.updatedNickname, '训练者 02');
    expect(api.updatedAvatarKey, 'ring-lime');
    expect(controller.user?.publicDisplayName, '训练者 02');
    expect(controller.user?.avatarKey, 'ring-lime');
    expect(find.text('编辑资料'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('训练者 02'), findsOneWidget);
  });

  testWidgets('edit profile sheet uses the settings sheet visual style', (
    tester,
  ) async {
    final controller = _buildController();
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));

    await _openEditProfileSheet(tester);

    final sheet = find.byKey(const ValueKey('edit-profile-sheet'));
    final colors = Theme.of(tester.element(sheet)).colorScheme;
    expect(tester.widget<Material>(sheet).color, colors.surface);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      colors.surface,
    );
    expect(
      find.byKey(const ValueKey('edit-profile-close-button')),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, colors.onSurface);
    expect(field.decoration?.floatingLabelStyle?.color, colors.primary);
    expect(
      field.decoration?.floatingLabelStyle?.fontSize,
      greaterThanOrEqualTo(16),
    );
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

    await _openEditProfileSheet(tester);

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

    await _openEditProfileSheet(tester);

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
    expect(find.text('恢复会员权益'), findsNothing);
  });

  testWidgets('shows a VIP stamp only for premium accounts', (tester) async {
    final freeController = _buildController();
    await freeController.signIn();
    await tester.pumpWidget(_buildApp(freeController));

    expect(find.byKey(const ValueKey('profile-vip-stamp')), findsNothing);

    final premiumController = _buildController(isPremium: true);
    await premiumController.signIn();
    await tester.pumpWidget(_buildApp(premiumController));

    expect(find.byKey(const ValueKey('profile-vip-stamp')), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('profile-vip-stamp')),
        matching: find.byType(Transform),
      ),
      findsOneWidget,
    );
  });

  testWidgets('restore membership action invokes purchase restoration', (
    tester,
  ) async {
    final revenueCat = FakeRevenueCatService(isPremium: false);
    final controller = _buildController(revenueCat: revenueCat);
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复会员权益'));
    await tester.pumpAndSettle();

    expect(revenueCat.restoreCalls, 1);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('shows local history sync only for premium accounts', (
    tester,
  ) async {
    final freeController = _buildController();
    await freeController.signIn();
    final syncController = _TrackingWorkoutSyncController();

    await tester.pumpWidget(_buildApp(freeController, syncController));
    expect(find.text('同步本机历史'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('同步本机历史'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final premiumController = _buildController(isPremium: true);
    await premiumController.signIn();
    await tester.pumpWidget(_buildApp(premiumController, syncController));

    expect(find.text('同步本机历史'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
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
    await _openSyncHistoryConfirmation(tester);
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
    await _openSyncHistoryConfirmation(tester);
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
      await _openSyncHistoryConfirmation(tester);
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

  testWidgets('account deletion entry opens public request page', (
    tester,
  ) async {
    final controller = _buildController();
    await controller.signIn();
    Uri? openedUrl;

    await tester.pumpWidget(
      _buildApp(controller, null, null, (url) async {
        openedUrl = url;
        return true;
      }),
    );

    expect(find.text('隐私政策与账号删除'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    final deletionEntry = find.text('隐私政策与账号删除');
    expect(deletionEntry, findsOneWidget);
    await tester.ensureVisible(deletionEntry);
    await tester.tap(deletionEntry);
    await tester.pump();

    expect(
      openedUrl,
      Uri.parse('https://pushupai-privacy.pages.dev/#account-deletion'),
    );
  });

  testWidgets('account deletion entry reports when the page cannot open', (
    tester,
  ) async {
    final controller = _buildController();

    await tester.pumpWidget(
      _buildApp(controller, null, null, (_) async => false),
    );

    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    final deletionEntry = find.text('隐私政策与账号删除');
    await tester.ensureVisible(deletionEntry);
    await tester.tap(deletionEntry);
    await tester.pump();

    expect(find.text('无法打开账号删除页面，请稍后重试。'), findsOneWidget);
  });

  testWidgets('profile settings open from the app bar', (tester) async {
    final controller = _buildController();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('隐私政策与账号删除'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('隐私政策与账号删除'), findsOneWidget);
    final privacyCard = find.byKey(const ValueKey('settings-privacy-card'));
    final colors = Theme.of(tester.element(privacyCard)).colorScheme;
    expect(
      tester.widget<Material>(privacyCard).color,
      colors.surfaceContainerHighest,
    );
    expect(
      (tester.widget<Material>(privacyCard).shape! as RoundedRectangleBorder)
          .side,
      BorderSide.none,
    );
  });

  testWidgets('language choice updates the whole app locale', (tester) async {
    final controller = _buildController();
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setLanguage(AppLanguage.zh);

    await tester.pumpWidget(_buildApp(controller, null, null, null, settings));
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-language-en')));
    await tester.pumpAndSettle();

    expect(settings.language, AppLanguage.en);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('theme choice updates the whole app theme mode', (tester) async {
    final controller = _buildController();
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setLanguage(AppLanguage.zh);
    await settings.setTheme(AppThemePreference.light);

    await tester.pumpWidget(_buildApp(controller, null, null, null, settings));
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-theme-dark')));
    await tester.pumpAndSettle();

    expect(settings.theme, AppThemePreference.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });
}

Widget _buildApp(
  AccountController controller, [
  WorkoutSyncController? syncController,
  LeaderboardController? leaderboardController,
  Future<bool> Function(Uri url)? launchExternalUrl,
  AppSettingsController? settingsController,
]) {
  final settings =
      settingsController ??
      AppSettingsController(store: _TestAppSettingsStore());
  return ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      locale: settingsController == null ? const Locale('zh') : settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: appTheme(brightness: Brightness.light),
      darkTheme: appTheme(brightness: Brightness.dark),
      themeMode: settings.themeMode,
      home: ProfilePage(
        settingsController: settings,
        controller: controller,
        syncController: syncController,
        leaderboardController: leaderboardController,
        launchExternalUrl: launchExternalUrl,
      ),
    ),
  );
}

Future<void> _openEditProfileSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑资料'));
  await tester.pumpAndSettle();
}

Future<void> _openSyncHistoryConfirmation(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('同步本机历史'));
  await tester.pumpAndSettle();
}

class _TestAppSettingsStore implements AppSettingsStore {
  String? language;
  String? theme;

  @override
  Future<String?> loadLanguage() async => language;

  @override
  Future<String?> loadTheme() async => theme;

  @override
  Future<void> saveLanguage(String value) async => language = value;

  @override
  Future<void> saveTheme(String value) async => theme = value;
}

AccountController _buildController({
  bool isPremium = false,
  MembershipApiClient? apiClient,
  AppUser? user,
  FakeRevenueCatService? revenueCat,
  GoogleSignOutCallback? googleSignOut,
}) {
  return AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient:
        apiClient ?? _FakeMembershipApiClient(isPremium: isPremium, user: user),
    revenueCat: revenueCat ?? FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
    googleSignOut: googleSignOut,
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
  MembershipApiException? authGoogleError;
  Completer<void>? authGoogleCompleter;
  Completer<void>? updateProfileCompleter;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    if (authGoogleCompleter != null) {
      await authGoogleCompleter!.future;
    }
    if (authGoogleError case final error?) {
      throw error;
    }
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
