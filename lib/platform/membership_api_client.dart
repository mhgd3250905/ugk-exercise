import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../product/app_update.dart';
import '../product/leaderboard_models.dart';
import '../product/exercise_type.dart';
import '../product/membership_status.dart';
import '../product/workout_session_store.dart';
import 'ugk_log.dart';

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
    final localDate = session.localDate;
    final timezoneOffsetMinutes = session.timezoneOffsetMinutes;
    if (localDate == null || timezoneOffsetMinutes == null) {
      throw StateError('Workout session is missing fixed local metadata');
    }
    return WorkoutSyncRequest(
      clientSessionId: session.id,
      exerciseType: session.exerciseType,
      startedAt: session.startedAt.toUtc(),
      endedAt: session.endedAt.toUtc(),
      localDate: _formatWorkoutLocalDate(localDate),
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      metricValue: session.count,
      metricUnit: 'reps',
    );
  }

  Map<String, Object> toJson() => {
    'clientSessionId': clientSessionId,
    'exerciseType': exerciseType,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
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
  const MembershipApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.responseBody,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? responseBody;

  @override
  String toString() => 'MembershipApiException: $message';
}

class MembershipApiClient {
  MembershipApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _httpClient = httpClient ?? http.Client(),
       _requestTimeout = requestTimeout;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration _requestTimeout;

  Future<AppReleaseInfo> latestAppRelease({
    required String languageCode,
  }) async {
    final normalizedLanguage = languageCode
        .trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    final response = await _awaitResponse(
      _httpClient.get(
        _baseUri
            .resolve('app-update')
            .replace(
              queryParameters: {
                'platform': 'android',
                'locale': normalizedLanguage == 'zh' ? 'zh' : 'en',
              },
            ),
      ),
    );
    try {
      return AppReleaseInfo.fromApiJson(_parseJson(response));
    } catch (error) {
      _logParseError('app-update', response, error);
      rethrow;
    }
  }

