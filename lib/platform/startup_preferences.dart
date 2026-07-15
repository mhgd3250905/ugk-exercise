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
      return true;
    }
  }

  Future<void> _save(String key) async {
    try {
      await _write(key, _version);
    } catch (_) {}
  }

  static Future<String?> _readSecurely(String key) => _storage.read(key: key);

  static Future<void> _writeSecurely(String key, String value) =>
      _storage.write(key: key, value: value);
}
