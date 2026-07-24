import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
        if (!_isAllowedProductImport(file, import)) {
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
    final productFile = File('lib/product/example.dart');
    for (final import in [
      'dart:async',
      'dart:convert',
      'dart:math',
      'local_model.dart',
      'models/local_model.dart',
      './local_port.dart',
      '../pushup_domain.dart',
    ]) {
      expect(
        _isAllowedProductImport(productFile, import),
        isTrue,
        reason: import,
      );
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
      './../platform/workout_session_store.dart',
      'models/../../control/workout_controller.dart',
      'models/../../platform/workout_session_store.dart',
    ]) {
      expect(
        _isAllowedProductImport(productFile, import),
        isFalse,
        reason: import,
      );
    }
  });

  test('AST import scan handles conditions and ignores comments', () {
    const source = '''
// import '../platform/commented_out.dart';
import 'local_stub.dart'
    // A comment semicolon must not terminate the directive;
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
  return _importsFromSource(file.readAsStringSync(), path: file.path);
}

List<String> _importsFromSource(String source, {String? path}) {
  final unit = parseString(content: source, path: path).unit;
  return [
    for (final directive in unit.directives.whereType<NamespaceDirective>())
      if (directive.uri.stringValue case final uri?) uri,
    for (final directive in unit.directives.whereType<NamespaceDirective>())
      for (final configuration in directive.configurations)
        if (configuration.uri.stringValue case final uri?) uri,
  ];
}

bool _isAllowedProductImport(File importingFile, String import) {
  if (import.startsWith('dart:')) {
    return _allowedProductDartLibraries.contains(import);
  }
  final uri = Uri.parse(import);
  if (uri.hasScheme) {
    return false;
  }
  final projectRoot = Directory.current.absolute.path;
  final productRoot = p.normalize(p.join(projectRoot, 'lib', 'product'));
  final domainFile = p.normalize(
    p.join(projectRoot, 'lib', 'pushup_domain.dart'),
  );
  final target = p.normalize(
    p.absolute(importingFile.absolute.parent.path, Uri.decodeFull(uri.path)),
  );
  return p.isWithin(productRoot, target) || p.equals(domainFile, target);
}
