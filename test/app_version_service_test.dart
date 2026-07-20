import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ugk_exercise/platform/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const updateChannel = MethodChannel('de.ffuf.in_app_update/methods');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, null);
  });

  test(
    'installedBuildNumber returns the integer Android build number',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'PushupAI',
        packageName: 'com.ugkexercise.ugk_exercise',
        version: '0.3.14',
        buildNumber: '17',
        buildSignature: '',
      );

      expect(await const AppVersionService().installedBuildNumber(), 17);
    },
  );

  test('installedBuildNumber rejects a malformed build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'PushupAI',
      packageName: 'com.ugkexercise.ugk_exercise',
      version: '0.3.14',
      buildNumber: 'not-a-number',
      buildSignature: '',
    );

    await expectLater(
      const AppVersionService().installedBuildNumber(),
      throwsFormatException,
    );
  });

  test('availableUpdateBuildNumber returns the exact Play build', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          updateChannel,
          (_) async => _playUpdateInfo(availability: 2, versionCode: 18),
        );

    const service = AppVersionService();
    expect(await service.updateAvailable(), isTrue);
    expect(await service.availableUpdateBuildNumber(), 18);
  });

  test(
    'availableUpdateBuildNumber returns null without a usable Play build',
    () async {
      for (final (response, updateAvailable) in [
        (_playUpdateInfo(availability: 1, versionCode: 18), false),
        (_playUpdateInfo(availability: 2, versionCode: null), true),
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(updateChannel, (_) async => response);

        const service = AppVersionService();
        expect(await service.updateAvailable(), updateAvailable);
        expect(await service.availableUpdateBuildNumber(), isNull);
      }
    },
  );
}

Map<String, Object?> _playUpdateInfo({
  required int availability,
  required int? versionCode,
}) => {
  'updateAvailability': availability,
  'immediateAllowed': true,
  'immediateAllowedPreconditions': <int>[],
  'flexibleAllowed': true,
  'flexibleAllowedPreconditions': <int>[],
  'availableVersionCode': versionCode,
  'installStatus': 0,
  'packageName': 'com.ugkexercise.ugk_exercise',
  'clientVersionStalenessDays': 1,
  'updatePriority': 0,
};
