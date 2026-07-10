import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Android app is portrait-only', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:screenOrientation="portrait"'));
  });

  test('voice prompt script uses Chinese guide, ready, and count wording', () {
    final script = File('tool/tts/pushup_prompts.srt').readAsStringSync();

    expect(script, contains('请保持俯卧撑姿势'));
    expect(script, contains('您已进入准备状态'));
    for (final number in [
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '七',
      '八',
      '九',
      '十',
      '十一',
      '十二',
      '十三',
      '十四',
      '十五',
      '十六',
      '十七',
      '十八',
      '十九',
      '二十',
      '二十一',
      '二十二',
      '二十三',
      '二十四',
      '二十五',
      '二十六',
      '二十七',
      '二十八',
      '二十九',
      '三十',
    ]) {
      expect(script, contains('\n$number\n'));
    }
  });

  test('product home is an exercise-card list without standalone headline', () {
    final source = File('lib/ui/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf('class _HomePageState');
    expect(start, isNonNegative);
    final end = source.indexOf('\nclass ', start + 1);
    expect(end, isNonNegative);
    final body = source.substring(start, end);

    expect(body, contains('_ExerciseCard'));
    expect(body, contains('constraints: const BoxConstraints.expand()'));
    expect(body, isNot(contains('cardHeight')));
    expect(
      body,
      isNot(contains('_ExerciseCard(\n                      height:')),
    );
    expect(body, isNot(contains('_HomeMetric(')));
    expect(body, isNot(contains('headlineLarge')));
    expect(body, isNot(contains("'俯卧撑教练'")));
    expect(body, isNot(contains('_StartOrb(')));
    expect(source, isNot(contains('final double height;')));
    expect(source, contains('pushupTraining'));
  });

  test('app has localization scaffold for Chinese and English', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final home = File('lib/ui/pages/home_page.dart').readAsStringSync();

    expect(pubspec, contains('flutter_localizations:'));
    expect(pubspec, contains('generate: true'));
    expect(File('l10n.yaml').existsSync(), isTrue);
    expect(File('lib/l10n/app_zh.arb').existsSync(), isTrue);
    expect(File('lib/l10n/app_en.arb').existsSync(), isTrue);
    expect(main, contains('AppLocalizations.localizationsDelegates'));
    expect(main, contains('AppLocalizations.supportedLocales'));
    expect(home, contains('AppLocalizations.of(context)'));
    expect(home, isNot(contains("const Text('俯卧撑训练'")));
  });

  test('app supports light dark and system theme modes', () {
    final main = File('lib/main.dart').readAsStringSync();
    final theme = File('lib/ui/app_theme.dart').readAsStringSync();
    final home = File('lib/ui/pages/home_page.dart').readAsStringSync();

    expect(main, contains('themeMode: ThemeMode.system'));
    expect(main, contains('theme: appTheme(brightness: Brightness.light)'));
    expect(main, contains('darkTheme: appTheme(brightness: Brightness.dark)'));
    expect(theme, contains('ThemeData appTheme({'));
    expect(theme, contains('Brightness brightness = Brightness.light'));
    expect(theme, contains('darkCanvas'));
    expect(theme, contains('darkPanel'));
    expect(theme, contains('darkLine'));
    expect(theme, contains('darkHomeGradientTop'));
    expect(home, contains('Theme.of(context).brightness'));
    expect(home, contains('darkHomeGradientTop'));
  });

  test('domain layer has no Flutter or platform dependencies', () {
    final source = File('lib/pushup_domain.dart').readAsStringSync();

    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('package:camera')));
    expect(source, isNot(contains('package:tflite_flutter')));
    expect(source, isNot(contains('dart:io')));
  });

  test('pose inference uses IsolateInterpreter', () {
    final source = File('lib/inference/pose_estimator.dart').readAsStringSync();

    expect(source, contains('IsolateInterpreter.create'));
    expect(source, contains('await isolate.run'));
  });

  test('delegate switch keeps current interpreter until replacement loads', () {
    final source = File('lib/inference/pose_estimator.dart').readAsStringSync();
    final start = source.indexOf('Future<void> switchDelegate');
    final end = source.indexOf('\n  Future<void> dispose()', start);
    final body = source.substring(start, end);

    expect(body, contains('final next = PoseEstimator()'));
    expect(body, contains('await next.load'));
    expect(body, isNot(contains('await load(')));
    expect(
      body.indexOf('await next.load'),
      lessThan(body.indexOf('_interpreter = next._interpreter')),
    );
  });

  test('pose load cleans partial resources on failure', () {
    final source = File('lib/inference/pose_estimator.dart').readAsStringSync();
    final start = source.indexOf('Future<void> load');
    final end = source.indexOf('\n  Future<List<KeyPoint>> infer', start);
    final body = source.substring(start, end);

    expect(body, contains('catch (_)'));
    expect(body, contains('await dispose();'));
    expect(body, contains('rethrow;'));
  });

  test(
    'live delegate switch blocks camera frames while replacing interpreter',
    () {
      final source = File(
        'lib/ui/pages/test_mode_page.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _onCycleDelegate');
      final end = source.indexOf('\n\n  @override\n  void dispose()', start);
      final body = source.substring(start, end);

      expect(body, contains('_busy = true;'));
      expect(body, contains('finally'));
      expect(body, contains('_busy = false;'));
      expect(
        body.indexOf('_busy = true;'),
        lessThan(body.indexOf('await _pose.switchDelegate(nextMode)')),
      );
    },
  );

  test('live camera startup failure cleans partial resources', () {
    final source = File('lib/ui/pages/test_mode_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _onToggleCamera');
    final end = source.indexOf('\n\n  Future<void> _stopCamera()', start);
    final body = source.substring(start, end);
    final catchBody = body.substring(body.indexOf('catch (error)'));

    expect(catchBody, contains('await _subscription?.cancel();'));
    expect(catchBody, contains('_subscription = null;'));
    expect(catchBody, contains('await _camera.dispose();'));
    expect(catchBody, contains('await _pose.dispose();'));
  });

  test('frame pipeline keeps Step0 int8 quantization contract', () {
    final source = File('lib/pipeline/frame_pipeline.dart').readAsStringSync();

    expect(source, contains('value / inputScale + inputZeroPoint'));
    expect(source, isNot(contains('/ 255')));
    expect(source, isNot(contains('/255')));
  });

  test('product workout uses PushupPipeline for live counting', () {
    // The counting chain (extractor→filter→counter) is assembled in
    // PushupPipeline; the workout controller drives it via process()/count,
    // no longer holding PushupCounter/SignalFilter/SignalExtractor directly.
    final source = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('class WorkoutController');
    expect(start, isNonNegative);
    final nextClass = source.indexOf('\nclass ', start + 1);
    final body = nextClass < 0
        ? source.substring(start)
        : source.substring(start, nextClass);

    expect(body, contains('PushupPipeline'));
    expect(body, contains('_pipeline.process'));
  });

  test('product workout stop flow is idempotent and stops voice first', () {
    // stop() now lives on the controller; the page only persists + navigates
    // after it returns. Voice is stopped before camera/pose disposal.
    final source = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> stop() async');
    expect(start, isNonNegative);
    final end = source.indexOf('\n\n  Future<void> _onCameraImage', start);
    expect(end, isNonNegative);
    final body = source.substring(start, end);

    expect(body, contains('if (!_running || _stopping)'));
    expect(body, contains('_stopping = true;'));
    expect(body, contains("_status = '保存中'"));
    expect(body, contains('await _voice.stop();'));
  });

  test('product workout stop button keeps bottom breathing room', () {
    final source = File('lib/ui/pages/workout_page.dart').readAsStringSync();
    final start = source.indexOf('class _WorkoutCountPanel');
    expect(start, isNonNegative);
    final end = source.indexOf('\nclass ', start + 1);
    expect(end, isNonNegative);
    final body = source.substring(start, end);

    expect(
      body,
      contains('EdgeInsets.fromLTRB(24, 20, 24, 34 + bottomPadding)'),
    );
    expect(body, contains('dimension: 154'));
  });

  test(
    'product workout camera chrome has selectable cameras without corners',
    () {
      final source = File('lib/ui/pages/workout_page.dart').readAsStringSync();
      final workoutStart = source.indexOf('class _WorkoutPageState');
      expect(workoutStart, isNonNegative);
      final workoutEnd = source.indexOf('\nclass ', workoutStart + 1);
      expect(workoutEnd, isNonNegative);
      final workoutBody = source.substring(workoutStart, workoutEnd);

      // UI chrome lives on the page: popup menu, a _switchCamera handler, and
      // no guide-corner overlays.
      expect(source, isNot(contains('class _CameraGuideCorners')));
      expect(source, isNot(contains('class _CameraCorner')));
      expect(workoutBody, isNot(contains('_CameraGuideCorners')));
      expect(workoutBody, contains('PopupMenuButton<CameraDescription>'));
      expect(workoutBody, contains('onSelected: _switchCamera'));
      expect(
        workoutBody,
        contains('Future<void> _switchCamera(CameraDescription camera)'),
      );

      // Camera teardown orchestration now lives on the controller.
      final controller = File(
        'lib/control/workout_controller.dart',
      ).readAsStringSync();
      expect(controller, contains('await _subscription?.cancel();'));
      expect(controller, contains('await _waitForFramePipelineToIdle();'));
    },
  );

  test('camera service supports selecting a discovered camera', () {
    final source = File('lib/platform/camera_service.dart').readAsStringSync();

    expect(
      source,
      contains('Future<List<CameraDescription>> listCameras() async'),
    );
    expect(source, contains('CameraDescription? camera,'));
    expect(source, contains('_description ='));
    expect(source, contains('camera ??'));
    expect(source, contains('CameraDescription? get description'));
  });

  test(
    'product workout removes camera preview before disposing controller',
    () {
      final source = File('lib/ui/pages/workout_page.dart').readAsStringSync();
      final workoutStart = source.indexOf('class _WorkoutPageState');
      expect(workoutStart, isNonNegative);
      final workoutEnd = source.indexOf('\nclass ', workoutStart + 1);
      expect(workoutEnd, isNonNegative);
      final workoutBody = source.substring(workoutStart, workoutEnd);

      // The UI drops the preview while stopping is in progress.
      expect(workoutBody, contains('final showPreview ='));
      expect(workoutBody, contains('!_controller.stopping &&'));

      // The controller waits one frame (so the preview is removed) before
      // disposing the camera controller.
      final controller = File(
        'lib/control/workout_controller.dart',
      ).readAsStringSync();
      final stopStart = controller.indexOf('Future<void> stop() async');
      final stopEnd = controller.indexOf(
        '\n\n  Future<void> _onCameraImage',
        stopStart,
      );
      final stopBody = controller.substring(stopStart, stopEnd);

      expect(stopBody, contains('await SchedulerBinding.instance.endOfFrame;'));
      expect(
        stopBody.indexOf('await SchedulerBinding.instance.endOfFrame;'),
        lessThan(stopBody.indexOf('await _camera.dispose();')),
      );
    },
  );

  test('product workout waits for frame inference before disposing pose', () {
    // The idle-wait and disposal ordering now live on the controller's stop().
    final source = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();
    final classStart = source.indexOf('class WorkoutController');
    expect(classStart, isNonNegative);
    final classEnd = source.indexOf('\nclass ', classStart + 1);
    final workoutBody = classEnd < 0
        ? source.substring(classStart)
        : source.substring(classStart, classEnd);
    final stopStart = workoutBody.indexOf('Future<void> stop() async');
    final stopEnd = workoutBody.indexOf(
      '\n\n  Future<void> _onCameraImage',
      stopStart,
    );
    final stopBody = workoutBody.substring(stopStart, stopEnd);

    expect(workoutBody, contains('Future<void> _waitForFramePipelineToIdle()'));
    expect(stopBody, isNot(contains('_busy = false;')));
    expect(stopBody, contains('await _waitForFramePipelineToIdle();'));
    expect(
      stopBody.indexOf('await _subscription?.cancel();'),
      lessThan(stopBody.indexOf('await _waitForFramePipelineToIdle();')),
    );
    expect(
      stopBody.indexOf('await _waitForFramePipelineToIdle();'),
      lessThan(stopBody.indexOf('await _pose.dispose();')),
    );
  });

  test(
    'product workout tolerates brief pose visibility drops while counting',
    () {
      final source = File(
        'lib/control/workout_controller.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> _onCameraImage');
      expect(start, isNonNegative);
      final end = source.indexOf(
        '\n\n  Future<void> _waitForFramePipelineToIdle',
        start,
      );
      expect(end, isNonNegative);
      final body = source.substring(start, end);

      expect(body, contains('!_coreTorsoVisible(keypoints)'));
      expect(source, contains('static const _maxLostPoseFrames = 15;'));
      expect(source, contains('var _lostPoseFrames = 0;'));
      expect(body, contains('_lostPoseFrames += 1;'));
      expect(body, contains('_lostPoseFrames >= _maxLostPoseFrames'));
      expect(body, contains('_lostPoseFrames = 0;'));
      expect(
        body.indexOf('_lostPoseFrames >= _maxLostPoseFrames'),
        lessThan(body.indexOf('_ready = false;')),
      );
      expect(
        body.indexOf('_lostPoseFrames = 0;'),
        lessThan(body.indexOf('_pipeline.process')),
      );
      expect(body, isNot(contains("status = '请保持完整入镜';")));
    },
  );

  test('product workout startup disposes pose when session goes stale', () {
    // Startup orchestration now lives on the controller's start().
    final source = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> start() async');
    expect(start, isNonNegative);
    final end = source.indexOf('\n\n  Future<void> switchCamera', start);
    expect(end, isNonNegative);
    final body = source.substring(start, end);

    expect(
      body,
      contains(
        'await _pose.load(assetPath: _modelPath, mode: DelegateMode.nnapi);',
      ),
    );
    expect(body, contains('if (session != _session) {'));
    expect(body, contains('await _pose.dispose();'));
  });

  test('android manifest declares Google Play billing permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('com.android.vending.BILLING'));
  });

  test('android manifest declares internet permission for membership auth', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('membership runtime config is not owned by UI theme', () {
    final theme = File('lib/ui/app_theme.dart').readAsStringSync();
    final configFile = File('lib/config/membership_config.dart');

    expect(theme, isNot(contains('membershipApiBaseUrl')));
    expect(theme, isNot(contains('googleServerClientId')));
    expect(theme, isNot(contains('revenueCatAndroidApiKey')));
    expect(configFile.existsSync(), isTrue);

    final config = configFile.readAsStringSync();
    expect(config, contains('membershipApiBaseUrl'));
    expect(config, contains('googleServerClientId'));
    expect(config, contains('revenueCatAndroidApiKey'));
    expect(config, contains('String.fromEnvironment'));
    expect(config, isNot(contains('defaultValue:')));
    expect(config, contains('kReleaseMode'));
    expect(config, contains('validateMembershipConfig'));
  });

  test('platform membership services do not depend on app theme', () {
    final revenueCat = File(
      'lib/platform/revenuecat_service.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(revenueCat, isNot(contains('../ui/app_theme.dart')));
    expect(revenueCat, contains('../config/membership_config.dart'));
    expect(main, contains('config/membership_config.dart'));
    expect(
      main.indexOf('validateMembershipConfig();'),
      lessThan(main.indexOf('GoogleAuthService()')),
    );
  });

  test('main initializes Flutter binding before platform services', () {
    final source = File('lib/main.dart').readAsStringSync();
    final binding = source.indexOf(
      'WidgetsFlutterBinding.ensureInitialized();',
    );
    final googleAuth = source.indexOf('GoogleAuthService()');

    expect(binding, isNonNegative);
    expect(googleAuth, isNonNegative);
    expect(binding, lessThan(googleAuth));
  });

  test('workout cloud sync wiring stays bound to the captured account', () {
    final main = File('lib/main.dart').readAsStringSync();
    final syncStart = main.indexOf('final syncController =');
    final syncEnd = main.indexOf('final leaderboardController', syncStart);
    final syncBlock = main.substring(syncStart, syncEnd);
    final syncBatch = syncBlock.substring(syncBlock.indexOf('syncBatch:'));
    final listener = main.indexOf('controller.addListener');
    final restore = main.indexOf('unawaited(controller.restore())');
    final home = File('lib/ui/pages/home_page.dart').readAsStringSync();
    final store = File(
      'lib/product/workout_session_store.dart',
    ).readAsStringSync();
    final syncController = File(
      'lib/control/workout_sync_controller.dart',
    ).readAsStringSync();

    expect(syncBlock, contains('syncBatch: (account, workouts) async'));
    expect(
      syncBlock,
      contains('apiClient.syncWorkouts(account.sessionToken, workouts)'),
    );
    expect(syncBatch, isNot(contains('controller.currentSession')));
    expect(listener, isNonNegative);
    expect(main, contains('syncController.syncForCurrentAccount()'));
    expect(listener, lessThan(restore));
    expect(home, contains('syncController: widget.syncController'));
    expect(home, contains('pendingCloudSyncForOwner'));
    expect(home, isNot(contains('.pendingCloudSync()')));
    expect(store, isNot(contains('Future<void> markForCloudSync(')));
    expect(store, isNot(contains('Future<void> markCloudSynced(')));
    expect(store, isNot(contains('Future<void> markCloudSyncFailed(')));
    expect(
      store,
      isNot(contains('Future<List<WorkoutSession>> pendingCloudSync()')),
    );
    expect(syncController, isNot(contains('claimLegacyForCurrentAccount')));
    expect(syncController, contains('claimLegacyForOwner('));
  });
}
