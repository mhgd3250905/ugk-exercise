import 'package:test/test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'dart:async';

void main() {
  test('load ignores signed out users', () async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: false,
      top: [],
      me: null,
    );
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    );
    var loadCalls = 0;
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, __) async {
        loadCalls++;
        return snapshot;
      },
      join: (_) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);
    expect(controller.snapshot, same(snapshot));

    session = null;

    await controller.load(LeaderboardPeriod.day);

    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
    expect(loadCalls, 1);
  });

  test('load stores snapshot for signed in users', () async {
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
      join: (_) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);

    expect(controller.snapshot?.period, LeaderboardPeriod.day);
  });

  test('join and leave pass session token for signed in users', () async {
    final tokens = <String>[];
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
      join: (token) async => tokens.add('join:$token'),
      leave: (token) async => tokens.add('leave:$token'),
    );

    await controller.join();
    await controller.leave();

    expect(tokens, ['join:session_1', 'leave:session_1']);
  });

  test('load stores error when request fails', () async {
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => throw StateError('load failed'),
      join: (_) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.week);

    expect(controller.error, contains('load failed'));
    expect(controller.busy, isFalse);
  });

  test('signed out load clears snapshot and skips request', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    );
    var notifications = 0;
    var loadCalls = 0;
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, __) async {
        loadCalls++;
        return const LeaderboardSnapshot(
          period: LeaderboardPeriod.day,
          exerciseType: 'pushup',
          isJoined: false,
          top: [],
          me: null,
        );
      },
      join: (_) async {},
      leave: (_) async {},
    );
    controller.addListener(() => notifications++);

    await controller.load(LeaderboardPeriod.day);
    expect(controller.snapshot?.period, LeaderboardPeriod.day);
    expect(notifications, 2);

    session = null;
    notifications = 0;

    await controller.load(LeaderboardPeriod.week);

    expect(loadCalls, 1);
    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
    expect(notifications, 1);
  });

  test('successful load clears previous error', () async {
    var shouldFail = true;
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async {
        if (shouldFail) {
          throw StateError('load failed');
        }
        return const LeaderboardSnapshot(
          period: LeaderboardPeriod.week,
          exerciseType: 'pushup',
          isJoined: false,
          top: [],
          me: null,
        );
      },
      join: (_) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);
    expect(controller.error, contains('load failed'));

    shouldFail = false;
    await controller.load(LeaderboardPeriod.week);

    expect(controller.snapshot?.period, LeaderboardPeriod.week);
    expect(controller.error, isNull);
  });

  test('failed load preserves previous snapshot', () async {
    var shouldFail = false;
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async {
        if (shouldFail) {
          throw StateError('load failed');
        }
        return const LeaderboardSnapshot(
          period: LeaderboardPeriod.day,
          exerciseType: 'pushup',
          isJoined: false,
          top: [],
          me: null,
        );
      },
      join: (_) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);
    shouldFail = true;
    await controller.load(LeaderboardPeriod.week);

    expect(controller.snapshot?.period, LeaderboardPeriod.day);
    expect(controller.error, contains('load failed'));
  });

  test('load discards result when session changes before request completes', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    );
    final completer = Completer<LeaderboardSnapshot>();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, __) => completer.future,
      join: (_) async {},
      leave: (_) async {},
    );

    final future = controller.load(LeaderboardPeriod.day);
    session = null;
    completer.complete(
      const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
    );

    await future;

    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
  });

  test('concurrent loads keep busy until latest request finishes', () async {
    final snapshots = {
      LeaderboardPeriod.day: const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
      LeaderboardPeriod.week: const LeaderboardSnapshot(
        period: LeaderboardPeriod.week,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      ),
    };
    final completers = {
      LeaderboardPeriod.day: Completer<LeaderboardSnapshot>(),
      LeaderboardPeriod.week: Completer<LeaderboardSnapshot>(),
    };
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, period) => completers[period]!.future,
      join: (_) async {},
      leave: (_) async {},
    );

    final loadDay = controller.load(LeaderboardPeriod.day);
    expect(controller.busy, isTrue);

    final loadWeek = controller.load(LeaderboardPeriod.week);
    expect(controller.busy, isTrue);

    completers[LeaderboardPeriod.day]!.complete(
      snapshots[LeaderboardPeriod.day]!,
    );
    await loadDay;

    expect(controller.busy, isTrue);
    expect(controller.snapshot, isNull);

    completers[LeaderboardPeriod.week]!.complete(
      snapshots[LeaderboardPeriod.week]!,
    );
    await loadWeek;

    expect(controller.busy, isFalse);
    expect(controller.snapshot, same(snapshots[LeaderboardPeriod.week]));
    expect(controller.error, isNull);
  });
}
