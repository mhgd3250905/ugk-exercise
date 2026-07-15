import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/startup_preferences.dart';

void main() {
  test(
    'startup preferences persist versioned onboarding and camera notice',
    () async {
      final values = <String, String>{};
      final preferences = StartupPreferences(
        read: (key) async => values[key],
        write: (key, value) async => values[key] = value,
      );

      expect(await preferences.onboardingCompleted(), isFalse);
      expect(await preferences.cameraNoticeAcknowledged(), isFalse);

      await preferences.completeOnboarding();
      await preferences.acknowledgeCameraNotice();

      expect(await preferences.onboardingCompleted(), isTrue);
      expect(await preferences.cameraNoticeAcknowledged(), isTrue);
    },
  );

  test('startup preference read failures do not block app entry', () async {
    final preferences = StartupPreferences(
      read: (_) async => throw StateError('secure storage unavailable'),
      write: (_, __) async {},
    );

    expect(await preferences.onboardingCompleted(), isTrue);
    expect(await preferences.cameraNoticeAcknowledged(), isTrue);
  });
}
