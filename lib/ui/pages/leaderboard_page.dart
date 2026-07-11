import 'dart:async';

import 'package:flutter/material.dart';

import '../../control/leaderboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/leaderboard_models.dart';
import '../app_theme.dart';

String _leaderboardErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    LeaderboardErrorCode.premiumRequired => l10n.leaderboardPremiumRequired,
    LeaderboardErrorCode.requestFailed => l10n.leaderboardErrorRequestFailed,
    LeaderboardErrorCode.unexpected => l10n.leaderboardErrorUnexpected,
    _ => l10n.leaderboardErrorUnexpected,
  };
}

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, this.controller, this.snapshot});

  final LeaderboardController? controller;
  final LeaderboardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    return _LeaderboardBody(controller: controller, snapshot: snapshot);
  }
}

class _LeaderboardBody extends StatefulWidget {
  const _LeaderboardBody({required this.controller, required this.snapshot});

  final LeaderboardController? controller;
  final LeaderboardSnapshot? snapshot;

  @override
  State<_LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends State<_LeaderboardBody> {
  late var _period = widget.snapshot?.period ?? LeaderboardPeriod.day;

  @override
  void initState() {
    super.initState();
    if (widget.snapshot == null) {
      unawaited(widget.controller?.load(_period));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) {
      return _buildScaffold(context, snapshot: widget.snapshot);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final snapshot = widget.snapshot ?? controller.snapshot;
        return _buildScaffold(
          context,
          snapshot: snapshot?.period == _period ? snapshot : null,
          busy: controller.busy,
          error: controller.error,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required LeaderboardSnapshot? snapshot,
    bool busy = false,
    String? error,
  }) {
    final l10n = AppLocalizations.of(context);
    final me = snapshot?.me;
    final notJoined = snapshot != null && !snapshot.isJoined;
    final premiumRequired = error == LeaderboardErrorCode.premiumRequired;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sportsPlazaTitle)),
      body: RefreshIndicator(
        onRefresh: () => widget.controller?.load(_period) ?? Future.value(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            SegmentedButton<LeaderboardPeriod>(
              segments: [
                ButtonSegment(
                  value: LeaderboardPeriod.day,
                  label: Text(l10n.leaderboardDay),
                ),
                ButtonSegment(
                  value: LeaderboardPeriod.week,
                  label: Text(l10n.leaderboardWeek),
                ),
              ],
              selected: {_period},
              onSelectionChanged: busy
                  ? null
                  : (selected) => _load(selected.first),
            ),
            const SizedBox(height: 16),
            if (error != null) ...[
              _ErrorPanel(
                message: _leaderboardErrorMessage(l10n, error),
                onRetry: () => _load(_period),
              ),
              const SizedBox(height: 12),
            ],
            if (!busy && notJoined && !premiumRequired) ...[
              if (snapshot.canJoin)
                _JoinPrompt(
                  controller: widget.controller,
                  onJoined: () => _load(_period),
                )
              else
                _EmptyPanel(text: l10n.leaderboardPremiumRequired),
              const SizedBox(height: 12),
            ],
            if (busy && snapshot == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (snapshot == null && error == null)
              _EmptyPanel(text: l10n.leaderboardSignedOutPrompt)
            else if (snapshot != null && snapshot.top.isEmpty)
              _EmptyPanel(text: l10n.leaderboardEmpty)
            else
              for (final row in snapshot?.top ?? const <LeaderboardRow>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LeaderboardRowTile(row: row),
                ),
          ],
        ),
      ),
      bottomNavigationBar: me == null
          ? (snapshot != null && snapshot.isJoined
                ? _JoinedNoRankPanel(
                    controller: widget.controller,
                    onLeft: () => _load(_period),
                  )
                : null)
          : _MyRankPanel(
              row: me,
              controller: widget.controller,
              onLeft: () => _load(_period),
            ),
    );
  }

  void _load(LeaderboardPeriod period) {
    setState(() => _period = period);
    unawaited(widget.controller?.load(period));
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.controller, required this.onJoined});

  final LeaderboardController? controller;
  final VoidCallback onJoined;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: greenDark),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.leaderboardJoinPrompt)),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: controller == null
                ? null
                : () async {
                    if (await controller!.join()) {
                      onJoined();
                    }
                  },
            child: Text(l10n.leaderboardJoinAction),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  const _LeaderboardRowTile({required this.row});

  final LeaderboardRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#${row.rank}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _LeaderboardAvatar(avatarKey: row.avatarKey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.profileAnonymousName,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.leaderboardTotalReps(row.totalValue),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _MyRankPanel extends StatelessWidget {
  const _MyRankPanel({
    required this.row,
    required this.controller,
    required this.onLeft,
  });

  final LeaderboardRow row;
  final LeaderboardController? controller;
  final VoidCallback onLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2217261F),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _LeaderboardAvatar(avatarKey: row.avatarKey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.leaderboardMyRank,
                    style: const TextStyle(
                      color: Color(0xFFCFE6D7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.leaderboardRank(row.rank),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              l10n.leaderboardTotalReps(row.totalValue),
              style: const TextStyle(
                color: lime,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (controller != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.leaderboardLeaveAction,
                onPressed: () async {
                  if (await controller!.leave()) {
                    onLeft();
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the user has joined but has no ranking row this period (zero
/// score). They must still be able to leave; leave eligibility is decided by
/// isJoined alone, never by score > 0.
class _JoinedNoRankPanel extends StatelessWidget {
  const _JoinedNoRankPanel({required this.controller, required this.onLeft});

  final LeaderboardController? controller;
  final VoidCallback onLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.leaderboardMyRank,
                style: const TextStyle(
                  color: Color(0xFFCFE6D7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (controller != null)
              IconButton(
                tooltip: l10n.leaderboardLeaveAction,
                onPressed: () async {
                  if (await controller!.leave()) {
                    onLeft();
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  const _LeaderboardAvatar({required this.avatarKey});

  final String? avatarKey;

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(avatarKey);
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(_avatarIcon(avatarKey), color: color),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: coral),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: coral),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: Text(l10n.leaderboardRetry)),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(text)),
    );
  }
}

Color _avatarColor(String? avatarKey) {
  final tone = avatarKey?.split('-').last;
  return switch (tone) {
    'lime' => lime,
    'sky' => sky,
    'yellow' => yellow,
    'coral' => coral,
    _ => green,
  };
}

IconData _avatarIcon(String? avatarKey) {
  return avatarKey?.startsWith('bolt-') == true
      ? Icons.bolt_rounded
      : Icons.fitness_center_rounded;
}
