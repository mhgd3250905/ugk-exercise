enum LeaderboardPeriod { day, week }

enum LeaderboardIdentityMode { profile, anonymous }

enum LeaderboardReportType { avatar, user }

enum LeaderboardReportReason {
  nudity,
  violence,
  hate,
  spam,
  impersonation,
  other,
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.nickname,
    required this.avatarKey,
    required this.avatarUrl,
  });

  final String userId;
  final String? nickname;
  final String? avatarKey;
  final String? avatarUrl;

  static BlockedUser fromJson(Map<String, Object?> json) {
    final userId = json['userId'];
    final nickname = json['nickname'];
    final avatarKey = json['avatarKey'];
    final avatarUrl = json['avatarUrl'];
    if (userId is! String ||
        userId.isEmpty ||
        (nickname != null && nickname is! String) ||
        (avatarKey != null && avatarKey is! String) ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const FormatException('Invalid blocked user');
    }
    return BlockedUser(
      userId: userId,
      nickname: nickname as String?,
      avatarKey: avatarKey as String?,
      avatarUrl: avatarUrl as String?,
    );
  }
}

class LeaderboardIdentityChoice {
  const LeaderboardIdentityChoice({required this.mode});

  final LeaderboardIdentityMode mode;

  static LeaderboardIdentityChoice fromJson(Map<String, Object?> json) {
    final modeName = json['mode'];
    if (modeName is! String) {
      throw const FormatException('Invalid leaderboard identity');
    }
    final mode = switch (modeName) {
      'profile' => LeaderboardIdentityMode.profile,
      'anonymous' => LeaderboardIdentityMode.anonymous,
      _ => throw const FormatException('Invalid leaderboard identity'),
    };
    return LeaderboardIdentityChoice(mode: mode);
  }

  Map<String, Object> toJson() => {'mode': mode.name};
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
    this.nextCursor,
    this.frozenTotalValue,
    required this.top,
    required this.me,
  });

  final LeaderboardPeriod period;
  final String exerciseType;
  final bool isJoined;
  final String anonymousAvatarKey;
  final bool canJoin;
  final LeaderboardIdentityChoice? identity;
  final String? nextCursor;
  final int? frozenTotalValue;
  final List<LeaderboardRow> top;
  final LeaderboardRow? me;

  static LeaderboardSnapshot fromJson(Map<String, Object?> json) {
    final periodName = json['period']! as String;
    final isJoined = json['isJoined'];
    final canJoin = json['canJoin'];
    final anonymousAvatarKey = json['anonymousAvatarKey'];
    final nextCursor = json['nextCursor'];
    final frozenTotalValue = json['frozenTotalValue'];
    if (isJoined is! bool ||
        (canJoin != null && canJoin is! bool) ||
        (nextCursor != null && nextCursor is! String) ||
        (frozenTotalValue != null &&
            (frozenTotalValue is! int || frozenTotalValue < 0)) ||
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
      nextCursor: nextCursor as String?,
      frozenTotalValue: frozenTotalValue as int?,
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
