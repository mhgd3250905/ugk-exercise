import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/workout_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
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

  testWidgets('cloud sync queue failure does not block leaving workout page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _FakeWorkoutController();
    final store = _RecordingSessionStore();
    final sync = _ThrowingWorkoutSyncController();

    await tester.pumpWidget(
      MaterialApp(
        home: _WorkoutPageHost(
          store: store,
          controller: controller,
          syncController: sync,
        ),
      ),
    );

    await tester.tap(find.text('开始测试训练'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(WorkoutPage), findsOneWidget);

    await tester.tap(find.text('结束训练'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(store.appendCalls, 1);
    expect(sync.queueCalls, 1);
    expect(sync.ownerCalls, 1);
    expect(store.appended?.ownerAppUserId, 'free-user');
    expect(store.appended?.startedAt.isUtc, isTrue);
    expect(store.appended?.endedAt.isUtc, isTrue);
    expect(store.appended?.localDate, DateTime(2026, 7, 9));
    expect(
      store.appended?.timezoneOffsetMinutes,
      DateTime(2026, 7, 9, 9).timeZoneOffset.inMinutes,
    );
    expect(find.byType(WorkoutPage), findsNothing);
    expect(find.text('训练页已关闭'), findsOneWidget);
  });
}

class _WorkoutPageHost extends StatelessWidget {
  const _WorkoutPageHost({
    required this.store,
    required this.controller,
    required this.syncController,
  });

  final WorkoutSessionStore store;
  final WorkoutController controller;
  final WorkoutSyncController syncController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('训练页已关闭'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutPage(
                      store: store,
                      controller: controller,
                      syncController: syncController,
                    ),
                  ),
                );
              },
              child: const Text('开始测试训练'),
            ),
          ],
        ),
      ),
    );
  }
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

class _RecordingSessionStore extends WorkoutSessionStore {
  var appendCalls = 0;
  WorkoutSession? appended;

  @override
  Future<void> append(WorkoutSession session) async {
    appendCalls++;
    appended = session;
  }
}

class _ThrowingWorkoutSyncController extends WorkoutSyncController {
  _ThrowingWorkoutSyncController()
    : super(
        store: WorkoutSessionStore(),
        sessionProvider: () => const SavedAccountSession(
          sessionToken: 'free-session',
          appUserId: 'free-user',
        ),
        premiumProvider: () => false,
        syncBatch: (account, workouts) async => const [],
      );

  var queueCalls = 0;
  var ownerCalls = 0;

  @override
  String? get currentOwnerAppUserId {
    ownerCalls += 1;
    return 'free-user';
  }

  @override
  Future<void> queueAfterLocalSave(String sessionId) async {
    queueCalls += 1;
    throw Exception('sync failed');
  }
}
