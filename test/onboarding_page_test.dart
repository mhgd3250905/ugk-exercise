import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/ui/pages/onboarding_page.dart';

void main() {
  testWidgets('startup duration begins after the first rasterized frame', (
    tester,
  ) async {
    final firstFrameRasterized = Completer<void>();
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: Future.value(true),
          completeOnboarding: () async {},
          home: const Text('HOME'),
          firstFrameRasterized: firstFrameRasterized.future,
        ),
      ),
      phase: EnginePhase.build,
    );

    await tester.pump(const Duration(milliseconds: 1200), EnginePhase.build);

    expect(find.byKey(const ValueKey('app-startup-loading')), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('startup loading shows a static branded lockup', (tester) async {
    final startup = Completer<bool>();
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: startup.future,
          completeOnboarding: () async {},
          home: const Text('HOME'),
          firstFrameRasterized: Future.value(),
        ),
      ),
    );

    final lockup = find.byKey(const ValueKey('startup-lockup'));
    expect(lockup, findsOneWidget);
    expect(
      (tester.widget<Image>(lockup).image as AssetImage).assetName,
      'assets/images/startup_lockup.png',
    );
    expect(tester.widget<Image>(lockup).width, 288);
    expect(
      tester.getCenter(lockup).dy,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('app-startup-loading'))).dy,
        0.1,
      ),
    );
    expect(find.bySemanticsLabel('PushupAI'), findsOneWidget);
    expect(find.text('PushupAI'), findsNothing);
    expect(find.text('架好手机，专心做好每一次。'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('startup-breathing')), findsNothing);
    final initialRect = tester.getRect(lockup);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getRect(lockup), initialRect);
  });

  testWidgets('startup lockup stays centered behind uneven system bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 96, bottom: 24),
            viewPadding: EdgeInsets.only(top: 96, bottom: 24),
          ),
          child: AppStartupGate(
            startup: Future.value(true),
            completeOnboarding: () async {},
            home: const Text('HOME'),
            firstFrameRasterized: Future.value(),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.byKey(const ValueKey('startup-lockup'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('app-startup-loading'))).dy,
        0.1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
  });

  testWidgets('startup slogan fades in without moving the lockup center', (
    tester,
  ) async {
    final startup = Completer<bool>();
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: startup.future,
          completeOnboarding: () async {},
          home: const Text('HOME'),
          firstFrameRasterized: Future.value(),
        ),
      ),
    );
    await tester.pump();

    final lockup = find.byKey(const ValueKey('startup-lockup'));
    final sloganOpacity = find.byKey(const ValueKey('startup-slogan-opacity'));
    final lockupCenter = tester.getCenter(lockup);
    expect(tester.widget<Opacity>(sloganOpacity).opacity, 0);

    await tester.pump(const Duration(milliseconds: 200));
    final halfwayOpacity = tester.widget<Opacity>(sloganOpacity).opacity;
    expect(halfwayOpacity, greaterThan(0));
    expect(halfwayOpacity, lessThan(1));
    expect((tester.getCenter(lockup) - lockupCenter).distance, lessThan(0.1));

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Opacity>(sloganOpacity).opacity, 1);
    expect((tester.getCenter(lockup) - lockupCenter).distance, lessThan(0.1));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('startup slogan appears immediately when animations are off', (
    tester,
  ) async {
    final startup = Completer<bool>();
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AppStartupGate(
            startup: startup.future,
            completeOnboarding: () async {},
            home: const Text('HOME'),
            firstFrameRasterized: Future.value(),
          ),
        ),
      ),
    );
    await tester.pump();

    final sloganOpacity = find.byKey(const ValueKey('startup-slogan-opacity'));
    expect(tester.widget<Opacity>(sloganOpacity).opacity, 1);
    await tester.pump(const Duration(milliseconds: 1200));
  });

  testWidgets('startup loading stays visible for at least 1.2 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: Future.value(true),
          completeOnboarding: () async {},
          home: const Text('HOME'),
          firstFrameRasterized: Future.value(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('app-startup-loading')), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1199));
    expect(find.byKey(const ValueKey('app-startup-loading')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('first-time user enters home while onboarding is disabled', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      _app(
        AppStartupGate(
          startup: Future.value(false),
          completeOnboarding: () async => completions++,
          showOnboarding: false,
          home: const Text('HOME'),
          firstFrameRasterized: Future.value(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-onboarding')), findsNothing);
    expect(completions, 0);
  });

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
            firstFrameRasterized: Future.value(),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('app-startup-loading')), findsOneWidget);
      expect(find.text('HOME'), findsNothing);

      startup.complete(false);
      await tester.pump(const Duration(milliseconds: 1200));
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
          firstFrameRasterized: Future.value(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-onboarding')), findsNothing);
  });

  testWidgets('next advances when system animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OnboardingPage(onComplete: () async {}),
        ),
      ),
    );

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('摆对手机，识别更稳定'), findsOneWidget);
  });
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
