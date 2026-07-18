import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/config/resource_constants.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/ui/app_settings.dart';

void main() {
  group('voicePromptBaseDirFor', () {
    test('explicit Chinese ignores the device locale', () {
      expect(
        voicePromptBaseDirFor(AppLanguage.zh, const Locale('en', 'US')),
        chineseVoicePromptBaseDir,
      );
    });

    test('explicit English ignores the device locale', () {
      expect(
        voicePromptBaseDirFor(AppLanguage.en, const Locale('zh', 'CN')),
        englishVoicePromptBaseDir,
      );
    });

    test('system Chinese locales use Chinese prompts', () {
      expect(
        voicePromptBaseDirFor(AppLanguage.system, const Locale('zh', 'CN')),
        chineseVoicePromptBaseDir,
      );
      expect(
        voicePromptBaseDirFor(AppLanguage.system, const Locale('zh', 'TW')),
        chineseVoicePromptBaseDir,
      );
    });

    test('system English locale uses English prompts', () {
      expect(
        voicePromptBaseDirFor(AppLanguage.system, const Locale('en', 'US')),
        englishVoicePromptBaseDir,
      );
    });

    test('unsupported system locale falls back to English prompts', () {
      expect(
        voicePromptBaseDirFor(AppLanguage.system, const Locale('ja', 'JP')),
        englishVoicePromptBaseDir,
      );
    });
  });

  test('restores persisted language, theme, and recognition logging', () async {
    final store = _MemoryAppSettingsStore(
      language: 'en',
      theme: 'dark',
      recognitionTraceEnabled: true,
    );
    final controller = AppSettingsController(store: store);

    await controller.restore();

    expect(controller.language, AppLanguage.en);
    expect(controller.locale, const Locale('en'));
    expect(controller.theme, AppThemePreference.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.recognitionTraceEnabled, isTrue);
  });

  test(
    'recognition logging is disabled when no preference was saved',
    () async {
      final controller = AppSettingsController(
        store: _MemoryAppSettingsStore(),
      );

      await controller.restore();

      expect(controller.recognitionTraceEnabled, isFalse);
    },
  );

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
    await controller.setRecognitionTraceEnabled(true);

    expect(controller.locale, const Locale('zh'));
    expect(controller.themeMode, ThemeMode.light);
    expect(store.language, 'zh');
    expect(store.theme, 'light');
    expect(store.recognitionTraceEnabled, isTrue);
    expect(notifications, 3);
  });

  test(
    'storage write failure keeps language and theme but rolls back logging',
    () async {
      final store = _MemoryAppSettingsStore()..failWrites = true;
      final controller = AppSettingsController(store: store);

      await controller.setLanguage(AppLanguage.en);
      await controller.setTheme(AppThemePreference.dark);
      await controller.setRecognitionTraceEnabled(true);

      expect(controller.locale, const Locale('en'));
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.recognitionTraceEnabled, isFalse);
    },
  );

  test(
    'failed recognition logging disable rolls back the visible setting',
    () async {
      final store = _MemoryAppSettingsStore(recognitionTraceEnabled: true);
      final controller = AppSettingsController(store: store);
      await controller.restore();
      store.failWrites = true;

      await controller.setRecognitionTraceEnabled(false);

      expect(controller.recognitionTraceEnabled, isTrue);
      expect(store.recognitionTraceEnabled, isTrue);
    },
  );

  test(
    'recognition logging writes are serialized so the last choice wins',
    () async {
      final store = _DelayedRecognitionSettingsStore();
      final controller = AppSettingsController(store: store);

      final enable = controller.setRecognitionTraceEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final disable = controller.setRecognitionTraceEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(store.writeValues, [true]);

      store.completeNextWrite();
      await Future<void>.delayed(Duration.zero);
      expect(store.writeValues, [true, false]);
      store.completeNextWrite();
      await Future.wait([enable, disable]);

      expect(controller.recognitionTraceEnabled, isFalse);
      expect(store.recognitionTraceEnabled, isFalse);
    },
  );

  test(
    'two failed rapid logging writes return to the last persisted value',
    () async {
      final store = _DelayedRecognitionSettingsStore();
      final controller = AppSettingsController(store: store);

      final enable = controller.setRecognitionTraceEnabled(true);
      await Future<void>.delayed(Duration.zero);
      final disable = controller.setRecognitionTraceEnabled(false);
      await Future<void>.delayed(Duration.zero);

      store.failNextWrite();
      await Future<void>.delayed(Duration.zero);
      store.failNextWrite();
      await Future.wait([enable, disable]);

      expect(controller.recognitionTraceEnabled, isFalse);
      expect(store.recognitionTraceEnabled, isNull);
    },
  );
}

class _MemoryAppSettingsStore implements AppSettingsStore {
  _MemoryAppSettingsStore({
    this.language,
    this.theme,
    this.recognitionTraceEnabled,
  });

  String? language;
  String? theme;
  bool? recognitionTraceEnabled;
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
  Future<bool?> loadRecognitionTraceEnabled() async {
    if (failReads) throw StateError('read failed');
    return recognitionTraceEnabled;
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

  @override
  Future<void> saveRecognitionTraceEnabled(bool value) async {
    if (failWrites) throw StateError('write failed');
    recognitionTraceEnabled = value;
  }
}

class _DelayedRecognitionSettingsStore extends _MemoryAppSettingsStore {
  final writeValues = <bool>[];
  final _pendingWrites = <({bool value, Completer<void> completer})>[];

  @override
  Future<void> saveRecognitionTraceEnabled(bool value) {
    writeValues.add(value);
    final completer = Completer<void>();
    _pendingWrites.add((value: value, completer: completer));
    return completer.future.then((_) => recognitionTraceEnabled = value);
  }

  void completeNextWrite() {
    _pendingWrites.removeAt(0).completer.complete();
  }

  void failNextWrite() {
    _pendingWrites
        .removeAt(0)
        .completer
        .completeError(StateError('write failed'));
  }
}
