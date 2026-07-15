import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/ui/pages/blocked_users_page.dart';

void main() {
  testWidgets('failed unblock keeps the row retryable, then removes it', (
    tester,
  ) async {
    var attempts = 0;
    final controller = _controller(
      loadBlockedUsers: (_) async => const [
        BlockedUser(
          userId: 'blocked-user',
          nickname: '待解除用户',
          avatarKey: 'ring-lime',
          avatarUrl: null,
        ),
      ],
      unblockUser: (_, __) async {
        attempts += 1;
        if (attempts == 1) {
          throw const MembershipApiException('offline');
        }
      },
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('待解除用户'), findsOneWidget);
    await tester.tap(find.text('解除屏蔽'));
    await tester.pumpAndSettle();
    expect(find.text('待解除用户'), findsOneWidget);
    expect(find.text('解除屏蔽失败，请重试。'), findsOneWidget);

    await tester.tap(find.text('解除屏蔽'));
    await tester.pumpAndSettle();
    expect(find.text('待解除用户'), findsNothing);
    expect(find.text('暂无已屏蔽用户'), findsOneWidget);
  });

  testWidgets('load failure exposes a retry action', (tester) async {
    var attempts = 0;
    final controller = _controller(
      loadBlockedUsers: (_) async {
        attempts += 1;
        if (attempts == 1) {
          throw const MembershipApiException('offline');
        }
        return const [];
      },
      unblockUser: (_, __) async {},
    );
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('无法加载屏蔽名单，请稍后重试。'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('暂无已屏蔽用户'), findsOneWidget);
  });
}

LeaderboardController _controller({
  required LeaderboardBlockedUsersLoad loadBlockedUsers,
  required LeaderboardUserCommand unblockUser,
}) => LeaderboardController(
  sessionProvider: () =>
      const SavedAccountSession(sessionToken: 'session_1', appUserId: 'user_1'),
  load: (_, period) async => LeaderboardSnapshot(
    period: period,
    exerciseType: 'pushup',
    isJoined: true,
    top: const [],
    me: null,
  ),
  joinIdentity: (_, __) async {},
  updateIdentity: (_, __) async {},
  leave: (_) async {},
  loadBlockedUsers: loadBlockedUsers,
  unblockUser: unblockUser,
);

Widget _app(LeaderboardController controller) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlockedUsersPage(controller: controller),
);
