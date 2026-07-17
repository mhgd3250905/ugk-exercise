import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/platform/avatar_image_service.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/product/premium_plan.dart';
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

  testWidgets('opening profile refreshes the shared account snapshot', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient();
    final controller = _buildController(apiClient: api);
    await controller.signIn();
    api.meCalls = 0;

    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    expect(api.meCalls, 1);
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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

  testWidgets(
    'opening the page clears a stale error from a previous session', (
      tester,
    ) async {
      // Reproduce the reported bug: a prior failure left a sticky _error on
      // the app-scoped controller (which outlives the page). Re-entering the
      // page must clear it so the user does not see a stale banner.
      final api = _FakeMembershipApiClient()
        ..authGoogleCompleter = Completer<void>()
        ..authGoogleError = const MembershipApiException(
          'HTTP 503',
          statusCode: 503,
        );
      final controller = _buildController(apiClient: api);
      final settings = AppSettingsController(store: _TestAppSettingsStore());
      // Use a shell that pushes ProfilePage as a new route, so leaving and
      // re-entering actually rebuilds the page State (initState runs again),
      // matching how the user navigates on a real device.
      await tester.pumpWidget(
        _buildShellApp(controller: controller, settings: settings),
      );

      await tester.tap(find.byKey(const ValueKey('shell-open-profile')));
      await tester.pumpAndSettle();

      // Trigger a sign-in that fails, leaving a sticky _error on the
      // app-scoped controller.
      await tester.tap(find.byKey(const ValueKey('profile-sign-in-button')));
      await tester.pump();
      api.authGoogleCompleter!.complete();
      await tester.pumpAndSettle();
      expect(controller.error, isNotNull);
      expect(find.text('服务暂时不可用，请稍后再试。'), findsOneWidget);

      // Leave the page (Navigator pop) and come back via the shell button,
      // which pushes a fresh route and rebuilds the page State.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('shell-open-profile')));
      await tester.pumpAndSettle();

      expect(controller.error, isNull);
      expect(find.text('服务暂时不可用，请稍后再试。'), findsNothing);
    },
  );

  testWidgets('pull-to-refresh gesture covers the whole body height', (
    tester,
  ) async {
    // Regression guard: the scrollable area must fill the whole body so the
    // pull-to-refresh gesture works anywhere, not only on the upper card area.
    // The bottom action is a pinned overlay above the scroll area.
    final controller = _buildController();
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));
    await tester.pumpAndSettle();

    final scrollRect = tester.getRect(find.byType(CustomScrollView));
    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    // The scrollable fills the whole body (from the AppBar bottom to the
    // Scaffold bottom), so the pull gesture works anywhere on the page.
    expect(scrollRect.top, appBarBottom);
    expect(scrollRect.bottom, scaffoldRect.bottom);

    // The pinned action floats near the bottom edge, not inside the scroll.
    final button = find.byKey(const ValueKey('profile-sign-out-button'));
    expect(button, findsOneWidget);
    expect(
      tester.getRect(button).bottom,
      greaterThan(scaffoldRect.bottom - 80),
    );
  });

  testWidgets('pull-to-refresh clears a stale error and reloads the account', (
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

    // Trigger a sign-in that fails, leaving a sticky _error.
    await tester.tap(find.byKey(const ValueKey('profile-sign-in-button')));
    await tester.pump();
    api.authGoogleCompleter!.complete();
    await tester.pumpAndSettle();
    expect(controller.error, isNotNull);

    api.authGoogleError = null; // allow a clean sign-in for a fresh state
    await controller.signIn();
    await tester.pumpAndSettle();
    api.meCalls = 0; // isolate the refresh call below

    // Trigger pull-to-refresh with an overscroll drag.
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    // The stale error must be cleared and the account snapshot reloaded.
    expect(controller.error, isNull);
    expect(api.meCalls, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'sign-out requires confirmation and never shows sign-in progress',
    (tester) async {
      final signOutCompleter = Completer<void>();
      final controller = _buildController(
        googleSignOut: () => signOutCompleter.future,
      );
      await controller.signIn();
      await tester.pumpWidget(_buildApp(controller));

      await tester.tap(find.byKey(const ValueKey('profile-sign-out-button')));
      await tester.pump();

      expect(find.text('退出登录？'), findsOneWidget);
      expect(controller.busy, isFalse);
      await tester.tap(find.byKey(const ValueKey('profile-sign-out-cancel')));
      await tester.pumpAndSettle();
      expect(controller.signedIn, isTrue);

      await tester.tap(find.byKey(const ValueKey('profile-sign-out-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-sign-out-confirm')));
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
    },
  );

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
    final subscribeButton = find.byKey(
      const ValueKey('profile-subscribe-button'),
    );
    expect(subscribeButton, findsOneWidget);
    expect(
      find.descendant(
        of: subscribeButton,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
    final colors = Theme.of(tester.element(find.text('训练者'))).colorScheme;
    final identityCard = tester.widget<Container>(
      find
          .ancestor(of: find.text('训练者'), matching: find.byType(Container))
          .first,
    );
    expect((identityCard.decoration! as BoxDecoration).color, colors.surface);
    expect(
      tester.widget<Text>(find.text('训练者')).style?.color,
      colors.onSurface,
    );
  });

  testWidgets('shows a subtle sync indicator while account restore is busy', (
    tester,
  ) async {
    final api = _ControlledRestoreMembershipApiClient();
    final controller = _buildController(apiClient: api);
    await controller.signIn();

    final restore = controller.restore();
    await api.meStarted.future;
    await tester.pumpWidget(_buildApp(controller));

    expect(
      find.byKey(const ValueKey('profile-account-sync-indicator')),
      findsOneWidget,
    );
    final indicator = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const ValueKey('profile-account-sync-indicator')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(
      indicator.color,
      Theme.of(tester.element(find.text('训练者'))).colorScheme.primary,
    );

    api.meResult.complete(api.snapshot());
    await restore;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile-account-sync-indicator')),
      findsNothing,
    );
  });

  testWidgets('profile identity reuses silver and gold medal frames', (
    tester,
  ) async {
    final freeController = _buildController();
    await freeController.signIn();
    await tester.pumpWidget(_buildApp(freeController));

    expect(
      find.byKey(const ValueKey('profile-avatar-medal-silver')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-avatar-medal-gold')),
      findsNothing,
    );

    final premiumController = _buildController(isPremium: true);
    await premiumController.signIn();
    await tester.pumpWidget(_buildApp(premiumController));

    expect(
      find.byKey(const ValueKey('profile-avatar-medal-gold')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-avatar-medal-silver')),
      findsNothing,
    );
  });

  testWidgets('uses a persistent cache provider for the Google avatar', (
    tester,
  ) async {
    final controller = _buildController(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: 'https://example.com/avatar.png',
      ),
    );
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    final avatar = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .singleWhere((avatar) => avatar.foregroundImage != null);
    expect(avatar.foregroundImage, isA<CachedNetworkImageProvider>());
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
    final banner = find.byKey(const ValueKey('edit-profile-error-banner'));
    expect(banner, findsOneWidget);
    expect(
      tester.getTopLeft(banner).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
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

  testWidgets('custom avatar upload requires active policy acceptance', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: 'https://example.com/google.png',
        avatarKey: 'ring-green',
        avatarPolicyVersion: '2026-07-14',
      ),
    );
    AvatarImageSource? pickedSource;
    final imageService = AvatarImageService(
      pickImage: (source) async {
        pickedSource = source;
        return 'picked.jpg';
      },
      cropImage: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    final controller = _buildController(apiClient: api);
    await controller.signIn();
    await tester.pumpWidget(
      _buildApp(controller, null, null, null, null, imageService),
    );
    await _openEditProfileSheet(tester);

    await tester.tap(find.byKey(const ValueKey('custom-avatar-gallery')));
    await tester.pump();

    expect(pickedSource, AvatarImageSource.gallery);
    expect(find.text('自定义头像内容规范'), findsOneWidget);
    expect(api.uploadAvatarCalls, 0);

    await tester.tap(find.byKey(const ValueKey('avatar-policy-checkbox')));
    await tester.pump();
    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    expect(api.acceptedPolicyVersion, '2026-07-14');
    expect(api.uploadAvatarCalls, 1);
    expect(controller.user?.customAvatarUrl, 'https://example.com/custom.jpg');
    final customAvatar = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .where((avatar) => avatar.foregroundImage != null)
        .first;
    expect(
      (customAvatar.foregroundImage! as CachedNetworkImageProvider).url,
      'https://example.com/custom.jpg',
    );
  });

  testWidgets('custom avatar replacement stays loading until ready', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: null,
        avatarKey: 'ring-green',
        customAvatarUrl: 'https://example.com/old.jpg',
        avatarPolicyVersion: '2026-07-14',
        avatarPolicyAccepted: true,
      ),
    )..uploadAvatarCompleter = Completer<void>();
    final imageService = AvatarImageService(
      pickImage: (_) async => 'picked.jpg',
      cropImage: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    final controller = _buildController(apiClient: api);
    await controller.signIn();
    await tester.pumpWidget(
      _buildApp(controller, null, null, null, null, imageService),
    );
    await _openEditProfileSheet(tester);

    await tester.tap(find.byKey(const ValueKey('custom-avatar-gallery')));
    await tester.pump();

    expect(api.uploadAvatarCalls, 1);
    expect(
      find.byKey(const ValueKey('custom-avatar-progress')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('正在上传头像'), findsOneWidget);
    expect(find.text('正在更换头像'), findsOneWidget);

    api.uploadAvatarCompleter!.complete();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('custom-avatar-progress')),
      findsOneWidget,
    );
    final preview = find.descendant(
      of: find.byKey(const ValueKey('edit-profile-sheet')),
      matching: find.byKey(const ValueKey('user-avatar')),
    );
    expect(
      (tester.widget<CircleAvatar>(preview).foregroundImage!
              as CachedNetworkImageProvider)
          .url,
      'https://example.com/old.jpg',
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-avatar-progress')), findsNothing);
    expect(
      (tester.widget<CircleAvatar>(preview).foregroundImage!
              as CachedNetworkImageProvider)
          .url,
      'https://example.com/custom.jpg',
    );
  });

  testWidgets('cancelled camera selection does not upload an avatar', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient();
    AvatarImageSource? pickedSource;
    final imageService = AvatarImageService(
      pickImage: (source) async {
        pickedSource = source;
        return null;
      },
      cropImage: (_) async => Uint8List(0),
    );
    final controller = _buildController(apiClient: api);
    await controller.signIn();
    await tester.pumpWidget(
      _buildApp(controller, null, null, null, null, imageService),
    );
    await _openEditProfileSheet(tester);

    await tester.tap(find.byKey(const ValueKey('custom-avatar-camera')));
    await tester.pumpAndSettle();

    expect(pickedSource, AvatarImageSource.camera);
    expect(api.uploadAvatarCalls, 0);
    expect(find.text('自定义头像内容规范'), findsNothing);
  });

  testWidgets('custom avatar can be deleted to reveal the fallback avatar', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(
      user: const AppUser(
        id: 'user_1',
        displayName: 'Google Name',
        email: 'a@example.com',
        avatarUrl: null,
        avatarKey: 'ring-green',
        customAvatarUrl: 'https://example.com/custom.jpg',
        avatarPolicyVersion: '2026-07-14',
        avatarPolicyAccepted: true,
      ),
    );
    final controller = _buildController(apiClient: api);
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));
    await _openEditProfileSheet(tester);

    await tester.tap(find.byKey(const ValueKey('custom-avatar-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除头像'));
    await tester.pumpAndSettle();

    expect(api.deleteAvatarCalls, 1);
    expect(controller.user?.customAvatarUrl, isNull);
  });

  testWidgets('hides purchase button when already premium', (tester) async {
    final controller = _buildController(isPremium: true);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    expect(find.text('会员已开通。高级功能会在本账号下生效。'), findsOneWidget);
    final membershipCard = find.byKey(
      const ValueKey('profile-membership-status-card'),
    );
    expect(membershipCard, findsOneWidget);
    final decoration = tester.widget<Container>(membershipCard).decoration!;
    final colors = Theme.of(tester.element(membershipCard)).colorScheme;
    expect((decoration as BoxDecoration).color, colors.surfaceContainerHighest);
    expect(decoration.border, isNull);
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
    expect(tester.widget<Text>(find.text('VIP')).style?.color, ink);
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

  testWidgets('restore membership sync failure shows a distinct message', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient()
      ..reconcileError = const MembershipApiException(
        'HTTP 503',
        statusCode: 503,
        errorCode: 'membership_sync_unavailable',
      );
    final controller = _buildController(
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: true),
    );
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复会员权益'));
    await tester.pumpAndSettle();

    expect(find.text('会员权益同步失败，请稍后重试。'), findsOneWidget);
    expect(controller.premium, isFalse);
  });

  testWidgets('signed-in settings open a persistent blocked users list', (
    tester,
  ) async {
    final account = _buildController();
    await account.signIn();
    final leaderboard = LeaderboardController(
      sessionProvider: () => account.currentSession,
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: false,
        top: const [],
        me: null,
      ),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
      loadBlockedUsers: (_) async => const [],
      unblockUser: (_, __) async {},
    );
    await tester.pumpWidget(_buildApp(account, null, leaderboard));

    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();
    expect(find.text('屏蔽名单'), findsOneWidget);
    await tester.tap(find.text('屏蔽名单'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('blocked-users-page')), findsOneWidget);
    expect(find.text('暂无已屏蔽用户'), findsOneWidget);
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

  testWidgets('paywall defaults annual and purchases selected monthly plan', (
    tester,
  ) async {
    final controller = _PurchaseTrackingAccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      premiumPlans: const [
        PremiumPlan(id: PremiumPlanId.monthly, price: r'$2.99'),
        PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
      ],
    );
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.text('PushupAI 会员'), findsOneWidget);
    expect(find.text(r'$2.99 / 月'), findsOneWidget);
    expect(find.text(r'$20.00 / 年'), findsOneWidget);
    final paywallColors = Theme.of(
      tester.element(find.text('PushupAI 会员')),
    ).colorScheme;
    expect(
      tester.widget<Text>(find.text('PushupAI 会员')).style?.color,
      paywallColors.onSurface,
    );
    expect(
      find.byKey(const ValueKey('premium-plan-check-annual')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-plan-check-monthly')),
      findsNothing,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('premium-plan-annual')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('premium-plan-annual')))
          .selectedColor,
      paywallColors.primaryContainer,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('premium-plan-monthly')),
          )
          .backgroundColor,
      paywallColors.surface,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('继续开通'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{}),
      paywallColors.primary,
    );
    expect(controller.purchaseCalls, 0);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('PushupAI 会员'), findsNothing);

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.text('PushupAI 会员'), findsNothing);

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('premium-plan-monthly')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('premium-plan-check-annual')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('premium-plan-check-monthly')),
      findsOneWidget,
    );
    await tester.tap(find.text('继续开通'));
    await tester.pumpAndSettle();

    expect(controller.purchaseCalls, 1);
    expect(controller.purchasedPlanId, PremiumPlanId.monthly);
  });

  testWidgets('paywall uses the PushupAI product name in English', (
    tester,
  ) async {
    final controller = _PurchaseTrackingAccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      premiumPlans: const [
        PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
      ],
    );
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setLanguage(AppLanguage.en);
    await controller.signIn();

    await tester.pumpWidget(_buildApp(controller, null, null, null, settings));
    await tester.tap(find.text('Subscribe to Premium'));
    await tester.pumpAndSettle();

    expect(find.text('PushupAI Premium'), findsOneWidget);
  });

  testWidgets('paywall falls back to the only available annual plan', (
    tester,
  ) async {
    final controller = _PurchaseTrackingAccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      premiumPlans: const [
        PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
      ],
    );
    await controller.signIn();
    await tester.pumpWidget(_buildApp(controller));

    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('premium-plan-monthly')), findsNothing);
    expect(find.byKey(const ValueKey('premium-plan-annual')), findsOneWidget);
    await tester.tap(find.text('继续开通'));
    await tester.pumpAndSettle();

    expect(controller.purchasedPlanId, PremiumPlanId.annual);
  });

  testWidgets('paywall retries when no premium plans are available', (
    tester,
  ) async {
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

    expect(find.text('暂时无法加载会员套餐。'), findsOneWidget);
    final retryButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('重试'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
    );
    expect(
      retryButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      Theme.of(tester.element(find.text('重试'))).colorScheme.primary,
    );
    expect(controller.planLoadCalls, 1);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(controller.planLoadCalls, 2);
    expect(controller.purchaseCalls, 0);
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

  testWidgets(
    'profile leaderboard card shows a loading state instead of "not joined" '
    'while the snapshot is loading',
    (tester) async {
      // Regression: when the leaderboard snapshot is cleared and reloaded
      // (account change / pull-to-refresh via the account listener), the card
      // must not flash "未加入运动广场" before the data arrives. While the
      // snapshot is null it should show a loading indicator instead.
      final account = _buildController();
      await account.signIn();
      // load() never completes → the controller stays busy with snapshot ==
      // null, mirroring the window between clear and load-complete during a
      // reload triggered by account change / pull-to-refresh.
      final pendingLoad = Completer<LeaderboardSnapshot>();
      final leaderboard = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, __) => pendingLoad.future,
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
        leave: (_) async {},
      );
      // Kick off a reload but do not await it; it stays in the loading state.
      unawaited(leaderboard.reloadForCurrentAccount());

      await tester.pumpWidget(_buildApp(account, null, leaderboard));
      await tester.pump();

      expect(leaderboard.snapshot, isNull);
      expect(leaderboard.busy, isTrue);
      // Must not jump to a "not joined" conclusion while loading.
      expect(find.text('未加入运动广场'), findsNothing);
      expect(find.text('已加入运动广场'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-leaderboard-loading')),
        findsOneWidget,
      );
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {
        leaveCalls++;
        joined = false;
      },
    );
    await leaderboard.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(account, null, leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('已加入运动广场'), findsOneWidget);
    final statusCard = find.byKey(
      const ValueKey('profile-leaderboard-status-card'),
    );
    expect(statusCard, findsOneWidget);
    final statusDecoration = tester.widget<Container>(statusCard).decoration!;
    final colors = Theme.of(tester.element(statusCard)).colorScheme;
    expect(
      (statusDecoration as BoxDecoration).color,
      colors.surfaceContainerHighest,
    );
    expect(statusDecoration.border, isNull);
    await tester.tap(find.text('退出榜单'));
    await tester.pumpAndSettle();

    expect(find.text('确认退出运动广场？'), findsOneWidget);
    expect(leaveCalls, 0);
    await tester.tap(find.byKey(const ValueKey('leaderboard-leave-confirm')));
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

  testWidgets('settings show an available update and open Google Play', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'AI俯卧撑',
      packageName: 'com.ugkexercise.ugk_exercise',
      version: '0.3.8',
      buildNumber: '11',
      buildSignature: '',
      installerStore: 'com.android.vending',
    );
    const updateChannel = MethodChannel('de.ffuf.in_app_update/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          expect(call.method, 'checkForUpdate');
          return <String, Object?>{
            'updateAvailability': 2,
            'immediateAllowed': true,
            'immediateAllowedPreconditions': <int>[],
            'flexibleAllowed': true,
            'flexibleAllowedPreconditions': <int>[],
            'availableVersionCode': 12,
            'installStatus': 0,
            'packageName': 'com.ugkexercise.ugk_exercise',
            'clientVersionStalenessDays': 1,
            'updatePriority': 0,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null),
    );
    const playStoreChannel = MethodChannel(
      'com.ugkexercise.ugk_exercise/play_store',
    );
    String? playStoreMethod;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playStoreChannel, (call) async {
          playStoreMethod = call.method;
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(playStoreChannel, null),
    );
    Uri? openedUrl;
    final controller = _buildController();

    await tester.pumpWidget(
      _buildApp(controller, null, null, (url) async {
        openedUrl = url;
        return true;
      }),
    );
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('版本'), findsOneWidget);
    expect(find.text('0.3.8 (11)'), findsOneWidget);
    expect(find.text('新版本可用'), findsOneWidget);

    final versionTile = find.byKey(const ValueKey('settings-version-tile'));
    await tester.ensureVisible(versionTile);
    await tester.tap(versionTile);
    await tester.pump();

    expect(playStoreMethod, 'openProductPage');
    expect(openedUrl, isNull);
  });

  testWidgets('version entry opens Google Play without an update signal', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'AI俯卧撑',
      packageName: 'com.ugkexercise.ugk_exercise',
      version: '0.3.8',
      buildNumber: '11',
      buildSignature: '',
    );
    const updateChannel = MethodChannel('de.ffuf.in_app_update/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (_) async {
          return <String, Object?>{
            'updateAvailability': 1,
            'immediateAllowed': false,
            'immediateAllowedPreconditions': <int>[],
            'flexibleAllowed': false,
            'flexibleAllowedPreconditions': <int>[],
            'availableVersionCode': 11,
            'installStatus': 0,
            'packageName': 'com.ugkexercise.ugk_exercise',
            'clientVersionStalenessDays': null,
            'updatePriority': 0,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null),
    );
    const playStoreChannel = MethodChannel(
      'com.ugkexercise.ugk_exercise/play_store',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playStoreChannel, (_) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(playStoreChannel, null),
    );
    Uri? openedUrl;
    final controller = _buildController();

    await tester.pumpWidget(
      _buildApp(controller, null, null, (url) async {
        openedUrl = url;
        return true;
      }),
    );
    await tester.tap(find.byKey(const ValueKey('profile-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('新版本可用'), findsNothing);
    final versionTile = find.byKey(const ValueKey('settings-version-tile'));
    await tester.ensureVisible(versionTile);
    await tester.tap(versionTile);
    await tester.pump();

    expect(
      openedUrl,
      Uri.parse(
        'https://play.google.com/store/apps/details?'
        'id=com.ugkexercise.ugk_exercise',
      ),
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
  AvatarImageService? avatarImageService,
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
        avatarImageService: avatarImageService,
      ),
    ),
  );
}

