import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/ui/pages/leaderboard_page.dart';

void main() {
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
      join: (_) async => throw StateError('join failed'),
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );

    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();

    expect(loadCalls, 0);
    expect(find.text('加载失败，请稍后重试。'), findsOneWidget);
  });

  testWidgets('inactive member sees premium prompt instead of join action', (
    tester,
  ) async {
    final snapshot = LeaderboardSnapshot.fromJson({
      'period': 'day',
      'exerciseType': 'pushup',
      'isJoined': false,
      'canJoin': false,
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
      'top': <Object?>[],
      'me': null,
    });
    final controller = _buildController(
      join: (_) async => throw const MembershipApiException(
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
}

Widget _buildApp(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

LeaderboardController _buildController({
  SavedAccountSession? session = _session,
  LeaderboardLoad? load,
  LeaderboardCommand? join,
  LeaderboardCommand? leave,
}) {
  return LeaderboardController(
    sessionProvider: () => session,
    load: load ?? (_, __) async => _daySnapshot,
    join: join ?? (_) async {},
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
  top: [],
  me: null,
);
