import 'dart:io';

import 'package:test/test.dart';

final _directivePattern = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

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
        final isAllowed =
            (import.startsWith('dart:') &&
                import != 'dart:io' &&
                import != 'dart:ui') ||
            (!import.startsWith('../') && !import.startsWith('package:')) ||
            import == '../pushup_domain.dart';
        if (!isAllowed) {
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
  final source = file.readAsStringSync();
  return [
    for (final match in _directivePattern.allMatches(source)) match.group(1)!,
  ];
}
