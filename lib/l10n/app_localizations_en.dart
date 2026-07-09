// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Push-up Detection';

  @override
  String get profileTooltip => 'Profile';

  @override
  String get testMode => 'Test Mode';

  @override
  String todayCount(int count) {
    return 'Today $count';
  }

  @override
  String get aiPoseRecognition => 'AI Pose Recognition';

  @override
  String goalCount(int count) {
    return 'Goal $count';
  }

  @override
  String get pushupTraining => 'Push-up Training';

  @override
  String exerciseSummary(int todayCount) {
    return 'AI pose recognition · auto counting · Chinese voice prompts\nCompleted today: $todayCount';
  }

  @override
  String get startTraining => 'Start Training';
}
