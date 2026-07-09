import 'package:test/test.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';

void main() {
  test('memory session store saves and clears session', () async {
    final store = MemoryAccountSessionStore();
    const session = SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    );

    await store.save(session);
    expect(await store.load(), session);

    await store.clear();
    expect(await store.load(), isNull);
  });
}
