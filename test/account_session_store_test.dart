import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/product/membership_status.dart';

import 'support/memory_account_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('secure session store round-trips cached account profile', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureAccountSessionStore(
      storage: const FlutterSecureStorage(),
    );
    const user = AppUser(
      id: 'user_1',
      displayName: 'Google Name',
      email: 'a@example.com',
      avatarUrl: 'https://example.com/avatar.png',
      nickname: '训练者 01',
      avatarKey: 'ring-green',
    );

    await store.save(
      const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
        user: user,
      ),
    );
    final restored = await store.load();

    expect(restored?.sessionToken, 'session_1');
    expect(restored?.appUserId, 'user_1');
    expect(restored?.user?.displayName, 'Google Name');
    expect(restored?.user?.email, 'a@example.com');
    expect(restored?.user?.avatarUrl, 'https://example.com/avatar.png');
    expect(restored?.user?.nickname, '训练者 01');
    expect(restored?.user?.avatarKey, 'ring-green');

    await store.clear();
    expect(await store.load(), isNull);
  });
}
