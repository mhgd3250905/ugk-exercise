import '../product/app_update.dart';

typedef LatestAppReleaseLoader =
    Future<AppReleaseInfo> Function(String languageCode);
typedef InstalledBuildLoader = Future<int> Function();
typedef PlayUpdateAvailabilityLoader = Future<bool> Function();

class AppUpdateChecker {
  const AppUpdateChecker({
    required this.loadLatestRelease,
    required this.loadInstalledBuild,
    required this.playUpdateAvailable,
    this.timeout = const Duration(seconds: 4),
  });

  final LatestAppReleaseLoader loadLatestRelease;
  final InstalledBuildLoader loadInstalledBuild;
  final PlayUpdateAvailabilityLoader playUpdateAvailable;
  final Duration timeout;

  Future<AppReleaseInfo?> check({required String languageCode}) async {
    try {
      return await _check(languageCode).timeout(timeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<AppReleaseInfo?> _check(String languageCode) async {
    final latestFuture = loadLatestRelease(languageCode);
    final installedFuture = loadInstalledBuild();
    final latest = await latestFuture;
    final installedBuild = await installedFuture;
    if (latest.versionCode <= installedBuild) return null;
    return await playUpdateAvailable() ? latest : null;
  }
}
