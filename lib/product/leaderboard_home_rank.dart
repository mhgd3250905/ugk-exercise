import 'leaderboard_models.dart';

const leaderboardPointsMetric = 'pushup_points_v1';
const _leaderboardHomeRankSchemaVersion = 1;

class LeaderboardHomeRank {
  const LeaderboardHomeRank({
    required this.ownerAppUserId,
    required this.period,
    required this.periodScope,
    required this.rank,
    required this.totalValue,
    this.metric = leaderboardPointsMetric,
  }) : assert(ownerAppUserId != ''),
       assert(periodScope != ''),
       assert(rank >= 1),
       assert(totalValue >= 0),
       assert(metric == leaderboardPointsMetric);

  final String ownerAppUserId;
  final LeaderboardPeriod period;
  final String periodScope;
  final int rank;
  final int totalValue;
  final String metric;

  Map<String, Object> toJson() => {
    'schemaVersion': _leaderboardHomeRankSchemaVersion,
    'ownerAppUserId': ownerAppUserId,
    'period': period.name,
    'periodScope': periodScope,
    'rank': rank,
    'totalValue': totalValue,
    'metric': metric,
  };

  static LeaderboardHomeRank fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final ownerAppUserId = json['ownerAppUserId'];
    final periodName = json['period'];
    final periodScope = json['periodScope'];
    final rank = json['rank'];
    final totalValue = json['totalValue'];
    final metric = json['metric'];
    if (schemaVersion != _leaderboardHomeRankSchemaVersion ||
        ownerAppUserId is! String ||
        ownerAppUserId.isEmpty ||
        periodScope is! String ||
        periodScope.isEmpty ||
        rank is! int ||
        rank < 1 ||
        totalValue is! int ||
        totalValue < 0 ||
        metric is! String ||
        metric != leaderboardPointsMetric) {
      throw const FormatException('Invalid leaderboard home rank');
    }
    final period = switch (periodName) {
      'day' => LeaderboardPeriod.day,
      'week' => LeaderboardPeriod.week,
      _ => throw const FormatException('Invalid leaderboard home rank'),
    };
    return LeaderboardHomeRank(
      ownerAppUserId: ownerAppUserId,
      period: period,
      periodScope: periodScope,
      rank: rank,
      totalValue: totalValue,
      metric: metric,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LeaderboardHomeRank &&
        other.ownerAppUserId == ownerAppUserId &&
        other.period == period &&
        other.periodScope == periodScope &&
        other.rank == rank &&
        other.totalValue == totalValue &&
        other.metric == metric;
  }

  @override
  int get hashCode => Object.hash(
    ownerAppUserId,
    period,
    periodScope,
    rank,
    totalValue,
    metric,
  );
}

String leaderboardPeriodScope(LeaderboardPeriod period, DateTime time) {
  final shanghai = time.toUtc().add(const Duration(hours: 8));
  final day = DateTime.utc(shanghai.year, shanghai.month, shanghai.day);
  return switch (period) {
    LeaderboardPeriod.day => _formatDate(day),
    LeaderboardPeriod.week => _formatDate(
      day.subtract(Duration(days: day.weekday - DateTime.monday)),
    ),
  };
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
