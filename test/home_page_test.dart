import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/platform/leaderboard_home_rank_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_home_rank.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/product/premium_plan.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/app_settings.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/pages/home_page.dart';
import 'package:ugk_exercise/ui/pages/records_page.dart';
import 'package:ugk_exercise/ui/pages/workout_page.dart';

void main() {
  testWidgets('premium profile entry uses a gold medal', (tester) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-built-in-avatar-ring-sky')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-profile-icon')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-profile-medal-gold')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-profile-medal-silver')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-premium-badge')), findsNothing);
  });

  testWidgets('personal avatar is the top-left home action', (tester) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final avatar = find.byKey(const ValueKey('home-profile-medal-silver'));
    final today = find.byKey(const ValueKey('home-today-summary'));
    expect(tester.getCenter(avatar).dx, lessThan(tester.getCenter(today).dx));
  });

  testWidgets('home never exposes the developer test entry', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(find.text('测试模式'), findsNothing);
  });

  testWidgets('profile medal uses a scalloped circular edge', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final medal = find.byKey(const ValueKey('home-profile-medal-silver'));
    final clippedEdge = find.descendant(
      of: medal,
      matching: find.byType(ClipPath),
    );
    expect(clippedEdge, findsOneWidget);

    final clipper = tester.widget<ClipPath>(clippedEdge).clipper!;
    final path = clipper.getClip(const Size.square(50));
    const center = Offset(25, 25);
    const peak = Offset(25, 1);
    const valleyAngle = -math.pi / 2 + math.pi / 18;
    final betweenTeeth = center + Offset.fromDirection(valleyAngle, 24);

    expect(path.contains(peak), isTrue);
    expect(path.contains(betweenTeeth), isFalse);
  });

  testWidgets(
    'home today summary uses a raised tonal control without outline',
    (tester) async {
      final account = _buildController(isPremium: false);
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      final summary = find.byKey(const ValueKey('home-today-summary'));
      expect(summary, findsOneWidget);
      final material = tester.widget<Material>(summary);
      expect(material.shape, isA<RoundedRectangleBorder>());
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      expect(material.elevation, greaterThan(0));
      expect(
        find.descendant(of: summary, matching: find.byType(FilledButton)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.byIcon(Icons.calendar_month_rounded),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('records page receives the current workout owner', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-today-summary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final page = tester.widget<RecordsPage>(find.byType(RecordsPage));
    expect(page.ownerAppUserId, 'user_1');
  });

  testWidgets('today total uses the current workout owner', (tester) async {
    final account = _buildController(isPremium: false);
    final store = _RecordingWorkoutSessionStore();
    await account.signIn();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pumpAndSettle();

    expect(store.lastOwnerAppUserId, 'user_1');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-today-summary')),
        matching: find.text('今日 12'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('today total and exercise cards bind distinct type totals', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final store = _TypedTotalsWorkoutSessionStore();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pumpAndSettle();

    expect(find.text('今日 19'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-exercise-card')),
        matching: find.text('今日 12'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-exercise-card-narrow-pushup')),
        matching: find.text('今日 7'),
      ),
      findsOneWidget,
    );
    expect(store.requestedDates.toSet(), hasLength(1));
  });

  testWidgets('exercise cards keep only difficulty and today metadata', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final store = _TypedTotalsWorkoutSessionStore();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pumpAndSettle();

    final standard = find.byKey(const ValueKey('home-exercise-card'));
    final narrow = find.byKey(
      const ValueKey('home-exercise-card-narrow-pushup'),
    );
    expect(
      find.descendant(of: standard, matching: find.text('难度 I')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: narrow, matching: find.text('难度 II')),
      findsOneWidget,
    );
    expect(find.text('AI 姿态识别'), findsNothing);
    expect(find.text('目标 100'), findsNothing);
    expect(find.textContaining('今日已完成'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('today counts are anchored to the exercise card right edge', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final store = _TypedTotalsWorkoutSessionStore();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pumpAndSettle();

    for (final entry in const [
      ('home-exercise-card', '今日 12'),
      ('home-exercise-card-narrow-pushup', '今日 7'),
    ]) {
      final card = find.byKey(ValueKey(entry.$1));
      final count = find.descendant(of: card, matching: find.text(entry.$2));
      expect(
        tester.getTopRight(count).dx,
        closeTo(tester.getTopRight(card).dx - 20, 0.1),
      );
    }
  });

  testWidgets('exercise difficulty metadata is localized in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = _buildController(isPremium: false);
    final store = _TypedTotalsWorkoutSessionStore();

    await tester.pumpWidget(
      _app(account: account, store: store, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Level I'), findsOneWidget);
    expect(find.text('Level II'), findsOneWidget);
    expect(find.text('Today 12'), findsOneWidget);
    expect(find.text('Today 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign out replaces the today total with ownerless records', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final store = _RecordingWorkoutSessionStore();
    await account.signIn();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pumpAndSettle();

    await account.signOut();
    await tester.pumpAndSettle();

    expect(store.lastOwnerAppUserId, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-today-summary')),
        matching: find.text('今日 99'),
      ),
      findsOneWidget,
    );
    expect(find.text('今日 12'), findsNothing);
  });

  testWidgets('stale account total cannot overwrite the current owner', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final store = _DelayedWorkoutSessionStore();
    await account.signIn();
    await tester.pumpWidget(_app(account: account, store: store));
    await tester.pump();

    await account.signOut();
    await tester.pump();
    store.complete(null, 99);
    await tester.pump();
    await tester.pump();
    expect(find.text('今日 99'), findsOneWidget);

    store.complete('user_1', 12);
    await tester.pump();
    await tester.pump();
    expect(find.text('今日 99'), findsOneWidget);
    expect(find.text('今日 12'), findsNothing);
  });

  testWidgets('exercise card is a single tappable training entry', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-exercise-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/pushup_silhouette.png',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('narrow pushup has its own card and workout type', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-exercise-card-narrow-pushup'));
    expect(card, findsOneWidget);
    expect(find.text('窄距俯卧撑'), findsOneWidget);

    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final page = tester.widget<WorkoutPage>(find.byType(WorkoutPage));
    expect(page.exerciseType, ExerciseType.narrowPushup);
  });

  testWidgets('workout page receives the recognition logging preference', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setRecognitionTraceEnabled(true);
    await tester.pumpWidget(_app(account: account, settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-exercise-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final page = tester.widget<WorkoutPage>(find.byType(WorkoutPage));
    expect(page.recognitionTraceEnabled, isTrue);
  });

  testWidgets('workout page receives the app settings controller', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    final settings = AppSettingsController(store: _TestAppSettingsStore());
    await settings.setLanguage(AppLanguage.en);
    await tester.pumpWidget(_app(account: account, settings: settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-exercise-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final page = tester.widget<WorkoutPage>(find.byType(WorkoutPage));
    expect(page.settingsController, same(settings));
  });

  testWidgets('light exercise card uses tonal layers instead of an outline', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-exercise-card')),
    );
    final narrowCard = tester.widget<Container>(
      find.byKey(const ValueKey('home-exercise-card-narrow-pushup')),
    );
    expect(card.child, isA<Material>());
    expect(card.foregroundDecoration, isNull);
    expect(narrowCard.foregroundDecoration, isNull);

    final decoration = _exerciseDecoration(tester);
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFFFFCF6),
      Color(0xFFC9E5CF),
    ]);
    expect(decoration.borderRadius, BorderRadius.circular(30));
    expect(decoration.border, isNull);
    expect(card.decoration, isA<BoxDecoration>());
    final elevation = card.decoration! as BoxDecoration;
    expect(elevation.boxShadow, hasLength(1));
    expect(elevation.boxShadow!.single.color, const Color(0x26118C4F));
    expect(elevation.boxShadow!.single.blurRadius, 28);
    expect(elevation.boxShadow!.single.offset, const Offset(0, 14));
    expect(tester.widget<Text>(find.text('俯卧撑训练')).style?.color, ink);
  });

  testWidgets('light exercise cards use distinct low-saturation themes', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final standard = _exerciseDecoration(tester);
    final narrow = _exerciseDecoration(
      tester,
      cardKey: const ValueKey('home-exercise-card-narrow-pushup'),
    );
    expect((standard.gradient! as LinearGradient).colors, const [
      Color(0xFFFFFCF6),
      Color(0xFFC9E5CF),
    ]);
    expect((narrow.gradient! as LinearGradient).colors, const [
      Color(0xFFFBFDFC),
      Color(0xFFD6ECEB),
    ]);
  });

  testWidgets('light difficulty badge uses tonal fill without an outline', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final badge = find.ancestor(
      of: find.text('难度 I'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(999),
      ),
    );
    expect(badge, findsOneWidget);
    final decoration =
        tester.widget<Container>(badge).decoration! as BoxDecoration;
    expect(decoration.border, isNull);
  });

  testWidgets('dark exercise card keeps its forest treatment', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(
      _app(account: account, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(
      (_exerciseDecoration(tester).gradient! as LinearGradient).colors,
      const [Color(0xFF16261F), Color(0xFF244736)],
    );
    expect(
      (_exerciseDecoration(
                tester,
                cardKey: const ValueKey('home-exercise-card-narrow-pushup'),
              ).gradient!
              as LinearGradient)
          .colors,
      const [Color(0xFF15262A), Color(0xFF214247)],
    );
    expect(tester.widget<Text>(find.text('俯卧撑训练')).style?.color, Colors.white);
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-exercise-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.boxShadow!.single.offset, const Offset(0, 18));
  });

  testWidgets(
    'light sports plaza card uses layered mint surfaces without outline',
    (tester) async {
      final account = _buildController(isPremium: false);
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('home-sports-plaza-card'));
      final shadowHost = tester.widget<Container>(card);
      final hostDecoration = shadowHost.decoration! as BoxDecoration;
      final ink = tester.widget<Ink>(
        find.descendant(of: card, matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, const [Color(0xFFFFFCF7), Color(0xFFD6EBDD)]);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
      expect(hostDecoration.borderRadius, BorderRadius.circular(26));
      expect(hostDecoration.boxShadow, hasLength(1));
      expect(hostDecoration.boxShadow!.single.color, const Color(0x26118C4F));
      expect(hostDecoration.boxShadow!.single.blurRadius, 28);
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('home-sports-plaza-status')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'dark sports plaza card uses a tonal step without a bright frame',
    (tester) async {
      final account = _buildController(isPremium: false);
      await tester.pumpWidget(
        _app(account: account, brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('home-sports-plaza-card'));
      final ink = tester.widget<Ink>(
        find.descendant(of: card, matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect((decoration.gradient! as LinearGradient).colors, const [
        Color(0xFF1A2C22),
        Color(0xFF15382A),
      ]);
    },
  );

  testWidgets('sports plaza uses the whole card as its call to action', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-sports-plaza-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact exercise cards fit a small safe-area viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final account = _buildController(isPremium: false);

    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final standard = find.byKey(const ValueKey('home-exercise-card'));
    final narrow = find.byKey(
      const ValueKey('home-exercise-card-narrow-pushup'),
    );
    final sportsPlaza = find.byKey(const ValueKey('home-sports-plaza-card'));
    expect(standard, findsOneWidget);
    expect(narrow, findsOneWidget);
    expect(tester.getBottomRight(narrow).dy, lessThanOrEqualTo(616));
    expect(tester.getTopLeft(sportsPlaza).dy, lessThan(616));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home surfaces fit English with top and bottom safe insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final account = _buildController(isPremium: false);

    await tester.pumpWidget(_app(account: account, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-today-summary')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-sports-plaza-card')),
      findsOneWidget,
    );
    expect(find.text('Level I'), findsOneWidget);
    expect(find.text('Level II'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home sports plaza card shows signed-out prompt when not signed in',
    (tester) async {
      final account = _buildController(isPremium: true);
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      expect(find.text('登录后查看运动广场'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
    },
  );

  testWidgets(
    'home sports plaza card shows free-user prompt for signed-in free member',
    (tester) async {
      final account = _buildController(isPremium: false);
      await account.signIn();
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-profile-medal-silver')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-profile-medal-gold')),
        findsNothing,
      );
    },
  );

  testWidgets('free member opens leaderboard premium action at the bottom', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    final leaderboard = _leaderboard(_freeNotJoinedSnapshot);
    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('查看榜单'));
    await tester.tap(find.text('查看榜单'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsOneWidget,
    );
    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.text('PushupAI 会员'), findsOneWidget);
  });

  testWidgets('renewal shows progress before clearing a frozen panel', (
    tester,
  ) async {
    final reconcileGate = Completer<void>();
    addTearDown(() {
      if (!reconcileGate.isCompleted) reconcileGate.complete();
    });
    final api = _FakeMembershipApiClient(
      isPremium: false,
      activateOnReconcile: true,
      reconcileGate: reconcileGate.future,
    );
    final account = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(
        isPremium: true,
        premiumPlans: const [
          PremiumPlan(id: PremiumPlanId.annual, price: '¥198'),
        ],
      ),
      googleSignIn: () async => 'google-token',
    );
    await account.signIn();
    final leaderboard = _dynamicLeaderboard(_frozenSnapshot);

    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-sports-plaza-card')),
    );
    await tester.tap(find.byKey(const ValueKey('home-sports-plaza-card')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-frozen-score')),
      findsOneWidget,
    );
    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续开通'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(account.busy, isTrue);
    expect(
      find.byKey(const ValueKey('leaderboard-membership-refreshing')),
      findsOneWidget,
    );
    expect(find.text('正在验证账号与会员状态，请稍候。'), findsOneWidget);
    final progress = find.descendant(
      of: find.byKey(const ValueKey('leaderboard-membership-refreshing')),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(tester.getSize(progress), const Size.square(20));
    expect(tester.widget<CircularProgressIndicator>(progress).strokeWidth, 2);

    reconcileGate.complete();
    await tester.pumpAndSettle();

    expect(account.premium, isTrue);
    expect(
      find.byKey(const ValueKey('leaderboard-frozen-score')),
      findsNothing,
    );
    expect(find.text('我的排名'), findsOneWidget);
  });

  testWidgets(
    'home sports plaza card shows join prompt for premium-not-joined',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final leaderboard = _leaderboard(_notJoinedSnapshot);
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pumpAndSettle();

      expect(find.text('加入运动广场后展示你的排名'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
    },
  );

  testWidgets(
    'home sports plaza card shows rank and points for premium-joined with day snapshot',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final leaderboard = _leaderboard(_daySnapshot);
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await leaderboard.load(LeaderboardPeriod.day);
      await tester.pumpAndSettle();

      // C3: both rank and points must render for the day snapshot.
      expect(find.text('第 12 名'), findsOneWidget);
      expect(find.text('20 分'), findsOneWidget);
      expect(find.text('登录后查看运动广场'), findsNothing);
    },
  );

  testWidgets(
    'home cached day rank keeps its row while refreshed points load',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final store = MemoryLeaderboardHomeRankStore();
      const cachedRank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      await store.save(cachedRank);
      final pending = Completer<LeaderboardSnapshot>();
      final leaderboard = _homeRankLeaderboard(
        store: store,
        load: (_, __) => pending.future,
      );
      await leaderboard.restoreHomeRankForCurrentAccount();
      final reload = leaderboard.reloadForCurrentAccount();

      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pump();

      expect(find.text('第 2 名'), findsOneWidget);
      expect(find.text('14 分'), findsNothing);
      final loading = find.byKey(
        const ValueKey('home-sports-plaza-score-loading'),
      );
      expect(loading, findsOneWidget);
      expect(tester.getSize(loading), const Size.square(20));
      expect(tester.widget<CircularProgressIndicator>(loading).strokeWidth, 2);

      pending.complete(_homeRankDaySnapshot(rank: 3, totalValue: 21));
      await reload;
      await tester.pumpAndSettle();

      expect(find.text('第 3 名'), findsOneWidget);
      expect(find.text('21 分'), findsOneWidget);
      expect(loading, findsNothing);
    },
  );

  testWidgets('home hides a cached rank for a confirmed non-premium account', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    final store = MemoryLeaderboardHomeRankStore();
    await store.save(
      const LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      ),
    );
    final leaderboard = _homeRankLeaderboard(
      store: store,
      load: (_, __) async => _notJoinedSnapshot,
    );
    await leaderboard.restoreHomeRankForCurrentAccount();

    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('第 2 名'), findsNothing);
    expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);
  });

  testWidgets(
    'home hides cached rank as soon as restore confirms inactive membership',
    (tester) async {
      final sessionStore = MemoryAccountSessionStore();
      await sessionStore.save(
        const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
          user: AppUser(
            id: 'user_1',
            displayName: '训练者',
            email: 'a@example.com',
            avatarUrl: null,
          ),
        ),
      );
      final revenueCat = _BlockingConfigureRevenueCatService();
      final meGate = Completer<void>();
      final meStarted = Completer<void>();
      final account = AccountController(
        sessionStore: sessionStore,
        apiClient: _FakeMembershipApiClient(
          isPremium: false,
          meGate: meGate.future,
          meStarted: meStarted,
        ),
        revenueCat: revenueCat,
        googleSignIn: () async => null,
      );
      final store = MemoryLeaderboardHomeRankStore();
      await store.save(
        const LeaderboardHomeRank(
          ownerAppUserId: 'user_1',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
          rank: 2,
          totalValue: 14,
        ),
      );
      final leaderboard = _homeRankLeaderboard(
        store: store,
        load: (_, __) async => _notJoinedSnapshot,
      );
      await leaderboard.restoreHomeRankForCurrentAccount();

      final restore = account.restore();
      await account.localRestoreCompleted;
      await meStarted.future;
      expect(account.busy, isTrue);
      expect(account.premium, isFalse);

      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pump();

      expect(find.text('第 2 名'), findsOneWidget);

      meGate.complete();
      await revenueCat.configureStarted.future;
      await tester.pump();

      expect(find.text('第 2 名'), findsNothing);
      expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);

      revenueCat.configureGate.complete();
      await restore;
    },
  );

  testWidgets(
    'home hides cached rank when refresh recovers a failed membership verification',
    (tester) async {
      final sessionStore = _BlockingSaveAccountSessionStore(
        const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
          user: AppUser(
            id: 'user_1',
            displayName: '训练者',
            email: 'a@example.com',
            avatarUrl: null,
          ),
        ),
      );
      final account = AccountController(
        sessionStore: sessionStore,
        apiClient: _RestoreFailureThenRefreshMembershipApiClient(),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => null,
      );
      final store = MemoryLeaderboardHomeRankStore();
      await store.save(
        const LeaderboardHomeRank(
          ownerAppUserId: 'user_1',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
          rank: 2,
          totalValue: 14,
        ),
      );
      final leaderboard = _homeRankLeaderboard(
        store: store,
        load: (_, __) async => _notJoinedSnapshot,
      );
      await leaderboard.restoreHomeRankForCurrentAccount();

      await account.restore();
      expect(account.membershipVerificationPending, isTrue);
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pump();
      expect(find.text('第 2 名'), findsOneWidget);

      final refresh = account.refresh();
      await sessionStore.saveStarted.future;
      await tester.pump();

      expect(account.membershipVerificationPending, isFalse);
      expect(find.text('第 2 名'), findsNothing);
      expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);

      sessionStore.saveGate.complete();
      await refresh;
    },
  );

  testWidgets(
    'server-confirmed no-rank response removes the home cached rank',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final store = MemoryLeaderboardHomeRankStore();
      await store.save(
        const LeaderboardHomeRank(
          ownerAppUserId: 'user_1',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
          rank: 2,
          totalValue: 14,
        ),
      );
      final leaderboard = _homeRankLeaderboard(
        store: store,
        load: (_, __) async => _notJoinedSnapshot,
      );
      await leaderboard.restoreHomeRankForCurrentAccount();
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pumpAndSettle();

      expect(find.text('第 2 名'), findsOneWidget);
      await leaderboard.load(LeaderboardPeriod.day);
      await tester.pumpAndSettle();

      expect(find.text('第 2 名'), findsNothing);
      expect(find.text('加入运动广场后展示你的排名'), findsOneWidget);
    },
  );

  testWidgets(
    'home sports plaza card does not surface a week snapshot as day rank',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final leaderboard = _leaderboard(_weekSnapshot);
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await leaderboard.load(LeaderboardPeriod.week);
      await tester.pumpAndSettle();

      // C3: a week-period snapshot must NOT be rendered as the home day rank/count,
      // even though the user is joined and me is present.
      expect(find.text('第 5 名'), findsNothing);
      expect(find.text('40 分'), findsNothing);
    },
  );

  testWidgets('resuming the app refreshes the shared account snapshot', (
    tester,
  ) async {
    final api = _FakeMembershipApiClient(isPremium: false);
    final account = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    api.meCalls = 0;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.meCalls, 1);
  });

  testWidgets('free records do not request premium cloud history', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    var cloudLoads = 0;
    await tester.pumpWidget(
      _app(
        account: account,
        cloudSessionsLoader: (_) async {
          cloudLoads += 1;
          return const [];
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-today-summary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(cloudLoads, 0);
  });

  testWidgets('premium records request cloud history', (tester) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    var cloudLoads = 0;
    await tester.pumpWidget(
      _app(
        account: account,
        cloudSessionsLoader: (_) async {
          cloudLoads += 1;
          return const [];
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-today-summary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(cloudLoads, 1);
  });
}

Widget _app({
  required AccountController account,
  AppSettingsController? settings,
  LeaderboardController? leaderboard,
  Brightness? brightness,
  Locale locale = const Locale('zh'),
  Future<List<WorkoutSession>> Function(String month)? cloudSessionsLoader,
  WorkoutSessionStore? store,
}) {
  return MaterialApp(
    theme: brightness == null ? null : appTheme(brightness: brightness),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomePage(
      settingsController:
          settings ?? AppSettingsController(store: _TestAppSettingsStore()),
      accountController: account,
      leaderboardController: leaderboard,
      cloudSessionsLoader: cloudSessionsLoader,
      workoutSessionStore: store,
    ),
  );
}

BoxDecoration _exerciseDecoration(
  WidgetTester tester, {
  ValueKey<String> cardKey = const ValueKey('home-exercise-card'),
}) {
  final card = find.byKey(cardKey);
  final background = find.descendant(
    of: card,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Ink &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).gradient is LinearGradient,
    ),
  );
  return tester.widget<Ink>(background).decoration! as BoxDecoration;
}

class _TestAppSettingsStore implements AppSettingsStore {
  @override
  Future<String?> loadLanguage() async => null;

  @override
  Future<String?> loadTheme() async => null;

  @override
  Future<bool?> loadRecognitionTraceEnabled() async => null;

  @override
  Future<void> saveLanguage(String value) async {}

  @override
  Future<void> saveTheme(String value) async {}

  @override
  Future<void> saveRecognitionTraceEnabled(bool value) async {}
}

class _RecordingWorkoutSessionStore extends WorkoutSessionStore {
  String? lastOwnerAppUserId;

  @override
  Future<int> totalForLocalDate(
    DateTime date, {
    String? ownerAppUserId,
    String? exerciseType,
  }) async {
    lastOwnerAppUserId = ownerAppUserId;
    if (exerciseType == ExerciseType.narrowPushup.storageValue) {
      return 0;
    }
    return ownerAppUserId == 'user_1' ? 12 : 99;
  }
}

class _TypedTotalsWorkoutSessionStore extends WorkoutSessionStore {
  final requestedDates = <DateTime>[];

  @override
  Future<int> totalForLocalDate(
    DateTime date, {
    String? ownerAppUserId,
    String? exerciseType,
  }) async {
    requestedDates.add(date);
    return switch (exerciseType) {
      null => 19,
      'pushup' => 12,
      'narrow_pushup' => 7,
      _ => 0,
    };
  }
}

class _DelayedWorkoutSessionStore extends WorkoutSessionStore {
  final _totals = <(String?, String?), Completer<int>>{};

  @override
  Future<int> totalForLocalDate(
    DateTime date, {
    String? ownerAppUserId,
    String? exerciseType,
  }) {
    return _totals.putIfAbsent((
      ownerAppUserId,
      exerciseType,
    ), Completer<int>.new).future;
  }

  void complete(String? ownerAppUserId, int total) {
    for (final entry in _totals.entries) {
      if (entry.key.$1 == ownerAppUserId && !entry.value.isCompleted) {
        entry.value.complete(entry.key.$2 == null ? total : 0);
      }
    }
  }
}

AccountController _buildController({required bool isPremium}) {
  return AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient: _FakeMembershipApiClient(isPremium: isPremium),
    revenueCat: FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
    clearAvatarImageCache: () async {},
  );
}

