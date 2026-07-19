import 'dart:async';

import 'package:flutter/material.dart';

import 'config/membership_config.dart';
import 'control/account_controller.dart';
import 'control/leaderboard_controller.dart';
import 'control/workout_sync_controller.dart';
import 'l10n/app_localizations.dart';
import 'platform/account_session_store.dart';
import 'platform/app_settings_store.dart';
import 'platform/avatar_image_service.dart';
import 'platform/google_auth_service.dart';
import 'platform/membership_api_client.dart';
import 'platform/revenuecat_service.dart';
import 'platform/startup_preferences.dart';
import 'platform/ugk_log.dart';
import 'product/workout_session_store.dart';
import 'ui/app_settings.dart';
import 'ui/app_theme.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/onboarding_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  validateMembershipConfig();
  FlutterError.onError = (details) {
    ugkLog('flutter-error: type=${details.exception.runtimeType}');
    FlutterError.presentError(details);
  };
  runZonedGuarded<void>(_runUgkApp, (error, stackTrace) {
    ugkLog('zone-error: type=${error.runtimeType}');
    debugPrintStack(stackTrace: stackTrace);
  });
}

void _runUgkApp() {
  final settingsController = AppSettingsController(
    store: SecureAppSettingsStore(),
  );
  final settingsRestore = settingsController.restore();
  final googleAuth = GoogleAuthService();
  final apiClient = MembershipApiClient(baseUrl: membershipApiBaseUrl);
  final avatarImageService = AvatarImageService();
  final startupPreferences = StartupPreferences();
  final controller = AccountController(
    sessionStore: SecureAccountSessionStore(),
    apiClient: apiClient,
    revenueCat: PurchasesRevenueCatService(),
    googleSignIn: () async {
      await googleAuth.initialize(serverClientId: googleServerClientId);
      final result = await googleAuth.signIn();
      return result?.idToken;
    },
    googleSignOut: () async {
      await googleAuth.initialize(serverClientId: googleServerClientId);
      await googleAuth.signOut();
    },
  );
  final syncController = WorkoutSyncController(
    store: WorkoutSessionStore(),
    sessionProvider: () => controller.currentSession,
    premiumProvider: () => controller.premium,
    syncBatch: (account, workouts) async {
      return apiClient.syncWorkouts(account.sessionToken, workouts);
    },
  );
  final leaderboardController = LeaderboardController(
    sessionProvider: () => controller.currentSession,
    load: (sessionToken, period) => apiClient.leaderboard(
      sessionToken,
      period: period,
      metric: 'pushup_points_v1',
    ),
    loadMore: (sessionToken, period, cursor) => apiClient.leaderboard(
      sessionToken,
      period: period,
      metric: 'pushup_points_v1',
      cursor: cursor,
    ),
    joinIdentity: (sessionToken, choice) =>
        apiClient.joinLeaderboard(sessionToken, choice),
    updateIdentity: apiClient.updateLeaderboardIdentity,
    leave: apiClient.leaveLeaderboard,
    reportUser: (sessionToken, userId, type, reason) =>
        apiClient.reportLeaderboardUser(
          sessionToken,
          userId: userId,
          reportType: type,
          reason: reason,
        ),
    blockUser: apiClient.blockLeaderboardUser,
    loadBlockedUsers: apiClient.blockedUsers,
    unblockUser: apiClient.unblockLeaderboardUser,
  );
  controller.addListener(() {
    if (!controller.busy) {
      unawaited(syncController.syncForCurrentAccount());
      // Account changes (sign-in / sign-out / switch) must immediately clear
      // any stale leaderboard snapshot/error and reload for the new account.
      unawaited(leaderboardController.reloadForCurrentAccount());
    }
  });
  unawaited(controller.restore());
  final startup = () async {
    await settingsRestore;
    await controller.localRestoreCompleted;
    return startupPreferences.onboardingCompleted();
  }();
  runApp(
    UgkExerciseApp(
      settingsController: settingsController,
      accountController: controller,
      syncController: syncController,
      leaderboardController: leaderboardController,
      avatarImageService: avatarImageService,
      cloudSessionsLoader: (month) {
        final account = controller.currentSession;
        if (account == null) {
          return Future.value(const <WorkoutSession>[]);
        }
        return apiClient.cloudWorkouts(account.sessionToken, month: month);
      },
      startup: startup,
      completeOnboarding: startupPreferences.completeOnboarding,
      cameraNoticeAcknowledged: startupPreferences.cameraNoticeAcknowledged,
      acknowledgeCameraNotice: startupPreferences.acknowledgeCameraNotice,
    ),
  );
}

class UgkExerciseApp extends StatelessWidget {
  const UgkExerciseApp({
    super.key,
    required this.settingsController,
    required this.accountController,
    required this.syncController,
    required this.leaderboardController,
    required this.avatarImageService,
    required this.cloudSessionsLoader,
    required this.startup,
    required this.completeOnboarding,
    required this.cameraNoticeAcknowledged,
    required this.acknowledgeCameraNotice,
  });

  final AppSettingsController settingsController;
  final AccountController accountController;
  final WorkoutSyncController syncController;
  final LeaderboardController leaderboardController;
  final AvatarImageService avatarImageService;
  final Future<List<WorkoutSession>> Function(String month) cloudSessionsLoader;
  final Future<bool> startup;
  final Future<void> Function() completeOnboarding;
  final Future<bool> Function() cameraNoticeAcknowledged;
  final Future<void> Function() acknowledgeCameraNotice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: settingsController.locale,
        theme: appTheme(brightness: Brightness.light),
        darkTheme: appTheme(brightness: Brightness.dark),
        themeMode: settingsController.themeMode,
        home: AppStartupGate(
          startup: startup,
          completeOnboarding: completeOnboarding,
          showOnboarding: false,
          home: HomePage(
            settingsController: settingsController,
            accountController: accountController,
            leaderboardController: leaderboardController,
            avatarImageService: avatarImageService,
            syncController: syncController,
            cloudSessionsLoader: cloudSessionsLoader,
            cameraNoticeAcknowledged: cameraNoticeAcknowledged,
            acknowledgeCameraNotice: acknowledgeCameraNotice,
          ),
        ),
      ),
    );
  }
}
