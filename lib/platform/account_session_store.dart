import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../product/membership_status.dart';

class SavedAccountSession {
  const SavedAccountSession({
    required this.sessionToken,
    required this.appUserId,
    this.user,
  });

  final String sessionToken;
  final String appUserId;
  final AppUser? user;

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
  static const _userKey = 'ugk_account_user';

  final FlutterSecureStorage _storage;

  @override
  Future<SavedAccountSession?> load() async {
    final sessionToken = await _storage.read(key: _sessionTokenKey);
    final appUserId = await _storage.read(key: _appUserIdKey);
    if (sessionToken == null || appUserId == null) {
      return null;
    }
    final user = _decodeUser(await _storage.read(key: _userKey));
    return SavedAccountSession(
      sessionToken: sessionToken,
      appUserId: appUserId,
      user: user?.id == appUserId ? user : null,
    );
  }

  @override
  Future<void> save(SavedAccountSession session) async {
    await _storage.write(key: _sessionTokenKey, value: session.sessionToken);
    await _storage.write(key: _appUserIdKey, value: session.appUserId);
    final user = session.user;
    if (user == null) {
      await _storage.delete(key: _userKey);
    } else {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionTokenKey);
    await _storage.delete(key: _appUserIdKey);
    await _storage.delete(key: _userKey);
  }

  AppUser? _decodeUser(String? value) {
    if (value == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, Object?> ? AppUser.fromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
