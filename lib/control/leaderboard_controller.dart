import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../product/leaderboard_models.dart';

typedef LeaderboardSessionProvider = SavedAccountSession? Function();
typedef LeaderboardLoad =
    Future<LeaderboardSnapshot> Function(
      String sessionToken,
      LeaderboardPeriod period,
    );
typedef LeaderboardCommand = Future<void> Function(String sessionToken);

/// Stable error codes surfaced by [LeaderboardController.error]. The UI maps
/// these to localized strings and never renders a raw exception message.
class LeaderboardErrorCode {
  const LeaderboardErrorCode._();

  static const requestFailed = 'leaderboard_request_failed';
  static const premiumRequired = 'leaderboard_premium_required';
  static const unexpected = 'leaderboard_unexpected';
}

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required LeaderboardSessionProvider sessionProvider,
    required LeaderboardLoad load,
    required LeaderboardCommand join,
    required LeaderboardCommand leave,
  }) : _sessionProvider = sessionProvider,
       _load = load,
       _join = join,
       _leave = leave;

  final LeaderboardSessionProvider _sessionProvider;
  final LeaderboardLoad _load;
  final LeaderboardCommand _join;
  final LeaderboardCommand _leave;

  LeaderboardSnapshot? _snapshot;
  var _busy = false;
  String? _error;
  var _runGeneration = 0;
  LeaderboardPeriod _lastPeriod = LeaderboardPeriod.day;

  LeaderboardSnapshot? get snapshot => _snapshot;
  bool get busy => _busy;
  String? get error => _error;

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
      _error = null;
      _busy = false;
      notifyListeners();
      return;
    }
    final sessionToken = session.sessionToken;
    final appUserId = session.appUserId;
    final generation = _runGeneration + 1;
    await _run(() async {
      try {
        final snapshot = await _load(sessionToken, period);
        final currentSession = _sessionProvider();
        if (generation != _runGeneration ||
            currentSession == null ||
            currentSession.sessionToken != sessionToken ||
            currentSession.appUserId != appUserId) {
          return;
        }
        _snapshot = snapshot;
      } catch (error) {
        final currentSession = _sessionProvider();
        if (generation != _runGeneration ||
            currentSession == null ||
            currentSession.sessionToken != sessionToken ||
            currentSession.appUserId != appUserId) {
          return;
        }
        rethrow;
      }
    });
  }

  Future<bool> join() async {
    final session = _sessionProvider();
    if (session == null) return false;
    return _run(() => _join(session.sessionToken));
  }

  Future<bool> leave() async {
    final session = _sessionProvider();
    if (session == null) return false;
    return _run(() => _leave(session.sessionToken));
  }

  Future<bool> _run(Future<void> Function() action) async {
    final generation = ++_runGeneration;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      if (generation == _runGeneration) {
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

  String _mapError(Object error) {
    if (error is MembershipApiException) {
      if (error.errorCode == 'premium_required') {
        return LeaderboardErrorCode.premiumRequired;
      }
      return LeaderboardErrorCode.requestFailed;
    }
    return LeaderboardErrorCode.unexpected;
  }
}
