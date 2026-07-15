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
const homeGradientTop = Color(0xFFF2F9ED);
const homeGradientBottom = Color(0xFFE1F0E5);
const green = Color(0xFF42C96B);
const greenDark = Color(0xFF118C4F);
const lime = Color(0xFFB7EA4C);
const sky = Color(0xFF43B7FF);
const coral = Color(0xFFFF4F55);
const yellow = Color(0xFFFFD84D);

const darkInk = Color(0xFFE7F3EA);
const darkMuted = Color(0xFF9EB3A6);
const darkCanvas = Color(0xFF0E1713);
const darkPanel = Color(0xFF17241D);
const darkLine = Color(0xFF2B4034);
const darkHomeGradientTop = Color(0xFF122019);
const darkHomeGradientBottom = Color(0xFF0A120E);

const modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';
const replayVideoName = '俯卧撑.mp4';

ThemeData appTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? darkCanvas : canvas;
  final surface = isDark ? darkPanel : panel;
  final foreground = isDark ? darkInk : ink;
  final secondaryText = isDark ? darkMuted : muted;
  final outline = isDark ? darkLine : line;
  final primary = isDark ? green : greenDark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
      primary: primary,
      secondary: sky,
      surface: surface,
      onSurface: foreground,
      outline: outline,
    ),
    scaffoldBackgroundColor: background,
    cardColor: surface,
    dividerColor: outline,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: foreground),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: outline),
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: foreground,
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1.05,
      ),
      headlineSmall: TextStyle(
        color: foreground,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
      titleLarge: TextStyle(
        color: foreground,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      titleMedium: TextStyle(
        color: foreground,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(color: secondaryText, fontSize: 15, height: 1.35),
      labelLarge: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}
