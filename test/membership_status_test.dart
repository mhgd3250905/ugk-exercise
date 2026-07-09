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
}
