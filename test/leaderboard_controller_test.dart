import 'package:test/test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
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

  test(
    'join and identity update pass choices then refresh current period',
    () async {
      final periods = <LeaderboardPeriod>[];
      final choices = <String>[];
      final controller = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, period) async {
          periods.add(period);
          return LeaderboardSnapshot(
            period: period,
            exerciseType: 'pushup',
            isJoined: true,
            top: const [],
            me: null,
          );
        },
        joinIdentity: (token, choice) async {
          choices.add('join:$token:${choice.mode.name}:${choice.nickname}');
        },
        updateIdentity: (token, choice) async {
          choices.add('update:$token:${choice.mode.name}:${choice.avatarKey}');
        },
        leave: (_) async {},
      );
      const custom = LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.custom,
        nickname: '训练者 01',
        avatarKey: 'ring-green',
      );
      const anonymous = LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.anonymous,
      );

      await controller.load(LeaderboardPeriod.week);
      expect(await controller.join(custom), isTrue);
      expect(await controller.updateIdentity(anonymous), isTrue);

      expect(choices, [
        'join:session_1:custom:训练者 01',
        'update:session_1:anonymous:null',
      ]);
      expect(periods, [
        LeaderboardPeriod.week,
        LeaderboardPeriod.week,
        LeaderboardPeriod.week,
      ]);
      expect(controller.snapshot?.period, LeaderboardPeriod.week);
    },
  );

  test('identity API errors map to stable codes', () async {
    const expectedCodes = {
      'nickname_taken': LeaderboardErrorCode.nicknameTaken,
      'invalid_nickname': LeaderboardErrorCode.invalidNickname,
      'invalid_avatar_key': LeaderboardErrorCode.invalidAvatarKey,
      'invalid_identity_mode': LeaderboardErrorCode.invalidIdentityMode,
      'leaderboard_not_joined': LeaderboardErrorCode.notJoined,
      'premium_required': LeaderboardErrorCode.premiumRequired,
      'invalid_json': LeaderboardErrorCode.requestFailed,
    };

    for (final entry in expectedCodes.entries) {
      final controller = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, period) async => LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          top: const [],
          me: null,
        ),
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async => throw MembershipApiException(
          'raw server detail must stay hidden',
          errorCode: entry.key,
        ),
        leave: (_) async {},
      );

      await controller.updateIdentity(
        const LeaderboardIdentityChoice(
          mode: LeaderboardIdentityMode.anonymous,
        ),
      );

      expect(controller.error, entry.value, reason: entry.key);
      expect(controller.error, isNot(contains('raw server detail')));
    }
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

    expect(controller.error, LeaderboardErrorCode.unexpected);
    expect(controller.busy, isFalse);
  });

  test('join preserves premium-required error from API', () async {
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => throw UnimplementedError(),
      join: (_) async => throw const MembershipApiException(
        'HTTP 403',
        statusCode: 403,
        errorCode: 'premium_required',
      ),
      leave: (_) async {},
    );

    await controller.join();

    expect(controller.error, 'leaderboard_premium_required');
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
    expect(controller.error, LeaderboardErrorCode.unexpected);

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
    expect(controller.error, LeaderboardErrorCode.unexpected);
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

  test('reloadForCurrentAccount clears snapshot and error when signed out', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    );
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      ),
      join: (_) async => throw StateError('join failed'),
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);
    await controller.join();
    expect(controller.snapshot, isNotNull);
    expect(controller.error, LeaderboardErrorCode.unexpected);

    session = null;
    await controller.reloadForCurrentAccount();

    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
  });

  test('reloadForCurrentAccount clears stale snapshot before the new load resolves', () async {
    // C1 RED: when the account switches A->B (session non-null but different
    // identity), the A snapshot must be cleared IMMEDIATELY, before B's load
    // resolves. The bug: reload awaits load() without clearing _snapshot first,
    // so account A's snapshot stays visible during B's load.
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    const aSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [],
      me: null,
    );
    final bCompleter = Completer<LeaderboardSnapshot>();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, __) {
        if (session?.appUserId == 'user_A') {
          return Future.value(aSnapshot);
        }
        return bCompleter.future;
      },
      join: (_) async {},
      leave: (_) async {},
    );

    // Account A loaded.
    await controller.load(LeaderboardPeriod.day);
    expect(controller.snapshot, same(aSnapshot));

    // Switch to account B; B's load is pending.
    session = const SavedAccountSession(
      sessionToken: 'session_B',
      appUserId: 'user_B',
    );
    final reloadFuture = controller.reloadForCurrentAccount();

    // BEFORE B resolves, the stale A snapshot must already be gone.
    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);

    // B resolves -> only B's snapshot appears.
    const bSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: false,
      top: [],
      me: null,
    );
    bCompleter.complete(bSnapshot);
    await reloadFuture;

    expect(controller.snapshot, same(bSnapshot));
  });

  test('newer load makes pending join and identity update report false', () async {
    for (final commandName in ['join', 'update']) {
      final commandStarted = Completer<void>();
      final commandResult = Completer<void>();
      final newerLoadResult = Completer<LeaderboardSnapshot>();
      final loadPeriods = <LeaderboardPeriod>[];
      final controller = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, period) {
          loadPeriods.add(period);
          return newerLoadResult.future;
        },
        joinIdentity: (_, __) {
          if (commandName == 'join') {
            commandStarted.complete();
            return commandResult.future;
          }
          return Future.value();
        },
        updateIdentity: (_, __) {
          if (commandName == 'update') {
            commandStarted.complete();
            return commandResult.future;
          }
          return Future.value();
        },
        leave: (_) async {},
      );
      const choice = LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.anonymous,
      );

      final mutation = commandName == 'join'
          ? controller.join(choice)
          : controller.updateIdentity(choice);
      await commandStarted.future;
      final newerLoad = controller.load(LeaderboardPeriod.week);
      commandResult.complete();

      expect(await mutation, isFalse, reason: commandName);
      expect(controller.snapshot, isNull, reason: commandName);
      expect(controller.busy, isTrue, reason: commandName);
      expect(loadPeriods, [LeaderboardPeriod.week], reason: commandName);

      const snapshot = LeaderboardSnapshot(
        period: LeaderboardPeriod.week,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      );
      newerLoadResult.complete(snapshot);
      await newerLoad;
      expect(controller.snapshot, same(snapshot), reason: commandName);
    }
  });

  test('stale join cannot refresh or overwrite a switched account', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    final joinStarted = Completer<void>();
    final joinResult = Completer<void>();
    final bLoad = Completer<LeaderboardSnapshot>();
    const aSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: false,
      top: [],
      me: null,
    );
    const bSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [],
      me: null,
    );
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (token, _) =>
          token == 'session_A' ? Future.value(aSnapshot) : bLoad.future,
      joinIdentity: (_, __) {
        joinStarted.complete();
        return joinResult.future;
      },
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );
    await controller.load(LeaderboardPeriod.day);

    final oldJoin = controller.join(
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.profile),
    );
    await joinStarted.future;
    session = const SavedAccountSession(
      sessionToken: 'session_B',
      appUserId: 'user_B',
    );
    final reload = controller.reloadForCurrentAccount();

    joinResult.complete();
    await oldJoin;

    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isTrue);

    bLoad.complete(bSnapshot);
    await reload;
    expect(controller.snapshot, same(bSnapshot));
    expect(controller.busy, isFalse);
  });

  test('stale identity update cannot restore state after sign out', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    final updateStarted = Completer<void>();
    final updateResult = Completer<void>();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: true,
        top: const [],
        me: null,
      ),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) {
        updateStarted.complete();
        return updateResult.future;
      },
      leave: (_) async {},
    );
    await controller.load(LeaderboardPeriod.day);

    final oldUpdate = controller.updateIdentity(
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.anonymous),
    );
    await updateStarted.future;
    session = null;
    await controller.reloadForCurrentAccount();
    updateResult.completeError(StateError('stale failure'));
    await oldUpdate;

    expect(controller.snapshot, isNull);
    expect(controller.error, isNull);
    expect(controller.busy, isFalse);
  });
}
