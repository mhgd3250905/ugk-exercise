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

    expect(totals, {
      DateTime(2026, 7, 8): 3,
      DateTime(2026, 7, 9): 5,
    });
  });
}
