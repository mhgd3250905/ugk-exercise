import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/account_controller.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/membership_status.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
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
    expect(find.text('标准 1 分 · 窄距 2 分'), findsOneWidget);
    final networkAvatar = tester.widget<CircleAvatar>(
      find.byType(CircleAvatar).first,
    );
    expect(networkAvatar.foregroundImage, isA<CachedNetworkImageProvider>());
    expect(networkAvatar.onForegroundImageError, isNotNull);
  });

  testWidgets('leaderboard rows use tonal rank surfaces without color frames', (
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
    expect(decorations[3].color, lightRaisedSurface);
    expect(decorations[3].gradient, isNull);
    expect(
      decorations.every((decoration) => decoration.border == null),
      isTrue,
    );
    expect(decorations[0].boxShadow, isNotEmpty);
    expect(decorations[1].boxShadow, isNotEmpty);
    expect(
      decorations[0].boxShadow!.single.blurRadius,
      greaterThan(decorations[1].boxShadow!.single.blurRadius),
    );
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
      final medal = tester.widget<Icon>(
        find.byKey(ValueKey('leaderboard-rank-medal-$rank')),
      );
      expect(medal.size, rank == 1 ? 34 : 30);
      final halo = find.byKey(ValueKey('leaderboard-rank-medal-halo-$rank'));
      expect(tester.getSize(halo), const Size.square(40));
      final haloDecoration =
          tester.widget<Container>(halo).decoration! as BoxDecoration;
      expect(haloDecoration.boxShadow, isNotEmpty);
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

  testWidgets('dark leaderboard rows keep metal accents off the outer frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const LeaderboardPage(
          snapshot: LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
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
        theme: appTheme(brightness: Brightness.dark),
      ),
    );
    await tester.pumpAndSettle();

    final first = tester.widget<Container>(
      find.byKey(const ValueKey('leaderboard-row-1')),
    );
    final ordinary = tester.widget<Container>(
      find.byKey(const ValueKey('leaderboard-row-4')),
    );
    final firstDecoration = first.decoration! as BoxDecoration;
    final ordinaryDecoration = ordinary.decoration! as BoxDecoration;
    expect(firstDecoration.border, isNull);
    expect(ordinaryDecoration.border, isNull);
    expect(firstDecoration.gradient, isA<LinearGradient>());
    expect(ordinaryDecoration.color, darkRaisedSurface);
  });

  testWidgets('period selector and points rule use one-layer tonal surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        const LeaderboardPage(snapshot: _daySnapshot),
        theme: appTheme(brightness: Brightness.light),
      ),
    );

    final pill = tester.widget<Container>(
      find.byKey(const ValueKey('leaderboard-period-pill')),
    );
    final indicator = tester.widget<Container>(
      find.byKey(const ValueKey('leaderboard-period-indicator')),
    );
    expect((pill.decoration! as BoxDecoration).border, isNull);
    expect((indicator.decoration! as BoxDecoration).border, isNull);
    // The points rule is now a plain inline caption (a Padding) with no card
    // background, not a boxed chip.
    final rule = tester.widget<Padding>(
      find.byKey(const ValueKey('leaderboard-points-rule')),
    );
    expect(rule.child, isA<Row>());

    final selectedValues = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byKey(const ValueKey('leaderboard-period-pill')),
            matching: find.byType(Semantics),
          ),
        )
        .map((semantics) => semantics.properties.selected)
        .whereType<bool>()
        .toList();
    expect(selectedValues, containsAll(<bool>[true, false]));
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
    expect(
      find.byKey(const ValueKey('leaderboard-my-exercise-counts')),
      findsNothing,
    );
  });

  testWidgets(
    'my rank card uses a distinct light sage anchor and keeps the dark anchor',
    (tester) async {
      final snapshot = LeaderboardSnapshot.fromJson({
        'period': 'day',
        'metric': 'pushup_points_v1',
        'metricUnit': 'points',
        'isJoined': true,
        'canJoin': false,
        'anonymousAvatarKey': 'ring-green',
        'myExerciseCounts': {'pushup': 56, 'narrow_pushup': 6},
        'top': <Object?>[],
        'me': {
          'rank': 1,
          'userId': 'me',
          'nickname': '我',
          'avatarKey': 'ring-lime',
          'avatarUrl': null,
          'totalValue': 68,
        },
        'identity': {'mode': 'profile'},
      });

      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: appTheme(),
            darkTheme: appTheme(brightness: Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: LeaderboardPage(snapshot: snapshot),
          ),
        );
        await tester.pumpAndSettle();

        final panel = find.byKey(const ValueKey('leaderboard-my-rank-panel'));
        final panelDecoration =
            tester.widget<Container>(panel).decoration! as BoxDecoration;
        expect(panelDecoration.border, isNull, reason: brightness.name);
        if (brightness == Brightness.light) {
          final gradient = panelDecoration.gradient! as LinearGradient;
          expect(
            gradient.colors,
            equals(const [Color(0xFFE7F4E8), Color(0xFFC5E5CC)]),
          );
          expect(panelDecoration.color, isNull);
          expect(panelDecoration.boxShadow, hasLength(1));
          expect(
            panelDecoration.boxShadow!.single.color,
            const Color(0x26118C4F),
          );
          expect(panelDecoration.boxShadow!.single.blurRadius, 28);
        } else {
          expect(panelDecoration.color, ink);
          expect(panelDecoration.gradient, isNull);
        }
        expect(
          find.descendant(of: panel, matching: find.text('标准 56 次 · 窄距 6 次')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('English exercise breakdown fits a small screen in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.week,
      isJoined: true,
      anonymousAvatarKey: 'ring-green',
      myExerciseCounts: LeaderboardExerciseCounts(pushup: 56, narrowPushup: 6),
      top: [],
      me: LeaderboardRow(
        rank: 1,
        userId: 'me',
        nickname: 'Me',
        avatarKey: 'ring-lime',
        totalValue: 68,
      ),
    );

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: appTheme(brightness: brightness),
          home: const LeaderboardPage(snapshot: snapshot),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Standard 56 reps · Narrow 6 reps'),
        findsOneWidget,
        reason: brightness.name,
      );
      expect(tester.takeException(), isNull, reason: brightness.name);
    }
  });

  testWidgets('joined leaderboard without my rank does not show join prompt', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: appTheme(),
          darkTheme: appTheme(brightness: Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const LeaderboardPage(
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
      await tester.pumpAndSettle();

      expect(find.text('加入运动广场后展示你的排名'), findsNothing);
      expect(find.text('暂无排行'), findsOneWidget);
      final noRank = find.byKey(
        const ValueKey('leaderboard-joined-no-rank-panel'),
      );
      expect(noRank, findsOneWidget);
      final decoration =
          tester.widget<Container>(noRank).decoration! as BoxDecoration;
      expect(decoration.border, isNull, reason: brightness.name);
      if (brightness == Brightness.light) {
        expect((decoration.gradient! as LinearGradient).colors, const [
          lightMyRankCardTop,
          lightMyRankCardBottom,
        ]);
        expect(decoration.color, isNull);
        expect(decoration.boxShadow, const [lightHomeCardShadow]);
      } else {
        expect(decoration.color, ink);
        expect(decoration.gradient, isNull);
      }
      final label = tester.widget<Text>(
        find.descendant(of: noRank, matching: find.text('我的排名')),
      );
      expect(
        label.style?.color,
        brightness == Brightness.light ? ink : const Color(0xFFCFE6D7),
      );
      expect(
        find.byKey(const ValueKey('leaderboard-empty-panel')),
        findsOneWidget,
      );
    }
  });

  testWidgets('expired joined member sees their frozen score and can renew', (
    tester,
  ) async {
    var subscribeCalls = 0;
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(
          snapshot: const LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            isJoined: true,
            canJoin: false,
            frozenTotalValue: 42,
            top: [
              LeaderboardRow(
                rank: 1,
                userId: 'me',
                nickname: '盛开',
                avatarKey: 'ring-green',
                totalValue: 42,
              ),
            ],
            me: LeaderboardRow(
              rank: 1,
              userId: 'me',
              nickname: '盛开',
              avatarKey: 'ring-green',
              totalValue: 42,
            ),
          ),
          onSubscribe: () async {
            subscribeCalls++;
          },
        ),
        theme: appTheme(brightness: Brightness.light),
      ),
    );

    expect(
      find.byKey(const ValueKey('leaderboard-frozen-score')),
      findsOneWidget,
    );
    // The frozen panel no longer shows a header row (title + points + leave);
    // only the expiry prompt + subscribe button remain.
    expect(find.text('我的成绩已冻结'), findsNothing);
    expect(find.text('盛开'), findsOneWidget);
    expect(find.text('42 分'), findsNWidgets(1));
    expect(find.text('会员已过期，续费后继续参与排名'), findsOneWidget);
    final frozenPanel = tester.widget<Container>(
      find.byKey(const ValueKey('leaderboard-frozen-score')),
    );
    final frozenDecoration = frozenPanel.decoration! as BoxDecoration;
    expect(frozenDecoration.color, isNull);
    expect(frozenDecoration.gradient, isA<LinearGradient>());
    expect(frozenDecoration.border, isNull);
    expect(frozenDecoration.boxShadow, isNotEmpty);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-frozen-score')),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('开通会员'));
    await tester.pump();
    expect(subscribeCalls, 1);
  });

  testWidgets('expired joined member can leave the leaderboard', (
    tester,
  ) async {
    var leaveCalls = 0;
    final controller = _buildController(
      leave: (_) async {
        leaveCalls++;
      },
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(
          controller: controller,
          snapshot: const LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            isJoined: true,
            canJoin: false,
            frozenTotalValue: 42,
            // Even when frozen/expired, the user still appears as a ranked row
            // in the list; long-pressing that row offers "leave".
            top: [
              LeaderboardRow(
                rank: 2,
                userId: 'user_1',
                nickname: '我',
                avatarKey: 'ring-lime',
                totalValue: 42,
              ),
            ],
            me: null,
          ),
        ),
      ),
    );

    // Long-press my own row in the list → leave action sheet → confirm.
    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-row-actions-user_1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出榜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leaderboard-leave-confirm')));
    await tester.pumpAndSettle();

    expect(leaveCalls, 1);
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

  testWidgets('initial load uses the pull refresh indicator', (tester) async {
    final loads = {
      for (final period in LeaderboardPeriod.values)
        period: Completer<LeaderboardSnapshot>(),
    };
    final controller = _buildController(
      load: (_, period) => loads[period]!.future,
    );

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    loads[LeaderboardPeriod.day]!.complete(_daySnapshot);
    loads[LeaderboardPeriod.week]!.complete(
      const LeaderboardSnapshot(
        period: LeaderboardPeriod.week,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('missing cached period refreshes instead of showing sign in', (
    tester,
  ) async {
    const weekSnapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.week,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 1,
          userId: 'week-1',
          nickname: '周榜恢复',
          avatarKey: null,
          totalValue: 90,
        ),
      ],
      me: null,
    );
    final interruptedDay = Completer<LeaderboardSnapshot>();
    final interruptedWeek = Completer<LeaderboardSnapshot>();
    var dayCalls = 0;
    var weekCalls = 0;
    final controller = _buildController(
      load: (_, period) {
        if (period == LeaderboardPeriod.day) {
          dayCalls++;
          return dayCalls == 2
              ? interruptedDay.future
              : Future.value(_daySnapshot);
        }
        weekCalls++;
        return weekCalls == 1
            ? interruptedWeek.future
            : Future.value(weekSnapshot);
      },
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(controller.busy, isTrue);

    await controller.load(LeaderboardPeriod.day);
    interruptedDay.complete(_daySnapshot);
    interruptedWeek.complete(weekSnapshot);
    await tester.pumpAndSettle();
    expect(controller.snapshotFor(LeaderboardPeriod.week), isNull);
    expect(controller.busy, isFalse);

    await tester.tap(find.text('周榜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(dayCalls, 4);
    expect(weekCalls, 2);
    expect(find.text('登录后查看运动广场'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('周榜恢复'), findsOneWidget);
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
    final rows = find.byKey(const ValueKey('leaderboard-rows-day'));
    expect(
      find.descendant(of: rows, matching: find.byType(FractionalTranslation)),
      findsNothing,
    );
    expect(
      find.descendant(of: rows, matching: find.byType(FadeTransition)),
      findsNothing,
    );

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

  testWidgets('period pill uses a compact centered size', (tester) async {
    await tester.pumpWidget(
      _buildApp(const LeaderboardPage(snapshot: _daySnapshot)),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('leaderboard-period-pill'))),
      const Size(270, 44),
    );
  });

  testWidgets('same-length refresh does not restart row reveal', (
    tester,
  ) async {
    final dayRefresh = Completer<LeaderboardSnapshot>();
    final weekRefresh = Completer<LeaderboardSnapshot>();
    var primingCache = true;
    final controller = _buildController(
      load: (_, period) {
        if (primingCache) return Future.value(_daySnapshot);
        return switch (period) {
          LeaderboardPeriod.day => dayRefresh.future,
          LeaderboardPeriod.week => weekRefresh.future,
        };
      },
    );
    await controller.load(LeaderboardPeriod.day);
    primingCache = false;

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    double scale() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('leaderboard-row-reveal-1')),
        )
        .transform
        .entry(0, 0);
    final scaleBeforeRefresh = scale();
    expect(scaleBeforeRefresh, greaterThan(0));

    dayRefresh.complete(
      const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        isJoined: true,
        top: [
          LeaderboardRow(
            rank: 1,
            userId: 'u1',
            nickname: '刷新后的名字',
            avatarKey: 'ring-green',
            totalValue: 63,
          ),
        ],
        me: null,
      ),
    );
    weekRefresh.complete(
      const LeaderboardSnapshot(
        period: LeaderboardPeriod.week,
        exerciseType: 'pushup',
        isJoined: true,
        top: [],
        me: null,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('刷新后的名字'), findsOneWidget);
    expect(scale(), greaterThanOrEqualTo(scaleBeforeRefresh));
  });

  testWidgets('cached rows skip reveal while page enters', (tester) async {
    final controller = _buildController();
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('leaderboard-row-reveal-1')),
    );
    expect(transform.transform.entry(0, 0), 1);
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

  testWidgets('membership sync failure shows a distinct retry message', (
    tester,
  ) async {
    final controller = _buildController(
      load: (_, __) async => throw const MembershipApiException(
        'HTTP 503',
        statusCode: 503,
        errorCode: 'membership_sync_unavailable',
      ),
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('会员权益同步失败，请稍后重试。'), findsOneWidget);
    expect(find.text('需要 Premium 会员才能加入运动广场。'), findsNothing);
    final errorPanel = find.byKey(const ValueKey('leaderboard-error-panel'));
    expect(errorPanel, findsOneWidget);
    expect(
      (tester.widget<Container>(errorPanel).decoration! as BoxDecoration)
          .border,
      isNull,
    );
  });

  testWidgets('legacy Worker response failure shows localized retry state', (
    tester,
  ) async {
    final controller = _buildController(
      load: (_, __) async =>
          throw const MembershipApiException('Invalid leaderboard response'),
    );
    await controller.load(LeaderboardPeriod.day);

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The leaderboard could not be loaded. Please try again later.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leaderboard-error-panel')),
      findsOneWidget,
    );
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
      'metric': 'pushup_points_v1',
      'metricUnit': 'points',
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
    final premiumDecoration =
        tester.widget<Container>(premiumAction).decoration! as BoxDecoration;
    expect(premiumDecoration.border, isNull);
    expect(premiumDecoration.color, lightSageSurface);
  });

  testWidgets('global premium state overrides a stale non-member snapshot', (
    tester,
  ) async {
    final account = await _signedInAccount(isPremium: true);
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: false,
      canJoin: false,
      top: [],
      me: null,
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(snapshot: snapshot, accountController: account),
      ),
    );

    expect(find.text('加入广场'), findsOneWidget);
    final joinPrompt = find.byKey(const ValueKey('leaderboard-join-prompt'));
    expect(joinPrompt, findsOneWidget);
    final joinDecoration =
        tester.widget<Container>(joinPrompt).decoration! as BoxDecoration;
    expect(joinDecoration.border, isNull);
    expect(joinDecoration.color, lightMintSurface);
    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsNothing,
    );
  });

  testWidgets('global free state overrides a stale member snapshot', (
    tester,
  ) async {
    final account = await _signedInAccount(isPremium: false);
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: false,
      canJoin: true,
      top: [],
      me: null,
    );

    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(snapshot: snapshot, accountController: account),
      ),
    );

    expect(find.text('加入广场'), findsNothing);
    expect(
      find.byKey(const ValueKey('leaderboard-premium-action')),
      findsOneWidget,
    );
  });

  testWidgets('premium-required join failure shows membership prompt', (
    tester,
  ) async {
    final snapshot = LeaderboardSnapshot.fromJson({
      'period': 'day',
      'metric': 'pushup_points_v1',
      'metricUnit': 'points',
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

    // Long-press my own rank panel → leave action sheet → confirm.
    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-my-rank-panel')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出榜单'));
    await tester.pumpAndSettle();
    expect(find.text('确认退出运动广场？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaderboard-leave-confirm')));
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

    expect(find.text('确认退出运动广场？'), findsOneWidget);
    expect(leaveCalls, 0);
    await tester.tap(find.byKey(const ValueKey('leaderboard-leave-cancel')));
    await tester.pumpAndSettle();
    expect(leaveCalls, 0);

    await tester.tap(find.byTooltip('退出榜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('leaderboard-leave-confirm')));
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
    expect(find.text('加入后，你的训练成绩会参与公开排名；可随时退出。'), findsOne);
    expect(find.text('使用当前个人资料'), findsOne);
    expect(find.text('设置榜单专用身份'), findsNothing);
    expect(
      find.byKey(const ValueKey('leaderboard-identity-custom-card')),
      findsNothing,
    );
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
          .widget<RadioGroup<LeaderboardIdentityMode>>(
            find.byKey(const ValueKey('leaderboard-identity-radio-group')),
          )
          .groupValue,
      LeaderboardIdentityMode.anonymous,
    );
    final anonymousDecoration =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(
                          const ValueKey('leaderboard-identity-anonymous-card'),
                        ),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(anonymousDecoration.border, isNull);

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

  testWidgets('successful join closes the sheet and confirms the result', (
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
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(joinCalls, 1);
    expect(
      find.byKey(const ValueKey('leaderboard-identity-sheet')),
      findsNothing,
    );
    expect(find.text('已加入运动广场'), findsOneWidget);
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

  testWidgets('join error keeps the selected profile identity', (tester) async {
    final controller = _buildController(
      joinIdentity: (_, __) async => throw const MembershipApiException(
        'HTTP 409',
        statusCode: 500,
        errorCode: 'request_failed',
      ),
    );
    await tester.pumpWidget(
      _buildApp(
        LeaderboardPage(controller: controller, snapshot: _notJoinedSnapshot),
      ),
    );
    await tester.tap(find.text('加入广场'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用当前个人资料'));
    await tester.tap(find.text('确认加入'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('leaderboard-identity-sheet')), findsOne);
    expect(find.text('身份保存失败，请稍后重试。'), findsWidgets);
    expect(
      tester
          .widget<RadioGroup<LeaderboardIdentityMode>>(
            find.byKey(const ValueKey('leaderboard-identity-radio-group')),
          )
          .groupValue,
      LeaderboardIdentityMode.profile,
    );
  });

  testWidgets('joined user edits current identity from my rank panel', (
    tester,
  ) async {
    LeaderboardIdentityChoice? submitted;
    final snapshot = _snapshotWithIdentity(
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.profile),
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
    expect(find.text('Create leaderboard identity'), findsNothing);
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

  testWidgets('long press opens moderation actions without a trailing menu', (
    tester,
  ) async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 2,
          userId: 'other_user',
          nickname: '测试用户',
          avatarKey: 'ring-green',
          totalValue: 20,
        ),
      ],
      me: null,
    );
    final controller = _buildController(load: (_, __) async => snapshot);
    await controller.load(LeaderboardPeriod.day);
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    expect(
      find.byKey(const ValueKey('leaderboard-row-menu-other_user')),
      findsNothing,
    );
    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-row-actions-other_user')),
    );
    await tester.pumpAndSettle();

    expect(find.text('用户操作'), findsOneWidget);
    expect(find.text('测试用户'), findsNWidgets(2));
    expect(find.text('举报头像'), findsOneWidget);
    expect(find.text('举报用户'), findsOneWidget);
    expect(find.text('屏蔽用户'), findsOneWidget);
  });

  testWidgets('current user row offers leave but no moderation actions', (
    tester,
  ) async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 1,
          userId: 'user_1',
          nickname: '我',
          avatarKey: 'ring-lime',
          totalValue: 20,
        ),
      ],
      me: null,
    );
    final controller = _buildController(load: (_, __) async => snapshot);
    await controller.load(LeaderboardPeriod.day);
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-row-actions-user_1')),
    );
    await tester.pumpAndSettle();

    // Own row offers "leave" but never moderation actions (report/block).
    expect(find.text('退出榜单'), findsOneWidget);
    expect(find.text('举报头像'), findsNothing);
    expect(find.text('举报用户'), findsNothing);
    expect(find.text('屏蔽用户'), findsNothing);
  });

  testWidgets('reporting an avatar removes that user from cached rankings', (
    tester,
  ) async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 2,
          userId: 'reported_user',
          nickname: '待举报用户',
          avatarKey: 'ring-green',
          totalValue: 20,
        ),
      ],
      me: LeaderboardRow(
        rank: 8,
        userId: 'user_1',
        nickname: '我',
        avatarKey: 'ring-lime',
        totalValue: 8,
      ),
    );
    LeaderboardReportType? submittedType;
    LeaderboardReportReason? submittedReason;
    final controller = _buildController(
      load: (_, __) async => snapshot,
      reportUser: (_, userId, type, reason) async {
        expect(userId, 'reported_user');
        submittedType = type;
        submittedReason = reason;
      },
    );
    await controller.load(LeaderboardPeriod.day);
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-row-actions-reported_user')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报头像'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('垃圾广告'));
    await tester.pumpAndSettle();

    expect(submittedType, LeaderboardReportType.avatar);
    expect(submittedReason, LeaderboardReportReason.spam);
    expect(find.text('待举报用户'), findsNothing);
  });

  testWidgets('report shows progress and success feedback', (tester) async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 2,
          userId: 'reported_user',
          nickname: '待举报用户',
          avatarKey: 'ring-green',
          totalValue: 20,
        ),
      ],
      me: null,
    );
    final report = Completer<void>();
    final controller = _buildController(
      load: (_, __) async => snapshot,
      reportUser: (_, __, ___, ____) => report.future,
    );
    await controller.load(LeaderboardPeriod.day);
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    await tester.longPress(
      find.byKey(const ValueKey('leaderboard-row-actions-reported_user')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报用户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('其他违规'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('正在提交举报…'), findsOneWidget);

    report.complete();
    await tester.pumpAndSettle();

    expect(find.text('已举报并屏蔽该用户'), findsOneWidget);
    expect(find.text('待举报用户'), findsNothing);
  });

  testWidgets('failed block stays retryable and succeeds locally on retry', (
    tester,
  ) async {
    const snapshot = LeaderboardSnapshot(
      period: LeaderboardPeriod.day,
      exerciseType: 'pushup',
      isJoined: true,
      top: [
        LeaderboardRow(
          rank: 3,
          userId: 'blocked_user',
          nickname: '待屏蔽用户',
          avatarKey: null,
          totalValue: 12,
        ),
      ],
      me: null,
    );
    var attempts = 0;
    final controller = _buildController(
      load: (_, __) async => snapshot,
      blockUser: (_, userId) async {
        attempts += 1;
        if (attempts == 1) throw Exception('offline');
      },
    );
    await controller.load(LeaderboardPeriod.day);
    await tester.pumpWidget(_buildApp(LeaderboardPage(controller: controller)));

    Future<void> block() async {
      await tester.longPress(
        find.byKey(const ValueKey('leaderboard-row-actions-blocked_user')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('屏蔽用户'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认屏蔽'));
      await tester.pumpAndSettle();
    }

    await block();
    expect(find.text('待屏蔽用户'), findsOneWidget);
    expect(find.text('操作失败，请重试。'), findsOneWidget);

    await block();
    expect(attempts, 2);
    expect(find.text('待屏蔽用户'), findsNothing);
  });

  group('exercise breakdown expansion', () {
    LeaderboardSnapshot pointsSnapshot({
      int? topPushup,
      int? topNarrow,
      int topTotal = 68,
    }) {
      return LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        metric: 'pushup_points_v1',
        metricUnit: 'points',
        isJoined: true,
        anonymousAvatarKey: 'ring-coral',
        top: [
          LeaderboardRow(
            rank: 1,
            userId: 'leader',
            nickname: '榜首',
            avatarKey: 'ring-green',
            totalValue: topTotal,
            pushupTotal: topPushup,
            narrowPushupTotal: topNarrow,
          ),
          const LeaderboardRow(
            rank: 2,
            userId: 'zero',
            nickname: '零分用户',
            avatarKey: 'ring-sky',
            totalValue: 0,
            pushupTotal: 0,
            narrowPushupTotal: 0,
          ),
        ],
        me: null,
      );
    }

    testWidgets('tapping a ranked row with points expands the breakdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardPage(snapshot: pointsSnapshot(topPushup: 56, topNarrow: 6)),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed initially: no breakdown labels visible.
      expect(find.text('标准'), findsNothing);
      expect(find.text('窄距'), findsNothing);

      await tester.tap(find.text('榜首'));
      await tester.pumpAndSettle();

      // Structured breakdown: independent standard/narrow labels plus the
      // rep numbers beneath the tapped row.
      expect(find.text('标准'), findsOneWidget);
      expect(find.text('窄距'), findsOneWidget);
      expect(find.text('56'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('tapping the same row again collapses the breakdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardPage(snapshot: pointsSnapshot(topPushup: 56, topNarrow: 6)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('榜首'));
      await tester.pumpAndSettle();
      expect(find.text('标准'), findsOneWidget);
      expect(find.text('窄距'), findsOneWidget);

      await tester.tap(find.text('榜首'));
      await tester.pumpAndSettle();
      expect(find.text('标准'), findsNothing);
      expect(find.text('窄距'), findsNothing);
    });

    testWidgets('a zero-point row does not expand', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardPage(snapshot: pointsSnapshot(topPushup: 56, topNarrow: 6)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('零分用户'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('leaderboard-row-details-zero')),
        findsNothing,
      );
    });
  });
}

Widget _buildApp(
  Widget home, {
  Locale locale = const Locale('zh'),
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Future<AccountController> _signedInAccount({required bool isPremium}) async {
  final controller = AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient: _AccountMembershipApiClient(isPremium),
    revenueCat: FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
  );
  await controller.signIn();
  return controller;
}

class _AccountMembershipApiClient extends MembershipApiClient {
  _AccountMembershipApiClient(this.isPremium)
    : super(baseUrl: 'https://api.example.com');

  final bool isPremium;

  @override
  Future<AccountSnapshot> authGoogle(String idToken) async => AccountSnapshot(
    sessionToken: 'session_1',
    appUserId: 'user_1',
    user: const AppUser(
      id: 'user_1',
      displayName: '训练者',
      email: 'user@example.com',
      avatarUrl: null,
    ),
    membership: MembershipStatus(
      entitlement: 'premium',
      isActive: isPremium,
      expiresAt: null,
      source: isPremium ? 'revenuecat_verified' : 'none',
    ),
  );
}

LeaderboardController _buildController({
  SavedAccountSession? session = _session,
  LeaderboardLoad? load,
  LeaderboardLoadMore? loadMore,
  LeaderboardIdentityCommand? joinIdentity,
  LeaderboardIdentityCommand? updateIdentity,
  LeaderboardCommand? leave,
  LeaderboardReportCommand? reportUser,
  LeaderboardUserCommand? blockUser,
}) {
  return LeaderboardController(
    sessionProvider: () => session,
    load: load ?? (_, __) async => _daySnapshot,
    loadMore: loadMore,
    joinIdentity: joinIdentity ?? (_, __) async {},
    updateIdentity: updateIdentity ?? (_, __) async {},
    leave: leave ?? (_) async {},
    reportUser: reportUser,
    blockUser: blockUser,
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
