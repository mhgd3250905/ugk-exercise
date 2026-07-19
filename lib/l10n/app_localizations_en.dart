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
  String get startupSlogan => 'Set up your phone. Focus on every rep.';

  @override
  String get onboardingCountTitle => 'Let AI count every rep';

  @override
  String get onboardingCountBody =>
      'Automatic push-up recognition, counting, and voice prompts keep you focused on training.';

  @override
  String get onboardingSetupTitle => 'Place your phone for reliable tracking';

  @override
  String get onboardingSetupBody =>
      'Secure the phone in front of you, keep your head, shoulders, and arms in frame, and leave room to move.';

  @override
  String get onboardingPrivacyTitle => 'Camera frames stay on this device';

  @override
  String get onboardingPrivacyBody =>
      'Original frames are never uploaded. Camera access is requested when you start a workout, and you can decline.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String get profileTooltip => 'Profile';

  @override
  String get sportsPlazaTitle => 'Sports Plaza';

  @override
  String get sportsPlazaSubtitle => 'Push-up points leaderboard';

  @override
  String get sportsPlazaFreePrompt =>
      'Subscribe to Premium to join the Sports Plaza ranking';

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
  String get leaderboardFrozenScoreTitle => 'My score is frozen';

  @override
  String get leaderboardFrozenScoreDescription =>
      'Your membership expired. Renew to rejoin the rankings.';

  @override
  String leaderboardRank(int rank) {
    return 'No. $rank';
  }

  @override
  String get leaderboardPointsRule => 'Standard 1 pt · Narrow 2 pts';

  @override
  String leaderboardMyExerciseCounts(int standardCount, int narrowCount) {
    return 'Standard $standardCount reps · Narrow $narrowCount reps';
  }

  @override
  String leaderboardTotalPoints(int count) {
    return '$count pts';
  }

  @override
  String get leaderboardHomeRefreshing => 'Refreshing leaderboard';

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
  String get leaderboardJoinDescription =>
      'After joining, your workouts contribute to public rankings. You can leave anytime.';

  @override
  String get leaderboardJoinSuccess => 'Joined Sports Plaza';

  @override
  String get leaderboardLeaveConfirmTitle => 'Leave Sports Plaza?';

  @override
  String get leaderboardLeaveConfirmDescription =>
      'New workouts will no longer count toward rankings. If you rejoin, this weeks pre-leave ranking totals wont return.';

  @override
  String get leaderboardLeaveCancel => 'Stay joined';

  @override
  String get leaderboardLeaveConfirm => 'Leave';

  @override
  String get leaderboardLeaveSuccess => 'Left Sports Plaza';

  @override
  String get leaderboardRetry => 'Retry';

  @override
  String get leaderboardIdentitySheetTitle =>
      'Choose your Sports Plaza identity';

  @override
  String get leaderboardIdentityProfile => 'Use current profile';

  @override
  String get leaderboardIdentityProfileDescription =>
      'Leaderboard updates automatically when your profile changes';

  @override
  String get leaderboardIdentityAnonymous => 'Join anonymously';

  @override
  String get leaderboardIdentityAnonymousDescription =>
      'Your personal profile will not be shared';

  @override
  String get leaderboardAnonymousName => 'Anonymous Trainer';

  @override
  String get leaderboardIdentityPreview => 'Public preview';

  @override
  String get leaderboardIdentityCancel => 'Cancel';

  @override
  String get leaderboardIdentityConfirmJoin => 'Confirm Join';

  @override
  String get leaderboardIdentityConfirmEdit => 'Save Identity';

  @override
  String get leaderboardIdentityEdit => 'Edit leaderboard identity';

  @override
  String get leaderboardIdentitySaveFailed =>
      'Could not save your identity. Please try again later.';

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
  String get settingsBlockedUsers => 'Blocked users';

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
  String get settingsVersion => 'Version';

  @override
  String get settingsUpdateAvailable => 'Update available';

  @override
  String get settingsUpdateOpenFailed =>
      'Could not open Google Play. Please try again later.';

  @override
  String get settingsRecognitionDiagnostics => 'Recognition diagnostics';

  @override
  String get settingsRecognitionTraceTitle => 'Workout test logs';

  @override
  String get settingsRecognitionTraceEnabled => 'On';

  @override
  String get settingsRecognitionTraceDisabled => 'Off';

  @override
  String get settingsRecognitionTraceDescription =>
      'Stored only on this device. Includes pose keypoints and recognition states, but no photos, video, or audio. Keeps the latest 20 workouts.';

  @override
  String get settingsRecognitionTraceSaveFailed =>
      'Could not save the workout test log setting. Try again.';

  @override
  String get settingsRecognitionTraceExport => 'Export workout test logs';

  @override
  String get settingsRecognitionTraceExportDescription =>
      'Save as JSONL for analysis after connecting to a computer';

  @override
  String get settingsRecognitionTraceExported => 'Workout test logs exported';

  @override
  String get settingsRecognitionTraceNoLogs => 'No workout test logs to export';

  @override
  String get settingsRecognitionTraceTooLarge =>
      'Workout test logs are too large to export safely';

  @override
  String get settingsRecognitionTraceExportFailed =>
      'Could not export workout test logs. Try again.';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'No blocked users';

  @override
  String get blockedUsersAnonymous => 'Anonymous user';

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String get blockedUsersLoadFailed =>
      'Could not load blocked users. Please try again later.';

  @override
  String get blockedUsersUnblockFailed =>
      'Could not unblock this user. Please try again.';

  @override
  String get blockedUsersRetry => 'Retry';

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
  String get profileCustomAvatarTitle => 'Custom avatar';

  @override
  String get profileCustomAvatarDescription =>
      'Your custom avatar is shown first. Delete it to use your built-in or Google avatar.';

  @override
  String get profileCustomAvatarGallery => 'Choose from gallery';

  @override
  String get profileCustomAvatarCamera => 'Take photo';

  @override
  String get profileCustomAvatarUploading => 'Uploading avatar';

  @override
  String get profileCustomAvatarReplacing => 'Updating avatar';

  @override
  String get profileCustomAvatarDelete => 'Delete custom avatar';

  @override
  String get profileCustomAvatarDeleteTitle => 'Delete custom avatar?';

  @override
  String get profileCustomAvatarDeleteMessage =>
      'Your fallback avatar will be shown instead.';

  @override
  String get profileCustomAvatarDeleteConfirm => 'Delete avatar';

  @override
  String get profileCustomAvatarPolicyTitle => 'Custom avatar content policy';

  @override
  String get profileCustomAvatarPolicyMessage =>
      'Do not upload nudity, violence, hate, illegal content, impersonation, or spam. Violating avatars may be removed and uploads suspended.';

  @override
  String get profileCustomAvatarPolicyAgree =>
      'I confirm this avatar follows the content policy';

  @override
  String get profileCustomAvatarPolicyContinue => 'Agree and continue';

  @override
  String get profileCustomAvatarUploadSuspended =>
      'Your custom avatar upload access is suspended.';

  @override
  String get profileCustomAvatarError =>
      'The avatar operation failed. Please try again later.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get leaderboardActionsTitle => 'User actions';

  @override
  String get leaderboardLongPressHint =>
      'Long press to report or block this user';

  @override
  String get leaderboardReportAvatar => 'Report avatar';

  @override
  String get leaderboardReportUser => 'Report user';

  @override
  String get leaderboardBlockUser => 'Block user';

  @override
  String get leaderboardReportReasonTitle => 'Choose a report reason';

  @override
  String get leaderboardReportReasonNudity => 'Nudity';

  @override
  String get leaderboardReportReasonViolence => 'Violence';

  @override
  String get leaderboardReportReasonHate => 'Hateful content';

  @override
  String get leaderboardReportReasonSpam => 'Spam';

  @override
  String get leaderboardReportReasonImpersonation => 'Impersonation';

  @override
  String get leaderboardReportReasonOther => 'Other violation';

  @override
  String get leaderboardReportSubmitting => 'Submitting report…';

  @override
  String get leaderboardReportSuccess => 'User reported and blocked';

  @override
  String get leaderboardBlockTitle => 'Block this user?';

  @override
  String get leaderboardBlockMessage =>
      'You will no longer see this user in the leaderboard.';

  @override
  String get leaderboardBlockConfirm => 'Block';

  @override
  String get leaderboardModerationFailed =>
      'The action failed. Please try again.';

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
  String get membershipSyncUnavailable =>
      'Your membership could not be synced. Please try again later.';

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
  String get profileManageSubscription => 'Manage Google Play subscription';

  @override
  String get profileManageSubscriptionDescription =>
      'View, cancel, or resubscribe.';

  @override
  String get profileManageSubscriptionOpenFailed =>
      'Could not open Google Play subscriptions. Please try again.';

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
  String get profilePremiumTitle => 'PushupAI Premium';

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
  String get profilePremiumMonthly => 'Monthly membership';

  @override
  String get profilePremiumAnnual => 'Annual membership';

  @override
  String get profilePremiumRecommended => 'Recommended';

  @override
  String profilePremiumMonthlyPrice(String price) {
    return '$price / month';
  }

  @override
  String profilePremiumAnnualPrice(String price) {
    return '$price / year';
  }

  @override
  String profilePremiumTrialBadge(int days) {
    return '$days days free';
  }

  @override
  String profilePremiumAfterTrialMonthlyPrice(String price) {
    return 'After trial: $price / month';
  }

  @override
  String profilePremiumAfterTrialAnnualPrice(String price) {
    return 'After trial: $price / year';
  }

  @override
  String profilePremiumTrialRenewal(int days, String price) {
    return 'Free for $days days, then $price / month through Google Play unless canceled before the trial ends.';
  }

  @override
  String profilePremiumAnnualTrialRenewal(int days, String price) {
    return 'Free for $days days, then $price / year through Google Play unless canceled before the trial ends.';
  }

  @override
  String profilePremiumStartTrial(int days) {
    return 'Start $days-day free trial';
  }

  @override
  String get profilePremiumPlansUnavailable =>
      'Membership plans are temporarily unavailable.';

  @override
  String get profilePremiumRetry => 'Retry';

  @override
  String get profilePremiumAutoRenewal =>
      'Subscriptions renew automatically through Google Play and can be canceled anytime.';

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
  String get pushupTraining => 'Push-up Training';

  @override
  String exerciseSummary(int todayCount) {
    return 'AI pose recognition · auto counting · English voice prompts\nCompleted today: $todayCount';
  }

  @override
  String get narrowPushupTraining => 'Narrow Push-ups';

  @override
  String get exerciseDifficultyOne => 'Level I';

  @override
  String get exerciseDifficultyTwo => 'Level II';

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
  String get workoutCameraNoticeCancel => 'Not now';

  @override
  String get workoutCameraPermissionDenied =>
      'Camera access is required for pose recognition. Allow access, then reopen the workout.';

  @override
  String get workoutCameraPermissionSettings =>
      'Camera access is disabled. Enable it in system settings, then try again.';

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
  String get workoutStatusNarrowForm =>
      'Bring your arms in and keep both wrists no wider than your shoulders';

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
  String get workoutStatusStartupError =>
      'Unable to start the workout. Please try again.';

  @override
  String get workoutStatusCameraError =>
      'Something went wrong with the camera. Please try again.';

  @override
  String get workoutStatusFrameError =>
      'Pose recognition failed. Please try again.';

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