ProfilePage _profilePage(AccountController controller, AppSettingsController settings) {
  return ProfilePage(settingsController: settings, controller: controller);
}

Widget _buildShellApp({
  required AccountController controller,
  required AppSettingsController settings,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: appTheme(brightness: Brightness.light),
      home: _ShellPage(child: _profilePage(controller, settings)),
  );
}

class _ShellPage extends StatelessWidget {
  const _ShellPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('shell-open-profile'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => child),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
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
    clearAvatarImageCache: () async {},
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
    this.premiumPlans = const [],
  });

  final List<PremiumPlan> premiumPlans;
  var purchaseCalls = 0;
  var planLoadCalls = 0;
  PremiumPlanId? purchasedPlanId;

  @override
  Future<List<PremiumPlan>> loadPremiumPlans() async {
    planLoadCalls += 1;
    return premiumPlans;
  }

  @override
  Future<void> purchasePremiumPlan(PremiumPlanId planId) async {
    purchaseCalls += 1;
    purchasedPlanId = planId;
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
  var uploadAvatarCalls = 0;
  var deleteAvatarCalls = 0;
  String? acceptedPolicyVersion;
  MembershipApiException? updateProfileError;
  MembershipApiException? authGoogleError;
  MembershipApiException? reconcileError;
  Completer<void>? authGoogleCompleter;
  Completer<void>? updateProfileCompleter;
  Completer<void>? uploadAvatarCompleter;
  var meCalls = 0;

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

  @override
  Future<void> acceptAvatarPolicy(
    String sessionToken, {
    required String policyVersion,
  }) async {
    acceptedPolicyVersion = policyVersion;
    user = _copyUser(user, avatarPolicyAccepted: true);
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    meCalls += 1;
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: appUserId,
      user: user,
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_verified' : 'none',
      ),
    );
  }

  @override
  Future<MembershipStatus> reconcileMembership(String sessionToken) async {
    final error = reconcileError;
    if (error != null) throw error;
    return MembershipStatus(
      entitlement: 'premium',
      isActive: isPremium,
      expiresAt: null,
      source: isPremium ? 'revenuecat_verified' : 'none',
    );
  }

  @override
  Future<AppUser> uploadAvatar(String sessionToken, Uint8List jpegBytes) async {
    uploadAvatarCalls += 1;
    if (uploadAvatarCompleter != null) {
      await uploadAvatarCompleter!.future;
    }
    user = _copyUser(user, customAvatarUrl: 'https://example.com/custom.jpg');
    return user;
  }

  @override
  Future<AppUser> deleteAvatar(String sessionToken) async {
    deleteAvatarCalls += 1;
    user = _copyUser(user, clearCustomAvatar: true);
    return user;
  }
}

AppUser _copyUser(
  AppUser user, {
  String? customAvatarUrl,
  bool clearCustomAvatar = false,
  bool? avatarPolicyAccepted,
}) => AppUser(
  id: user.id,
  displayName: user.displayName,
  email: user.email,
  avatarUrl: user.avatarUrl,
  nickname: user.nickname,
  avatarKey: user.avatarKey,
  customAvatarUrl: clearCustomAvatar
      ? null
      : customAvatarUrl ?? user.customAvatarUrl,
  avatarPolicyVersion: user.avatarPolicyVersion,
  avatarPolicyAccepted: avatarPolicyAccepted ?? user.avatarPolicyAccepted,
  avatarUploadSuspended: user.avatarUploadSuspended,
);

class _ControlledRestoreMembershipApiClient extends _FakeMembershipApiClient {
  final meStarted = Completer<void>();
  final meResult = Completer<AccountSnapshot>();

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

  AccountSnapshot snapshot() {
    return AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: user,
      membership: MembershipStatus.none,
    );
  }
}
