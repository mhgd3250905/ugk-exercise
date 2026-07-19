import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../product/leaderboard_home_rank.dart';
import '../product/leaderboard_models.dart';

abstract class LeaderboardHomeRankStore {
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  });

  Future<void> save(LeaderboardHomeRank rank);

  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  });

  Future<void> clearForAccount(String appUserId);
}

class SecureLeaderboardHomeRankStore implements LeaderboardHomeRankStore {
  SecureLeaderboardHomeRankStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'ugk_leaderboard_home_rank_v1';

  final FlutterSecureStorage _storage;

  static String keyFor({
    required String appUserId,
    required LeaderboardPeriod period,
  }) {
    final encodedAppUserId = base64UrlEncode(
      utf8.encode(appUserId),
    ).replaceAll('=', '');
    return '${_keyPrefix}_${encodedAppUserId}_${period.name}';
  }

  @override
  Future<LeaderboardHomeRank?> load({
    required String appUserId,
    required LeaderboardPeriod period,
    required String periodScope,
  }) async {
    try {
      final value = await _storage.read(
        key: keyFor(appUserId: appUserId, period: period),
      );
      if (value == null) return null;
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final rank = LeaderboardHomeRank.fromJson(
        Map<String, Object?>.from(decoded),
      );
      return rank.ownerAppUserId == appUserId &&
              rank.period == period &&
              rank.periodScope == periodScope
          ? rank
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LeaderboardHomeRank rank) {
    return _storage.write(
      key: keyFor(appUserId: rank.ownerAppUserId, period: rank.period),
      value: jsonEncode(rank.toJson()),
    );
  }

  @override
  Future<void> clear({
    required String appUserId,
    required LeaderboardPeriod period,
  }) {
    return _storage.delete(
      key: keyFor(appUserId: appUserId, period: period),
    );
  }

  @override
  Future<void> clearForAccount(String appUserId) async {
    for (final period in LeaderboardPeriod.values) {
      await clear(appUserId: appUserId, period: period);
    }
  }
}

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
