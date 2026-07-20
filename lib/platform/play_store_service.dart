import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const playStoreChannel = MethodChannel(
  'com.ugkexercise.ugk_exercise/play_store',
);
final playStoreProductUrl = Uri.parse(
  'https://play.google.com/store/apps/details?id=com.ugkexercise.ugk_exercise',
);

typedef ExternalUrlLauncher = Future<bool> Function(Uri url);

class PlayStoreService {
  PlayStoreService({
    this.channel = playStoreChannel,
    ExternalUrlLauncher? launchExternalUrl,
  }) : _launchExternalUrl = launchExternalUrl ?? _launchExternal;

  final MethodChannel channel;
  final ExternalUrlLauncher _launchExternalUrl;

  Future<bool> openProductPage() async {
    try {
      final opened = await channel.invokeMethod<bool>('openProductPage');
      if (opened == true) return true;
    } catch (_) {}

    try {
      return await _launchExternalUrl(playStoreProductUrl);
    } catch (_) {
      return false;
    }
  }
}

Future<bool> _launchExternal(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);
