enum LeaderboardPeriod { day, week }

class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.avatarKey,
    required this.totalValue,
  });

  final int rank;
  final String userId;
  final String? nickname;
  final String? avatarKey;
  final int totalValue;

  static LeaderboardRow fromJson(Map<String, Object?> json) {
    return LeaderboardRow(
      rank: json['rank']! as int,
      userId: json['userId']! as String,
      nickname: json['nickname'] as String?,
      avatarKey: json['avatarKey'] as String?,
      totalValue: json['totalValue']! as int,
    );
  }
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.period,
    required this.exerciseType,
    required this.isJoined,
    required this.top,
    required this.me,
  });

  final LeaderboardPeriod period;
  final String exerciseType;
  final bool isJoined;
  final List<LeaderboardRow> top;
  final LeaderboardRow? me;

  static LeaderboardSnapshot fromJson(Map<String, Object?> json) {
    final periodName = json['period']! as String;
    final isJoined = json['isJoined'];
    if (isJoined is! bool) {
      throw const FormatException('Invalid leaderboard response');
    }
    return LeaderboardSnapshot(
      period: LeaderboardPeriod.values.byName(periodName),
      exerciseType: json['exerciseType']! as String,
      isJoined: isJoined,
      top: [
        for (final item in json['top']! as List<Object?>)
          LeaderboardRow.fromJson(Map<String, Object?>.from(item! as Map)),
      ],
      me: json['me'] == null
          ? null
          : LeaderboardRow.fromJson(
              Map<String, Object?>.from(json['me']! as Map),
            ),
    );
  }
}
