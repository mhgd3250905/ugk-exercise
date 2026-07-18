import 'package:flutter/material.dart';

import '../config/resource_constants.dart';
import '../platform/app_settings_store.dart';

enum AppLanguage { system, zh, en }

enum AppThemePreference { system, light, dark }

String voicePromptBaseDirFor(AppLanguage language, Locale deviceLocale) {
  return switch (language) {
    AppLanguage.zh => chineseVoicePromptBaseDir,
    AppLanguage.en => englishVoicePromptBaseDir,
    AppLanguage.system =>
      deviceLocale.languageCode.toLowerCase() == 'zh'
          ? chineseVoicePromptBaseDir
          : englishVoicePromptBaseDir,
  };
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({required AppSettingsStore store}) : _store = store;

  final AppSettingsStore _store;

  AppLanguage _language = AppLanguage.system;
  AppThemePreference _theme = AppThemePreference.system;
  bool _recognitionTraceEnabled = false;
  bool _savedRecognitionTraceEnabled = false;
  Future<void> _recognitionTraceWrite = Future<void>.value();

  AppLanguage get language => _language;
  AppThemePreference get theme => _theme;
  bool get recognitionTraceEnabled => _recognitionTraceEnabled;

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
      final savedRecognitionTraceEnabled = await _store
          .loadRecognitionTraceEnabled();
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
      _recognitionTraceEnabled = savedRecognitionTraceEnabled == true;
      _savedRecognitionTraceEnabled = _recognitionTraceEnabled;
    } catch (_) {
      _language = AppLanguage.system;
      _theme = AppThemePreference.system;
      _recognitionTraceEnabled = false;
      _savedRecognitionTraceEnabled = false;
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

  Future<bool> setRecognitionTraceEnabled(bool value) async {
    if (_recognitionTraceEnabled == value) return true;
    _recognitionTraceEnabled = value;
    notifyListeners();

    var saved = false;
    final write = _recognitionTraceWrite.then((_) async {
      try {
        await _store.saveRecognitionTraceEnabled(value);
        _savedRecognitionTraceEnabled = value;
        saved = true;
      } catch (_) {}
    });
    _recognitionTraceWrite = write;
    await write;

    if (!saved && _recognitionTraceEnabled == value) {
      _recognitionTraceEnabled = _savedRecognitionTraceEnabled;
      notifyListeners();
    }
    return saved;
  }
}
