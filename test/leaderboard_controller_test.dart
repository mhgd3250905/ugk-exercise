import 'package:test/test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/leaderboard_home_rank_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/leaderboard_home_rank.dart';
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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
      joinIdentity: (token, _) async => tokens.add('join:$token'),
      updateIdentity: (_, __) async {},
      leave: (token) async => tokens.add('leave:$token'),
    );

    await controller.join(
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.anonymous),
    );
    await controller.leave();

    expect(tokens, ['join:session_1', 'leave:session_1']);
  });

  test(
    'join and identity update pass choices then refresh both periods',
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
          choices.add('join:$token:${choice.mode.name}');
        },
        updateIdentity: (token, choice) async {
          choices.add('update:$token:${choice.mode.name}');
        },
        leave: (_) async {},
      );
      const profile = LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.profile,
      );
      const anonymous = LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.anonymous,
      );

      await controller.load(LeaderboardPeriod.week);
      expect(await controller.join(profile), isTrue);
      expect(await controller.updateIdentity(anonymous), isTrue);

      expect(choices, ['join:session_1:profile', 'update:session_1:anonymous']);
      expect(periods, [
        LeaderboardPeriod.week,
        LeaderboardPeriod.day,
        LeaderboardPeriod.week,
        LeaderboardPeriod.day,
        LeaderboardPeriod.week,
      ]);
      expect(controller.snapshot?.period, LeaderboardPeriod.week);
      expect(controller.snapshotFor(LeaderboardPeriod.day), isNotNull);
      expect(controller.snapshotFor(LeaderboardPeriod.week), isNotNull);
    },
  );

  test('identity API errors map to stable codes', () async {
    const expectedCodes = {
      'invalid_identity_mode': LeaderboardErrorCode.invalidIdentityMode,
      'leaderboard_not_joined': LeaderboardErrorCode.notJoined,
      'premium_required': LeaderboardErrorCode.premiumRequired,
      'membership_sync_unavailable': 'leaderboard_membership_sync_unavailable',
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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
      joinIdentity: (_, __) async => throw const MembershipApiException(
        'HTTP 403',
        statusCode: 403,
        errorCode: 'premium_required',
      ),
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    await controller.join(
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.anonymous),
    );

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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    await controller.load(LeaderboardPeriod.day);
    shouldFail = true;
    await controller.load(LeaderboardPeriod.week);

    expect(controller.snapshot?.period, LeaderboardPeriod.day);
    expect(controller.error, LeaderboardErrorCode.unexpected);
  });

  test(
    'load discards result when session changes before request completes',
    () async {
      SavedAccountSession? session = const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      );
      final completer = Completer<LeaderboardSnapshot>();
      final controller = LeaderboardController(
        sessionProvider: () => session,
        load: (_, __) => completer.future,
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
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
    },
  );

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
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
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

  test(
    'reloadForCurrentAccount clears snapshot and error when signed out',
    () async {
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
        joinIdentity: (_, __) async => throw StateError('join failed'),
        updateIdentity: (_, __) async {},
        leave: (_) async {},
      );

      await controller.load(LeaderboardPeriod.day);
      await controller.join(
        const LeaderboardIdentityChoice(
          mode: LeaderboardIdentityMode.anonymous,
        ),
      );
      expect(controller.snapshot, isNotNull);
      expect(controller.error, LeaderboardErrorCode.unexpected);

      session = null;
      await controller.reloadForCurrentAccount();

      expect(controller.snapshot, isNull);
      expect(controller.error, isNull);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'reloadForCurrentAccount clears stale snapshot before the new load resolves',
    () async {
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
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
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
    },
  );

  test(
    'reloadForCurrentAccount keeps the snapshot for the same account until the '
    'new load resolves',
    () async {
      // Mirror of the account-switch guard above, but for the SAME account:
      // pull-to-refresh / re-entering profile / other account notifications
      // reload without changing appUserId. The card must keep showing the last
      // snapshot instead of clearing to a loading state every time.
      SavedAccountSession? session = const SavedAccountSession(
        sessionToken: 'session_A',
        appUserId: 'user_A',
      );
      const firstSnapshot = LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      );
      const secondSnapshot = LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: false,
        top: [],
        me: null,
      );
      final secondCompleter = Completer<LeaderboardSnapshot>();
      var loadCalls = 0;
      final controller = LeaderboardController(
        sessionProvider: () => session,
        load: (_, __) {
          loadCalls++;
          // First load resolves immediately with the joined snapshot; the
          // reload stays pending on the completer.
          return loadCalls == 1
              ? Future.value(firstSnapshot)
              : secondCompleter.future;
        },
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
        leave: (_) async {},
      );

      // Account A loaded.
      await controller.load(LeaderboardPeriod.day);
      expect(controller.snapshot, same(firstSnapshot));

      // Reload the SAME account; its load stays pending.
      final reloadFuture = controller.reloadForCurrentAccount();

      // BEFORE the new load resolves, the same-account snapshot must remain
      // (not cleared to null / loading).
      expect(controller.snapshot, same(firstSnapshot));
      expect(controller.busy, isTrue);

      // New data arrives -> snapshot updates to the fresh value.
      secondCompleter.complete(secondSnapshot);
      await reloadFuture;

      expect(controller.snapshot, same(secondSnapshot));
    },
  );

  test(
    'newer load makes pending join and identity update report false',
    () async {
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
    },
  );

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

  test('refreshAll loads and caches day and week in parallel', () async {
    final calls = <LeaderboardPeriod>[];
    final pending = {
      for (final period in LeaderboardPeriod.values)
        period: Completer<LeaderboardSnapshot>(),
    };
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, period) {
        calls.add(period);
        return pending[period]!.future;
      },
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    final refresh = controller.refreshAll();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [LeaderboardPeriod.day, LeaderboardPeriod.week]);
    for (final period in LeaderboardPeriod.values) {
      pending[period]!.complete(
        LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          top: const [],
          me: null,
        ),
      );
    }
    await refresh;

    expect(
      controller.snapshotFor(LeaderboardPeriod.day)?.period,
      LeaderboardPeriod.day,
    );
    expect(
      controller.snapshotFor(LeaderboardPeriod.week)?.period,
      LeaderboardPeriod.week,
    );
    controller.selectPeriod(LeaderboardPeriod.week);
    expect(controller.snapshot?.period, LeaderboardPeriod.week);
    expect(calls, hasLength(2));
  });

  test(
    'loadMore appends unique rows and advances the selected cursor',
    () async {
      final cursors = <String>[];
      final controller = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, period) async => LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          nextCursor: 'page-2',
          frozenTotalValue: 42,
          myExerciseCounts: const LeaderboardExerciseCounts(
            pushup: 8,
            narrowPushup: 6,
          ),
          top: const [
            LeaderboardRow(
              rank: 1,
              userId: 'u1',
              nickname: null,
              avatarKey: null,
              totalValue: 100,
            ),
          ],
          me: null,
        ),
        loadMore: (_, period, cursor) async {
          cursors.add(cursor);
          return LeaderboardSnapshot(
            period: period,
            exerciseType: 'pushup',
            isJoined: true,
            nextCursor: null,
            top: const [
              LeaderboardRow(
                rank: 1,
                userId: 'u1',
                nickname: null,
                avatarKey: null,
                totalValue: 100,
              ),
              LeaderboardRow(
                rank: 2,
                userId: 'u2',
                nickname: null,
                avatarKey: null,
                totalValue: 90,
              ),
            ],
            me: null,
          );
        },
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
        leave: (_) async {},
      );
      await controller.load(LeaderboardPeriod.day);

      expect(await controller.loadMore(LeaderboardPeriod.day), isTrue);

      expect(cursors, ['page-2']);
      expect(
        controller
            .snapshotFor(LeaderboardPeriod.day)!
            .top
            .map((row) => row.userId),
        ['u1', 'u2'],
      );
      expect(controller.snapshotFor(LeaderboardPeriod.day)?.nextCursor, isNull);
      expect(
        controller.snapshotFor(LeaderboardPeriod.day)?.frozenTotalValue,
        42,
      );
      expect(
        controller.snapshotFor(LeaderboardPeriod.day)?.myExerciseCounts?.pushup,
        8,
      );
      expect(
        controller
            .snapshotFor(LeaderboardPeriod.day)
            ?.myExerciseCounts
            ?.narrowPushup,
        6,
      );
    },
  );

  test(
    'loadMore failure preserves rows and exposes a retryable error',
    () async {
      final controller = LeaderboardController(
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        load: (_, period) async => LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          nextCursor: 'page-2',
          top: const [
            LeaderboardRow(
              rank: 1,
              userId: 'u1',
              nickname: null,
              avatarKey: null,
              totalValue: 100,
            ),
          ],
          me: null,
        ),
        loadMore: (_, __, ___) async => throw StateError('offline'),
        joinIdentity: (_, __) async {},
        updateIdentity: (_, __) async {},
        leave: (_) async {},
      );
      await controller.load(LeaderboardPeriod.day);

      expect(await controller.loadMore(LeaderboardPeriod.day), isFalse);

      expect(controller.snapshotFor(LeaderboardPeriod.day)?.top, hasLength(1));
      expect(
        controller.loadMoreErrorFor(LeaderboardPeriod.day),
        LeaderboardErrorCode.unexpected,
      );
      expect(controller.isLoadingMore(LeaderboardPeriod.day), isFalse);
    },
  );

  test('blocking a row preserves the current user frozen score', () async {
    final controller = LeaderboardController(
      sessionProvider: () =>
          const SavedAccountSession(sessionToken: 'session_1', appUserId: 'me'),
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: true,
        frozenTotalValue: 42,
        myExerciseCounts: const LeaderboardExerciseCounts(
          pushup: 8,
          narrowPushup: 6,
        ),
        top: const [
          LeaderboardRow(
            rank: 1,
            userId: 'other',
            nickname: null,
            avatarKey: null,
            totalValue: 10,
          ),
        ],
        me: null,
      ),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
      blockUser: (_, __) async {},
    );
    await controller.load(LeaderboardPeriod.day);

    expect(await controller.blockUser('other'), isTrue);
    expect(controller.snapshot?.top, isEmpty);
    expect(controller.snapshot?.frozenTotalValue, 42);
    expect(controller.snapshot?.myExerciseCounts?.pushup, 8);
    expect(controller.snapshot?.myExerciseCounts?.narrowPushup, 6);
  });

  test(
    'blocked users load and unblock update their own retryable state',
    () async {
      var attempts = 0;
      final unblocked = <String>[];
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
        updateIdentity: (_, __) async {},
        leave: (_) async {},
        loadBlockedUsers: (_) async {
          attempts += 1;
          if (attempts == 1) {
            throw const MembershipApiException('offline');
          }
          return const [
            BlockedUser(
              userId: 'blocked-user',
              nickname: 'Blocked',
              avatarKey: 'ring-lime',
              avatarUrl: null,
            ),
          ];
        },
        unblockUser: (token, userId) async => unblocked.add('$token:$userId'),
      );

      await controller.loadBlockedUsers();
      expect(controller.blockedUsersError, LeaderboardErrorCode.requestFailed);
      expect(controller.blockedUsers, isEmpty);

      await controller.loadBlockedUsers();
      expect(controller.blockedUsers.single.userId, 'blocked-user');
      expect(controller.blockedUsersError, isNull);
      expect(await controller.unblockUser('blocked-user'), isTrue);
      expect(controller.blockedUsers, isEmpty);
      expect(unblocked, ['session_1:blocked-user']);
    },
  );

  test(
    'blocked users from an old account are discarded after account switch',
    () async {
      SavedAccountSession? session = const SavedAccountSession(
        sessionToken: 'session_A',
        appUserId: 'user_A',
      );
      final pending = Completer<List<BlockedUser>>();
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
        updateIdentity: (_, __) async {},
        leave: (_) async {},
        loadBlockedUsers: (_) => pending.future,
        unblockUser: (_, __) async {},
      );

      final oldLoad = controller.loadBlockedUsers();
      session = const SavedAccountSession(
        sessionToken: 'session_B',
        appUserId: 'user_B',
      );
      await controller.reloadForCurrentAccount();
      pending.complete(const [
        BlockedUser(
          userId: 'private_A',
          nickname: 'A only',
          avatarKey: null,
          avatarUrl: null,
        ),
      ]);
      await oldLoad;

      expect(controller.blockedUsers, isEmpty);
      expect(controller.blockedUsersError, isNull);
      expect(controller.blockedUsersBusy, isFalse);
    },
  );

  test(
    'restores only the current account home rank without a leaderboard snapshot',
    () async {
      final store = MemoryLeaderboardHomeRankStore();
      const cachedRank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      await store.save(cachedRank);
      final controller = _homeRankController(
        homeRankStore: store,
        load: (_, __) async => throw UnimplementedError(),
      );

      await controller.restoreHomeRankForCurrentAccount();

      expect(controller.homeRankFor(LeaderboardPeriod.day), cachedRank);
      expect(controller.snapshot, isNull);
    },
  );

  test('home rank hydration cannot publish after an account switch', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    final store = _DelayedHomeRankStore();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      homeRankStore: store,
      clock: _homeRankClock,
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: false,
        top: const [],
        me: null,
      ),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    final restore = controller.restoreHomeRankForCurrentAccount();
    session = const SavedAccountSession(
      sessionToken: 'session_B',
      appUserId: 'user_B',
    );
    await controller.reloadForCurrentAccount();
    store.result.complete(
      const LeaderboardHomeRank(
        ownerAppUserId: 'user_A',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      ),
    );
    await restore;

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
  });

  test(
    'same-account reload does not cancel in-flight home rank hydration',
    () async {
      final store = _DelayedHomeRankStore();
      final pendingLoad = Completer<LeaderboardSnapshot>();
      final controller = _homeRankController(
        homeRankStore: store,
        load: (_, __) => pendingLoad.future,
      );

      final restore = controller.restoreHomeRankForCurrentAccount();
      final reload = controller.reloadForCurrentAccount();
      store.result.complete(
        const LeaderboardHomeRank(
          ownerAppUserId: 'user_1',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
          rank: 2,
          totalValue: 14,
        ),
      );

      await restore;

      expect(controller.homeRankFor(LeaderboardPeriod.day)?.rank, 2);

      pendingLoad.complete(_joinedDaySnapshot(rank: 3, totalValue: 21));
      await reload;
    },
  );

  test(
    'day refresh keeps cached rank then replaces its points from Worker',
    () async {
      final pending = Completer<LeaderboardSnapshot>();
      final store = MemoryLeaderboardHomeRankStore();
      const cachedRank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      await store.save(cachedRank);
      final controller = _homeRankController(
        homeRankStore: store,
        load: (_, __) => pending.future,
      );
      await controller.restoreHomeRankForCurrentAccount();

      final reload = controller.reloadForCurrentAccount();

      expect(controller.homeRankFor(LeaderboardPeriod.day), cachedRank);
      expect(controller.isLoading(LeaderboardPeriod.day), isTrue);
      pending.complete(_joinedDaySnapshot(rank: 3, totalValue: 21));
      await reload;

      const refreshedRank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 3,
        totalValue: 21,
      );
      expect(controller.homeRankFor(LeaderboardPeriod.day), refreshedRank);
      expect(controller.isLoading(LeaderboardPeriod.day), isFalse);
      await _flushHomeRankMutations();
      expect(
        await store.load(
          appUserId: 'user_1',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
        ),
        refreshedRank,
      );
    },
  );

  test('authoritative no-rank response clears cached home rank', () async {
    final store = MemoryLeaderboardHomeRankStore();
    const cachedRank = LeaderboardHomeRank(
      ownerAppUserId: 'user_1',
      period: LeaderboardPeriod.day,
      periodScope: '2026-07-20',
      rank: 2,
      totalValue: 14,
    );
    await store.save(cachedRank);
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: false,
        top: const [],
        me: null,
      ),
    );
    await controller.restoreHomeRankForCurrentAccount();

    await controller.load(LeaderboardPeriod.day);

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
    await _flushHomeRankMutations();
    expect(
      await store.load(
        appUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
      ),
      isNull,
    );
  });

  test('failed day refresh preserves cached home rank', () async {
    final store = MemoryLeaderboardHomeRankStore();
    const cachedRank = LeaderboardHomeRank(
      ownerAppUserId: 'user_1',
      period: LeaderboardPeriod.day,
      periodScope: '2026-07-20',
      rank: 2,
      totalValue: 14,
    );
    await store.save(cachedRank);
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, __) async => throw StateError('network unavailable'),
    );
    await controller.restoreHomeRankForCurrentAccount();

    await controller.load(LeaderboardPeriod.day);

    expect(controller.homeRankFor(LeaderboardPeriod.day), cachedRank);
    expect(controller.isLoading(LeaderboardPeriod.day), isFalse);
  });

  test('authoritative membership errors clear cached home rank', () async {
    for (final errorCode in ['premium_required', 'leaderboard_not_joined']) {
      final store = MemoryLeaderboardHomeRankStore();
      const cachedRank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      await store.save(cachedRank);
      final controller = _homeRankController(
        homeRankStore: store,
        load: (_, __) async => throw MembershipApiException(
          'HTTP 403',
          statusCode: 403,
          errorCode: errorCode,
        ),
      );
      await controller.restoreHomeRankForCurrentAccount();

      await controller.load(LeaderboardPeriod.day);

      expect(
        controller.homeRankFor(LeaderboardPeriod.day),
        isNull,
        reason: errorCode,
      );
    }
  });

  test('refreshAll membership error clears cached home rank', () async {
    final store = MemoryLeaderboardHomeRankStore();
    const cachedRank = LeaderboardHomeRank(
      ownerAppUserId: 'user_1',
      period: LeaderboardPeriod.day,
      periodScope: '2026-07-20',
      rank: 2,
      totalValue: 14,
    );
    await store.save(cachedRank);
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, period) async {
        if (period == LeaderboardPeriod.day) {
          throw const MembershipApiException(
            'HTTP 403',
            statusCode: 403,
            errorCode: 'premium_required',
          );
        }
        return _joinedSnapshot(period: period, rank: 3, totalValue: 21);
      },
    );
    await controller.restoreHomeRankForCurrentAccount();

    await controller.refreshAll();

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
  });

  test('identity refresh membership error clears cached home rank', () async {
    final store = MemoryLeaderboardHomeRankStore();
    const cachedRank = LeaderboardHomeRank(
      ownerAppUserId: 'user_1',
      period: LeaderboardPeriod.day,
      periodScope: '2026-07-20',
      rank: 2,
      totalValue: 14,
    );
    await store.save(cachedRank);
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      homeRankStore: store,
      clock: _homeRankClock,
      load: (_, __) async => throw const MembershipApiException(
        'HTTP 403',
        statusCode: 403,
        errorCode: 'leaderboard_not_joined',
      ),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );
    await controller.restoreHomeRankForCurrentAccount();

    expect(
      await controller.join(
        const LeaderboardIdentityChoice(
          mode: LeaderboardIdentityMode.anonymous,
        ),
      ),
      isFalse,
    );

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
  });

  test('old-account load cannot keep current account day loading', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    final oldAccountLoad = Completer<LeaderboardSnapshot>();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      load: (sessionToken, period) {
        if (sessionToken == 'session_A') return oldAccountLoad.future;
        return Future.value(
          LeaderboardSnapshot(
            period: period,
            exerciseType: 'pushup',
            isJoined: false,
            top: const [],
            me: null,
          ),
        );
      },
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    final oldLoad = controller.load(LeaderboardPeriod.day);
    expect(controller.isLoading(LeaderboardPeriod.day), isTrue);

    session = const SavedAccountSession(
      sessionToken: 'session_B',
      appUserId: 'user_B',
    );
    await controller.reloadForCurrentAccount();

    expect(controller.isLoading(LeaderboardPeriod.day), isFalse);

    oldAccountLoad.complete(_joinedDaySnapshot(rank: 2, totalValue: 14));
    await oldLoad;
  });

  test('authoritative rank does not wait for home rank save', () async {
    final store = _QueuedHomeRankStore();
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, __) async => _joinedDaySnapshot(rank: 3, totalValue: 21),
    );

    final load = controller.load(LeaderboardPeriod.day);
    await store.saveStarted.future;
    await Future<void>.delayed(Duration.zero);

    expect(controller.snapshotFor(LeaderboardPeriod.day)?.me?.totalValue, 21);
    expect(controller.isLoading(LeaderboardPeriod.day), isFalse);

    store.saveGate.complete();
    await load;
  });

  test('authoritative no-rank does not wait for home rank clear', () async {
    final store = _DelayedClearHomeRankStore(
      const LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      ),
    );
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: false,
        top: const [],
        me: null,
      ),
    );
    await controller.restoreHomeRankForCurrentAccount();

    final load = controller.load(LeaderboardPeriod.day);
    await store.clearStarted.future;
    await Future<void>.delayed(Duration.zero);

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
    expect(controller.isLoading(LeaderboardPeriod.day), isFalse);

    store.clearGate.complete();
    await load;
  });

  test('successful leave clears home rank before a later refresh', () async {
    final store = MemoryLeaderboardHomeRankStore();
    const cachedRank = LeaderboardHomeRank(
      ownerAppUserId: 'user_1',
      period: LeaderboardPeriod.day,
      periodScope: '2026-07-20',
      rank: 2,
      totalValue: 14,
    );
    await store.save(cachedRank);
    final controller = _homeRankController(
      homeRankStore: store,
      load: (_, __) async => throw UnimplementedError(),
    );
    await controller.restoreHomeRankForCurrentAccount();

    expect(await controller.leave(), isTrue);

    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
    await _flushHomeRankMutations();
    expect(
      await store.load(
        appUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
      ),
      isNull,
    );
  });

  test('queued old-account cache save cannot survive sign out clear', () async {
    SavedAccountSession? session = const SavedAccountSession(
      sessionToken: 'session_A',
      appUserId: 'user_A',
    );
    final store = _QueuedHomeRankStore();
    final controller = LeaderboardController(
      sessionProvider: () => session,
      homeRankStore: store,
      clock: _homeRankClock,
      load: (_, __) async => _joinedDaySnapshot(rank: 2, totalValue: 14),
      joinIdentity: (_, __) async {},
      updateIdentity: (_, __) async {},
      leave: (_) async {},
    );

    final load = controller.load(LeaderboardPeriod.day);
    await store.saveStarted.future;
    session = null;
    await controller.reloadForCurrentAccount();
    store.saveGate.complete();
    await load;
    await store.clearCompleted.future;

    expect(store.persisted, isNull);
    expect(controller.homeRankFor(LeaderboardPeriod.day), isNull);
  });

  for (final period in LeaderboardPeriod.values) {
    test(
      'home rank expires when ${period.name} Shanghai scope changes',
      () async {
        var now = DateTime.utc(2026, 7, 19, 16);
        final controller = _homeRankController(
          homeRankStore: MemoryLeaderboardHomeRankStore(),
          clock: () => now,
          load: (_, requestedPeriod) async =>
              _joinedSnapshot(period: requestedPeriod, rank: 2, totalValue: 14),
        );
        await controller.load(period);

        expect(controller.homeRankFor(period)?.rank, 2);

        now = now.add(Duration(days: period == LeaderboardPeriod.day ? 1 : 7));

        expect(controller.homeRankFor(period), isNull);
      },
    );

    test(
      'cross-boundary ${period.name} response does not become current home rank',
      () async {
        var now = DateTime.utc(2026, 7, 19, 15, 59, 59);
        final pending = Completer<LeaderboardSnapshot>();
        final controller = _homeRankController(
          homeRankStore: MemoryLeaderboardHomeRankStore(),
          clock: () => now,
          load: (_, __) => pending.future,
        );

        final load = controller.load(period);
        now = DateTime.utc(2026, 7, 19, 16);
        pending.complete(
          _joinedSnapshot(period: period, rank: 2, totalValue: 14),
        );
        await load;

        expect(controller.homeRankFor(period), isNull);
      },
    );
  }
}

