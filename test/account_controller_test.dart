import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/product/premium_plan.dart';

void main() {
  test('signIn saves session and configures RevenueCat', () async {
    final store = MemoryAccountSessionStore();
    final api = _FakeMembershipApiClient();
    final revenueCat = FakeRevenueCatService(isPremium: true);
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );

    await controller.signIn();

    expect(controller.signedIn, isTrue);
    expect(controller.premium, isFalse);
    expect((await store.load())?.sessionToken, 'session_1');
    expect(revenueCat.configuredAppUserId, 'user_1');
  });

  test('signIn stays signed out when the session cannot be saved', () async {
    final controller = AccountController(
      sessionStore: _ThrowingSaveAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );

    await controller.signIn();

    expect(controller.signedIn, isFalse);
    expect(controller.user, isNull);
    expect(controller.error, AccountErrorCode.unexpected);
  });

  test('restore loads existing session', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(sessionToken: 'session_1', appUserId: 'user_1'),
    );
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => null,
    );

    await controller.restore();

    expect(controller.signedIn, isTrue);
    expect(controller.premium, isFalse);
  });

  test('refresh updates the shared user and membership snapshot', () async {
    final api = _FakeMembershipApiClient();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();
    api.user = const AppUser(
      id: 'user_1',
      displayName: '刷新后的用户',
      email: 'updated@example.com',
      avatarUrl: null,
    );
    api.membership = MembershipStatus(
      entitlement: 'premium',
      isActive: true,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      source: 'revenuecat_verified',
    );

    await controller.refresh();

    expect(controller.user?.displayName, '刷新后的用户');
    expect(controller.premium, isTrue);
  });

  test('refresh result is discarded after sign out', () async {
    final api = _ControlledMembershipApiClient()
      ..immediateAuthSnapshot = _snapshot('user_1', 'session_1');
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    final refresh = controller.refresh();
    await api.meStarted.future;
    await controller.signOut();
    api.meResult.complete(
      AccountSnapshot(
        sessionToken: 'session_1',
        appUserId: 'user_1',
        user: const AppUser(
          id: 'user_1',
          displayName: '过期结果',
          email: 'stale@example.com',
          avatarUrl: null,
        ),
        membership: MembershipStatus(
          entitlement: 'premium',
          isActive: true,
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          source: 'revenuecat_verified',
        ),
      ),
    );
    await refresh;

    expect(controller.signedIn, isFalse);
    expect(controller.user, isNull);
    expect(controller.premium, isFalse);
  });

  test(
    'refresh does not block account actions while request is pending',
    () async {
      final api = _ControlledMembershipApiClient()
        ..immediateAuthSnapshot = _snapshot('user_1', 'session_1');
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();

      final refresh = controller.refresh();
      await api.meStarted.future;

      expect(controller.busy, isFalse);

      api.meResult.complete(_snapshot('user_1', 'session_1'));
      await refresh;
    },
  );

  test('membership expiry notifies shared listeners', () async {
    final api = _FakeMembershipApiClient()
      ..membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(milliseconds: 100)),
        source: 'revenuecat_verified',
      );
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(controller.premium, isFalse);
    expect(notifications, 1);
  });

  test(
    'restore publishes cached user before account verification finishes',
    () async {
      final store = MemoryAccountSessionStore();
      final firstController = AccountController(
        sessionStore: store,
        apiClient: _ImmediateMembershipApiClient(
          const AccountSnapshot(
            sessionToken: 'session_1',
            appUserId: 'user_1',
            user: AppUser(
              id: 'user_1',
              displayName: 'Cached Name',
              email: 'cached@example.com',
              avatarUrl: 'https://example.com/avatar.png',
            ),
            membership: MembershipStatus.none,
          ),
        ),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await firstController.signIn();
      final api = _ControlledMembershipApiClient();
      final restoredController = AccountController(
        sessionStore: store,
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => null,
      );

      final restore = restoredController.restore();
      await restoredController.localRestoreCompleted;
      await api.meStarted.future;

      expect(restoredController.signedIn, isTrue);
      expect(restoredController.user?.displayName, 'Cached Name');
      expect(restoredController.user?.email, 'cached@example.com');
      expect(restoredController.busy, isTrue);

      api.meResult.complete(_snapshot('user_1', 'session_1'));
      await restore;

      expect(restoredController.user?.displayName, 'user_1');
      expect(restoredController.busy, isFalse);
    },
  );

  test('local restore completes when there is no saved account', () async {
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => null,
    );

    final restore = controller.restore();
    await controller.localRestoreCompleted;

    expect(controller.signedIn, isFalse);
    await restore;
  });

  test('signOut clears session', () async {
    final store = MemoryAccountSessionStore();
    final revenueCat = FakeRevenueCatService(isPremium: true);
    var googleSignedOut = false;
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      googleSignOut: () async => googleSignedOut = true,
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    await controller.signOut();

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(revenueCat.configuredAppUserId, isNull);
    expect(googleSignedOut, isTrue);
    expect(controller.currentSession, isNull);
  });

  test('signOut clears the avatar image cache', () async {
    var cacheClears = 0;
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: () async => cacheClears++,
    );
    await controller.signIn();

    await controller.signOut();

    expect(cacheClears, 1);
  });

  test('signOut clears local session when RevenueCat logout fails', () async {
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _ThrowingLogOutRevenueCatService(),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    await controller.signOut();

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(await store.load(), isNull);
  });

  test('restore clears expired local session', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(sessionToken: 'expired', appUserId: 'user_1'),
    );
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ExpiredSessionMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => null,
    );

    await controller.restore();

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(controller.error, isNull);
    expect(controller.currentSession, isNull);
  });

  test('purchase cancellation does not show an error', () async {
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _CancelRevenueCatService(),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.purchasePremiumPlan(PremiumPlanId.annual);

    expect(controller.error, isNull);
    expect(controller.premium, isFalse);
  });

  test('purchase failure shows a short user message', () async {
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: _FailRevenueCatService(),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.purchasePremiumPlan(PremiumPlanId.annual);

    expect(controller.error, AccountErrorCode.purchaseFailed);
    expect(controller.error, isNot(contains('PlatformException')));
  });

  test('loads plans and purchases the selected premium plan', () async {
    const plans = [
      PremiumPlan(id: PremiumPlanId.monthly, price: r'$2.99'),
      PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
    ];
    final revenueCat = FakeRevenueCatService(
      isPremium: true,
      premiumPlans: plans,
    );
    final api = _FakeMembershipApiClient();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    expect(await controller.loadPremiumPlans(), plans);
    api.membership = MembershipStatus(
      entitlement: 'premium',
      isActive: true,
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      source: 'revenuecat_verified',
    );
    await controller.purchasePremiumPlan(PremiumPlanId.annual);

    expect(revenueCat.purchasedPlanId, PremiumPlanId.annual);
    expect(controller.premium, isTrue);
    expect(api.reconcileCalls, 1);
  });

  test('plan load finishing after sign out is discarded', () async {
    final revenueCat = _ControlledRevenueCatService();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _FakeMembershipApiClient(),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    final load = controller.loadPremiumPlans();
    await revenueCat.planLoadStarted.future;
    final signOut = controller.signOut();
    revenueCat.planLoadResult.complete(const [
      PremiumPlan(id: PremiumPlanId.annual, price: r'$20.00'),
    ]);

    expect(await load, isEmpty);
    await signOut;
  });

  test(
    'purchase refreshes server membership when sdk result is not active',
    () async {
      final api = _FakeMembershipApiClient();
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();
      api.membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        source: 'revenuecat_google_play',
      );

      await controller.purchasePremiumPlan(PremiumPlanId.annual);

      expect(controller.premium, isTrue);
      expect(api.reconcileCalls, 1);
    },
  );

  test('sdk active membership cannot override stale server expiry', () async {
    final api = _FakeMembershipApiClient()
      ..membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        source: 'revenuecat_google_play',
      );
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: true),
      googleSignIn: () async => 'google-token',
    );

    await controller.signIn();

    expect(controller.premium, isFalse);
  });

  test(
    'restore purchases applies only the reconciled server membership',
    () async {
      final api = _FakeMembershipApiClient();
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: true),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();
      api.membership = MembershipStatus(
        entitlement: 'premium',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        source: 'revenuecat_verified',
      );

      await controller.restorePurchases();

      expect(controller.premium, isTrue);
      expect(api.reconcileCalls, 1);
    },
  );

  test('purchase sync failure does not grant sdk membership', () async {
    final api = _FakeMembershipApiClient()
      ..reconcileError = const MembershipApiException(
        'HTTP 503',
        statusCode: 503,
        errorCode: 'membership_sync_unavailable',
      );
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: true),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.purchasePremiumPlan(PremiumPlanId.annual);

    expect(controller.premium, isFalse);
    expect(controller.error, 'membership_sync_unavailable');
  });

  test(
    'currentSession exposes saved token appUserId and user after sign in',
    () async {
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: _FakeMembershipApiClient(),
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );

      await controller.signIn();

      expect(
        controller.currentSession,
        const SavedAccountSession(
          sessionToken: 'session_1',
          appUserId: 'user_1',
        ),
      );
      expect(controller.currentSession?.user, same(controller.user));
      expect(controller.currentSession?.user?.displayName, '训练者');
    },
  );

  test('updateProfile refreshes current user', () async {
    final api = _FakeMembershipApiClient();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.updateProfile(nickname: '训练者 01', avatarKey: 'ring-green');

    expect(controller.user?.publicDisplayName, '训练者 01');
    expect(controller.user?.avatarKey, 'ring-green');
  });

  test('updateProfile ignores stale result after signOut', () async {
    final api = _FakeMembershipApiClient()..delayProfileUpdate = true;
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    final updateFuture = controller.updateProfile(
      nickname: '训练者 01',
      avatarKey: 'ring-green',
    );
    await Future<void>.delayed(Duration.zero);

    await controller.signOut();
    api.completeProfileUpdate();
    await updateFuture;

    expect(controller.signedIn, isFalse);
    expect(controller.user, isNull);
  });

  test('signOut wins while signIn is waiting for Google', () async {
    final googleStarted = Completer<void>();
    final googleResult = Completer<String?>();
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _FakeMembershipApiClient(),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () {
        googleStarted.complete();
        return googleResult.future;
      },
      clearAvatarImageCache: _noopAvatarImageCache,
    );

    final signIn = controller.signIn();
    await googleStarted.future;
    await controller.signOut();
    googleResult.complete('google-token');
    await signIn;

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut wins while signIn is waiting for the auth API', () async {
    final api = _ControlledMembershipApiClient();
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );

    final signIn = controller.signIn();
    await api.authStarted.future;
    await controller.signOut();
    api.authResult.complete(_snapshot('user-a', 'token-a'));
    await signIn;

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut clears a signIn blocked in secure session save', () async {
    final store = _ControlledAccountSessionStore()
      ..saveGate = Completer<void>();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );

    final signIn = controller.signIn();
    await store.saveStarted.future;
    final signOut = controller.signOut();
    store.saveGate!.complete();
    await Future.wait([signIn, signOut]);

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
  });

  test('signOut logs out RevenueCat after stale configure completes', () async {
    final store = MemoryAccountSessionStore();
    final revenueCat = _ControlledRevenueCatService()
      ..configureGate = Completer<void>();
    final controller = AccountController(
      sessionStore: store,
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );

    final signIn = controller.signIn();
    await revenueCat.configureStarted.future;
    final signOut = controller.signOut();
    revenueCat.configureGate!.complete();
    await Future.wait([signIn, signOut]);

    expect(controller.signedIn, isFalse);
    expect(await store.load(), isNull);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test('new signIn wins over an older restore', () async {
    final store = MemoryAccountSessionStore();
    await store.save(
      const SavedAccountSession(
        sessionToken: 'old-token',
        appUserId: 'old-user',
      ),
    );
    final api = _ControlledMembershipApiClient()
      ..immediateAuthSnapshot = _snapshot('new-user', 'new-token');
    final revenueCat = FakeRevenueCatService(isPremium: false);
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
    );

    final restore = controller.restore();
    await api.meStarted.future;
    await controller.signIn();
    api.meResult.complete(_snapshot('old-user', 'old-token'));
    await restore;

    expect(controller.currentSession?.appUserId, 'new-user');
    expect((await store.load())?.appUserId, 'new-user');
    expect(revenueCat.configuredAppUserId, 'new-user');
  });

  test('signOut invalidates a pending purchase result', () async {
    final revenueCat = _ControlledRevenueCatService();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();
    revenueCat.purchaseResult = Completer<bool>();

    final purchase = controller.purchasePremiumPlan(PremiumPlanId.annual);
    await revenueCat.purchaseStarted.future;
    final signOut = controller.signOut();
    revenueCat.purchaseResult!.complete(true);
    await Future.wait([purchase, signOut]);

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test(
    'stale avatar policy snapshot cannot end a newer account state',
    () async {
      final store = MemoryAccountSessionStore();
      await store.save(
        const SavedAccountSession(
          sessionToken: 'old-token',
          appUserId: 'old-user',
        ),
      );
      final api = _AvatarPolicyRecoveryMembershipApiClient();
      final controller = AccountController(
        sessionStore: store,
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => null,
        clearAvatarImageCache: _noopAvatarImageCache,
      );
      await controller.restore();
      expect(controller.membershipVerificationPending, isTrue);

      final accept = controller.acceptAvatarPolicy('2026-07-14');
      await api.recoveryMeStarted.future;
      await controller.signOut();
      await store.save(
        const SavedAccountSession(
          sessionToken: 'new-token',
          appUserId: 'new-user',
          user: AppUser(
            id: 'new-user',
            displayName: 'New user',
            email: 'new@example.com',
            avatarUrl: null,
          ),
        ),
      );
      final restoreNewAccount = controller.restore();
      await api.newAccountMeStarted.future;

      api.recoveryMeResult.complete(
        AccountSnapshot(
          sessionToken: 'old-token',
          appUserId: 'old-user',
          user: const AppUser(
            id: 'old-user',
            displayName: 'Stale premium user',
            email: 'old@example.com',
            avatarUrl: null,
          ),
          membership: MembershipStatus(
            entitlement: 'premium',
            isActive: true,
            expiresAt: DateTime.now().add(const Duration(days: 1)),
            source: 'revenuecat_verified',
          ),
        ),
      );
      await accept;

      expect(controller.currentSession?.appUserId, 'new-user');
      expect(controller.user?.id, 'new-user');
      expect(controller.membership, MembershipStatus.none);
      expect(controller.membershipVerificationPending, isTrue);
      expect(controller.premium, isFalse);

      api.newAccountMeResult.complete(_snapshot('new-user', 'new-token'));
      await restoreNewAccount;
    },
  );

  test('signOut invalidates a pending restore purchases result', () async {
    final revenueCat = _ControlledRevenueCatService();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: _ImmediateMembershipApiClient(_snapshot('user-a', 'token-a')),
      revenueCat: revenueCat,
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();
    revenueCat.restoreResult = Completer<bool>();

    final restore = controller.restorePurchases();
    await revenueCat.restoreStarted.future;
    final signOut = controller.signOut();
    revenueCat.restoreResult!.complete(true);
    await Future.wait([restore, signOut]);

    expect(controller.signedIn, isFalse);
    expect(controller.premium, isFalse);
    expect(revenueCat.configuredAppUserId, isNull);
  });

  test(
    'later profile update wins when the older request finishes last',
    () async {
      final api = _ProfileRaceMembershipApiClient();
      final controller = AccountController(
        sessionStore: MemoryAccountSessionStore(),
        apiClient: api,
        revenueCat: FakeRevenueCatService(isPremium: false),
        googleSignIn: () async => 'google-token',
      );
      await controller.signIn();

      final slow = controller.updateProfile(
        nickname: 'slow',
        avatarKey: 'ring-green',
      );
      await api.started['slow']!.future;
      final fast = controller.updateProfile(
        nickname: 'fast',
        avatarKey: 'ring-lime',
      );
      await api.started['fast']!.future;
      api.results['fast']!.complete(_user('fast', 'ring-lime'));
      await fast;
      api.results['slow']!.complete(_user('slow', 'ring-green'));
      await slow;

      expect(controller.user?.nickname, 'fast');
      expect(controller.user?.avatarKey, 'ring-lime');
    },
  );

  test('avatar policy, upload, and delete refresh the saved user', () async {
    final api = _FakeMembershipApiClient();
    final store = MemoryAccountSessionStore();
    final controller = AccountController(
      sessionStore: store,
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
    );
    await controller.signIn();

    await controller.acceptAvatarPolicy('2026-07-14');
    expect(controller.user?.avatarPolicyAccepted, isTrue);
    await controller.uploadAvatar(Uint8List.fromList([1, 2, 3]));
    expect(controller.user?.customAvatarUrl, endsWith('custom.jpg'));
    await controller.deleteAvatar();
    expect(controller.user?.customAvatarUrl, isNull);
    expect((await store.load())?.user?.customAvatarUrl, isNull);
  });

  test('signOut and a newer delete win over a pending avatar upload', () async {
    final api = _AvatarRaceMembershipApiClient();
    final controller = AccountController(
      sessionStore: MemoryAccountSessionStore(),
      apiClient: api,
      revenueCat: FakeRevenueCatService(isPremium: false),
      googleSignIn: () async => 'google-token',
      clearAvatarImageCache: _noopAvatarImageCache,
    );
    await controller.signIn();

    var upload = controller.uploadAvatar(Uint8List(1));
    await api.uploadStarted.future;
    await controller.deleteAvatar();
    api.uploadResult.complete(_avatarUser('late.jpg'));
    await upload;
    expect(controller.user?.customAvatarUrl, isNull);

    api.resetUpload();
    upload = controller.uploadAvatar(Uint8List(1));
    await api.uploadStarted.future;
    await controller.signOut();
    api.uploadResult.complete(_avatarUser('signed-out.jpg'));
    await upload;
    expect(controller.user, isNull);
  });
}

Future<void> _noopAvatarImageCache() async {}

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  MembershipStatus membership = MembershipStatus.none;
  MembershipApiException? reconcileError;
  var reconcileCalls = 0;
  bool delayProfileUpdate = false;
  AppUser user = const AppUser(
    id: 'user_1',
    displayName: '训练者',
    email: 'a@example.com',
    avatarUrl: null,
  );
  Completer<void>? _profileUpdateCompleter;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return _snapshot(sessionToken: 'session_1');
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    return _snapshot(sessionToken: sessionToken);
  }

  @override
  Future<MembershipStatus> reconcileMembership(String sessionToken) async {
    reconcileCalls += 1;
    final error = reconcileError;
    if (error != null) throw error;
    return membership;
  }

  @override
  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) async {
    if (delayProfileUpdate) {
      _profileUpdateCompleter ??= Completer<void>();
      await _profileUpdateCompleter!.future;
    }
    user = AppUser(
      id: user.id,
      displayName: user.displayName,
      email: user.email,
      avatarUrl: user.avatarUrl,
      nickname: nickname,
      avatarKey: avatarKey,
    );
    return user;
  }

  @override
  Future<void> acceptAvatarPolicy(
    String sessionToken, {
    required String policyVersion,
  }) async {
    user = _avatarUser(null, policyAccepted: true);
  }

  @override
  Future<AppUser> uploadAvatar(String sessionToken, Uint8List jpegBytes) async {
    return user = _avatarUser('custom.jpg', policyAccepted: true);
  }

  @override
  Future<AppUser> deleteAvatar(String sessionToken) async {
    return user = _avatarUser(null, policyAccepted: true);
  }

  void completeProfileUpdate() {
    _profileUpdateCompleter?.complete();
  }

  AccountSnapshot _snapshot({required String sessionToken}) {
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: 'user_1',
      user: user,
      membership: membership,
    );
  }
}

