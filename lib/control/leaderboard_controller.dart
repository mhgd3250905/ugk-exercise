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
  static const nicknameTaken = 'leaderboard_nickname_taken';
  static const invalidNickname = 'leaderboard_invalid_nickname';
  static const invalidAvatarKey = 'leaderboard_invalid_avatar_key';
  static const invalidIdentityMode = 'leaderboard_invalid_identity_mode';
  static const notJoined = 'leaderboard_not_joined';
  static const unexpected = 'leaderboard_unexpected';
}

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required LeaderboardSessionProvider sessionProvider,
    required LeaderboardLoad load,
    LeaderboardCommand? join,
    LeaderboardIdentityCommand? joinIdentity,
    LeaderboardIdentityCommand? updateIdentity,
    required LeaderboardCommand leave,
  }) : assert(join != null || joinIdentity != null),
       _sessionProvider = sessionProvider,
       _load = load,
       _joinIdentity =
           joinIdentity ?? ((sessionToken, _) => join!(sessionToken)),
       _updateIdentity = updateIdentity ?? _unsupportedIdentityUpdate,
       _leave = leave;

  final LeaderboardSessionProvider _sessionProvider;
  final LeaderboardLoad _load;
  final LeaderboardIdentityCommand _joinIdentity;
  final LeaderboardIdentityCommand _updateIdentity;
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
    await _run((generation) async {
      final snapshot = await _load(sessionToken, period);
      if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        _snapshot = snapshot;
      }
    }, isStillRelevant: () => _isCurrentAccount(sessionToken, appUserId));
  }

  Future<bool> join([
    LeaderboardIdentityChoice choice = const LeaderboardIdentityChoice(
      mode: LeaderboardIdentityMode.anonymous,
    ),
  ]) => _runIdentityMutation(choice, _joinIdentity);

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
    final period = _lastPeriod;
    var refreshed = false;
    final completed = await _run((generation) async {
      await command(sessionToken, choice);
      if (!_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        return;
      }
      final snapshot = await _load(sessionToken, period);
      if (_isCurrentAccountRun(generation, sessionToken, appUserId)) {
        _snapshot = snapshot;
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

  String _mapError(Object error) {
    if (error is MembershipApiException) {
      if (error.errorCode == 'premium_required') {
        return LeaderboardErrorCode.premiumRequired;
      }
      if (error.errorCode == 'nickname_taken') {
        return LeaderboardErrorCode.nicknameTaken;
      }
      if (error.errorCode == 'invalid_nickname') {
        return LeaderboardErrorCode.invalidNickname;
      }
      if (error.errorCode == 'invalid_avatar_key') {
        return LeaderboardErrorCode.invalidAvatarKey;
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

Future<void> _unsupportedIdentityUpdate(
  String _,
  LeaderboardIdentityChoice __,
) => throw UnsupportedError('Leaderboard identity update is not configured');
