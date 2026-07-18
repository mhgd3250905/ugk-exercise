import 'package:flutter/material.dart';

/// Direction the pushed page slides in from, mirroring the on-screen position
/// of the entry that triggered it — like swiping between home-screen panes.
enum PageEnterDirection {
  /// Page slides in from the trailing (right) edge. Use for entries on the
  /// right half of the screen (e.g. the today summary button).
  right,

  /// Page slides in from the leading (left) edge. Use for entries on the left
  /// half of the screen (e.g. the profile avatar).
  left,

  /// Page slides up from the bottom edge. Use for entries in the lower half
  /// of the screen (e.g. the sports plaza card).
  bottom,
}

/// Pushes a full-screen route whose transition casts **no elevation shadow**.
///
/// The default [MaterialPageRoute] wraps the pushed page in a physical model
/// that draws a drop shadow during the push/pop transition. While the previous
/// route is still visible underneath, that shadow sweeps across its widgets and
/// looks like each of them briefly "flashes" a shadow on return — a long-standing
/// Flutter behavior (see flutter/flutter#72501).
///
/// This helper keeps a clean slide (no fade, no shadow) and uses
/// [PageRouteBuilder], which does not apply an elevation, so no shadow is cast
/// over the previous route. The slide direction follows [direction] so it
/// matches the entry's position on screen. iOS-style back gestures are not
/// provided; this is an Android-first app.
Future<T?> pushWithoutShadow<T>(
  BuildContext context,
  WidgetBuilder builder, {
  PageEnterDirection direction = PageEnterDirection.right,
  bool fullscreenDialog = false,
}) {
  // begin offset: enter from the chosen edge. The page ends at Offset.zero.
  final begin = switch (direction) {
    PageEnterDirection.left => const Offset(-1.0, 0.0),
    PageEnterDirection.bottom => const Offset(0.0, 1.0),
    PageEnterDirection.right => const Offset(1.0, 0.0),
  };
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Pure slide, no fade, no elevation / physical model → no shadow over
        // the previous route.
        final position = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(position),
          child: child,
        );
      },
    ),
  );
}
