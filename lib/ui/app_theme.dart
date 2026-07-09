import 'package:flutter/material.dart';

/// Shared color palette and theme for the app.
///
/// Extracted from main.dart so that each page/widget file can use the palette
/// without depending on main.dart. Keep this free of any widget or logic —
/// constants and the app [ThemeData] only.

const ink = Color(0xFF17261F);
const muted = Color(0xFF6D7D72);
const canvas = Color(0xFFF3FAF2);
const panel = Color(0xFFFFFFFF);
const line = Color(0xFFDCEBDF);
const green = Color(0xFF42C96B);
const greenDark = Color(0xFF118C4F);
const lime = Color(0xFFB7EA4C);
const sky = Color(0xFF43B7FF);
const coral = Color(0xFFFF4F55);
const yellow = Color(0xFFFFD84D);

const modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';
const replayVideoName = '俯卧撑.mp4';
const membershipApiBaseUrl = String.fromEnvironment(
  'UGK_MEMBERSHIP_API_BASE_URL',
  defaultValue: 'https://ugk-membership-api.294851575.workers.dev',
);
const googleServerClientId = String.fromEnvironment(
  'UGK_GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '424372780580-7tva9i6141q75kdhtjcgnlv9j0rc7cnj.apps.googleusercontent.com',
);
const revenueCatAndroidApiKey = String.fromEnvironment(
  'UGK_REVENUECAT_ANDROID_API_KEY',
  defaultValue: 'test_vPUqtEGsWzWxGpecInNmziZboEI',
);
const premiumEntitlementId = 'premium';

ThemeData appTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: greenDark,
      secondary: sky,
      surface: panel,
    ),
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: ink,
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
      headlineSmall: TextStyle(
        color: ink,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(color: muted, fontSize: 15, height: 1.35),
      labelLarge: TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}
