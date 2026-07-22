import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Android launcher uses the approved app name', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="AI俯卧撑"'));
  });

  test('Android launcher uses the approved icon at every density', () {
    const icons = {
      'mipmap-mdpi': (48, 4153437476),
      'mipmap-hdpi': (72, 1137407407),
      'mipmap-xhdpi': (96, 130390033),
      'mipmap-xxhdpi': (144, 1143680267),
      'mipmap-xxxhdpi': (192, 3389431009),
    };

    for (final MapEntry(key: density, value: expected) in icons.entries) {
      final bytes = File(
        'android/app/src/main/res/$density/ic_launcher.png',
      ).readAsBytesSync();
      final width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height =
          (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      var a = 1;
      var b = 0;
      for (final byte in bytes) {
        a = (a + byte) % 65521;
        b = (b + a) % 65521;
      }

      expect((width, height), (expected.$1, expected.$1));
      expect((b << 16) | a, expected.$2);
    }
  });

  test('Android app supports resizing and every window orientation', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('android:screenOrientation')));
    expect(manifest, isNot(contains('android:resizeableActivity')));
    expect(manifest, isNot(contains('android:minAspectRatio')));
    expect(manifest, isNot(contains('android:maxAspectRatio')));
  });

  test('Android edge-to-edge uses the supported Flutter window contract', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final onboarding = File(
      'lib/ui/pages/onboarding_page.dart',
    ).readAsStringSync();
    final workout = File('lib/ui/pages/workout_page.dart').readAsStringSync();
    final styleFiles = Directory('android/app/src/main/res')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('styles.xml'));

    expect(pubspec, contains("flutter: '>=3.44.0'"));
    expect(main, contains("import 'package:flutter/services.dart';"));
    expect(
      main,
      contains(
        'await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);',
      ),
    );
    for (final file in styleFiles) {
      final style = file.readAsStringSync();
      expect(
        style,
        isNot(contains('android:statusBarColor')),
        reason: file.path,
      );
      expect(
        style,
        isNot(contains('android:navigationBarColor')),
        reason: file.path,
      );
      expect(
        style,
        isNot(contains('windowOptOutEdgeToEdgeEnforcement')),
        reason: file.path,
      );
    }
    for (final source in [onboarding, workout]) {
      expect(source, isNot(contains('statusBarColor:')));
      expect(source, isNot(contains('systemNavigationBarColor:')));
      expect(source, isNot(contains('SystemUiOverlayStyle.light')));
      expect(source, isNot(contains('SystemUiOverlayStyle.dark')));
    }
  });

  test('Flutter binding and runApp share the guarded startup zone', () {
    final source = File('lib/main.dart').readAsStringSync();
    final guardedZone = source.indexOf('runZonedGuarded');
    final binding = source.indexOf('WidgetsFlutterBinding.ensureInitialized');
    final runAppCall = source.indexOf('runApp(');

    expect(guardedZone, isNonNegative);
    expect(binding, greaterThan(guardedZone));
    expect(runAppCall, greaterThan(binding));
  });

  test(
    'Android modules share the Java 17 toolchain required by modern AGP',
    () {
      final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
      final rootGradle = File('android/build.gradle.kts').readAsStringSync();

      expect(
        RegExp('JavaVersion\\.VERSION_17').allMatches(appGradle).length,
        greaterThanOrEqualTo(2),
      );
      expect(appGradle, contains('JvmTarget.JVM_17'));
      expect(rootGradle, contains('LibraryAndroidComponentsExtension'));
      expect(rootGradle, contains('finalizeDsl'));
      expect(rootGradle, contains('jvmToolchain(17)'));
      expect(rootGradle, contains('KotlinJvmCompile'));
    },
  );

  test('Android build tools stay on the Flutter 3.44 supported baseline', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();

    expect(settings, contains('com.android.application") version "8.11.1"'));
    expect(
      settings,
      contains('org.jetbrains.kotlin.android") version "2.2.20"'),
    );
    expect(wrapper, contains('gradle-8.14.3-all.zip'));
  });

  test('Android and Flutter startup share one safe branded lockup', () {
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final launchColors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    final launchNightColors = File(
      'android/app/src/main/res/values-night/colors.xml',
    ).readAsStringSync();
    final launchStyle = File(
      'android/app/src/main/res/values/styles.xml',
    ).readAsStringSync();
    final flutterLockup = File('assets/images/startup_lockup.png');
    final androidLockup = File(
      'android/app/src/main/res/drawable-xxxhdpi/startup_lockup.png',
    );
    final android12Style = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    final android12NightStyle = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    ).readAsStringSync();

    expect(launchBackground, contains('@color/launch_background'));
    expect(launchBackground, contains('@drawable/startup_lockup'));
    expect(launchBackground, isNot(contains('@mipmap/ic_launcher')));
    expect(launchColors, contains('#083F3E'));
    expect(launchNightColors, contains('#083F3E'));
    expect(launchStyle, contains('android:windowLightStatusBar">false'));
    expect(android12Style, contains('windowSplashScreenBackground'));
    expect(
      android12Style,
      contains(
        'android:windowSplashScreenAnimatedIcon">@drawable/startup_lockup',
      ),
    );
    expect(
      android12NightStyle,
      contains(
        'android:windowSplashScreenAnimatedIcon">@drawable/startup_lockup',
      ),
    );
    expect(android12Style, contains('android:windowLightStatusBar">false'));
    expect(android12NightStyle, contains('Theme.Black.NoTitleBar'));
    expect(flutterLockup.existsSync(), isTrue);
    expect(androidLockup.existsSync(), isTrue);

    final flutterBytes = flutterLockup.readAsBytesSync();
    final androidBytes = androidLockup.readAsBytesSync();
    final width =
        (flutterBytes[16] << 24) |
        (flutterBytes[17] << 16) |
        (flutterBytes[18] << 8) |
        flutterBytes[19];
    final height =
        (flutterBytes[20] << 24) |
        (flutterBytes[21] << 16) |
        (flutterBytes[22] << 8) |
        flutterBytes[23];

    expect((width, height), (1152, 1152));
    expect(androidBytes, flutterBytes);
  });

  test('Android 12 requests immediate system splash removal', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/ugkexercise/ugk_exercise/MainActivity.kt',
    ).readAsStringSync();

    expect(
      mainActivity,
      contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.S'),
    );
    expect(mainActivity, contains('splashScreen.setOnExitAnimationListener'));
    expect(mainActivity, contains('splashScreenView.remove()'));
  });

  test('Android Play Store launcher pins the Google Play app', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/ugkexercise/ugk_exercise/MainActivity.kt',
    ).readAsStringSync();

    expect(mainActivity, contains('setPackage("com.android.vending")'));
    expect(
      mainActivity,
      contains('https://play.google.com/store/apps/details?id=\$packageName'),
    );
  });

  test('release signing uses an ignored upload keystore configuration', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final gitignore = File('.gitignore').readAsStringSync();

    expect(gradle, contains('key.properties'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gitignore, contains('/android/key.properties'));
    expect(gitignore, contains('*.jks'));
  });

  test('voice prompt script covers guide, ready, lost pose, and counts', () {
    final script = File('tool/tts/pushup_prompts.srt').readAsStringSync();

    expect(script, contains('请保持俯卧撑姿势'));
    expect(script, contains('您已进入准备状态'));
    expect(script, contains('姿势已中断，请按指引重新准备。'));
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

  test('app root restores and applies language and theme preferences', () {
    final main = File('lib/main.dart').readAsStringSync();
    final theme = File('lib/ui/app_theme.dart').readAsStringSync();
    final home = File('lib/ui/pages/home_page.dart').readAsStringSync();

    expect(File('lib/ui/app_settings.dart').existsSync(), isTrue);
    expect(File('lib/platform/app_settings_store.dart').existsSync(), isTrue);
    expect(
      main,
      contains('final settingsRestore = settingsController.restore();'),
    );
    expect(main, contains('await settingsRestore;'));
    expect(main, isNot(contains('await settingsController.restore();')));
    expect(main, contains('locale: settingsController.locale'));
    expect(main, contains('themeMode: settingsController.themeMode'));
    expect(main, contains('settingsController: settingsController'));
    expect(home, contains('required this.settingsController'));
    expect(home, contains('settingsController: widget.settingsController'));
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

  test('NNAPI interpreter creation stays off the UI isolate', () {
    final source = File('lib/inference/pose_estimator.dart').readAsStringSync();
    final start = source.indexOf('Future<void> load');
    final end = source.indexOf('\n  Future<List<KeyPoint>> infer', start);
    final body = source.substring(start, end);

    expect(body, contains('final address = await Isolate.run'));
    expect(body, contains('Interpreter.fromBuffer'));
    expect(body, contains('Interpreter.fromAddress(address, allocated: true)'));
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
    // The counting chain (extractor→counter-owned smoothing) is assembled in
    // PushupPipeline; the workout controller drives it via process()/count,
    // no longer holding PushupCounter/SignalExtractor directly.
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
    expect(body, contains('_pipeline.calibrateReadyDepth'));
  });

  test(
    'product workout statuses are typed and stop flow stops voice first',
    () {
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

      expect(source, contains('enum WorkoutStatus {'));
      expect(source, contains('WorkoutStatus get status => _status;'));
      expect(body, contains('if (!_running || _stopping)'));
      expect(body, contains('_stopping = true;'));
      expect(body, contains('_status = WorkoutStatus.saving;'));
      expect(body, contains('await _voice.stop();'));
      expect(
        body.indexOf('await _voice.stop();'),
        lessThan(body.indexOf('await _camera.dispose();')),
      );

      final page = File('lib/ui/pages/workout_page.dart').readAsStringSync();
      final mappingStart = page.indexOf('String _localizedWorkoutStatus');
      expect(mappingStart, isNonNegative);
      final mappingEnd = page.indexOf('\n}\n', mappingStart);
      expect(mappingEnd, isNonNegative);
      final mapping = page.substring(mappingStart, mappingEnd);
      expect(mapping, contains('WorkoutStatus status'));
      expect(mapping, contains('return switch (status) {'));
      expect(mapping, isNot(contains('_ =>')));
    },
  );

  test('workout voice directory flows from the page into the controller', () {
    final controller = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();
    final page = File('lib/ui/pages/workout_page.dart').readAsStringSync();

    expect(
      controller,
      contains('String voiceBaseDir = chineseVoicePromptBaseDir'),
    );
    expect(controller, contains('VoicePromptPlayer(baseDir: voiceBaseDir)'));
    expect(page, contains('required this.settingsController'));
    expect(page, contains('voicePromptBaseDirFor('));
    expect(page, contains('widget.settingsController.language'));
    expect(page, contains('WidgetsBinding.instance.platformDispatcher.locale'));
  });

  test(
    'product workout panel keeps safe bottom room and a circular count halo',
    () {
      final source = File('lib/ui/pages/workout_page.dart').readAsStringSync();
      final start = source.indexOf('class _WorkoutCountPanel');
      expect(start, isNonNegative);
      final end = source.indexOf('\nclass ', start + 1);
      expect(end, isNonNegative);
      final body = source.substring(start, end);

      expect(
        body,
        contains('final safePadding = MediaQuery.paddingOf(context)'),
      );
      expect(body, contains('24 + safePadding.right'));
      expect(body, contains('24 + safePadding.bottom'));
      expect(body, contains("ValueKey('workout-count-halo')"));
      expect(body, contains('shape: BoxShape.circle'));
      expect(body, isNot(contains('CircularProgressIndicator(')));
      expect(body, isNot(contains('workoutTodayGoal')));
      expect(body, isNot(contains('workoutBurned')));
    },
  );

  test(
    'product workout switches guide layer and live silhouette by ready state',
    () {
      final workout = File('lib/ui/pages/workout_page.dart').readAsStringSync();
      final testMode = File(
        'lib/ui/pages/test_mode_page.dart',
      ).readAsStringSync();
      final rawOverlay = File(
        'lib/ui/overlay_renderer.dart',
      ).readAsStringSync();

      expect(workout, contains('PoseSilhouetteOverlay('));
      expect(workout, contains('WorkoutPoseGuide('));
      expect(workout, contains('showPreview && !_controller.ready'));
      expect(workout, contains('showPreview && _controller.ready'));
      expect(workout, contains('moveNetHeadShoulderObservation('));
      expect(workout, isNot(contains('OverlayRenderer(')));
      expect(workout, isNot(contains('showGuide')));
      expect(rawOverlay, isNot(contains('showGuide')));
      expect(testMode, contains('OverlayRenderer('));
      expect(testMode, isNot(contains('PoseSilhouetteOverlay(')));
    },
  );

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
      expect(controller, contains('await _cancelSubscription();'));
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
      stopBody.indexOf('await _cancelSubscription();'),
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

      expect(
        body,
        contains(
          'final usable = motionPoseUsable(keypoints, sourceHeight: frameHeight)',
        ),
      );
      expect(body, contains('if (!usable)'));
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
      expect(body, contains('_reacquiringPose = true;'));
      expect(body, contains('status = WorkoutStatus.reacquiringPose;'));
      expect(body, contains('unawaited(_voice.playPoseLost());'));
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

    expect(source, contains("import '../config/resource_constants.dart';"));
    expect(
      body,
      contains(
        'await _pose.load(assetPath: modelPath, mode: DelegateMode.nnapi);',
      ),
    );
    expect(body, contains('if (session != _session) {'));
    expect(body, contains('await _pose.dispose();'));
    expect(source, contains('var _starting = false;'));
    expect(body, contains('_starting = true;'));
    expect(body, contains('_starting = false;'));

    final switchStart = source.indexOf('Future<void> switchCamera');
    final switchEnd = source.indexOf('\n\n  /// Stops camera', switchStart);
    final switchBody = source.substring(switchStart, switchEnd);
    expect(switchBody, contains('if (_starting ||'));
  });

  test('workout async cleanup keeps session guards after every await', () {
    final source = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();

    void expectGuardAfter(String body, String awaitedOperation) {
      final awaitIndex = body.indexOf(awaitedOperation);
      expect(awaitIndex, isNonNegative, reason: awaitedOperation);
      final afterAwait = body
          .substring(awaitIndex + awaitedOperation.length)
          .trimLeft();
      expect(
        afterAwait,
        startsWith('if (session != _session) {'),
        reason: 'missing session guard after $awaitedOperation',
      );
    }

    final startBegin = source.indexOf('Future<void> start() async');
    final startEnd = source.indexOf(
      '\n\n  Future<void> switchCamera',
      startBegin,
    );
    final startBody = source.substring(startBegin, startEnd);
    final startCatch = startBody.substring(startBody.indexOf('catch (error)'));
    for (final operation in [
      'await _cancelSubscription();',
      'await _camera.dispose();',
      'await _pose.dispose();',
    ]) {
      expectGuardAfter(startCatch, operation);
    }

    final switchBegin = startEnd;
    final switchEnd = source.indexOf('\n\n  /// Stops camera', switchBegin);
    final switchBody = source.substring(switchBegin, switchEnd);
    final switchCatch = switchBody.substring(
      switchBody.indexOf('catch (error)'),
    );
    for (final operation in [
      'await _cancelSubscription();',
      'await _camera.dispose();',
      'await _pose.dispose();',
    ]) {
      expectGuardAfter(switchCatch, operation);
    }

    final stopBegin = source.indexOf('Future<void> stop() async');
    final stopEnd = source.indexOf(
      '\n\n  Future<void> _onCameraImage',
      stopBegin,
    );
    final stopBody = source.substring(stopBegin, stopEnd);
    for (final operation in [
      'await SchedulerBinding.instance.endOfFrame;',
      'await _voice.stop();',
      'await _cancelSubscription();',
      'await _waitForFramePipelineToIdle();',
      'await _camera.dispose();',
      'await _pose.dispose();',
      'await _trace.close();',
    ]) {
      expectGuardAfter(stopBody, operation);
    }

    final disposeHelperStart = source.indexOf(
      'Future<void> _disposeCameraAndPoseWhenIdle() async',
    );
    final disposeHelperEnd = source.indexOf('\n\n  bool _sameCamera', disposeHelperStart);
    final disposeHelper = source.substring(disposeHelperStart, disposeHelperEnd);
    expect(disposeHelper, contains('await _cancelSubscription();'));
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

  test('runtime and resource config are not owned by UI theme', () {
    final theme = File('lib/ui/app_theme.dart').readAsStringSync();
    final configFile = File('lib/config/membership_config.dart');
    final resourceFile = File('lib/config/resource_constants.dart');

    expect(theme, isNot(contains('membershipApiBaseUrl')));
    expect(theme, isNot(contains('googleServerClientId')));
    expect(theme, isNot(contains('revenueCatAndroidApiKey')));
    expect(theme, isNot(contains('modelPath')));
    expect(theme, isNot(contains('replayVideoName')));
    expect(configFile.existsSync(), isTrue);
    expect(resourceFile.existsSync(), isTrue);

    final config = configFile.readAsStringSync();
    expect(config, contains('membershipApiBaseUrl'));
    expect(config, contains('googleServerClientId'));
    expect(config, contains('revenueCatAndroidApiKey'));
    expect(config, contains('String.fromEnvironment'));
    expect(config, isNot(contains('defaultValue:')));
    expect(config, contains('kReleaseMode'));
    expect(config, contains('validateMembershipConfig'));

    final resources = resourceFile.readAsStringSync();
    expect(
      resources,
      contains(
        "const modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';",
      ),
    );
    expect(resources, contains("const replayVideoName = '俯卧撑.mp4';"));
  });

  test('voice prompt directories are owned by resource config', () {
    final config = File(
      'lib/config/resource_constants.dart',
    ).readAsStringSync();
    final settings = File('lib/ui/app_settings.dart').readAsStringSync();
    final player = File(
      'lib/product/voice_prompt_player.dart',
    ).readAsStringSync();
    final controller = File(
      'lib/control/workout_controller.dart',
    ).readAsStringSync();

    expect(config, contains('chineseVoicePromptBaseDir'));
    expect(config, contains('englishVoicePromptBaseDir'));
    for (final source in [settings, player, controller]) {
      expect(source, isNot(contains("'audio/prompts'")));
      expect(source, isNot(contains("'audio/voices/manbo/en'")));
    }
  });

  test('platform services keep config and logging boundaries', () {
    final revenueCat = File(
      'lib/platform/revenuecat_service.dart',
    ).readAsStringSync();
    final googleAuth = File(
      'lib/platform/google_auth_service.dart',
    ).readAsStringSync();
    final sync = File(
      'lib/control/workout_sync_controller.dart',
    ).readAsStringSync();
    final api = File(
      'lib/platform/membership_api_client.dart',
    ).readAsStringSync();
    final log = File('lib/platform/ugk_log.dart');
    final replay = File('lib/platform/replay_utils.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(revenueCat, isNot(contains('../ui/app_theme.dart')));
    expect(revenueCat, contains('../config/membership_config.dart'));
    expect(replay, isNot(contains('../ui/app_theme.dart')));
    expect(replay, contains('../config/resource_constants.dart'));
    expect(log.existsSync(), isTrue);
    expect(log.readAsStringSync(), contains("debugPrint('UGK \$message')"));
    expect(revenueCat, contains("ugkLog('purchase: failed code="));
    expect(googleAuth, contains("ugkLog('auth: failed type="));
    expect(sync, contains("'sync: failed pending="));
    expect(api, contains("'api: parse-error operation=\$operation '"));
    expect(api, contains('bodyLength=\${response.bodyBytes.length}'));
    expect(api, isNot(contains('body=\${response.body}')));
    expect(main, contains('config/membership_config.dart'));
    expect(
      main.indexOf('validateMembershipConfig();'),
      lessThan(main.indexOf('GoogleAuthService()')),
    );
  });

  test('main installs global error hooks before app startup', () {
    final source = File('lib/main.dart').readAsStringSync();
    final binding = source.indexOf(
      'WidgetsFlutterBinding.ensureInitialized();',
    );
    final validation = source.indexOf('validateMembershipConfig();');
    final flutterError = source.indexOf('FlutterError.onError =');
    final zone = source.indexOf('runZonedGuarded');
    final appStartup = source.indexOf('_runUgkApp();');
    final runApp = source.indexOf('runApp(');
    final googleAuth = source.indexOf('GoogleAuthService()');

    expect(binding, isNonNegative);
    expect(validation, isNonNegative);
    expect(flutterError, isNonNegative);
    expect(zone, isNonNegative);
    expect(appStartup, isNonNegative);
    expect(runApp, isNonNegative);
    expect(googleAuth, isNonNegative);
    expect(validation, lessThan(zone));
    expect(zone, lessThan(binding));
    expect(binding, lessThan(flutterError));
    expect(flutterError, lessThan(appStartup));
    expect(appStartup, lessThan(runApp));
    expect(binding, lessThan(googleAuth));
    expect(source, contains("ugkLog('flutter-error: type="));
    expect(source, contains('FlutterError.presentError(details);'));
    expect(source, contains("ugkLog('zone-error: type="));
    expect(source, contains('debugPrintStack(stackTrace: stackTrace);'));
  });

  test('startup update prompt is wired after the local startup gate', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains("import 'control/app_update_checker.dart';"));
    expect(source, contains("import 'platform/app_version_service.dart';"));
    expect(source, contains("import 'platform/play_store_service.dart';"));
    expect(source, contains("import 'ui/app_update_prompt.dart';"));
    expect(source, contains('final appUpdateChecker = AppUpdateChecker('));
    expect(source, contains('apiClient.latestAppRelease('));
    expect(source, contains('appVersionService.installedBuildNumber'));
    expect(source, contains('appVersionService.availableUpdateBuildNumber'));
    expect(source, contains('final playStoreService = PlayStoreService();'));

    final startupGate = source.indexOf('home: AppStartupGate(');
    final updatePrompt = source.indexOf('home: AppUpdatePrompt(', startupGate);
    final homePage = source.indexOf('child: HomePage(', updatePrompt);
    expect(startupGate, isNonNegative);
    expect(updatePrompt, greaterThan(startupGate));
    expect(homePage, greaterThan(updatePrompt));
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
