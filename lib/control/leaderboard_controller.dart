import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
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

/// Stable error codes surfaced by [LeaderboardController.error]. The UI maps
/// these to localized strings and never renders a raw exception message.
class LeaderboardErrorCode {
  const LeaderboardErrorCode._();

  static const requestFailed = 'leaderboard_request_failed';
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
  }) : _sessionProvider = sessionProvider,
       _load = load,
       _loadMore = loadMore,
       _joinIdentity = joinIdentity,
       _updateIdentity = updateIdentity,
       _leave = leave;

  final LeaderboardSessionProvider _sessionProvider;
  final LeaderboardLoad _load;
  final LeaderboardLoadMore? _loadMore;
  final LeaderboardIdentityCommand _joinIdentity;
  final LeaderboardIdentityCommand _updateIdentity;
  final LeaderboardCommand _leave;

  LeaderboardSnapshot? _snapshot;
  final _snapshots = <LeaderboardPeriod, LeaderboardSnapshot>{};
  final _periodErrors = <LeaderboardPeriod, String>{};
  final _loadingMorePeriods = <LeaderboardPeriod>{};
  final _loadMoreErrors = <LeaderboardPeriod, String>{};
  var _busy = false;
  String? _error;
  var _runGeneration = 0;
  LeaderboardPeriod _lastPeriod = LeaderboardPeriod.day;

  LeaderboardSnapshot? get snapshot => _snapshot;
  LeaderboardSnapshot? snapshotFor(LeaderboardPeriod period) =>
      _snapshots[period];
  String? errorFor(LeaderboardPeriod period) => _periodErrors[period];
  bool isLoadingMore(LeaderboardPeriod period) =>
      _loadingMorePeriods.contains(period);
  String? loadMoreErrorFor(LeaderboardPeriod period) => _loadMoreErrors[period];
  bool get busy => _busy;
  String? get error => _error;
  SavedAccountSession? get currentSession => _sessionProvider();
  AppUser? get currentUser => currentSession?.user;

  /// Called when the account may have changed (sign-in / sign-out / switch).
  /// Immediately clears any snapshot/error belonging to the previous account,
  /// then reloads the last-viewed period for the current account. A signed-out
  /// state clears everything and issues no request. Clearing happens BEFORE the
  /// new load resolves so a stale snapshot from the previous account is never
  /// visible during the switch.
  Future<void> reloadForCurrentAccount() async {
    final session = _sessionProvider();
    _runGeneration++;
    _snapshot = null;
    _snapshots.clear();
    _periodErrors.clear();
    _loadingMorePeriods.clear();
    _loadMoreErrors.clear();
    _error = null;
    _busy = session != null;
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
      _snapshot = null;
      _snapshots.clear();
      _periodErrors.clear();
      _loadingMorePeriods.clear();
      _loadMoreErrors.clear();
      _error = null;
      _busy = false;
      notifyListeners();
      return;
    }
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    await _run((generation) async {
      final snapshot = await _load(sessionToken, period);
      if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        _snapshot = snapshot;
        _snapshots[period] = snapshot;
        _periodErrors.remove(period);
      }
    }, isStillRelevant: () => _isCurrentAccount(sessionToken, appUserId));
  }

  void selectPeriod(LeaderboardPeriod period) {
    if (_lastPeriod == period) return;
    _lastPeriod = period;
    _snapshot = _snapshots[period];
    _error = _periodErrors[period];
    notifyListeners();
  }

  Future<void> refreshAll() async {
    final session = _sessionProvider();
    if (session == null) {
      _runGeneration++;
      _snapshot = null;
      _snapshots.clear();
      _periodErrors.clear();
      _loadingMorePeriods.clear();
      _loadMoreErrors.clear();
      _error = null;
      _busy = false;
      notifyListeners();
      return;
    }
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    final generation = ++_runGeneration;
    _busy = true;
    _error = null;
    _periodErrors.clear();
    _loadMoreErrors.clear();
    notifyListeners();
    try {
      final results = await Future.wait([
        for (final period in LeaderboardPeriod.values)
          _loadPeriod(sessionToken, period),
      ]);
      if (!_isCurrentAccountRun(generation, sessionToken, appUserId)) return;
      for (final result in results) {
        final snapshot = result.snapshot;
        if (snapshot != null) {
          _snapshots[result.period] = snapshot;
        } else {
          _periodErrors[result.period] = result.error!;
        }
      }
      _snapshot = _snapshots[_lastPeriod];
      _error = _periodErrors[_lastPeriod];
    } finally {
      if (generation == _runGeneration) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<_LeaderboardPeriodResult> _loadPeriod(
    String sessionToken,
    LeaderboardPeriod period,
  ) async {
    try {
      return _LeaderboardPeriodResult(
        period: period,
        snapshot: await _load(sessionToken, period),
      );
    } catch (error) {
      return _LeaderboardPeriodResult(period: period, error: _mapError(error));
    }
  }

  Future<bool> loadMore(LeaderboardPeriod period) async {
    final loader = _loadMore;
    final current = _snapshots[period];
    final cursor = current?.nextCursor;
    final session = _sessionProvider();
    if (loader == null ||
        current == null ||
        cursor == null ||
        session == null ||
        _loadingMorePeriods.contains(period)) {
      return false;
    }
    final generation = _runGeneration;
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    _loadingMorePeriods.add(period);
    _loadMoreErrors.remove(period);
    notifyListeners();
    try {
      final page = await loader(sessionToken, period, cursor);
      if (generation != _runGeneration ||
          !_isCurrentAccount(sessionToken, appUserId) ||
          _snapshots[period]?.nextCursor != cursor) {
        return false;
      }
      final merged = _appendPage(current, page);
      _snapshots[period] = merged;
      if (_lastPeriod == period) _snapshot = merged;
      return true;
    } catch (error) {
      if (generation == _runGeneration &&
          _isCurrentAccount(sessionToken, appUserId)) {
        _loadMoreErrors[period] = _mapError(error);
      }
      return false;
    } finally {
      _loadingMorePeriods.remove(period);
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
    return _run((_) => _leave(session.sessionToken));
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
      await command(sessionToken, choice);
      if (!_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        return;
      }
      final snapshots = await Future.wait([
        for (final period in LeaderboardPeriod.values)
          _load(sessionToken, period),
      ]);
      if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        for (final snapshot in snapshots) {
          _snapshots[snapshot.period] = snapshot;
          _periodErrors.remove(snapshot.period);
        }
        _snapshot = _snapshots[_lastPeriod];
        refreshed = true;
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
      exerciseType: current.exerciseType,
      isJoined: current.isJoined,
      anonymousAvatarKey: current.anonymousAvatarKey,
      canJoin: current.canJoin,
      identity: current.identity,
      nextCursor: page.nextCursor,
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
}

class _LeaderboardPeriodResult {
  const _LeaderboardPeriodResult({
    required this.period,
    this.snapshot,
    this.error,
  });

  final LeaderboardPeriod period;
  final LeaderboardSnapshot? snapshot;
  final String? error;
}
