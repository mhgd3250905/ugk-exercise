import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// App title used by MaterialApp.
  ///
  /// In zh, this message translates to:
  /// **'俯卧撑检测'**
  String get appTitle;

  /// Tooltip for the profile entry button on the home page.
  ///
  /// In zh, this message translates to:
  /// **'个人信息'**
  String get profileTooltip;

  /// Title for the sports plaza card and leaderboard page.
  ///
  /// In zh, this message translates to:
  /// **'运动广场'**
  String get sportsPlazaTitle;

  /// Subtitle for the sports plaza card on the home page.
  ///
  /// In zh, this message translates to:
  /// **'俯卧撑项目日榜'**
  String get sportsPlazaSubtitle;

  /// Home sports plaza prompt for a signed-in free member.
  ///
  /// In zh, this message translates to:
  /// **'开通会员后参与运动广场排行'**
  String get sportsPlazaFreePrompt;

  /// Profile leaderboard status when the user has joined.
  ///
  /// In zh, this message translates to:
  /// **'已加入运动广场'**
  String get leaderboardProfileJoined;

  /// Profile leaderboard status when the user has not joined.
  ///
  /// In zh, this message translates to:
  /// **'未加入运动广场'**
  String get leaderboardProfileNotJoined;

  /// Profile leaderboard status when signed out.
  ///
  /// In zh, this message translates to:
  /// **'登录并开通会员后可加入'**
  String get leaderboardProfileSignedOut;

  /// Generic localized leaderboard error for request failures.
  ///
  /// In zh, this message translates to:
  /// **'榜单暂时无法加载，请稍后重试。'**
  String get leaderboardErrorRequestFailed;

  /// Generic localized leaderboard error for unknown failures.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，请稍后重试。'**
  String get leaderboardErrorUnexpected;

  /// Leaderboard prompt shown when an active Premium membership is required.
  ///
  /// In zh, this message translates to:
  /// **'需要 Premium 会员才能加入运动广场。'**
  String get leaderboardPremiumRequired;

  /// Button label to open the leaderboard page.
  ///
  /// In zh, this message translates to:
  /// **'查看榜单'**
  String get viewLeaderboard;

  /// Day leaderboard segment label.
  ///
  /// In zh, this message translates to:
  /// **'日榜'**
  String get leaderboardDay;

  /// Week leaderboard segment label.
  ///
  /// In zh, this message translates to:
  /// **'周榜'**
  String get leaderboardWeek;

  /// Title for the current user's pinned leaderboard rank panel.
  ///
  /// In zh, this message translates to:
  /// **'我的排名'**
  String get leaderboardMyRank;

  /// Formatted leaderboard rank.
  ///
  /// In zh, this message translates to:
  /// **'第 {rank} 名'**
  String leaderboardRank(int rank);

  /// Total push-up reps shown in a leaderboard row.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String leaderboardTotalReps(int count);

  /// Empty state text when the leaderboard has no rows.
  ///
  /// In zh, this message translates to:
  /// **'暂无排行'**
  String get leaderboardEmpty;

  /// Prompt shown when the user has not joined the leaderboard.
  ///
  /// In zh, this message translates to:
  /// **'加入运动广场后展示你的排名'**
  String get leaderboardJoinPrompt;

  /// Prompt shown when leaderboard is opened without a signed-in account.
  ///
  /// In zh, this message translates to:
  /// **'登录后查看运动广场'**
  String get leaderboardSignedOutPrompt;

  /// Button label to join the leaderboard.
  ///
  /// In zh, this message translates to:
  /// **'加入广场'**
  String get leaderboardJoinAction;

  /// Button label to leave the leaderboard.
  ///
  /// In zh, this message translates to:
  /// **'退出榜单'**
  String get leaderboardLeaveAction;

  /// Button label to retry loading leaderboard data.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get leaderboardRetry;

  /// Title for the profile page.
  ///
  /// In zh, this message translates to:
  /// **'个人信息'**
  String get profileTitle;

  /// Action label to edit profile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfile;

  /// Title for the edit profile bottom sheet.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get editProfileSheetTitle;

  /// Label for the nickname input field.
  ///
  /// In zh, this message translates to:
  /// **'昵称'**
  String get profileNicknameLabel;

  /// Hint text for the nickname input field.
  ///
  /// In zh, this message translates to:
  /// **'训练者 01'**
  String get profileNicknameHint;

  /// Save button label for profile changes.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get saveProfile;

  /// No description provided for @profileErrorInvalidNickname.
  ///
  /// In zh, this message translates to:
  /// **'昵称需为 2–16 个字符，只能包含中英文字母、数字、空格、下划线或连字符。'**
  String get profileErrorInvalidNickname;

  /// No description provided for @profileErrorInvalidAvatar.
  ///
  /// In zh, this message translates to:
  /// **'所选头像无效，请重新选择。'**
  String get profileErrorInvalidAvatar;

  /// No description provided for @profileErrorNicknameTaken.
  ///
  /// In zh, this message translates to:
  /// **'该昵称已被使用，请换一个。'**
  String get profileErrorNicknameTaken;

  /// No description provided for @profileErrorNicknameCooldown.
  ///
  /// In zh, this message translates to:
  /// **'昵称每 30 天只能修改一次。你仍可单独更换头像。'**
  String get profileErrorNicknameCooldown;

  /// No description provided for @accountErrorPurchaseFailed.
  ///
  /// In zh, this message translates to:
  /// **'购买没有完成，请稍后再试。'**
  String get accountErrorPurchaseFailed;

  /// No description provided for @accountErrorRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'服务暂时不可用，请稍后再试。'**
  String get accountErrorRequestFailed;

  /// No description provided for @accountErrorUnexpected.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请稍后再试。'**
  String get accountErrorUnexpected;

  /// Fallback profile display name.
  ///
  /// In zh, this message translates to:
  /// **'训练者'**
  String get profileAnonymousName;

  /// Fallback subtitle when signed in without email.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get profileSignedInFallback;

  /// Subtitle shown when not signed in.
  ///
  /// In zh, this message translates to:
  /// **'本机训练数据'**
  String get profileLocalTrainingData;

  /// Sign in button label on the profile page.
  ///
  /// In zh, this message translates to:
  /// **'使用 Google 登录'**
  String get profileSignInWithGoogle;

  /// Button label to start premium purchase.
  ///
  /// In zh, this message translates to:
  /// **'开通会员'**
  String get profileSubscribePremium;

  /// Button label to restore purchases.
  ///
  /// In zh, this message translates to:
  /// **'恢复购买'**
  String get profileRestorePurchases;

  /// Button label to sign out.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get profileSignOut;

  /// Membership card message when premium is active.
  ///
  /// In zh, this message translates to:
  /// **'会员已开通。高级功能会在本账号下生效。'**
  String get profileMembershipActive;

  /// Membership card message when premium is inactive.
  ///
  /// In zh, this message translates to:
  /// **'当前未开通会员。本机训练仍可正常使用。'**
  String get profileMembershipInactive;

  /// Button label for explicitly claiming legacy local workouts.
  ///
  /// In zh, this message translates to:
  /// **'同步本机历史'**
  String get profileSyncLocalHistory;

  /// Confirmation dialog title for claiming legacy workouts.
  ///
  /// In zh, this message translates to:
  /// **'同步本机历史？'**
  String get profileSyncLocalHistoryTitle;

  /// Privacy warning before claiming legacy workouts.
  ///
  /// In zh, this message translates to:
  /// **'这会将本机尚未归属账号的训练记录绑定到当前账号，并上传至云端。绑定后不能改到其他账号。'**
  String get profileSyncLocalHistoryMessage;

  /// Cancel button for legacy workout claiming.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get profileSyncLocalHistoryCancel;

  /// Confirm button for legacy workout claiming.
  ///
  /// In zh, this message translates to:
  /// **'确认同步'**
  String get profileSyncLocalHistoryConfirm;

  /// Premium sheet title.
  ///
  /// In zh, this message translates to:
  /// **'UGK Premium'**
  String get profilePremiumTitle;

  /// Premium sheet subtitle.
  ///
  /// In zh, this message translates to:
  /// **'会员权益绑定当前账号'**
  String get profilePremiumSubtitle;

  /// Premium sheet benefit about restore.
  ///
  /// In zh, this message translates to:
  /// **'Google 账号登录后，会员状态可恢复'**
  String get profilePremiumBenefitRestore;

  /// Premium sheet benefit about attribution.
  ///
  /// In zh, this message translates to:
  /// **'后续高级训练功能自动归属本账号'**
  String get profilePremiumBenefitAttribution;

  /// Premium sheet continue button.
  ///
  /// In zh, this message translates to:
  /// **'继续开通'**
  String get profilePremiumContinue;

  /// Premium sheet dismiss button.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get profilePremiumLater;

  /// Readable label for the green ring avatar option.
  ///
  /// In zh, this message translates to:
  /// **'绿色圆环头像'**
  String get profileAvatarRingGreen;

  /// Readable label for the lime ring avatar option.
  ///
  /// In zh, this message translates to:
  /// **'黄绿色圆环头像'**
  String get profileAvatarRingLime;

  /// Readable label for the sky ring avatar option.
  ///
  /// In zh, this message translates to:
  /// **'天蓝色圆环头像'**
  String get profileAvatarRingSky;

  /// Readable label for the yellow ring avatar option.
  ///
  /// In zh, this message translates to:
  /// **'黄色圆环头像'**
  String get profileAvatarRingYellow;

  /// Readable label for the coral ring avatar option.
  ///
  /// In zh, this message translates to:
  /// **'珊瑚色圆环头像'**
  String get profileAvatarRingCoral;

  /// Readable label for the green bolt avatar option.
  ///
  /// In zh, this message translates to:
  /// **'绿色闪电头像'**
  String get profileAvatarBoltGreen;

  /// Readable label for the lime bolt avatar option.
  ///
  /// In zh, this message translates to:
  /// **'黄绿色闪电头像'**
  String get profileAvatarBoltLime;

  /// Readable label for the sky bolt avatar option.
  ///
  /// In zh, this message translates to:
  /// **'天蓝色闪电头像'**
  String get profileAvatarBoltSky;

  /// Label for the test mode entry button.
  ///
  /// In zh, this message translates to:
  /// **'测试模式'**
  String get testMode;

  /// Compact label showing today's completed push-up count.
  ///
  /// In zh, this message translates to:
  /// **'今日 {count}'**
  String todayCount(int count);

  /// Badge text for the home workout card.
  ///
  /// In zh, this message translates to:
  /// **'AI 姿态识别'**
  String get aiPoseRecognition;

  /// Workout goal label on the home workout card.
  ///
  /// In zh, this message translates to:
  /// **'目标 {count}'**
  String goalCount(int count);

  /// Main workout card title.
  ///
  /// In zh, this message translates to:
  /// **'俯卧撑训练'**
  String get pushupTraining;

  /// Home workout card summary text.
  ///
  /// In zh, this message translates to:
  /// **'AI 姿态识别 · 自动计数 · 中文播报\n今日已完成 {todayCount} 次'**
  String exerciseSummary(int todayCount);

  /// Primary action to start a workout.
  ///
  /// In zh, this message translates to:
  /// **'开始训练'**
  String get startTraining;

  /// Title for the records page.
  ///
  /// In zh, this message translates to:
  /// **'训练记录'**
  String get recordsTitle;

  /// Week mode label on the records page.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get recordsModeWeek;

  /// Month mode label on the records page.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get recordsModeMonth;

  /// Year mode label on the records page.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get recordsModeYear;

  /// Current month title on the records page.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月'**
  String recordsMonthTitle(int year, int month);

  /// Sunday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get recordsWeekdaySun;

  /// Monday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get recordsWeekdayMon;

  /// Tuesday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get recordsWeekdayTue;

  /// Wednesday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get recordsWeekdayWed;

  /// Thursday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get recordsWeekdayThu;

  /// Friday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get recordsWeekdayFri;

  /// Saturday label in the records calendar.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get recordsWeekdaySat;

  /// Monthly active days summary label.
  ///
  /// In zh, this message translates to:
  /// **'训练天数'**
  String get recordsTrainingDays;

  /// Monthly total reps summary label.
  ///
  /// In zh, this message translates to:
  /// **'总个数'**
  String get recordsTotalCount;

  /// Best day summary label.
  ///
  /// In zh, this message translates to:
  /// **'最高单日'**
  String get recordsBestDay;

  /// Number of active workout days.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String recordsDaysValue(int count);

  /// Number of workout reps.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String recordsRepsValue(int count);

  /// Status shown while cloud records are loading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取云端记录'**
  String get recordsCloudLoading;

  /// Status shown after cloud records are merged.
  ///
  /// In zh, this message translates to:
  /// **'云端记录已合并'**
  String get recordsCloudMerged;

  /// Status shown when cloud records fail to load while local records remain visible.
  ///
  /// In zh, this message translates to:
  /// **'云端记录暂不可用，本地记录已显示'**
  String get recordsCloudUnavailable;

  /// Pending cloud sync count on the records page.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 条记录待同步'**
  String recordsPendingSyncCount(int count);

  /// No description provided for @workoutPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中'**
  String get workoutPreparing;

  /// No description provided for @workoutReady.
  ///
  /// In zh, this message translates to:
  /// **'已准备'**
  String get workoutReady;

  /// No description provided for @workoutStartingCamera.
  ///
  /// In zh, this message translates to:
  /// **'正在启动相机'**
  String get workoutStartingCamera;

  /// No description provided for @workoutSavingTraining.
  ///
  /// In zh, this message translates to:
  /// **'正在保存训练'**
  String get workoutSavingTraining;

  /// No description provided for @workoutSelectCamera.
  ///
  /// In zh, this message translates to:
  /// **'选择摄像头'**
  String get workoutSelectCamera;

  /// No description provided for @workoutCameraLoading.
  ///
  /// In zh, this message translates to:
  /// **'相机加载中'**
  String get workoutCameraLoading;

  /// No description provided for @workoutEnd.
  ///
  /// In zh, this message translates to:
  /// **'结束训练'**
  String get workoutEnd;

  /// No description provided for @workoutRetrySave.
  ///
  /// In zh, this message translates to:
  /// **'重试保存'**
  String get workoutRetrySave;

  /// No description provided for @workoutTodayGoal.
  ///
  /// In zh, this message translates to:
  /// **'今日目标'**
  String get workoutTodayGoal;

  /// No description provided for @workoutGoalValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String workoutGoalValue(int count);

  /// No description provided for @workoutBurned.
  ///
  /// In zh, this message translates to:
  /// **'消耗'**
  String get workoutBurned;

  /// No description provided for @workoutCaloriesValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 千卡'**
  String workoutCaloriesValue(int count);

  /// No description provided for @workoutCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'个'**
  String get workoutCountUnit;

  /// No description provided for @workoutStatusLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get workoutStatusLoading;

  /// No description provided for @workoutStatusLoadingModel.
  ///
  /// In zh, this message translates to:
  /// **'加载模型'**
  String get workoutStatusLoadingModel;

  /// No description provided for @workoutStatusStartingCamera.
  ///
  /// In zh, this message translates to:
  /// **'启动相机'**
  String get workoutStatusStartingCamera;

  /// No description provided for @workoutStatusPositionGuide.
  ///
  /// In zh, this message translates to:
  /// **'请按提示摆放手机并保持姿势'**
  String get workoutStatusPositionGuide;

  /// No description provided for @workoutStatusReady.
  ///
  /// In zh, this message translates to:
  /// **'已准备好，请开始训练'**
  String get workoutStatusReady;

  /// No description provided for @workoutStatusHoldPose.
  ///
  /// In zh, this message translates to:
  /// **'请保持俯卧撑姿势并稳定入镜'**
  String get workoutStatusHoldPose;

  /// No description provided for @workoutStatusFullPose.
  ///
  /// In zh, this message translates to:
  /// **'请保持俯卧撑姿势并完整入镜'**
  String get workoutStatusFullPose;

  /// No description provided for @workoutStatusTraining.
  ///
  /// In zh, this message translates to:
  /// **'训练中'**
  String get workoutStatusTraining;

  /// No description provided for @workoutStatusSwitchingCamera.
  ///
  /// In zh, this message translates to:
  /// **'切换相机'**
  String get workoutStatusSwitchingCamera;

  /// No description provided for @workoutStatusSaving.
  ///
  /// In zh, this message translates to:
  /// **'保存中'**
  String get workoutStatusSaving;

  /// No description provided for @workoutStatusError.
  ///
  /// In zh, this message translates to:
  /// **'发生错误，请重试。'**
  String get workoutStatusError;

  /// No description provided for @workoutStatusSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试。'**
  String get workoutStatusSaveFailed;

  /// No description provided for @workoutCameraFront.
  ///
  /// In zh, this message translates to:
  /// **'前置'**
  String get workoutCameraFront;

  /// No description provided for @workoutCameraRear.
  ///
  /// In zh, this message translates to:
  /// **'后置'**
  String get workoutCameraRear;

  /// No description provided for @workoutCameraExternal.
  ///
  /// In zh, this message translates to:
  /// **'外接'**
  String get workoutCameraExternal;

  /// No description provided for @workoutCameraWide.
  ///
  /// In zh, this message translates to:
  /// **'广角摄像头'**
  String get workoutCameraWide;

  /// No description provided for @workoutCameraNormal.
  ///
  /// In zh, this message translates to:
  /// **'正常摄像头'**
  String get workoutCameraNormal;

  /// No description provided for @workoutCameraBackup.
  ///
  /// In zh, this message translates to:
  /// **'备用摄像头 {name}'**
  String workoutCameraBackup(String name);

  /// No description provided for @workoutCameraLabel.
  ///
  /// In zh, this message translates to:
  /// **'{direction}{type}'**
  String workoutCameraLabel(String direction, String type);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
