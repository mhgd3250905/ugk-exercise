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
  String get sportsPlazaTitle => '运动广场';

  @override
  String get sportsPlazaSubtitle => '俯卧撑项目日榜';

  @override
  String get viewLeaderboard => '查看榜单';

  @override
  String get leaderboardDay => '日榜';

  @override
  String get leaderboardWeek => '周榜';

  @override
  String get leaderboardMyRank => '我的排名';

  @override
  String leaderboardRank(int rank) {
    return '第 $rank 名';
  }

  @override
  String leaderboardTotalReps(int count) {
    return '$count 次';
  }

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
  String get leaderboardRetry => '重试';

  @override
  String get profileTitle => '个人信息';

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
  String get accountErrorUnexpected => '操作失败，请稍后再试。';

  @override
  String get profileAnonymousName => '训练者';

  @override
  String get profileSignedInFallback => '已登录';

  @override
  String get profileLocalTrainingData => '本机训练数据';

  @override
  String get profileSignInWithGoogle => '使用 Google 登录';

  @override
  String get profileSubscribePremium => '开通会员';

  @override
  String get profileRestorePurchases => '恢复购买';

  @override
  String get profileSignOut => '退出登录';

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
  String get profilePremiumTitle => 'UGK Premium';

  @override
  String get profilePremiumSubtitle => '会员权益绑定当前账号';

  @override
  String get profilePremiumBenefitRestore => 'Google 账号登录后，会员状态可恢复';

  @override
  String get profilePremiumBenefitAttribution => '后续高级训练功能自动归属本账号';

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

  @override
  String get recordsTitle => '训练记录';

  @override
  String get recordsModeWeek => '周';

  @override
  String get recordsModeMonth => '月';

  @override
  String get recordsModeYear => '年';

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
}
