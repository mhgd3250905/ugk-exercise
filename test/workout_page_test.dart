import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/workout_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/pages/workout_page.dart';

void main() {
  testWidgets('explains on-device camera processing before starting', (
    tester,
  ) async {
    final controller = _FakeWorkoutController();

    await tester.pumpWidget(_workoutApp(controller: controller));
    await tester.pump();

    expect(controller.startCalls, 0);
    expect(find.text('相机与端侧处理'), findsOneWidget);
    expect(find.textContaining('原始画面不会上传'), findsOneWidget);

    await tester.tap(find.text('我知道了，开始训练'));
    await tester.pump();

    expect(controller.startCalls, 1);
  });

  testWidgets('keeps the count progress ring circular on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final ring = find.byWidgetPredicate(
      (widget) => widget is CircularProgressIndicator && widget.value != null,
    );
    final size = tester.getSize(ring);

    expect(size.width, size.height);
  });

  testWidgets('aligns camera controls with the workout status', (tester) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final statusY = tester.getCenter(find.text('已准备')).dy;
    expect(
      tester.getCenter(find.byIcon(Icons.close_rounded)).dy,
      closeTo(statusY, 2),
    );
    expect(
      tester.getCenter(find.byIcon(Icons.tune_rounded)).dy,
      closeTo(statusY, 2),
    );
  });

  testWidgets('uses restrained count and stop control styling', (tester) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final ring = find.byWidgetPredicate(
      (widget) => widget is CircularProgressIndicator && widget.value != null,
    );
    final count = find.text('7');
    expect(tester.getCenter(count).dx, closeTo(tester.getCenter(ring).dx, 0.1));
    expect(tester.widget<Text>(count).style?.fontSize, 72);

    final stopButton = find.ancestor(
      of: find.text('结束训练'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    final shape =
        tester
                .widget<FilledButton>(stopButton)
                .style
                ?.shape
                ?.resolve(<WidgetState>{})
            as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(16));
    expect(
      find.descendant(
        of: stopButton,
        matching: find.byIcon(Icons.stop_circle_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('places workout guidance above the count panel', (tester) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final guidance = find.byKey(const ValueKey('workout-guidance-chip'));
    final panel = find.byKey(const ValueKey('workout-count-panel'));
    expect(
      tester.getRect(guidance).bottom,
      lessThan(tester.getRect(panel).top),
    );
    expect(
      find.descendant(of: panel, matching: find.text('训练中')),
      findsNothing,
    );
  });

  testWidgets('fits the API 35 emulator viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.view.padding = const FakeViewPadding(bottom: 63);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the workout page in English', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _workoutApp(
        controller: _FakeWorkoutController(),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text("Today's goal"), findsOneWidget);
    expect(find.text('100 reps'), findsOneWidget);
    expect(find.text('Burned'), findsOneWidget);
    expect(find.text('32 kcal'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('End workout'), findsOneWidget);
    expect(find.text('训练中'), findsNothing);
  });

  testWidgets('shows retryable save error when append fails after stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _FakeWorkoutController();
    final store = _ThrowingSessionStore();

    await tester.pumpWidget(_workoutApp(store: store, controller: controller));
    await tester.pump();
    await tester.tap(find.text('我知道了，开始训练'));
    await tester.pump();

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
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
    await tester.tap(find.text('我知道了，开始训练'));
    await tester.pump();

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

Widget _workoutApp({
  WorkoutSessionStore? store,
  required WorkoutController controller,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: WorkoutPage(
      store: store ?? WorkoutSessionStore(),
      controller: controller,
    ),
  );
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
  var startCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
  }

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
