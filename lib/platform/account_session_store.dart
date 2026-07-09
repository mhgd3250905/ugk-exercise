import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccountSession {
  const SavedAccountSession({
    required this.sessionToken,
    required this.appUserId,
  });

  final String sessionToken;
  final String appUserId;

  @override
  bool operator ==(Object other) {
    return other is SavedAccountSession &&
        other.sessionToken == sessionToken &&
        other.appUserId == appUserId;
  }

  @override
  int get hashCode => Object.hash(sessionToken, appUserId);
}

abstract class AccountSessionStore {
  Future<SavedAccountSession?> load();
  Future<void> save(SavedAccountSession session);
  Future<void> clear();
}

class SecureAccountSessionStore implements AccountSessionStore {
  SecureAccountSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionTokenKey = 'ugk_session_token';
  static const _appUserIdKey = 'ugk_app_user_id';

  final FlutterSecureStorage _storage;

  @override
  Future<SavedAccountSession?> load() async {
    final sessionToken = await _storage.read(key: _sessionTokenKey);
    final appUserId = await _storage.read(key: _appUserIdKey);
    if (sessionToken == null || appUserId == null) {
      return null;
    }
    return SavedAccountSession(sessionToken: sessionToken, appUserId: appUserId);
  }

  @override
  Future<void> save(SavedAccountSession session) async {
    await _storage.write(key: _sessionTokenKey, value: session.sessionToken);
    await _storage.write(key: _appUserIdKey, value: session.appUserId);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionTokenKey);
    await _storage.delete(key: _appUserIdKey);
  }
}

class MemoryAccountSessionStore implements AccountSessionStore {
  SavedAccountSession? _session;

  @override
  Future<SavedAccountSession?> load() async => _session;

  @override
  Future<void> save(SavedAccountSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
