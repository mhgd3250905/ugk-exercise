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
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 12,
    );

    await store.append(session);

    expect(await store.load(), [session]);
  });

  test('fromJson defaults old sessions to pushup localOnly records', () {
    final session = WorkoutSession.fromJson({
      'id': 'old',
      'startedAt': '2026-07-08T09:00:00.000',
      'endedAt': '2026-07-08T09:03:00.000',
      'count': 12,
    });

    expect(session.exerciseType, 'pushup');
    expect(session.syncStatus, WorkoutSyncStatus.localOnly);
    expect(session.syncedAt, isNull);
  });

  test('localDate round trips through JSON', () {
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime(2026, 6, 30, 16),
      endedAt: DateTime(2026, 6, 30, 16, 3),
      count: 12,
      localDate: DateTime(2026, 7, 1),
    );

    final restored = WorkoutSession.fromJson(session.toJson());

    expect(restored.localDate, DateTime(2026, 7, 1));
    expect(restored, session);
  });

  test('mergeWorkoutSessions keeps one per id and preserves cloud-only', () {
    final sameLocal = WorkoutSession(
      id: 'same',
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 12,
      syncStatus: WorkoutSyncStatus.pending,
    );
    final sameCloud = WorkoutSession(
      id: 'same',
      startedAt: DateTime(2026, 7, 8, 9),
      endedAt: DateTime(2026, 7, 8, 9, 3),
      count: 20,
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
    expect(merged.first.count, 20);
    expect(merged.first.syncStatus, WorkoutSyncStatus.synced);
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
}
