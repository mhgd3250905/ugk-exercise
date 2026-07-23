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
  String get startupSlogan => '架好手机，专心做好每一次。';

  @override
  String get onboardingCountTitle => 'AI 帮你数好每一次';

  @override
  String get onboardingCountBody => '自动识别俯卧撑动作、计数并语音播报，让你专注完成训练。';

  @override
  String get onboardingSetupTitle => '摆对手机，识别更稳定';

  @override
  String get onboardingSetupBody => '将手机固定在身体正前方，保持头、肩和手臂完整入镜，并预留动作空间。';

  @override
  String get onboardingPrivacyTitle => '相机画面只在本机处理';

  @override
  String get onboardingPrivacyBody => '原始画面不会上传。相机权限会在你开始训练时申请，也可以暂不授权。';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get profileTooltip => '个人信息';

  @override
  String get sportsPlazaTitle => '运动广场';

  @override
  String get sportsPlazaSubtitle => '俯卧撑积分日榜';

  @override
  String get sportsPlazaFreePrompt => '开通会员后参与运动广场排行';

  @override
  String get leaderboardErrorRequestFailed => '榜单暂时无法加载，请稍后重试。';

  @override
  String get leaderboardErrorUnexpected => '加载失败，请稍后重试。';

  @override
  String get leaderboardPremiumRequired => '需要 Premium 会员才能加入运动广场。';

  @override
  String get viewLeaderboard => '查看榜单';

  @override
  String get leaderboardDay => '日榜';

  @override
  String get leaderboardWeek => '周榜';

  @override
  String get leaderboardMyRank => '我的排名';

  @override
  String get leaderboardFrozenScoreTitle => '我的成绩已冻结';

  @override
  String get leaderboardFrozenScoreDescription => '会员已过期，续费后继续参与排名';

  @override
  String leaderboardRank(int rank) {
    return '第 $rank 名';
  }

  @override
  String get leaderboardPointsRule => '标准 1 分 · 窄距 2 分';

  @override
  String leaderboardMyExerciseCounts(int standardCount, int narrowCount) {
    return '标准 $standardCount 次 · 窄距 $narrowCount 次';
  }

  @override
  String leaderboardTotalPoints(int count) {
    return '$count 分';
  }

  @override
  String get leaderboardHomeRefreshing => '正在刷新排行榜';

  @override
  String get leaderboardEmpty => '暂无排行';

  @override
  String get leaderboardJoinPrompt => '加入运动广场后展示你的排名';

  @override
  String get leaderboardSignedOutPrompt => '登录后查看运动广场';

  @override
  String get leaderboardJoinAction => '加入广场';

  @override
  String get leaderboardLeaveAction => '退出榜单';

  @override
  String get leaderboardJoinDescription => '加入后，你的训练成绩会参与公开排名；可随时退出。';

  @override
  String get leaderboardJoinSuccess => '已加入运动广场';

  @override
  String get leaderboardLeaveConfirmTitle => '确认退出运动广场？';

  @override
  String get leaderboardLeaveConfirmDescription =>
      '退出后，新训练不再计入榜单；重新加入时，本周退出前的榜单统计不会恢复。';

  @override
  String get leaderboardLeaveCancel => '暂不退出';

  @override
  String get leaderboardLeaveConfirm => '确认退出';

  @override
  String get leaderboardLeaveSuccess => '已退出运动广场';

  @override
  String get leaderboardRetry => '重试';

  @override
  String get leaderboardIdentitySheetTitle => '选择你在运动广场中的身份';

  @override
  String get leaderboardIdentityProfile => '使用当前个人资料';

  @override
  String get leaderboardIdentityProfileDescription => '资料变化后，榜单会自动更新';

  @override
  String get leaderboardIdentityAnonymous => '匿名参加';

  @override
  String get leaderboardIdentityAnonymousDescription => '不会公开你的个人资料';

  @override
  String get leaderboardAnonymousName => '匿名训练者';

  @override
  String get leaderboardIdentityPreview => '公开预览';

  @override
  String get leaderboardIdentityCancel => '取消';

  @override
  String get leaderboardIdentityConfirmJoin => '确认加入';

  @override
  String get leaderboardIdentityConfirmEdit => '保存身份';

  @override
  String get leaderboardIdentityEdit => '编辑榜单身份';

  @override
  String get leaderboardIdentitySaveFailed => '身份保存失败，请稍后重试。';

  @override
  String get profileTitle => '个人信息';

  @override
  String get profileSettingsTooltip => '打开设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsBlockedUsers => '屏蔽名单';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsChinese => '中文';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsUpdateAvailable => '新版本可用';

  @override
  String get settingsUpdateOpenFailed => '无法打开 Google Play，请稍后重试。';

  @override
  String get appUpdateTitle => '发现新版本';

  @override
  String appUpdateVersionLabel(String version) {
    return 'PushupAI $version';
  }

  @override
  String get appUpdateReleaseNotesTitle => '本次更新';

  @override
  String get appUpdateLater => '稍后';

  @override
  String get appUpdateOpenStore => '前往更新';

  @override
  String get settingsRecognitionDiagnostics => '识别诊断';

  @override
  String get settingsRecognitionTraceTitle => '运动测试日志';

  @override
  String get settingsRecognitionTraceEnabled => '已开启';

  @override
  String get settingsRecognitionTraceDisabled => '已关闭';

  @override
  String get settingsRecognitionTraceDescription =>
      '仅保存在本机，包含姿态关键点和识别状态，不含照片、视频或音频。最多保留最近 20 次训练。';

  @override
  String get settingsRecognitionTraceSaveFailed => '无法保存运动测试日志设置，请重试';

  @override
  String get settingsRecognitionTraceExport => '导出运动测试日志';

  @override
  String get settingsRecognitionTraceExportDescription =>
      '保存为 JSONL 文件，连接电脑后可用于问题分析';

  @override
  String get settingsRecognitionTraceExported => '运动测试日志已导出';

  @override
  String get settingsRecognitionTraceNoLogs => '暂无可导出的运动测试日志';

  @override
  String get settingsRecognitionTraceTooLarge => '运动测试日志过大，无法安全导出';

  @override
  String get settingsRecognitionTraceExportFailed => '日志导出失败，请重试';

  @override
  String get blockedUsersTitle => '屏蔽名单';

  @override
  String get blockedUsersEmpty => '暂无已屏蔽用户';

  @override
  String get blockedUsersAnonymous => '匿名用户';

  @override
  String get blockedUsersUnblock => '解除屏蔽';

  @override
  String get blockedUsersLoadFailed => '无法加载屏蔽名单，请稍后重试。';

  @override
  String get blockedUsersUnblockFailed => '解除屏蔽失败，请重试。';

  @override
  String get blockedUsersRetry => '重试';

  @override
  String get editProfile => '编辑资料';

  @override
  String get editProfileSheetTitle => '编辑资料';

  @override
  String get profileNicknameLabel => '昵称';

  @override
  String get profileNicknameHint => '训练者 01';

  @override
  String get saveProfile => '保存';

  @override
  String get profileCustomAvatarTitle => '自定义头像';

  @override
  String get profileCustomAvatarDescription =>
      '自定义头像会优先显示；删除后恢复为内置头像或 Google 头像。';

  @override
  String get profileCustomAvatarGallery => '从相册选择';

  @override
  String get profileCustomAvatarCamera => '拍照';

  @override
  String get profileCustomAvatarUploading => '正在上传头像';

  @override
  String get profileCustomAvatarReplacing => '正在更换头像';

  @override
  String get profileCustomAvatarDelete => '删除自定义头像';

  @override
  String get profileCustomAvatarDeleteTitle => '删除自定义头像？';

  @override
  String get profileCustomAvatarDeleteMessage => '删除后将恢复显示你的备用头像。';

  @override
  String get profileCustomAvatarDeleteConfirm => '删除头像';

  @override
  String get profileCustomAvatarPolicyTitle => '自定义头像内容规范';

  @override
  String get profileCustomAvatarPolicyMessage =>
      '请勿上传裸露、暴力、仇恨、违法、冒充他人或垃圾广告内容。违规头像可能被移除，并暂停上传权限。';

  @override
  String get profileCustomAvatarPolicyAgree => '我确认头像符合内容规范';

  @override
  String get profileCustomAvatarPolicyContinue => '同意并继续';

  @override
  String get profileCustomAvatarUploadSuspended => '你的自定义头像上传权限已暂停。';

  @override
  String get profileCustomAvatarError => '头像操作失败，请稍后重试。';

  @override
  String get commonCancel => '取消';

  @override
  String get leaderboardActionsTitle => '用户操作';

  @override
  String get leaderboardLongPressHint => '长按可举报或屏蔽此用户';

  @override
  String get leaderboardRowExpandDetails => '点击查看运动明细';

  @override
  String get leaderboardRowCollapseDetails => '点击收起运动明细';

  @override
  String get leaderboardReportAvatar => '举报头像';

  @override
  String get leaderboardReportUser => '举报用户';

  @override
  String get leaderboardBlockUser => '屏蔽用户';

  @override
  String get leaderboardReportReasonTitle => '选择举报原因';

  @override
  String get leaderboardReportReasonNudity => '裸露内容';

  @override
  String get leaderboardReportReasonViolence => '暴力内容';

  @override
  String get leaderboardReportReasonHate => '仇恨内容';

  @override
  String get leaderboardReportReasonSpam => '垃圾广告';

  @override
  String get leaderboardReportReasonImpersonation => '冒充他人';

  @override
  String get leaderboardReportReasonOther => '其他违规';

  @override
  String get leaderboardReportSubmitting => '正在提交举报…';

  @override
  String get leaderboardReportSuccess => '已举报并屏蔽该用户';

  @override
  String get leaderboardBlockTitle => '屏蔽该用户？';

  @override
  String get leaderboardBlockMessage => '屏蔽后，你将不再在榜单中看到该用户。';

  @override
  String get leaderboardBlockConfirm => '确认屏蔽';

  @override
  String get leaderboardModerationFailed => '操作失败，请重试。';

  @override
  String get profileErrorInvalidNickname =>
      '昵称需为 2–16 个字符，只能包含中英文字母、数字、空格、下划线或连字符。';

  @override
  String get profileErrorInvalidAvatar => '所选头像无效，请重新选择。';

  @override
  String get profileErrorNicknameTaken => '该昵称已被使用，请换一个。';

  @override
  String get profileErrorNicknameCooldown => '昵称每 30 天只能修改一次。你仍可单独更换头像。';

  @override
  String get accountErrorPurchaseFailed => '购买没有完成，请稍后再试。';

  @override
  String get accountErrorRequestFailed => '服务暂时不可用，请稍后再试。';

  @override
  String get membershipSyncUnavailable => '会员权益同步失败，请稍后重试。';

  @override
  String get accountErrorUnexpected => '操作失败，请稍后再试。';

  @override
  String get profileAnonymousName => '训练者';

  @override
  String get profileSignedOutTitle => '您尚未登录';

  @override
  String get profileSignedOutSubtitle => '登录后使用账号与会员功能';

  @override
  String get profileSignedInFallback => '已登录';

  @override
  String get profileLocalTrainingData => '本机训练数据';

  @override
  String get profileSignInWithGoogle => '使用 Google 登录';

  @override
  String get profileSigningIn => '正在登录…';

  @override
  String get profileSigningInDescription => '正在验证账号与会员状态，请稍候。';

  @override
  String get profileAccountSyncing => '正在同步账号信息';

  @override
  String get profileMembershipSyncing => '正在同步会员状态';

  @override
  String get profileSubscribePremium => '开通会员';

  @override
  String get profileRestorePurchases => '恢复会员权益';

  @override
  String get profileRestorePurchasesDescription => '重装或换设备后找回已购买会员';

  @override
  String get profileManageSubscription => '管理 Google Play 订阅';

  @override
  String get profileManageSubscriptionDescription => '查看、取消或重新订阅。';

  @override
  String get profileManageSubscriptionOpenFailed =>
      '无法打开 Google Play 订阅管理，请稍后重试。';

  @override
  String get profileSignOut => '退出登录';

  @override
  String get profileSignOutConfirmTitle => '退出登录？';

  @override
  String get profileSignOutConfirmMessage => '退出后，你可以随时使用 Google 账号重新登录。';

  @override
  String get profileAccountDeletion => '隐私政策与账号删除';

  @override
  String get profileAccountDeletionOpenFailed => '无法打开账号删除页面，请稍后重试。';

  @override
  String get profileMembershipActive => '会员已开通。高级功能会在本账号下生效。';

  @override
  String get profileMembershipInactive => '当前未开通会员。本机训练仍可正常使用。';

  @override
  String get profileSyncLocalHistory => '同步本机历史';

  @override
  String get profileSyncLocalHistoryTitle => '同步本机历史？';

  @override
  String get profileSyncLocalHistoryMessage =>
      '这会将本机尚未归属账号的训练记录绑定到当前账号，并上传至云端。绑定后不能改到其他账号。';

  @override
  String get profileSyncLocalHistoryCancel => '取消';

  @override
  String get profileSyncLocalHistoryConfirm => '确认同步';

  @override
  String get profilePremiumTitle => 'PushupAI 会员';

  @override
  String get profilePremiumSubtitle => '会员权益绑定当前账号';

  @override
  String get profilePremiumBenefitRestore => 'Google 账号登录后，会员状态可恢复';

  @override
  String get profilePremiumBenefitAttribution => '后续高级训练功能自动归属本账号';

  @override
  String get profilePremiumMonthly => '月度会员';

  @override
  String get profilePremiumAnnual => '年度会员';

  @override
  String get profilePremiumRecommended => '推荐';

  @override
  String profilePremiumMonthlyPrice(String price) {
    return '$price / 月';
  }

  @override
  String profilePremiumAnnualPrice(String price) {
    return '$price / 年';
  }

  @override
  String profilePremiumTrialBadge(int days) {
    return '免费 $days 天';
  }

  @override
  String profilePremiumAfterTrialMonthlyPrice(String price) {
    return '试用后 $price / 月';
  }

  @override
  String profilePremiumAfterTrialAnnualPrice(String price) {
    return '试用后 $price / 年';
  }

  @override
  String profilePremiumTrialRenewal(int days, String price) {
    return '前 $days 天免费，之后按 $price / 月通过 Google Play 自动续费，除非提前取消。';
  }

  @override
  String profilePremiumAnnualTrialRenewal(int days, String price) {
    return '前 $days 天免费，之后按 $price / 年通过 Google Play 自动续费，除非提前取消。';
  }

  @override
  String profilePremiumStartTrial(int days) {
    return '开始 $days 天免费试用';
  }

  @override
  String get profilePremiumPlansUnavailable => '暂时无法加载会员套餐。';

  @override
  String get profilePremiumRetry => '重试';

  @override
  String get profilePremiumAutoRenewal => '订阅将通过 Google Play 自动续费，可随时取消。';

  @override
  String get profilePremiumContinue => '继续开通';

  @override
  String get profilePremiumLater => '稍后再说';

  @override
  String get profileAvatarRingGreen => '绿色圆环头像';

  @override
  String get profileAvatarRingLime => '黄绿色圆环头像';

  @override
  String get profileAvatarRingSky => '天蓝色圆环头像';

  @override
  String get profileAvatarRingYellow => '黄色圆环头像';

  @override
  String get profileAvatarRingCoral => '珊瑚色圆环头像';

  @override
  String get profileAvatarBoltGreen => '绿色闪电头像';

  @override
  String get profileAvatarBoltLime => '黄绿色闪电头像';

  @override
  String get profileAvatarBoltSky => '天蓝色闪电头像';

  @override
  String get testMode => '测试模式';

  @override
  String todayCount(int count) {
    return '今日 $count';
  }

  @override
  String get pushupTraining => '俯卧撑训练';

  @override
  String exerciseSummary(int todayCount) {
    return 'AI 姿态识别 · 自动计数 · 中文播报\n今日已完成 $todayCount 次';
  }

  @override
  String get narrowPushupTraining => '窄距俯卧撑';

  @override
  String get exerciseDifficultyOne => '难度 I';

  @override
  String get exerciseDifficultyTwo => '难度 II';

  @override
  String get startTraining => '开始训练';

  @override
  String get recordsTitle => '训练记录';

  @override
  String get recordsModeWeek => '周';

  @override
  String get recordsModeMonth => '月';

  @override
  String get recordsModeYear => '年';

  @override
  String recordsWeekTitle(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日–$endMonth月$endDay日';
  }

  @override
  String recordsYearTitle(int year) {
    return '$year年';
  }

  @override
  String recordsMonthTitle(int year, int month) {
    return '$year年$month月';
  }

  @override
  String get recordsWeekdaySun => '日';

  @override
  String get recordsWeekdayMon => '一';

  @override
  String get recordsWeekdayTue => '二';

  @override
  String get recordsWeekdayWed => '三';

  @override
  String get recordsWeekdayThu => '四';

  @override
  String get recordsWeekdayFri => '五';

  @override
  String get recordsWeekdaySat => '六';

  @override
  String get recordsTrainingDays => '训练天数';

  @override
  String get recordsTotalCount => '总个数';

  @override
  String get recordsBestDay => '最高单日';

  @override
  String recordsDaysValue(int count) {
    return '$count 天';
  }

  @override
  String recordsRepsValue(int count) {
    return '$count 个';
  }

  @override
  String get recordsCloudLoading => '正在读取云端记录';

  @override
  String get recordsCloudMerged => '云端记录已合并';

  @override
  String get recordsCloudUnavailable => '云端记录暂不可用，本地记录已显示';

  @override
  String recordsPendingSyncCount(int count) {
    return '有 $count 条记录待同步';
  }

  @override
  String get workoutPreparing => '准备中';

  @override
  String get workoutCameraNoticeTitle => '相机与端侧处理';

  @override
  String get workoutCameraNoticeBody =>
      '训练时，相机画面仅在本机用于姿态识别和计数，原始画面不会上传至我们的服务器。';

  @override
  String get workoutCameraNoticeStart => '我知道了，开始训练';

  @override
  String get workoutCameraNoticeCancel => '暂不使用相机';

  @override
  String get workoutCameraPermissionDenied => '需要相机权限才能识别动作。请允许权限后重新进入训练。';

  @override
  String get workoutCameraPermissionSettings => '相机权限已关闭，请前往系统设置开启后重试。';

  @override
  String get workoutReady => '已准备';

  @override
  String get workoutStartingCamera => '正在启动相机';

  @override
  String get workoutSavingTraining => '正在保存训练';

  @override
  String get workoutSelectCamera => '选择摄像头';

  @override
  String get workoutCameraLoading => '相机加载中';

  @override
  String get workoutEnd => '结束训练';

  @override
  String get workoutRetrySave => '重试保存';

  @override
  String get workoutTodayGoal => '今日目标';

  @override
  String workoutGoalValue(int count) {
    return '$count 个';
  }

  @override
  String get workoutBurned => '消耗';

  @override
  String workoutCaloriesValue(int count) {
    return '$count 千卡';
  }

  @override
  String get workoutCountUnit => '个';

  @override
  String get workoutStatusLoading => '加载中';

  @override
  String get workoutStatusLoadingModel => '加载模型';

  @override
  String get workoutStatusStartingCamera => '启动相机';

  @override
  String get workoutStatusPositionGuide => '请按指引调整姿势并稳定入镜';

  @override
  String get workoutStatusReady => '已准备好，请开始训练';

  @override
  String get workoutStatusHoldPose => '请对齐指引并保持姿势';

  @override
  String get workoutStatusNarrowForm => '收拢双臂，手腕再靠近一点';

  @override
  String get workoutStatusTooClose => '距离过近，请退后一点点';

  @override
  String get workoutStatusReacquiringPose => '姿势已中断，请按指引重新准备。';

  @override
  String get workoutStatusTraining => '训练中';

  @override
  String get workoutStatusSwitchingCamera => '切换相机';

  @override
  String get workoutStatusSaving => '保存中';

  @override
  String get workoutStatusError => '发生错误，请重试。';

  @override
  String get workoutStatusStartupError => '训练启动失败，请重试。';

  @override
  String get workoutStatusCameraError => '相机发生错误，请重试。';

  @override
  String get workoutStatusFrameError => '识别发生错误，请重试。';

  @override
  String get workoutStatusSaveFailed => '保存失败，请重试。';

  @override
  String get workoutCameraFront => '前置';

  @override
  String get workoutCameraRear => '后置';

  @override
  String get workoutCameraExternal => '外接';

  @override
  String get workoutCameraWide => '广角摄像头';

  @override
  String get workoutCameraNormal => '正常摄像头';

  @override
  String workoutCameraBackup(String name) {
    return '备用摄像头 $name';
  }

  @override
  String workoutCameraLabel(String direction, String type) {
    return '$direction$type';
  }
}
