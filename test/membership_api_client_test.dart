import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';

void main() {
  test('joinLeaderboard requires an explicit identity choice', () {
    expect(
      MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      ).joinLeaderboard,
      isNot(isA<Future<void> Function(String)>()),
    );
  });

  test('authGoogle posts id token and parses account snapshot', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.example.com/auth/google');
        expect(request.body, contains('google-id-token'));
        return http.Response(
          '''
          {
            "sessionToken": "session_1",
            "appUserId": "user_1",
            "user": {
              "id": "user_1",
              "displayName": "训练者",
              "email": "a@example.com",
              "avatarUrl": null
            },
            "membership": {
              "entitlement": "premium",
              "isActive": true,
              "expiresAt": "2026-08-09T00:00:00.000Z",
              "source": "revenuecat_google_play"
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final snapshot = await client.authGoogle('google-id-token');

    expect(snapshot.sessionToken, 'session_1');
    expect(snapshot.appUserId, 'user_1');
    expect(snapshot.membership.isActive, isTrue);
  });

  test('me sends bearer token', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com/',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.example.com/me');
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '''
          {
            "user": {
              "id": "user_1",
              "displayName": "训练者",
              "email": "a@example.com",
              "avatarUrl": null
            },
            "membership": {
              "entitlement": "premium",
              "isActive": false,
              "expiresAt": null,
              "source": "none"
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final snapshot = await client.me('session_1', appUserId: 'user_1');

    expect(snapshot.sessionToken, 'session_1');
    expect(snapshot.membership.isActive, isFalse);
  });

  test('updateProfile patches nickname and avatar key', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.toString(), 'https://api.example.com/me/profile');
        expect(request.headers['authorization'], 'Bearer session_1');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'nickname': '训练者 01',
          'avatarKey': 'ring-green',
        });
        return http.Response(
          '''
          {
            "user": {
              "id": "user_1",
              "displayName": "Google Name",
              "email": "a@example.com",
              "avatarUrl": null,
              "nickname": "训练者 01",
              "avatarKey": "ring-green"
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final user = await client.updateProfile(
      'session_1',
      nickname: '训练者 01',
      avatarKey: 'ring-green',
    );

    expect(user.publicDisplayName, '训练者 01');
    expect(user.displayName, 'Google Name');
    expect(user.email, 'a@example.com');
    expect(user.avatarUrl, isNull);
    expect(user.avatarKey, 'ring-green');
  });

  test('throws readable exception on server error', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async => http.Response('bad', 401)),
    );

    expect(
      () => client.authGoogle('bad-token'),
      throwsA(isA<MembershipApiException>()),
    );
  });

  test('server error preserves worker error code and response body', () async {
    const body = '{"error":"nickname_taken"}';
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async => http.Response(body, 409)),
    );

    await expectLater(
      client.updateProfile(
        'session_1',
        nickname: 'taken',
        avatarKey: 'ring-green',
      ),
      throwsA(
        isA<MembershipApiException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.errorCode, 'errorCode', 'nickname_taken')
            .having((error) => error.responseBody, 'responseBody', body),
      ),
    );
  });

  test('syncWorkouts posts a batch and parses per-item results', () async {
    final session = WorkoutSession(
      id: 's1',
      startedAt: DateTime.utc(2026, 7, 9, 1),
      endedAt: DateTime.utc(2026, 7, 9, 1, 3),
      count: 20,
      localDate: DateTime(2026, 7, 9),
      timezoneOffsetMinutes: 480,
    );
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://api.example.com/workouts/sync');
        expect(request.headers['authorization'], 'Bearer session_1');
        expect(jsonDecode(request.body), {
          'workouts': [
            {
              'clientSessionId': 's1',
              'exerciseType': 'pushup',
              'startedAt': '2026-07-09T01:00:00.000Z',
              'endedAt': '2026-07-09T01:03:00.000Z',
              'localDate': '2026-07-09',
              'timezoneOffsetMinutes': 480,
              'metricValue': 20,
              'metricUnit': 'reps',
            },
          ],
        });
        return http.Response(
          '''
          {
            "results": [
              {"clientSessionId": "s1", "status": "accepted", "aggregated": false}
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final results = await client.syncWorkouts('session_1', [
      WorkoutSyncRequest.fromSession(session),
    ]);

    expect(results.single.clientSessionId, 's1');
    expect(results.single.status, WorkoutSyncResultStatus.accepted);
  });

  test('WorkoutSyncRequest uses persisted local metadata', () {
    final session = WorkoutSession(
      id: 'fixed-facts',
      startedAt: DateTime.utc(2026, 6, 30, 16),
      endedAt: DateTime.utc(2026, 6, 30, 16, 3),
      count: 9,
      localDate: DateTime(2026, 7, 1),
      timezoneOffsetMinutes: 480,
      ownerAppUserId: 'user-a',
    );

    final request = WorkoutSyncRequest.fromSession(session);

    expect(request.startedAt, DateTime.utc(2026, 6, 30, 16));
    expect(request.endedAt, DateTime.utc(2026, 6, 30, 16, 3));
    expect(request.localDate, '2026-07-01');
    expect(request.timezoneOffsetMinutes, 480);
  });

  test('WorkoutSyncRequest rejects legacy sessions without fixed metadata', () {
    final sessions = [
      WorkoutSession(
        id: 'missing-both',
        startedAt: DateTime.utc(2026, 7, 9, 1),
        endedAt: DateTime.utc(2026, 7, 9, 1, 3),
        count: 5,
      ),
      WorkoutSession(
        id: 'missing-offset',
        startedAt: DateTime.utc(2026, 7, 9, 1),
        endedAt: DateTime.utc(2026, 7, 9, 1, 3),
        count: 5,
        localDate: DateTime(2026, 7, 9),
      ),
      WorkoutSession(
        id: 'missing-date',
        startedAt: DateTime.utc(2026, 7, 9, 1),
        endedAt: DateTime.utc(2026, 7, 9, 1, 3),
        count: 5,
        timezoneOffsetMinutes: 480,
      ),
    ];

    for (final session in sessions) {
      expect(
        () => WorkoutSyncRequest.fromSession(session),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Workout session is missing fixed local metadata',
          ),
        ),
      );
      expect(session.ownerAppUserId, isNull);
    }
  });

  test('cloudWorkouts fetches month sessions', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.com/workouts?month=2026-07',
        );
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '''
          {
            "workouts": [
              {
                "clientSessionId": "s1",
                "exerciseType": "pushup",
                "startedAt": "2026-07-09T01:00:00.000Z",
                "endedAt": "2026-07-09T01:03:00.000Z",
                "localDate": "2026-07-09",
                "metricValue": 20,
                "metricUnit": "reps"
              }
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final sessions = await client.cloudWorkouts('session_1', month: '2026-07');

    expect(sessions.single.id, 's1');
    expect(sessions.single.count, 20);
    expect(sessions.single.localDate, DateTime(2026, 7, 9));
    expect(sessions.single.syncStatus, WorkoutSyncStatus.synced);
  });

  test(
    'cloudWorkouts wraps malformed response as MembershipApiException',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            '''
          {
            "workouts": [
              {"clientSessionId": "s1", "metricValue": "20"}
            ]
          }
          ''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => client.cloudWorkouts('session_1', month: '2026-07'),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid cloud workouts response',
          ),
        ),
      );
    },
  );

  test('cloudWorkouts rejects invalid metric unit', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        return http.Response(
          '''
          {
            "workouts": [
              {
                "clientSessionId": "s1",
                "exerciseType": "pushup",
                "startedAt": "2026-07-09T01:00:00.000Z",
                "endedAt": "2026-07-09T01:03:00.000Z",
                "localDate": "2026-07-09",
                "metricValue": 20,
                "metricUnit": "seconds"
              }
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.cloudWorkouts('session_1', month: '2026-07'),
      throwsA(
        isA<MembershipApiException>().having(
          (error) => error.message,
          'message',
          'Invalid cloud workouts response',
        ),
      ),
    );
  });

  test('cloudWorkouts rejects non-positive metric value', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        return http.Response(
          '''
          {
            "workouts": [
              {
                "clientSessionId": "s1",
                "exerciseType": "pushup",
                "startedAt": "2026-07-09T01:00:00.000Z",
                "endedAt": "2026-07-09T01:03:00.000Z",
                "localDate": "2026-07-09",
                "metricValue": 0,
                "metricUnit": "reps"
              }
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.cloudWorkouts('session_1', month: '2026-07'),
      throwsA(
        isA<MembershipApiException>().having(
          (error) => error.message,
          'message',
          'Invalid cloud workouts response',
        ),
      ),
    );
  });

  test('cloudWorkouts rejects negative metric value', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        return http.Response(
          '''
          {
            "workouts": [
              {
                "clientSessionId": "s1",
                "exerciseType": "pushup",
                "startedAt": "2026-07-09T01:00:00.000Z",
                "endedAt": "2026-07-09T01:03:00.000Z",
                "localDate": "2026-07-09",
                "metricValue": -1,
                "metricUnit": "reps"
              }
            ]
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.cloudWorkouts('session_1', month: '2026-07'),
      throwsA(
        isA<MembershipApiException>().having(
          (error) => error.message,
          'message',
          'Invalid cloud workouts response',
        ),
      ),
    );
  });

  test(
    'cloudWorkouts wraps malformed JSON as MembershipApiException',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response('not-json', 200);
        }),
      );

      expect(
        () => client.cloudWorkouts('session_1', month: '2026-07'),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid cloud workouts response',
          ),
        ),
      );
    },
  );

  test(
    'syncWorkouts wraps malformed response as MembershipApiException',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            '''
          {
            "results": [
              {"clientSessionId": "s1", "status": "weird", "aggregated": false}
            ]
          }
          ''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => client.syncWorkouts('session_1', const []),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid workout sync response',
          ),
        ),
      );
    },
  );

  test('leaderboard identity rejects missing unknown or wrong-type mode', () {
    for (final json in <Map<String, Object?>>[
      const {},
      const {'mode': 'unknown'},
      const {'mode': 1},
    ]) {
      expect(
        () => LeaderboardIdentityChoice.fromJson(json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });

  test('custom leaderboard identity requires nonblank nickname and avatar', () {
    for (final json in <Map<String, Object?>>[
      const {'mode': 'custom', 'avatarKey': 'ring-green'},
      const {'mode': 'custom', 'nickname': '训练者'},
      const {'mode': 'custom', 'nickname': '   ', 'avatarKey': 'ring-green'},
      const {'mode': 'custom', 'nickname': '训练者', 'avatarKey': ' '},
    ]) {
      expect(
        () => LeaderboardIdentityChoice.fromJson(json),
        throwsFormatException,
        reason: '$json',
      );
    }
    expect(
      () => const LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.custom,
      ).toJson(),
      throwsFormatException,
    );
  });

  test('non-custom identity JSON never includes stale custom fields', () {
    for (final mode in [
      LeaderboardIdentityMode.profile,
      LeaderboardIdentityMode.anonymous,
    ]) {
      expect(
        LeaderboardIdentityChoice(
          mode: mode,
          nickname: 'must-not-leak',
          avatarKey: 'ring-green',
        ).toJson(),
        {'mode': mode.name},
      );
    }
  });

  test('leaderboard request parses top rows and my rank', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), contains('/leaderboard?'));
        expect(request.url.queryParameters['period'], 'day');
        expect(request.url.queryParameters['exerciseType'], 'push up');
        expect(request.url.queryParameters['cursor'], 'next-page-token');
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '''
          {
            "period": "day",
            "exerciseType": "push up",
            "isJoined": true,
            "canJoin": false,
            "anonymousAvatarKey": "ring-coral",
            "nextCursor": "following-page-token",
            "top": [
              {"rank": 1, "userId": "u1", "nickname": null, "avatarKey": null, "avatarUrl": "https://example.com/u1.png", "totalValue": 80}
            ],
            "me": {"rank": 12, "userId": "me", "nickname": "我", "avatarKey": "ring-lime", "avatarUrl": null, "totalValue": 20},
            "identity": {"mode": "custom", "nickname": "我", "avatarKey": "ring-lime"}
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final board = await client.leaderboard(
      'session_1',
      period: LeaderboardPeriod.day,
      exerciseType: 'push up',
      cursor: 'next-page-token',
    );

    expect(board.top.single.rank, 1);
    expect(board.top.single.nickname, isNull);
    expect(board.top.single.avatarUrl, 'https://example.com/u1.png');
    expect(board.isJoined, isTrue);
    expect((board as dynamic).canJoin, isFalse);
    expect(board.me?.rank, 12);
    expect(board.identity?.mode, LeaderboardIdentityMode.custom);
    expect(board.identity?.nickname, '我');
    expect(board.identity?.avatarKey, 'ring-lime');
    expect(board.anonymousAvatarKey, 'ring-coral');
    expect(board.nextCursor, 'following-page-token');
  });

  test('leaderboard rejects missing or invalid anonymous avatar key', () async {
    for (final field in [null, 'bolt-green', '', 42]) {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'period': 'day',
              'exerciseType': 'pushup',
              'isJoined': false,
              'canJoin': true,
              if (field != null) 'anonymousAvatarKey': field,
              'identity': null,
              'top': <Object?>[],
              'me': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        client.leaderboard(
          'session_1',
          period: LeaderboardPeriod.day,
          exerciseType: 'pushup',
        ),
        throwsA(isA<MembershipApiException>()),
      );
    }
  });

  test(
    'leaderboard remains compatible with responses before canJoin',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((_) async {
          return http.Response(
            '''
          {
            "period": "day",
            "exerciseType": "pushup",
            "isJoined": false,
            "anonymousAvatarKey": "ring-green",
            "top": [],
            "me": null
          }
          ''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final board = await client.leaderboard(
        'session_1',
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
      );

      expect((board as dynamic).canJoin, isTrue);
      expect(board.identity, isNull);
      expect(board.nextCursor, isNull);
    },
  );

  test(
    'leaderboard wraps malformed response as MembershipApiException',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            '''
          {
            "period": "month",
            "exerciseType": "pushup",
            "top": []
          }
          ''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => client.leaderboard(
          'session_1',
          period: LeaderboardPeriod.day,
          exerciseType: 'pushup',
        ),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid leaderboard response',
          ),
        ),
      );
    },
  );

  test(
    'leaderboard wraps missing isJoined as MembershipApiException',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            '''
          {
            "period": "day",
            "exerciseType": "pushup",
            "anonymousAvatarKey": "ring-green",
            "top": [],
            "me": null
          }
          ''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => client.leaderboard(
          'session_1',
          period: LeaderboardPeriod.day,
          exerciseType: 'pushup',
        ),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid leaderboard response',
          ),
        ),
      );
    },
  );

  test('joinLeaderboard posts the selected identity as JSON', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/leaderboard/join',
        );
        expect(request.headers['authorization'], 'Bearer session_1');
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {
          'mode': 'custom',
          'nickname': '训练者 01',
          'avatarKey': 'ring-green',
        });
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.joinLeaderboard(
      'session_1',
      const LeaderboardIdentityChoice(
        mode: LeaderboardIdentityMode.custom,
        nickname: '训练者 01',
        avatarKey: 'ring-green',
      ),
    );
  });

  test(
    'updateLeaderboardIdentity patches the selected identity as JSON',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(
            request.url.toString(),
            'https://api.example.com/leaderboard/identity',
          );
          expect(request.headers['authorization'], 'Bearer session_1');
          expect(request.headers['content-type'], 'application/json');
          expect(jsonDecode(request.body), {'mode': 'anonymous'});
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await client.updateLeaderboardIdentity(
        'session_1',
        const LeaderboardIdentityChoice(
          mode: LeaderboardIdentityMode.anonymous,
        ),
      );
    },
  );

  test('leaveLeaderboard posts bearer token to leave path', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/leaderboard/leave',
        );
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.leaveLeaderboard('session_1');
  });
}
