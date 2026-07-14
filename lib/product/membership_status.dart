class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.nickname,
    this.avatarKey,
    this.customAvatarUrl,
    this.avatarPolicyVersion,
    this.avatarPolicyAccepted = false,
    this.avatarUploadSuspended = false,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? nickname;
  final String? avatarKey;
  final String? customAvatarUrl;
  final String? avatarPolicyVersion;
  final bool avatarPolicyAccepted;
  final bool avatarUploadSuspended;

  String get publicDisplayName {
    final value = nickname?.trim();
    return value == null || value.isEmpty ? displayName : value;
  }

  static AppUser fromJson(Map<String, Object?> json) {
    return AppUser(
      id: json['id']! as String,
      displayName: (json['displayName'] as String?) ?? '训练者',
      email: (json['email'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      nickname: json['nickname'] as String?,
      avatarKey: json['avatarKey'] as String?,
      customAvatarUrl: json['customAvatarUrl'] as String?,
      avatarPolicyVersion: json['avatarPolicyVersion'] as String?,
      avatarPolicyAccepted: (json['avatarPolicyAccepted'] as bool?) ?? false,
      avatarUploadSuspended: (json['avatarUploadSuspended'] as bool?) ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'nickname': nickname,
      'avatarKey': avatarKey,
      'customAvatarUrl': customAvatarUrl,
      'avatarPolicyVersion': avatarPolicyVersion,
      'avatarPolicyAccepted': avatarPolicyAccepted,
      'avatarUploadSuspended': avatarUploadSuspended,
    };
  }
}

class MembershipStatus {
  const MembershipStatus({
    required this.entitlement,
    required this.isActive,
    required this.expiresAt,
    required this.source,
  });

  final String entitlement;
  final bool isActive;
  final DateTime? expiresAt;
  final String source;

  static const none = MembershipStatus(
    entitlement: 'premium',
    isActive: false,
    expiresAt: null,
    source: 'none',
  );

  bool activeAt(DateTime now) {
    final expiry = expiresAt;
    return isActive && (expiry == null || expiry.isAfter(now));
  }

  static MembershipStatus fromJson(Map<String, Object?> json) {
    final expiresAt = json['expiresAt'] as String?;
    return MembershipStatus(
      entitlement: (json['entitlement'] as String?) ?? 'premium',
      isActive: (json['isActive'] as bool?) ?? false,
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt).toLocal(),
      source: (json['source'] as String?) ?? 'unknown',
    );
  }
}

class AccountSnapshot {
  const AccountSnapshot({
    required this.sessionToken,
    required this.appUserId,
    required this.user,
    required this.membership,
  });

  final String sessionToken;
  final String appUserId;
  final AppUser user;
  final MembershipStatus membership;
}
