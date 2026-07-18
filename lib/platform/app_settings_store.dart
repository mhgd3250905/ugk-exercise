import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AppSettingsStore {
  Future<String?> loadLanguage();
  Future<String?> loadTheme();
  Future<bool?> loadRecognitionTraceEnabled();
  Future<void> saveLanguage(String value);
  Future<void> saveTheme(String value);
  Future<void> saveRecognitionTraceEnabled(bool value);
}

class SecureAppSettingsStore implements AppSettingsStore {
  SecureAppSettingsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _languageKey = 'ugk_app_language';
  static const _themeKey = 'ugk_app_theme';
  static const _recognitionTraceEnabledKey = 'ugk_recognition_trace_enabled';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> loadLanguage() => _storage.read(key: _languageKey);

  @override
  Future<String?> loadTheme() => _storage.read(key: _themeKey);

  @override
  Future<bool?> loadRecognitionTraceEnabled() async {
    final value = await _storage.read(key: _recognitionTraceEnabledKey);
    return switch (value) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  @override
  Future<void> saveLanguage(String value) =>
      _storage.write(key: _languageKey, value: value);

  @override
  Future<void> saveTheme(String value) =>
      _storage.write(key: _themeKey, value: value);

  @override
  Future<void> saveRecognitionTraceEnabled(bool value) =>
      _storage.write(key: _recognitionTraceEnabledKey, value: value.toString());
}
