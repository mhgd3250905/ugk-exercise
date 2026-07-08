import 'dart:io';

import 'package:test/test.dart';
import 'package:ugk_exercise/platform/report_directory.dart';

void main() {
  test('prefers external app directory and falls back to documents', () {
    final external = Directory('external');
    final documents = Directory('documents');

    expect(
      selectReportDirectory(external: external, documents: documents),
      external,
    );
    expect(
      selectReportDirectory(external: null, documents: documents),
      documents,
    );
  });
}
