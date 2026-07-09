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
  String get sportsPlazaTitle => 'Sports Plaza';

  @override
  String get sportsPlazaSubtitle => 'Push-up daily leaderboard';

  @override
  String get viewLeaderboard => 'View Leaderboard';

  @override
  String get leaderboardDay => 'Day';

  @override
  String get leaderboardWeek => 'Week';

  @override
  String get leaderboardMyRank => 'My Rank';

  @override
  String leaderboardRank(int rank) {
    return 'No. $rank';
  }

  @override
  String leaderboardTotalReps(int count) {
    return '$count reps';
  }

  @override
  String get leaderboardEmpty => 'No rankings yet';

  @override
  String get leaderboardJoinPrompt => 'Join Sports Plaza to show your rank';

  @override
  String get leaderboardSignedOutPrompt => 'Sign in to view Sports Plaza';

  @override
  String get leaderboardJoinAction => 'Join';

  @override
  String get leaderboardLeaveAction => 'Leave';

  @override
  String get leaderboardRetry => 'Retry';

  @override
  String get profileTitle => 'Profile';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get editProfileSheetTitle => 'Edit Profile';

  @override
  String get profileNicknameLabel => 'Nickname';

  @override
  String get profileNicknameHint => 'Trainer 01';

  @override
  String get saveProfile => 'Save';

  @override
  String get profileAnonymousName => 'Trainer';

  @override
  String get profileSignedInFallback => 'Signed in';

  @override
  String get profileLocalTrainingData => 'Local workout data';

  @override
  String get profileSignInWithGoogle => 'Sign in with Google';

  @override
  String get profileSubscribePremium => 'Subscribe to Premium';

  @override
  String get profileRestorePurchases => 'Restore Purchases';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileMembershipActive =>
      'Premium is active. Advanced features apply to this account.';

  @override
  String get profileMembershipInactive =>
      'Premium is not active. Local workouts still work normally.';

  @override
  String get profilePremiumTitle => 'UGK Premium';

  @override
  String get profilePremiumSubtitle =>
      'Premium benefits are linked to this account';

  @override
  String get profilePremiumBenefitRestore =>
      'After signing in with Google, premium status can be restored';

  @override
  String get profilePremiumBenefitAttribution =>
      'Future advanced training features will belong to this account automatically';

  @override
  String get profilePremiumContinue => 'Continue';

  @override
  String get profilePremiumLater => 'Maybe later';

  @override
  String get profileAvatarRingGreen => 'Green ring avatar';

  @override
  String get profileAvatarRingLime => 'Lime ring avatar';

  @override
  String get profileAvatarRingSky => 'Sky ring avatar';

  @override
  String get profileAvatarRingYellow => 'Yellow ring avatar';

  @override
  String get profileAvatarRingCoral => 'Coral ring avatar';

  @override
  String get profileAvatarBoltGreen => 'Green bolt avatar';

  @override
  String get profileAvatarBoltLime => 'Lime bolt avatar';

  @override
  String get profileAvatarBoltSky => 'Sky bolt avatar';

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

  @override
  String get recordsTitle => 'Training Records';

  @override
  String get recordsModeWeek => 'Week';

  @override
  String get recordsModeMonth => 'Month';

  @override
  String get recordsModeYear => 'Year';

  @override
  String recordsMonthTitle(int year, int month) {
    return '$year-$month';
  }

  @override
  String get recordsWeekdaySun => 'Sun';

  @override
  String get recordsWeekdayMon => 'Mon';

  @override
  String get recordsWeekdayTue => 'Tue';

  @override
  String get recordsWeekdayWed => 'Wed';

  @override
  String get recordsWeekdayThu => 'Thu';

  @override
  String get recordsWeekdayFri => 'Fri';

  @override
  String get recordsWeekdaySat => 'Sat';

  @override
  String get recordsTrainingDays => 'Training Days';

  @override
  String get recordsTotalCount => 'Total Reps';

  @override
  String get recordsBestDay => 'Best Day';

  @override
  String recordsDaysValue(int count) {
    return '$count days';
  }

  @override
  String recordsRepsValue(int count) {
    return '$count reps';
  }

  @override
  String get recordsCloudLoading => 'Loading cloud records';

  @override
  String get recordsCloudMerged => 'Cloud records merged';

  @override
  String get recordsCloudUnavailable =>
      'Cloud records unavailable. Local records are shown.';

  @override
  String recordsPendingSyncCount(int count) {
    return '$count records waiting to sync';
  }
}
