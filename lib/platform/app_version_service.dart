import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  const AppVersionService();

  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  }

  Future<int> installedBuildNumber() async {
    final info = await PackageInfo.fromPlatform();
    return int.parse(info.buildNumber);
  }

  Future<bool> updateAvailable() async {
    final info = await _updateInfo();
    return info?.updateAvailability == UpdateAvailability.updateAvailable;
  }

  Future<int?> availableUpdateBuildNumber() async {
    final info = await _updateInfo();
    if (info?.updateAvailability != UpdateAvailability.updateAvailable) {
      return null;
    }
    return info?.availableVersionCode;
  }

  Future<AppUpdateInfo?> _updateInfo() async {
    try {
      return await InAppUpdate.checkForUpdate();
    } catch (_) {
      return null;
    }
  }
}
