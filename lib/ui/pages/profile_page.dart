import 'package:flutter/material.dart';

import '../../control/account_controller.dart';
import '../app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
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
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: yellow,
                        foregroundImage: user?.avatarUrl == null
                            ? null
                            : NetworkImage(user!.avatarUrl!),
                        child: user?.avatarUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: ink,
                              )
                            : null,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '训练者',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.signedIn
                                  ? (user?.email ?? '已登录')
                                  : '本机训练数据',
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
                    label: const Text('使用 Google 登录'),
                  )
                else ...[
                  if (!controller.premium) ...[
                    FilledButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => _showPremiumSheet(context),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('开通会员'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : controller.restorePurchases,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('恢复购买'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: controller.busy ? null : controller.signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('退出登录'),
                  ),
                ],
                if (controller.error != null) ...[
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
      await controller.purchasePremium();
    }
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
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: coral, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: muted, height: 1.35),
            ),
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
    final active = controller.premium;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
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
              active ? '会员已开通。高级功能会在本账号下生效。' : '当前未开通会员。本机训练仍可正常使用。',
              style: const TextStyle(color: muted, height: 1.35),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UGK Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '会员权益绑定当前账号',
                        style: TextStyle(color: Color(0xFFCFE6D7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _PremiumBenefit(
              icon: Icons.verified_user_rounded,
              text: 'Google 账号登录后，会员状态可恢复',
            ),
            const SizedBox(height: 10),
            const _PremiumBenefit(
              icon: Icons.bolt_rounded,
              text: '后续高级训练功能自动归属本账号',
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('继续开通'),
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: ink,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后再说'),
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
