import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/ui/profile_avatar.dart';
import 'package:ugk_exercise/ui/user_avatar.dart';

void main() {
  testWidgets('custom avatar wins and keeps built-in as network fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserAvatar(
          radius: 32,
          customAvatarUrl: 'https://example.com/custom.jpg',
          avatarKey: 'ring-lime',
          avatarUrl: 'https://example.com/google.jpg',
        ),
      ),
    );

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      (circle.foregroundImage! as CachedNetworkImageProvider).url,
      'https://example.com/custom.jpg',
    );
    expect(circle.onForegroundImageError, isNotNull);
    expect(find.byType(ProfileBuiltInAvatar), findsOneWidget);
  });

  testWidgets('built-in avatar wins over Google avatar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserAvatar(
          radius: 24,
          avatarKey: 'ring-sky',
          avatarUrl: 'https://example.com/google.jpg',
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('profile-built-in-avatar-ring-sky')),
      findsOneWidget,
    );
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('Google avatar falls back to the safe default on network error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserAvatar(
          radius: 20,
          avatarUrl: 'https://example.com/google.jpg',
        ),
      ),
    );

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      (circle.foregroundImage! as CachedNetworkImageProvider).url,
      'https://example.com/google.jpg',
    );
    expect(circle.onForegroundImageError, isNotNull);
    expect(find.byKey(const ValueKey('user-avatar-default')), findsOneWidget);
  });

  testWidgets('missing avatar data uses the safe default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserAvatar(radius: 20)));

    expect(find.byKey(const ValueKey('user-avatar-default')), findsOneWidget);
  });
}
