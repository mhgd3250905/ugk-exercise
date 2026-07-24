import 'package:ugk_exercise/platform/leaderboard_home_rank_store.dart';
import 'package:ugk_exercise/product/leaderboard_home_rank.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';

class MemoryLeaderboardHomeRankStore implements LeaderboardHomeRankStore {
  final _ranks = <String, LeaderboardHomeRank>{};

  @override
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  }) async {
    final rank = _ranks[_keyFor(appUserId, period)];
    return rank?.periodScope == periodScope ? rank : null;
  }

  @override
  Future<void> save(LeaderboardHomeRank rank) async {
    _ranks[_keyFor(rank.ownerAppUserId, rank.period)] = rank;
  }

  @override
  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  }) async {
    _ranks.remove(_keyFor(appUserId, period));
  }

  @override
  Future<void> clearForAccount(String appUserId) async {
    _ranks.removeWhere((_, rank) => rank.ownerAppUserId == appUserId);
  }

  String _keyFor(String appUserId, LeaderboardPeriod period) =>
      '$appUserId:${period.name}';
}
