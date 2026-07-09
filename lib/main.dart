import 'dart:async';

import 'package:flutter/material.dart';

import 'config/membership_config.dart';
import 'control/account_controller.dart';
import 'l10n/app_localizations.dart';
import 'platform/account_session_store.dart';
import 'platform/google_auth_service.dart';
import 'platform/membership_api_client.dart';
import 'platform/revenuecat_service.dart';
import 'ui/app_theme.dart';
import 'ui/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  validateMembershipConfig();
  final googleAuth = GoogleAuthService();
  final controller = AccountController(
    sessionStore: SecureAccountSessionStore(),
    apiClient: MembershipApiClient(baseUrl: membershipApiBaseUrl),
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
  unawaited(controller.restore());
  runApp(UgkExerciseApp(accountController: controller));
}

class UgkExerciseApp extends StatelessWidget {
  const UgkExerciseApp({super.key, required this.accountController});

  final AccountController accountController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: appTheme(brightness: Brightness.light),
      darkTheme: appTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomePage(accountController: accountController),
    );
  }
}