DateTime _homeRankClock() => DateTime.utc(2026, 7, 19, 16);

Future<void> _flushHomeRankMutations() => Future<void>.delayed(Duration.zero);

LeaderboardController _homeRankController({
  required LeaderboardLoad load,
  required LeaderboardHomeRankStore homeRankStore,
  LeaderboardClock? clock,
}) {
  return LeaderboardController(
    sessionProvider: () => const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    ),
    homeRankStore: homeRankStore,
    clock: clock ?? _homeRankClock,
    load: load,
    joinIdentity: (_, __) async {},
    updateIdentity: (_, __) async {},
    leave: (_) async {},
  );
}

LeaderboardSnapshot _joinedDaySnapshot({
  required int rank,
  required int totalValue,
}) => _joinedSnapshot(
  period: LeaderboardPeriod.day,
  rank: rank,
  totalValue: totalValue,
);

LeaderboardSnapshot _joinedSnapshot({
  required LeaderboardPeriod period,
  required int rank,
  required int totalValue,
}) {
  return LeaderboardSnapshot(
    period: period,
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

class _DelayedHomeRankStore implements LeaderboardHomeRankStore {
  final result = Completer<LeaderboardHomeRank?>();

  @override
  Future<void> clearForAccount(String appUserId) async {}

  @override
  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  }) async {}

  @override
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  }) => result.future;

  @override
  Future<void> save(LeaderboardHomeRank rank) async {}
}

