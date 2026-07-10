import 'dart:async';

import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../product/workout_session_store.dart';

typedef AccountSessionProvider = SavedAccountSession? Function();
typedef PremiumProvider = bool Function();
typedef WorkoutSyncBatch =
    Future<List<WorkoutSyncResult>> Function(
      SavedAccountSession account,
      List<WorkoutSyncRequest> workouts,
    );

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

  Future<void>? _inFlight;
  var _syncRequested = false;

  String? get currentOwnerAppUserId => _sessionProvider()?.appUserId;

  Future<void> queueAfterLocalSave(String sessionId) async {
    final account = _sessionProvider();
    if (account == null || !_premiumProvider()) {
      return;
    }
    await _store.markForCloudSyncForOwner(sessionId, account.appUserId);
    if (_isCurrent(account) && _premiumProvider()) {
      unawaited(syncPending());
    }
  }

  Future<void> syncForCurrentAccount() async {
    final account = _sessionProvider();
    if (account == null || !_premiumProvider()) {
      return;
    }
    await _store.queueOwnedHistoryForCloudSync(account.appUserId);
    if (_isCurrent(account) && _premiumProvider()) {
      await syncPending();
    }
  }

  Future<int> claimLegacyForOwner(String expectedOwnerAppUserId) async {
    final account = _sessionProvider();
    if (account == null ||
        account.appUserId != expectedOwnerAppUserId ||
        !_premiumProvider()) {
      return 0;
    }
    final claimed = await _store.claimLegacyForOwner(expectedOwnerAppUserId);
    if (!_isCurrent(account) || !_premiumProvider()) {
      return claimed;
    }
    await syncPending();
    if (!_isCurrent(account) || !_premiumProvider()) {
      return claimed;
    }
    return claimed;
  }

  Future<void> syncPending() {
    _syncRequested = true;
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final future = _drain();
    _inFlight = future;
    return future;
  }

  Future<void> _drain() async {
    try {
      do {
        _syncRequested = false;
        try {
          await _syncOnce();
        } catch (_) {
          // A later account/app trigger retries persisted pending records.
        }
      } while (_syncRequested);
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _syncOnce() async {
    final account = _sessionProvider();
    if (account == null || !_premiumProvider()) {
      return;
    }
    final sessions = await _store.pendingCloudSyncForOwner(account.appUserId);
    if (sessions.isEmpty || !_isCurrent(account) || !_premiumProvider()) {
      return;
    }
    final results = await _syncBatch(account, [
      for (final session in sessions) WorkoutSyncRequest.fromSession(session),
    ]);
    if (!_isCurrent(account)) {
      return;
    }
    final remainingIds = {for (final session in sessions) session.id};
    final now = DateTime.now();
    for (final result in results) {
      if (!remainingIds.remove(result.clientSessionId) ||
          !_isCurrent(account)) {
        continue;
      }
      if (result.status == WorkoutSyncResultStatus.accepted ||
          result.status == WorkoutSyncResultStatus.duplicate) {
        await _store.markCloudSyncedForOwner(
          result.clientSessionId,
          now,
          account.appUserId,
        );
      } else {
        await _store.markCloudSyncFailedForOwner(
          result.clientSessionId,
          account.appUserId,
        );
      }
    }
  }

  bool _isCurrent(SavedAccountSession account) {
    final current = _sessionProvider();
    return current?.sessionToken == account.sessionToken &&
        current?.appUserId == account.appUserId;
  }
}
