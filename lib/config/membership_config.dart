import 'package:flutter/foundation.dart';

const _membershipApiBaseUrlFromEnv = String.fromEnvironment(
  'UGK_MEMBERSHIP_API_BASE_URL',
);
const _googleServerClientIdFromEnv = String.fromEnvironment(
  'UGK_GOOGLE_SERVER_CLIENT_ID',
);
const _revenueCatAndroidApiKeyFromEnv = String.fromEnvironment(
  'UGK_REVENUECAT_ANDROID_API_KEY',
);

const _debugMembershipApiBaseUrl = '';
const _debugGoogleServerClientId = '';
const _debugRevenueCatAndroidApiKey = '';

const membershipApiBaseUrl = _membershipApiBaseUrlFromEnv == ''
    ? (kDebugMode ? _debugMembershipApiBaseUrl : '')
    : _membershipApiBaseUrlFromEnv;
const googleServerClientId = _googleServerClientIdFromEnv == ''
    ? (kDebugMode ? _debugGoogleServerClientId : '')
    : _googleServerClientIdFromEnv;
const revenueCatAndroidApiKey = _revenueCatAndroidApiKeyFromEnv == ''
    ? (kDebugMode ? _debugRevenueCatAndroidApiKey : '')
    : _revenueCatAndroidApiKeyFromEnv;
const premiumEntitlementId = 'premium';

void validateMembershipConfig() {
  if (!kReleaseMode) {
    return;
  }
  final missing = <String>[
    if (membershipApiBaseUrl.isEmpty) 'UGK_MEMBERSHIP_API_BASE_URL',
    if (googleServerClientId.isEmpty) 'UGK_GOOGLE_SERVER_CLIENT_ID',
    if (revenueCatAndroidApiKey.isEmpty) 'UGK_REVENUECAT_ANDROID_API_KEY',
  ];
  if (missing.isNotEmpty) {
    throw StateError(
      'Missing release membership config: ${missing.join(', ')}',
    );
  }
  if (revenueCatAndroidApiKey.startsWith('test_')) {
    throw StateError('Release RevenueCat API key must not use a test key.');
  }
}
