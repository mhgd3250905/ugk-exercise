import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ponytail: global lock, switch to per-path locks only if storage throughput matters.
Future<void> _workoutSessionMutationQueue = Future.value();

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
  static const schemaVersion = 1;

  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.count,
    this.exerciseType = 'pushup',
    this.localDate,
    this.timezoneOffsetMinutes,
    this.ownerAppUserId,
    this.syncStatus = WorkoutSyncStatus.localOnly,
    this.syncedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int count;
  final String exerciseType;
  final DateTime? localDate;
  final int? timezoneOffsetMinutes;
  final String? ownerAppUserId;
  final WorkoutSyncStatus syncStatus;
  final DateTime? syncedAt;

  Map<String, Object> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'id': id,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'count': count,
      'exerciseType': exerciseType,
      if (localDate != null) 'localDate': _formatLocalDate(localDate!),
      if (timezoneOffsetMinutes != null)
        'timezoneOffsetMinutes': timezoneOffsetMinutes!,
      if (ownerAppUserId != null) 'ownerAppUserId': ownerAppUserId!,
      'syncStatus': syncStatus.name,
      if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
    };
  }

  static WorkoutSession fromJson(Map<String, Object?> json) {
    final version = json.containsKey('schemaVersion')
        ? json['schemaVersion']
        : schemaVersion;
    if (version != schemaVersion) {
      throw FormatException('Unsupported workout session schema: $version');
    }
    return WorkoutSession(
      id: json['id']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
      endedAt: DateTime.parse(json['endedAt']! as String).toUtc(),
      count: json['count']! as int,
      exerciseType: (json['exerciseType'] as String?) ?? 'pushup',
      localDate: json['localDate'] == null
          ? null
          : _parseLocalDate(json['localDate']! as String),
      timezoneOffsetMinutes: json['timezoneOffsetMinutes'] as int?,
      ownerAppUserId: json['ownerAppUserId'] as String?,
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
    DateTime? localDate,
    int? timezoneOffsetMinutes,
    String? ownerAppUserId,
    WorkoutSyncStatus? syncStatus,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
  }) {
    if (this.ownerAppUserId != null &&
        ownerAppUserId != null &&
        ownerAppUserId != this.ownerAppUserId) {
      throw StateError('Workout owner cannot be replaced');
    }
    return WorkoutSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      count: count ?? this.count,
      exerciseType: exerciseType ?? this.exerciseType,
      localDate: localDate ?? this.localDate,
      timezoneOffsetMinutes:
          timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      ownerAppUserId: ownerAppUserId ?? this.ownerAppUserId,
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
        other.localDate == localDate &&
        other.timezoneOffsetMinutes == timezoneOffsetMinutes &&
        other.ownerAppUserId == ownerAppUserId &&
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
    localDate,
    timezoneOffsetMinutes,
    ownerAppUserId,
    syncStatus,
    syncedAt,
  );

  @override
  String toString() {
    return 'WorkoutSession(id: $id, startedAt: $startedAt, endedAt: $endedAt, count: $count, exerciseType: $exerciseType, localDate: $localDate, timezoneOffsetMinutes: $timezoneOffsetMinutes, ownerAppUserId: $ownerAppUserId, syncStatus: $syncStatus, syncedAt: $syncedAt)';
  }
}

DateTime _parseLocalDate(String value) {
  final parsed = DateTime.parse(value);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _formatLocalDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

List<WorkoutSession> mergeWorkoutSessions({
  required List<WorkoutSession> local,
  required List<WorkoutSession> cloud,
}) {
  final byId = <String, WorkoutSession>{
    for (final session in local) session.id: session,
  };
  for (final session in cloud) {
    byId.putIfAbsent(session.id, () => session);
  }
  return byId.values.toList(growable: false);
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

  Future<List<WorkoutSession>> loadForOwner(String? ownerAppUserId) async {
    return [
      for (final session in await load())
        if (session.ownerAppUserId == ownerAppUserId) session,
    ];
  }

  Future<void> append(WorkoutSession session) async {
    await _serializeMutation(() async {
      final sessions = await load();
      sessions.add(session);
      await _write(sessions);
    });
  }

  Future<void> markForCloudSyncForOwner(
    String id,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.pending,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  Future<void> markCloudSyncedForOwner(
    String id,
    DateTime syncedAt,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.synced,
        syncedAt: syncedAt,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  Future<void> markCloudSyncFailedForOwner(
    String id,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.failed,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  Future<List<WorkoutSession>> pendingCloudSyncForOwner(
    String ownerAppUserId,
  ) async {
    return [
      for (final session in await load())
        if (session.ownerAppUserId == ownerAppUserId &&
            (session.syncStatus == WorkoutSyncStatus.pending ||
                session.syncStatus == WorkoutSyncStatus.failed))
          session,
    ];
  }

  Future<void> queueOwnedHistoryForCloudSync(String ownerAppUserId) async {
    await _serializeMutation(() async {
      final sessions = await load();
      final next = [
        for (final session in sessions)
          session.ownerAppUserId == ownerAppUserId &&
                  (session.syncStatus == WorkoutSyncStatus.localOnly ||
                      session.syncStatus == WorkoutSyncStatus.failed)
              ? session.copyWith(
                  syncStatus: WorkoutSyncStatus.pending,
                  clearSyncedAt: true,
                )
              : session,
      ];
      await _write(next);
    });
  }

  Future<int> claimLegacyForOwner(String ownerAppUserId) {
    return _serializeMutation(() async {
      final sessions = await load();
      var claimed = 0;
      for (var index = 0; index < sessions.length; index++) {
        final session = sessions[index];
        if (session.ownerAppUserId != null ||
            session.syncStatus == WorkoutSyncStatus.synced) {
          continue;
        }
        final localStartedAt = session.startedAt.toLocal();
        sessions[index] = session.copyWith(
          localDate:
              session.localDate ??
              DateTime(
                localStartedAt.year,
                localStartedAt.month,
                localStartedAt.day,
              ),
          timezoneOffsetMinutes:
              session.timezoneOffsetMinutes ??
              localStartedAt.timeZoneOffset.inMinutes,
          ownerAppUserId: ownerAppUserId,
          syncStatus: WorkoutSyncStatus.pending,
          clearSyncedAt: true,
        );
        claimed++;
      }
      if (claimed > 0) {
        await _write(sessions);
      }
      return claimed;
    });
  }

  Future<int> totalForLocalDate(DateTime date, {String? ownerAppUserId}) async {
    final day = _localDay(date);
    final totals = await totalsByLocalDate(ownerAppUserId: ownerAppUserId);
    return totals[day] ?? 0;
  }

  Future<Map<DateTime, int>> totalsByLocalDate({String? ownerAppUserId}) async {
    final totals = <DateTime, int>{};
    for (final session in await loadForOwner(ownerAppUserId)) {
      final day = session.localDate ?? _localDay(session.startedAt);
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
    WorkoutSession Function(WorkoutSession session) update, {
    String? ownerAppUserId,
  }) async {
    await _serializeMutation(() async {
      final sessions = await load();
      final next = [
        for (final session in sessions)
          session.id == id &&
                  (ownerAppUserId == null ||
                      session.ownerAppUserId == ownerAppUserId)
              ? update(session)
              : session,
      ];
      await _write(next);
    });
  }

  Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final result = Completer<T>();
    _workoutSessionMutationQueue = _workoutSessionMutationQueue.then((_) async {
      try {
        result.complete(await mutation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
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