LeaderboardController _leaderboard(LeaderboardSnapshot snapshot) {
  return LeaderboardController(
    sessionProvider: () => const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    ),
    load: (_, __) async => snapshot,
    joinIdentity: (_, __) async {},
    updateIdentity: (_, __) async {},
    leave: (_) async {},
  );
}

LeaderboardController _dynamicLeaderboard(
  LeaderboardSnapshot Function(LeaderboardPeriod period) snapshot,
) {
  return LeaderboardController(
    sessionProvider: () => const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    ),
    load: (_, period) async => snapshot(period),
    joinIdentity: (_, __) async {},
    updateIdentity: (_, __) async {},
    leave: (_) async {},
  );
}

LeaderboardController _homeRankLeaderboard({
  required MemoryLeaderboardHomeRankStore store,
  required LeaderboardLoad load,
}) {
  return LeaderboardController(
    sessionProvider: () => const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    ),
    homeRankStore: store,
    clock: () => DateTime.utc(2026, 7, 19, 16),
    load: load,
    joinIdentity: (_, __) async {},
    updateIdentity: (_, __) async {},
    leave: (_) async {},
  );
}

LeaderboardSnapshot _homeRankDaySnapshot({
  required int rank,
  required int totalValue,
}) {
  return LeaderboardSnapshot(
    period: LeaderboardPeriod.day,
    exerciseType: 'pushup',
    isJoined: true,
    top: const [],
    me: LeaderboardRow(
      rank: rank,
      userId: 'user_1',
      nickname: null,
      avatarKey: 'ring-green',
      totalValue: totalValue,
    ),
  );
}