class _CancelRevenueCatService extends FakeRevenueCatService {
  _CancelRevenueCatService() : super(isPremium: false);

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async {
    throw const PurchaseCancelledException();
  }
}

class _FailRevenueCatService extends FakeRevenueCatService {
  _FailRevenueCatService() : super(isPremium: false);

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async {
    throw const PurchaseFailedException('购买没有完成，请稍后再试。');
  }
}

class _ThrowingLogOutRevenueCatService extends FakeRevenueCatService {
  _ThrowingLogOutRevenueCatService() : super(isPremium: true);

  @override
  Future<void> logOut() async {
    throw Exception('logout failed');
  }
}

class _ExpiredSessionMembershipApiClient extends _FakeMembershipApiClient {
  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    throw const MembershipApiException('HTTP 401', statusCode: 401);
  }
}

AccountSnapshot _snapshot(String appUserId, String sessionToken) {
  return AccountSnapshot(
    sessionToken: sessionToken,
    appUserId: appUserId,
    user: AppUser(
      id: appUserId,
      displayName: appUserId,
      email: '$appUserId@example.com',
      avatarUrl: null,
    ),
    membership: MembershipStatus.none,
  );
}

AppUser _user(String nickname, String avatarKey) {
  return AppUser(
    id: 'user-a',
    displayName: 'User A',
    email: 'a@example.com',
    avatarUrl: null,
    nickname: nickname,
    avatarKey: avatarKey,
  );
}

