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
  String get sportsPlazaFreePrompt =>
      'Subscribe to Premium to join the Sports Plaza ranking';

  @override
  String get leaderboardProfileJoined => 'Joined Sports Plaza';

  @override
  String get leaderboardProfileNotJoined => 'Not joined Sports Plaza';

  @override
  String get leaderboardProfileSignedOut => 'Sign in and subscribe to join';

  @override
  String get leaderboardErrorRequestFailed =>
      'The leaderboard could not be loaded. Please try again later.';

  @override
  String get leaderboardErrorUnexpected =>
      'Loading failed. Please try again later.';

  @override
  String get leaderboardPremiumRequired =>
      'Premium is required to join Sports Plaza.';

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
  String get profileSettingsTooltip => 'Open settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsChinese => '中文';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

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
  String get profileErrorInvalidNickname =>
      'Use 2–16 characters containing only letters, numbers, spaces, underscores, or hyphens.';

  @override
  String get profileErrorInvalidAvatar =>
      'That avatar is invalid. Please choose another.';

  @override
  String get profileErrorNicknameTaken => 'That nickname is already in use.';

  @override
  String get profileErrorNicknameCooldown =>
      'You can change your nickname once every 30 days. You can still change your avatar.';

  @override
  String get accountErrorPurchaseFailed =>
      'The purchase did not complete. Please try again later.';

  @override
  String get accountErrorRequestFailed =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get accountErrorUnexpected =>
      'The operation failed. Please try again later.';

  @override
  String get profileAnonymousName => 'Trainer';

  @override
  String get profileSignedOutTitle => 'You\'re not signed in';

  @override
  String get profileSignedOutSubtitle =>
      'Sign in to use account and membership features';

  @override
  String get profileSignedInFallback => 'Signed in';

  @override
  String get profileLocalTrainingData => 'Local workout data';

  @override
  String get profileSignInWithGoogle => 'Sign in with Google';

  @override
  String get profileSigningIn => 'Signing in…';

  @override
  String get profileSigningInDescription =>
      'Verifying your account and membership. Please wait.';

  @override
  String get profileAccountSyncing => 'Syncing account information';

  @override
  String get profileSubscribePremium => 'Subscribe to Premium';

  @override
  String get profileRestorePurchases => 'Restore membership';

  @override
  String get profileRestorePurchasesDescription =>
      'Recover a purchased membership after reinstalling or changing devices';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutConfirmTitle => 'Sign out?';

  @override
  String get profileSignOutConfirmMessage =>
      'You can sign in again with Google at any time.';

  @override
  String get profileAccountDeletion => 'Privacy policy and account deletion';

  @override
  String get profileAccountDeletionOpenFailed =>
      'Could not open the account deletion page. Please try again.';

  @override
  String get profileMembershipActive =>
      'Premium is active. Advanced features apply to this account.';

  @override
  String get profileMembershipInactive =>
      'Premium is not active. Local workouts still work normally.';

  @override
  String get profileSyncLocalHistory => 'Sync Local History';

  @override
  String get profileSyncLocalHistoryTitle => 'Sync local history?';

  @override
  String get profileSyncLocalHistoryMessage =>
      'This binds unassigned workouts on this device to the current account and uploads them to the cloud. They cannot later be moved to another account.';

  @override
  String get profileSyncLocalHistoryCancel => 'Cancel';

  @override
  String get profileSyncLocalHistoryConfirm => 'Sync';

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
  String recordsWeekTitle(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth/$startDay–$endMonth/$endDay';
  }

  @override
  String recordsYearTitle(int year) {
    return '$year';
  }

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

  @override
  String get workoutPreparing => 'Preparing';

  @override
  String get workoutCameraNoticeTitle => 'Camera and on-device processing';

  @override
  String get workoutCameraNoticeBody =>
      'During workouts, camera frames are processed only on this device for pose detection and counting. Original frames are not uploaded to our servers.';

  @override
  String get workoutCameraNoticeStart => 'Got it, start workout';

  @override
  String get workoutReady => 'Ready';

  @override
  String get workoutStartingCamera => 'Starting camera';

  @override
  String get workoutSavingTraining => 'Saving workout';

  @override
  String get workoutSelectCamera => 'Select camera';

  @override
  String get workoutCameraLoading => 'Loading cameras';

  @override
  String get workoutEnd => 'End workout';

  @override
  String get workoutRetrySave => 'Retry save';

  @override
  String get workoutTodayGoal => 'Today\'s goal';

  @override
  String workoutGoalValue(int count) {
    return '$count reps';
  }

  @override
  String get workoutBurned => 'Burned';

  @override
  String workoutCaloriesValue(int count) {
    return '$count kcal';
  }

  @override
  String get workoutCountUnit => 'reps';

  @override
  String get workoutStatusLoading => 'Loading';

  @override
  String get workoutStatusLoadingModel => 'Loading model';

  @override
  String get workoutStatusStartingCamera => 'Starting camera';

  @override
  String get workoutStatusPositionGuide =>
      'Position your phone as shown and hold the pose';

  @override
  String get workoutStatusReady => 'Ready. Start training';

  @override
  String get workoutStatusHoldPose => 'Hold a stable push-up pose in frame';

  @override
  String get workoutStatusFullPose => 'Keep your full push-up pose in frame';

  @override
  String get workoutStatusTraining => 'Training';

  @override
  String get workoutStatusSwitchingCamera => 'Switching camera';

  @override
  String get workoutStatusSaving => 'Saving';

  @override
  String get workoutStatusError => 'Something went wrong. Please try again.';

  @override
  String get workoutStatusSaveFailed => 'Save failed. Please try again.';

  @override
  String get workoutCameraFront => 'Front';

  @override
  String get workoutCameraRear => 'Rear';

  @override
  String get workoutCameraExternal => 'External';

  @override
  String get workoutCameraWide => 'wide camera';

  @override
  String get workoutCameraNormal => 'camera';

  @override
  String workoutCameraBackup(String name) {
    return 'backup camera $name';
  }

  @override
  String workoutCameraLabel(String direction, String type) {
    return '$direction $type';
  }
}
