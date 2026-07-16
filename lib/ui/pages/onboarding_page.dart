import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';

const _minimumStartupDuration = Duration(milliseconds: 1200);

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({
    super.key,
    required this.startup,
    required this.completeOnboarding,
    required this.home,
    this.firstFrameRasterized,
  });

  final Future<bool> startup;
  final Future<void> Function() completeOnboarding;
  final Widget home;
  final Future<void>? firstFrameRasterized;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  late final Future<void> _firstFrameRasterized;
  late final Future<bool> _startup;
  var _completedInThisRun = false;

  @override
  void initState() {
    super.initState();
    _firstFrameRasterized =
        widget.firstFrameRasterized ??
        WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    _startup = Future.wait<bool>([
      widget.startup,
      _firstFrameRasterized.then(
        (_) => Future<bool>.delayed(_minimumStartupDuration, () => true),
      ),
    ]).then((results) => results.first);
  }

  @override
  Widget build(BuildContext context) {
    if (_completedInThisRun) return _themedSystemBars(context, widget.home);
    return FutureBuilder<bool>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingPage();
        }
        if (snapshot.hasError || snapshot.data == true) {
          return _themedSystemBars(context, widget.home);
        }
        return OnboardingPage(onComplete: _complete);
      },
    );
  }

  Future<void> _complete() async {
    setState(() => _completedInThisRun = true);
    try {
      await widget.completeOnboarding();
    } catch (_) {}
  }

  Widget _themedSystemBars(BuildContext context, Widget child) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child,
    );
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: startupBackground,
        systemNavigationBarColor: startupBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: const ValueKey('app-startup-loading'),
        backgroundColor: startupBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Semantics(
                    label: 'PushupAI',
                    image: true,
                    child: Image.asset(
                      'assets/images/startup_lockup.png',
                      key: const ValueKey('startup-lockup'),
                      width: 288,
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, 84),
                    child: TweenAnimationBuilder<double>(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, opacity, child) => Opacity(
                        key: const ValueKey('startup-slogan-opacity'),
                        opacity: opacity,
                        child: child,
                      ),
                      child: Text(
                        l10n.startupSlogan,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pages = [
      _OnboardingContent(
        icon: Icons.auto_awesome_rounded,
        title: l10n.onboardingCountTitle,
        body: l10n.onboardingCountBody,
      ),
      _OnboardingContent(
        icon: Icons.phone_android_rounded,
        title: l10n.onboardingSetupTitle,
        body: l10n.onboardingSetupBody,
      ),
      _OnboardingContent(
        icon: Icons.privacy_tip_rounded,
        title: l10n.onboardingPrivacyTitle,
        body: l10n.onboardingPrivacyBody,
      ),
    ];
    return Scaffold(
      key: const ValueKey('app-onboarding'),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              dark ? darkHomeGradientTop : homeGradientTop,
              dark ? darkHomeGradientBottom : homeGradientBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text(l10n.onboardingSkip),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < pages.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: FilledButton(
                  onPressed: _page == pages.length - 1
                      ? widget.onComplete
                      : _next,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(
                    _page == pages.length - 1
                        ? l10n.onboardingStart
                        : l10n.onboardingNext,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(_page + 1);
      return;
    }
    unawaited(
      _pageController.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutQuart,
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BrandMark(size: 118, icon: icon),
          const SizedBox(height: 38),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size, this.icon = Icons.fitness_center});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [green, lime]),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.48, color: ink),
    );
  }
}
