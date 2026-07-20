import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/app_update_checker.dart';
import 'package:ugk_exercise/product/app_update.dart';

const _release = AppReleaseInfo(
  versionCode: 18,
  versionName: '0.3.15',
  releaseNotes: ['新增启动更新提示'],
);

void main() {
  test(
    'returns a newer release when Google Play confirms availability',
    () async {
      String? requestedLanguage;
      var playChecks = 0;
      final checker = AppUpdateChecker(
        loadLatestRelease: (languageCode) async {
          requestedLanguage = languageCode;
          return _release;
        },
        loadInstalledBuild: () async => 17,
        loadPlayAvailableBuild: () async {
          playChecks += 1;
          return 18;
        },
      );

      expect(await checker.check(languageCode: 'zh'), same(_release));
      expect(requestedLanguage, 'zh');
      expect(playChecks, 1);
    },
  );

  test('does not ask Google Play when the manifest is not newer', () async {
    var playChecks = 0;
    final checker = AppUpdateChecker(
      loadLatestRelease: (_) async => _release,
      loadInstalledBuild: () async => 18,
      loadPlayAvailableBuild: () async {
        playChecks += 1;
        return 18;
      },
    );

    expect(await checker.check(languageCode: 'en'), isNull);
    expect(playChecks, 0);
  });

  for (final playBuild in <int?>[null, 17, 19]) {
    test('returns no release when Google Play build is $playBuild', () async {
      final checker = AppUpdateChecker(
        loadLatestRelease: (_) async => _release,
        loadInstalledBuild: () async => 17,
        loadPlayAvailableBuild: () async => playBuild,
      );

      expect(await checker.check(languageCode: 'zh'), isNull);
    });
  }

  test('fails closed when a dependency throws', () async {
    final checker = AppUpdateChecker(
      loadLatestRelease: (_) async => throw StateError('offline'),
      loadInstalledBuild: () async => 17,
      loadPlayAvailableBuild: () async => 18,
    );

    expect(await checker.check(languageCode: 'zh'), isNull);
  });

  test('fails closed when the update check times out', () async {
    final pending = Completer<AppReleaseInfo>();
    final checker = AppUpdateChecker(
      loadLatestRelease: (_) => pending.future,
      loadInstalledBuild: () async => 17,
      loadPlayAvailableBuild: () async => 18,
      timeout: const Duration(milliseconds: 5),
    );

    expect(await checker.check(languageCode: 'zh'), isNull);
  });
}
