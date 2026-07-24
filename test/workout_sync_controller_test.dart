import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:test/test.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/workout_session_store.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';

const _accountA = SavedAccountSession(
  sessionToken: 'token-a',
  appUserId: 'user-a',
);
const _accountB = SavedAccountSession(
  sessionToken: 'token-b',
  appUserId: 'user-b',
);

void main() {
  late Directory tempDir;
  late WorkoutSessionStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ugk_sync_test_');
    store = WorkoutSessionStore(baseDir: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('free workout keeps its owner and remains localOnly', () async {
    await store.append(_session('free', owner: 'user-a'));
    var networkCalls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => false,
      syncBatch: (account, workouts) async {
        networkCalls++;
        return const [];
      },
    );

    await controller.queueAfterLocalSave('free');

    final saved = (await store.load()).single;
    expect(saved.ownerAppUserId, 'user-a');
    expect(saved.syncStatus, WorkoutSyncStatus.localOnly);
    expect(networkCalls, 0);
  });

  test(
    'premium workout is queued and starts sync without waiting for network',
    () async {
      await store.append(_session('premium', owner: 'user-a'));
      final networkResult = Completer<List<WorkoutSyncResult>>();
      final syncStarted = Completer<void>();
      var networkCalls = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) {
          networkCalls++;
          syncStarted.complete();
          return networkResult.future;
        },
      );

      await controller.queueAfterLocalSave('premium');
      await syncStarted.future;

      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);
      expect(networkCalls, 1);
      networkResult.complete([_accepted('premium')]);
      await controller.syncPending();
      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.synced);
    },
  );

  test(
    'queueAfterLocalSave ignores a workout owned by another account',
    () async {
      await store.append(_session('owned-b', owner: 'user-b'));
      var networkCalls = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async {
          networkCalls++;
          return const [];
        },
      );

      await controller.queueAfterLocalSave('owned-b');
      await controller.syncPending();

      final saved = (await store.load()).single;
      expect(saved.ownerAppUserId, 'user-b');
      expect(saved.syncStatus, WorkoutSyncStatus.localOnly);
      expect(networkCalls, 0);
    },
  );

  test('zero-count workout stays localOnly and is never uploaded', () async {
    await store.append(_session('zero', owner: 'user-a', count: 0));
    var networkCalls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        networkCalls++;
        return const [];
      },
    );

    await controller.queueAfterLocalSave('zero');
    await controller.syncForCurrentAccount();

    final saved = (await store.load()).single;
    expect(saved.syncStatus, WorkoutSyncStatus.localOnly);
    expect(await store.pendingCloudSyncForOwner('user-a'), isEmpty);
    expect(networkCalls, 0);
  });

  test('account B uploads only B pending workouts', () async {
    await store.append(
      _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    await store.append(
      _session('b', owner: 'user-b', status: WorkoutSyncStatus.pending),
    );
    SavedAccountSession? uploadedAccount;
    List<WorkoutSyncRequest>? uploaded;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountB,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        uploadedAccount = account;
        uploaded = workouts;
        return [_accepted('b')];
      },
    );

    await controller.syncPending();

    expect(uploadedAccount, _accountB);
    expect(uploaded!.map((item) => item.clientSessionId), ['b']);
    final saved = await _byId(store);
    expect(saved['a']!.syncStatus, WorkoutSyncStatus.pending);
    expect(saved['b']!.syncStatus, WorkoutSyncStatus.synced);
  });

  test(
    'switching account after network starts prevents stale A writes',
    () async {
      await store.append(
        _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      final state = _SessionState(_accountA);
      final started = Completer<void>();
      final result = Completer<List<WorkoutSyncResult>>();
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: state.read,
        premiumProvider: () => true,
        syncBatch: (account, workouts) {
          started.complete();
          return result.future;
        },
      );

      final sync = controller.syncPending();
      await started.future;
      state.current = _accountB;
      result.complete([_accepted('a')]);
      await sync;

      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);
    },
  );

  test('unknown server result id does not change any local workout', () async {
    await store.append(
      _session('sent', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    await store.append(_session('unknown', owner: 'user-a'));
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async => [_accepted('unknown')],
    );

    await controller.syncPending();

    final saved = await _byId(store);
    expect(saved['sent']!.syncStatus, WorkoutSyncStatus.pending);
    expect(saved['unknown']!.syncStatus, WorkoutSyncStatus.localOnly);
  });

  test('simultaneous sync calls share one network request', () async {
    await store.append(
      _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    final started = Completer<void>();
    final result = Completer<List<WorkoutSyncResult>>();
    var calls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) {
        calls++;
        started.complete();
        return result.future;
      },
    );

    final first = controller.syncPending();
    await started.future;
    final second = controller.syncPending();
    result.complete([_accepted('a')]);
    await Future.wait([first, second]);

    expect(calls, 1);
  });

  test('request during A sync drains B after account switch', () async {
    await store.append(
      _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    await store.append(
      _session('b', owner: 'user-b', status: WorkoutSyncStatus.pending),
    );
    final state = _SessionState(_accountA);
    final aStarted = Completer<void>();
    final aResult = Completer<List<WorkoutSyncResult>>();
    final uploadedOwners = <String>[];
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: state.read,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        uploadedOwners.add(account.appUserId);
        if (account.appUserId == 'user-a') {
          aStarted.complete();
          return aResult.future;
        }
        return [_accepted('b')];
      },
    );

    final first = controller.syncPending();
    await aStarted.future;
    state.current = _accountB;
    final second = controller.syncPending();
    aResult.complete([_accepted('a')]);
    await Future.wait([first, second]);

    expect(uploadedOwners, ['user-a', 'user-b']);
    final saved = await _byId(store);
    expect(saved['a']!.syncStatus, WorkoutSyncStatus.pending);
    expect(saved['b']!.syncStatus, WorkoutSyncStatus.synced);
  });

  test('network failure is swallowed and a later trigger retries', () async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);
    await store.append(
      _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    var calls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        calls++;
        if (calls == 1) {
          throw StateError('network down');
        }
        return [_accepted('a')];
      },
    );

    await expectLater(controller.syncPending(), completes);
    expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);
    await controller.syncPending();

    expect(calls, 2);
    expect((await store.load()).single.syncStatus, WorkoutSyncStatus.synced);
    expect(logs, contains('UGK sync: failed pending=1 type=StateError'));
    expect(logs.join('\n'), isNot(contains('network down')));
  });

  test('premium account automatically queues only its owned history', () async {
    await store.append(_session('a-local', owner: 'user-a'));
    await store.append(_session('b-local', owner: 'user-b'));
    await store.append(_session('legacy'));
    List<String>? uploaded;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        uploaded = workouts.map((item) => item.clientSessionId).toList();
        return [_accepted('a-local')];
      },
    );

    await controller.syncForCurrentAccount();

    expect(uploaded, ['a-local']);
    final saved = await _byId(store);
    expect(saved['a-local']!.syncStatus, WorkoutSyncStatus.synced);
    expect(saved['b-local']!.syncStatus, WorkoutSyncStatus.localOnly);
    expect(saved['legacy']!.ownerAppUserId, isNull);
    expect(saved['legacy']!.syncStatus, WorkoutSyncStatus.localOnly);
  });

  test(
    'legacy claim is rejected when current account differs from expected owner',
    () async {
      await store.append(_session('legacy'));
      final state = _SessionState(_accountA);
      var networkCalls = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: state.read,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async {
          networkCalls++;
          return const [];
        },
      );
      final expectedOwnerAppUserId = state.current!.appUserId;
      state.current = _accountB;

      final claimed = await controller.claimLegacyForOwner(
        expectedOwnerAppUserId,
      );

      expect(claimed, 0);
      expect((await store.load()).single.ownerAppUserId, isNull);
      expect(networkCalls, 0);
    },
  );

  // The sync controller is the only client action that changes cloud-derived
  // points/rank (workouts/sync accepted). It must notify listeners when a real
  // pending -> synced transition happens so the leaderboard can reload its
  // snapshot. The contract: never notify on empty sync, network failure, or
  // when the account has already switched away.
  group('cloud-derived data notification', () {
    test('accepted sync notifies listeners once', () async {
      await store.append(
        _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      var notifications = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async => [_accepted('a')],
      )..addListener(() => notifications++);

      await controller.syncPending();

      expect(notifications, 1);
      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.synced);
    });

    // End-to-end coverage of the real product entry point: workout_page
    // _onStopPressed -> queueAfterLocalSave. queueAfterLocalSave unawaited-
    // chains into syncPending, so awaiting the returned future drains the
    // network and must surface exactly one notification.
    test('queueAfterLocalSave notifies listeners once accepted', () async {
      await store.append(
        _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      var notifications = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async => [_accepted('a')],
      )..addListener(() => notifications++);

      await controller.queueAfterLocalSave('a');
      await controller.syncPending();

      expect(notifications, 1);
      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.synced);
    });

    test(
      'duplicate result still notifies (client caught up to cloud)',
      () async {
        await store.append(
          _session('dup', owner: 'user-a', status: WorkoutSyncStatus.pending),
        );
        var notifications = 0;
        final controller = WorkoutSyncController(
          store: store,
          sessionProvider: () => _accountA,
          premiumProvider: () => true,
          syncBatch: (account, workouts) async => [
            const WorkoutSyncResult(
              clientSessionId: 'dup',
              status: WorkoutSyncResultStatus.duplicate,
              aggregated: false,
            ),
          ],
        )..addListener(() => notifications++);

        await controller.syncPending();

        expect(notifications, 1);
        expect(
          (await store.load()).single.syncStatus,
          WorkoutSyncStatus.synced,
        );
      },
    );

    test('empty pending sync does not notify', () async {
      var notifications = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async => const [],
      )..addListener(() => notifications++);

      await controller.syncPending();

      expect(notifications, 0);
    });

    test('network failure does not notify', () async {
      await store.append(
        _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      var notifications = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async => throw StateError('down'),
      )..addListener(() => notifications++);

      await expectLater(controller.syncPending(), completes);

      expect(notifications, 0);
      expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);
    });

    test(
      'account switched away after network resolves does not notify',
      () async {
        await store.append(
          _session('a', owner: 'user-a', status: WorkoutSyncStatus.pending),
        );
        final state = _SessionState(_accountA);
        final started = Completer<void>();
        final result = Completer<List<WorkoutSyncResult>>();
        var notifications = 0;
        final controller = WorkoutSyncController(
          store: store,
          sessionProvider: state.read,
          premiumProvider: () => true,
          syncBatch: (account, workouts) {
            started.complete();
            return result.future;
          },
        )..addListener(() => notifications++);

        final sync = controller.syncPending();
        await started.future;
        state.current = _accountB;
        result.complete([_accepted('a')]);
        await sync;

        expect(notifications, 0);
      },
    );

    test('rejected server result does not notify', () async {
      await store.append(
        _session('bad', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      var notifications = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async => [
          const WorkoutSyncResult(
            clientSessionId: 'bad',
            status: WorkoutSyncResultStatus.rejected,
            aggregated: false,
            reason: 'invalid_metric',
          ),
        ],
      )..addListener(() => notifications++);

      await controller.syncPending();

      expect(notifications, 0);
      expect(
        (await store.load()).single.syncStatus,
        WorkoutSyncStatus.rejected,
      );
    });
  });

  test('terminal rejection is persisted and not retried', () async {
    await store.append(
      _session('bad', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    var calls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        calls++;
        return const [
          WorkoutSyncResult(
            clientSessionId: 'bad',
            status: WorkoutSyncResultStatus.rejected,
            aggregated: false,
            reason: 'invalid_metric',
          ),
        ];
      },
    );

    await controller.syncPending();
    await controller.syncPending();

    final saved = (await store.load()).single;
    expect(calls, 1);
    expect(saved.syncStatus, WorkoutSyncStatus.rejected);
    expect(saved.syncFailureReason, 'invalid_metric');
    expect(await store.pendingCloudSyncForOwner('user-a'), isEmpty);
  });

  test('premium rejection waits until premium becomes active', () async {
    await store.append(
      _session('blocked', owner: 'user-a', status: WorkoutSyncStatus.pending),
    );
    var premium = false;
    var calls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => premium,
      syncBatch: (account, workouts) async {
        calls++;
        if (calls == 1) {
          return const [
            WorkoutSyncResult(
              clientSessionId: 'blocked',
              status: WorkoutSyncResultStatus.rejected,
              aggregated: false,
              reason: 'premium_required',
            ),
          ];
        }
        return [_accepted('blocked')];
      },
    );

    premium = true;
    await controller.syncPending();
    premium = false;
    await controller.syncPending();
    expect(calls, 1);
    expect(
      (await store.load()).single.syncStatus,
      WorkoutSyncStatus.blockedOnPremium,
    );

    premium = true;
    await controller.syncForCurrentAccount();

    expect(calls, 2);
    expect((await store.load()).single.syncStatus, WorkoutSyncStatus.synced);
  });

  test(
    'sync splits 401 pending workouts into batches of at most 200',
    () async {
      for (var index = 0; index < 401; index++) {
        await store.append(
          _session(
            'session-$index',
            owner: 'user-a',
            status: WorkoutSyncStatus.pending,
          ),
        );
      }
      final batchSizes = <int>[];
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async {
          batchSizes.add(workouts.length);
          return [
            for (final workout in workouts) _accepted(workout.clientSessionId),
          ];
        },
      );

      await controller.syncPending();

      expect(batchSizes, [200, 200, 1]);
      expect(await store.pendingCloudSyncForOwner('user-a'), isEmpty);
      expect(
        (await store.load()).every(
          (session) => session.syncStatus == WorkoutSyncStatus.synced,
        ),
        isTrue,
      );
    },
  );

  test(
    'account switch between batches stops remaining old-account uploads',
    () async {
      for (var index = 0; index < 201; index++) {
        await store.append(
          _session(
            'session-$index',
            owner: 'user-a',
            status: WorkoutSyncStatus.pending,
          ),
        );
      }
      final state = _SessionState(_accountA);
      var calls = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: state.read,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async {
          calls++;
          state.current = _accountB;
          return [
            for (final workout in workouts) _accepted(workout.clientSessionId),
          ];
        },
      );

      await controller.syncPending();

      expect(calls, 1);
      expect(await store.pendingCloudSyncForOwner('user-a'), hasLength(201));
    },
  );

  test(
    'a session missing localDate metadata does not block other sessions from syncing',
    () async {
      // A legacy session without localDate/timezoneOffsetMinutes.
      final badSession = WorkoutSession(
        id: 'bad',
        startedAt: DateTime.utc(2026, 7, 9, 1),
        endedAt: DateTime.utc(2026, 7, 9, 1, 3),
        count: 10,
        ownerAppUserId: 'user-a',
        syncStatus: WorkoutSyncStatus.pending,
      );
      await store.append(badSession);
      await store.append(
        _session('good', owner: 'user-a', status: WorkoutSyncStatus.pending),
      );
      final synced = <String>[];
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => _accountA,
        premiumProvider: () => true,
        syncBatch: (account, workouts) async {
          synced.addAll(workouts.map((w) => w.clientSessionId));
          return [for (final w in workouts) _accepted(w.clientSessionId)];
        },
      );

      await controller.syncPending();

      // The good session must still be synced even though 'bad' is malformed.
      expect(synced, contains('good'));
      final sessions = await _byId(store);
      expect(sessions['good']!.syncStatus, WorkoutSyncStatus.synced);
      // The bad session is quarantined so it does not block future syncs.
      expect(sessions['bad']!.syncStatus, WorkoutSyncStatus.rejected);
      expect(sessions['bad']!.syncFailureReason, 'missing_local_metadata');
    },
  );

  test('all sessions missing metadata does not call network', () async {
    final badSession = WorkoutSession(
      id: 'bad1',
      startedAt: DateTime.utc(2026, 7, 9, 1),
      endedAt: DateTime.utc(2026, 7, 9, 1, 3),
      count: 10,
      ownerAppUserId: 'user-a',
      syncStatus: WorkoutSyncStatus.pending,
    );
    await store.append(badSession);
    var networkCalls = 0;
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => _accountA,
      premiumProvider: () => true,
      syncBatch: (account, workouts) async {
        networkCalls++;
        return [];
      },
    );

    await controller.syncPending();

    expect(networkCalls, 0);
    final sessions = await _byId(store);
    expect(sessions['bad1']!.syncStatus, WorkoutSyncStatus.rejected);
    expect(sessions['bad1']!.syncFailureReason, 'missing_local_metadata');
  });
}

WorkoutSession _session(
  String id, {
  String? owner,
  WorkoutSyncStatus status = WorkoutSyncStatus.localOnly,
  int count = 20,
}) {
  return WorkoutSession(
    id: id,
    startedAt: DateTime.utc(2026, 7, 9, 1),
    endedAt: DateTime.utc(2026, 7, 9, 1, 3),
    count: count,
    localDate: DateTime(2026, 7, 9),
    timezoneOffsetMinutes: 480,
    ownerAppUserId: owner,
    syncStatus: status,
  );
}

WorkoutSyncResult _accepted(String id) {
  return WorkoutSyncResult(
    clientSessionId: id,
    status: WorkoutSyncResultStatus.accepted,
    aggregated: true,
  );
}

Future<Map<String, WorkoutSession>> _byId(WorkoutSessionStore store) async {
  return {for (final session in await store.load()) session.id: session};
}

class _SessionState {
  _SessionState(this.current);

  SavedAccountSession? current;

  SavedAccountSession? read() => current;
}
