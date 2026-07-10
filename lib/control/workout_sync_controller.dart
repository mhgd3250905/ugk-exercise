import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../product/workout_session_store.dart';

typedef AccountSessionProvider = SavedAccountSession? Function();
typedef PremiumProvider = bool Function();
typedef WorkoutSyncBatch =
    Future<List<WorkoutSyncResult>> Function(List<WorkoutSyncRequest> workouts);

class WorkoutSyncController {
  WorkoutSyncController({
    required WorkoutSessionStore store,
    required AccountSessionProvider sessionProvider,
    required PremiumProvider premiumProvider,
    required WorkoutSyncBatch syncBatch,
  }) : _store = store,
       _sessionProvider = sessionProvider,
       _premiumProvider = premiumProvider,
       _syncBatch = syncBatch;

  final WorkoutSessionStore _store;
  final AccountSessionProvider _sessionProvider;
  final PremiumProvider _premiumProvider;
  final WorkoutSyncBatch _syncBatch;

  String? get currentOwnerAppUserId => _sessionProvider()?.appUserId;

  Future<void> queueAfterLocalSave(String sessionId) async {
    if (_sessionProvider() == null || !_premiumProvider()) {
      return;
    }
    await _store.markForCloudSync(sessionId);
  }

  Future<void> syncPending() async {
    final account = _sessionProvider();
    if (account == null || !_premiumProvider()) {
      return;
    }
    final sessions = await _store.pendingCloudSync();
    if (sessions.isEmpty) {
      return;
    }
    final currentAccount = _sessionProvider();
    if (currentAccount == null ||
        currentAccount.sessionToken != account.sessionToken ||
        currentAccount.appUserId != account.appUserId) {
      return;
    }
    final results = await _syncBatch([
      for (final session in sessions) WorkoutSyncRequest.fromSession(session),
    ]);
    final now = DateTime.now();
    for (final result in results) {
      if (result.status == WorkoutSyncResultStatus.accepted ||
          result.status == WorkoutSyncResultStatus.duplicate) {
        await _store.markCloudSynced(result.clientSessionId, now);
      } else {
        await _store.markCloudSyncFailed(result.clientSessionId);
      }
    }
  }
}
