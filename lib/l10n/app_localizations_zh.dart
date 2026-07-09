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
}
