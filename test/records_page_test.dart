import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/pages/records_page.dart';

import 'support/test_workout_session_repository.dart';

void main() {
  testWidgets('switches between current week month and year totals', (
    tester,
  ) async {
    final now = DateTime.now();
    final otherMonthDay = now.day > 7
        ? 1
        : DateUtils.getDaysInMonth(now.year, now.month);
    final otherYearMonth = now.month == 1 ? 2 : 1;
    final store = _MemoryWorkoutSessionStore([
      _session('today', DateTime(now.year, now.month, now.day), 10),
      _session('same-month', DateTime(now.year, now.month, otherMonthDay), 20),
      _session('same-year', DateTime(now.year, otherYearMonth, 15), 30),
      _session('previous-year', DateTime(now.year - 1, 12, 15), 100),
    ]);

    await tester.pumpWidget(_buildApp(RecordsPage(store: store)));
    await _pumpRecords(tester);

    expect(find.text('30 个'), findsOneWidget);

    await tester.tap(find.text('周'));
    await tester.pump();
    expect(find.text('10 个'), findsWidgets);

    await tester.tap(find.text('年'));
    await tester.pump();
    expect(find.text('60 个'), findsOneWidget);
  });

  testWidgets('record totals use compact rounded watermark cards', (
    tester,
  ) async {
    final now = DateTime.now();
    final activeDay = now.day == 1 ? 2 : 1;
    final store = _MemoryWorkoutSessionStore([
      _session('watermark-day', DateTime(now.year, now.month, activeDay), 37),
    ]);

    await tester.pumpWidget(_buildApp(RecordsPage(store: store)));
    await _pumpRecords(tester);

    final dayCell = find.byKey(ValueKey('records-day-cell-$activeDay'));
    expect(dayCell, findsOneWidget);
    expect(tester.getSize(dayCell), const Size.square(54));
    final decoration =
        tester.widget<Container>(dayCell).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, isNotNull);
    expect(decoration.color, isNot(Colors.transparent));

    final dayLabel = find.descendant(
      of: dayCell,
      matching: find.text('$activeDay'),
    );
    final watermark = find.descendant(of: dayCell, matching: find.text('37'));
    expect(
      tester.getTopLeft(dayLabel).dx,
      lessThanOrEqualTo(tester.getTopLeft(watermark).dx),
    );
    expect(
      tester.getTopLeft(dayLabel).dy,
      lessThan(tester.getTopLeft(watermark).dy),
    );
    final watermarkStyle = tester.widget<Text>(watermark).style!;
    expect(watermarkStyle.fontSize, 30);
    expect(watermarkStyle.color!.a, lessThan(0.25));

    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();

    final monthCell = find.byKey(ValueKey('records-day-cell-${now.month}'));
    expect(tester.getSize(monthCell), const Size.square(72));
    final yearWatermark = find.descendant(
      of: monthCell,
      matching: find.text('37'),
    );
    expect(tester.widget<Text>(yearWatermark).style!.fontSize, 40);
  });

  testWidgets('cloud status uses a tonal chip without decorative frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: _MemoryWorkoutSessionStore(const []),
          cloudSessionsFuture: Future.value(const []),
        ),
      ),
    );
    await _pumpRecords(tester);

    final chip = find.ancestor(
      of: find.text('云端记录已合并'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).borderRadius ==
                BorderRadius.circular(999),
      ),
    );
    expect(chip, findsOneWidget);
    final decoration =
        tester.widget<Container>(chip).decoration! as BoxDecoration;
    expect(decoration.color, lightSageSurface);
    expect(decoration.border, isNull);
    expect(
      find.descendant(
        of: chip,
        matching: find.byIcon(Icons.cloud_done_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('period summary is an elevated tonal surface in both themes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _buildApp(
          RecordsPage(store: _MemoryWorkoutSessionStore(const [])),
          brightness: brightness,
        ),
      );
      await _pumpRecords(tester);
      await tester.pumpAndSettle();

      final summary = tester.widget<Container>(
        find.byKey(const ValueKey('records-period-summary')),
      );
      final decoration = summary.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(
        decoration.color,
        brightness == Brightness.dark ? darkRaisedSurface : lightRaisedSurface,
      );
    }
  });

  testWidgets('period summary promotes the center total', (tester) async {
    final now = DateTime.now();
    final store = _MemoryWorkoutSessionStore([
      _session('a', DateTime(now.year, now.month, 1), 10),
      _session('b', DateTime(now.year, now.month, 2), 20),
    ]);
    await tester.pumpWidget(_buildApp(RecordsPage(store: store)));
    await _pumpRecords(tester);

    final total = tester.widget<Text>(find.text('30 个'));
    final best = tester.widget<Text>(find.text('20 个'));
    expect(total.style!.fontSize, greaterThan(best.style!.fontSize!));
    expect(
      total.style!.fontWeight!.value,
      greaterThan(best.style!.fontWeight!.value),
    );
  });

  testWidgets('animates the period pill and slides records by direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(RecordsPage(store: _MemoryWorkoutSessionStore(const []))),
    );
    await _pumpRecords(tester);

    final indicator = find.byKey(const ValueKey('records-period-indicator'));
    final monthContent = find.byKey(
      const ValueKey('records-period-content-month'),
    );
    final legend = find.byKey(const ValueKey('records-calendar-legend'));
    final summary = find.byKey(const ValueKey('records-period-summary'));
    final monthX = tester.getCenter(indicator).dx;
    final summaryRect = tester.getRect(summary);

    await tester.tap(find.text('年'));
    await tester.pump();
    final yearContent = find.byKey(
      const ValueKey('records-period-content-year'),
    );
    expect(
      find
          .ancestor(of: yearContent, matching: find.byType(FadeTransition))
          .first,
      findsOneWidget,
    );
    final yearStartX = tester.getTopLeft(yearContent).dx;
    expect(tester.getCenter(indicator).dx, monthX);

    await tester.pump(const Duration(milliseconds: 100));
    final indicatorMidX = tester.getCenter(indicator).dx;
    expect(indicatorMidX, greaterThan(monthX));
    expect(legend, findsOneWidget);
    expect(summary, findsOneWidget);
    expect(tester.getRect(summary), summaryRect);
    expect(
      tester.getRect(monthContent).right,
      lessThanOrEqualTo(tester.getRect(yearContent).left + 1),
    );
    await tester.pumpAndSettle();
    expect(tester.getCenter(indicator).dx, greaterThan(indicatorMidX));
    expect(yearStartX, greaterThan(tester.getTopLeft(yearContent).dx));
    expect(tester.getRect(summary), summaryRect);

    await tester.tap(find.text('周'));
    await tester.pump();
    final weekContent = find.byKey(
      const ValueKey('records-period-content-week'),
    );
    final weekStartX = tester.getTopLeft(weekContent).dx;
    await tester.pumpAndSettle();
    expect(weekStartX, lessThan(tester.getTopLeft(weekContent).dx));
    expect(tester.getRect(summary), summaryRect);
  });

  testWidgets('keeps period content top aligned throughout the slide', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(RecordsPage(store: _MemoryWorkoutSessionStore(const []))),
    );
    await _pumpRecords(tester);

    await tester.tap(find.text('周'));
    await tester.pump(const Duration(milliseconds: 100));
    final weekContent = find.byKey(
      const ValueKey('records-period-content-week'),
    );
    final transitionTop = tester.getTopLeft(weekContent).dy;

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(weekContent).dy, transitionTop);
  });

  testWidgets('navigates months without entering the future', (tester) async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);
    final store = _MemoryWorkoutSessionStore([
      _session('current-month', DateTime(now.year, now.month, 1), 3),
      _session(
        'previous-month-a',
        DateTime(previousMonth.year, previousMonth.month, 2),
        8,
      ),
      _session(
        'previous-month-b',
        DateTime(previousMonth.year, previousMonth.month, 3),
        7,
      ),
    ]);

    await tester.pumpWidget(_buildApp(RecordsPage(store: store)));
    await _pumpRecords(tester);

    expect(_periodButton(tester, 'records-period-next').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('records-period-previous')));
    await tester.pumpAndSettle();

    expect(find.text(_monthTitle(previousMonth)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('records-period-summary')),
        matching: find.text('15 个'),
      ),
      findsOneWidget,
    );
    expect(_periodButton(tester, 'records-period-next').onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('records-period-next')));
    await tester.pumpAndSettle();

    expect(find.text(_monthTitle(now)), findsOneWidget);
    expect(_periodButton(tester, 'records-period-next').onPressed, isNull);
  });

  testWidgets('moves weeks by seven days and years by one year', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: now.weekday % 7));
    final previousWeekStart = currentWeekStart.subtract(
      const Duration(days: 7),
    );
    final store = _MemoryWorkoutSessionStore([
      _session(
        'previous-week',
        previousWeekStart.add(const Duration(days: 2)),
        14,
      ),
      _session('previous-year', DateTime(now.year - 1, 6, 15), 25),
    ]);

    await tester.pumpWidget(_buildApp(RecordsPage(store: store)));
    await _pumpRecords(tester);

    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-period-previous')));
    await tester.pumpAndSettle();

    expect(find.text(_weekTitle(previousWeekStart)), findsOneWidget);
    expect(find.text('14 个'), findsWidgets);

    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('records-period-previous')));
    await tester.pumpAndSettle();

    expect(find.text('${now.year - 1}年'), findsOneWidget);
    expect(find.text('25 个'), findsWidgets);
  });

  testWidgets(
    'remembers each mode position and clears historical today marks',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentWeekStart = today.subtract(Duration(days: now.weekday % 7));
      final previousWeekStart = currentWeekStart.subtract(
        const Duration(days: 7),
      );
      final previousMonth = DateTime(now.year, now.month - 1);

      await tester.pumpWidget(
        _buildApp(RecordsPage(store: _MemoryWorkoutSessionStore(const []))),
      );
      await _pumpRecords(tester);

      await tester.tap(find.byKey(const ValueKey('records-period-previous')));
      await tester.pumpAndSettle();
      expect(find.text(_monthTitle(previousMonth)), findsOneWidget);
      expect(_todayMarkedCells(), findsNothing);

      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('records-period-previous')));
      await tester.pumpAndSettle();
      expect(find.text(_weekTitle(previousWeekStart)), findsOneWidget);

      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      expect(find.text(_monthTitle(previousMonth)), findsOneWidget);

      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      expect(find.text(_weekTitle(previousWeekStart)), findsOneWidget);

      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('records-period-previous')));
      await tester.pumpAndSettle();
      expect(_todayMarkedCells(), findsNothing);
    },
  );

  testWidgets('slides previous periods from left and next periods from right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(RecordsPage(store: _MemoryWorkoutSessionStore(const []))),
    );
    await _pumpRecords(tester);

    await tester.tap(find.byKey(const ValueKey('records-period-previous')));
    await tester.pump();
    final previousContent = find.byKey(
      const ValueKey('records-period-content-month-history1'),
    );
    final previousStartX = tester.getTopLeft(previousContent).dx;
    await tester.pumpAndSettle();
    expect(previousStartX, lessThan(tester.getTopLeft(previousContent).dx));

    await tester.tap(find.byKey(const ValueKey('records-period-next')));
    await tester.pump();
    final currentContent = find.byKey(
      const ValueKey('records-period-content-month'),
    );
    final currentStartX = tester.getTopLeft(currentContent).dx;
    await tester.pumpAndSettle();
    expect(currentStartX, greaterThan(tester.getTopLeft(currentContent).dx));
  });

  testWidgets('keeps records content above the system bottom inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 80);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      _buildApp(RecordsPage(store: _MemoryWorkoutSessionStore(const []))),
    );
    await _pumpRecords(tester);

    expect(
      find.ancestor(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
  });

  testWidgets('records footer fits English at 320px with safe insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: _MemoryWorkoutSessionStore(const []),
          cloudSessionsFuture: Future.value(const []),
          pendingSyncCountFuture: Future.value(2),
        ),
        locale: const Locale('en'),
      ),
    );
    await _pumpRecords(tester);

    expect(
      find.byKey(const ValueKey('records-calendar-legend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('records-period-summary')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('merged cloud-only records contribute to monthly total', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = _MemoryWorkoutSessionStore([
      WorkoutSession(
        id: 'local',
        startedAt: DateTime(now.year, now.month, 4, 9),
        endedAt: DateTime(now.year, now.month, 4, 9, 3),
        count: 10,
      ),
    ]);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: store,
          cloudSessionsFuture: Future.value([
            WorkoutSession(
              id: 'cloud-only',
              startedAt: DateTime(now.year, now.month, 5, 9),
              endedAt: DateTime(now.year, now.month, 5, 9, 3),
              count: 20,
              syncStatus: WorkoutSyncStatus.synced,
            ),
          ]),
        ),
      ),
    );
    await _pumpRecords(tester);

    expect(find.text('30 个'), findsOneWidget);
  });

  testWidgets('shows only local records owned by the current account', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = _MemoryWorkoutSessionStore([
      _session(
        'user-a',
        DateTime(now.year, now.month, 4),
        10,
        ownerAppUserId: 'user-a',
      ),
      _session(
        'user-b',
        DateTime(now.year, now.month, 5),
        20,
        ownerAppUserId: 'user-b',
      ),
      _session('ownerless', DateTime(now.year, now.month, 6), 40),
    ]);

    await tester.pumpWidget(
      _buildApp(RecordsPage(store: store, ownerAppUserId: 'user-b')),
    );
    await _pumpRecords(tester);

    expect(find.text('20 个'), findsWidgets);
    expect(find.text('70 个'), findsNothing);
  });

  testWidgets('cloud failure keeps local monthly total visible', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = _MemoryWorkoutSessionStore([
      WorkoutSession(
        id: 'local',
        startedAt: DateTime(now.year, now.month, 4, 9),
        endedAt: DateTime(now.year, now.month, 4, 9, 3),
        count: 10,
      ),
    ]);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: store,
          cloudSessionsFuture: Future<List<WorkoutSession>>(
            () => throw Exception('cloud down'),
          ),
        ),
      ),
    );
    await _pumpRecords(tester);

    expect(find.text('10 个'), findsWidgets);
    expect(find.text('云端记录暂不可用，本地记录已显示'), findsOneWidget);
  });

  testWidgets('cloud localDate controls monthly bucket', (tester) async {
    final now = DateTime.now();
    final firstDayUtc = DateTime.utc(now.year, now.month, 1);
    final store = _MemoryWorkoutSessionStore(const []);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: store,
          cloudSessionsFuture: Future.value([
            WorkoutSession(
              id: 'cloud-month-edge',
              startedAt: firstDayUtc.subtract(const Duration(hours: 12)),
              endedAt: firstDayUtc.subtract(const Duration(hours: 11)),
              localDate: DateTime(now.year, now.month),
              count: 20,
              syncStatus: WorkoutSyncStatus.synced,
            ),
          ]),
        ),
      ),
    );
    await _pumpRecords(tester);

    expect(find.text('20 个'), findsWidgets);
  });

  testWidgets('shows pending sync count when provided', (tester) async {
    final store = _MemoryWorkoutSessionStore(const []);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(store: store, pendingSyncCountFuture: Future.value(2)),
      ),
    );
    await _pumpRecords(tester);

    expect(find.text('有 2 条记录待同步'), findsOneWidget);
  });

  testWidgets('places cloud status above the calendar legend', (tester) async {
    final store = _MemoryWorkoutSessionStore(const []);

    await tester.pumpWidget(
      _buildApp(
        RecordsPage(
          store: store,
          cloudSessionsFuture: Future.value(const []),
          pendingSyncCountFuture: Future.value(2),
        ),
      ),
    );
    await _pumpRecords(tester);

    final summary = find.byKey(const ValueKey('records-period-summary'));
    final legend = find.byKey(const ValueKey('records-calendar-legend'));
    final cloudStatus = find.text('云端记录已合并');
    final pendingStatus = find.text('有 2 条记录待同步');
    expect(find.descendant(of: summary, matching: cloudStatus), findsNothing);
    expect(find.descendant(of: summary, matching: pendingStatus), findsNothing);
    expect(
      tester.getBottomLeft(cloudStatus).dy,
      lessThan(tester.getTopLeft(legend).dy),
    );
    expect(
      tester.getBottomLeft(pendingStatus).dy,
      lessThan(tester.getTopLeft(legend).dy),
    );
  });
}

