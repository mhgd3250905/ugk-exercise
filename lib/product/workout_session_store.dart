enum WorkoutSyncStatus {
  localOnly,
  pending,
  synced,
  failed,
  blockedOnPremium,
  rejected,
  protocolError;

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
    this.syncFailureReason,
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
  final String? syncFailureReason;
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
      if (syncFailureReason != null) 'syncFailureReason': syncFailureReason!,
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
      syncFailureReason: json['syncFailureReason'] as String?,
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
    String? syncFailureReason,
    bool clearSyncFailureReason = false,
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
      syncFailureReason: clearSyncFailureReason
          ? null
          : syncFailureReason ?? this.syncFailureReason,
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
        other.syncFailureReason == syncFailureReason &&
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
    syncFailureReason,
    syncedAt,
  );

  @override
  String toString() {
    return 'WorkoutSession(id: $id, startedAt: $startedAt, endedAt: $endedAt, count: $count, exerciseType: $exerciseType, localDate: $localDate, timezoneOffsetMinutes: $timezoneOffsetMinutes, ownerAppUserId: $ownerAppUserId, syncStatus: $syncStatus, syncFailureReason: $syncFailureReason, syncedAt: $syncedAt)';
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

/// Product-facing persistence port. Production wiring supplies the filesystem
/// implementation from `platform/`.
abstract class WorkoutSessionRepository {
  Future<List<WorkoutSession>> load();

  Future<List<WorkoutSession>> loadForOwner(String? ownerAppUserId) async {
    return [
      for (final session in await load())
        if (session.ownerAppUserId == ownerAppUserId) session,
    ];
  }

  Future<void> cacheCloudHistoryForOwner(
    String ownerAppUserId,
    List<WorkoutSession> sessions,
  );

  Future<void> append(WorkoutSession session);

  Future<void> markForCloudSyncForOwner(String id, String ownerAppUserId);

  Future<void> markCloudSyncedForOwner(
    String id,
    DateTime syncedAt,
    String ownerAppUserId,
  );

  Future<void> markCloudSyncFailedForOwner(String id, String ownerAppUserId);

  Future<void> markCloudSyncBlockedOnPremiumForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  );

  Future<void> markCloudSyncRejectedForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  );

  Future<void> markCloudSyncProtocolErrorForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  );

  Future<void> markCloudSyncRetryableForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  );

  Future<void> markCloudSyncLocalOnlyForOwner(String id, String ownerAppUserId);

  Future<List<WorkoutSession>> pendingCloudSyncForOwner(String ownerAppUserId);

  Future<void> queueOwnedHistoryForCloudSync(String ownerAppUserId);

  Future<int> claimLegacyForOwner(String ownerAppUserId);

  Future<int> totalForLocalDate(
    DateTime date, {
    String? ownerAppUserId,
    String? exerciseType,
  }) async {
    final day = _localDay(date);
    final totals = await totalsByLocalDate(
      ownerAppUserId: ownerAppUserId,
      exerciseType: exerciseType,
    );
    return totals[day] ?? 0;
  }

  Future<Map<DateTime, int>> totalsByLocalDate({
    String? ownerAppUserId,
    String? exerciseType,
  }) async {
    final totals = <DateTime, int>{};
    for (final session in await loadForOwner(ownerAppUserId)) {
      if (exerciseType != null && session.exerciseType != exerciseType) {
        continue;
      }
      final day = session.localDate ?? _localDay(session.startedAt);
      totals[day] = (totals[day] ?? 0) + session.count;
    }
    return totals;
  }
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
