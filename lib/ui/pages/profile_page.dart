import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../control/account_controller.dart';
import '../../control/leaderboard_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/membership_status.dart';
import '../app_settings.dart';
import '../app_theme.dart';

const _profileAvatarKeys = [
  'ring-green',
  'ring-lime',
  'ring-sky',
  'ring-yellow',
  'ring-coral',
  'bolt-green',
  'bolt-lime',
  'bolt-sky',
];

final _accountDeletionUrl = Uri.parse(
  'https://pushupai-privacy.pages.dev/#account-deletion',
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.settingsController,
    required this.controller,
    this.syncController,
    this.leaderboardController,
    this.launchExternalUrl,
  });

  final AppSettingsController settingsController;
  final AccountController controller;
  final WorkoutSyncController? syncController;
  final LeaderboardController? leaderboardController;
  final Future<bool> Function(Uri url)? launchExternalUrl;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _editingProfile = false;
  var _signingIn = false;

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
                    color: ink,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          _ProfileAvatar(
                            user: user,
                            radius: 34,
                            signedIn: controller.signedIn,
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
                                    style: const TextStyle(
                                      color: Colors.white,
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
                                  style: const TextStyle(
                                    color: Color(0xFFCFE6D7),
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
                  const SizedBox(height: 16),
                  if (controller.premium)
                    _MembershipCard(controller: controller)
                  else
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _showPremiumSheet(context),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(l10n.profileSubscribePremium),
                    ),
                  if (widget.leaderboardController != null) ...[
                    const SizedBox(height: 16),
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
      ),
    );
  }

  Future<void> _openAccountDeletion() async {
    var opened = false;
    try {
      final launcher = widget.launchExternalUrl;
      opened = launcher != null
          ? await launcher(_accountDeletionUrl)
          : await launchUrl(
              _accountDeletionUrl,
              mode: LaunchMode.externalApplication,
            );
    } catch (_) {
      opened = false;
    }
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

  Future<void> _showPremiumSheet(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PremiumSheet(),
    );
    if (confirmed == true) {
      await widget.controller.purchasePremium();
    }
  }

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
      builder: (context) =>
          _EditProfileSheet(controller: widget.controller, user: user),
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
    required this.onSyncLocalHistory,
    required this.onOpenPrivacy,
  });

  final AppSettingsController controller;
  final VoidCallback? onEditProfile;
  final VoidCallback? onRestorePurchases;
  final VoidCallback? onSyncLocalHistory;
  final VoidCallback onOpenPrivacy;

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
            ],
          ),
        ),
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
  });

  final AppUser? user;
  final double radius;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      final colors = Theme.of(context).colorScheme;
      return CircleAvatar(
        key: const ValueKey('signed-out-avatar'),
        radius: radius,
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurfaceVariant,
        child: const Icon(Icons.person_rounded, size: 40),
      );
    }
    final avatarKey = user?.avatarKey;
    if (avatarKey != null) {
      return _BuiltInAvatar(avatarKey: avatarKey, radius: radius);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: yellow,
      foregroundImage: user?.avatarUrl == null
          ? null
          : CachedNetworkImageProvider(user!.avatarUrl!),
      onForegroundImageError: user?.avatarUrl == null ? null : (_, _) {},
      child: const Icon(Icons.person_rounded, size: 40, color: ink),
    );
  }
}

class _ProfileSyncIndicator extends StatelessWidget {
  const _ProfileSyncIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).profileAccountSyncing,
      child: const SizedBox.square(
        key: ValueKey('profile-account-sync-indicator'),
        dimension: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFCFE6D7),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: yellow.withValues(alpha: 0.14),
        border: Border.all(color: yellow, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: yellow, size: 16),
          SizedBox(width: 4),
          Text(
            'VIP',
            style: TextStyle(
              color: yellow,
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
        label: _avatarLabel(context, avatarKey),
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
          child: _BuiltInAvatar(avatarKey: avatarKey, radius: 24),
        ),
      ),
    );
  }
}

