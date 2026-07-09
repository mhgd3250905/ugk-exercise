import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum WorkoutSyncStatus {
  localOnly,
  pending,
  synced,
  failed;

  static WorkoutSyncStatus fromJson(Object? value) {
    return WorkoutSyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkoutSyncStatus.localOnly,
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.count,
    this.exerciseType = 'pushup',
    this.syncStatus = WorkoutSyncStatus.localOnly,
    this.syncedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int count;
  final String exerciseType;
  final WorkoutSyncStatus syncStatus;
  final DateTime? syncedAt;

  Map<String, Object> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'count': count,
      'exerciseType': exerciseType,
      'syncStatus': syncStatus.name,
      if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
    };
  }

  static WorkoutSession fromJson(Map<String, Object?> json) {
    return WorkoutSession(
      id: json['id']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toLocal(),
      endedAt: DateTime.parse(json['endedAt']! as String).toLocal(),
      count: json['count']! as int,
      exerciseType: (json['exerciseType'] as String?) ?? 'pushup',
      syncStatus: WorkoutSyncStatus.fromJson(json['syncStatus']),
      syncedAt: json['syncedAt'] == null
          ? null
          : DateTime.parse(json['syncedAt']! as String).toLocal(),
    );
  }

  WorkoutSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    int? count,
    String? exerciseType,
    WorkoutSyncStatus? syncStatus,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      count: count ?? this.count,
      exerciseType: exerciseType ?? this.exerciseType,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: clearSyncedAt ? null : syncedAt ?? this.syncedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutSession &&
        other.id == id &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.count == count &&
        other.exerciseType == exerciseType &&
        other.syncStatus == syncStatus &&
        other.syncedAt == syncedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    count,
    exerciseType,
    syncStatus,
    syncedAt,
  );

  @override
  String toString() {
    return 'WorkoutSession(id: $id, startedAt: $startedAt, endedAt: $endedAt, count: $count, exerciseType: $exerciseType, syncStatus: $syncStatus, syncedAt: $syncedAt)';
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
    await _write(sessions);
  }

  Future<void> markForCloudSync(String id) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.pending,
        clearSyncedAt: true,
      ),
    );
  }

  Future<void> markCloudSynced(String id, DateTime syncedAt) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.synced,
        syncedAt: syncedAt,
      ),
    );
  }

  Future<void> markCloudSyncFailed(String id) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.failed,
        clearSyncedAt: true,
      ),
    );
  }

  Future<List<WorkoutSession>> pendingCloudSync() async {
    return [
      for (final session in await load())
        if (session.syncStatus == WorkoutSyncStatus.pending ||
            session.syncStatus == WorkoutSyncStatus.failed)
          session,
    ];
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

  Future<void> _replace(
    String id,
    WorkoutSession Function(WorkoutSession session) update,
  ) async {
    final sessions = await load();
    final next = [
      for (final session in sessions)
        session.id == id ? update(session) : session,
    ];
    await _write(next);
  }

  Future<void> _write(List<WorkoutSession> sessions) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert([for (final item in sessions) item.toJson()]),
      flush: true,
    );
  }

  static DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
