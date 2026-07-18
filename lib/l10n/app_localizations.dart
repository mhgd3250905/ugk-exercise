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

  /// Brand slogan shown while the app starts.
  ///
  /// In zh, this message translates to:
  /// **'架好手机，专心做好每一次。'**
  String get startupSlogan;

  /// No description provided for @onboardingCountTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 帮你数好每一次'**
  String get onboardingCountTitle;

  /// No description provided for @onboardingCountBody.
  ///
  /// In zh, this message translates to:
  /// **'自动识别俯卧撑动作、计数并语音播报，让你专注完成训练。'**
  String get onboardingCountBody;

  /// No description provided for @onboardingSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'摆对手机，识别更稳定'**
  String get onboardingSetupTitle;

  /// No description provided for @onboardingSetupBody.
  ///
  /// In zh, this message translates to:
  /// **'将手机固定在身体正前方，保持头、肩和手臂完整入镜，并预留动作空间。'**
  String get onboardingSetupBody;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'相机画面只在本机处理'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyBody.
  ///
  /// In zh, this message translates to:
  /// **'原始画面不会上传。相机权限会在你开始训练时申请，也可以暂不授权。'**
  String get onboardingPrivacyBody;

  /// No description provided for @onboardingSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get onboardingStart;

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

  /// Title for the private score card shown to an expired leaderboard member.
  ///
  /// In zh, this message translates to:
  /// **'我的成绩已冻结'**
  String get leaderboardFrozenScoreTitle;

  /// Explanation shown only to an expired leaderboard member whose score is frozen.
  ///
  /// In zh, this message translates to:
  /// **'会员已过期，续费后继续参与排名'**
  String get leaderboardFrozenScoreDescription;

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

  /// No description provided for @leaderboardJoinDescription.
  ///
  /// In zh, this message translates to:
  /// **'加入后，你的训练成绩会参与公开排名；可随时退出。'**
  String get leaderboardJoinDescription;

  /// No description provided for @leaderboardJoinSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已加入运动广场'**
  String get leaderboardJoinSuccess;

  /// No description provided for @leaderboardLeaveConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出运动广场？'**
  String get leaderboardLeaveConfirmTitle;

  /// No description provided for @leaderboardLeaveConfirmDescription.
  ///
  /// In zh, this message translates to:
  /// **'退出后，新训练不再计入榜单；重新加入时，本周退出前的榜单统计不会恢复。'**
  String get leaderboardLeaveConfirmDescription;

  /// No description provided for @leaderboardLeaveCancel.
  ///
  /// In zh, this message translates to:
  /// **'暂不退出'**
  String get leaderboardLeaveCancel;

  /// No description provided for @leaderboardLeaveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get leaderboardLeaveConfirm;

  /// No description provided for @leaderboardLeaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已退出运动广场'**
  String get leaderboardLeaveSuccess;

  /// Button label to retry loading leaderboard data.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get leaderboardRetry;

  /// No description provided for @leaderboardIdentitySheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择你在运动广场中的身份'**
  String get leaderboardIdentitySheetTitle;

  /// No description provided for @leaderboardIdentityProfile.
  ///
  /// In zh, this message translates to:
  /// **'使用当前个人资料'**
  String get leaderboardIdentityProfile;

  /// No description provided for @leaderboardIdentityProfileDescription.
  ///
  /// In zh, this message translates to:
  /// **'资料变化后，榜单会自动更新'**
  String get leaderboardIdentityProfileDescription;

  /// No description provided for @leaderboardIdentityAnonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名参加'**
  String get leaderboardIdentityAnonymous;

  /// No description provided for @leaderboardIdentityAnonymousDescription.
  ///
  /// In zh, this message translates to:
  /// **'不会公开你的个人资料'**
  String get leaderboardIdentityAnonymousDescription;

  /// No description provided for @leaderboardAnonymousName.
  ///
  /// In zh, this message translates to:
  /// **'匿名训练者'**
  String get leaderboardAnonymousName;

  /// No description provided for @leaderboardIdentityPreview.
  ///
  /// In zh, this message translates to:
  /// **'公开预览'**
  String get leaderboardIdentityPreview;

  /// No description provided for @leaderboardIdentityCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get leaderboardIdentityCancel;

  /// No description provided for @leaderboardIdentityConfirmJoin.
  ///
  /// In zh, this message translates to:
  /// **'确认加入'**
  String get leaderboardIdentityConfirmJoin;

  /// No description provided for @leaderboardIdentityConfirmEdit.
  ///
  /// In zh, this message translates to:
  /// **'保存身份'**
  String get leaderboardIdentityConfirmEdit;

  /// No description provided for @leaderboardIdentityEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑榜单身份'**
  String get leaderboardIdentityEdit;

  /// No description provided for @leaderboardIdentitySaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'身份保存失败，请稍后重试。'**
  String get leaderboardIdentitySaveFailed;

  /// Title for the profile page.
  ///
  /// In zh, this message translates to:
  /// **'个人信息'**
  String get profileTitle;

  /// No description provided for @profileSettingsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'打开设置'**
  String get profileSettingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get settingsAccount;

  /// No description provided for @settingsBlockedUsers.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽名单'**
  String get settingsBlockedUsers;

  /// No description provided for @settingsSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsSystem;

  /// No description provided for @settingsChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsChinese;

  /// No description provided for @settingsEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// No description provided for @settingsLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsDark;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'新版本可用'**
  String get settingsUpdateAvailable;

  /// No description provided for @settingsUpdateOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开 Google Play，请稍后重试。'**
  String get settingsUpdateOpenFailed;

  /// No description provided for @settingsRecognitionDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'识别诊断'**
  String get settingsRecognitionDiagnostics;

  /// No description provided for @settingsRecognitionTraceTitle.
  ///
  /// In zh, this message translates to:
  /// **'运动测试日志'**
  String get settingsRecognitionTraceTitle;

  /// No description provided for @settingsRecognitionTraceEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get settingsRecognitionTraceEnabled;

  /// No description provided for @settingsRecognitionTraceDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get settingsRecognitionTraceDisabled;

  /// No description provided for @settingsRecognitionTraceDescription.
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，包含姿态关键点和识别状态，不含照片、视频或音频。最多保留最近 20 次训练。'**
  String get settingsRecognitionTraceDescription;

  /// No description provided for @settingsRecognitionTraceSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法保存运动测试日志设置，请重试'**
  String get settingsRecognitionTraceSaveFailed;

  /// No description provided for @settingsRecognitionTraceExport.
  ///
  /// In zh, this message translates to:
  /// **'导出运动测试日志'**
  String get settingsRecognitionTraceExport;

  /// No description provided for @settingsRecognitionTraceExportDescription.
  ///
  /// In zh, this message translates to:
  /// **'保存为 JSONL 文件，连接电脑后可用于问题分析'**
  String get settingsRecognitionTraceExportDescription;

  /// No description provided for @settingsRecognitionTraceExported.
  ///
  /// In zh, this message translates to:
  /// **'运动测试日志已导出'**
  String get settingsRecognitionTraceExported;

  /// No description provided for @settingsRecognitionTraceNoLogs.
  ///
  /// In zh, this message translates to:
  /// **'暂无可导出的运动测试日志'**
  String get settingsRecognitionTraceNoLogs;

  /// No description provided for @settingsRecognitionTraceTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'运动测试日志过大，无法安全导出'**
  String get settingsRecognitionTraceTooLarge;

  /// No description provided for @settingsRecognitionTraceExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'日志导出失败，请重试'**
  String get settingsRecognitionTraceExportFailed;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽名单'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无已屏蔽用户'**
  String get blockedUsersEmpty;

  /// No description provided for @blockedUsersAnonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名用户'**
  String get blockedUsersAnonymous;

  /// No description provided for @blockedUsersUnblock.
  ///
  /// In zh, this message translates to:
  /// **'解除屏蔽'**
  String get blockedUsersUnblock;

  /// No description provided for @blockedUsersLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载屏蔽名单，请稍后重试。'**
  String get blockedUsersLoadFailed;

  /// No description provided for @blockedUsersUnblockFailed.
  ///
  /// In zh, this message translates to:
  /// **'解除屏蔽失败，请重试。'**
  String get blockedUsersUnblockFailed;

  /// No description provided for @blockedUsersRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get blockedUsersRetry;

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

  /// No description provided for @profileCustomAvatarTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义头像'**
  String get profileCustomAvatarTitle;

  /// No description provided for @profileCustomAvatarDescription.
  ///
  /// In zh, this message translates to:
  /// **'自定义头像会优先显示；删除后恢复为内置头像或 Google 头像。'**
  String get profileCustomAvatarDescription;

  /// No description provided for @profileCustomAvatarGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get profileCustomAvatarGallery;

  /// No description provided for @profileCustomAvatarCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get profileCustomAvatarCamera;

  /// No description provided for @profileCustomAvatarUploading.
  ///
  /// In zh, this message translates to:
  /// **'正在上传头像'**
  String get profileCustomAvatarUploading;

  /// No description provided for @profileCustomAvatarReplacing.
  ///
  /// In zh, this message translates to:
  /// **'正在更换头像'**
  String get profileCustomAvatarReplacing;

  /// No description provided for @profileCustomAvatarDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除自定义头像'**
  String get profileCustomAvatarDelete;

  /// No description provided for @profileCustomAvatarDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除自定义头像？'**
  String get profileCustomAvatarDeleteTitle;

  /// No description provided for @profileCustomAvatarDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'删除后将恢复显示你的备用头像。'**
  String get profileCustomAvatarDeleteMessage;

  /// No description provided for @profileCustomAvatarDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除头像'**
  String get profileCustomAvatarDeleteConfirm;

  /// No description provided for @profileCustomAvatarPolicyTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义头像内容规范'**
  String get profileCustomAvatarPolicyTitle;

  /// No description provided for @profileCustomAvatarPolicyMessage.
  ///
  /// In zh, this message translates to:
  /// **'请勿上传裸露、暴力、仇恨、违法、冒充他人或垃圾广告内容。违规头像可能被移除，并暂停上传权限。'**
  String get profileCustomAvatarPolicyMessage;

  /// No description provided for @profileCustomAvatarPolicyAgree.
  ///
  /// In zh, this message translates to:
  /// **'我确认头像符合内容规范'**
  String get profileCustomAvatarPolicyAgree;

  /// No description provided for @profileCustomAvatarPolicyContinue.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get profileCustomAvatarPolicyContinue;

  /// No description provided for @profileCustomAvatarUploadSuspended.
  ///
  /// In zh, this message translates to:
  /// **'你的自定义头像上传权限已暂停。'**
  String get profileCustomAvatarUploadSuspended;

  /// No description provided for @profileCustomAvatarError.
  ///
  /// In zh, this message translates to:
  /// **'头像操作失败，请稍后重试。'**
  String get profileCustomAvatarError;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @leaderboardActionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户操作'**
  String get leaderboardActionsTitle;

  /// No description provided for @leaderboardLongPressHint.
  ///
  /// In zh, this message translates to:
  /// **'长按可举报或屏蔽此用户'**
  String get leaderboardLongPressHint;

  /// No description provided for @leaderboardReportAvatar.
  ///
  /// In zh, this message translates to:
  /// **'举报头像'**
  String get leaderboardReportAvatar;

  /// No description provided for @leaderboardReportUser.
  ///
  /// In zh, this message translates to:
  /// **'举报用户'**
  String get leaderboardReportUser;

  /// No description provided for @leaderboardBlockUser.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽用户'**
  String get leaderboardBlockUser;

  /// No description provided for @leaderboardReportReasonTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择举报原因'**
  String get leaderboardReportReasonTitle;

  /// No description provided for @leaderboardReportReasonNudity.
  ///
  /// In zh, this message translates to:
  /// **'裸露内容'**
  String get leaderboardReportReasonNudity;

  /// No description provided for @leaderboardReportReasonViolence.
  ///
  /// In zh, this message translates to:
  /// **'暴力内容'**
  String get leaderboardReportReasonViolence;

  /// No description provided for @leaderboardReportReasonHate.
  ///
  /// In zh, this message translates to:
  /// **'仇恨内容'**
  String get leaderboardReportReasonHate;

  /// No description provided for @leaderboardReportReasonSpam.
  ///
  /// In zh, this message translates to:
  /// **'垃圾广告'**
  String get leaderboardReportReasonSpam;

  /// No description provided for @leaderboardReportReasonImpersonation.
  ///
  /// In zh, this message translates to:
  /// **'冒充他人'**
  String get leaderboardReportReasonImpersonation;

  /// No description provided for @leaderboardReportReasonOther.
  ///
  /// In zh, this message translates to:
  /// **'其他违规'**
  String get leaderboardReportReasonOther;

  /// No description provided for @leaderboardReportSubmitting.
  ///
  /// In zh, this message translates to:
  /// **'正在提交举报…'**
  String get leaderboardReportSubmitting;

  /// No description provided for @leaderboardReportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已举报并屏蔽该用户'**
  String get leaderboardReportSuccess;

  /// No description provided for @leaderboardBlockTitle.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽该用户？'**
  String get leaderboardBlockTitle;

  /// No description provided for @leaderboardBlockMessage.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽后，你将不再在榜单中看到该用户。'**
  String get leaderboardBlockMessage;

  /// No description provided for @leaderboardBlockConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认屏蔽'**
  String get leaderboardBlockConfirm;

  /// No description provided for @leaderboardModerationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请重试。'**
  String get leaderboardModerationFailed;

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

  /// Shown when the server cannot verify current membership with RevenueCat.
  ///
  /// In zh, this message translates to:
  /// **'会员权益同步失败，请稍后重试。'**
  String get membershipSyncUnavailable;

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

  /// No description provided for @profileSignedOutTitle.
  ///
  /// In zh, this message translates to:
  /// **'您尚未登录'**
  String get profileSignedOutTitle;

  /// No description provided for @profileSignedOutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录后使用账号与会员功能'**
  String get profileSignedOutSubtitle;

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

  /// Status shown while Google account authentication is in progress.
  ///
  /// In zh, this message translates to:
  /// **'正在登录…'**
  String get profileSigningIn;

  /// Explains the network work performed during sign-in.
  ///
  /// In zh, this message translates to:
  /// **'正在验证账号与会员状态，请稍候。'**
  String get profileSigningInDescription;

  /// Accessibility label for the subtle account sync indicator.
  ///
  /// In zh, this message translates to:
  /// **'正在同步账号信息'**
  String get profileAccountSyncing;

  /// Button label to start premium purchase.
  ///
  /// In zh, this message translates to:
  /// **'开通会员'**
  String get profileSubscribePremium;

  /// Button label to restore purchases.
  ///
  /// In zh, this message translates to:
  /// **'恢复会员权益'**
  String get profileRestorePurchases;

  /// Explains when restoring purchases is useful.
  ///
  /// In zh, this message translates to:
  /// **'重装或换设备后找回已购买会员'**
  String get profileRestorePurchasesDescription;

  /// Button label to sign out.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get profileSignOut;

  /// Title of the sign-out confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'退出登录？'**
  String get profileSignOutConfirmTitle;

  /// Message in the sign-out confirmation dialog.
  ///
  /// In zh, this message translates to:
  /// **'退出后，你可以随时使用 Google 账号重新登录。'**
  String get profileSignOutConfirmMessage;

  /// Button label that opens the public account deletion page.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策与账号删除'**
  String get profileAccountDeletion;

  /// Error shown when the public account deletion page cannot be opened.
  ///
  /// In zh, this message translates to:
  /// **'无法打开账号删除页面，请稍后重试。'**
  String get profileAccountDeletionOpenFailed;

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
  /// **'PushupAI 会员'**
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

  /// Monthly premium plan title.
  ///
  /// In zh, this message translates to:
  /// **'月度会员'**
  String get profilePremiumMonthly;

  /// Annual premium plan title.
  ///
  /// In zh, this message translates to:
  /// **'年度会员'**
  String get profilePremiumAnnual;

  /// Badge for the recommended premium plan.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get profilePremiumRecommended;

  /// Store-localized monthly premium price.
  ///
  /// In zh, this message translates to:
  /// **'{price} / 月'**
  String profilePremiumMonthlyPrice(String price);

  /// Store-localized annual premium price.
  ///
  /// In zh, this message translates to:
  /// **'{price} / 年'**
  String profilePremiumAnnualPrice(String price);

  /// Shown when RevenueCat returns no purchasable premium plans.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法加载会员套餐。'**
  String get profilePremiumPlansUnavailable;

  /// Retries loading premium plans.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get profilePremiumRetry;

  /// Auto-renewal disclosure on the premium sheet.
  ///
  /// In zh, this message translates to:
  /// **'订阅将通过 Google Play 自动续费，可随时取消。'**
  String get profilePremiumAutoRenewal;

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

  /// Narrow pushup workout card title.
  ///
  /// In zh, this message translates to:
  /// **'窄距俯卧撑'**
  String get narrowPushupTraining;

  /// Home workout card summary text.
  ///
  /// In zh, this message translates to:
  /// **'AI 姿态识别 · 自动计数 · 中文播报\n今日已完成 {todayCount} 次'**
  String exerciseSummary(int todayCount);

  /// Home narrow pushup card summary text.
  ///
  /// In zh, this message translates to:
  /// **'收拢双臂 · 顶部形态验证 · 自动计数\n今日已完成 {todayCount} 次'**
  String narrowExerciseSummary(int todayCount);

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

  /// Current week date range on the records page.
  ///
  /// In zh, this message translates to:
  /// **'{startMonth}月{startDay}日–{endMonth}月{endDay}日'**
  String recordsWeekTitle(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  );

  /// Current year title on the records page.
  ///
  /// In zh, this message translates to:
  /// **'{year}年'**
  String recordsYearTitle(int year);

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

  /// No description provided for @workoutCameraNoticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'相机与端侧处理'**
  String get workoutCameraNoticeTitle;

  /// No description provided for @workoutCameraNoticeBody.
  ///
  /// In zh, this message translates to:
  /// **'训练时，相机画面仅在本机用于姿态识别和计数，原始画面不会上传至我们的服务器。'**
  String get workoutCameraNoticeBody;

  /// No description provided for @workoutCameraNoticeStart.
  ///
  /// In zh, this message translates to:
  /// **'我知道了，开始训练'**
  String get workoutCameraNoticeStart;

  /// No description provided for @workoutCameraNoticeCancel.
  ///
  /// In zh, this message translates to:
  /// **'暂不使用相机'**
  String get workoutCameraNoticeCancel;

  /// No description provided for @workoutCameraPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'需要相机权限才能识别动作。请允许权限后重新进入训练。'**
  String get workoutCameraPermissionDenied;

  /// No description provided for @workoutCameraPermissionSettings.
  ///
  /// In zh, this message translates to:
  /// **'相机权限已关闭，请前往系统设置开启后重试。'**
  String get workoutCameraPermissionSettings;

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

  /// No description provided for @workoutStatusNarrowForm.
  ///
  /// In zh, this message translates to:
  /// **'收拢双臂，保持两侧手腕不比肩膀更向外'**
  String get workoutStatusNarrowForm;

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

  /// No description provided for @workoutStatusStartupError.
  ///
  /// In zh, this message translates to:
  /// **'训练启动失败，请重试。'**
  String get workoutStatusStartupError;

  /// No description provided for @workoutStatusCameraError.
  ///
  /// In zh, this message translates to:
  /// **'相机发生错误，请重试。'**
  String get workoutStatusCameraError;

  /// No description provided for @workoutStatusFrameError.
  ///
  /// In zh, this message translates to:
  /// **'识别发生错误，请重试。'**
  String get workoutStatusFrameError;

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
