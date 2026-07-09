import 'package:test/test.dart';
import 'package:ugk_exercise/platform/revenuecat_service.dart';

void main() {
  test('fake revenuecat service can toggle premium for controller tests', () async {
    final service = FakeRevenueCatService(isPremium: false);

    expect(await service.refreshPremium(), isFalse);

    service.isPremium = true;
    expect(await service.refreshPremium(), isTrue);
  });
}
