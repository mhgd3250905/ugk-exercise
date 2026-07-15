import 'dart:async';

import 'package:flutter/material.dart';

import '../../control/leaderboard_controller.dart';
import '../../l10n/app_localizations.dart';
import '../user_avatar.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key, required this.controller});

  final LeaderboardController controller;

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.loadBlockedUsers());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const ValueKey('blocked-users-page'),
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final users = widget.controller.blockedUsers;
          final error = widget.controller.blockedUsersError;
          final busy = widget.controller.blockedUsersBusy;
          if (busy && users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (error != null && users.isEmpty) {
            return _LoadError(
              message: l10n.blockedUsersLoadFailed,
              retryLabel: l10n.blockedUsersRetry,
              onRetry: () => unawaited(widget.controller.loadBlockedUsers()),
            );
          }
          if (users.isEmpty) {
            return Center(child: Text(l10n.blockedUsersEmpty));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.blockedUsersUnblockFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              for (final user in users)
                ListTile(
                  leading: UserAvatar(
                    radius: 24,
                    avatarKey: user.avatarKey,
                    avatarUrl: user.avatarUrl,
                  ),
                  title: Text(user.nickname ?? l10n.blockedUsersAnonymous),
                  trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () => unawaited(
                            widget.controller.unblockUser(user.userId),
                          ),
                    child: Text(l10n.blockedUsersUnblock),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
