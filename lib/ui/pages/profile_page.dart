import 'package:flutter/material.dart';

import '../../control/account_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/membership_status.dart';
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.controller, this.syncController});

  final AccountController controller;
  final WorkoutSyncController? syncController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _editingProfile = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final user = controller.user;
          return Padding(
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
                  child: Row(
                    children: [
                      _ProfileAvatar(user: user, radius: 34),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.publicDisplayName ??
                                  l10n.profileAnonymousName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.signedIn
                                  ? (user?.email ??
                                        l10n.profileSignedInFallback)
                                  : l10n.profileLocalTrainingData,
                              style: const TextStyle(color: Color(0xFFCFE6D7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _MembershipCard(controller: controller),
                const SizedBox(height: 16),
                if (!controller.signedIn)
                  FilledButton.icon(
                    onPressed: controller.busy ? null : controller.signIn,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(l10n.profileSignInWithGoogle),
                  )
                else ...[
                  if (!controller.premium) ...[
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _showPremiumSheet(context),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(l10n.profileSubscribePremium),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _showEditProfileSheet(context, user),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(l10n.editProfile),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : controller.restorePurchases,
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(l10n.profileRestorePurchases),
                  ),
                  const SizedBox(height: 10),
                  if (controller.premium && widget.syncController != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _confirmSyncLocalHistory(context),
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: Text(l10n.profileSyncLocalHistory),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: controller.busy ? null : controller.signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(l10n.profileSignOut),
                  ),
                ],
                if (controller.error != null && !_editingProfile) ...[
                  const SizedBox(height: 12),
                  _ErrorMessage(message: controller.error!),
                ],
              ],
            ),
          );
        },
      ),
    );
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      await widget.syncController?.claimLegacyForOwner(
        expectedOwnerAppUserId,
      );
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, required this.radius});

  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarKey = user?.avatarKey;
    if (avatarKey != null) {
      return _BuiltInAvatar(avatarKey: avatarKey, radius: radius);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: yellow,
      foregroundImage: user?.avatarUrl == null
          ? null
          : NetworkImage(user!.avatarUrl!),
      child: user?.avatarUrl == null
          ? const Icon(Icons.person_rounded, size: 40, color: ink)
          : null,
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
              color: selected ? lime : Colors.white.withValues(alpha: 0.28),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final busy = widget.controller.busy;
              final error = widget.controller.error;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.editProfileSheetTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nicknameController,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: l10n.profileNicknameLabel,
                        hintText: l10n.profileNicknameHint,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      _ErrorMessage(message: error),
                    ],
                    const SizedBox(height: 20),
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
