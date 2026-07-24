import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef StartupPreferenceRead = Future<String?> Function(String key);
typedef StartupPreferenceWrite =
    Future<void> Function(String key, String value);

class StartupPreferences {
  StartupPreferences({
    StartupPreferenceRead? read,
    StartupPreferenceWrite? write,
  }) : _read = read ?? _readSecurely,
       _write = write ?? _writeSecurely;

  static const _version = '1';
  static const _onboardingKey = 'ugk_onboarding_version';
  static const _cameraNoticeKey = 'ugk_camera_notice_version';
  static const _storage = FlutterSecureStorage();

  final StartupPreferenceRead _read;
  final StartupPreferenceWrite _write;

  Future<bool> onboardingCompleted() => _completed(_onboardingKey);

  Future<bool> cameraNoticeAcknowledged() => _completed(_cameraNoticeKey);

  Future<void> completeOnboarding() => _save(_onboardingKey);

  Future<void> acknowledgeCameraNotice() => _save(_cameraNoticeKey);

  Future<bool> _completed(String key) async {
    try {
      return await _read(key) == _version;
    } catch (_) {
      // Fail safe: a read failure (e.g. Android keystore invalidated after a
      // backup restore or OS key reset) must NOT be treated as "completed".
      // Treating it as completed would silently skip the camera-notice prompt
      // (a privacy/consent gate) and onboarding. Re-showing them on read
      // failure is the safe, compliant direction; the user can dismiss them
      // again, and the next successful write re-persists the version.
      return false;
    }
  }

  Future<void> _save(String key) async {
    try {
      await _write(key, _version);
    } catch (_) {
      // Best-effort: a write failure leaves the prompt to re-show until the
      // store is healthy again. Swallowing avoids crashing app entry.
    }
  }

  static Future<String?> _readSecurely(String key) => _storage.read(key: key);

  static Future<void> _writeSecurely(String key, String value) =>
      _storage.write(key: key, value: value);
}
