import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/ui/app_settings.dart';
import 'package:ugk_exercise/ui/pages/home_page.dart';

void main() {
  testWidgets('home sports plaza card shows signed-out prompt when not signed in', (
    tester,
  ) async {
    final account = _buildController(isPremium: true);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(find.text('登录后查看运动广场'), findsOneWidget);
    expect(find.text('第 12 名'), findsNothing);
  });

  testWidgets('home sports plaza card shows free-user prompt for signed-in free member', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);
    expect(find.text('第 12 名'), findsNothing);
  });

  testWidgets('home sports plaza card shows join prompt for premium-not-joined', (
    tester,
  ) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    final leaderboard = _leaderboard(_notJoinedSnapshot);
    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await tester.pumpAndSettle();

    expect(find.text('加入运动广场后展示你的排名'), findsOneWidget);
    expect(find.text('第 12 名'), findsNothing);
  });

  testWidgets('home sports plaza card shows rank and reps for premium-joined with day snapshot', (
    tester,
  ) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    final leaderboard = _leaderboard(_daySnapshot);
    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await leaderboard.load(LeaderboardPeriod.day);
    await tester.pumpAndSettle();

    // C3: both rank and reps must render for the day snapshot.
    expect(find.text('第 12 名'), findsOneWidget);
    expect(find.text('20 次'), findsOneWidget);
    expect(find.text('登录后查看运动广场'), findsNothing);
  });

  testWidgets('home sports plaza card does not surface a week snapshot as day rank', (
    tester,
  ) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    final leaderboard = _leaderboard(_weekSnapshot);
    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await leaderboard.load(LeaderboardPeriod.week);
    await tester.pumpAndSettle();

    // C3: a week-period snapshot must NOT be rendered as the home day rank/count,
    // even though the user is joined and me is present.
    expect(find.text('第 5 名'), findsNothing);
    expect(find.text('40 次'), findsNothing);
  });
}

Widget _app({
  required AccountController account,
  LeaderboardController? leaderboard,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomePage(
      settingsController: AppSettingsController(store: _TestAppSettingsStore()),
      accountController: account,
      leaderboardController: leaderboard,
    ),
  );
}

class _TestAppSettingsStore implements AppSettingsStore {
  @override
  Future<String?> loadLanguage() async => null;

  @override
  Future<String?> loadTheme() async => null;

  @override
  Future<void> saveLanguage(String value) async {}

  @override
  Future<void> saveTheme(String value) async {}
}

AccountController _buildController({required bool isPremium}) {
  return AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient: _FakeMembershipApiClient(isPremium: isPremium),
    revenueCat: FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
  );
}

LeaderboardController _leaderboard(LeaderboardSnapshot snapshot) {
  return LeaderboardController(
    sessionProvider: () => const SavedAccountSession(
      sessionToken: 'session_1',
      appUserId: 'user_1',
    ),
    load: (_, __) async => snapshot,
    joinIdentity: (_, __) async {},
    updateIdentity: (_, __) async {},
    leave: (_) async {},
  );
}

const _daySnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: true,
  top: [],
  me: LeaderboardRow(
    rank: 12,
    userId: 'me',
    nickname: '我',
    avatarKey: 'ring-lime',
    totalValue: 20,
  ),
);

const _notJoinedSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: false,
  top: [],
  me: null,
);

const _weekSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.week,
  exerciseType: 'pushup',
  isJoined: true,
  top: [],
  me: LeaderboardRow(
    rank: 5,
    userId: 'me',
    nickname: '我',
    avatarKey: 'ring-lime',
    totalValue: 40,
  ),
);

class _FakeMembershipApiClient extends MembershipApiClient {
  _FakeMembershipApiClient({required this.isPremium})
    : super(baseUrl: 'https://api.example.com');

  final bool isPremium;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async {
    return AccountSnapshot(
      sessionToken: 'session_1',
      appUserId: 'user_1',
      user: const AppUser(
        id: 'user_1',
        displayName: '训练者',
        email: 'a@example.com',
        avatarUrl: null,
      ),
      membership: MembershipStatus(
        entitlement: 'premium',
        isActive: isPremium,
        expiresAt: null,
        source: isPremium ? 'revenuecat_google_play' : 'none',
      ),
    );
  }
}
