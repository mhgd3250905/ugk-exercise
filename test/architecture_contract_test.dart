import 'dart:io';

import 'package:test/test.dart';

void main() {
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
      final source = File('lib/main.dart').readAsStringSync();
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
    final source = File('lib/main.dart').readAsStringSync();
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

  test('product workout uses PushupCounter for live counting', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('class _WorkoutPageState');
    final body = source.substring(start);

    expect(body, contains('PushupCounter'));
    expect(body, contains('_counter.update(signals)'));
    expect(body, contains('SignalExtractor'));
    expect(body, contains('SignalFilter'));
  });

  test('product workout stop flow is idempotent and stops voice first', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _stopAndSave()');
    final end = source.indexOf('\n\n  @override\n  void dispose()', start);
    final body = source.substring(start, end);

    expect(body, contains('if (!_running || _stopping)'));
    expect(body, contains('_stopping = true;'));
    expect(body, contains("setState(() => _status = '保存中')"));
    expect(body, contains('await _voice.stop();'));
  });

  test('product workout startup disposes pose when session goes stale', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _start() async');
    final end = source.indexOf('\n\n  Future<void> _onCameraImage', start);
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
}
