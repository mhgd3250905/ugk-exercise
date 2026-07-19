import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/leaderboard_home_rank_store.dart';
import 'package:ugk_exercise/product/leaderboard_home_rank.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaderboard scopes use Shanghai calendar boundaries', () {
    expect(
      leaderboardPeriodScope(
        LeaderboardPeriod.day,
        DateTime.utc(2026, 7, 19, 15, 59),
      ),
      '2026-07-19',
    );
    expect(
      leaderboardPeriodScope(
        LeaderboardPeriod.day,
        DateTime.utc(2026, 7, 19, 16),
      ),
      '2026-07-20',
    );
    expect(
      leaderboardPeriodScope(
        LeaderboardPeriod.week,
        DateTime.utc(2026, 7, 19, 15, 59),
      ),
      '2026-07-13',
    );
    expect(
      leaderboardPeriodScope(
        LeaderboardPeriod.week,
        DateTime.utc(2026, 7, 19, 16),
      ),
      '2026-07-20',
    );
  });

  test(
    'secure store round-trips only the matching account period and scope',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final store = SecureLeaderboardHomeRankStore(storage: storage);
      const rank = LeaderboardHomeRank(
        ownerAppUserId: 'user/A',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 0,
      );

      await store.save(rank);

      expect(
        await store.load(
          appUserId: 'user/A',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
        ),
        rank,
      );
      expect(
        await store.load(
          appUserId: 'user/B',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
        ),
        isNull,
      );
      expect(
        await store.load(
          appUserId: 'user/A',
          period: LeaderboardPeriod.week,
          periodScope: '2026-07-20',
        ),
        isNull,
      );
      expect(
        await store.load(
          appUserId: 'user/A',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-21',
        ),
        isNull,
      );
    },
  );

  test(
    'secure store ignores corrupt and obsolete cached rank payloads',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final store = SecureLeaderboardHomeRankStore(storage: storage);
      const rank = LeaderboardHomeRank(
        ownerAppUserId: 'user_1',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      final key = SecureLeaderboardHomeRankStore.keyFor(
        appUserId: rank.ownerAppUserId,
        period: rank.period,
      );

      await storage.write(key: key, value: 'not-json');
      expect(
        await store.load(
          appUserId: rank.ownerAppUserId,
          period: rank.period,
          periodScope: rank.periodScope,
        ),
        isNull,
      );

      final obsolete = rank.toJson()..['schemaVersion'] = 0;
      await storage.write(key: key, value: jsonEncode(obsolete));
      expect(
        await store.load(
          appUserId: rank.ownerAppUserId,
          period: rank.period,
          periodScope: rank.periodScope,
        ),
        isNull,
      );

      final oldMetric = rank.toJson()..['metric'] = 'pushup_points_v0';
      await storage.write(key: key, value: jsonEncode(oldMetric));
      expect(
        await store.load(
          appUserId: rank.ownerAppUserId,
          period: rank.period,
          periodScope: rank.periodScope,
        ),
        isNull,
      );
    },
  );

  test(
    'clearing one account removes both periods but not another account',
    () async {
      final store = MemoryLeaderboardHomeRankStore();
      const accountADay = LeaderboardHomeRank(
        ownerAppUserId: 'account_A',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 2,
        totalValue: 14,
      );
      const accountAWeek = LeaderboardHomeRank(
        ownerAppUserId: 'account_A',
        period: LeaderboardPeriod.week,
        periodScope: '2026-07-20',
        rank: 3,
        totalValue: 48,
      );
      const accountBDay = LeaderboardHomeRank(
        ownerAppUserId: 'account_B',
        period: LeaderboardPeriod.day,
        periodScope: '2026-07-20',
        rank: 1,
        totalValue: 24,
      );
      await store.save(accountADay);
      await store.save(accountAWeek);
      await store.save(accountBDay);

      await store.clearForAccount('account_A');

      expect(
        await store.load(
          appUserId: 'account_A',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
        ),
        isNull,
      );
      expect(
        await store.load(
          appUserId: 'account_A',
          period: LeaderboardPeriod.week,
          periodScope: '2026-07-20',
        ),
        isNull,
      );
      expect(
        await store.load(
          appUserId: 'account_B',
          period: LeaderboardPeriod.day,
          periodScope: '2026-07-20',
        ),
        accountBDay,
      );
    },
  );
}
