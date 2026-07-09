import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/pages/home_page.dart';

void main() {
  runApp(const UgkExerciseApp());
}

class UgkExerciseApp extends StatelessWidget {
  const UgkExerciseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '俯卧撑检测',
      theme: appTheme(),
      home: const HomePage(),
    );
  }
}
