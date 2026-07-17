import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../control/account_controller.dart';
import '../../control/leaderboard_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/app_version_service.dart';
import '../../platform/avatar_image_service.dart';
import '../../product/membership_status.dart';
import '../../product/premium_plan.dart';
import '../app_settings.dart';
import '../app_theme.dart';
import '../leaderboard_actions.dart';
import '../profile_avatar.dart';
import '../user_avatar.dart';
import 'blocked_users_page.dart';

final _accountDeletionUrl = Uri.parse(
  'https://pushupai-privacy.pages.dev/#account-deletion',
);
const _playStoreChannel = MethodChannel(
  'com.ugkexercise.ugk_exercise/play_store',
);
final _playStoreWebUrl = Uri.parse(
  'https://play.google.com/store/apps/details?id=com.ugkexercise.ugk_exercise',
);

Future<void> showPremiumPurchaseSheet(
  BuildContext context,
  AccountController controller,
) async {
  final selectedPlan = await showModalBottomSheet<PremiumPlanId>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PremiumSheet(controller: controller),
  );
  if (selectedPlan != null) {
    await controller.purchasePremiumPlan(selectedPlan);
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.settingsController,
    required this.controller,
    this.syncController,
    this.leaderboardController,
    this.launchExternalUrl,
    this.avatarImageService,
  });

  final AppSettingsController settingsController;
  final AccountController controller;
  final WorkoutSyncController? syncController;
  final LeaderboardController? leaderboardController;
  final Future<bool> Function(Uri url)? launchExternalUrl;
  final AvatarImageService? avatarImageService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _editingProfile = false;
  var _signingIn = false;

  @override
  void initState() {
    super.initState();
    // The controller is app-scoped and outlives this page; clear any error
    // left by a previous operation so re-entering does not show a stale
    // banner (e.g. an earlier network failure that the user has since moved
    // past). refresh() below is passive and never resets _error on its own.
    widget.controller.clearError();
    unawaited(widget.controller.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton.filledTonal(
            key: const ValueKey('profile-settings-button'),
            tooltip: l10n.profileSettingsTooltip,
            onPressed: _showSettingsSheet,
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final user = controller.user;
          final syncing = controller.signedIn && controller.busy;
          final content = SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.outline),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          _ProfileAvatar(
                            user: user,
                            radius: 34,
                            signedIn: controller.signedIn,
                            premium: controller.premium,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: controller.premium
                                        ? (syncing ? 102 : 74)
                                        : (syncing ? 26 : 0),
                                  ),
                                  child: Text(
                                    controller.signedIn
                                        ? (user?.publicDisplayName ??
                                              l10n.profileAnonymousName)
                                        : l10n.profileSignedOutTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  controller.signedIn
                                      ? (user?.email ??
                                            l10n.profileSignedInFallback)
                                      : l10n.profileSignedOutSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (controller.premium || syncing)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (syncing) const _ProfileSyncIndicator(),
                              if (syncing && controller.premium)
                                const SizedBox(width: 10),
                              if (controller.premium) const _VipStamp(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (!controller.signedIn && _signingIn) ...[
                  const SizedBox(height: 16),
                  const _SignInProgressCard(),
                ],
                if (controller.signedIn) ...[
                  const SizedBox(height: 14),
                  if (controller.premium)
                    _MembershipCard(controller: controller)
                  else
                    FilledButton(
                      key: const ValueKey('profile-subscribe-button'),
                      onPressed: controller.busy
                          ? null
                          : () => _showPremiumSheet(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.profileSubscribePremium,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  if (widget.leaderboardController != null) ...[
                    const SizedBox(height: 14),
                    _LeaderboardStatusCard(
                      accountController: controller,
                      leaderboardController: widget.leaderboardController!,
                    ),
                  ],
                  if (controller.error != null && !_editingProfile) ...[
                    const SizedBox(height: 12),
                    _ErrorMessage(
                      message: _accountErrorMessage(l10n, controller.error!),
                    ),
                  ],
                ],
              ],
            ),
          );
          return Column(
            children: [
              Expanded(child: content),
              if (!controller.signedIn && controller.error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ErrorMessage(
                    message: _accountErrorMessage(l10n, controller.error!),
                  ),
                ),
              ],
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: controller.signedIn
                      ? OutlinedButton.icon(
                          key: const ValueKey('profile-sign-out-button'),
                          onPressed: controller.busy ? null : _confirmSignOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(l10n.profileSignOut),
                        )
                      : FilledButton.icon(
                          key: const ValueKey('profile-sign-in-button'),
                          onPressed: controller.busy ? null : _signIn,
                          icon: _signingIn
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            _signingIn
                                ? l10n.profileSigningIn
                                : l10n.profileSignInWithGoogle,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      await widget.controller.signIn();
    } finally {
      if (mounted) {
        setState(() => _signingIn = false);
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSignOutConfirmTitle),
        content: Text(l10n.profileSignOutConfirmMessage),
        actions: [
          TextButton(
            key: const ValueKey('profile-sign-out-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('profile-sign-out-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        widget.controller.signedIn &&
        !widget.controller.busy) {
      await widget.controller.signOut();
    }
  }

  Future<void> _showSettingsSheet() {
    final accountController = widget.controller;
    final user = accountController.user;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ProfileSettingsSheet(
        controller: widget.settingsController,
        onEditProfile: !accountController.signedIn || accountController.busy
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(_showEditProfileSheet(context, user));
              },
        onRestorePurchases:
            !accountController.signedIn || accountController.busy
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(accountController.restorePurchases());
              },
        onOpenBlockedUsers:
            !accountController.signedIn || widget.leaderboardController == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlockedUsersPage(
                        controller: widget.leaderboardController!,
                      ),
                    ),
                  ),
                );
              },
        onSyncLocalHistory:
            accountController.premium && widget.syncController != null
            ? () {
                Navigator.of(sheetContext).pop();
                unawaited(_confirmSyncLocalHistory(context));
              }
            : null,
        onOpenPrivacy: () async {
          Navigator.of(sheetContext).pop();
          await _openAccountDeletion();
        },
        onOpenPlayStore: _openPlayStore,
      ),
    );
  }

  Future<void> _openAccountDeletion() async {
    final opened = await _launchExternal(_accountDeletionUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).profileAccountDeletionOpenFailed,
          ),
        ),
      );
    }
  }

  Future<void> _openPlayStore() async {
    final opened =
        await _openNativePlayStore() || await _launchExternal(_playStoreWebUrl);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).settingsUpdateOpenFailed),
        ),
      );
    }
  }

  Future<bool> _openNativePlayStore() async {
    try {
      return await _playStoreChannel.invokeMethod<bool>('openProductPage') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchExternal(Uri url) async {
    try {
      final launcher = widget.launchExternalUrl;
      return launcher != null
          ? await launcher(url)
          : await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _showPremiumSheet(BuildContext context) =>
      showPremiumPurchaseSheet(context, widget.controller);

  Future<void> _showEditProfileSheet(
    BuildContext context,
    AppUser? user,
  ) async {
    if (user == null) {
      return;
    }
    setState(() => _editingProfile = true);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _EditProfileSheet(
        controller: widget.controller,
        user: user,
        avatarImageService: widget.avatarImageService ?? AvatarImageService(),
      ),
    );
    if (mounted) {
      setState(() => _editingProfile = false);
    }
  }

  Future<void> _confirmSyncLocalHistory(BuildContext context) async {
    final expectedOwnerAppUserId = widget.controller.currentSession?.appUserId;
    if (expectedOwnerAppUserId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSyncLocalHistoryTitle),
        content: Text(l10n.profileSyncLocalHistoryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.profileSyncLocalHistoryCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profileSyncLocalHistoryConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.syncController?.claimLegacyForOwner(expectedOwnerAppUserId);
    }
  }
}

class _ProfileSettingsSheet extends StatelessWidget {
  const _ProfileSettingsSheet({
    required this.controller,
    required this.onEditProfile,
    required this.onRestorePurchases,
    required this.onOpenBlockedUsers,
    required this.onSyncLocalHistory,
    required this.onOpenPrivacy,
    required this.onOpenPlayStore,
  });

  final AppSettingsController controller;
  final VoidCallback? onEditProfile;
  final VoidCallback? onRestorePurchases;
  final VoidCallback? onOpenBlockedUsers;
  final VoidCallback? onSyncLocalHistory;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenPlayStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (onEditProfile != null && onRestorePurchases != null) ...[
                _SettingsSectionLabel(
                  icon: Icons.person_outline_rounded,
                  label: l10n.settingsAccount,
                ),
                const SizedBox(height: 10),
                Material(
                  key: const ValueKey('settings-account-card'),
                  color: colors.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        key: const ValueKey('settings-edit-profile'),
                        leading: const Icon(Icons.edit_rounded),
                        title: Text(
                          l10n.editProfile,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: onEditProfile,
                      ),
                      Divider(height: 1, color: colors.outlineVariant),
                      ListTile(
                        key: const ValueKey('settings-restore-purchases'),
                        leading: const Icon(Icons.restore_rounded),
                        title: Text(
                          l10n.profileRestorePurchases,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(l10n.profileRestorePurchasesDescription),
                        onTap: onRestorePurchases,
                      ),
                      if (onOpenBlockedUsers != null) ...[
                        Divider(height: 1, color: colors.outlineVariant),
                        ListTile(
                          key: const ValueKey('settings-blocked-users'),
                          leading: const Icon(Icons.block_rounded),
                          title: Text(
                            l10n.settingsBlockedUsers,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: onOpenBlockedUsers,
                        ),
                      ],
                      if (onSyncLocalHistory != null) ...[
                        Divider(height: 1, color: colors.outlineVariant),
                        ListTile(
                          key: const ValueKey('settings-sync-history'),
                          leading: const Icon(Icons.cloud_upload_rounded),
                          title: Text(
                            l10n.profileSyncLocalHistory,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: onSyncLocalHistory,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _SettingsSectionLabel(
                icon: Icons.translate_rounded,
                label: l10n.settingsLanguage,
              ),
              const SizedBox(height: 10),
              SegmentedButton<AppLanguage>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppLanguage.system,
                    label: Text(l10n.settingsSystem),
                  ),
                  ButtonSegment(
                    value: AppLanguage.zh,
                    label: Text(l10n.settingsChinese),
                  ),
                  ButtonSegment(
                    value: AppLanguage.en,
                    label: Text(
                      l10n.settingsEnglish,
                      key: const ValueKey('settings-language-en'),
                    ),
                  ),
                ],
                selected: {controller.language},
                onSelectionChanged: (selection) {
                  unawaited(controller.setLanguage(selection.single));
                },
              ),
              const SizedBox(height: 24),
              _SettingsSectionLabel(
                icon: Icons.contrast_rounded,
                label: l10n.settingsTheme,
              ),
              const SizedBox(height: 10),
              SegmentedButton<AppThemePreference>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppThemePreference.system,
                    label: Text(l10n.settingsSystem),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.light,
                    label: Text(l10n.settingsLight),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.dark,
                    label: Text(
                      l10n.settingsDark,
                      key: const ValueKey('settings-theme-dark'),
                    ),
                  ),
                ],
                selected: {controller.theme},
                onSelectionChanged: (selection) {
                  unawaited(controller.setTheme(selection.single));
                },
              ),
              const SizedBox(height: 24),
              Material(
                key: const ValueKey('settings-privacy-card'),
                color: colors.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const ValueKey('account-deletion-link'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    l10n.profileAccountDeletion,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenPrivacy,
                ),
              ),
              const SizedBox(height: 12),
              _VersionTile(
                service: const AppVersionService(),
                onOpenPlayStore: onOpenPlayStore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionTile extends StatefulWidget {
  const _VersionTile({required this.service, required this.onOpenPlayStore});

  final AppVersionService service;
  final VoidCallback onOpenPlayStore;

  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  String? _version;
  var _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
    unawaited(_checkForUpdate());
  }

  Future<void> _loadVersion() async {
    String? version;
    try {
      version = await widget.service.installedVersion();
    } catch (_) {}
    if (mounted) {
      setState(() => _version = version);
    }
  }

  Future<void> _checkForUpdate() async {
    final available = await widget.service.updateAvailable();
    if (mounted) {
      setState(() => _updateAvailable = available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('settings-version-tile'),
        leading: const Icon(Icons.info_outline_rounded),
        title: Text(
          l10n.settingsVersion,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_version ?? '—'),
        trailing: _updateAvailable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.settingsUpdateAvailable,
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: widget.onOpenPlayStore,
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.radius,
    required this.signedIn,
    required this.premium,
  });

  final AppUser? user;
  final double radius;
  final bool signedIn;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final innerRadius = radius * 0.8;
    final Widget avatar;
    if (!signedIn) {
      final colors = Theme.of(context).colorScheme;
      avatar = CircleAvatar(
        key: const ValueKey('signed-out-avatar'),
        radius: innerRadius,
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurfaceVariant,
        child: const Icon(Icons.person_rounded, size: 40),
      );
    } else {
      avatar = UserAvatar(
        radius: innerRadius,
        customAvatarUrl: user?.customAvatarUrl,
        avatarKey: user?.avatarKey,
        avatarUrl: user?.avatarUrl,
      );
    }
    return ProfileMedalFrame(
      key: ValueKey(
        premium ? 'profile-avatar-medal-gold' : 'profile-avatar-medal-silver',
      ),
      premium: premium,
      size: radius * 2,
      child: avatar,
    );
  }
}

class _ProfileSyncIndicator extends StatelessWidget {
  const _ProfileSyncIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).profileAccountSyncing,
      child: SizedBox.square(
        key: const ValueKey('profile-account-sync-indicator'),
        dimension: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _VipStamp extends StatelessWidget {
  const _VipStamp();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile-vip-stamp'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D2),
        border: Border.all(color: const Color(0xFFD79A16), width: 1.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFD79A16),
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            'VIP',
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
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
    return InkWell(
      key: ValueKey('avatar-$avatarKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Semantics(
        label: profileAvatarLabel(context, avatarKey),
        selected: selected,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: ProfileBuiltInAvatar(avatarKey: avatarKey, radius: 24),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.controller,
    required this.user,
    required this.avatarImageService,
  });

  final AccountController controller;
  final AppUser user;
  final AvatarImageService avatarImageService;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nicknameController;
  late String _selectedAvatarKey;
  var _avatarBusy = false;
  var _avatarReplacing = false;
  AppUser? _avatarBeforeReplacement;
  var _avatarError = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.user.nickname ?? widget.user.publicDisplayName,
    );
    _selectedAvatarKey = widget.user.avatarKey ?? profileAvatarKeys.first;
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
    return Material(
      key: const ValueKey('edit-profile-sheet'),
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final user = widget.controller.user ?? widget.user;
            final avatarUser = _avatarReplacing
                ? _avatarBeforeReplacement ?? user
                : user;
            final busy = widget.controller.busy || _avatarBusy;
            final error = widget.controller.error;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.editProfileSheetTitle,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('edit-profile-close-button'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorMessage(
                      key: const ValueKey('edit-profile-error-banner'),
                      message: _accountErrorMessage(l10n, error),
                    ),
                  ],
                  const SizedBox(height: 22),
                  TextField(
                    controller: _nicknameController,
                    enabled: !busy,
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      labelText: l10n.profileNicknameLabel,
                      hintText: l10n.profileNicknameHint,
                      labelStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                      floatingLabelStyle: TextStyle(
                        color: colors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.profileCustomAvatarTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        dimension: 68,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            UserAvatar(
                              radius: 34,
                              customAvatarUrl: avatarUser.customAvatarUrl,
                              avatarKey: avatarUser.avatarKey,
                              avatarUrl: avatarUser.avatarUrl,
                            ),
                            if (_avatarBusy)
                              Semantics(
                                label: l10n.profileCustomAvatarUploading,
                                liveRegion: true,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.scrim.withValues(alpha: 0.45),
                                  ),
                                  child: Center(
                                    child: SizedBox.square(
                                      key: const ValueKey(
                                        'custom-avatar-progress',
                                      ),
                                      dimension: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: colors.surface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.profileCustomAvatarDescription,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('custom-avatar-gallery'),
                        onPressed: busy || user.avatarUploadSuspended
                            ? null
                            : () => _pickAvatar(AvatarImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.profileCustomAvatarGallery),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('custom-avatar-camera'),
                        onPressed: busy || user.avatarUploadSuspended
                            ? null
                            : () => _pickAvatar(AvatarImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.profileCustomAvatarCamera),
                      ),
                      if (_avatarReplacing)
                        TextButton.icon(
                          key: const ValueKey('custom-avatar-replacing'),
                          onPressed: null,
                          icon: const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text(l10n.profileCustomAvatarReplacing),
                        )
                      else if (user.customAvatarUrl != null)
                        TextButton.icon(
                          key: const ValueKey('custom-avatar-delete'),
                          onPressed: busy ? null : _deleteAvatar,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(l10n.profileCustomAvatarDelete),
                        ),
                    ],
                  ),
                  if (user.avatarUploadSuspended) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.profileCustomAvatarUploadSuspended,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  if (_avatarError) ...[
                    const SizedBox(height: 8),
                    _ErrorMessage(message: l10n.profileCustomAvatarError),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    l10n.profileErrorInvalidAvatar,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final avatarKey in profileAvatarKeys)
                        _AvatarOption(
                          avatarKey: avatarKey,
                          selected: avatarKey == _selectedAvatarKey,
                          onTap: busy
                              ? null
                              : () => setState(
                                  () => _selectedAvatarKey = avatarKey,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final navigator = Navigator.of(context);
                            await widget.controller.updateProfile(
                              nickname: _nicknameController.text.trim(),
                              avatarKey: _selectedAvatarKey,
                            );
                            if (mounted && widget.controller.error == null) {
                              navigator.pop();
                            }
                          },
                    child: Text(l10n.saveProfile),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickAvatar(AvatarImageSource source) async {
    setState(() {
      _avatarBusy = true;
      _avatarError = false;
    });
    try {
      final bytes = await widget.avatarImageService.pickAndCrop(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _avatarReplacing = true;
        _avatarBeforeReplacement = widget.controller.user ?? widget.user;
      });
      var user = widget.controller.user ?? widget.user;
      if (!user.avatarPolicyAccepted) {
        final accepted = await _confirmAvatarPolicy();
        if (accepted != true || !mounted) return;
        final policyVersion = user.avatarPolicyVersion;
        if (policyVersion == null) {
          setState(() => _avatarError = true);
          return;
        }
        await widget.controller.acceptAvatarPolicy(policyVersion);
        if (!mounted || widget.controller.error != null) return;
        user = widget.controller.user ?? user;
        if (!user.avatarPolicyAccepted) return;
      }
      await widget.controller.uploadAvatar(bytes);
      final avatarUrl = widget.controller.user?.customAvatarUrl;
      if (mounted && widget.controller.error == null && avatarUrl != null) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(avatarUrl),
            context,
          ).timeout(const Duration(seconds: 15));
        } catch (_) {
          // The upload succeeded; UserAvatar can retry the image request.
        }
      }
    } catch (_) {
      if (mounted) setState(() => _avatarError = true);
    } finally {
      if (mounted) {
        setState(() {
          _avatarBusy = false;
          _avatarReplacing = false;
          _avatarBeforeReplacement = null;
        });
      }
    }
  }

  Future<bool?> _confirmAvatarPolicy() {
    var agreed = false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.profileCustomAvatarPolicyTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.profileCustomAvatarPolicyMessage),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey('avatar-policy-checkbox'),
                  contentPadding: EdgeInsets.zero,
                  value: agreed,
                  title: Text(l10n.profileCustomAvatarPolicyAgree),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setDialogState(() => agreed = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: agreed
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(l10n.profileCustomAvatarPolicyContinue),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileCustomAvatarDeleteTitle),
        content: Text(l10n.profileCustomAvatarDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.profileCustomAvatarDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _avatarBusy = true;
      _avatarError = false;
    });
    await widget.controller.deleteAvatar();
    if (mounted) setState(() => _avatarBusy = false);
  }
}

class _SignInProgressCard extends StatelessWidget {
  const _SignInProgressCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('profile-sign-in-progress'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileSigningIn,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.profileSigningInDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: coral, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.controller});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final active = controller.premium;
    return Container(
      key: const ValueKey('profile-membership-status-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.verified_rounded : Icons.cloud_off_rounded,
            color: active ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              active
                  ? l10n.profileMembershipActive
                  : l10n.profileMembershipInactive,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the user's current public leaderboard state and, when joined, a leave
/// action. Leave is gated on isJoined alone (not on score), so a joined user
/// with zero current-period score can still opt out.
class _LeaderboardStatusCard extends StatelessWidget {
  const _LeaderboardStatusCard({
    required this.accountController,
    required this.leaderboardController,
  });

  final AccountController accountController;
  final LeaderboardController leaderboardController;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[accountController, leaderboardController];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final colors = Theme.of(context).colorScheme;
        final snapshot = leaderboardController.snapshot;
        final isJoined = snapshot?.isJoined ?? false;
        final statusText = !accountController.signedIn
            ? l10n.leaderboardProfileSignedOut
            : (isJoined
                  ? l10n.leaderboardProfileJoined
                  : l10n.leaderboardProfileNotJoined);
        return Container(
          key: const ValueKey('profile-leaderboard-status-card'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(
                isJoined ? Icons.emoji_events_rounded : Icons.groups_rounded,
                color: isJoined ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isJoined && !leaderboardController.busy)
                TextButton.icon(
                  onPressed: () async {
                    if (!await confirmLeaderboardLeave(context) ||
                        !context.mounted) {
                      return;
                    }
                    final ok = await leaderboardController.leave();
                    if (ok && context.mounted) {
                      // Refresh so the status reflects the new not-joined state
                      // instead of the pre-leave snapshot.
                      await leaderboardController.reloadForCurrentAccount();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.leaderboardLeaveSuccess)),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.leaderboardLeaveAction),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumSheet extends StatefulWidget {
  const _PremiumSheet({required this.controller});

  final AccountController controller;

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  late Future<List<PremiumPlan>> _plans;
  PremiumPlanId? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _plans = _loadPlans();
  }

  Future<List<PremiumPlan>> _loadPlans() async {
    final plans = await widget.controller.loadPremiumPlans();
    if (mounted && plans.isNotEmpty) {
      setState(() {
        _selectedPlan = plans.any((plan) => plan.id == PremiumPlanId.annual)
            ? PremiumPlanId.annual
            : plans.first.id;
      });
    }
    return plans;
  }

  void _retry() {
    setState(() {
      _selectedPlan = null;
      _plans = _loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: ink,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profilePremiumTitle,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.profilePremiumSubtitle,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _PremiumBenefit(
              icon: Icons.verified_user_rounded,
              text: l10n.profilePremiumBenefitRestore,
            ),
            const SizedBox(height: 10),
            _PremiumBenefit(
              icon: Icons.bolt_rounded,
              text: l10n.profilePremiumBenefitAttribution,
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<PremiumPlan>>(
              future: _plans,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final plans = snapshot.data ?? const <PremiumPlan>[];
                if (plans.isEmpty) {
                  return Column(
                    children: [
                      Text(
                        l10n.profilePremiumPlansUnavailable,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _retry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.outline),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.profilePremiumRetry),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final plan in plans) ...[
                      Builder(
                        builder: (context) {
                          final selected = _selectedPlan == plan.id;
                          return ChoiceChip(
                            key: ValueKey('premium-plan-${plan.id.name}'),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: colors.primaryContainer,
                            backgroundColor: colors.surface,
                            side: BorderSide(
                              color: selected ? colors.primary : colors.outline,
                              width: selected ? 1.5 : 1,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedPlan = plan.id);
                            },
                            label: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      plan.id == PremiumPlanId.annual
                                          ? '${l10n.profilePremiumAnnual} · ${l10n.profilePremiumRecommended}'
                                          : l10n.profilePremiumMonthly,
                                      style: TextStyle(
                                        color: selected
                                            ? colors.onPrimaryContainer
                                            : colors.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    plan.id == PremiumPlanId.annual
                                        ? l10n.profilePremiumAnnualPrice(
                                            plan.price,
                                          )
                                        : l10n.profilePremiumMonthlyPrice(
                                            plan.price,
                                          ),
                                    style: TextStyle(
                                      color: selected
                                          ? colors.onPrimaryContainer
                                          : colors.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: selected
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            key: ValueKey(
                                              'premium-plan-check-${plan.id.name}',
                                            ),
                                            color: colors.primary,
                                            size: 22,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      l10n.profilePremiumAutoRenewal,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _selectedPlan == null
                  ? null
                  : () => Navigator.of(context).pop(_selectedPlan),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.profilePremiumContinue),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.profilePremiumLater),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBenefit extends StatelessWidget {
  const _PremiumBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.onSurface, height: 1.35),
          ),
        ),
      ],
    );
  }
}

String _accountErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    'invalid_nickname' => l10n.profileErrorInvalidNickname,
    'invalid_avatar_key' => l10n.profileErrorInvalidAvatar,
    'nickname_taken' => l10n.profileErrorNicknameTaken,
    'nickname_change_too_soon' => l10n.profileErrorNicknameCooldown,
    AccountErrorCode.purchaseFailed => l10n.accountErrorPurchaseFailed,
    AccountErrorCode.requestFailed => l10n.accountErrorRequestFailed,
    'membership_sync_unavailable' => l10n.membershipSyncUnavailable,
    _ => l10n.accountErrorUnexpected,
  };
}
