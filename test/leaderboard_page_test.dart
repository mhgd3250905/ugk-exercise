import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/ui/pages/leaderboard_page.dart';

void main() {
  testWidgets('leaderboard renders server-approved and anonymous names', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeaderboardPage(
          snapshot: LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            isJoined: true,
            top: [
              LeaderboardRow(
                rank: 1,
                userId: 'user_1',
                nickname: '公开昵称',
                avatarKey: null,
                avatarUrl: 'https://example.com/public.png',
                totalValue: 80,
              ),
              LeaderboardRow(
                rank: 2,
                userId: 'user_2',
                nickname: null,
                avatarKey: 'ring-lime',
                totalValue: 20,
              ),
            ],
            me: null,
          ),
        ),
      ),
    );

    expect(find.text('公开昵称'), findsOneWidget);
    expect(find.text('匿名训练者'), findsOneWidget);
    final networkAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar).first,
    );
    expect(networkAvatar.foregroundImage, isA<CachedNetworkImageProvider>());
    expect(networkAvatar.onForegroundImageError, isNotNull);
  });

  testWidgets('leaderboard page shows top rows and my rank', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeaderboardPage(
          snapshot: LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            isJoined: true,
            top: [
              LeaderboardRow(
                rank: 1,
                userId: 'u1',
                nickname: 'A',
                avatarKey: 'ring-green',
                totalValue: 80,
              ),
            ],
            me: LeaderboardRow(
              rank: 12,
              userId: 'me',
              nickname: '我',
              avatarKey: 'ring-lime',
              totalValue: 20,
            ),
          ),
        ),
      ),
    );

    expect(find.text('运动广场'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('我的排名'), findsOneWidget);
    expect(find.text('第 12 名'), findsOneWidget);
  });

  testWidgets('joined leaderboard without my rank does not show join prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeaderboardPage(
          snapshot: LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            isJoined: true,
            top: [],
            me: null,
          ),
        ),
      ),
    );

    expect(find.text('加入运动广场后展示你的排名'), findsNothing);
    expect(find.text('暂无排行'), findsOneWidget);
  });

  testWidgets('switching period hides old rows while new period loads', (
    tester,
  ) async {
    final weekCompleter = Completer<LeaderboardSnapshot>();
    final controller = _buildController(
      load: (_, period) {
        if (period == LeaderboardPeriod.day) {
          return Future.value(_daySnapshot);
        }
        return weekCompleter.future;
      },
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('我的排名'), findsOneWidget);

    await tester.tap(find.text('周榜'));
    await tester.pump();

    expect(find.text('A'), findsNothing);
    expect(find.text('我的排名'), findsNothing);
  });

  testWidgets('failed period load does not show old period rows', (
    tester,
  ) async {
    final controller = _buildController(
      load: (_, period) async {
        if (period == LeaderboardPeriod.day) {
          return _daySnapshot;
        }
        throw StateError('week failed');
      },
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('周榜'));
    await tester.pumpAndSettle();

    expect(find.text('加载失败，请稍后重试。'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('我的排名'), findsNothing);
  });

  testWidgets('join failure shows error without reloading', (tester) async {
    var loadCalls = 0;
    final controller = _buildController(
      load: (_, __) async {
        loadCalls++;
        return _notJoinedSnapshot;
      },
      joinIdentity: (_, __) async => throw StateError('join failed'),
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );

    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(loadCalls, 0);
    expect(controller.error, LeaderboardErrorCode.unexpected);
    expect(find.byKey(const ValueKey('leaderboard-identity-sheet')), findsOne);
    expect(find.text('身份保存失败，请稍后重试。'), findsOneWidget);
  });

  testWidgets('inactive member sees premium prompt instead of join action', (
    tester,
  ) async {
    final snapshot = LeaderboardSnapshot.fromJson({
      'period': 'day',
      'exerciseType': 'pushup',
      'isJoined': false,
      'canJoin': false,
      'anonymousAvatarKey': 'ring-green',
      'top': <Object?>[],
      'me': null,
    });

    await tester.pumpWidget(_buildApp(LeaderboardPage(snapshot: snapshot)));

    expect(find.text('加入广场'), findsNothing);
    expect(find.text('需要 Premium 会员才能加入运动广场。'), findsOneWidget);
  });

  testWidgets('premium-required join failure shows membership prompt', (
    tester,
  ) async {
    final snapshot = LeaderboardSnapshot.fromJson({
      'period': 'day',
      'exerciseType': 'pushup',
      'isJoined': false,
      'canJoin': true,
      'anonymousAvatarKey': 'ring-green',
      'top': <Object?>[],
      'me': null,
    });
    final controller = _buildController(
      joinIdentity: (_, __) async => throw const MembershipApiException(
        'HTTP 403',
        statusCode: 403,
        errorCode: 'premium_required',
      ),
    );

    await tester.pumpWidget(
      _buildApp(LeaderboardPage(controller: controller, snapshot: snapshot)),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(find.text('加入广场'), findsNothing);
    expect(find.text('需要 Premium 会员才能加入运动广场。'), findsOneWidget);
  });

  testWidgets('leave failure shows error without reloading', (tester) async {
    var loadCalls = 0;
    final controller = _buildController(
      load: (_, __) async {
        loadCalls++;
        return _daySnapshot;
      },
      leave: (_) async => throw StateError('leave failed'),
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _daySnapshot),
      ),
    );

    await tester.tap(find.byTooltip('退出榜单'));
    await tester.pumpAndSettle();

    expect(loadCalls, 0);
    expect(find.text('加载失败，请稍后重试。'), findsOneWidget);
  });

  testWidgets('signed out leaderboard shows sign in prompt', (tester) async {
    final controller = _buildController(session: null);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('登录后查看运动广场'), findsOneWidget);
  });

  testWidgets('joined user with zero score can still leave', (tester) async {
    var leaveCalls = 0;
    final controller = _buildController(
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      ),
      leave: (_) async => leaveCalls++,
    );

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    // Joined with zero score: leave must be reachable even though me is null.
    expect(find.byTooltip('退出榜单'), findsOneWidget);
    await tester.tap(find.byTooltip('退出榜单'));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
  });

  testWidgets('join opens identity sheet with anonymous selected by default', (
    tester,
  ) async {
    var joinCalls = 0;
    final controller = _buildController(
      joinIdentity: (_, __) async => joinCalls++,
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();

    expect(joinCalls, 0);
    expect(find.byKey(const ValueKey('leaderboard-identity-sheet')), findsOne);
    expect(find.text('选择你在运动广场中的身份'), findsOne);
    expect(find.text('使用当前个人资料'), findsOne);
    expect(find.text('设置榜单专用身份'), findsOne);
    expect(find.text('匿名参加'), findsOne);
    expect(find.text('不会公开你的个人资料'), findsOne);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-identity-anonymous-card')),
        matching: find.byKey(
          const ValueKey('profile-built-in-avatar-ring-coral'),
        ),
      ),
      findsOne,
    );
    expect(
      tester
          .widget<Radio<LeaderboardIdentityMode>>(
            find.byKey(const ValueKey('leaderboard-identity-anonymous-radio')),
          )
          .groupValue,
      LeaderboardIdentityMode.anonymous,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('leaderboard-identity-sheet')),
      findsNothing,
    );
    expect(joinCalls, 0);
  });

  testWidgets('profile preview prefers app profile and falls back to Google', (
    tester,
  ) async {
    final controller = _buildController(
      session: const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
        user: AppUser(
          id: 'user_1',
          displayName: 'Google 名字',
          email: '',
          avatarUrl: 'https://example.com/google.png',
          nickname: '应用昵称',
          avatarKey: 'bolt-sky',
        ),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();

    expect(find.text('应用昵称'), findsOne);
    expect(find.text('Google 名字'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-profile-preview-avatar')),
        matching: find.byIcon(Icons.bolt_rounded),
      ),
      findsOne,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final fallbackController = _buildController(
      session: const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
        user: AppUser(
          id: 'user_1',
          displayName: 'Google 名字',
          email: '',
          avatarUrl: 'https://example.com/google.png',
        ),
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(
          controller: fallbackController,
          snapshot: _notJoinedSnapshot,
        ),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();

    expect(find.text('Google 名字'), findsOne);
    final networkAvatar = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-profile-preview-avatar')),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(networkAvatar.foregroundImage, isA<CachedNetworkImageProvider>());
    expect(networkAvatar.onForegroundImageError, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-profile-preview-avatar')),
        matching: find.byIcon(Icons.person_rounded),
      ),
      findsOne,
    );
  });

  testWidgets('custom identity keeps input and submits selected avatar', (
    tester,
  ) async {
    LeaderboardIdentityChoice? submitted;
    final controller = _buildController(
      joinIdentity: (_, choice) async => submitted = choice,
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置榜单专用身份'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('leaderboard-custom-nickname')),
      '我的榜单名',
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-identity-custom-card')),
        matching: find.byKey(const ValueKey('leaderboard-custom-preview-name')),
      ),
      findsOne,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('leaderboard-custom-preview-name')),
          )
          .data,
      '我的榜单名',
    );
    await tester.tap(
      find.byKey(const ValueKey('leaderboard-avatar-ring-coral')),
    );
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(submitted?.mode, LeaderboardIdentityMode.custom);
    expect(submitted?.nickname, '我的榜单名');
    expect(submitted?.avatarKey, 'ring-coral');
  });

  testWidgets('anonymous edit preview keeps the server-assigned avatar', (
    tester,
  ) async {
    final snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      anonymousAvatarKey: 'ring-yellow',
      identity: const LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.anonymous,
      ),
      top: _daySnapshot.top,
      me: const LeaderboardRow(
        rank: 12,
        userId: 'me',
        nickname: null,
        avatarKey: 'ring-yellow',
        totalValue: 20,
      ),
    );
    final controller = _buildController(load: (_, __) async => snapshot);
    await tester.pumpWidget(
      _buildApp(LeaderboardPage(controller: controller, snapshot: snapshot)),
    );

    await tester.tap(find.byTooltip('编辑榜单身份'));
    await tester.pumpAndSettle();

    final anonymousCard = find.byKey(
      const ValueKey('leaderboard-identity-anonymous-card'),
    );
    expect(
      find.descendant(
        of: anonymousCard,
        matching: find.byKey(
          const ValueKey('profile-built-in-avatar-ring-yellow'),
        ),
      ),
      findsOne,
    );
  });

  testWidgets('ring avatar uses the shared white ring specification', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(const LeaderboardPage(snapshot: _daySnapshot)),
    );

    final avatar = tester.widget<Container>(
      find.byKey(const ValueKey('profile-built-in-avatar-ring-green')).first,
    );
    final decoration = avatar.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.border?.top.color, const Color(0xFF42C96B));
    expect(
      find.descendant(
        of: find
            .byKey(const ValueKey('profile-built-in-avatar-ring-green'))
            .first,
        matching: find.byIcon(Icons.fitness_center_rounded),
      ),
      findsOne,
    );
  });

  testWidgets('join error keeps sheet selection and custom nickname', (
    tester,
  ) async {
    final controller = _buildController(
      joinIdentity: (_, __) async => throw const MembershipApiException(
        'HTTP 409',
        statusCode: 409,
        errorCode: 'nickname_taken',
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置榜单专用身份'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('leaderboard-custom-nickname')),
      '重复昵称',
    );
    await tester.tap(
      find.byKey(const ValueKey('leaderboard-avatar-bolt-lime')),
    );
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('leaderboard-identity-sheet')), findsOne);
    expect(find.text('重复昵称'), findsWidgets);
    expect(find.text('这个榜单昵称已被使用，请换一个。'), findsWidgets);
    expect(
      tester
          .widget<Radio<LeaderboardIdentityMode>>(
            find.byKey(const ValueKey('leaderboard-identity-custom-radio')),
          )
          .groupValue,
      LeaderboardIdentityMode.custom,
    );
  });

  testWidgets('joined user edits current identity from my rank panel', (
    tester,
  ) async {
    LeaderboardIdentityChoice? submitted;
    final snapshot = _snapshotWithIdentity(
      const LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.custom,
        nickname: '原榜单名',
        avatarKey: 'ring-lime',
      ),
    );
    final controller = _buildController(
      load: (_, __) async => snapshot,
      updateIdentity: (_, choice) async => submitted = choice,
    );
    await tester.pumpWidget(
      _buildApp(LeaderboardPage(controller: controller, snapshot: snapshot)),
    );

    await tester.tap(find.byTooltip('编辑榜单身份'));
    await tester.pumpAndSettle();
    expect(find.text('原榜单名'), findsWidgets);
    final anonymousCard = find.byKey(
      const ValueKey('leaderboard-identity-anonymous-card'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(anonymousCard);
    await tester.pump();
    await tester.tap(find.text('保存身份'));
    await tester.pumpAndSettle();

    expect(submitted?.mode, LeaderboardIdentityMode.anonymous);
  });

  testWidgets('English identity controls expose localized semantics', (
    tester,
  ) async {
    final controller = _buildController();
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
        locale: const Locale('en'),
      ),
    );
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your Sports Plaza identity'), findsOne);
    expect(find.text('Use current profile'), findsOne);
    expect(find.text('Create leaderboard identity'), findsOne);
    expect(find.text('Join anonymously'), findsOne);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Join anonymously',
      ),
      findsOne,
    );
  });
}

