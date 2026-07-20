import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ugk_exercise/platform/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
