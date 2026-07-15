import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

Future<bool> confirmLeaderboardLeave(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.leaderboardLeaveConfirmTitle),
          content: Text(l10n.leaderboardLeaveConfirmDescription),
          actions: [
            TextButton(
              key: const ValueKey('leaderboard-leave-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.leaderboardLeaveCancel),
            ),
            FilledButton(
              key: const ValueKey('leaderboard-leave-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.leaderboardLeaveConfirm),
            ),
          ],
        ),
      ) ??
      false;
}