class _ImmediateMembershipApiClient extends MembershipApiClient {
  _ImmediateMembershipApiClient(this.snapshot)
    : super(baseUrl: 'https://api.example.com');

  final AccountSnapshot snapshot;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async => snapshot;

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async => snapshot;
}

class _ControlledMembershipApiClient extends MembershipApiClient {
  _ControlledMembershipApiClient() : super(baseUrl: 'https://api.example.com');

  final authStarted = Completer<void>();
  final authResult = Completer<AccountSnapshot>();
  final meStarted = Completer<void>();
  final meResult = Completer<AccountSnapshot>();
  AccountSnapshot? immediateAuthSnapshot;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    if (!authStarted.isCompleted) {
      authStarted.complete();
    }
    return immediateAuthSnapshot ?? await authResult.future;
  }

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    if (!meStarted.isCompleted) {
      meStarted.complete();
    }
    return meResult.future;
  }
}

class _AvatarPolicyRecoveryMembershipApiClient extends MembershipApiClient {
  _AvatarPolicyRecoveryMembershipApiClient()
    : super(baseUrl: 'https://api.example.com');

  final recoveryMeStarted = Completer<void>();
  final recoveryMeResult = Completer<AccountSnapshot>();
  final newAccountMeStarted = Completer<void>();
  final newAccountMeResult = Completer<AccountSnapshot>();
  var _meCalls = 0;

