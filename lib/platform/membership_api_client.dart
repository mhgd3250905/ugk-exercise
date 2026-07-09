import 'dart:convert';

import 'package:http/http.dart' as http;

import '../product/leaderboard_models.dart';
import '../product/membership_status.dart';
import '../product/workout_session_store.dart';

enum WorkoutSyncResultStatus { accepted, duplicate, rejected }

class WorkoutSyncRequest {
  const WorkoutSyncRequest({
    required this.clientSessionId,
    required this.exerciseType,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.timezoneOffsetMinutes,
    required this.metricValue,
    required this.metricUnit,
  });

  final String clientSessionId;
  final String exerciseType;
  final DateTime startedAt;
  final DateTime endedAt;
  final String localDate;
  final int timezoneOffsetMinutes;
  final int metricValue;
  final String metricUnit;

  factory WorkoutSyncRequest.fromSession(WorkoutSession session) {
    final local = session.startedAt.toLocal();
    return WorkoutSyncRequest(
      clientSessionId: session.id,
      exerciseType: session.exerciseType,
      startedAt: session.startedAt.toUtc(),
      endedAt: session.endedAt.toUtc(),
      localDate:
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}',
      timezoneOffsetMinutes: local.timeZoneOffset.inMinutes,
      metricValue: session.count,
      metricUnit: 'reps',
    );
  }

  Map<String, Object> toJson() => {
    'clientSessionId': clientSessionId,
    'exerciseType': exerciseType,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'localDate': localDate,
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
    'metricValue': metricValue,
    'metricUnit': metricUnit,
  };
}

class WorkoutSyncResult {
  const WorkoutSyncResult({
    required this.clientSessionId,
    required this.status,
    required this.aggregated,
  });

  final String clientSessionId;
  final WorkoutSyncResultStatus status;
  final bool aggregated;

  factory WorkoutSyncResult.fromJson(Map<String, Object?> json) {
    final clientSessionId = json['clientSessionId'];
    final statusName = json['status'];
    final aggregated = json['aggregated'];
    if (clientSessionId is! String ||
        statusName is! String ||
        (aggregated != null && aggregated is! bool)) {
      throw const FormatException('Invalid workout sync response');
    }
    final status = WorkoutSyncResultStatus.values
        .cast<WorkoutSyncResultStatus?>()
        .firstWhere((value) => value?.name == statusName, orElse: () => null);
    if (status == null) {
      throw const FormatException('Invalid workout sync response');
    }
    return WorkoutSyncResult(
      clientSessionId: clientSessionId,
      status: status,
      aggregated: aggregated as bool? ?? false,
    );
  }
}

class MembershipApiException implements Exception {
  const MembershipApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

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

  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) async {
    final response = await _httpClient.patch(
      _baseUri.resolve('me/profile'),
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({'nickname': nickname, 'avatarKey': avatarKey}),
    );
    final parsed = _parseJson(response);
    return AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map));
  }

  Future<List<WorkoutSyncResult>> syncWorkouts(
    String sessionToken,
    List<WorkoutSyncRequest> workouts,
  ) async {
    final response = await _httpClient.post(
      _baseUri.resolve('workouts/sync'),
      headers: {
        'authorization': 'Bearer $sessionToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'workouts': [for (final workout in workouts) workout.toJson()],
      }),
    );
    final parsed = _parseJson(response);
    try {
      final results = parsed['results'];
      if (results is! List) {
        throw const FormatException('Invalid workout sync response');
      }
      return [
        for (final item in results)
          WorkoutSyncResult.fromJson(Map<String, Object?>.from(item as Map)),
      ];
    } on FormatException {
      throw const MembershipApiException('Invalid workout sync response');
    } on TypeError {
      throw const MembershipApiException('Invalid workout sync response');
    }
  }

  Future<LeaderboardSnapshot> leaderboard(
    String sessionToken, {
    required LeaderboardPeriod period,
    required String exerciseType,
  }) async {
    final response = await _httpClient.get(
      _baseUri.resolve('leaderboard').replace(
        queryParameters: {
          'period': period.name,
          'exerciseType': exerciseType,
        },
      ),
      headers: {'authorization': 'Bearer $sessionToken'},
    );
    try {
      return LeaderboardSnapshot.fromJson(_parseJson(response));
    } on FormatException {
      throw const MembershipApiException('Invalid leaderboard response');
    } on TypeError {
      throw const MembershipApiException('Invalid leaderboard response');
    } on ArgumentError {
      throw const MembershipApiException('Invalid leaderboard response');
    }
  }

  Future<void> joinLeaderboard(String sessionToken) async {
    _parseJson(
      await _httpClient.post(
        _baseUri.resolve('leaderboard/join'),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
  }

  Future<void> leaveLeaderboard(String sessionToken) async {
    _parseJson(
      await _httpClient.post(
        _baseUri.resolve('leaderboard/leave'),
        headers: {'authorization': 'Bearer $sessionToken'},
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
      throw MembershipApiException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }
}
