import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/control/workout_controller.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/l10n/app_localizations.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/platform/app_settings_store.dart';
import 'package:ugk_exercise/product/exercise_type.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';
import 'package:ugk_exercise/ui/app_settings.dart';
import 'package:ugk_exercise/ui/app_theme.dart';
import 'package:ugk_exercise/ui/pages/workout_page.dart';

void main() {
  testWidgets('waits for the camera notice to exit before starting', (
    tester,
  ) async {
    final controller = _FakeWorkoutController();
    var acknowledgements = 0;

    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        cameraNoticeAcknowledged: () async => false,
        acknowledgeCameraNotice: () async => acknowledgements++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.startCalls, 0);
    expect(find.text('相机与端侧处理'), findsOneWidget);
    expect(find.textContaining('原始画面不会上传'), findsOneWidget);

    await tester.tap(find.text('我知道了，开始训练'));
    await tester.pump();

    expect(controller.startCalls, 0);

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('相机与端侧处理'), findsNothing);
    expect(controller.startCalls, 1);
    expect(acknowledgements, 1);
  });

  testWidgets('acknowledged camera notice starts without another dialog', (
    tester,
  ) async {
    final controller = _FakeWorkoutController();

    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('相机与端侧处理'), findsNothing);
    expect(controller.startCalls, 1);
  });

  testWidgets('camera notice can be cancelled without starting', (
    tester,
  ) async {
    final controller = _FakeWorkoutController();
    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        cameraNoticeAcknowledged: () async => false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('暂不使用相机'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.startCalls, 0);
    expect(find.text('相机与端侧处理'), findsNothing);
  });

  testWidgets('camera denial explains how to recover', (tester) async {
    final controller = _FakeWorkoutController(
      currentStatus: WorkoutStatus.cameraPermissionSettings,
    );
    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('系统设置'), findsOneWidget);
  });

  testWidgets('localizes every WorkoutStatus without a fallback', (
    tester,
  ) async {
    const expectedStatuses = <WorkoutStatus, String>{
      WorkoutStatus.loading: '加载中',
      WorkoutStatus.loadingModel: '加载模型',
      WorkoutStatus.startingCamera: '启动相机',
      WorkoutStatus.positionGuide: '请按提示摆放手机并保持姿势',
      WorkoutStatus.startupError: '训练启动失败，请重试。',
      WorkoutStatus.switchingCamera: '切换相机',
      WorkoutStatus.cameraError: '相机发生错误，请重试。',
      WorkoutStatus.cameraPermissionDenied: '需要相机权限才能识别动作。请允许权限后重新进入训练。',
      WorkoutStatus.cameraPermissionSettings: '相机权限已关闭，请前往系统设置开启后重试。',
      WorkoutStatus.saving: '保存中',
      WorkoutStatus.holdPose: '请保持俯卧撑姿势并稳定入镜',
      WorkoutStatus.narrowForm: '收拢双臂，保持两侧手腕不比肩膀更向外',
      WorkoutStatus.readyToStart: '已准备好，请开始训练',
      WorkoutStatus.fullPose: '请保持俯卧撑姿势并完整入镜',
      WorkoutStatus.training: '训练中',
      WorkoutStatus.frameError: '识别发生错误，请重试。',
      WorkoutStatus.saveFailed: '保存失败，请重试。',
    };
    expect(expectedStatuses.keys, unorderedEquals(WorkoutStatus.values));

    final controller = _FakeWorkoutController();
    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    for (final entry in expectedStatuses.entries) {
      controller.updateStatus(entry.key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(entry.value), findsOneWidget, reason: entry.key.name);
    }
  });

  testWidgets('keeps the count halo circular on a short viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final halo = find.byKey(const ValueKey('workout-count-halo'));
    final console = find.byKey(const ValueKey('workout-count-panel'));
    final size = tester.getSize(halo);

    expect(size.width, size.height);
    expect(
      find.descendant(
        of: console,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });

  testWidgets('aligns camera controls across the camera stage', (tester) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    expect(
      tester.getCenter(find.byIcon(Icons.close_rounded)).dy,
      closeTo(tester.getCenter(find.byIcon(Icons.tune_rounded)).dy, 2),
    );
  });

  testWidgets('uses one coach bar and omits fixed workout statistics', (
    tester,
  ) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    expect(find.byKey(const ValueKey('workout-coach-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-guidance-chip')), findsNothing);
    expect(find.text('已准备'), findsNothing);
    expect(find.text('今日目标'), findsNothing);
    expect(find.text('100 个'), findsNothing);
    expect(find.text('消耗'), findsNothing);
    expect(find.text('32 千卡'), findsNothing);
  });

  testWidgets('uses a large count and restrained danger action', (
    tester,
  ) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final count = find.text('7');
    final halo = find.byKey(const ValueKey('workout-count-halo'));
    expect(tester.getCenter(count).dx, closeTo(tester.getCenter(halo).dx, 0.1));
    expect(
      tester.widget<Text>(count).style?.fontSize,
      greaterThanOrEqualTo(84),
    );

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
    expect(shape?.borderRadius, BorderRadius.circular(20));
    expect(
      find.descendant(
        of: stopButton,
        matching: find.byIcon(Icons.stop_circle_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the coach bar above the count console', (tester) async {
    await tester.pumpWidget(_workoutApp(controller: _FakeWorkoutController()));
    await tester.pump();

    final guidance = find.byKey(const ValueKey('workout-coach-bar'));
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

  testWidgets('debounces narrow guidance without changing coach bar height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _FakeWorkoutController(
      currentStatus: WorkoutStatus.narrowForm,
    );

    await tester.pumpWidget(
      _workoutApp(
        controller: controller,
        locale: const Locale('en'),
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    const narrowLabel =
        'Bring your arms in and keep both wrists no wider than your shoulders';
    const holdLabel = 'Hold a stable push-up pose in frame';
    final coachBar = find.byKey(const ValueKey('workout-coach-bar'));
    final initialHeight = tester.getSize(coachBar).height;
    expect(find.text(narrowLabel), findsOneWidget);

    controller.updateStatus(WorkoutStatus.holdPose);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(narrowLabel), findsOneWidget);
    expect(find.text(holdLabel), findsNothing);

    controller.updateStatus(WorkoutStatus.narrowForm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(narrowLabel), findsOneWidget);
    expect(tester.getSize(coachBar).height, initialHeight);

    controller.updateStatus(WorkoutStatus.holdPose);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(holdLabel), findsOneWidget);
    expect(tester.getSize(coachBar).height, initialHeight);
  });

  testWidgets('disposing narrow guidance cancels its pending debounce', (
    tester,
  ) async {
    final oldController = _FakeWorkoutController(
      currentStatus: WorkoutStatus.narrowForm,
    );
    await tester.pumpWidget(
      _workoutApp(
        controller: oldController,
        locale: const Locale('en'),
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    oldController.updateStatus(WorkoutStatus.holdPose);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    final newController = _FakeWorkoutController(
      currentStatus: WorkoutStatus.narrowForm,
    );
    await tester.pumpWidget(
      _workoutApp(
        controller: newController,
        locale: const Locale('en'),
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text(
        'Bring your arms in and keep both wrists no wider than your shoulders',
      ),
      findsOneWidget,
    );
    expect(find.text('Hold a stable push-up pose in frame'), findsNothing);
  });

  testWidgets('uses a theme-aware camera stage and count console', (
    tester,
  ) async {
    Color? lightStageColor;
    Color? lightConsoleColor;
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        _workoutApp(
          controller: _FakeWorkoutController(),
          brightness: brightness,
          cameraNoticeAcknowledged: () async => true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final stage = tester.widget<Container>(
        find.byKey(const ValueKey('workout-camera-stage')),
      );
      final console = tester.widget<Container>(
        find.byKey(const ValueKey('workout-count-panel')),
      );
      final decoration = console.decoration! as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>());
      final gradient = decoration.gradient! as LinearGradient;
      if (brightness == Brightness.light) {
        lightStageColor = stage.color;
        lightConsoleColor = gradient.colors.first;
      } else {
        expect(stage.color, isNot(lightStageColor));
        expect(gradient.colors.first, isNot(lightConsoleColor));
      }
    }
  });

  testWidgets(
    'keeps the live workout controls accessible on a compact English viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _workoutApp(
          controller: _FakeWorkoutController(
            currentStatus: WorkoutStatus.narrowForm,
          ),
          locale: const Locale('en'),
          brightness: Brightness.dark,
          cameraNoticeAcknowledged: () async => true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final coachBar = find.byKey(const ValueKey('workout-coach-bar'));
      final console = find.byKey(const ValueKey('workout-count-panel'));
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(coachBar).bottom,
        lessThanOrEqualTo(tester.getRect(console).top),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('workout-close-control')))
            .width,
        48,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('workout-camera-picker')))
            .width,
        48,
      );
      final stopButton = find.ancestor(
        of: find.text('End workout'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.getSize(stopButton).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Select camera'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('workout-count-semantics')))
            .label,
        '7 reps',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('workout-close-semantics')))
            .label,
        contains('Close'),
      );
      semantics.dispose();
    },
  );

  testWidgets('keeps a four digit count inside the halo at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _workoutApp(
        controller: _FakeWorkoutController(currentCount: 1234),
        textScaler: const TextScaler.linear(1.5),
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final haloRect = tester.getRect(
      find.byKey(const ValueKey('workout-count-halo')),
    );
    final countRect = tester.getRect(find.text('1234'));
    expect(countRect.left, greaterThanOrEqualTo(haloRect.left));
    expect(countRect.right, lessThanOrEqualTo(haloRect.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the count console clear of a large bottom safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 72);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      _workoutApp(
        controller: _FakeWorkoutController(),
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final haloRect = tester.getRect(
      find.byKey(const ValueKey('workout-count-halo')),
    );
    final stopButton = find.ancestor(
      of: find.text('结束训练'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(haloRect.bottom, lessThanOrEqualTo(tester.getRect(stopButton).top));
    expect(tester.takeException(), isNull);
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

    expect(find.text('Ready'), findsNothing);
    expect(find.text("Today's goal"), findsNothing);
    expect(find.text('100 reps'), findsNothing);
    expect(find.text('Burned'), findsNothing);
    expect(find.text('32 kcal'), findsNothing);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('End workout'), findsOneWidget);
    expect(find.text('训练中'), findsNothing);
  });

  testWidgets('localizes narrow-form guidance in Chinese and English', (
    tester,
  ) async {
    final controller = _FakeWorkoutController(
      currentStatus: WorkoutStatus.narrowForm,
    );
    await tester.pumpWidget(_workoutApp(controller: controller));
    expect(find.text('收拢双臂，保持两侧手腕不比肩膀更向外'), findsOneWidget);

    await tester.pumpWidget(
      _workoutApp(controller: controller, locale: const Locale('en')),
    );
    expect(
      find.text(
        'Bring your arms in and keep both wrists no wider than your shoulders',
      ),
      findsOneWidget,
    );
  });

  testWidgets('narrow workout persists its exercise type', (tester) async {
    final controller = _FakeWorkoutController(
      exerciseType: ExerciseType.narrowPushup,
    );
    final store = _RecordingSessionStore();
    await tester.pumpWidget(
      _workoutApp(
        store: store,
        controller: controller,
        exerciseType: ExerciseType.narrowPushup,
        cameraNoticeAcknowledged: () async => true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('结束训练'));
    await tester.pump();
    await tester.pump();

    expect(store.appended?.exerciseType, 'narrow_pushup');
  });

  test('rejects a page and injected controller type mismatch', () {
    expect(
      () => WorkoutPage(
        store: WorkoutSessionStore(),
        settingsController: AppSettingsController(
          store: _TestAppSettingsStore(),
        ),
        controller: _FakeWorkoutController(),
        exerciseType: ExerciseType.narrowPushup,
      ),
      throwsArgumentError,
    );
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
    expect(store.appended?.exerciseType, 'pushup');
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
  Brightness brightness = Brightness.light,
  ExerciseType exerciseType = ExerciseType.pushup,
  TextScaler textScaler = TextScaler.noScaling,
  Future<bool> Function()? cameraNoticeAcknowledged,
  Future<void> Function()? acknowledgeCameraNotice,
}) {
  return MaterialApp(
    locale: locale,
    theme: appTheme(),
    darkTheme: appTheme(brightness: Brightness.dark),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: WorkoutPage(
      store: store ?? WorkoutSessionStore(),
      settingsController: AppSettingsController(store: _TestAppSettingsStore()),
      controller: controller,
      exerciseType: exerciseType,
      cameraNoticeAcknowledged: cameraNoticeAcknowledged,
      acknowledgeCameraNotice: acknowledgeCameraNotice,
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
                      settingsController: AppSettingsController(
                        store: _TestAppSettingsStore(),
                      ),
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

class _TestAppSettingsStore implements AppSettingsStore {
  @override
  Future<String?> loadLanguage() async => null;

  @override
  Future<String?> loadTheme() async => null;

  @override
  Future<bool?> loadRecognitionTraceEnabled() async => null;

  @override
  Future<void> saveLanguage(String value) async {}

  @override
  Future<void> saveTheme(String value) async {}

  @override
  Future<void> saveRecognitionTraceEnabled(bool value) async {}
}

class _FakeWorkoutController extends WorkoutController {
  _FakeWorkoutController({
    this.currentStatus = WorkoutStatus.training,
    this.currentCount = 7,
    super.exerciseType = ExerciseType.pushup,
  });

  WorkoutStatus currentStatus;
  final int currentCount;
  var _running = true;
  var _stopping = false;
  var startCalls = 0;

  void updateStatus(WorkoutStatus status) {
    currentStatus = status;
    notifyListeners();
  }

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
  int get count => currentCount;

  @override
  bool get ready => true;

  @override
  WorkoutStatus get status => currentStatus;

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