  @override
  Future<void> acceptAvatarPolicy(
    String sessionToken, {
    required String policyVersion,
  }) async {}

  @override
  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    _meCalls++;
    if (_meCalls == 1) {
      throw const MembershipApiException('temporary failure', statusCode: 503);
    }
    if (_meCalls == 2) {
      recoveryMeStarted.complete();
      return recoveryMeResult.future;
    }
    newAccountMeStarted.complete();
    return newAccountMeResult.future;
  }
}

class _ControlledAccountSessionStore implements AccountSessionStore {
  SavedAccountSession? session;
  Completer<void>? saveGate;
  final saveStarted = Completer<void>();

  @override
  Future<SavedAccountSession?> load() async => session;

  @override
  Future<void> save(SavedAccountSession value) async {
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    await saveGate?.future;
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class _ThrowingSaveAccountSessionStore extends MemoryAccountSessionStore {
  @override
  Future<void> save(SavedAccountSession session) async {
    throw StateError('secure storage unavailable');
  }
}

class _ControlledRevenueCatService implements RevenueCatService {
  String? configuredAppUserId;
  Completer<void>? configureGate;
  Completer<bool>? purchaseResult;
  Completer<bool>? restoreResult;
  var configureStarted = Completer<void>();
  var purchaseStarted = Completer<void>();
  var restoreStarted = Completer<void>();
  final planLoadStarted = Completer<void>();
  final planLoadResult = Completer<List<PremiumPlan>>();

  @override
  Future<void> configure({required String appUserId}) async {
    if (!configureStarted.isCompleted) {
      configureStarted.complete();
    }
    await configureGate?.future;
    configuredAppUserId = appUserId;
  }

  @override
  Future<List<PremiumPlan>> loadPremiumPlans() async {
    planLoadStarted.complete();
    return planLoadResult.future;
  }

  @override
  Future<bool> purchasePremiumPlan(PremiumPlanId planId) async {
    purchaseStarted.complete();
    return purchaseResult?.future ?? Future.value(false);
  }

  @override
  Future<bool> restorePurchases() async {
    restoreStarted.complete();
    return restoreResult?.future ?? Future.value(false);
  }

  @override
  Future<void> logOut() async {
    configuredAppUserId = null;
  }
}

class _ProfileRaceMembershipApiClient extends _ImmediateMembershipApiClient {
  _ProfileRaceMembershipApiClient() : super(_snapshot('user-a', 'token-a'));

  final started = <String, Completer<void>>{};
  final results = <String, Completer<AppUser>>{};

  @override
  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) {
    started[nickname] = Completer<void>()..complete();
    return (results[nickname] = Completer<AppUser>()).future;
  }
}

AppUser _avatarUser(String? name, {bool policyAccepted = true}) => AppUser(
  id: 'user_1',
  displayName: 'User',
  email: 'user@example.com',
  avatarUrl: 'https://example.com/google.png',
  customAvatarUrl: name == null
      ? null
      : 'https://api.example.com/avatars/$name',
  avatarPolicyVersion: '2026-07-14',
  avatarPolicyAccepted: policyAccepted,
);

class _AvatarRaceMembershipApiClient extends _ImmediateMembershipApiClient {
  _AvatarRaceMembershipApiClient()
    : super(
        AccountSnapshot(
          sessionToken: 'token-a',
          appUserId: 'user_1',
          user: _avatarUser(null),
          membership: MembershipStatus.none,
        ),
      );

  var uploadStarted = Completer<void>();
  var uploadResult = Completer<AppUser>();

  @override
  Future<AppUser> uploadAvatar(String sessionToken, Uint8List jpegBytes) {
    uploadStarted.complete();
    return uploadResult.future;
  }

  @override
  Future<AppUser> deleteAvatar(String sessionToken) async => _avatarUser(null);

  void resetUpload() {
    uploadStarted = Completer<void>();
    uploadResult = Completer<AppUser>();
  }
}
