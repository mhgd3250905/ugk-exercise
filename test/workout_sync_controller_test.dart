import 'dart:async';

import 'package:test/test.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';

void main() {
  test(
    'queueAfterLocalSave does nothing for free or signed out account',
    () async {
      final store = MemoryWorkoutSessionStore();
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => null,
        premiumProvider: () => false,
        syncBatch: (_) async => const [],
      );

      await controller.queueAfterLocalSave('s1');

      expect(store.markForCloudSyncCalls, 0);
    },
  );

  test(
    'queueAfterLocalSave marks premium sessions pending without uploading inline',
    () async {
      final store = MemoryWorkoutSessionStore();
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        premiumProvider: () => true,
        syncBatch: (_) async => throw StateError('must not upload inline'),
      );

      await controller.queueAfterLocalSave('s1');

      expect(store.markForCloudSyncCalls, 1);
    },
  );

  test(
    'syncPending sends pending sessions and updates per-item statuses',
    () async {
      final store = MemoryWorkoutSessionStore(
        sessions: [
          WorkoutSession(
            id: 'accepted',
            startedAt: DateTime.utc(2026, 7, 9, 1),
            endedAt: DateTime.utc(2026, 7, 9, 1, 3),
            count: 20,
            syncStatus: WorkoutSyncStatus.pending,
          ),
          WorkoutSession(
            id: 'duplicate',
            startedAt: DateTime.utc(2026, 7, 9, 2),
            endedAt: DateTime.utc(2026, 7, 9, 2, 4),
            count: 21,
            syncStatus: WorkoutSyncStatus.failed,
          ),
          WorkoutSession(
            id: 'rejected',
            startedAt: DateTime.utc(2026, 7, 9, 3),
            endedAt: DateTime.utc(2026, 7, 9, 3, 5),
            count: 22,
            syncStatus: WorkoutSyncStatus.pending,
          ),
        ],
      );
      List<WorkoutSyncRequest>? uploaded;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        premiumProvider: () => true,
        syncBatch: (workouts) async {
          uploaded = workouts;
          return const [
            WorkoutSyncResult(
              clientSessionId: 'accepted',
              status: WorkoutSyncResultStatus.accepted,
              aggregated: false,
            ),
            WorkoutSyncResult(
              clientSessionId: 'duplicate',
              status: WorkoutSyncResultStatus.duplicate,
              aggregated: true,
            ),
            WorkoutSyncResult(
              clientSessionId: 'rejected',
              status: WorkoutSyncResultStatus.rejected,
              aggregated: false,
            ),
          ];
        },
      );

      await controller.syncPending();

      expect(uploaded?.map((item) => item.clientSessionId), [
        'accepted',
        'duplicate',
        'rejected',
      ]);
      expect(store.markCloudSyncedCalls.map((item) => item.id), [
        'accepted',
        'duplicate',
      ]);
      expect(store.markCloudSyncFailedCalls, ['rejected']);
    },
  );

  test(
    'syncPending does not upload when account changes while loading pending sessions',
    () async {
      final gate = Completer<void>();
      final state = _SessionState(
        const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
      );
      final store = MemoryWorkoutSessionStore(
        sessions: [
          WorkoutSession(
            id: 's1',
            startedAt: DateTime.utc(2026, 7, 9, 1),
            endedAt: DateTime.utc(2026, 7, 9, 1, 3),
            count: 20,
            syncStatus: WorkoutSyncStatus.pending,
          ),
        ],
        pendingCloudSyncBlocker: gate.future,
      );
      var syncBatchCalls = 0;
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: state.read,
        premiumProvider: () => true,
        syncBatch: (_) async {
          syncBatchCalls += 1;
          return const [];
        },
      );

      final future = controller.syncPending();
      state.current = const SavedAccountSession(
        sessionToken: 'session_2',
        appUserId: 'user_2',
      );
      gate.complete();
      await future;

      expect(syncBatchCalls, 0);
      expect(store.markCloudSyncedCalls, isEmpty);
      expect(store.markCloudSyncFailedCalls, isEmpty);
    },
  );

  test('syncPending is a no-op for signed out or free account', () async {
    final signedOutStore = MemoryWorkoutSessionStore(
      sessions: [
        WorkoutSession(
          id: 's1',
          startedAt: DateTime.utc(2026, 7, 9, 1),
          endedAt: DateTime.utc(2026, 7, 9, 1, 3),
          count: 20,
          syncStatus: WorkoutSyncStatus.pending,
        ),
      ],
    );
    var signedOutSyncCalls = 0;
    final signedOutController = WorkoutSyncController(
      store: signedOutStore,
      sessionProvider: () => null,
      premiumProvider: () => true,
      syncBatch: (_) async {
        signedOutSyncCalls += 1;
        return const [];
      },
    );

    await signedOutController.syncPending();

    expect(signedOutSyncCalls, 0);
    expect(signedOutStore.pendingCloudSyncCalls, 0);

    final freeStore = MemoryWorkoutSessionStore(
      sessions: [
        WorkoutSession(
          id: 's2',
          startedAt: DateTime.utc(2026, 7, 9, 2),
          endedAt: DateTime.utc(2026, 7, 9, 2, 3),
          count: 15,
          syncStatus: WorkoutSyncStatus.pending,
        ),
      ],
    );
    var freeSyncCalls = 0;
    final freeController = WorkoutSyncController(
      store: freeStore,
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      premiumProvider: () => false,
      syncBatch: (_) async {
        freeSyncCalls += 1;
        return const [];
      },
    );

    await freeController.syncPending();

    expect(freeSyncCalls, 0);
    expect(freeStore.pendingCloudSyncCalls, 0);
  });

  test(
    'syncPending leaves local statuses untouched when syncBatch throws',
    () async {
      final store = MemoryWorkoutSessionStore(
        sessions: [
          WorkoutSession(
            id: 's1',
            startedAt: DateTime.utc(2026, 7, 9, 1),
            endedAt: DateTime.utc(2026, 7, 9, 1, 3),
            count: 20,
            syncStatus: WorkoutSyncStatus.pending,
          ),
        ],
      );
      final controller = WorkoutSyncController(
        store: store,
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
        premiumProvider: () => true,
        syncBatch: (_) async => throw StateError('network down'),
      );

      expect(controller.syncPending(), throwsA(isA<StateError>()));
      expect(store.markCloudSyncedCalls, isEmpty);
      expect(store.markCloudSyncFailedCalls, isEmpty);
    },
  );
}

