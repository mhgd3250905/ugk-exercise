import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.count,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int count;

  Map<String, Object> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'count': count,
    };
  }

  static WorkoutSession fromJson(Map<String, Object?> json) {
    return WorkoutSession(
      id: json['id']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toLocal(),
      endedAt: DateTime.parse(json['endedAt']! as String).toLocal(),
      count: json['count']! as int,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutSession &&
        other.id == id &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(id, startedAt, endedAt, count);

  @override
  String toString() {
    return 'WorkoutSession(id: $id, startedAt: $startedAt, endedAt: $endedAt, count: $count)';
  }
}

class WorkoutSessionStore {
  WorkoutSessionStore({Directory? baseDir}) : _baseDir = baseDir;

  static const fileName = 'workout_sessions.json';

  final Directory? _baseDir;

  Future<List<WorkoutSession>> load() async {
    final file = await _file();
    if (!await file.exists()) {
      return <WorkoutSession>[];
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as List<Object?>;
    return [
      for (final item in decoded)
        WorkoutSession.fromJson(Map<String, Object?>.from(item! as Map)),
    ];
  }

  Future<void> append(WorkoutSession session) async {
    final sessions = await load();
    sessions.add(session);

    final file = await _file();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert([for (final item in sessions) item.toJson()]),
      flush: true,
    );
  }

  Future<int> totalForLocalDate(DateTime date) async {
    final day = _localDay(date);
    final totals = await totalsByLocalDate();
    return totals[day] ?? 0;
  }

  Future<Map<DateTime, int>> totalsByLocalDate() async {
    final totals = <DateTime, int>{};
    for (final session in await load()) {
      final day = _localDay(session.startedAt);
      totals[day] = (totals[day] ?? 0) + session.count;
    }
    return totals;
  }

  Future<File> _file() async {
    final dir = _baseDir ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, fileName));
  }

  static DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
