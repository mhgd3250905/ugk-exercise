enum LeaderboardPeriod { day, week }

enum LeaderboardIdentityMode { profile, custom, anonymous }

class LeaderboardIdentityChoice {
  const LeaderboardIdentityChoice({
    required this.mode,
    this.nickname,
    this.avatarKey,
  });

  final LeaderboardIdentityMode mode;
  final String? nickname;
  final String? avatarKey;

  static LeaderboardIdentityChoice fromJson(Map<String, Object?> json) {
    final modeName = json['mode'];
    if (modeName is! String) {
      throw const FormatException('Invalid leaderboard identity');
    }
    final mode = switch (modeName) {
      'profile' => LeaderboardIdentityMode.profile,
      'custom' => LeaderboardIdentityMode.custom,
      'anonymous' => LeaderboardIdentityMode.anonymous,
      _ => throw const FormatException('Invalid leaderboard identity'),
    };
    if (mode != LeaderboardIdentityMode.custom) {
      return LeaderboardIdentityChoice(mode: mode);
    }
    final nickname = json['nickname'];
    final avatarKey = json['avatarKey'];
    if (nickname is! String ||
        nickname.trim().isEmpty ||
        avatarKey is! String ||
        avatarKey.trim().isEmpty) {
      throw const FormatException('Invalid leaderboard identity');
    }
    return LeaderboardIdentityChoice(
      mode: mode,
      nickname: nickname,
      avatarKey: avatarKey,
    );
  }

  Map<String, Object> toJson() {
    if (mode != LeaderboardIdentityMode.custom) {
      return {'mode': mode.name};
    }
    final nickname = this.nickname;
    final avatarKey = this.avatarKey;
    if (nickname == null ||
        nickname.trim().isEmpty ||
        avatarKey == null ||
        avatarKey.trim().isEmpty) {
      throw const FormatException('Invalid leaderboard identity');
    }
    return {'mode': mode.name, 'nickname': nickname, 'avatarKey': avatarKey};
  }
}

class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.avatarKey,
    this.avatarUrl,
    required this.totalValue,
  });

  final int rank;
  final String userId;
  final String? nickname;
  final String? avatarKey;
  final String? avatarUrl;
  final int totalValue;

  static LeaderboardRow fromJson(Map<String, Object?> json) {
    return LeaderboardRow(
      rank: json['rank']! as int,
      userId: json['userId']! as String,
      nickname: json['nickname'] as String?,
      avatarKey: json['avatarKey'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      totalValue: json['totalValue']! as int,
    );
  }
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.period,
    required this.exerciseType,
    required this.isJoined,
    this.anonymousAvatarKey = 'ring-green',
    this.canJoin = true,
    this.identity,
    required this.top,
    required this.me,
  });

  final LeaderboardPeriod period;
  final String exerciseType;
  final bool isJoined;
  final String anonymousAvatarKey;
  final bool canJoin;
  final LeaderboardIdentityChoice? identity;
  final List<LeaderboardRow> top;
  final LeaderboardRow? me;

  static LeaderboardSnapshot fromJson(Map<String, Object?> json) {
    final periodName = json['period']! as String;
    final isJoined = json['isJoined'];
    final canJoin = json['canJoin'];
    final anonymousAvatarKey = json['anonymousAvatarKey'];
    if (isJoined is! bool ||
        (canJoin != null && canJoin is! bool) ||
        anonymousAvatarKey is! String ||
        !_anonymousAvatarKeys.contains(anonymousAvatarKey)) {
      throw const FormatException('Invalid leaderboard response');
    }
    return LeaderboardSnapshot(
      period: LeaderboardPeriod.values.byName(periodName),
      exerciseType: json['exerciseType']! as String,
      isJoined: isJoined,
      anonymousAvatarKey: anonymousAvatarKey,
      canJoin: canJoin as bool? ?? true,
      identity: json['identity'] == null
          ? null
          : LeaderboardIdentityChoice.fromJson(
              Map<String, Object?>.from(json['identity']! as Map),
            ),
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

const _anonymousAvatarKeys = {
  'ring-green',
  'ring-lime',
  'ring-sky',
  'ring-yellow',
  'ring-coral',
};
