import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_theme.dart';

const profileAvatarKeys = [
  'ring-green',
  'ring-lime',
  'ring-sky',
  'ring-yellow',
  'ring-coral',
  'bolt-green',
  'bolt-lime',
  'bolt-sky',
];

class ProfileBuiltInAvatar extends StatelessWidget {
  const ProfileBuiltInAvatar({
    super.key,
    required this.avatarKey,
    required this.radius,
  });

  final String avatarKey;
  final double radius;

  @override
  Widget build(BuildContext context) {
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
    final ring = family != 'bolt';
    return Container(
      key: ValueKey('profile-built-in-avatar-$avatarKey'),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: ring ? Colors.white : color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: color, width: radius * 0.24) : null,
      ),
      child: Icon(
        ring ? Icons.fitness_center_rounded : Icons.bolt_rounded,
        color: ring ? ink : color,
        size: radius * 0.95,
      ),
    );
  }
}

String profileAvatarLabel(BuildContext context, String avatarKey) {
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

class MedalEdgeClipper extends CustomClipper<Path> {
  const MedalEdgeClipper();

  @override
  Path getClip(Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = math.min(size.width, size.height) / 2;
    final innerRadius = outerRadius * 0.9;
    final path = Path();

    for (var index = 0; index < 36; index++) {
      final angle = -math.pi / 2 + index * math.pi / 18;
      final radius = index.isEven ? outerRadius : innerRadius;
      final point = center + Offset.fromDirection(angle, radius);
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldReclip(MedalEdgeClipper oldClipper) => false;
}
