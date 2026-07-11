import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/pages/records_page.dart';

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
}

Future<void> _pumpRecords(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

Widget _buildApp(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

class _MemoryWorkoutSessionStore extends WorkoutSessionStore {
  _MemoryWorkoutSessionStore(this.sessions);

  final List<WorkoutSession> sessions;

  @override
  Future<List<WorkoutSession>> load() async => sessions;
}

WorkoutSession _session(String id, DateTime startedAt, int count) {
  return WorkoutSession(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 1)),
    count: count,
  );
}
