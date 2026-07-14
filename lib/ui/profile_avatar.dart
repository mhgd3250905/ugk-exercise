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

class ProfileMedalFrame extends StatelessWidget {
  const ProfileMedalFrame({
    super.key,
    required this.premium,
    required this.size,
    required this.child,
  });

  final bool premium;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final medalColors = premium
        ? const [Color(0xFFFFF2A8), Color(0xFFFFD84D), Color(0xFFD79A16)]
        : const [Color(0xFFF4F6F5), Color(0xFFC7CFCC), Color(0xFF8D9994)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: medalColors.last.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const MedalEdgeClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: medalColors,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.surface.withValues(alpha: 0.85),
                  width: 1.5,
                ),
              ),
              child: ClipOval(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

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
