import 'package:test/test.dart';
import 'package:ugk_exercise/inference/delegate_mode.dart';

void main() {
  test('cycles delegate modes in UI order', () {
    expect(nextDelegateMode(DelegateMode.cpu), DelegateMode.nnapi);
    expect(nextDelegateMode(DelegateMode.nnapi), DelegateMode.gpu);
    expect(nextDelegateMode(DelegateMode.gpu), DelegateMode.cpu);
  });
}
