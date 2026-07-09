import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../product/leaderboard_models.dart';

typedef LeaderboardSessionProvider = SavedAccountSession? Function();
typedef LeaderboardLoad = Future<LeaderboardSnapshot> Function(
  String sessionToken,
  LeaderboardPeriod period,
);
typedef LeaderboardCommand = Future<void> Function(String sessionToken);

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

  LeaderboardSnapshot? get snapshot => _snapshot;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> load(LeaderboardPeriod period) async {
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

  Future<void> join() async {
    final session = _sessionProvider();
    if (session == null) return;
    await _run(() => _join(session.sessionToken));
  }

  Future<void> leave() async {
    final session = _sessionProvider();
    if (session == null) return;
    await _run(() => _leave(session.sessionToken));
  }

  Future<void> _run(Future<void> Function() action) async {
    final generation = ++_runGeneration;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      if (generation == _runGeneration) {
        _error = error.toString();
      }
    } finally {
      if (generation == _runGeneration) {
        _busy = false;
        notifyListeners();
      }
    }
  }
}
