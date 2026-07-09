// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '俯卧撑检测';

  @override
  String get profileTooltip => '个人信息';

  @override
  String get testMode => '测试模式';

  @override
  String todayCount(int count) {
    return '今日 $count';
  }

  @override
  String get aiPoseRecognition => 'AI 姿态识别';

  @override
  String goalCount(int count) {
    return '目标 $count';
  }

  @override
  String get pushupTraining => '俯卧撑训练';

  @override
  String exerciseSummary(int todayCount) {
    return 'AI 姿态识别 · 自动计数 · 中文播报\n今日已完成 $todayCount 次';
  }

  @override
  String get startTraining => '开始训练';
}