LeaderboardSnapshot _frozenSnapshot(LeaderboardPeriod period) {
  return LeaderboardSnapshot(
    period: period,
    exerciseType: 'pushup',
    isJoined: true,
    canJoin: false,
    frozenTotalValue: 42,
    top: const [],
    me: const LeaderboardRow(
      rank: 1,
      userId: 'user_1',
      nickname: '训练者',
      avatarKey: 'ring-sky',
      totalValue: 42,
    ),
  );
}

const _daySnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: true,
  top: [],
  me: LeaderboardRow(
    rank: 12,
    userId: 'me',
    nickname: '我',
    avatarKey: 'ring-lime',
    totalValue: 20,
  ),
);

const _notJoinedSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: false,
  top: [],
  me: null,
);

const _freeNotJoinedSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: false,
  canJoin: false,
  top: [],
  me: null,
);

const _weekSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.week,
  exerciseType: 'pushup',
  isJoined: true,
  top: [],
  me: LeaderboardRow(
    rank: 5,
    userId: 'me',
    nickname: '我',
    avatarKey: 'ring-lime',
    totalValue: 40,
  ),
);

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient({
    required this.isPremium,
    this.activateOnReconcile = false,
    this.reconcileGate,
    this.meGate,
    this.meStarted,
  }) : super(baseUrl: 'https://api.example.com');

  bool isPremium;
  final bool activateOnReconcile;
  final Future<void>? reconcileGate;
  final Future<void>? meGate;
  final Completer<void>? meStarted;
  var meCalls = 0;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
        avatarKey: 'ring-sky',
      ),
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_google_play' : 'none',
      ),
    );
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    meCalls += 1;
    meStarted?.complete();
    await meGate;
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: appUserId,
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
        avatarKey: 'ring-sky',
      ),
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_google_play' : 'none',
      ),
    );
  }

  @override
  Future<MembershipStatus> reconcileMembership(String sessionToken) async {
    final gate = reconcileGate;
    if (gate != null) await gate;
    if (activateOnReconcile) isPremium = true;
    return MembershipStatus(
      entitlement: 'premium',
      isActive: isPremium,
      expiresAt: null,
      source: isPremium ? 'revenuecat_google_play' : 'none',
    );
  }
}

