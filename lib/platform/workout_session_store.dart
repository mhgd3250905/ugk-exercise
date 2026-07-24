import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../product/workout_session_store.dart';

// Global lock keeps independent store instances from losing concurrent writes.
Future<void> _workoutSessionMutationQueue = Future.value();

enum WorkoutSessionLoadIssueType { invalidJson, invalidRoot, invalidEntries }

class WorkoutSessionLoadIssue {
  const WorkoutSessionLoadIssue({
    required this.type,
    required this.invalidEntryCount,
    required this.backupPath,
  });

  final WorkoutSessionLoadIssueType type;
  final int invalidEntryCount;
  final String? backupPath;
}

class WorkoutSessionCorruptionException implements Exception {
  const WorkoutSessionCorruptionException();

  @override
  String toString() {
    return 'WorkoutSessionCorruptionException: recovery backup failed';
  }
}

class WorkoutSessionStore extends WorkoutSessionRepository {
  WorkoutSessionStore({Directory? baseDir}) : _baseDir = baseDir;

  static const fileName = 'workout_sessions.json';

  final Directory? _baseDir;
  WorkoutSessionLoadIssue? _lastLoadIssue;

  WorkoutSessionLoadIssue? get lastLoadIssue => _lastLoadIssue;

  @override
  Future<List<WorkoutSession>> load() {
    return _load(requireRecoveryBackup: false);
  }

  Future<List<WorkoutSession>> _load({
    required bool requireRecoveryBackup,
  }) async {
    final file = await _file();
    if (!await file.exists()) {
      _lastLoadIssue = null;
      return <WorkoutSession>[];
    }

    String raw;
    try {
      raw = await file.readAsString();
    } on FormatException {
      await _recordCorruption(
        file,
        type: WorkoutSessionLoadIssueType.invalidJson,
        invalidEntryCount: 0,
        requireRecoveryBackup: requireRecoveryBackup,
      );
      return <WorkoutSession>[];
    }
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      await _recordCorruption(
        file,
        type: WorkoutSessionLoadIssueType.invalidJson,
        invalidEntryCount: 0,
        requireRecoveryBackup: requireRecoveryBackup,
      );
      return <WorkoutSession>[];
    }
    if (parsed is! List<Object?>) {
      await _recordCorruption(
        file,
        type: WorkoutSessionLoadIssueType.invalidRoot,
        invalidEntryCount: 0,
        requireRecoveryBackup: requireRecoveryBackup,
      );
      return <WorkoutSession>[];
    }

