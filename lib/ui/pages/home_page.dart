// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../control/account_controller.dart';
import '../../control/leaderboard_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/avatar_image_service.dart';
import '../../product/leaderboard_models.dart';
import '../../product/membership_status.dart';
import '../../product/workout_session_store.dart';
import '../app_settings.dart';
import '../app_theme.dart';
import '../profile_avatar.dart';
import '../user_avatar.dart';
import 'leaderboard_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'test_mode_page.dart';
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
    this.showTestEntry = kDebugMode,
  });

  final AppSettingsController settingsController;
  final AccountController accountController;
  final LeaderboardController? leaderboardController;
  final WorkoutSyncController? syncController;
  final AvatarImageService? avatarImageService;
  final Future<List<WorkoutSession>> Function(String month)?
  cloudSessionsLoader;
  final bool showTestEntry;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = WorkoutSessionStore();
  var _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshTodayTotal());
  }

  Future<void> _refreshTodayTotal() async {
    final total = await _store.totalForLocalDate(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() => _todayTotal = total);
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
                    _TodayButton(
                      count: _todayTotal,
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecordsPage(
                              store: _store,
                              cloudSessionsFuture: _cloudSessionsFuture(),
                              pendingSyncCountFuture: _pendingSyncCountFuture(),
                            ),
                          ),
                        );
                        await _refreshTodayTotal();
                      },
                    ),
                    ListenableBuilder(
                      listenable: widget.accountController,
                      builder: (context, _) => _ProfileButton(
                        premium: widget.accountController.premium,
                        user: widget.accountController.user,
                        tooltip: l10n.profileTooltip,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfilePage(
                                settingsController: widget.settingsController,
                                controller: widget.accountController,
                                syncController: widget.syncController,
                                leaderboardController:
                                    widget.leaderboardController,
                                avatarImageService: widget.avatarImageService,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _ExerciseCard(
                  todayCount: _todayTotal,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutPage(
                          store: _store,
                          syncController: widget.syncController,
                        ),
                      ),
                    );
                    await _refreshTodayTotal();
                  },
                ),
                const SizedBox(height: 18),
                _SportsPlazaCard(
                  accountController: widget.accountController,
                  leaderboardController: widget.leaderboardController,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (leaderboardContext) => LeaderboardPage(
                          controller: widget.leaderboardController,
                          onSubscribe: () => showPremiumPurchaseSheet(
                            leaderboardContext,
                            widget.accountController,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.showTestEntry) ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TestModePage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.science_rounded),
                      label: Text(l10n.testMode),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<WorkoutSession>>? _cloudSessionsFuture() {
    final loader = widget.cloudSessionsLoader;
    if (loader == null || widget.accountController.currentSession == null) {
      return null;
    }
    final now = DateTime.now();
    return loader(
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}',
    );
  }

  Future<int>? _pendingSyncCountFuture() {
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
                  colorScheme.surface,
                  isDark
                      ? greenDark.withValues(alpha: 0.72)
                      : sky.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: isDark
                    ? sky.withValues(alpha: 0.22)
                    : sky.withValues(alpha: 0.38),
              ),
              boxShadow: [
                BoxShadow(
                  color: ink.withValues(alpha: isDark ? 0.24 : 0.08),
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
                            gradient: const LinearGradient(
                              colors: [sky, green],
                            ),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
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
                            color: colorScheme.surface.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: colorScheme.primary,
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
                          color: colorScheme.surface.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.leaderboard_rounded, color: green),
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
                          color: colorScheme.primary,
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

    final borderRadius = BorderRadius.circular(20);
    return Material(
      key: const ValueKey('home-today-summary'),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colorScheme.outline),
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
  const _ExerciseCard({required this.todayCount, required this.onPressed});

  final int todayCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final progress = (todayCount / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      key: const ValueKey('home-exercise-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3317261F),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF16261F), Color(0xFF244736)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -54,
                  top: -46,
                  child: Container(
                    width: 184,
                    height: 184,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x2242C96B),
                    ),
                  ),
                ),
                Positioned(
                  left: -36,
                  bottom: -46,
                  child: Container(
                    width: 148,
                    height: 148,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x1A43B7FF),
                    ),
                  ),
                ),
                Positioned(
                  right: 26,
                  top: 60,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xCC43B7FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 124,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xCCB7EA4C),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _HeroBadge(
                            icon: Icons.auto_awesome_rounded,
                            label: l10n.aiPoseRecognition,
                          ),
                          const Spacer(),
                          Text(
                            l10n.goalCount(100),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 58),
                      Text(
                        l10n.pushupTraining,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.exerciseSummary(todayCount),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.13),
                          valueColor: const AlwaysStoppedAnimation(lime),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: lime.withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: ink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.startTraining,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, color: ink),
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

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: lime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
