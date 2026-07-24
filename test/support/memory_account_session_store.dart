import 'package:ugk_exercise/platform/account_session_store.dart';

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
