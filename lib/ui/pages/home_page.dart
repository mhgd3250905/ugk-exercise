// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../control/account_controller.dart';
import '../../control/leaderboard_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/workout_session_store.dart';
import '../app_theme.dart';
import 'leaderboard_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'test_mode_page.dart';
import 'workout_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.accountController,
    this.leaderboardController,
    this.syncController,
    this.cloudSessionsLoader,
  });

  final AccountController accountController;
  final LeaderboardController? leaderboardController;
  final WorkoutSyncController? syncController;
  final Future<List<WorkoutSession>> Function(String month)?
  cloudSessionsLoader;

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
                    _RoundIconButton(
                      icon: Icons.person_rounded,
                      tooltip: l10n.profileTooltip,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfilePage(
                              controller: widget.accountController,
                              syncController: widget.syncController,
                              leaderboardController:
                                  widget.leaderboardController,
                            ),
                          ),
                        );
                      },
                    ),
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
                        builder: (_) => LeaderboardPage(
                          controller: widget.leaderboardController,
                        ),
                      ),
                    );
                  },
                ),
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
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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
        final status = _resolveStatus();
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: greenDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sportsPlazaTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status.subtitle(l10n),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (status case _JoinedRank(rank: final rank))
                    Text(
                      l10n.leaderboardRank(rank),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.leaderboard_rounded),
                label: Text(l10n.viewLeaderboard),
              ),
            ],
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
    final me = snapshot?.me;
    if (me != null) {
      return _JoinedRank(rank: me.rank);
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
  const _JoinedRank({required this.rank});
  final int rank;
  @override
  String subtitle(AppLocalizations l10n) => l10n.sportsPlazaSubtitle;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        fixedSize: const Size(54, 54),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
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

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.calendar_month_rounded, size: 20),
      label: Text(l10n.todayCount(count)),
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

    return Container(
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
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(l10n.startTraining),
                    style: FilledButton.styleFrom(
                      backgroundColor: lime,
                      foregroundColor: ink,
                      minimumSize: const Size.fromHeight(58),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
