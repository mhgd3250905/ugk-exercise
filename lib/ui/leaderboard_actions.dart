import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Bottom sheet that exposes the "leave leaderboard" action. Used by the
/// long-press menus on the user's own leaderboard panels (my rank / frozen),
/// so the leave entry is no longer a persistent icon button.
///
/// Returns true if the user picked "leave" (the caller then runs the
/// controller leave, which itself asks for final confirmation via
/// [confirmLeaderboardLeave]).
Future<bool> showLeaderboardLeaveActionSheet(BuildContext context) async {
  unawaited(HapticFeedback.selectionClick());
  final l10n = AppLocalizations.of(context);
  final colors = Theme.of(context).colorScheme;
  final leave = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.leaderboardActionsTitle,
            style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 18),
          Material(
            color: colors.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              iconColor: colors.error,
              textColor: colors.error,
              leading: const Icon(Icons.logout_rounded),
              title: Text(l10n.leaderboardLeaveAction),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        ],
      ),
    ),
  );
  return leave == true;
}

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
