import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../control/leaderboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/leaderboard_models.dart';
import '../../product/membership_status.dart';
import '../app_theme.dart';
import '../profile_avatar.dart';

String _leaderboardErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    LeaderboardErrorCode.premiumRequired => l10n.leaderboardPremiumRequired,
    LeaderboardErrorCode.nicknameTaken => l10n.leaderboardIdentityNicknameTaken,
    LeaderboardErrorCode.invalidNickname =>
      l10n.leaderboardIdentityInvalidNickname,
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
                  onPressed: () => _showIdentitySheet(
                    joining: true,
                    anonymousAvatarKey: snapshot.anonymousAvatarKey,
                  ),
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
                    onEdit: () => _showIdentitySheet(
                      joining: false,
                      initial: snapshot.identity,
                      anonymousAvatarKey: snapshot.anonymousAvatarKey,
                    ),
                    onLeft: () => _load(_period),
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
              onLeft: () => _load(_period),
            ),
    );
  }

  void _load(LeaderboardPeriod period) {
    setState(() => _period = period);
    unawaited(widget.controller?.load(period));
  }

  Future<void> _showIdentitySheet({
    required bool joining,
    LeaderboardIdentityChoice? initial,
    String? anonymousAvatarKey,
  }) async {
    final controller = widget.controller;
    if (controller == null) return;
    await showModalBottomSheet<void>(
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
          _LeaderboardAvatar(
            avatarKey: row.avatarKey,
            avatarUrl: row.avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.nickname ?? l10n.leaderboardAnonymousName,
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
    required this.onEdit,
    required this.onLeft,
  });

  final LeaderboardRow row;
  final LeaderboardController? controller;
  final VoidCallback onEdit;
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
  const _JoinedNoRankPanel({
    required this.controller,
    required this.onEdit,
    required this.onLeft,
  });

  final LeaderboardController? controller;
  final VoidCallback onEdit;
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
            if (controller != null) ...[
              IconButton(
                tooltip: l10n.leaderboardIdentityEdit,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: Colors.white,
              ),
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
  late final TextEditingController _nicknameController;
  late String _avatarKey;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial?.mode ?? LeaderboardIdentityMode.anonymous;
    _nicknameController = TextEditingController(text: initial?.nickname ?? '');
    _avatarKey = initial?.avatarKey ?? profileAvatarKeys.first;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
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
              final error = _validationError ?? widget.controller.error;
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
                          mode: LeaderboardIdentityMode.custom,
                          selectedMode: _mode,
                          title: l10n.leaderboardIdentityCustom,
                          description:
                              l10n.leaderboardIdentityCustomDescription,
                          onSelected: busy ? null : _selectMode,
                          preview: _IdentityPreview(
                            name: _nicknameController.text.trim().isEmpty
                                ? l10n.leaderboardCustomNickname
                                : _nicknameController.text.trim(),
                            nameKey: const ValueKey(
                              'leaderboard-custom-preview-name',
                            ),
                            avatarKey: _avatarKey,
                          ),
                          child: _mode == LeaderboardIdentityMode.custom
                              ? Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    TextField(
                                      key: const ValueKey(
                                        'leaderboard-custom-nickname',
                                      ),
                                      controller: _nicknameController,
                                      enabled: !busy,
                                      onChanged: (_) => setState(
                                        () => _validationError = null,
                                      ),
                                      decoration: InputDecoration(
                                        labelText:
                                            l10n.leaderboardCustomNickname,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final avatarKey
                                            in profileAvatarKeys)
                                          _IdentityAvatarOption(
                                            avatarKey: avatarKey,
                                            selected: avatarKey == _avatarKey,
                                            onTap: busy
                                                ? null
                                                : () => setState(
                                                    () =>
                                                        _avatarKey = avatarKey,
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ],
                                )
                              : null,
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
      _validationError = null;
    });
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    if (_mode == LeaderboardIdentityMode.custom && nickname.isEmpty) {
      setState(() => _validationError = LeaderboardErrorCode.invalidNickname);
      return;
    }
    final choice = LeaderboardIdentityChoice(
      mode: _mode,
      nickname: _mode == LeaderboardIdentityMode.custom ? nickname : null,
      avatarKey: _mode == LeaderboardIdentityMode.custom ? _avatarKey : null,
    );
    final saved = widget.joining
        ? await widget.controller.join(choice)
        : await widget.controller.updateIdentity(choice);
    if (saved && mounted) {
      Navigator.of(context).pop();
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
    this.child,
  });

  final LeaderboardIdentityMode mode;
  final LeaderboardIdentityMode selectedMode;
  final String title;
  final String description;
  final ValueChanged<LeaderboardIdentityMode>? onSelected;
  final Widget preview;
  final Widget? child;

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
              if (child != null) child!,
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
      avatarUrl: user?.avatarKey == null ? user?.avatarUrl : null,
      avatarWidgetKey: const ValueKey('leaderboard-profile-preview-avatar'),
    );
  }
}

class _IdentityPreview extends StatelessWidget {
  const _IdentityPreview({
    required this.name,
    this.avatarKey,
    this.avatarUrl,
    this.avatarWidgetKey,
    this.nameKey,
  });

  final String name;
  final String? avatarKey;
  final String? avatarUrl;
  final Key? avatarWidgetKey;
  final Key? nameKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _LeaderboardAvatar(
          key: avatarWidgetKey,
          avatarKey: avatarKey,
          avatarUrl: avatarUrl,
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
              Text(name, key: nameKey, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityAvatarOption extends StatelessWidget {
  const _IdentityAvatarOption({
    required this.avatarKey,
    required this.selected,
    required this.onTap,
  });

  final String avatarKey;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: profileAvatarLabel(context, avatarKey),
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('leaderboard-avatar-$avatarKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: _LeaderboardAvatar(avatarKey: avatarKey),
        ),
      ),
    );
  }
}

class _LeaderboardAvatar extends StatelessWidget {
  const _LeaderboardAvatar({super.key, this.avatarKey, this.avatarUrl});

  final String? avatarKey;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final builtInKey = avatarKey;
    if (builtInKey != null) {
      return ProfileBuiltInAvatar(avatarKey: builtInKey, radius: 20);
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: yellow,
      foregroundImage: avatarUrl == null
          ? null
          : CachedNetworkImageProvider(avatarUrl!),
      onForegroundImageError: avatarUrl == null ? null : (_, _) {},
      child: const Icon(Icons.person_rounded, color: ink),
    );
  }
}

String _identityErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    LeaderboardErrorCode.nicknameTaken => l10n.leaderboardIdentityNicknameTaken,
    LeaderboardErrorCode.invalidNickname =>
      l10n.leaderboardIdentityInvalidNickname,
    _ => l10n.leaderboardIdentitySaveFailed,
  };
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