Widget _buildApp(Widget home, {Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

LeaderboardController _buildController({
  SavedAccountSession? session = _session,
  LeaderboardLoad? load,
  LeaderboardIdentityCommand? joinIdentity,
  LeaderboardIdentityCommand? updateIdentity,
  LeaderboardCommand? leave,
}) {
  return LeaderboardController(
    sessionProvider: () => session,
    load: load ?? (_, __) async => _daySnapshot,
    joinIdentity: joinIdentity ?? (_, __) async {},
    updateIdentity: updateIdentity ?? (_, __) async {},
    leave: leave ?? (_) async {},
  );
}

const _session = SavedAccountSession(
  sessionToken: 'session_1',
  appUserId: 'user_1',
);

const _daySnapshot = LeaderboardSnapshot(
  period: LeaderboardPeriod.day,
  exerciseType: 'pushup',
  isJoined: true,
  top: [
    LeaderboardRow(
      rank: 1,
      userId: 'u1',
      nickname: 'A',
      avatarKey: 'ring-green',
      totalValue: 80,
    ),
  ],
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
  anonymousAvatarKey: 'ring-coral',
  top: [],
  me: null,
);

LeaderboardSnapshot _snapshotWithIdentity(LeaderboardIdentityChoice identity) =>
    LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      identity: identity,
      top: _daySnapshot.top,
      me: _daySnapshot.me,
    );
