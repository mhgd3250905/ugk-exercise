import 'dart:io';

import 'package:test/test.dart';

final _directivePattern = RegExp(
  r'''^\s*(?:import|export)\s+([\s\S]*?);''',
  multiLine: true,
);
final _uriPattern = RegExp(r'''['"]([^'"]+)['"]''');
const _allowedProductDartLibraries = {
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
  'dart:typed_data',
};

void main() {
  test('domain remains a pure Dart foundation', () {
    final imports = _importsIn(File('lib/pushup_domain.dart'));

    expect(imports, everyElement(startsWith('dart:')));
    expect(imports, isNot(contains('dart:io')));
    expect(imports, isNot(contains('dart:ui')));
  });

  test('product contains only pure rules and ports', () {
    final violations = <String>[];

    for (final file in _dartFiles('lib/product')) {
      for (final import in _importsIn(file)) {
        if (!_isAllowedProductImport(import)) {
          violations.add('${file.path}: $import');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'product may depend only on the Dart SDK, product peers, and '
          'pushup_domain.dart',
    );
  });

  test('product import policy rejects platform and package dependencies', () {
    for (final import in [
      'dart:async',
      'dart:convert',
      'dart:math',
      'local_model.dart',
      'models/local_model.dart',
      './local_port.dart',
      '../pushup_domain.dart',
    ]) {
      expect(_isAllowedProductImport(import), isTrue, reason: import);
    }
    for (final import in [
      'dart:ffi',
      'dart:io',
      'dart:isolate',
      'dart:ui',
      'package:flutter/foundation.dart',
      'package:path/path.dart',
      '../config/resource_constants.dart',
      '../control/workout_controller.dart',
      '../platform/workout_session_store.dart',
      '../ui/pages/home_page.dart',
    ]) {
      expect(_isAllowedProductImport(import), isFalse, reason: import);
    }
  });

  test('conditional imports are all inspected', () {
    const source = '''
import 'local_stub.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart';
''';

    expect(_importsFromSource(source), [
      'local_stub.dart',
      'platform_io.dart',
      'platform_web.dart',
    ]);
  });

  test('domain product and control do not depend on UI localization', () {
    final violations = <String>[];
    final files = <File>[
      File('lib/pushup_domain.dart'),
      ..._dartFiles('lib/product'),
      ..._dartFiles('lib/control'),
    ];

    for (final file in files) {
      for (final import in _importsIn(file)) {
        if (import.contains('/ui/') ||
            import.startsWith('../ui/') ||
            import.contains('/l10n/') ||
            import.startsWith('../l10n/')) {
          violations.add('${file.path}: $import');
        }
      }
    }

    expect(violations, isEmpty);
  });
}

Iterable<File> _dartFiles(String directoryPath) sync* {
  final files =
      Directory(directoryPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  yield* files;
}

List<String> _importsIn(File file) {
  return _importsFromSource(file.readAsStringSync());
}

List<String> _importsFromSource(String source) {
  return [
    for (final directive in _directivePattern.allMatches(source))
      for (final uri in _uriPattern.allMatches(directive.group(1)!))
        uri.group(1)!,
  ];
}

bool _isAllowedProductImport(String import) {
  if (import.startsWith('dart:')) {
    return _allowedProductDartLibraries.contains(import);
  }
  if (Uri.parse(import).hasScheme || import.startsWith('../')) {
    return import == '../pushup_domain.dart';
  }
  return true;
}
