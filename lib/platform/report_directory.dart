import 'dart:io';

Directory selectReportDirectory({
  required Directory? external,
  required Directory documents,
}) {
  return external ?? documents;
}
