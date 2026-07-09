import 'dart:convert';

import 'package:http/http.dart' as http;

import '../product/membership_status.dart';

class MembershipApiException implements Exception {
  const MembershipApiException(this.message);

  final String message;

  @override
  String toString() => 'MembershipApiException: $message';
}

class MembershipApiClient {
  MembershipApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  Future<AccountSnapshot> authGoogle(String idToken) async {
    final response = await _httpClient.post(
      _baseUri.resolve('auth/google'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    return _parseAccountResponse(response);
  }

  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    final response = await _httpClient.get(
      _baseUri.resolve('me'),
      headers: {'authorization': 'Bearer $sessionToken'},
    );
    final parsed = _parseJson(response);
    return AccountSnapshot(
      sessionToken: sessionToken,
      appUserId: appUserId,
      user: AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map)),
      membership: MembershipStatus.fromJson(
        Map<String, Object?>.from(parsed['membership']! as Map),
      ),
    );
  }

  AccountSnapshot _parseAccountResponse(http.Response response) {
    final parsed = _parseJson(response);
    return AccountSnapshot(
      sessionToken: parsed['sessionToken']! as String,
      appUserId: parsed['appUserId']! as String,
      user: AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map)),
      membership: MembershipStatus.fromJson(
        Map<String, Object?>.from(parsed['membership']! as Map),
      ),
    );
  }

  Map<String, Object?> _parseJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MembershipApiException('HTTP ${response.statusCode}');
    }
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }
}