class _BuiltInAvatar extends StatelessWidget {
  const _BuiltInAvatar({required this.avatarKey, required this.radius});

  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final spec = _avatarSpec(avatarKey);
    final diameter = radius * 2;
    final iconSize = radius * 0.95;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: spec.background,
        shape: BoxShape.circle,
        border: spec.ringColor == null
            ? null
            : Border.all(color: spec.ringColor!, width: radius * 0.24),
      ),
      child: Icon(spec.icon, color: spec.iconColor, size: iconSize),
    );
  }
}

({Color background, Color? ringColor, Color iconColor, IconData icon})
_avatarSpec(String avatarKey) {
  final parts = avatarKey.split('-');
  final family = parts.first;
  final tone = parts.length > 1 ? parts[1] : 'green';
  final color = switch (tone) {
    'lime' => lime,
    'sky' => sky,
    'yellow' => yellow,
    'coral' => coral,
    _ => green,
  };
  if (family == 'bolt') {
    return (
      background: color.withValues(alpha: 0.18),
      ringColor: null,
      iconColor: color,
      icon: Icons.bolt_rounded,
    );
  }
  return (
    background: Colors.white,
    ringColor: color,
    iconColor: ink,
    icon: Icons.fitness_center_rounded,
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.controller, required this.user});

  final AccountController controller;
  final AppUser user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nicknameController;
  late String _selectedAvatarKey;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.user.nickname ?? widget.user.publicDisplayName,
    );
    _selectedAvatarKey = widget.user.avatarKey ?? _profileAvatarKeys.first;
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
            final busy = widget.controller.busy;
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final avatarKey in _profileAvatarKeys)
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
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorMessage(message: _accountErrorMessage(l10n, error)),
                  ],
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
  const _ErrorMessage({required this.message});

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
    final active = controller.premium;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.verified_rounded : Icons.cloud_off_rounded,
            color: active ? greenDark : muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              active
                  ? l10n.profileMembershipActive
                  : l10n.profileMembershipInactive,
              style: Theme.of(context).textTheme.bodyMedium,
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
        final snapshot = leaderboardController.snapshot;
        final isJoined = snapshot?.isJoined ?? false;
        final statusText = !accountController.signedIn
            ? l10n.leaderboardProfileSignedOut
            : (isJoined
                  ? l10n.leaderboardProfileJoined
                  : l10n.leaderboardProfileNotJoined);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(
                isJoined ? Icons.emoji_events_rounded : Icons.groups_rounded,
                color: isJoined ? greenDark : muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (isJoined && !leaderboardController.busy)
                TextButton.icon(
                  onPressed: () async {
                    final ok = await leaderboardController.leave();
                    if (ok) {
                      // Refresh so the status reflects the new not-joined state
                      // instead of the pre-leave snapshot.
                      await leaderboardController.reloadForCurrentAccount();
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

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(28),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.profilePremiumSubtitle,
                        style: const TextStyle(color: Color(0xFFCFE6D7)),
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
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l10n.profilePremiumContinue),
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: ink,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
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
    return Row(
      children: [
        Icon(icon, color: lime, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
        ),
      ],
    );
  }
}

String _avatarLabel(BuildContext context, String avatarKey) {
  final l10n = AppLocalizations.of(context);
  return switch (avatarKey) {
    'ring-green' => l10n.profileAvatarRingGreen,
    'ring-lime' => l10n.profileAvatarRingLime,
    'ring-sky' => l10n.profileAvatarRingSky,
    'ring-yellow' => l10n.profileAvatarRingYellow,
    'ring-coral' => l10n.profileAvatarRingCoral,
    'bolt-green' => l10n.profileAvatarBoltGreen,
    'bolt-lime' => l10n.profileAvatarBoltLime,
    'bolt-sky' => l10n.profileAvatarBoltSky,
    _ => l10n.profileAvatarRingGreen,
  };
}

String _accountErrorMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    'invalid_nickname' => l10n.profileErrorInvalidNickname,
    'invalid_avatar_key' => l10n.profileErrorInvalidAvatar,
    'nickname_taken' => l10n.profileErrorNicknameTaken,
    'nickname_change_too_soon' => l10n.profileErrorNicknameCooldown,
    AccountErrorCode.purchaseFailed => l10n.accountErrorPurchaseFailed,
    AccountErrorCode.requestFailed => l10n.accountErrorRequestFailed,
    _ => l10n.accountErrorUnexpected,
  };
}
