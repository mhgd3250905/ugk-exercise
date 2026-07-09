import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/workout_controller.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/pages/workout_page.dart';

void main() {
  testWidgets('shows retryable save error when append fails after stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _FakeWorkoutController();
    final store = _ThrowingSessionStore();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPage(store: store, controller: controller),
      ),
    );

    await tester.tap(find.text('结束训练'));
    await tester.pump();
    await tester.pump();

    expect(store.appendCalls, 1);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(find.text('重试保存'), findsOneWidget);
  });
}

class _FakeWorkoutController extends WorkoutController {
  var _running = true;
  var _stopping = false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    _running = false;
    _stopping = true;
    notifyListeners();
  }

  @override
  int get count => 7;

  @override
  bool get ready => true;

  @override
  String get status => '训练中';

  @override
  bool get stopping => _stopping;

  @override
  bool get switchingCamera => false;

  @override
  bool get running => _running;

  @override
  DateTime? get startedAt => DateTime(2026, 7, 9, 9);
}

class _ThrowingSessionStore extends WorkoutSessionStore {
  var appendCalls = 0;

  @override
  Future<void> append(WorkoutSession session) async {
    appendCalls++;
    throw StateError('disk full');
  }
}