class MemoryWorkoutSessionStore extends WorkoutSessionStore {
  MemoryWorkoutSessionStore({
    List<WorkoutSession>? sessions,
    this.pendingCloudSyncBlocker,
  }) : sessions = List<WorkoutSession>.from(sessions ?? const []);

  final List<WorkoutSession> sessions;
  final Future<void>? pendingCloudSyncBlocker;
  var markForCloudSyncCalls = 0;
  var pendingCloudSyncCalls = 0;
  final markCloudSyncedCalls = <_SyncedCall>[];
  final markCloudSyncFailedCalls = <String>[];

  @override
  Future<void> markForCloudSync(String id) async {
    markForCloudSyncCalls += 1;
  }

  @override
  Future<List<WorkoutSession>> pendingCloudSync() async {
    pendingCloudSyncCalls += 1;
    await pendingCloudSyncBlocker;
    return List<WorkoutSession>.from(sessions);
  }

  @override
  Future<void> markCloudSynced(String id, DateTime syncedAt) async {
    markCloudSyncedCalls.add(_SyncedCall(id, syncedAt));
  }

  @override
  Future<void> markCloudSyncFailed(String id) async {
    markCloudSyncFailedCalls.add(id);
  }
}

class _SessionState {
  _SessionState(this.current);

  SavedAccountSession? current;

  SavedAccountSession? read() => current;
}

class _SyncedCall {
  const _SyncedCall(this.id, this.syncedAt);

  final String id;
  final DateTime syncedAt;
}