  Future<AccountSnapshot> authGoogle(String idToken) async {
    final response = await _awaitResponse(
      _httpClient.post(
        _baseUri.resolve('auth/google'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      ),
    );
    return _parseAccountResponse(response);
  }

  Future<AccountSnapshot> me(
    String sessionToken, {
    required String appUserId,
  }) async {
    final response = await _awaitResponse(
      _httpClient.get(
        _baseUri.resolve('me'),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
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

  Future<MembershipStatus> reconcileMembership(String sessionToken) async {
    final response = await _awaitResponse(
      _httpClient.post(
        _baseUri.resolve('membership/reconcile'),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
    return MembershipStatus.fromJson(_parseJson(response));
  }

  Future<AppUser> updateProfile(
    String sessionToken, {
    required String nickname,
    required String avatarKey,
  }) async {
    final response = await _awaitResponse(
      _httpClient.patch(
        _baseUri.resolve('me/profile'),
        headers: {
          'authorization': 'Bearer $sessionToken',
          'content-type': 'application/json',
        },
        body: jsonEncode({'nickname': nickname, 'avatarKey': avatarKey}),
      ),
    );
    final parsed = _parseJson(response);
    return AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map));
  }

  Future<void> acceptAvatarPolicy(
    String sessionToken, {
    required String policyVersion,
  }) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.post(
          _baseUri.resolve('me/avatar-policy/accept'),
          headers: {
            'authorization': 'Bearer $sessionToken',
            'content-type': 'application/json',
          },
          body: jsonEncode({'policyVersion': policyVersion}),
        ),
      ),
    );
  }

  Future<AppUser> uploadAvatar(String sessionToken, Uint8List jpegBytes) async {
    final response = await _awaitResponse(
      _httpClient.put(
        _baseUri.resolve('me/avatar'),
        headers: {
          'authorization': 'Bearer $sessionToken',
          'content-type': 'image/jpeg',
        },
        body: jpegBytes,
      ),
    );
    final parsed = _parseJson(response);
    return AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map));
  }

  Future<AppUser> deleteAvatar(String sessionToken) async {
    final response = await _awaitResponse(
      _httpClient.delete(
        _baseUri.resolve('me/avatar'),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
    final parsed = _parseJson(response);
    return AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map));
  }

  Future<void> reportLeaderboardUser(
    String sessionToken, {
    required String userId,
    required LeaderboardReportType reportType,
    required LeaderboardReportReason reason,
    String? details,
  }) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.post(
          _baseUri.resolve(
            'leaderboard/users/${Uri.encodeComponent(userId)}/report',
          ),
          headers: {
            'authorization': 'Bearer $sessionToken',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'reportType': reportType.name,
            'reason': reason.name,
            if (details != null) 'details': details,
          }),
        ),
      ),
    );
  }

  Future<void> blockLeaderboardUser(String sessionToken, String userId) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.put(
          _baseUri.resolve('me/blocks/${Uri.encodeComponent(userId)}'),
          headers: {'authorization': 'Bearer $sessionToken'},
        ),
      ),
    );
  }

  Future<void> unblockLeaderboardUser(
    String sessionToken,
    String userId,
  ) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.delete(
          _baseUri.resolve('me/blocks/${Uri.encodeComponent(userId)}'),
          headers: {'authorization': 'Bearer $sessionToken'},
        ),
      ),
    );
  }

  Future<List<BlockedUser>> blockedUsers(String sessionToken) async {
    final response = await _awaitResponse(
      _httpClient.get(
        _baseUri.resolve('me/blocks'),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
    try {
      final blocks = _parseJson(response)['blocks'];
      if (blocks is! List<Object?>) {
        throw const FormatException('Invalid blocked users response');
      }
      return [
        for (final block in blocks)
          BlockedUser.fromJson(Map<String, Object?>.from(block! as Map)),
      ];
    } on FormatException catch (error) {
      _logParseError('blocked-users', response, error);
      throw const MembershipApiException('Invalid blocked users response');
    } on TypeError catch (error) {
      _logParseError('blocked-users', response, error);
      throw const MembershipApiException('Invalid blocked users response');
    }
  }

  Future<List<WorkoutSyncResult>> syncWorkouts(
    String sessionToken,
    List<WorkoutSyncRequest> workouts,
  ) async {
    final response = await _awaitResponse(
      _httpClient.post(
        _baseUri.resolve('workouts/sync'),
        headers: {
          'authorization': 'Bearer $sessionToken',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'workouts': [for (final workout in workouts) workout.toJson()],
        }),
      ),
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
    } on FormatException catch (error) {
      _logParseError('workout-sync', response, error);
      throw const MembershipApiException('Invalid workout sync response');
    } on TypeError catch (error) {
      _logParseError('workout-sync', response, error);
      throw const MembershipApiException('Invalid workout sync response');
    }
  }

  Future<List<WorkoutSession>> cloudWorkouts(
    String sessionToken, {
    required String month,
  }) async {
    final response = await _awaitResponse(
      _httpClient.get(
        _baseUri.resolve('workouts').replace(queryParameters: {'month': month}),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
    try {
      final parsed = _parseJson(response);
      final workouts = parsed['workouts'];
      if (workouts is! List) {
        throw const FormatException('Invalid cloud workouts response');
      }
      return [
        for (final item in workouts)
          _cloudWorkoutFromJson(Map<String, Object?>.from(item as Map)),
      ];
    } on FormatException catch (error) {
      _logParseError('cloud-workouts', response, error);
      throw const MembershipApiException('Invalid cloud workouts response');
    } on TypeError catch (error) {
      _logParseError('cloud-workouts', response, error);
      throw const MembershipApiException('Invalid cloud workouts response');
    }
  }

  Future<LeaderboardSnapshot> leaderboard(
    String sessionToken, {
    required LeaderboardPeriod period,
    required String metric,
    String? cursor,
  }) async {
    final response = await _awaitResponse(
      _httpClient.get(
        _baseUri
            .resolve('leaderboard')
            .replace(
              queryParameters: {
                'period': period.name,
                'metric': metric,
                if (cursor != null) 'cursor': cursor,
              },
            ),
        headers: {'authorization': 'Bearer $sessionToken'},
      ),
    );
    try {
      return LeaderboardSnapshot.fromJson(_parseJson(response));
    } on FormatException catch (error) {
      _logParseError('leaderboard', response, error);
      throw const MembershipApiException('Invalid leaderboard response');
    } on TypeError catch (error) {
      _logParseError('leaderboard', response, error);
      throw const MembershipApiException('Invalid leaderboard response');
    } on ArgumentError catch (error) {
      _logParseError('leaderboard', response, error);
      throw const MembershipApiException('Invalid leaderboard response');
    }
  }

  Future<void> joinLeaderboard(
    String sessionToken,
    LeaderboardIdentityChoice choice,
  ) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.post(
          _baseUri.resolve('leaderboard/join'),
          headers: {
            'authorization': 'Bearer $sessionToken',
            'content-type': 'application/json',
          },
          body: jsonEncode(choice.toJson()),
        ),
      ),
    );
  }

  Future<void> updateLeaderboardIdentity(
    String sessionToken,
    LeaderboardIdentityChoice choice,
  ) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.patch(
          _baseUri.resolve('leaderboard/identity'),
          headers: {
            'authorization': 'Bearer $sessionToken',
            'content-type': 'application/json',
          },
          body: jsonEncode(choice.toJson()),
        ),
      ),
    );
  }

  Future<void> leaveLeaderboard(String sessionToken) async {
    _parseJson(
      await _awaitResponse(
        _httpClient.post(
          _baseUri.resolve('leaderboard/leave'),
          headers: {'authorization': 'Bearer $sessionToken'},
        ),
      ),
    );
  }

  Future<http.Response> _awaitResponse(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const MembershipApiException(
        'Request timed out',
        errorCode: 'request_timeout',
      );
    }
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
      String? errorCode;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is String) {
          errorCode = decoded['error'] as String;
        }
      } on FormatException {
        // Non-JSON error bodies are still preserved verbatim below.
      }
      throw MembershipApiException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        errorCode: errorCode,
        responseBody: response.body,
      );
    }
    return Map<String, Object?>.from(jsonDecode(response.body) as Map);
  }

  void _logParseError(String operation, http.Response response, Object error) {
    var errorCode = 'none';
    try {
      final decoded = jsonDecode(response.body);
      final candidate = decoded is Map ? decoded['error'] : null;
      if (candidate is String) {
        errorCode = RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(candidate)
            ? candidate
            : 'redacted';
      }
    } on FormatException {
      // The response body is intentionally not logged.
    }
    ugkLog(
      'api: parse-error operation=$operation '
      'status=${response.statusCode} errorCode=$errorCode '
      'bodyLength=${response.bodyBytes.length} type=${error.runtimeType}',
    );
  }

  WorkoutSession _cloudWorkoutFromJson(Map<String, Object?> json) {
    final clientSessionId = json['clientSessionId'];
    final exerciseType = json['exerciseType'];
    final startedAt = json['startedAt'];
    final endedAt = json['endedAt'];
    final localDate = json['localDate'];
    final metricValue = json['metricValue'];
    final metricUnit = json['metricUnit'];
    if (clientSessionId is! String ||
        exerciseType is! String ||
        startedAt is! String ||
        endedAt is! String ||
        localDate is! String ||
        metricValue is! int ||
        metricUnit is! String ||
        !ExerciseType.values.any((type) => type.storageValue == exerciseType) ||
        metricUnit != 'reps' ||
        metricValue <= 0 ||
        metricValue > 1000) {
      throw const FormatException('Invalid cloud workouts response');
    }
    return WorkoutSession(
      id: clientSessionId,
      exerciseType: exerciseType,
      startedAt: DateTime.parse(startedAt).toUtc(),
      endedAt: DateTime.parse(endedAt).toUtc(),
      localDate: _parseCloudLocalDate(localDate),
      count: metricValue,
      syncStatus: WorkoutSyncStatus.synced,
    );
  }

  DateTime _parseCloudLocalDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid cloud workouts response');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Invalid cloud workouts response');
    }
    return date;
  }
}

String _formatWorkoutLocalDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
