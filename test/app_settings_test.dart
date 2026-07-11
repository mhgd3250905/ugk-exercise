import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/ui/app_settings.dart';

void main() {
  test('restores persisted language and theme', () async {
    final store = _MemoryAppSettingsStore(language: 'en', theme: 'dark');
    final controller = AppSettingsController(store: store);

    await controller.restore();

    expect(controller.language, AppLanguage.en);
    expect(controller.locale, const Locale('en'));
    expect(controller.theme, AppThemePreference.dark);
    expect(controller.themeMode, ThemeMode.dark);
  });

  test('invalid persisted settings fall back to system defaults', () async {
    final store = _MemoryAppSettingsStore(
      language: 'unsupported',
      theme: 'unknown',
    );
    final controller = AppSettingsController(store: store);

    await controller.restore();

    expect(controller.language, AppLanguage.system);
    expect(controller.locale, isNull);
    expect(controller.theme, AppThemePreference.system);
    expect(controller.themeMode, ThemeMode.system);
  });

  test('storage read failure keeps system defaults', () async {
    final store = _MemoryAppSettingsStore()..failReads = true;
    final controller = AppSettingsController(store: store);

    await controller.restore();

    expect(controller.locale, isNull);
    expect(controller.themeMode, ThemeMode.system);
  });

  test('changes notify immediately and persist each preference', () async {
    final store = _MemoryAppSettingsStore();
    final controller = AppSettingsController(store: store);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await controller.setLanguage(AppLanguage.zh);
    await controller.setTheme(AppThemePreference.light);

    expect(controller.locale, const Locale('zh'));
    expect(controller.themeMode, ThemeMode.light);
    expect(store.language, 'zh');
    expect(store.theme, 'light');
    expect(notifications, 2);
  });

  test('storage write failure keeps the current selection', () async {
    final store = _MemoryAppSettingsStore()..failWrites = true;
    final controller = AppSettingsController(store: store);

    await controller.setLanguage(AppLanguage.en);
    await controller.setTheme(AppThemePreference.dark);

    expect(controller.locale, const Locale('en'));
    expect(controller.themeMode, ThemeMode.dark);
  });
}

class _MemoryAppSettingsStore implements AppSettingsStore {
  _MemoryAppSettingsStore({this.language, this.theme});

  String? language;
  String? theme;
  var failReads = false;
  var failWrites = false;

  @override
  Future<String?> loadLanguage() async {
    if (failReads) throw StateError('read failed');
    return language;
  }

  @override
  Future<String?> loadTheme() async {
    if (failReads) throw StateError('read failed');
    return theme;
  }

  @override
  Future<void> saveLanguage(String value) async {
    if (failWrites) throw StateError('write failed');
    language = value;
  }

  @override
  Future<void> saveTheme(String value) async {
    if (failWrites) throw StateError('write failed');
    theme = value;
  }
}
