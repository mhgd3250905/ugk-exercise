import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/ui/pages/onboarding_page.dart';

void main() {
  testWidgets(
    'startup gate waits, then first-time user can finish onboarding',
    (tester) async {
      final startup = Completer<bool>();
      var completions = 0;
      await tester.pumpWidget(
        _app(
          AppStartupGate(
            startup: startup.future,
            completeOnboarding: () async => completions++,
            home: const Text('HOME'),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('app-startup-loading')), findsOneWidget);
      expect(find.text('HOME'), findsNothing);

      startup.complete(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-onboarding')), findsOneWidget);
      expect(find.text('AI 帮你数好每一次'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('摆对手机，识别更稳定'), findsOneWidget);

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.textContaining('开始训练时'), findsOneWidget);

      await tester.tap(find.text('开始使用'));
      await tester.pumpAndSettle();
      expect(completions, 1);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('returning user enters home without onboarding', (tester) async {
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: Future.value(true),
          completeOnboarding: () async {},
          home: const Text('HOME'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-onboarding')), findsNothing);
  });
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
