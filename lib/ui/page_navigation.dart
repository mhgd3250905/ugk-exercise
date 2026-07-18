import 'package:flutter/material.dart';

/// Pushes a full-screen route whose transition casts **no elevation shadow**.
///
/// The default [MaterialPageRoute] wraps the pushed page in a physical model
/// that draws a drop shadow during the push/pop transition. While the previous
/// route is still visible underneath, that shadow sweeps across its widgets and
/// looks like each of them briefly "flashes" a shadow on return — a long-standing
/// Flutter behavior (see flutter/flutter#72501).
///
/// This helper keeps the familiar forward-slide + fade feel but uses
/// [PageRouteBuilder], which does not apply an elevation, so no shadow is cast
/// over the previous route. iOS-style back gestures are not provided; this is
/// an Android-first app.
Future<T?> pushWithoutShadow<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide in from the trailing edge (Material forward navigation) plus a
        // gentle fade. No elevation / physical model → no shadow over the
        // previous route.
        final position = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(position),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    ),
  );
}