Future<void> _pumpRecords(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Widget _buildApp(
  Widget home, {
  Locale locale = const Locale('zh'),
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: appTheme(brightness: brightness),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

class _MemoryWorkoutSessionStore extends TestWorkoutSessionRepository {
  _MemoryWorkoutSessionStore(this.sessions);

  final List<WorkoutSession> sessions;

  @override
  Future<List<WorkoutSession>> load() async => sessions;
}

WorkoutSession _session(
  String id,
  DateTime startedAt,
  int count, {
  String? ownerAppUserId,
}) {
  return WorkoutSession(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 1)),
    count: count,
    ownerAppUserId: ownerAppUserId,
  );
}

IconButton _periodButton(WidgetTester tester, String key) {
  return tester.widget<IconButton>(find.byKey(ValueKey(key)));
}

String _monthTitle(DateTime date) => '${date.year}年${date.month}月';

String _weekTitle(DateTime start) {
  final end = start.add(const Duration(days: 6));
  return '${start.month}月${start.day}日–${end.month}月${end.day}日';
}

Finder _todayMarkedCells() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Container || widget.decoration is! BoxDecoration) {
      return false;
    }
    final key = widget.key;
    if (key is! ValueKey<String> ||
        !key.value.startsWith('records-day-cell-')) {
      return false;
    }
    final decoration = widget.decoration! as BoxDecoration;
    return decoration.borderRadius != null && decoration.border != null;
  });
}
