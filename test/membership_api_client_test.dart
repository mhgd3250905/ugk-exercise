import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  test('reconcileMembership posts bearer token and parses status', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/membership/reconcile',
        );
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '''
          {
            "entitlement": "premium",
            "isActive": true,
            "expiresAt": "2026-08-15T00:00:00.000Z",
            "source": "revenuecat_verified"
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final membership = await client.reconcileMembership('session_1');

    expect(membership.isActive, isTrue);
    expect(membership.source, 'revenuecat_verified');
  });

  test('reconcileMembership preserves membership sync error code', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient(
        (_) async =>
            http.Response('{"error":"membership_sync_unavailable"}', 503),
      ),
    );

    await expectLater(
      client.reconcileMembership('session_1'),
      throwsA(
        isA<MembershipApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          'membership_sync_unavailable',
        ),
      ),
    );
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

  test('avatar and moderation APIs send the exact Worker contract', () async {
    var call = 0;
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        call += 1;
        expect(request.headers['authorization'], 'Bearer session_1');
        switch (call) {
          case 1:
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://api.example.com/me/avatar-policy/accept',
            );
            expect(jsonDecode(request.body), {'policyVersion': '2026-07-14'});
            return http.Response('{}', 200);
          case 2:
            expect(request.method, 'PUT');
            expect(request.url.toString(), 'https://api.example.com/me/avatar');
            expect(request.headers['content-type'], 'image/jpeg');
            expect(request.bodyBytes, [0xff, 0xd8, 0xff, 0xd9]);
            return http.Response(_avatarUserJson('custom.jpg'), 200);
          case 3:
            expect(request.method, 'DELETE');
            expect(request.url.toString(), 'https://api.example.com/me/avatar');
            return http.Response(_avatarUserJson(null), 200);
          case 4:
            expect(request.method, 'POST');
            expect(
              request.url.toString(),
              'https://api.example.com/leaderboard/users/target-user/report',
            );
            expect(jsonDecode(request.body), {
              'reportType': 'avatar',
              'reason': 'impersonation',
              'details': 'not this person',
            });
            return http.Response('{}', 200);
          case 5:
            expect(request.method, 'PUT');
            expect(
              request.url.toString(),
              'https://api.example.com/me/blocks/target-user',
            );
            return http.Response('{}', 200);
          case 6:
            expect(request.method, 'DELETE');
            expect(
              request.url.toString(),
              'https://api.example.com/me/blocks/target-user',
            );
            return http.Response('{}', 200);
          default:
            throw StateError('unexpected request');
        }
      }),
    );

    await client.acceptAvatarPolicy('session_1', policyVersion: '2026-07-14');
    expect(
      (await client.uploadAvatar(
        'session_1',
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      )).customAvatarUrl,
      endsWith('custom.jpg'),
    );
    expect((await client.deleteAvatar('session_1')).customAvatarUrl, isNull);
    await client.reportLeaderboardUser(
      'session_1',
      userId: 'target-user',
      reportType: LeaderboardReportType.avatar,
      reason: LeaderboardReportReason.impersonation,
      details: 'not this person',
    );
    await client.blockLeaderboardUser('session_1', 'target-user');
    await client.unblockLeaderboardUser('session_1', 'target-user');
    expect(call, 6);
  });

  test('avatar API preserves stable Worker error codes', () async {
    const body = '{"error":"avatar_too_large"}';
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((_) async => http.Response(body, 413)),
    );

    await expectLater(
      client.uploadAvatar('session_1', Uint8List(1)),
      throwsA(
        isA<MembershipApiException>()
            .having((error) => error.statusCode, 'statusCode', 413)
            .having(
              (error) => error.errorCode,
              'errorCode',
              'avatar_too_large',
            ),
      ),
    );
  });

  test('blocked users API reads the private public-identity list', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.example.com/me/blocks');
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          jsonEncode({
            'blocks': [
              {
                'userId': 'anonymous-user',
                'nickname': null,
                'avatarKey': 'ring-coral',
                'avatarUrl': null,
              },
            ],
          }),
          200,
        );
      }),
    );

    final blocks = await client.blockedUsers('session_1');

    expect(blocks, hasLength(1));
    expect(blocks.single.userId, 'anonymous-user');
    expect(blocks.single.nickname, isNull);
    expect(blocks.single.avatarKey, 'ring-coral');
    expect(blocks.single.avatarUrl, isNull);
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

  test('cloudWorkouts accepts narrow pushup sessions', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        return http.Response(
          '''
          {
            "workouts": [
              {
                "clientSessionId": "narrow-1",
                "exerciseType": "narrow_pushup",
                "startedAt": "2026-07-09T01:00:00.000Z",
                "endedAt": "2026-07-09T01:03:00.000Z",
                "localDate": "2026-07-09",
                "metricValue": 12,
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

    expect(sessions.single.exerciseType, 'narrow_pushup');
    expect(sessions.single.count, 12);
  });

  test(
    'cloudWorkouts wraps malformed response as MembershipApiException',
    () async {
      final logs = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) {
          logs.add(message);
        }
      };
      addTearDown(() => debugPrint = previousDebugPrint);
      const responseBody = '''
          {
            "error": "invalid_payload",
            "diagnostic": "private@example.com",
            "workouts": [
              {"clientSessionId": "s1", "metricValue": "20"}
            ]
          }
          ''';
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            responseBody,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        client.cloudWorkouts('session_1', month: '2026-07'),
        throwsA(
          isA<MembershipApiException>().having(
            (error) => error.message,
            'message',
            'Invalid cloud workouts response',
          ),
        ),
      );
      expect(
        logs,
        contains(
          'UGK api: parse-error operation=cloud-workouts status=200 '
          'errorCode=invalid_payload bodyLength=${utf8.encode(responseBody).length} '
          'type=FormatException',
        ),
      );
      expect(logs.join('\n'), isNot(contains('private@example.com')));
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

  test('retired custom leaderboard identity is rejected', () {
    expect(
      () => LeaderboardIdentityChoice.fromJson(const {
        'mode': 'custom',
        'nickname': '训练者',
        'avatarKey': 'ring-green',
      }),
      throwsFormatException,
    );
  });

  test('identity JSON contains only the selected mode', () {
    for (final mode in [
      LeaderboardIdentityMode.profile,
      LeaderboardIdentityMode.anonymous,
    ]) {
      expect(LeaderboardIdentityChoice(mode: mode).toJson(), {
        'mode': mode.name,
      });
    }
  });

  test('leaderboard rejects a negative frozen score', () {
    expect(
      () => LeaderboardSnapshot.fromJson({
        'period': 'day',
        'metric': 'pushup_points_v1',
        'metricUnit': 'points',
        'isJoined': true,
        'canJoin': false,
        'anonymousAvatarKey': 'ring-green',
        'frozenTotalValue': -1,
        'top': <Object?>[],
        'me': null,
      }),
      throwsFormatException,
    );
  });

  test('leaderboard rejects invalid personal exercise counts', () {
    expect(
      () => LeaderboardSnapshot.fromJson({
        'period': 'day',
        'metric': 'pushup_points_v1',
        'metricUnit': 'points',
        'isJoined': true,
        'canJoin': true,
        'anonymousAvatarKey': 'ring-green',
        'myExerciseCounts': {'pushup': -1, 'narrow_pushup': 6},
        'top': <Object?>[],
        'me': null,
      }),
      throwsFormatException,
    );
  });

  test('leaderboard requests and parses the points v1 metric', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), contains('/leaderboard?'));
        expect(request.url.queryParameters['period'], 'day');
        expect(request.url.queryParameters['metric'], 'pushup_points_v1');
        expect(request.url.queryParameters['exerciseType'], isNull);
        expect(request.url.queryParameters['cursor'], 'next-page-token');
        expect(request.headers['authorization'], 'Bearer session_1');
        return http.Response(
          '''
          {
            "period": "day",
            "metric": "pushup_points_v1",
            "metricUnit": "points",
            "isJoined": true,
            "canJoin": false,
            "anonymousAvatarKey": "ring-coral",
            "nextCursor": "following-page-token",
            "frozenTotalValue": 42,
            "myExerciseCounts": {"pushup": 8, "narrow_pushup": 6},
            "top": [
              {"rank": 1, "userId": "u1", "nickname": null, "avatarKey": null, "avatarUrl": "https://example.com/u1.png", "totalValue": 80}
            ],
            "me": {"rank": 12, "userId": "me", "nickname": "我", "avatarKey": "ring-lime", "avatarUrl": null, "totalValue": 20},
            "identity": {"mode": "profile"}
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
      metric: 'pushup_points_v1',
      cursor: 'next-page-token',
    );

    expect(board.top.single.rank, 1);
    expect(board.metric, 'pushup_points_v1');
    expect(board.metricUnit, 'points');
    expect(board.top.single.nickname, isNull);
    expect(board.top.single.avatarUrl, 'https://example.com/u1.png');
    expect(board.isJoined, isTrue);
    expect((board as dynamic).canJoin, isFalse);
    expect(board.me?.rank, 12);
    expect(board.identity?.mode, LeaderboardIdentityMode.profile);
    expect(board.anonymousAvatarKey, 'ring-coral');
    expect(board.nextCursor, 'following-page-token');
    expect((board as dynamic).frozenTotalValue, 42);
    expect(board.myExerciseCounts?.pushup, 8);
    expect(board.myExerciseCounts?.narrowPushup, 6);
  });

  test('leaderboard rejects missing or invalid anonymous avatar key', () async {
    for (final field in [null, 'bolt-green', '', 42]) {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'period': 'day',
              'metric': 'pushup_points_v1',
              'metricUnit': 'points',
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
          metric: 'pushup_points_v1',
        ),
        throwsA(isA<MembershipApiException>()),
      );
    }
  });

  test(
    'leaderboard remains compatible with points responses before canJoin',
    () async {
      final client = MembershipApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((_) async {
          return http.Response(
            '''
          {
            "period": "day",
            "metric": "pushup_points_v1",
            "metricUnit": "points",
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
        metric: 'pushup_points_v1',
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
            "metric": "pushup_points_v1",
            "metricUnit": "points",
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
          metric: 'pushup_points_v1',
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

  test('leaderboard rejects a legacy reps response from an old Worker', () async {
    final client = MembershipApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'period': 'day',
            'exerciseType': 'pushup',
            'isJoined': true,
            'top': <Object?>[],
            'me': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(
      () => client.leaderboard(
        'session_1',
        period: LeaderboardPeriod.day,
        metric: 'pushup_points_v1',
      ),
      throwsA(
        isA<MembershipApiException>().having(
          (error) => error.message,
          'message',
          'Invalid leaderboard response',
        ),
      ),
    );
  });

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
            "metric": "pushup_points_v1",
            "metricUnit": "points",
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
          metric: 'pushup_points_v1',
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
        expect(jsonDecode(request.body), {'mode': 'profile'});
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.joinLeaderboard(
      'session_1',
      const LeaderboardIdentityChoice(mode: LeaderboardIdentityMode.profile),
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

String _avatarUserJson(String? customAvatar) => jsonEncode({
  'user': {
    'id': 'user_1',
    'displayName': 'User',
    'email': 'user@example.com',
    'avatarUrl': 'https://example.com/google.png',
    'customAvatarUrl': customAvatar == null
        ? null
        : 'https://api.example.com/avatars/$customAvatar',
    'avatarPolicyVersion': '2026-07-14',
    'avatarPolicyAccepted': true,
    'avatarUploadSuspended': false,
  },
});
