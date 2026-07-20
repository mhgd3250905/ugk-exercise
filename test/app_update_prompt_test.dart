import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/product/app_update.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/app_update_prompt.dart';

const _zhRelease = AppReleaseInfo(
  versionCode: 18,
  versionName: '0.3.15',
  releaseNotes: ['新增启动更新提示', '提升版本检查稳定性'],
);

Widget _app({
  required Future<AppReleaseInfo?> Function(String languageCode) checkForUpdate,
  required Future<bool> Function() openPlayStore,
  Locale locale = const Locale('zh'),
  ThemeMode themeMode = ThemeMode.light,
  Widget? child,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: appTheme(brightness: Brightness.light),
    darkTheme: appTheme(brightness: Brightness.dark),
    themeMode: themeMode,
    home: AppUpdatePrompt(
      checkForUpdate: checkForUpdate,
      openPlayStore: openPlayStore,
      child: child ?? const Scaffold(body: Text('Home')),
    ),
  );
}

void main() {
  testWidgets('shows the localized version and release-note list once', (
    tester,
  ) async {
    var checks = 0;
    String? languageCode;
    await tester.pumpWidget(
      _app(
        checkForUpdate: (language) async {
          checks += 1;
          languageCode = language;
          return _zhRelease;
        },
        openPlayStore: () async => true,
      ),
    );

    await tester.pumpAndSettle();

    expect(checks, 1);
    expect(languageCode, 'zh');
    expect(find.byKey(const ValueKey('app-update-dialog')), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('PushupAI 0.3.15'), findsOneWidget);
    expect(find.text('本次更新'), findsOneWidget);
    expect(find.text('新增启动更新提示'), findsOneWidget);
    expect(find.text('提升版本检查稳定性'), findsOneWidget);

    await tester.pump();
    expect(checks, 1);
  });

  testWidgets('later dismisses without opening Google Play', (tester) async {
    var launches = 0;
    await tester.pumpWidget(
      _app(
        checkForUpdate: (_) async => _zhRelease,
        openPlayStore: () async {
          launches += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-update-later')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-update-dialog')), findsNothing);
    expect(launches, 0);
  });

  testWidgets('update dismisses and opens Google Play', (tester) async {
    var launches = 0;
    await tester.pumpWidget(
      _app(
        checkForUpdate: (_) async => _zhRelease,
        openPlayStore: () async {
          launches += 1;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-update-open-store')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-update-dialog')), findsNothing);
    expect(launches, 1);
  });

  testWidgets('failed Google Play launch shows the existing localized error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        checkForUpdate: (_) async => _zhRelease,
        openPlayStore: () async => false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('app-update-open-store')));
    await tester.pumpAndSettle();

    expect(find.text('无法打开 Google Play，请稍后重试。'), findsOneWidget);
  });

  testWidgets('no available update leaves the home screen untouched', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(checkForUpdate: (_) async => null, openPlayStore: () async => true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('does not interrupt after the user leaves the home route', (
    tester,
  ) async {
    final pending = Completer<AppReleaseInfo?>();
    await tester.pumpWidget(
      _app(
        checkForUpdate: (_) => pending.future,
        openPlayStore: () async => true,
        child: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Workout')),
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    pending.complete(_zhRelease);
    await tester.pumpAndSettle();

    expect(find.text('Workout'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-update-dialog')), findsNothing);
  });

  testWidgets('English dark dialog fits a 320 by 640 viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const release = AppReleaseInfo(
      versionCode: 18,
      versionName: '0.3.15',
      releaseNotes: [
        'A clearer update prompt at startup',
        'More reliable version checks on slow networks',
        'A safer Google Play handoff for every release',
      ],
    );

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        themeMode: ThemeMode.dark,
        checkForUpdate: (_) async => release,
        openPlayStore: () async => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A new version is ready'), findsOneWidget);
    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