class _BlockingConfigureRevenueCatService implements RevenueCatService {
  final configureGate = Completer<void>();
  final configureStarted = Completer<void>();

  @override
  Future<void> configure({required String appUserId}) async {
    configureStarted.complete();
    await configureGate.future;
  }

  @override
  Future<List<PremiumPlan>> loadPremiumPlans() async => const [];

  @override
  Future<void> logOut() async {}

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async => false;

  @override
  Future<bool> restorePurchases() async => false;
}

class _BlockingSaveAccountSessionStore implements AccountSessionStore {
  _BlockingSaveAccountSessionStore(this.session);

  SavedAccountSession? session;
  final saveStarted = Completer<void>();
  final saveGate = Completer<void>();

  @override
  Future<SavedAccountSession?> load() async => session;

  @override
  Future<void> save(SavedAccountSession value) async {
    saveStarted.complete();
    await saveGate.future;
    session = value;
  }

  @override
  Future<void> clear() async => session = null;
}

class _RestoreFailureThenRefreshMembershipApiClient
    extends MembershipApiClient {
  _RestoreFailureThenRefreshMembershipApiClient()
    : super(baseUrl: 'https://api.example.com');

  var _meCalls = 0;

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    _meCalls++;
    if (_meCalls == 1) {
      throw const MembershipApiException('temporary failure', statusCode: 503);
    }
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: appUserId,
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
      ),
      membership: MembershipStatus.none,
    );
  }
}
