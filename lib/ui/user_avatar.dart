import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'profile_avatar.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.radius,
    this.customAvatarUrl,
    this.avatarKey,
    this.avatarUrl,
  });

  final double radius;
  final String? customAvatarUrl;
  final String? avatarKey;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final customUrl = _present(customAvatarUrl);
    final builtInKey = _present(avatarKey);
    final googleUrl = _present(avatarUrl);
    if (customUrl == null && builtInKey != null) {
      return ProfileBuiltInAvatar(avatarKey: builtInKey, radius: radius);
    }

    final foregroundUrl = customUrl ?? googleUrl;
    final backgroundUrl = customUrl != null && builtInKey == null
        ? googleUrl
        : null;
    return CircleAvatar(
      key: const ValueKey('user-avatar'),
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundImage: foregroundUrl == null
          ? null
          : CachedNetworkImageProvider(foregroundUrl),
      onForegroundImageError: foregroundUrl == null ? null : (_, _) {},
      backgroundImage: backgroundUrl == null
          ? null
          : CachedNetworkImageProvider(backgroundUrl),
      onBackgroundImageError: backgroundUrl == null ? null : (_, _) {},
      child: builtInKey == null
          ? Icon(
              Icons.person_rounded,
              key: const ValueKey('user-avatar-default'),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: radius,
            )
          : ProfileBuiltInAvatar(avatarKey: builtInKey, radius: radius),
    );
  }
}

String? _present(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
