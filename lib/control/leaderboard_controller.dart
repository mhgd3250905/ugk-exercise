import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../platform/leaderboard_home_rank_store.dart';
import '../platform/membership_api_client.dart';
import '../product/leaderboard_home_rank.dart';
import '../product/leaderboard_models.dart';
import '../product/membership_status.dart';

typedef LeaderboardSessionProvider = SavedAccountSession? Function();
typedef LeaderboardLoad =
    Future<LeaderboardSnapshot> Function(
      String sessionToken,
      LeaderboardPeriod period,
    );
typedef LeaderboardLoadMore =
    Future<LeaderboardSnapshot> Function(
      String sessionToken,
      LeaderboardPeriod period,
      String cursor,
    );
typedef LeaderboardCommand = Future<void> Function(String sessionToken);
typedef LeaderboardIdentityCommand =
    Future<void> Function(
      String sessionToken,
      LeaderboardIdentityChoice choice,
    );
typedef LeaderboardReportCommand =
    Future<void> Function(
      String sessionToken,
      String userId,
      LeaderboardReportType type,
      LeaderboardReportReason reason,
    );
typedef LeaderboardUserCommand =
    Future<void> Function(String sessionToken, String userId);
typedef LeaderboardBlockedUsersLoad =
    Future<List<BlockedUser>> Function(String sessionToken);
typedef LeaderboardClock = DateTime Function();

/// Stable error codes surfaced by [LeaderboardController.error]. The UI maps
/// these to localized strings and never renders a raw exception message.
class LeaderboardErrorCode {
  const LeaderboardErrorCode._();

