import 'dart:math' as math;

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

  testWidgets('leaderboard rows emphasize medal borders and score', (
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
                userId: 'u1',
                nickname: 'A',
                avatarKey: null,
                totalValue: 80,
              ),
              LeaderboardRow(
                rank: 2,
                userId: 'u2',
                nickname: 'B',
                avatarKey: null,
                totalValue: 60,
              ),
              LeaderboardRow(
                rank: 3,
                userId: 'u3',
                nickname: 'C',
                avatarKey: null,
                totalValue: 40,
              ),
              LeaderboardRow(
                rank: 4,
                userId: 'u4',
                nickname: 'D',
                avatarKey: null,
                totalValue: 20,
              ),
            ],
            me: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rows = [
      1,
      2,
      3,
      4,
    ].map((rank) => find.byKey(ValueKey('leaderboard-row-$rank'))).toList();
    final heights = rows
        .map(tester.getSize)
        .map((size) => size.height)
        .toList();
    expect(heights[0] > heights[1], isTrue);
    expect(heights[1] > heights[2], isTrue);
    expect(heights[2] > heights[3], isTrue);

    final decorations = rows
        .map(tester.widget<Container>)
        .map((container) => container.decoration! as BoxDecoration)
        .toList();
    expect(
      decorations
          .take(3)
          .every((decoration) => decoration.gradient is LinearGradient),
      isTrue,
    );
    final metalDeltas = decorations.take(3).map((decoration) {
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, hasLength(5));
      expect(gradient.stops, const [0, 0.28, 0.46, 0.62, 1]);
      final metal = gradient.colors.last;
      return (1 - metal.r).abs() + (1 - metal.g).abs() + (1 - metal.b).abs();
    }).toList();
    expect(metalDeltas[0] > metalDeltas[1], isTrue);
    expect(metalDeltas[1] > metalDeltas[2], isTrue);
    expect(metalDeltas[2], greaterThan(0.25));
    expect(decorations[3].color, Colors.white);
    expect(decorations[3].gradient, isNull);
    expect(
      decorations.every((decoration) => decoration.border != null),
      isTrue,
    );
    expect(decorations[0].boxShadow, isNotEmpty);
    expect(decorations[1].boxShadow, isNotEmpty);
    expect(decorations[2].boxShadow, isEmpty);
    expect(decorations[3].boxShadow, isEmpty);

    for (final rank in [1, 2, 3]) {
      final frame = find.byKey(ValueKey('leaderboard-avatar-frame-rank-$rank'));
      expect(frame, findsOneWidget);
      expect(tester.getSize(frame), const Size.square(46));
      expect(
        tester.getSize(
          find.descendant(of: frame, matching: find.byType(CircleAvatar)),
        ),
        const Size.square(36),
      );
      expect(
        find.descendant(of: frame, matching: find.byType(ClipPath)),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('leaderboard-rank-medal-$rank')),
        findsOneWidget,
      );
    }
    final topOneClipPath = find.descendant(
      of: find.byKey(const ValueKey('leaderboard-avatar-frame-rank-1')),
      matching: find.byType(ClipPath),
    );
    final clipper = tester.widget<ClipPath>(topOneClipPath).clipper!;
    final path = clipper.getClip(const Size.square(46));
    const center = Offset(23, 23);
    const peak = Offset(23, 1);
    const valleyAngle = -math.pi / 2 + math.pi / 18;
    final betweenTeeth = center + Offset.fromDirection(valleyAngle, 22);
    expect(path.contains(peak), isTrue);
    expect(path.contains(betweenTeeth), isFalse);
    expect(
      find.byKey(const ValueKey('leaderboard-rank-number-4')),
      findsOneWidget,
    );
    expect(find.text('#4'), findsOneWidget);

    final rowFour = rows.last;
    final avatarLeft = tester
        .getTopLeft(
          find.descendant(of: rowFour, matching: find.byType(CircleAvatar)),
        )
        .dx;
    final nameLeft = tester
        .getTopLeft(find.descendant(of: rowFour, matching: find.text('D')))
        .dx;
    final rankLeft = tester
        .getTopLeft(find.byKey(const ValueKey('leaderboard-rank-number-4')))
        .dx;
    final scoreLeft = tester
        .getTopLeft(find.byKey(const ValueKey('leaderboard-score-4')))
        .dx;
    expect(avatarLeft < nameLeft, isTrue);
    expect(nameLeft < rankLeft, isTrue);
    expect(rankLeft < scoreLeft, isTrue);

    final rankText = tester.widget<Text>(
      find.byKey(const ValueKey('leaderboard-rank-number-4')),
    );
    final score = tester.widget<Text>(
      find.byKey(const ValueKey('leaderboard-score-4')),
    );
    final scoreSpan = score.textSpan! as TextSpan;
    final scoreDigits = scoreSpan.children!.first as TextSpan;
    expect(rankText.style!.fontSize! < scoreDigits.style!.fontSize!, isTrue);
    expect(scoreDigits.style!.fontFamily, 'BebasNeue');
    expect(find.byType(ShaderMask), findsNothing);
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

  testWidgets('entry preloads both periods and switching uses cached rows', (
    tester,
  ) async {
    final calls = <LeaderboardPeriod>[];
    final controller = _buildController(
      load: (_, period) async {
        calls.add(period);
        return period == LeaderboardPeriod.day
            ? _daySnapshot
            : const LeaderboardSnapshot(
                period: LeaderboardPeriod.week,
                exerciseType: 'pushup',
                isJoined: true,
                top: [
                  LeaderboardRow(
                    rank: 1,
                    userId: 'week-1',
                    nickname: '周榜第一',
                    avatarKey: null,
                    totalValue: 90,
                  ),
                ],
                me: null,
              );
      },
    );

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();
    expect(calls, [LeaderboardPeriod.day, LeaderboardPeriod.week]);
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.text('周榜'));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(find.text('周榜第一'), findsOneWidget);
    expect(calls, hasLength(2));
  });

  testWidgets('pull to refresh reloads both cached periods', (tester) async {
    final calls = <LeaderboardPeriod>[];
    final controller = _buildController(
      load: (_, period) async {
        calls.add(period);
        return LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          top: const [],
          me: null,
        );
      },
    );
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(calls, [
      LeaderboardPeriod.day,
      LeaderboardPeriod.week,
      LeaderboardPeriod.day,
      LeaderboardPeriod.week,
    ]);
  });

  testWidgets('scrolling near the bottom appends the next page once', (
    tester,
  ) async {
    final loadMorePeriods = <LeaderboardPeriod>[];
    final firstRows = List.generate(
      20,
      (index) => LeaderboardRow(
        rank: index + 1,
        userId: 'u${index + 1}',
        nickname: '用户${index + 1}',
        avatarKey: null,
        totalValue: 100 - index,
      ),
    );
    final controller = _buildController(
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: true,
        nextCursor: period == LeaderboardPeriod.day ? 'page-2' : null,
        top: period == LeaderboardPeriod.day ? firstRows : const [],
        me: null,
      ),
      loadMore: (_, period, __) async {
        loadMorePeriods.add(period);
        return LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          top: const [
            LeaderboardRow(
              rank: 21,
              userId: 'u21',
              nickname: '用户21',
              avatarKey: null,
              totalValue: 80,
            ),
          ],
          me: null,
        );
      },
    );
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 2000);
    await tester.pumpAndSettle();

    expect(loadMorePeriods, [LeaderboardPeriod.day]);
    expect(find.text('用户21'), findsOneWidget);
  });

  testWidgets('failed next page keeps rows and offers retry', (tester) async {
    var attempts = 0;
    final controller = _buildController(
      load: (_, period) async => LeaderboardSnapshot(
        period: period,
        exerciseType: 'pushup',
        isJoined: true,
        nextCursor: period == LeaderboardPeriod.day ? 'page-2' : null,
        top: period == LeaderboardPeriod.day
            ? const [
                LeaderboardRow(
                  rank: 1,
                  userId: 'u1',
                  nickname: '仍然显示',
                  avatarKey: null,
                  totalValue: 100,
                ),
              ]
            : const [],
        me: null,
      ),
      loadMore: (_, period, __) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return LeaderboardSnapshot(
          period: period,
          exerciseType: 'pushup',
          isJoined: true,
          top: const [],
          me: null,
        );
      },
    );
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    await controller.loadMore(LeaderboardPeriod.day);
    await tester.pump();

    expect(find.text('仍然显示'), findsOneWidget);
    final retry = find.byKey(const ValueKey('leaderboard-load-more-retry'));
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(retry, findsNothing);
  });

  testWidgets('period pill loads rows with staggered scale reveals', (
    tester,
  ) async {
    const weekSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.week,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 1,
          userId: 'w1',
          nickname: 'W1',
          avatarKey: null,
          totalValue: 90,
        ),
        LeaderboardRow(
          rank: 2,
          userId: 'w2',
          nickname: 'W2',
          avatarKey: null,
          totalValue: 70,
        ),
        LeaderboardRow(
          rank: 3,
          userId: 'w3',
          nickname: 'W3',
          avatarKey: null,
          totalValue: 50,
        ),
      ],
      me: null,
    );
    final controller = _buildController(
      load: (_, period) => period == LeaderboardPeriod.day
          ? Future.value(_daySnapshot)
          : Future.value(weekSnapshot),
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<LeaderboardPeriod>), findsNothing);
    final indicator = find.byKey(
      const ValueKey('leaderboard-period-indicator'),
    );
    expect(indicator, findsOneWidget);
    expect(
      tester
          .widget<AnimatedAlign>(
            find.ancestor(of: indicator, matching: find.byType(AnimatedAlign)),
          )
          .duration,
      const Duration(milliseconds: 220),
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(FractionalTranslation), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);

    await tester.tap(find.text('周榜'));
    await tester.pump();
    await tester.pump();
    expect(find.text('W1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    double scale(int rank) => tester
        .widget<Transform>(find.byKey(ValueKey('leaderboard-row-reveal-$rank')))
        .transform
        .entry(0, 0);
    expect(scale(1) > scale(2), isTrue);
    expect(scale(2) > scale(3), isTrue);
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

    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsNothing,
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

  testWidgets('inactive member sees premium action at the bottom', (
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
    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).bottomNavigationBar,
      isNotNull,
    );
    final premiumAction = find.byKey(
      const ValueKey('leaderboard-premium-action'),
    );
    expect(
      find.descendant(of: premiumAction, matching: find.byType(FilledButton)),
      findsNothing,
    );
    expect(
      find.descendant(of: premiumAction, matching: find.byType(TextButton)),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsOneWidget,
    );
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
  LeaderboardLoadMore? loadMore,
  LeaderboardIdentityCommand? joinIdentity,
  LeaderboardIdentityCommand? updateIdentity,
  LeaderboardCommand? leave,
}) {
  return LeaderboardController(
    sessionProvider: () => session,
    load: load ?? (_, __) async => _daySnapshot,
    loadMore: loadMore,
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
