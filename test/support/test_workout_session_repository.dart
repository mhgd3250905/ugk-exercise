import 'package:ugk_exercise/product/workout_session_store.dart';

abstract class TestWorkoutSessionRepository extends WorkoutSessionRepository {
  @override
  Future<List<WorkoutSession>> load() {
    throw UnimplementedError();
  }

  @override
  Future<void> cacheCloudHistoryForOwner(
    String ownerAppUserId,
    List<WorkoutSession> sessions,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> append(WorkoutSession session) {
    throw UnimplementedError();
  }

  @override
  Future<void> markForCloudSyncForOwner(String id, String ownerAppUserId) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncedForOwner(
    String id,
    DateTime syncedAt,
    String ownerAppUserId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncFailedForOwner(String id, String ownerAppUserId) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncBlockedOnPremiumForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncRejectedForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncProtocolErrorForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncRetryableForOwner(
    String id,
    String ownerAppUserId,
    String reason,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> markCloudSyncLocalOnlyForOwner(
    String id,
    String ownerAppUserId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkoutSession>> pendingCloudSyncForOwner(String ownerAppUserId) {
    throw UnimplementedError();
  }

  @override
  Future<void> queueOwnedHistoryForCloudSync(String ownerAppUserId) {
    throw UnimplementedError();
  }

  @override
  Future<int> claimLegacyForOwner(String ownerAppUserId) {
    throw UnimplementedError();
  }
}
