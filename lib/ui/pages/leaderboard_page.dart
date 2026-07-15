import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../control/leaderboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/leaderboard_models.dart';
import '../../product/membership_status.dart';
import '../app_theme.dart';
import '../leaderboard_actions.dart';
import '../profile_avatar.dart';
import '../user_avatar.dart';

String _leaderboardErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    LeaderboardErrorCode.premiumRequired => l10n.leaderboardPremiumRequired,
    LeaderboardErrorCode.requestFailed => l10n.leaderboardErrorRequestFailed,
    LeaderboardErrorCode.unexpected => l10n.leaderboardErrorUnexpected,
    _ => l10n.leaderboardErrorUnexpected,
  };
}

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    super.key,
    this.controller,
    this.snapshot,
    this.onSubscribe,
  });

  final LeaderboardController? controller;
  final LeaderboardSnapshot? snapshot;
  final Future<void> Function()? onSubscribe;

  @override
  Widget build(BuildContext context) {
    return _LeaderboardBody(
      controller: controller,
      snapshot: snapshot,
      onSubscribe: onSubscribe,
    );
  }
}

class _LeaderboardBody extends StatefulWidget {
  const _LeaderboardBody({
    required this.controller,
    required this.snapshot,
    required this.onSubscribe,
  });

  final LeaderboardController? controller;
  final LeaderboardSnapshot? snapshot;
  final Future<void> Function()? onSubscribe;

  @override
  State<_LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends State<_LeaderboardBody> {
  late var _period = widget.snapshot?.period ?? LeaderboardPeriod.day;
  late var _animateRowsOnMount =
      widget.snapshot == null &&
      widget.controller?.snapshotFor(_period) == null;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearBottom);
    if (widget.snapshot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRefresh();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        final snapshot = widget.snapshot ?? controller.snapshotFor(_period);
        return _buildScaffold(
          context,
          snapshot: snapshot,
          busy: controller.busy,
          error: controller.errorFor(_period) ?? controller.error,
          loadingMore: controller.isLoadingMore(_period),
          loadMoreError: controller.loadMoreErrorFor(_period),
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required LeaderboardSnapshot? snapshot,
    bool busy = false,
    String? error,
    bool loadingMore = false,
    String? loadMoreError,
  }) {
    final l10n = AppLocalizations.of(context);
    final me = snapshot?.me;
    final notJoined = snapshot != null && !snapshot.isJoined;
    final premiumRequired = error == LeaderboardErrorCode.premiumRequired;
    final showPremiumAction =
        notJoined && (!snapshot.canJoin || premiumRequired);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sportsPlazaTitle)),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: () => widget.controller?.refreshAll() ?? Future.value(),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _LeaderboardPeriodPill(
              period: _period,
              onSelected: widget.controller == null ? null : _selectPeriod,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null && !premiumRequired) ...[
                  _ErrorPanel(
                    message: _leaderboardErrorMessage(l10n, error),
                    onRetry: _refreshAll,
                  ),
                  const SizedBox(height: 12),
                ],
                if (!busy &&
                    notJoined &&
                    !premiumRequired &&
                    snapshot.canJoin) ...[
                  _JoinPrompt(
                    controller: widget.controller,
                    onPressed: () => _showIdentitySheet(
                      joining: true,
                      anonymousAvatarKey: snapshot.anonymousAvatarKey,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!busy &&
                    snapshot == null &&
                    error == null &&
                    widget.controller?.currentSession == null)
                  _EmptyPanel(text: l10n.leaderboardSignedOutPrompt)
                else if (snapshot != null && snapshot.top.isEmpty)
                  _EmptyPanel(text: l10n.leaderboardEmpty)
                else if (snapshot != null) ...[
                  _StaggeredLeaderboardRows(
                    key: ValueKey('leaderboard-rows-${snapshot.period.name}'),
                    rows: snapshot.top,
                    animateOnMount: _animateRowsOnMount,
                    controller: widget.controller,
                  ),
                  if (loadingMore || loadMoreError != null)
                    _LeaderboardLoadMoreFooter(
                      loading: loadingMore,
                      onRetry: loadMoreError == null
                          ? null
                          : () =>
                                unawaited(widget.controller?.loadMore(_period)),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: showPremiumAction
          ? _LeaderboardPremiumAction(
              onPressed: widget.onSubscribe == null
                  ? null
                  : () => unawaited(_subscribe()),
            )
          : me == null
          ? (snapshot != null && snapshot.isJoined
                ? _JoinedNoRankPanel(
                    controller: widget.controller,
                    onEdit: () => _showIdentitySheet(
                      joining: false,
                      initial: snapshot.identity,
                      anonymousAvatarKey: snapshot.anonymousAvatarKey,
                    ),
                    onLeave: _leave,
                  )
                : null)
          : _MyRankPanel(
              row: me,
              controller: widget.controller,
              onEdit: () => _showIdentitySheet(
                joining: false,
                initial: snapshot?.identity,
                anonymousAvatarKey: snapshot?.anonymousAvatarKey,
              ),
              onLeave: _leave,
            ),
    );
  }

  void _selectPeriod(LeaderboardPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _animateRowsOnMount = true;
    });
    final controller = widget.controller;
    controller?.selectPeriod(period);
    if (controller?.currentSession != null &&
        controller?.snapshotFor(period) == null) {
      _showRefresh();
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _loadMoreNearBottom() {
    if (_scrollController.position.extentAfter < 240) {
      unawaited(widget.controller?.loadMore(_period));
    }
  }

  void _refreshAll() {
    unawaited(widget.controller?.refreshAll());
  }

  void _showRefresh() {
    unawaited(
      _refreshKey.currentState?.show() ?? widget.controller?.refreshAll(),
    );
  }

  Future<void> _subscribe() async {
    await widget.onSubscribe?.call();
    if (!mounted) return;
    await widget.controller?.refreshAll();
  }

  Future<void> _showIdentitySheet({
    required bool joining,
    LeaderboardIdentityChoice? initial,
    String? anonymousAvatarKey,
  }) async {
    final controller = widget.controller;
    if (controller == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LeaderboardIdentitySheet(
        controller: controller,
        joining: joining,
        initial: initial,
        anonymousAvatarKey:
            anonymousAvatarKey ??
            _anonymousAvatarKeyForUser(controller.currentSession?.appUserId),
      ),
    );
    if (joining && saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).leaderboardJoinSuccess),
        ),
      );
    }
  }

  Future<void> _leave() async {
    final controller = widget.controller;
    if (controller == null || !await confirmLeaderboardLeave(context)) return;
    if (!await controller.leave() || !mounted) return;
    _refreshAll();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).leaderboardLeaveSuccess),
      ),
    );
  }
}