  static const requestFailed = 'leaderboard_request_failed';
  static const membershipSyncUnavailable =
      'leaderboard_membership_sync_unavailable';
  static const premiumRequired = 'leaderboard_premium_required';
  static const invalidIdentityMode = 'leaderboard_invalid_identity_mode';
  static const notJoined = 'leaderboard_not_joined';
  static const unexpected = 'leaderboard_unexpected';
}

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required LeaderboardSessionProvider sessionProvider,
    required LeaderboardLoad load,
    LeaderboardLoadMore? loadMore,
    required LeaderboardIdentityCommand joinIdentity,
    required LeaderboardIdentityCommand updateIdentity,
    required LeaderboardCommand leave,
    LeaderboardReportCommand? reportUser,
    LeaderboardUserCommand? blockUser,
    LeaderboardBlockedUsersLoad? loadBlockedUsers,
    LeaderboardUserCommand? unblockUser,
    LeaderboardHomeRankStore? homeRankStore,
    LeaderboardClock? clock,
  }) : _sessionProvider = sessionProvider,
       _load = load,
       _loadMore = loadMore,
       _joinIdentity = joinIdentity,
       _updateIdentity = updateIdentity,
       _leave = leave,
       _reportUser = reportUser,
       _blockUser = blockUser,
       _loadBlockedUsers = loadBlockedUsers,
       _unblockUser = unblockUser,
       _homeRankStore = homeRankStore,
       _clock = clock ?? DateTime.now;

  final LeaderboardSessionProvider _sessionProvider;
  final LeaderboardLoad _load;
  final LeaderboardLoadMore? _loadMore;
  final LeaderboardIdentityCommand _joinIdentity;
  final LeaderboardIdentityCommand _updateIdentity;
  final LeaderboardCommand _leave;
  final LeaderboardReportCommand? _reportUser;
  final LeaderboardUserCommand? _blockUser;
  final LeaderboardBlockedUsersLoad? _loadBlockedUsers;
  final LeaderboardUserCommand? _unblockUser;
  final LeaderboardHomeRankStore? _homeRankStore;
  final LeaderboardClock _clock;

  LeaderboardSnapshot? _snapshot;
  // The appUserId that produced the current [_snapshot]/[_snapshots]. Used by
  // reloadForCurrentAccount to keep showing the last snapshot during a
  // same-account refresh (pull-to-refresh, re-entering profile, other account
  // notifications) while still clearing immediately on a real account switch
  // or sign-out (privacy: never show another account's snapshot).
  String? _snapshotOwnerAppUserId;
  final _snapshots = <LeaderboardPeriod, LeaderboardSnapshot>{};
  final _snapshotPeriodScopes = <LeaderboardPeriod, String>{};
  final _periodErrors = <LeaderboardPeriod, String>{};
  final _loadMoreLeases = <LeaderboardPeriod, Set<_LoadMoreLease>>{};
  final _loadMoreErrors = <LeaderboardPeriod, String>{};
  final _periodLoadLeases = <LeaderboardPeriod, Set<_PeriodLoadLease>>{};
  final _homeRanks = <LeaderboardPeriod, LeaderboardHomeRank>{};
  String? _homeRankOwnerAppUserId;
  var _homeRankRestoreGeneration = 0;
  String? _homeRankRestoreOwnerAppUserId;
  Future<void> _homeRankMutationQueue = Future.value();
  Future<void>? _activeAccountReload;
  SavedAccountSession? _activeAccountReloadSession;
  var _busy = false;
  String? _error;
  var _runGeneration = 0;
  List<BlockedUser> _blockedUsers = const [];
  String? _blockedUsersError;
  var _blockedUsersBusy = false;
  var _blockedUsersGeneration = 0;
  LeaderboardPeriod _lastPeriod = LeaderboardPeriod.day;

  LeaderboardSnapshot? get snapshot {
    final current = _snapshot;
    return current == null ? null : _snapshotForCurrentScope(current.period);
  }

  LeaderboardSnapshot? snapshotFor(LeaderboardPeriod period) =>
      _snapshotForCurrentScope(period);
  String? errorFor(LeaderboardPeriod period) => _periodErrors[period];
  bool isLoadingMore(LeaderboardPeriod period) {
    final session = _sessionProvider();
    if (session == null) return false;
    return _loadMoreLeases[period]?.any(
          (lease) =>
              lease.generation == _runGeneration &&
              lease.sessionToken == session.sessionToken &&
              lease.appUserId == session.appUserId &&
              lease.requestPeriodScope ==
                  leaderboardPeriodScope(period, _clock()) &&
              lease.cursor == _snapshots[period]?.nextCursor,
        ) ??
        false;
  }

  bool isLoading(LeaderboardPeriod period) {
    final appUserId = _sessionProvider()?.appUserId;
    if (appUserId == null) return false;
    return _periodLoadLeases[period]?.any(
          (lease) =>
              lease.appUserId == appUserId &&
              lease.generation == _runGeneration,
        ) ??
        false;
  }

  String? loadMoreErrorFor(LeaderboardPeriod period) => _loadMoreErrors[period];
  bool get busy => _busy;
  String? get error => _error;
  List<BlockedUser> get blockedUsers => _blockedUsers;
  String? get blockedUsersError => _blockedUsersError;
  bool get blockedUsersBusy => _blockedUsersBusy;
  SavedAccountSession? get currentSession => _sessionProvider();
  AppUser? get currentUser => currentSession?.user;

  LeaderboardHomeRank? homeRankFor(LeaderboardPeriod period) {
    final session = _sessionProvider();
    final rank = _homeRanks[period];
    if (session == null ||
        rank == null ||
        _homeRankOwnerAppUserId != session.appUserId ||
        rank.ownerAppUserId != session.appUserId ||
        rank.periodScope != leaderboardPeriodScope(period, _clock())) {
      if (rank != null && rank.ownerAppUserId == session?.appUserId) {
        _clearHomeRankForPeriod(session!.appUserId, period);
      }
      return null;
    }
    return rank;
  }

  /// Called when the account may have changed (sign-in / sign-out / switch)
  /// or when the same account is simply refreshed (pull-to-refresh, re-entering
  /// profile, other account notifications).
  ///
  /// On a real account switch or sign-out, any snapshot/error belonging to the
  /// previous account is cleared IMMEDIATELY, before the new load resolves, so
  /// a stale snapshot from another account is never visible during the switch.
  ///
  /// On a same-account refresh, the last snapshot is KEPT until the new load
  /// resolves, so the card does not flash to a loading state on every refresh.
  /// Account identity is tracked by [appUserId] (stable across re-logins,
  /// changes only on switch/sign-out), not sessionToken (which rotates on every
  /// sign-in).
  Future<void> reloadForCurrentAccount() {
    final session = _sessionProvider();
    final activeReload = _activeAccountReload;
    if (activeReload != null && session == _activeAccountReloadSession) {
      return activeReload;
    }
    late final Future<void> reload;
    reload = _reloadForCurrentAccount().whenComplete(() {
      if (identical(_activeAccountReload, reload)) {
        _activeAccountReload = null;
        _activeAccountReloadSession = null;
      }
    });
    _activeAccountReload = reload;
    _activeAccountReloadSession = session;
    return reload;
  }

  Future<void> _reloadForCurrentAccount() async {
    final session = _sessionProvider();
    _runGeneration++;
    _blockedUsersGeneration++;
    final newOwner = session?.appUserId;
    final currentOwner = _snapshotOwnerAppUserId ?? _homeRankOwnerAppUserId;
    final sameAccount = newOwner != null && newOwner == currentOwner;
    if (!sameAccount) {
      // Account switched or signed out: drop the previous account's data now.
      _invalidateHomeRankRestoreForAccountChange(newOwner);
      _discardHomeRanksForAccountChange(newOwner);
      _snapshot = null;
      _snapshotOwnerAppUserId = null;
      _snapshots.clear();
      _snapshotPeriodScopes.clear();
      _periodErrors.clear();
      _periodLoadLeases.clear();
      _loadMoreLeases.clear();
      _loadMoreErrors.clear();
    } else {
      // Same account: keep the visible snapshot, only clear transient errors.
      _discardExpiredSnapshots();
      _periodErrors.clear();
      _loadMoreErrors.clear();
    }
    _error = null;
    _busy = session != null;
    _blockedUsers = const [];
    _blockedUsersError = null;
    _blockedUsersBusy = false;
    notifyListeners();
    if (session == null) {
      return;
    }
    await load(_lastPeriod);
  }

  Future<void> load(LeaderboardPeriod period) async {
    _lastPeriod = period;
    final session = _sessionProvider();
    if (session == null) {
      _runGeneration++;
      _invalidateHomeRankRestoreForAccountChange(null);
      _discardHomeRanksForAccountChange(null);
      _snapshot = null;
      _snapshotOwnerAppUserId = null;
      _snapshots.clear();
      _snapshotPeriodScopes.clear();
      _periodErrors.clear();
      _periodLoadLeases.clear();
      _loadMoreLeases.clear();
      _loadMoreErrors.clear();
      _error = null;
      _busy = false;
      notifyListeners();
      return;
    }
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    await _run((generation) async {
      final lease = _beginPeriodLoad(period, generation, appUserId);
      final requestPeriodScope = leaderboardPeriodScope(period, _clock());
      try {
        final snapshot = await _load(sessionToken, period);
        if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
          _applyAuthoritativeSnapshot(
            period: period,
            snapshot: snapshot,
            appUserId: appUserId,
            requestPeriodScope: requestPeriodScope,
          );
        }
      } catch (error) {
        if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
          if (requestPeriodScope != leaderboardPeriodScope(period, _clock())) {
            _discardSnapshotForExpiredScope(period);
            return;
          }
          if (_invalidatesHomeRank(error)) {
            _clearAllHomeRanksForAccount(appUserId);
          }
        }
        rethrow;
      } finally {
        _endPeriodLoad(period, lease);
      }
    }, isStillRelevant: () => _isCurrentAccount(sessionToken, appUserId));
  }

  Future<void> restoreHomeRankForCurrentAccount() async {
    final store = _homeRankStore;
    final session = _sessionProvider();
    if (store == null || session == null) return;
    final appUserId = session.appUserId;
    if (_homeRankOwnerAppUserId != null &&
        _homeRankOwnerAppUserId != appUserId) {
      _discardHomeRanksForAccountChange(appUserId);
    }
    final generation = ++_homeRankRestoreGeneration;
    _homeRankRestoreOwnerAppUserId = appUserId;
    const period = LeaderboardPeriod.day;
    final periodScope = leaderboardPeriodScope(period, _clock());
    try {
      final rank = await store.load(
        appUserId: appUserId,
        period: period,
        periodScope: periodScope,
      );
      if (rank == null ||
          generation != _homeRankRestoreGeneration ||
          !_isCurrentAccount(session.sessionToken, appUserId) ||
          _snapshots.containsKey(period)) {
        return;
      }
      _homeRanks[period] = rank;
      _homeRankOwnerAppUserId = appUserId;
      notifyListeners();
    } catch (_) {
      // Cache failures must never block the authoritative leaderboard flow.
    } finally {
      if (generation == _homeRankRestoreGeneration &&
          _homeRankRestoreOwnerAppUserId == appUserId) {
        _homeRankRestoreOwnerAppUserId = null;
      }
    }
  }

  _PeriodLoadLease _beginPeriodLoad(
    LeaderboardPeriod period,
    int generation,
    String appUserId,
  ) {
    final lease = _PeriodLoadLease(
      generation: generation,
      appUserId: appUserId,
    );
    (_periodLoadLeases[period] ??= {}).add(lease);
    return lease;
  }

  void _endPeriodLoad(LeaderboardPeriod period, _PeriodLoadLease lease) {
    final leases = _periodLoadLeases[period];
    if (leases == null) return;
    leases.remove(lease);
    if (leases.isEmpty) _periodLoadLeases.remove(period);
  }

  bool _applyAuthoritativeSnapshot({
    required LeaderboardPeriod period,
    required LeaderboardSnapshot snapshot,
    required String appUserId,
    required String requestPeriodScope,
    bool updateHomeRank = true,
  }) {
    if (requestPeriodScope != leaderboardPeriodScope(period, _clock())) {
      _discardSnapshotForExpiredScope(period);
      return false;
    }
    _snapshots[period] = snapshot;
    _snapshotPeriodScopes[period] = requestPeriodScope;
    _snapshotOwnerAppUserId = appUserId;
    _periodErrors.remove(period);
    if (_lastPeriod == period) {
      _snapshot = snapshot;
    }
    if (updateHomeRank) {
      _updateHomeRankFromSnapshot(
        period: period,
        snapshot: snapshot,
        appUserId: appUserId,
        requestPeriodScope: requestPeriodScope,
      );
    }
    return true;
  }

  LeaderboardSnapshot? _snapshotForCurrentScope(LeaderboardPeriod period) {
    final scope = _snapshotPeriodScopes[period];
    if (scope == null || scope != leaderboardPeriodScope(period, _clock())) {
      return null;
    }
    return _snapshots[period];
  }

  void _discardSnapshotForExpiredScope(LeaderboardPeriod period) {
    final scope = _snapshotPeriodScopes[period];
    if (scope != null && scope == leaderboardPeriodScope(period, _clock())) {
      return;
    }
    _snapshots.remove(period);
    _snapshotPeriodScopes.remove(period);
    _periodErrors.remove(period);
    _loadMoreErrors.remove(period);
    if (_snapshot?.period == period) {
      _snapshot = null;
    }
    if (_snapshots.isEmpty) {
      _snapshotOwnerAppUserId = null;
    }
  }

  void _discardExpiredSnapshots() {
    for (final period in _snapshots.keys.toList()) {
      _discardSnapshotForExpiredScope(period);
    }
  }

  void _updateHomeRankFromSnapshot({
    required LeaderboardPeriod period,
    required LeaderboardSnapshot snapshot,
    required String appUserId,
    required String requestPeriodScope,
  }) {
    final me = snapshot.me;
    final currentPeriodScope = leaderboardPeriodScope(period, _clock());
    if (snapshot.period != period ||
        snapshot.metric != leaderboardPointsMetric ||
        !snapshot.isJoined ||
        me == null ||
        me.rank < 1 ||
        me.totalValue < 0 ||
        requestPeriodScope != currentPeriodScope) {
      _clearHomeRankForPeriod(appUserId, period);
      return;
    }
    if (_homeRankOwnerAppUserId != appUserId) {
      _homeRanks.clear();
      _homeRankOwnerAppUserId = appUserId;
    }
    final rank = LeaderboardHomeRank(
      ownerAppUserId: appUserId,
      period: period,
      periodScope: currentPeriodScope,
      rank: me.rank,
      totalValue: me.totalValue,
      metric: snapshot.metric,
    );
    _homeRanks[period] = rank;
    unawaited(_queueHomeRankMutation((store) => store.save(rank)));
  }

  void _clearHomeRankForPeriod(String appUserId, LeaderboardPeriod period) {
    if (_homeRankOwnerAppUserId == appUserId) {
      _homeRanks.remove(period);
      if (_homeRanks.isEmpty) {
        _homeRankOwnerAppUserId = null;
      }
    }
    unawaited(
      _queueHomeRankMutation(
        (store) => store.clear(appUserId: appUserId, period: period),
      ),
    );
  }

  void _clearAllHomeRanksForAccount(String appUserId) {
    if (_homeRankOwnerAppUserId == appUserId) {
      _homeRanks.clear();
      _homeRankOwnerAppUserId = null;
    }
    unawaited(
      _queueHomeRankMutation((store) => store.clearForAccount(appUserId)),
    );
  }

  void _invalidateHomeRankRestoreForAccountChange(String? newOwnerAppUserId) {
    final restoreOwnerAppUserId = _homeRankRestoreOwnerAppUserId;
    if (restoreOwnerAppUserId == null ||
        restoreOwnerAppUserId == newOwnerAppUserId) {
      return;
    }
    _homeRankRestoreGeneration++;
    _homeRankRestoreOwnerAppUserId = null;
  }

  void _discardHomeRanksForAccountChange(String? newOwnerAppUserId) {
    final oldOwnerAppUserId =
        _homeRankOwnerAppUserId ?? _snapshotOwnerAppUserId;
    if (oldOwnerAppUserId == null || oldOwnerAppUserId == newOwnerAppUserId) {
      return;
    }
    _homeRanks.clear();
    _homeRankOwnerAppUserId = null;
    unawaited(
      _queueHomeRankMutation(
        (store) => store.clearForAccount(oldOwnerAppUserId),
      ),
    );
  }

  Future<void> _queueHomeRankMutation(
    Future<void> Function(LeaderboardHomeRankStore store) mutation,
  ) {
    final store = _homeRankStore;
    if (store == null) return Future.value();
    final queued = _homeRankMutationQueue.then((_) async {
      try {
        await mutation(store);
      } catch (_) {
        // Cache failures must never override an authoritative leaderboard view.
      }
    });
    _homeRankMutationQueue = queued;
    return queued;
  }

  void selectPeriod(LeaderboardPeriod period) {
    if (_lastPeriod == period) return;
    _discardSnapshotForExpiredScope(period);
    _lastPeriod = period;
    _snapshot = _snapshotForCurrentScope(period);
    _error = _periodErrors[period];
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final session = _sessionProvider();
    if (session == null) {
      _runGeneration++;
      _invalidateHomeRankRestoreForAccountChange(null);
      _discardHomeRanksForAccountChange(null);
      _snapshot = null;
      _snapshotOwnerAppUserId = null;
      _snapshots.clear();
      _snapshotPeriodScopes.clear();
      _periodErrors.clear();
      _periodLoadLeases.clear();
      _loadMoreLeases.clear();
      _loadMoreErrors.clear();
      _error = null;
      _busy = false;
      notifyListeners();
      return;
    }
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    _discardExpiredSnapshots();
    final generation = ++_runGeneration;
    _busy = true;
    _error = null;
    _periodErrors.clear();
    _loadMoreErrors.clear();
    final periodLoadLeases = <LeaderboardPeriod, _PeriodLoadLease>{};
    final requestPeriodScopes = <LeaderboardPeriod, String>{
      for (final period in LeaderboardPeriod.values)
        period: leaderboardPeriodScope(period, _clock()),
    };
    for (final period in LeaderboardPeriod.values) {
      periodLoadLeases[period] = _beginPeriodLoad(
        period,
        generation,
        appUserId,
      );
    }
    notifyListeners();
    try {
      final results = await Future.wait([
        for (final period in LeaderboardPeriod.values)
          _loadPeriod(sessionToken, period, requestPeriodScopes[period]!),
      ]);
      if (!_isCurrentAccountRun(generation, sessionToken, appUserId)) return;
      final currentResults = <_LeaderboardPeriodResult>[];
      for (final result in results) {
        if (result.requestPeriodScope !=
            leaderboardPeriodScope(result.period, _clock())) {
          _discardSnapshotForExpiredScope(result.period);
        } else {
          currentResults.add(result);
        }
      }
      final invalidatesHomeRank = currentResults.any(
        (result) => result.invalidatesHomeRank,
      );
      if (invalidatesHomeRank) {
        _clearAllHomeRanksForAccount(appUserId);
      }
      for (final result in currentResults) {
        final snapshot = result.snapshot;
        if (snapshot != null) {
          _applyAuthoritativeSnapshot(
            period: result.period,
            snapshot: snapshot,
            appUserId: appUserId,
            requestPeriodScope: result.requestPeriodScope,
            updateHomeRank: !invalidatesHomeRank,
          );
        } else {
          _periodErrors[result.period] = result.error!;
        }
      }
      _snapshot = _snapshotForCurrentScope(_lastPeriod);
      _snapshotOwnerAppUserId = _snapshots.isEmpty ? null : appUserId;
      _error = _periodErrors[_lastPeriod];
    } finally {
      for (final entry in periodLoadLeases.entries) {
        _endPeriodLoad(entry.key, entry.value);
      }
      if (generation == _runGeneration) {
        _busy = false;
      }
      notifyListeners();
    }
  }

  Future<_LeaderboardPeriodResult> _loadPeriod(
    String sessionToken,
    LeaderboardPeriod period,
    String requestPeriodScope,
  ) async {
    try {
      return _LeaderboardPeriodResult(
        period: period,
        requestPeriodScope: requestPeriodScope,
        snapshot: await _load(sessionToken, period),
      );
    } catch (error) {
      return _LeaderboardPeriodResult(
        period: period,
        requestPeriodScope: requestPeriodScope,
        error: _mapError(error),
        invalidatesHomeRank: _invalidatesHomeRank(error),
      );
    }
  }

  Future<bool> loadMore(LeaderboardPeriod period) async {
    final loader = _loadMore;
    _discardSnapshotForExpiredScope(period);
    final current = _snapshots[period];
    final requestPeriodScope = leaderboardPeriodScope(period, _clock());
    final cursor = current?.nextCursor;
    final session = _sessionProvider();
    if (loader == null ||
        current == null ||
        cursor == null ||
        session == null) {
      return false;
    }
    final generation = _runGeneration;
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    if (isLoadingMore(period)) return false;
    final lease = _LoadMoreLease(
      generation: generation,
      sessionToken: sessionToken,
      appUserId: appUserId,
      requestPeriodScope: requestPeriodScope,
      cursor: cursor,
    );
    (_loadMoreLeases[period] ??= {}).add(lease);
    _loadMoreErrors.remove(period);
    notifyListeners();
    try {
      final page = await loader(sessionToken, period, cursor);
      if (generation != _runGeneration ||
          !_isCurrentAccount(sessionToken, appUserId) ||
          requestPeriodScope != leaderboardPeriodScope(period, _clock()) ||
          _snapshotPeriodScopes[period] != requestPeriodScope ||
          _snapshots[period]?.nextCursor != cursor) {
        _discardSnapshotForExpiredScope(period);
        return false;
      }
      final merged = _appendPage(current, page);
      _snapshots[period] = merged;
      _snapshotPeriodScopes[period] = requestPeriodScope;
      if (_lastPeriod == period) _snapshot = merged;
      return true;
    } catch (error) {
      if (requestPeriodScope != leaderboardPeriodScope(period, _clock())) {
        _discardSnapshotForExpiredScope(period);
        return false;
      }
      if (generation == _runGeneration &&
          _isCurrentAccount(sessionToken, appUserId)) {
        _loadMoreErrors[period] = _mapError(error);
      }
      return false;
    } finally {
      final leases = _loadMoreLeases[period];
      leases?.remove(lease);
      if (leases?.isEmpty ?? false) {
        _loadMoreLeases.remove(period);
      }
      notifyListeners();
    }
  }

  Future<bool> join(LeaderboardIdentityChoice choice) =>
      _runIdentityMutation(choice, _joinIdentity);

  Future<bool> updateIdentity(LeaderboardIdentityChoice choice) =>
      _runIdentityMutation(choice, _updateIdentity);

  Future<bool> leave() async {
    final session = _sessionProvider();
    if (session == null) return false;
    return _run(
      (generation) async {
        try {
          await _leave(session.sessionToken);
        } catch (error) {
          if (_isCurrentAccountRun(
                generation,
                session.sessionToken,
                session.appUserId,
              ) &&
              _invalidatesHomeRank(error)) {
            _clearAllHomeRanksForAccount(session.appUserId);
          }
          rethrow;
        }
        if (_isCurrentAccountRun(
          generation,
          session.sessionToken,
          session.appUserId,
        )) {
          _clearAllHomeRanksForAccount(session.appUserId);
        }
      },
      isStillRelevant: () =>
          _isCurrentAccount(session.sessionToken, session.appUserId),
    );
  }

  Future<bool> reportUser(
    String userId,
    LeaderboardReportType type,
    LeaderboardReportReason reason,
  ) async {
    final command = _reportUser;
    final session = _sessionProvider();
    if (command == null || session == null || session.appUserId == userId) {
      return false;
    }
    return _runModeration(
      session,
      userId,
      () => command(session.sessionToken, userId, type, reason),
    );
  }

  Future<bool> blockUser(String userId) async {
    final command = _blockUser;
    final session = _sessionProvider();
    if (command == null || session == null || session.appUserId == userId) {
      return false;
    }
    return _runModeration(
      session,
      userId,
      () => command(session.sessionToken, userId),
    );
  }

  Future<void> loadBlockedUsers() async {
    final loader = _loadBlockedUsers;
    final session = _sessionProvider();
    final generation = ++_blockedUsersGeneration;
    if (loader == null || session == null) {
      _blockedUsers = const [];
      _blockedUsersError = null;
      _blockedUsersBusy = false;
      notifyListeners();
      return;
    }
    _blockedUsersBusy = true;
    _blockedUsersError = null;
    notifyListeners();
    try {
      final users = await loader(session.sessionToken);
      if (_isCurrentBlockedUsersRun(generation, session)) {
        _blockedUsers = List.unmodifiable(users);
      }
    } catch (error) {
      if (_isCurrentBlockedUsersRun(generation, session)) {
        _blockedUsersError = _mapError(error);
      }
    } finally {
      if (generation == _blockedUsersGeneration) {
        _blockedUsersBusy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> unblockUser(String userId) async {
    final command = _unblockUser;
    final session = _sessionProvider();
    if (command == null || session == null || session.appUserId == userId) {
      return false;
    }
    final generation = ++_blockedUsersGeneration;
    _blockedUsersBusy = true;
    _blockedUsersError = null;
    notifyListeners();
    try {
      await command(session.sessionToken, userId);
      if (!_isCurrentBlockedUsersRun(generation, session)) return false;
      _blockedUsers = List.unmodifiable(
        _blockedUsers.where((user) => user.userId != userId),
      );
      return true;
    } catch (error) {
      if (_isCurrentBlockedUsersRun(generation, session)) {
        _blockedUsersError = _mapError(error);
      }
      return false;
    } finally {
      if (generation == _blockedUsersGeneration) {
        _blockedUsersBusy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _runModeration(
    SavedAccountSession session,
    String userId,
    Future<void> Function() command,
  ) => _run(
    (generation) async {
      await command();
      if (_isCurrentAccountRun(
        generation,
        session.sessionToken,
        session.appUserId,
      )) {
        _removeUserFromSnapshots(userId);
      }
    },
    isStillRelevant: () =>
        _isCurrentAccount(session.sessionToken, session.appUserId),
  );

  void _removeUserFromSnapshots(String userId) {
    _discardExpiredSnapshots();
    for (final entry in _snapshots.entries.toList()) {
      final current = entry.value;
      _snapshots[entry.key] = LeaderboardSnapshot(
        period: current.period,
        metric: current.metric,
        metricUnit: current.metricUnit,
        exerciseType: current.exerciseType,
        isJoined: current.isJoined,
        anonymousAvatarKey: current.anonymousAvatarKey,
        canJoin: current.canJoin,
        identity: current.identity,
        nextCursor: current.nextCursor,
        frozenTotalValue: current.frozenTotalValue,
        myExerciseCounts: current.myExerciseCounts,
        top: current.top.where((row) => row.userId != userId).toList(),
        me: current.me?.userId == userId ? null : current.me,
      );
    }
    _snapshot = _snapshotForCurrentScope(_lastPeriod);
  }

  Future<bool> _runIdentityMutation(
    LeaderboardIdentityChoice choice,
    LeaderboardIdentityCommand command,
  ) async {
    final session = _sessionProvider();
    if (session == null) return false;
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    var refreshed = false;
    final completed = await _run((generation) async {
      final periodLoadLeases = <LeaderboardPeriod, _PeriodLoadLease>{};
      try {
        await command(sessionToken, choice);
        if (!_isCurrentAccountRun(generation, sessionToken, appUserId)) {
          return;
        }
        final requestPeriodScopes = <LeaderboardPeriod, String>{
          for (final period in LeaderboardPeriod.values)
            period: leaderboardPeriodScope(period, _clock()),
        };
        for (final period in LeaderboardPeriod.values) {
          periodLoadLeases[period] = _beginPeriodLoad(
            period,
            generation,
            appUserId,
          );
        }
        notifyListeners();
        final results = await Future.wait([
          for (final period in LeaderboardPeriod.values)
            _loadPeriod(sessionToken, period, requestPeriodScopes[period]!),
        ]);
        if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
          final currentResults = <_LeaderboardPeriodResult>[];
          for (final result in results) {
            if (result.requestPeriodScope !=
                leaderboardPeriodScope(result.period, _clock())) {
              _discardSnapshotForExpiredScope(result.period);
            } else {
              currentResults.add(result);
            }
          }
          _LeaderboardPeriodResult? refreshError;
          for (final result in currentResults) {
            if (result.error != null) {
              refreshError = result;
              break;
            }
          }
          if (refreshError != null) {
            if (currentResults.any((result) => result.invalidatesHomeRank)) {
              _clearAllHomeRanksForAccount(appUserId);
            }
            _error = refreshError.error;
            return;
          }
          var acceptedAnySnapshot = false;
          for (final result in currentResults) {
            final snapshot = result.snapshot!;
            acceptedAnySnapshot =
                _applyAuthoritativeSnapshot(
                  period: result.period,
                  snapshot: snapshot,
                  appUserId: appUserId,
                  requestPeriodScope: result.requestPeriodScope,
                ) ||
                acceptedAnySnapshot;
          }
          _snapshot = _snapshotForCurrentScope(_lastPeriod);
          refreshed = acceptedAnySnapshot;
        }
      } catch (error) {
        if (_isCurrentAccountRun(generation, sessionToken, appUserId) &&
            _invalidatesHomeRank(error)) {
          _clearAllHomeRanksForAccount(appUserId);
        }
        rethrow;
      } finally {
        for (final entry in periodLoadLeases.entries) {
          _endPeriodLoad(entry.key, entry.value);
        }
      }
    }, isStillRelevant: () => _isCurrentAccount(sessionToken, appUserId));
    return completed && refreshed;
  }

  Future<bool> _run(
    Future<void> Function(int generation) action, {
    bool Function()? isStillRelevant,
  }) async {
    final generation = ++_runGeneration;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action(generation);
    } catch (error) {
      if (generation == _runGeneration &&
          (isStillRelevant == null || isStillRelevant())) {
        // Surface a stable error code only. The UI maps it to localized text;
        // raw exception strings are never rendered to the user.
        _error = _mapError(error);
      }
      return false;
    } finally {
      if (generation == _runGeneration) {
        _busy = false;
        notifyListeners();
      }
    }
    return true;
  }

  bool _isCurrentAccount(String sessionToken, String appUserId) {
    final currentSession = _sessionProvider();
    return currentSession?.sessionToken == sessionToken &&
        currentSession?.appUserId == appUserId;
  }

  bool _isCurrentBlockedUsersRun(int generation, SavedAccountSession session) =>
      generation == _blockedUsersGeneration &&
      _isCurrentAccount(session.sessionToken, session.appUserId);

  bool _isCurrentAccountRun(
    int generation,
    String sessionToken,
    String appUserId,
  ) =>
      generation == _runGeneration &&
      _isCurrentAccount(sessionToken, appUserId);

  LeaderboardSnapshot _appendPage(
    LeaderboardSnapshot current,
    LeaderboardSnapshot page,
  ) {
    final userIds = current.top.map((row) => row.userId).toSet();
    return LeaderboardSnapshot(
      period: current.period,
      metric: current.metric,
      metricUnit: current.metricUnit,
      exerciseType: current.exerciseType,
      isJoined: current.isJoined,
      anonymousAvatarKey: current.anonymousAvatarKey,
      canJoin: current.canJoin,
      identity: current.identity,
      nextCursor: page.nextCursor,
      frozenTotalValue: current.frozenTotalValue,
      myExerciseCounts: current.myExerciseCounts,
      top: [
        ...current.top,
        ...page.top.where((row) => userIds.add(row.userId)),
      ],
      me: current.me,
    );
  }

  String _mapError(Object error) {
    if (error is MembershipApiException) {
      if (error.errorCode == 'premium_required') {
        return LeaderboardErrorCode.premiumRequired;
      }
      if (error.errorCode == 'membership_sync_unavailable') {
        return LeaderboardErrorCode.membershipSyncUnavailable;
      }
      if (error.errorCode == 'invalid_identity_mode') {
        return LeaderboardErrorCode.invalidIdentityMode;
      }
      if (error.errorCode == 'leaderboard_not_joined') {
        return LeaderboardErrorCode.notJoined;
      }
      return LeaderboardErrorCode.requestFailed;
    }
    return LeaderboardErrorCode.unexpected;
  }

  bool _invalidatesHomeRank(Object error) =>
      error is MembershipApiException &&
      (error.errorCode == 'premium_required' ||
          error.errorCode == 'leaderboard_not_joined');
}

class _LeaderboardPeriodResult {
  const _LeaderboardPeriodResult({
    required this.period,
    required this.requestPeriodScope,
    this.snapshot,
    this.error,
    this.invalidatesHomeRank = false,
  });

  final LeaderboardPeriod period;
  final String requestPeriodScope;
  final LeaderboardSnapshot? snapshot;
  final String? error;
  final bool invalidatesHomeRank;
}

class _PeriodLoadLease {
  const _PeriodLoadLease({required this.generation, required this.appUserId});

  final int generation;
  final String appUserId;
}

class _LoadMoreLease {
  const _LoadMoreLease({
    required this.generation,
    required this.sessionToken,
    required this.appUserId,
    required this.requestPeriodScope,
    required this.cursor,
  });

  final int generation;
  final String sessionToken;
  final String appUserId;
  final String requestPeriodScope;
  final String cursor;
}
