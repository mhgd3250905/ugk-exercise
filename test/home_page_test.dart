import 'dart:math' as math;

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
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/pages/home_page.dart';

void main() {
  testWidgets('premium profile entry uses a gold medal', (tester) async {
    final account = _buildController(isPremium: true);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-built-in-avatar-ring-sky')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-profile-icon')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-profile-medal-gold')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-profile-medal-silver')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-premium-badge')), findsNothing);
  });

  testWidgets('personal avatar is the top-left home action', (tester) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final avatar = find.byKey(const ValueKey('home-profile-medal-silver'));
    final today = find.byKey(const ValueKey('home-today-summary'));
    expect(tester.getCenter(avatar).dx, lessThan(tester.getCenter(today).dx));
  });

  testWidgets('home never exposes the developer test entry', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(find.text('测试模式'), findsNothing);
  });

  testWidgets('profile medal uses a scalloped circular edge', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final medal = find.byKey(const ValueKey('home-profile-medal-silver'));
    final clippedEdge = find.descendant(
      of: medal,
      matching: find.byType(ClipPath),
    );
    expect(clippedEdge, findsOneWidget);

    final clipper = tester.widget<ClipPath>(clippedEdge).clipper!;
    final path = clipper.getClip(const Size.square(50));
    const center = Offset(25, 25);
    const peak = Offset(25, 1);
    const valleyAngle = -math.pi / 2 + math.pi / 18;
    final betweenTeeth = center + Offset.fromDirection(valleyAngle, 24);

    expect(path.contains(peak), isTrue);
    expect(path.contains(betweenTeeth), isFalse);
  });

  testWidgets('home today summary uses a quiet surface control', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final summary = find.byKey(const ValueKey('home-today-summary'));
    expect(summary, findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.byIcon(Icons.calendar_month_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('exercise card is a single tappable progress entry', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-exercise-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/pushup_silhouette.png',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('light exercise card uses a quiet surface with dark content', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final decoration = _exerciseDecoration(tester);
    expect((decoration.gradient! as LinearGradient).colors, const [
      Color(0xFFFAFBF6),
      Color(0xFFDCE9DA),
    ]);
    expect(decoration.border, Border.all(color: const Color(0x26118C4F)));
    expect(tester.widget<Text>(find.text('俯卧撑训练')).style?.color, ink);
  });

  testWidgets('dark exercise card keeps its forest treatment', (tester) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(
      _app(account: account, brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    expect(
      (_exerciseDecoration(tester).gradient! as LinearGradient).colors,
      const [Color(0xFF16261F), Color(0xFF244736)],
    );
    expect(tester.widget<Text>(find.text('俯卧撑训练')).style?.color, Colors.white);
    final card = tester.widget<Container>(
      find.byKey(const ValueKey('home-exercise-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.boxShadow!.single.offset, const Offset(0, 18));
  });

  testWidgets('light sports plaza card stays in the mint theme family', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-sports-plaza-card'));
    final ink = tester.widget<Ink>(
      find.descendant(of: card, matching: find.byType(Ink)),
    );
    final decoration = ink.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, const [Color(0xFFF8FAF5), Color(0xFFF1F5EF)]);
  });

  testWidgets('sports plaza uses the whole card as its call to action', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('home-sports-plaza-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(OutlinedButton)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.arrow_forward_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('home entry cards fit a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = _buildController(isPremium: false);

    await tester.pumpWidget(_app(account: account));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-exercise-card')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-sports-plaza-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home sports plaza card shows signed-out prompt when not signed in',
    (tester) async {
      final account = _buildController(isPremium: true);
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      expect(find.text('登录后查看运动广场'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
    },
  );

  testWidgets(
    'home sports plaza card shows free-user prompt for signed-in free member',
    (tester) async {
      final account = _buildController(isPremium: false);
      await account.signIn();
      await tester.pumpWidget(_app(account: account));
      await tester.pumpAndSettle();

      expect(find.text('开通会员后参与运动广场排行'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-profile-medal-silver')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-profile-medal-gold')),
        findsNothing,
      );
    },
  );

  testWidgets('free member opens leaderboard premium action at the bottom', (
    tester,
  ) async {
    final account = _buildController(isPremium: false);
    await account.signIn();
    final leaderboard = _leaderboard(_freeNotJoinedSnapshot);
    await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看榜单'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsOneWidget,
    );
    await tester.tap(find.text('开通会员'));
    await tester.pumpAndSettle();

    expect(find.text('PushupAI 会员'), findsOneWidget);
  });

  testWidgets(
    'home sports plaza card shows join prompt for premium-not-joined',
    (tester) async {
      final account = _buildController(isPremium: true);
      await account.signIn();
      final leaderboard = _leaderboard(_notJoinedSnapshot);
      await tester.pumpWidget(_app(account: account, leaderboard: leaderboard));
      await tester.pumpAndSettle();

      expect(find.text('加入运动广场后展示你的排名'), findsOneWidget);
      expect(find.text('第 12 名'), findsNothing);
    },
  );

  testWidgets(
    'home sports plaza card shows rank and reps for premium-joined with day snapshot',
    (tester) async {
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
    },
  );

  testWidgets(
    'home sports plaza card does not surface a week snapshot as day rank',
    (tester) async {
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
    },
  );
}

Widget _app({
  required AccountController account,
  LeaderboardController? leaderboard,
  Brightness? brightness,
}) {
  return MaterialApp(
    theme: brightness == null ? null : appTheme(brightness: brightness),
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

BoxDecoration _exerciseDecoration(WidgetTester tester) {
  final card = find.byKey(const ValueKey('home-exercise-card'));
  final background = find.descendant(
    of: card,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).gradient is LinearGradient,
    ),
  );
  return tester.widget<Container>(background).decoration! as BoxDecoration;
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

const _freeNotJoinedSnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: false,
  canJoin: false,
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
        avatarKey: 'ring-sky',
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
