import 'dart:async';

import 'package:flutter/material.dart';

import 'config/membership_config.dart';
import 'control/account_controller.dart';
import 'control/leaderboard_controller.dart';
import 'control/workout_sync_controller.dart';
import 'l10n/app_localizations.dart';
import 'platform/account_session_store.dart';
import 'platform/app_settings_store.dart';
import 'platform/google_auth_service.dart';
import 'platform/membership_api_client.dart';
import 'platform/revenuecat_service.dart';
import 'product/workout_session_store.dart';
import 'ui/app_settings.dart';
import 'ui/app_theme.dart';
import 'ui/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  validateMembershipConfig();
  final settingsController = AppSettingsController(
    store: SecureAppSettingsStore(),
  );
  await settingsController.restore();
  final googleAuth = GoogleAuthService();
  final apiClient = MembershipApiClient(baseUrl: membershipApiBaseUrl);
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
      exerciseType: 'pushup',
    ),
    joinIdentity: (sessionToken, choice) =>
        apiClient.joinLeaderboard(sessionToken, choice),
    updateIdentity: apiClient.updateLeaderboardIdentity,
    leave: apiClient.leaveLeaderboard,
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
  runApp(
    UgkExerciseApp(
      settingsController: settingsController,
      accountController: controller,
      syncController: syncController,
      leaderboardController: leaderboardController,
      cloudSessionsLoader: (month) {
        final account = controller.currentSession;
        if (account == null) {
          return Future.value(const <WorkoutSession>[]);
        }
        return apiClient.cloudWorkouts(account.sessionToken, month: month);
      },
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
    required this.cloudSessionsLoader,
  });

  final AppSettingsController settingsController;
  final AccountController accountController;
  final WorkoutSyncController syncController;
  final LeaderboardController leaderboardController;
  final Future<List<WorkoutSession>> Function(String month) cloudSessionsLoader;

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
        home: HomePage(
          settingsController: settingsController,
          accountController: accountController,
          leaderboardController: leaderboardController,
          syncController: syncController,
          cloudSessionsLoader: cloudSessionsLoader,
        ),
      ),
    );
  }
}
