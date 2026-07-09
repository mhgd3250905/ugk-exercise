import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ugk_exercise/platform/membership_api_client.dart';

void main() {
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
}