class _LeaderboardPeriodPill extends StatelessWidget {
  const _LeaderboardPeriodPill({
    required this.period,
    required this.onSelected,
  });

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    Widget segment(LeaderboardPeriod value, String label) {
      final selected = period == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onSelected == null || selected
                ? null
                : () => onSelected!(value),
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeOutQuart,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        key: const ValueKey('leaderboard-period-pill'),
        width: 270,
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.outline.withValues(alpha: 0.9)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutQuart,
                alignment: period == LeaderboardPeriod.day
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  key: const ValueKey('leaderboard-period-indicator'),
                  width: constraints.maxWidth / 2,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        green.withValues(alpha: 0.16),
                        green.withValues(alpha: 0.28),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: green.withValues(alpha: 0.28)),
                    boxShadow: [
                      BoxShadow(
                        color: green.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Row(
                  children: [
                    segment(LeaderboardPeriod.day, l10n.leaderboardDay),
                    segment(LeaderboardPeriod.week, l10n.leaderboardWeek),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardPremiumAction extends StatelessWidget {
  const _LeaderboardPremiumAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('leaderboard-premium-action'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.leaderboardPremiumRequired,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onPressed,
              child: Text(l10n.profileSubscribePremium),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.controller, required this.onPressed});

  final LeaderboardController? controller;
  final VoidCallback onPressed;

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
            onPressed: controller == null ? null : onPressed,
            child: Text(l10n.leaderboardJoinAction),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardLoadMoreFooter extends StatelessWidget {
  const _LeaderboardLoadMoreFooter({
    required this.loading,
    required this.onRetry,
  });

  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        key: ValueKey('leaderboard-load-more-progress'),
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return Center(
      child: TextButton(
        key: const ValueKey('leaderboard-load-more-retry'),
        onPressed: onRetry,
        child: Text(AppLocalizations.of(context).leaderboardRetry),
      ),
    );
  }
}

class _StaggeredLeaderboardRows extends StatefulWidget {
  const _StaggeredLeaderboardRows({
    super.key,
    required this.rows,
    required this.animateOnMount,
    required this.controller,
  });

  final List<LeaderboardRow> rows;
  final bool animateOnMount;
  final LeaderboardController? controller;

  @override
  State<_StaggeredLeaderboardRows> createState() =>
      _StaggeredLeaderboardRowsState();
}

class _StaggeredLeaderboardRowsState extends State<_StaggeredLeaderboardRows>
    with SingleTickerProviderStateMixin {
  static const _itemDurationMs = 220;
  static const _staggerMs = 45;

  var _firstAnimatedIndex = 0;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _durationFor(widget.rows.length),
  )..forward(from: widget.animateOnMount ? 0 : 1);

  Duration _durationFor(int count) =>
      Duration(milliseconds: _itemDurationMs + (count - 1) * _staggerMs);

  @override
  void didUpdateWidget(covariant _StaggeredLeaderboardRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length <= oldWidget.rows.length) return;
    _firstAnimatedIndex = oldWidget.rows.length;
    _controller.duration = _durationFor(
      widget.rows.length - _firstAnimatedIndex,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final totalMs = _controller.duration!.inMilliseconds;
    return Column(
      children: [
        for (var index = 0; index < widget.rows.length; index++)
          AnimatedBuilder(
            animation: _controller,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaderboardRowTile(
                row: widget.rows[index],
                controller: widget.controller,
              ),
            ),
            builder: (context, child) {
              if (index < _firstAnimatedIndex) return child!;
              final animatedIndex = index - _firstAnimatedIndex;
              final start = animatedIndex * _staggerMs / totalMs;
              final end =
                  (animatedIndex * _staggerMs + _itemDurationMs) / totalMs;
              final progress = animationsDisabled
                  ? 1.0
                  : Interval(
                      start,
                      end,
                      curve: Curves.easeOutBack,
                    ).transform(_controller.value);
              return Transform.scale(
                key: ValueKey(
                  'leaderboard-row-reveal-${widget.rows[index].rank}',
                ),
                scale: progress,
                alignment: Alignment.center,
                child: child,
              );
            },
          ),
      ],
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  const _LeaderboardRowTile({required this.row, required this.controller});

  final LeaderboardRow row;
  final LeaderboardController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final medalColor = switch (row.rank) {
      1 => const Color(0xFFE0A000),
      2 => const Color(0xFF7C8E98),
      3 => const Color(0xFF9A603B),
      _ => null,
    };
    final height = switch (row.rank) {
      1 => 88.0,
      2 => 82.0,
      3 => 76.0,
      _ => 68.0,
    };
    final cardColor = theme.brightness == Brightness.light
        ? panel
        : colorScheme.surface;
    final sheenAlpha = switch (row.rank) {
      1 => 0.3,
      2 => 0.24,
      3 => 0.16,
      _ => 0.0,
    };
    final session = controller?.currentSession;
    final canModerate = session != null && session.appUserId != row.userId;
    void openActions() => unawaited(_showActions(context));
    final card = Container(
      key: ValueKey('leaderboard-row-${row.rank}'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: medalColor == null ? cardColor : null,
        gradient: medalColor == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.28, 0.46, 0.62, 1],
                colors: [
                  Color.alphaBlend(
                    medalColor.withValues(alpha: sheenAlpha * 0.25),
                    cardColor,
                  ),
                  Color.alphaBlend(
                    medalColor.withValues(alpha: sheenAlpha * 0.82),
                    cardColor,
                  ),
                  cardColor,
                  Color.alphaBlend(
                    medalColor.withValues(alpha: sheenAlpha * 0.4),
                    cardColor,
                  ),
                  Color.alphaBlend(
                    medalColor.withValues(alpha: sheenAlpha),
                    cardColor,
                  ),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: medalColor ?? colorScheme.outline,
          width: switch (row.rank) {
            1 => 2.2,
            2 => 1.8,
            3 => 1.5,
            _ => 1,
          },
        ),
        boxShadow: switch (row.rank) {
          1 => [
            BoxShadow(
              color: medalColor!.withValues(alpha: 0.24),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
          2 => [
            BoxShadow(
              color: medalColor!.withValues(alpha: 0.16),
              blurRadius: 10,
            ),
          ],
          _ => const [],
        },
      ),
      child: Row(
        children: [
          _LeaderboardAvatar(
            avatarKey: row.avatarKey,
            avatarUrl: row.avatarUrl,
            rank: row.rank,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.nickname ?? l10n.leaderboardAnonymousName,
              style: row.rank == 1
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: medalColor == null
                ? Text(
                    '#${row.rank}',
                    key: ValueKey('leaderboard-rank-number-${row.rank}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Semantics(
                    label: l10n.leaderboardRank(row.rank),
                    child: ExcludeSemantics(
                      child: Icon(
                        row.rank == 1
                            ? Icons.emoji_events_rounded
                            : Icons.military_tech_rounded,
                        key: ValueKey('leaderboard-rank-medal-${row.rank}'),
                        color: medalColor,
                        size: row.rank == 1 ? 28 : 25,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: _RankScore(rank: row.rank, totalValue: row.totalValue),
          ),
        ],
      ),
    );
    return Semantics(
      hint: canModerate ? l10n.leaderboardLongPressHint : null,
      onLongPress: canModerate ? openActions : null,
      child: GestureDetector(
        key: ValueKey('leaderboard-row-actions-${row.userId}'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onLongPress: canModerate ? openActions : null,
        child: card,
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    unawaited(HapticFeedback.selectionClick());
    final action = await showModalBottomSheet<_LeaderboardRowAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);
        final theme = Theme.of(sheetContext);
        final colors = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _LeaderboardAvatar(
                    avatarKey: row.avatarKey,
                    avatarUrl: row.avatarUrl,
                    rank: row.rank,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.leaderboardActionsTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          row.nickname ?? l10n.leaderboardAnonymousName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Material(
                color: colors.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.image_outlined),
                      title: Text(l10n.leaderboardReportAvatar),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_LeaderboardRowAction.reportAvatar),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(l10n.leaderboardReportUser),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_LeaderboardRowAction.reportUser),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    ListTile(
                      iconColor: colors.error,
                      textColor: colors.error,
                      leading: const Icon(Icons.block_rounded),
                      title: Text(l10n.leaderboardBlockUser),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_LeaderboardRowAction.blockUser),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        );
      },
    );
    if (action != null && context.mounted) {
      unawaited(_handleAction(context, action));
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    _LeaderboardRowAction action,
  ) async {
    final leaderboard = controller;
    if (leaderboard == null) return;
    if (action == _LeaderboardRowAction.blockUser) {
      final success = await _block(context, leaderboard);
      if (!context.mounted || success) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).leaderboardModerationFailed,
          ),
        ),
      );
      return;
    }
    final type = action == _LeaderboardRowAction.reportAvatar
        ? LeaderboardReportType.avatar
        : LeaderboardReportType.user;
    final reason = await _chooseReportReason(context);
    if (reason == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progressColor = Theme.of(context).colorScheme.onInverseSurface;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 1),
        content: Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: progressColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.leaderboardReportSubmitting)),
          ],
        ),
      ),
    );
    final success = await leaderboard.reportUser(row.userId, type, reason);
    if (!messenger.mounted) return;
    messenger.hideCurrentSnackBar();
    if (!success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.leaderboardModerationFailed)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.leaderboardReportSuccess)),
      );
    }
  }

  Future<LeaderboardReportReason?> _chooseReportReason(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      LeaderboardReportReason.nudity: l10n.leaderboardReportReasonNudity,
      LeaderboardReportReason.violence: l10n.leaderboardReportReasonViolence,
      LeaderboardReportReason.hate: l10n.leaderboardReportReasonHate,
      LeaderboardReportReason.spam: l10n.leaderboardReportReasonSpam,
      LeaderboardReportReason.impersonation:
          l10n.leaderboardReportReasonImpersonation,
      LeaderboardReportReason.other: l10n.leaderboardReportReasonOther,
    };
    return showDialog<LeaderboardReportReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.leaderboardReportReasonTitle),
        children: [
          for (final entry in labels.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
  }

  Future<bool> _block(
    BuildContext context,
    LeaderboardController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaderboardBlockTitle),
        content: Text(l10n.leaderboardBlockMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leaderboardBlockConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return true;
    return controller.blockUser(row.userId);
  }
}

