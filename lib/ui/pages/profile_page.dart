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
                  FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : controller.purchasePremium,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('开通会员'),
                  ),
                  const SizedBox(height: 10),
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
                  Text(controller.error!, style: const TextStyle(color: coral)),
                ],
              ],
            ),
          );
        },
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