    final sessions = <WorkoutSession>[];
    var invalidEntryCount = 0;
    for (final item in parsed) {
      try {
        if (item is! Map) {
          throw const FormatException('Invalid workout session entry');
        }
        sessions.add(WorkoutSession.fromJson(Map<String, Object?>.from(item)));
      } on FormatException {
        invalidEntryCount++;
      } on TypeError {
        invalidEntryCount++;
      } on ArgumentError {
        invalidEntryCount++;
      }
    }
    if (invalidEntryCount > 0) {
      await _recordCorruption(
        file,
        type: WorkoutSessionLoadIssueType.invalidEntries,
        invalidEntryCount: invalidEntryCount,
        requireRecoveryBackup: requireRecoveryBackup,
      );
    } else {
      _lastLoadIssue = null;
    }
    return sessions;
  }

  Future<void> _recordCorruption(
    File file, {
    required WorkoutSessionLoadIssueType type,
    required int invalidEntryCount,
    required bool requireRecoveryBackup,
  }) async {
    String? backupPath;
    try {
      backupPath = await _backupCorruptFile(file);
    } on FileSystemException {
      if (requireRecoveryBackup) {
        throw const WorkoutSessionCorruptionException();
      }
    }
    _lastLoadIssue = WorkoutSessionLoadIssue(
      type: type,
      invalidEntryCount: invalidEntryCount,
      backupPath: backupPath,
    );
  }

  Future<String> _backupCorruptFile(File file) async {
    final stat = await file.stat();
    final backupPath =
        '${file.path}.corrupt.${stat.modified.millisecondsSinceEpoch}.${stat.size}.bak';
    final backup = File(backupPath);
    if (!await backup.exists()) {
      await file.copy(backupPath);
    }
    return backupPath;
  }

  @override
  Future<void> cacheCloudHistoryForOwner(
    String ownerAppUserId,
    List<WorkoutSession> sessions,
  ) async {
    await _serializeMutation(() async {
      for (final session in sessions) {
        if (session.ownerAppUserId != null &&
            session.ownerAppUserId != ownerAppUserId) {
          throw StateError('Cloud workout owner does not match cache owner');
        }
      }

      final stored = await _load(requireRecoveryBackup: true);
      final storedKeys = {
        for (final session in stored) (session.ownerAppUserId, session.id),
      };
      var appended = false;
      for (final session in sessions) {
        final key = (ownerAppUserId, session.id);
        if (!storedKeys.add(key)) {
          continue;
        }
        stored.add(
          session.copyWith(
            ownerAppUserId: ownerAppUserId,
            syncStatus: WorkoutSyncStatus.synced,
          ),
        );
        appended = true;
      }
      if (appended) {
        await _write(stored);
      }
    });
  }

  @override
  Future<void> append(WorkoutSession session) async {
    await _serializeMutation(() async {
      final sessions = await _load(requireRecoveryBackup: true);
      sessions.add(session);
      await _write(sessions);
    });
  }

  @override
  Future<void> markForCloudSyncForOwner(
    String id,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.count <= 0
          ? session
          : session.copyWith(
              syncStatus: WorkoutSyncStatus.pending,
              clearSyncFailureReason: true,
              clearSyncedAt: true,
            ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  @override
  Future<void> markCloudSyncedForOwner(
    String id,
    DateTime syncedAt,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.synced,
        clearSyncFailureReason: true,
        syncedAt: syncedAt,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  @override
  Future<void> markCloudSyncFailedForOwner(
    String id,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.failed,
        clearSyncFailureReason: true,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  @override
  Future<void> markCloudSyncBlockedOnPremiumForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) async {
    await _markCloudSyncRejectedForOwner(
      id,
      ownerAppUserId,
      status: WorkoutSyncStatus.blockedOnPremium,
      reason: reason,
    );
  }

  @override
  Future<void> markCloudSyncRejectedForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) async {
    await _markCloudSyncRejectedForOwner(
      id,
      ownerAppUserId,
      status: WorkoutSyncStatus.rejected,
      reason: reason,
    );
  }

  @override
  Future<void> markCloudSyncProtocolErrorForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) async {
    await _markCloudSyncRejectedForOwner(
      id,
      ownerAppUserId,
      status: WorkoutSyncStatus.protocolError,
      reason: reason,
    );
  }

  @override
  Future<void> markCloudSyncRetryableForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.failed,
        syncFailureReason: reason,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  @override
  Future<void> markCloudSyncLocalOnlyForOwner(
    String id,
    String ownerAppUserId,
  ) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: WorkoutSyncStatus.localOnly,
        clearSyncFailureReason: true,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
  }

  @override
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

  @override
  Future<void> queueOwnedHistoryForCloudSync(String ownerAppUserId) async {
    await _serializeMutation(() async {
      final sessions = await _load(requireRecoveryBackup: true);
      final next = [
        for (final session in sessions)
          session.ownerAppUserId == ownerAppUserId &&
                  (session.syncStatus == WorkoutSyncStatus.localOnly ||
                      session.syncStatus == WorkoutSyncStatus.failed ||
                      session.syncStatus ==
                          WorkoutSyncStatus.blockedOnPremium) &&
                  session.count > 0
              ? session.copyWith(
                  syncStatus: WorkoutSyncStatus.pending,
                  clearSyncFailureReason: true,
                  clearSyncedAt: true,
                )
              : session,
      ];
      await _write(next);
    });
  }

  @override
  Future<int> claimLegacyForOwner(String ownerAppUserId) {
    return _serializeMutation(() async {
      final sessions = await _load(requireRecoveryBackup: true);
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
          syncStatus: session.count > 0
              ? WorkoutSyncStatus.pending
              : WorkoutSyncStatus.localOnly,
          clearSyncFailureReason: true,
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
      final sessions = await _load(requireRecoveryBackup: true);
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

  Future<void> _markCloudSyncRejectedForOwner(
    String id,
    String ownerAppUserId, {
    required WorkoutSyncStatus status,
    required String reason,
  }) async {
    await _replace(
      id,
      (session) => session.copyWith(
        syncStatus: status,
        syncFailureReason: reason,
        clearSyncedAt: true,
      ),
      ownerAppUserId: ownerAppUserId,
    );
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
    final content = encoder.convert([
      for (final item in sessions) item.toJson(),
    ]);
    final tmpFile = File('${file.path}.tmp');
    await tmpFile.writeAsString(content, flush: true);
    await tmpFile.rename(file.path);
    _lastLoadIssue = null;
  }
}
