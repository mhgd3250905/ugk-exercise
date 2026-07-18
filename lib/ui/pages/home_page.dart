// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../control/account_controller.dart';
import '../../control/leaderboard_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/avatar_image_service.dart';
import '../../product/leaderboard_models.dart';
import '../../product/membership_status.dart';
import '../../product/exercise_type.dart';
import '../../product/workout_session_store.dart';
import '../app_settings.dart';
import '../app_theme.dart';
import '../page_navigation.dart';
import '../profile_avatar.dart';
import '../user_avatar.dart';
import 'leaderboard_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'workout_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settingsController,
    required this.accountController,
    this.leaderboardController,
    this.syncController,
    this.avatarImageService,
    this.cloudSessionsLoader,
    this.workoutSessionStore,
    this.cameraNoticeAcknowledged,
    this.acknowledgeCameraNotice,
  });

  final AppSettingsController settingsController;
  final AccountController accountController;
  final LeaderboardController? leaderboardController;
  final WorkoutSyncController? syncController;
  final AvatarImageService? avatarImageService;
  final Future<List<WorkoutSession>> Function(String month)?
  cloudSessionsLoader;
  final WorkoutSessionStore? workoutSessionStore;
  final Future<bool> Function()? cameraNoticeAcknowledged;
  final Future<void> Function()? acknowledgeCameraNotice;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _store = widget.workoutSessionStore ?? WorkoutSessionStore();
  late final AppLifecycleListener _lifecycleListener;
  var _todayTotal = 0;
  var _todayPushup = 0;
  var _todayNarrowPushup = 0;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(widget.accountController.refresh()),
    );
    widget.accountController.addListener(_handleAccountChange);
    unawaited(_refreshTodayTotal());
  }

  @override
  void dispose() {
    widget.accountController.removeListener(_handleAccountChange);
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _handleAccountChange() {
    if (!widget.accountController.busy) {
      unawaited(_refreshTodayTotal());
    }
  }

  Future<void> _refreshTodayTotal() async {
    final ownerAppUserId = widget.accountController.currentSession?.appUserId;
    final today = DateTime.now();
    final totals = await Future.wait([
      _store.totalForLocalDate(today, ownerAppUserId: ownerAppUserId),
      _store.totalForLocalDate(
        today,
        ownerAppUserId: ownerAppUserId,
        exerciseType: ExerciseType.pushup.storageValue,
      ),
      _store.totalForLocalDate(
        today,
        ownerAppUserId: ownerAppUserId,
        exerciseType: ExerciseType.narrowPushup.storageValue,
      ),
    ]);
    if (!mounted ||
        ownerAppUserId != widget.accountController.currentSession?.appUserId) {
      return;
    }
    setState(() {
      _todayTotal = totals[0];
      _todayPushup = totals[1];
      _todayNarrowPushup = totals[2];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? darkHomeGradientTop : homeGradientTop,
              isDark ? darkHomeGradientBottom : homeGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ListenableBuilder(
                      listenable: widget.accountController,
                      builder: (context, _) => _ProfileButton(
                        premium: widget.accountController.premium,
                        user: widget.accountController.user,
                        tooltip: l10n.profileTooltip,
                        onPressed: () {
                          pushWithoutShadow(
                            context,
                            (_) => ProfilePage(
                              settingsController: widget.settingsController,
                              controller: widget.accountController,
                              syncController: widget.syncController,
                              leaderboardController:
                                  widget.leaderboardController,
                              avatarImageService: widget.avatarImageService,
                            ),
                            // Avatar sits on the left → enter from the left.
                            direction: PageEnterDirection.left,
                          );
                        },
                      ),
                    ),
                    _TodayButton(
                      count: _todayTotal,
                      onPressed: () async {
                        await pushWithoutShadow(
                          context,
                          (_) => RecordsPage(
                            store: _store,
                            ownerAppUserId: widget
                                .accountController
                                .currentSession
                                ?.appUserId,
                            cloudSessionsFuture: _cloudSessionsFuture(),
                            pendingSyncCountFuture: _pendingSyncCountFuture(),
                          ),
                        );
                        await _refreshTodayTotal();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ExerciseCard(
                  exerciseType: ExerciseType.pushup,
                  todayCount: _todayPushup,
                  onPressed: () async {
                    await pushWithoutShadow(
                      context,
                      (_) => WorkoutPage(
                        store: _store,
                        exerciseType: ExerciseType.pushup,
                        recognitionTraceEnabled:
                            widget.settingsController.recognitionTraceEnabled,
                        syncController: widget.syncController,
                        cameraNoticeAcknowledged:
                            widget.cameraNoticeAcknowledged,
                        acknowledgeCameraNotice: widget.acknowledgeCameraNotice,
                      ),
                    );
                    await _refreshTodayTotal();
                  },
                ),
                const SizedBox(height: 14),
                _ExerciseCard(
                  exerciseType: ExerciseType.narrowPushup,
                  todayCount: _todayNarrowPushup,
                  onPressed: () async {
                    await pushWithoutShadow(
                      context,
                      (_) => WorkoutPage(
                        store: _store,
                        exerciseType: ExerciseType.narrowPushup,
                        recognitionTraceEnabled:
                            widget.settingsController.recognitionTraceEnabled,
                        syncController: widget.syncController,
                        cameraNoticeAcknowledged:
                            widget.cameraNoticeAcknowledged,
                        acknowledgeCameraNotice: widget.acknowledgeCameraNotice,
                      ),
                    );
                    await _refreshTodayTotal();
                  },
                ),
                const SizedBox(height: 14),
                _SportsPlazaCard(
                  accountController: widget.accountController,
                  leaderboardController: widget.leaderboardController,
                  onPressed: () {
                    pushWithoutShadow(
                      context,
                      (leaderboardContext) => LeaderboardPage(
                        controller: widget.leaderboardController,
                        accountController: widget.accountController,
                        onSubscribe: () => showPremiumPurchaseSheet(
                          leaderboardContext,
                          widget.accountController,
                        ),
                      ),
                      // Sports plaza card sits low → enter from the bottom.
                      direction: PageEnterDirection.bottom,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<WorkoutSession>>? _cloudSessionsFuture() {
    final loader = widget.cloudSessionsLoader;
    if (loader == null ||
        !widget.accountController.premium ||
        widget.accountController.currentSession == null) {
      return null;
    }
    final now = DateTime.now();
    return loader(
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}',
    );
  }

  Future<int>? _pendingSyncCountFuture() {
    if (!widget.accountController.premium) {
      return null;
    }
    final ownerAppUserId = widget.syncController?.currentOwnerAppUserId;
    if (ownerAppUserId == null) {
      return null;
    }
    return _store
        .pendingCloudSyncForOwner(ownerAppUserId)
        .then((sessions) => sessions.length);
  }
}

class _SportsPlazaCard extends StatelessWidget {
  const _SportsPlazaCard({
    required this.accountController,
    required this.leaderboardController,
    required this.onPressed,
  });

  final AccountController accountController;
  final LeaderboardController? leaderboardController;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[accountController];
    if (leaderboardController != null) {
      listenables.add(leaderboardController!);
    }
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final status = _resolveStatus();
        final radius = BorderRadius.circular(26);
        return Material(
          key: const ValueKey('home-sports-plaza-card'),
          color: Colors.transparent,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? colorScheme.surface : const Color(0xFFF8FAF5),
                  isDark
                      ? greenDark.withValues(alpha: 0.72)
                      : const Color(0xFFF1F5EF),
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: isDark
                    ? sky.withValues(alpha: 0.22)
                    : greenDark.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? ink : greenDark).withValues(
                    alpha: isDark ? 0.24 : 0.05,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark
                                ? null
                                : greenDark.withValues(alpha: 0.10),
                            gradient: isDark
                                ? const LinearGradient(colors: [sky, green])
                                : null,
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: isDark ? Colors.white : greenDark,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.sportsPlazaTitle,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                status.subtitle(l10n),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.surface.withValues(alpha: 0.72)
                                : greenDark.withValues(alpha: 0.07),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: isDark ? colorScheme.primary : greenDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (status case _JoinedRank(
                      rank: final rank,
                      totalValue: final total,
                    ))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.surface.withValues(alpha: 0.68)
                              : greenDark.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.leaderboard_rounded,
                              color: isDark ? green : greenDark,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.leaderboardRank(rank),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              l10n.leaderboardTotalReps(total),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        l10n.viewLeaderboard,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isDark ? colorScheme.primary : greenDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _SportsPlazaStatus _resolveStatus() {
    if (!accountController.signedIn) {
      return const _SignedOut();
    }
    if (!accountController.premium) {
      return const _FreeMember();
    }
    final snapshot = leaderboardController?.snapshot;
    final isJoined = snapshot?.isJoined ?? false;
    if (!isJoined) {
      return const _PremiumNotJoined();
    }
    // The home card is a DAY summary. Only consume a day-period snapshot's me;
    // a week snapshot must never be surfaced as the home day rank/count.
    final me = snapshot?.period == LeaderboardPeriod.day ? snapshot?.me : null;
    if (me != null) {
      return _JoinedRank(rank: me.rank, totalValue: me.totalValue);
    }
    return const _PremiumJoinedNoRank();
  }
}

/// Four distinct home-card states for the sports plaza, so the user always
/// knows whether they can see their rank, need to subscribe, or need to join.
sealed class _SportsPlazaStatus {
  const _SportsPlazaStatus();
  String subtitle(AppLocalizations l10n);
}

class _SignedOut extends _SportsPlazaStatus {
  const _SignedOut();
  @override
  String subtitle(AppLocalizations l10n) => l10n.leaderboardSignedOutPrompt;
}

class _FreeMember extends _SportsPlazaStatus {
  const _FreeMember();
  @override
  String subtitle(AppLocalizations l10n) => l10n.sportsPlazaFreePrompt;
}

class _PremiumNotJoined extends _SportsPlazaStatus {
  const _PremiumNotJoined();
  @override
  String subtitle(AppLocalizations l10n) => l10n.leaderboardJoinPrompt;
}

class _PremiumJoinedNoRank extends _SportsPlazaStatus {
  const _PremiumJoinedNoRank();
  @override
  String subtitle(AppLocalizations l10n) => l10n.sportsPlazaSubtitle;
}

class _JoinedRank extends _SportsPlazaStatus {
  const _JoinedRank({required this.rank, required this.totalValue});
  final int rank;
  final int totalValue;
  @override
  String subtitle(AppLocalizations l10n) => l10n.sportsPlazaSubtitle;
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.premium,
    required this.user,
    required this.tooltip,
    required this.onPressed,
  });

  final bool premium;
  final AppUser? user;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: ProfileMedalFrame(
        key: ValueKey(
          premium ? 'home-profile-medal-gold' : 'home-profile-medal-silver',
        ),
        premium: premium,
        size: 50,
        child: UserAvatar(
          radius: 20,
          customAvatarUrl: user?.customAvatarUrl,
          avatarKey: user?.avatarKey,
          avatarUrl: user?.avatarUrl,
        ),
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size(54, 54),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderRadius = BorderRadius.circular(20);
    return Material(
      key: const ValueKey('home-today-summary'),
      color: isDark ? colorScheme.surface : const Color(0xFFF7FBF4),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: isDark
              ? colorScheme.outline
              : greenDark.withValues(alpha: 0.14),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 21,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.todayCount(count),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exerciseType,
    required this.todayCount,
    required this.onPressed,
  });

  final ExerciseType exerciseType;
  final int todayCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = exerciseType == ExerciseType.narrowPushup;
    final foreground = isDark ? Colors.white : ink;
    final accentColor = isNarrow
        ? (isDark ? sky : homeNarrowAccent)
        : (isDark ? lime : greenDark);
    final gradientColors = isDark
        ? (isNarrow
              ? const [darkHomeNarrowCardTop, darkHomeNarrowCardBottom]
              : const [Color(0xFF16261F), Color(0xFF244736)])
        : (isNarrow
              ? const [homeNarrowCardTop, homeNarrowCardBottom]
              : const [Color(0xFFFAFBF6), Color(0xFFDCE9DA)]);
    final actionForeground = isDark ? ink : Colors.white;

    final radius = BorderRadius.circular(30);
    return Container(
      key: ValueKey(
        exerciseType == ExerciseType.pushup
            ? 'home-exercise-card'
            : 'home-exercise-card-narrow-pushup',
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x3317261F)
                : accentColor.withValues(alpha: 0.08),
            blurRadius: isDark ? 30 : 22,
            offset: Offset(0, isDark ? 18 : 12),
          ),
        ],
      ),
      foregroundDecoration: isDark
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isNarrow
                    ? homeNarrowAccent.withValues(alpha: 0.20)
                    : const Color(0x33118C4F),
              ),
            ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 45,
                  width: 270,
                  height: 112,
                  child: Opacity(
                    opacity: isDark ? 0.26 : 0.18,
                    child: Image.asset(
                      'assets/images/pushup_silhouette.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                      color: isDark && !isNarrow ? null : accentColor,
                      colorBlendMode: isDark && !isNarrow
                          ? null
                          : BlendMode.srcIn,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _DifficultyBadge(
                                label: isNarrow
                                    ? l10n.exerciseDifficultyTwo
                                    : l10n.exerciseDifficultyOne,
                                accentColor: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.todayCount(todayCount),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 44),
                      Text(
                        exerciseType == ExerciseType.pushup
                            ? l10n.pushupTraining
                            : l10n.narrowPushupTraining,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.20),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ink
                                    : ink.withValues(alpha: 0.24),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.startTraining,
                                style: TextStyle(
                                  color: actionForeground,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: actionForeground,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