enum _LeaderboardRowAction { reportAvatar, reportUser, blockUser }

class _RankScore extends StatelessWidget {
  const _RankScore({required this.rank, required this.totalValue});

  final int rank;
  final int totalValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final digits = '$totalValue';
    final text = l10n.leaderboardTotalReps(totalValue);
    final digitStart = text.indexOf(digits);
    final scoreColor = switch (rank) {
      1 => const Color(0xFF9A6900),
      2 => const Color(0xFF526771),
      3 => const Color(0xFF70452C),
      _ => theme.colorScheme.onSurface,
    };
    return Text.rich(
      key: ValueKey('leaderboard-score-$rank'),
      textAlign: TextAlign.right,
      maxLines: 1,
      TextSpan(
        style: theme.textTheme.labelLarge?.copyWith(color: scoreColor),
        children: [
          if (digitStart > 0) TextSpan(text: text.substring(0, digitStart)),
          TextSpan(
            text: digits,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: rank == 1 ? 30 : 28,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
          TextSpan(text: text.substring(digitStart + digits.length)),
        ],
      ),
    );
  }
}

class _MyRankPanel extends StatelessWidget {
  const _MyRankPanel({
    required this.row,
    required this.controller,
    required this.onEdit,
    required this.onLeave,
  });

  final LeaderboardRow row;
  final LeaderboardController? controller;
  final VoidCallback onEdit;
  final Future<void> Function() onLeave;

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
            _LeaderboardAvatar(
              avatarKey: row.avatarKey,
              avatarUrl: row.avatarUrl,
            ),
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
                tooltip: l10n.leaderboardIdentityEdit,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: Colors.white,
              ),
              IconButton(
                tooltip: l10n.leaderboardLeaveAction,
                onPressed: onLeave,
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
  const _JoinedNoRankPanel({
    required this.controller,
    required this.onEdit,
    required this.onLeave,
  });

  final LeaderboardController? controller;
  final VoidCallback onEdit;
  final Future<void> Function() onLeave;

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
            if (controller != null) ...[
              IconButton(
                tooltip: l10n.leaderboardIdentityEdit,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: Colors.white,
              ),
              IconButton(
                tooltip: l10n.leaderboardLeaveAction,
                onPressed: onLeave,
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

class _LeaderboardIdentitySheet extends StatefulWidget {
  const _LeaderboardIdentitySheet({
    required this.controller,
    required this.joining,
    required this.initial,
    required this.anonymousAvatarKey,
  });

  final LeaderboardController controller;
  final bool joining;
  final LeaderboardIdentityChoice? initial;
  final String anonymousAvatarKey;

  @override
  State<_LeaderboardIdentitySheet> createState() =>
      _LeaderboardIdentitySheetState();
}

class _LeaderboardIdentitySheetState extends State<_LeaderboardIdentitySheet> {
  late LeaderboardIdentityMode _mode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial?.mode ?? LeaderboardIdentityMode.anonymous;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Material(
        key: const ValueKey('leaderboard-identity-sheet'),
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final busy = widget.controller.busy;
              final error = widget.controller.error;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      children: [
                        Text(
                          l10n.leaderboardIdentitySheetTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (widget.joining) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.leaderboardJoinDescription,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _IdentityCard(
                          mode: LeaderboardIdentityMode.profile,
                          selectedMode: _mode,
                          title: l10n.leaderboardIdentityProfile,
                          description:
                              l10n.leaderboardIdentityProfileDescription,
                          onSelected: busy ? null : _selectMode,
                          preview: _ProfileIdentityPreview(
                            user: widget.controller.currentUser,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _IdentityCard(
                          mode: LeaderboardIdentityMode.anonymous,
                          selectedMode: _mode,
                          title: l10n.leaderboardIdentityAnonymous,
                          description:
                              l10n.leaderboardIdentityAnonymousDescription,
                          onSelected: busy ? null : _selectMode,
                          preview: _IdentityPreview(
                            name: l10n.leaderboardAnonymousName,
                            avatarKey: widget.anonymousAvatarKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        _identityErrorMessage(l10n, error),
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(l10n.leaderboardIdentityCancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: busy ? null : _submit,
                            child: Text(
                              widget.joining
                                  ? l10n.leaderboardIdentityConfirmJoin
                                  : l10n.leaderboardIdentityConfirmEdit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectMode(LeaderboardIdentityMode mode) {
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _submit() async {
    final choice = LeaderboardIdentityChoice(mode: _mode);
    final saved = widget.joining
        ? await widget.controller.join(choice)
        : await widget.controller.updateIdentity(choice);
    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.mode,
    required this.selectedMode,
    required this.title,
    required this.description,
    required this.onSelected,
    required this.preview,
  });

  final LeaderboardIdentityMode mode;
  final LeaderboardIdentityMode selectedMode;
  final String title;
  final String description;
  final ValueChanged<LeaderboardIdentityMode>? onSelected;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = mode == selectedMode;
    return Semantics(
      label: title,
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('leaderboard-identity-${mode.name}-card'),
        onTap: onSelected == null ? null : () => onSelected!(mode),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.45)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Radio<LeaderboardIdentityMode>(
                    key: ValueKey('leaderboard-identity-${mode.name}-radio'),
                    value: mode,
                    groupValue: selectedMode,
                    onChanged: onSelected == null
                        ? null
                        : (value) {
                            if (value != null) onSelected!(value);
                          },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              preview,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileIdentityPreview extends StatelessWidget {
  const _ProfileIdentityPreview({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = user?.publicDisplayName.trim();
    return _IdentityPreview(
      name: name == null || name.isEmpty ? l10n.leaderboardAnonymousName : name,
      avatarKey: user?.avatarKey,
      customAvatarUrl: user?.customAvatarUrl,
      avatarUrl: user?.avatarUrl,
      avatarWidgetKey: const ValueKey('leaderboard-profile-preview-avatar'),
    );
  }
}

class _IdentityPreview extends StatelessWidget {
  const _IdentityPreview({
    required this.name,
    this.avatarKey,
    this.avatarUrl,
    this.customAvatarUrl,
    this.avatarWidgetKey,
  });

  final String name;
  final String? avatarKey;
  final String? avatarUrl;
  final String? customAvatarUrl;
  final Key? avatarWidgetKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _LeaderboardAvatar(
          key: avatarWidgetKey,
          avatarKey: avatarKey,
          avatarUrl: avatarUrl,
          customAvatarUrl: customAvatarUrl,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.leaderboardIdentityPreview,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(name, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  const _LeaderboardAvatar({
    super.key,
    this.avatarKey,
    this.avatarUrl,
    this.customAvatarUrl,
    this.rank,
  });

  final String? avatarKey;
  final String? avatarUrl;
  final String? customAvatarUrl;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final medalColors = switch (rank) {
      1 => const [Color(0xFFFFF2A8), Color(0xFFFFD84D), Color(0xFFD79A16)],
      2 => const [Color(0xFFF4F6F5), Color(0xFFC7CFCC), Color(0xFF8D9994)],
      3 => const [Color(0xFFFFD2AD), Color(0xFFC77B49), Color(0xFF8C4E2A)],
      _ => null,
    };
    final avatarRadius = medalColors == null ? 20.0 : 18.0;
    final avatar = UserAvatar(
      radius: avatarRadius,
      customAvatarUrl: customAvatarUrl,
      avatarKey: avatarKey,
      avatarUrl: avatarUrl,
    );
    if (medalColors == null) return avatar;
    return Container(
      key: ValueKey('leaderboard-avatar-frame-rank-$rank'),
      child: ClipPath(
        clipper: const MedalEdgeClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: medalColors,
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(5), child: avatar),
        ),
      ),
    );
  }
}

String _identityErrorMessage(AppLocalizations l10n, String errorCode) {
  return l10n.leaderboardIdentitySaveFailed;
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

String _anonymousAvatarKeyForUser(String? userId) {
  if (userId == null) return profileAvatarKeys.first;
  var hash = 0;
  for (final codeUnit in userId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0xFFFFFFFF;
  }
  return profileAvatarKeys[hash % 5];
}
