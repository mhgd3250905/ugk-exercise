import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../product/app_update.dart';

typedef AppUpdateCheck = Future<AppReleaseInfo?> Function(String languageCode);
typedef PlayStoreOpener = Future<bool> Function();

class AppUpdatePrompt extends StatefulWidget {
  const AppUpdatePrompt({
    super.key,
    required this.checkForUpdate,
    required this.openPlayStore,
    required this.child,
  });

  final AppUpdateCheck checkForUpdate;
  final PlayStoreOpener openPlayStore;
  final Widget child;

  @override
  State<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<AppUpdatePrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _checkForUpdate() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    final release = await widget.checkForUpdate(languageCode);
    if (!mounted ||
        release == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    final shouldOpenStore = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AppUpdateDialog(release: release),
    );
    if (shouldOpenStore != true || !mounted) return;

    final opened = await widget.openPlayStore();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).settingsUpdateOpenFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppUpdateDialog extends StatelessWidget {
  const _AppUpdateDialog({required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableHeight = MediaQuery.sizeOf(context).height - 48;
    return Dialog(
      key: const ValueKey('app-update-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: availableHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      color: colors.onPrimaryContainer,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appUpdateTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              l10n.appUpdateVersionLabel(release.versionName),
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                l10n.appUpdateReleaseNotesTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < release.releaseNotes.length;
                        index += 1
                      ) ...[
                        _ReleaseNote(text: release.releaseNotes[index]),
                        if (index != release.releaseNotes.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('app-update-later'),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    child: Text(l10n.appUpdateLater),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('app-update-open-store'),
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(128, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                    label: Text(l10n.appUpdateOpenStore),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseNote extends StatelessWidget {
  const _ReleaseNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.check_rounded, color: colors.primary, size: 16),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
