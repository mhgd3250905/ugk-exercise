import 'package:test/test.dart';
import 'package:ugk_exercise/product/membership_status.dart';

void main() {
  test('membership is active only when server says active and expiry is future', () {
    final now = DateTime(2026, 7, 9, 10);
    final status = MembershipStatus(
      entitlement: 'premium',
      isActive: true,
      expiresAt: DateTime(2026, 7, 10),
      source: 'revenuecat_google_play',
    );

    expect(status.activeAt(now), isTrue);
    expect(status.activeAt(DateTime(2026, 7, 11)), isFalse);
  });

  test('membership parses missing expiry as inactive unless active is true', () {
    final status = MembershipStatus.fromJson({
      'entitlement': 'premium',
      'isActive': false,
      'expiresAt': null,
      'source': 'revenuecat_google_play',
    });

    expect(status.isActive, isFalse);
    expect(status.expiresAt, isNull);
  });

  test('app user parses from auth response', () {
    final user = AppUser.fromJson({
      'id': 'user_1',
      'displayName': '训练者',
      'email': 'a@example.com',
      'avatarUrl': 'https://example.com/a.png',
    });

    expect(user.id, 'user_1');
    expect(user.displayName, '训练者');
    expect(user.email, 'a@example.com');
    expect(user.avatarUrl, 'https://example.com/a.png');
  });

  test('AppUser parses public nickname and avatar key with legacy fallback', () {
    final user = AppUser.fromJson({
      'id': 'user_1',
      'displayName': 'Google Name',
      'email': 'a@example.com',
      'avatarUrl': 'https://example.com/a.png',
      'nickname': '训练者 01',
      'avatarKey': 'ring-green',
    });

    expect(user.publicDisplayName, '训练者 01');
    expect(user.avatarKey, 'ring-green');
  });

  test('AppUser falls back to display name when nickname is absent', () {
    final user = AppUser.fromJson({
      'id': 'user_1',
      'displayName': 'Google Name',
      'email': 'a@example.com',
      'avatarUrl': null,
    });

    expect(user.publicDisplayName, 'Google Name');
    expect(user.avatarKey, isNull);
  });

  test('AppUser falls back to display name when nickname is blank', () {
    final user = AppUser.fromJson({
      'id': 'user_1',
      'displayName': 'Google Name',
      'email': 'a@example.com',
      'avatarUrl': null,
      'nickname': '   ',
    });

    expect(user.publicDisplayName, 'Google Name');
  });

  test('AppUser persists custom avatar governance and reads legacy cache', () {
    final user = AppUser.fromJson({
      'id': 'user_1',
      'displayName': 'Google Name',
      'email': 'a@example.com',
      'avatarUrl': 'https://example.com/google.png',
      'customAvatarUrl': 'https://api.example.com/avatars/version.jpg',
      'avatarPolicyVersion': '2026-07-14',
      'avatarPolicyAccepted': true,
      'avatarUploadSuspended': true,
    });

    expect(user.customAvatarUrl, contains('/avatars/version.jpg'));
    expect(user.avatarPolicyVersion, '2026-07-14');
    expect(user.avatarPolicyAccepted, isTrue);
    expect(user.avatarUploadSuspended, isTrue);
    expect(AppUser.fromJson(user.toJson()).toJson(), user.toJson());

    final legacy = AppUser.fromJson({
      'id': 'legacy',
      'displayName': 'Legacy',
      'email': '',
      'avatarUrl': null,
    });
    expect(legacy.customAvatarUrl, isNull);
    expect(legacy.avatarPolicyVersion, isNull);
    expect(legacy.avatarPolicyAccepted, isFalse);
    expect(legacy.avatarUploadSuspended, isFalse);
  });
}