class _QueuedHomeRankStore implements LeaderboardHomeRankStore {
  final saveStarted = Completer<void>();
  final saveGate = Completer<void>();
  final clearCompleted = Completer<void>();
  LeaderboardHomeRank? persisted;

  @override
  Future<void> clearForAccount(String appUserId) async {
    if (persisted?.ownerAppUserId == appUserId) {
      persisted = null;
    }
    if (!clearCompleted.isCompleted) clearCompleted.complete();
  }

  @override
  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  }) async {
    if (persisted?.ownerAppUserId == appUserId && persisted?.period == period) {
      persisted = null;
    }
  }

  @override
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  }) async => null;

  @override
  Future<void> save(LeaderboardHomeRank rank) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate.future;
    persisted = rank;
  }
}

class _DelayedClearHomeRankStore implements LeaderboardHomeRankStore {
  _DelayedClearHomeRankStore(this.persisted);

  final clearStarted = Completer<void>();
  final clearGate = Completer<void>();
  LeaderboardHomeRank? persisted;

  @override
  Future<void> clearForAccount(String appUserId) async {
    if (persisted?.ownerAppUserId == appUserId) {
      persisted = null;
    }
  }

  @override
  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  }) async {
    if (!clearStarted.isCompleted) clearStarted.complete();
    await clearGate.future;
    if (persisted?.ownerAppUserId == appUserId && persisted?.period == period) {
      persisted = null;
    }
  }

  @override
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  }) async {
    final rank = persisted;
    return rank?.ownerAppUserId == appUserId &&
            rank?.period == period &&
            rank?.periodScope == periodScope
        ? rank
        : null;
  }

  @override
  Future<void> save(LeaderboardHomeRank rank) async {
    persisted = rank;
  }
}
