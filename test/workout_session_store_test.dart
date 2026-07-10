import 'dart:io';

import 'package:test/test.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ugk_sessions_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('load returns empty list when the JSON file does not exist', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);

    expect(await store.load(), isEmpty);
  });

  test('append writes a session and load reads it back', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime.utc(2026, 7, 8, 9),
      endedAt: DateTime.utc(2026, 7, 8, 9, 3),
      count: 12,
    );

    await store.append(session);

    expect(await store.load(), [session]);
  });

  test('fromJson defaults old sessions to ownerless localOnly records', () {
    final session = WorkoutSession.fromJson({
      'id': 'old',
      'startedAt': '2026-07-08T09:00:00.000',
      'endedAt': '2026-07-08T09:03:00.000',
      'count': 12,
    });

    expect(session.exerciseType, 'pushup');
    expect(session.syncStatus, WorkoutSyncStatus.localOnly);
    expect(session.syncedAt, isNull);
    expect(session.localDate, isNull);
    expect(session.timezoneOffsetMinutes, isNull);
    expect(session.ownerAppUserId, isNull);
  });

  test('immutable workout facts and owner round trip through JSON', () {
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime.utc(2026, 6, 30, 16),
      endedAt: DateTime.utc(2026, 6, 30, 16, 3),
      count: 12,
      localDate: DateTime(2026, 7, 1),
      timezoneOffsetMinutes: 480,
      ownerAppUserId: 'user-a',
    );

    final json = session.toJson();
    final restored = WorkoutSession.fromJson(json);

    expect(json['startedAt'], '2026-06-30T16:00:00.000Z');
    expect(json['endedAt'], '2026-06-30T16:03:00.000Z');
    expect(restored.localDate, DateTime(2026, 7, 1));
    expect(restored.timezoneOffsetMinutes, 480);
    expect(restored.ownerAppUserId, 'user-a');
    expect(restored.startedAt.isUtc, isTrue);
    expect(restored.endedAt.isUtc, isTrue);
    expect(restored, session);
  });

  test('a non-null workout owner cannot be replaced', () {
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime.utc(2026, 7, 8, 1),
      endedAt: DateTime.utc(2026, 7, 8, 1, 3),
      count: 12,
      ownerAppUserId: 'user-a',
    );

    expect(() => session.copyWith(ownerAppUserId: 'user-b'), throwsStateError);
  });

  test('mergeWorkoutSessions keeps one per id and preserves cloud-only', () {
    final sameLocal = WorkoutSession(
      id: 'same',
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 12,
      localDate: DateTime(2026, 7, 8),
      syncStatus: WorkoutSyncStatus.pending,
    );
    final sameCloud = WorkoutSession(
      id: 'same',
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 20,
      localDate: DateTime(2026, 7, 9),
      syncStatus: WorkoutSyncStatus.synced,
    );
    final cloudOnly = WorkoutSession(
      id: 'cloud-only',
      startedAt: DateTime(2026, 7, 9, 9),
      endedAt: DateTime(2026, 7, 9, 9, 3),
      count: 8,
      syncStatus: WorkoutSyncStatus.synced,
    );

    final merged = mergeWorkoutSessions(
      local: [sameLocal],
      cloud: [sameCloud, cloudOnly],
    );

    expect(merged.map((session) => session.id), ['same', 'cloud-only']);
    expect(merged.first, sameLocal);
    expect(merged.first.count, 12);
    expect(merged.first.localDate, DateTime(2026, 7, 8));
    expect(merged.first.syncStatus, WorkoutSyncStatus.pending);
  });

  test('markForCloudSync and markSynced update stored sync status', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 12,
    );
    await store.append(session);

    await store.markForCloudSync('s1');
    expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);

    await store.markCloudSynced('s1', DateTime(2026, 7, 8, 10));
    final updated = (await store.load()).single;
    expect(updated.syncStatus, WorkoutSyncStatus.synced);
    expect(updated.syncedAt, DateTime(2026, 7, 8, 10));
  });

  test('pending and failed sync states clear syncedAt', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 's1',
        startedAt: DateTime(2026, 7, 8, 9),
        endedAt: DateTime(2026, 7, 8, 9, 3),
        count: 12,
      ),
    );

    await store.markCloudSynced('s1', DateTime(2026, 7, 8, 10));
    await store.markForCloudSync('s1');
    final pending = (await store.load()).single;
    expect(pending.syncStatus, WorkoutSyncStatus.pending);
    expect(pending.syncedAt, isNull);

    await store.markCloudSynced('s1', DateTime(2026, 7, 8, 11));
    await store.markCloudSyncFailed('s1');
    final failed = (await store.load()).single;
    expect(failed.syncStatus, WorkoutSyncStatus.failed);
    expect(failed.syncedAt, isNull);
  });

  test('pendingCloudSync includes pending and failed sessions', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 'pending',
        startedAt: DateTime(2026, 7, 8, 9),
        endedAt: DateTime(2026, 7, 8, 9, 3),
        count: 12,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'failed',
        startedAt: DateTime(2026, 7, 8, 10),
        endedAt: DateTime(2026, 7, 8, 10, 3),
        count: 8,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'local',
        startedAt: DateTime(2026, 7, 8, 11),
        endedAt: DateTime(2026, 7, 8, 11, 3),
        count: 5,
      ),
    );

    await store.markForCloudSync('pending');
    await store.markCloudSyncFailed('failed');

    expect((await store.pendingCloudSync()).map((session) => session.id), [
      'pending',
      'failed',
    ]);
  });

  test('pendingCloudSync and status writes are scoped to owner', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 'a',
        startedAt: DateTime.utc(2026, 7, 8, 1),
        endedAt: DateTime.utc(2026, 7, 8, 1, 3),
        count: 12,
        ownerAppUserId: 'user-a',
        syncStatus: WorkoutSyncStatus.pending,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'b',
        startedAt: DateTime.utc(2026, 7, 8, 2),
        endedAt: DateTime.utc(2026, 7, 8, 2, 3),
        count: 8,
        ownerAppUserId: 'user-b',
        syncStatus: WorkoutSyncStatus.pending,
      ),
    );

    expect(
      (await store.pendingCloudSyncForOwner(
        'user-b',
      )).map((session) => session.id),
      ['b'],
    );

    await store.markCloudSyncedForOwner(
      'a',
      DateTime.utc(2026, 7, 8, 4),
      'user-b',
    );
    await store.markCloudSyncFailedForOwner('a', 'user-b');

    final unchanged = (await store.load()).first;
    expect(unchanged.syncStatus, WorkoutSyncStatus.pending);
    expect(unchanged.syncedAt, isNull);
    expect(unchanged.ownerAppUserId, 'user-a');
  });

  test('concurrent appends retain both sessions', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    final first = WorkoutSession(
      id: 'a',
      startedAt: DateTime.utc(2026, 7, 8, 1),
      endedAt: DateTime.utc(2026, 7, 8, 1, 3),
      count: 12,
    );
    final second = WorkoutSession(
      id: 'b',
      startedAt: DateTime.utc(2026, 7, 8, 2),
      endedAt: DateTime.utc(2026, 7, 8, 2, 3),
      count: 8,
    );

    await Future.wait([store.append(first), store.append(second)]);

    expect((await store.load()).map((session) => session.id), ['a', 'b']);
  });

  test(
    'concurrent appends across store instances retain both sessions',
    () async {
      final firstStore = WorkoutSessionStore(baseDir: tempDir);
      final secondStore = WorkoutSessionStore(baseDir: tempDir);
      final first = WorkoutSession(
        id: 'a',
        startedAt: DateTime.utc(2026, 7, 8, 1),
        endedAt: DateTime.utc(2026, 7, 8, 1, 3),
        count: 12,
      );
      final second = WorkoutSession(
        id: 'b',
        startedAt: DateTime.utc(2026, 7, 8, 2),
        endedAt: DateTime.utc(2026, 7, 8, 2, 3),
        count: 8,
      );

      await Future.wait([firstStore.append(first), secondStore.append(second)]);

      expect((await firstStore.load()).map((session) => session.id), [
        'a',
        'b',
      ]);
    },
  );

  test('append and status update do not lose the appended session', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    final session = WorkoutSession(
      id: 'a',
      startedAt: DateTime.utc(2026, 7, 8, 1),
      endedAt: DateTime.utc(2026, 7, 8, 1, 3),
      count: 12,
      ownerAppUserId: 'user-a',
    );

    await Future.wait([
      store.append(session),
      store.markCloudSyncFailedForOwner('a', 'user-a'),
    ]);

    final stored = (await store.load()).single;
    expect(stored.id, 'a');
    expect(stored.syncStatus, WorkoutSyncStatus.failed);
  });

  test('append and status update across store instances retain both', () async {
    final firstStore = WorkoutSessionStore(baseDir: tempDir);
    final secondStore = WorkoutSessionStore(baseDir: tempDir);
    final existing = WorkoutSession(
      id: 'existing',
      startedAt: DateTime.utc(2026, 7, 8, 1),
      endedAt: DateTime.utc(2026, 7, 8, 1, 3),
      count: 12,
      ownerAppUserId: 'user-a',
    );
    final added = WorkoutSession(
      id: 'added',
      startedAt: DateTime.utc(2026, 7, 8, 2),
      endedAt: DateTime.utc(2026, 7, 8, 2, 3),
      count: 8,
      ownerAppUserId: 'user-a',
    );
    await firstStore.append(existing);

    await Future.wait([
      firstStore.append(added),
      secondStore.markCloudSyncFailedForOwner('existing', 'user-a'),
    ]);

    final stored = await firstStore.load();
    expect(stored.map((session) => session.id), ['existing', 'added']);
    expect(stored.first.syncStatus, WorkoutSyncStatus.failed);
  });

  test('totalForLocalDate sums only sessions on that local day', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 'morning',
        startedAt: DateTime(2026, 7, 8, 8),
        endedAt: DateTime(2026, 7, 8, 8, 5),
        count: 10,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'evening',
        startedAt: DateTime(2026, 7, 8, 20),
        endedAt: DateTime(2026, 7, 8, 20, 4),
        count: 7,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'next-day',
        startedAt: DateTime(2026, 7, 9, 7),
        endedAt: DateTime(2026, 7, 9, 7, 2),
        count: 4,
      ),
    );

    expect(await store.totalForLocalDate(DateTime(2026, 7, 8, 12)), 17);
    expect(await store.totalForLocalDate(DateTime(2026, 7, 9, 12)), 4);
  });

  test('totalsByLocalDate groups sessions by midnight date', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 'a',
        startedAt: DateTime(2026, 7, 8, 23, 50),
        endedAt: DateTime(2026, 7, 8, 23, 55),
        count: 3,
      ),
    );
    await store.append(
      WorkoutSession(
        id: 'b',
        startedAt: DateTime(2026, 7, 9, 0, 5),
        endedAt: DateTime(2026, 7, 9, 0, 8),
        count: 5,
      ),
    );

    final totals = await store.totalsByLocalDate();

    expect(totals, {DateTime(2026, 7, 8): 3, DateTime(2026, 7, 9): 5});
  });

  test('totalsByLocalDate uses the persisted training date', () async {
    final store = WorkoutSessionStore(baseDir: tempDir);
    await store.append(
      WorkoutSession(
        id: 'travelled',
        startedAt: DateTime.utc(2026, 6, 30, 16),
        endedAt: DateTime.utc(2026, 6, 30, 16, 3),
        count: 3,
        localDate: DateTime(2026, 7, 1),
        timezoneOffsetMinutes: 480,
      ),
    );

    expect(await store.totalsByLocalDate(), {DateTime(2026, 7, 1): 3});
  });
}
