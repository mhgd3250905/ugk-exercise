import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/platform/play_store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/play-store');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native Play Store success does not open the web fallback', () async {
    MethodCall? nativeCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCall = call;
          return true;
        });
    Uri? webUrl;
    final service = PlayStoreService(
      channel: channel,
      launchExternalUrl: (url) async {
        webUrl = url;
        return true;
      },
    );

    expect(await service.openProductPage(), isTrue);
    expect(nativeCall?.method, 'openProductPage');
    expect(webUrl, isNull);
  });

  test('native Play Store failure opens the pinned HTTPS fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    Uri? webUrl;
    final service = PlayStoreService(
      channel: channel,
      launchExternalUrl: (url) async {
        webUrl = url;
        return true;
      },
    );

    expect(await service.openProductPage(), isTrue);
    expect(webUrl, playStoreProductUrl);
  });

  test('native channel exceptions still use the web fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    var webCalls = 0;
    final service = PlayStoreService(
      channel: channel,
      launchExternalUrl: (_) async {
        webCalls += 1;
        return false;
      },
    );

    expect(await service.openProductPage(), isFalse);
    expect(webCalls, 1);
  });
}
