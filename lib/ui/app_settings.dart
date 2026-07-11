import 'package:flutter/material.dart';

import '../platform/app_settings_store.dart';

enum AppLanguage { system, zh, en }

enum AppThemePreference { system, light, dark }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({required AppSettingsStore store}) : _store = store;

  final AppSettingsStore _store;

  AppLanguage _language = AppLanguage.system;
  AppThemePreference _theme = AppThemePreference.system;

  AppLanguage get language => _language;
  AppThemePreference get theme => _theme;

  Locale? get locale => switch (_language) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
  };

  ThemeMode get themeMode => switch (_theme) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Future<void> restore() async {
    try {
      final savedLanguage = await _store.loadLanguage();
      final savedTheme = await _store.loadTheme();
      _language = switch (savedLanguage) {
        'zh' => AppLanguage.zh,
        'en' => AppLanguage.en,
        _ => AppLanguage.system,
      };
      _theme = switch (savedTheme) {
        'light' => AppThemePreference.light,
        'dark' => AppThemePreference.dark,
        _ => AppThemePreference.system,
      };
    } catch (_) {
      _language = AppLanguage.system;
      _theme = AppThemePreference.system;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    try {
      await _store.saveLanguage(value.name);
    } catch (_) {}
  }

  Future<void> setTheme(AppThemePreference value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    try {
      await _store.saveTheme(value.name);
    } catch (_) {}
  }
}
