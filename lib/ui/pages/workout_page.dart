// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../control/workout_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/recognition_trace_log.dart';
import '../../product/exercise_type.dart';
import '../../product/workout_session_store.dart';
import '../app_settings.dart';
import '../app_theme.dart';
import '../pose_feedback/movenet_pose_adapter.dart';
import '../pose_feedback/pose_silhouette_overlay.dart';

String _localizedWorkoutStatus(AppLocalizations l10n, WorkoutStatus status) {
  return switch (status) {
    WorkoutStatus.loading => l10n.workoutStatusLoading,
    WorkoutStatus.loadingModel => l10n.workoutStatusLoadingModel,
    WorkoutStatus.startingCamera => l10n.workoutStatusStartingCamera,
    WorkoutStatus.positionGuide => l10n.workoutStatusPositionGuide,
    WorkoutStatus.startupError => l10n.workoutStatusStartupError,
    WorkoutStatus.switchingCamera => l10n.workoutStatusSwitchingCamera,
    WorkoutStatus.cameraError => l10n.workoutStatusCameraError,
    WorkoutStatus.cameraPermissionDenied => l10n.workoutCameraPermissionDenied,
    WorkoutStatus.cameraPermissionSettings =>
      l10n.workoutCameraPermissionSettings,
    WorkoutStatus.saving => l10n.workoutStatusSaving,
    WorkoutStatus.holdPose => l10n.workoutStatusHoldPose,
    WorkoutStatus.narrowForm => l10n.workoutStatusNarrowForm,
    WorkoutStatus.readyToStart => l10n.workoutStatusReady,
    WorkoutStatus.fullPose => l10n.workoutStatusFullPose,
    WorkoutStatus.training => l10n.workoutStatusTraining,
    WorkoutStatus.frameError => l10n.workoutStatusFrameError,
    WorkoutStatus.saveFailed => l10n.workoutStatusSaveFailed,
  };
}

class WorkoutPage extends StatefulWidget {
  WorkoutPage({
    super.key,
    required this.store,
    required this.settingsController,
    this.exerciseType = ExerciseType.pushup,
    this.recognitionTraceEnabled = false,
    this.controller,
    this.syncController,
    this.cameraNoticeAcknowledged,
    this.acknowledgeCameraNotice,
  }) {
    final controllerExerciseType = controller?.exerciseType;
    if (controllerExerciseType != null &&
        controllerExerciseType != exerciseType) {
      throw ArgumentError.value(
        controllerExerciseType,
        'controller',
        'The injected controller exercise type must match exerciseType.',
      );
    }
  }

  final WorkoutSessionStore store;
  final ExerciseType exerciseType;
  final AppSettingsController settingsController;
  final bool recognitionTraceEnabled;
  final WorkoutController? controller;
  final WorkoutSyncController? syncController;
  final Future<bool> Function()? cameraNoticeAcknowledged;
  final Future<void> Function()? acknowledgeCameraNotice;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  late final WorkoutController _controller;
  late WorkoutStatus _coachStatus;
  WorkoutStatus? _pendingCoachStatus;
  Timer? _coachStatusTimer;
  WorkoutSession? _pendingSession;
  var _saveFailed = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        WorkoutController(
          exerciseType: widget.exerciseType,
          voiceBaseDir: voicePromptBaseDirFor(
            widget.settingsController.language,
            WidgetsBinding.instance.platformDispatcher.locale,
          ),
          trace: RecognitionTraceLog(enabled: widget.recognitionTraceEnabled),
        );
    _coachStatus = _controller.status;
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_showCameraNotice()),
    );
  }

  Future<void> _showCameraNotice() async {
    final acknowledged = await widget.cameraNoticeAcknowledged?.call() ?? false;
    if (!mounted) return;
    if (acknowledged) {
      unawaited(_controller.start());
      return;
    }
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.workoutCameraNoticeTitle),
          content: Text(l10n.workoutCameraNoticeBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.workoutCameraNoticeCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.workoutCameraNoticeStart),
            ),
          ],
        ),
      ),
    );
    final shouldStart = await navigator.push(route) ?? false;
    await route.completed;
    if (shouldStart) {
      await widget.acknowledgeCameraNotice?.call();
    }
    if (mounted && shouldStart) {
      unawaited(_controller.start());
    }
  }

  void _onChanged() {
    final nextStatus = _controller.status;
    if (nextStatus == _coachStatus) {
      _cancelPendingCoachStatus();
    } else if (_isNarrowPreparationTransition(_coachStatus, nextStatus)) {
      _scheduleCoachStatus(nextStatus);
    } else {
      _cancelPendingCoachStatus();
      _coachStatus = nextStatus;
    }
    setState(() {});
  }

  bool _isNarrowPreparationTransition(
    WorkoutStatus current,
    WorkoutStatus next,
  ) {
    return (current == WorkoutStatus.narrowForm &&
            next == WorkoutStatus.holdPose) ||
        (current == WorkoutStatus.holdPose && next == WorkoutStatus.narrowForm);
  }

  void _scheduleCoachStatus(WorkoutStatus status) {
    if (_pendingCoachStatus == status) {
      return;
    }
    _coachStatusTimer?.cancel();
    _pendingCoachStatus = status;
    _coachStatusTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted ||
          _pendingCoachStatus != status ||
          _controller.status != status) {
        return;
      }
      setState(() {
        _coachStatus = status;
        _pendingCoachStatus = null;
        _coachStatusTimer = null;
      });
    });
  }

  void _cancelPendingCoachStatus() {
    _coachStatusTimer?.cancel();
    _coachStatusTimer = null;
    _pendingCoachStatus = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = _controller.camera.controller;
    final showPreview =
        !_controller.stopping &&
        !_controller.switchingCamera &&
        controller != null &&
        controller.value.isInitialized;
    final canStop =
        !_saving && (_controller.running || _pendingSession != null);
    final workoutStatus = _saveFailed
        ? WorkoutStatus.saveFailed
        : _saving
        ? WorkoutStatus.saving
        : _coachStatus;
    final status = _localizedWorkoutStatus(l10n, workoutStatus);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = widget.exerciseType == ExerciseType.narrowPushup
        ? (isDark ? sky : homeNarrowAccent)
        : colorScheme.primary;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? darkCanvas : ink,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final preferredCardHeight = (constraints.maxHeight * 0.38)
                .clamp(268.0, 348.0)
                .toDouble();
            final minimumCardHeight =
                240.0 + MediaQuery.paddingOf(context).bottom;
            final cardHeight = preferredCardHeight < minimumCardHeight
                ? minimumCardHeight
                : preferredCardHeight;
            return Stack(
              children: [
                Positioned.fill(
                  bottom: cardHeight - 24,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
                    child: Container(
                      key: const ValueKey('workout-camera-stage'),
                      color: isDark ? darkCanvas : ink,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (showPreview) CameraPreview(controller),
                          if (showPreview)
                            PoseSilhouetteOverlay(
                              observation: moveNetHeadShoulderObservation(
                                keypoints: _controller.keypoints,
                                sourceSize: _controller.sourceSize,
                                at: DateTime.now(),
                              ),
                            ),
                          if (showPreview)
                            const IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0x66000000),
                                      Color(0x14000000),
                                      Colors.transparent,
                                    ],
                                    stops: [0, 0.38, 0.72],
                                  ),
                                ),
                              ),
                            ),
                          if (!showPreview)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(color: lime),
                                  const SizedBox(height: 18),
                                  Text(
                                    _controller.stopping
                                        ? l10n.workoutSavingTraining
                                        : l10n.workoutStartingCamera,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SafeArea(
                            bottom: false,
                            child: Stack(
                              children: [
                                const Positioned(
                                  left: 18,
                                  top: 14,
                                  child: _CameraBackButton(),
                                ),
                                Positioned(
                                  right: 18,
                                  top: 14,
                                  child: PopupMenuButton<CameraDescription>(
                                    key: const ValueKey(
                                      'workout-camera-picker',
                                    ),
                                    tooltip: l10n.workoutSelectCamera,
                                    color: colorScheme.surface,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    onSelected: _switchCamera,
                                    itemBuilder: (context) {
                                      if (_controller.cameras.isEmpty) {
                                        return [
                                          PopupMenuItem<CameraDescription>(
                                            enabled: false,
                                            child: Text(
                                              l10n.workoutCameraLoading,
                                            ),
                                          ),
                                        ];
                                      }
                                      return [
                                        for (final camera
                                            in _controller.cameras)
                                          PopupMenuItem<CameraDescription>(
                                            value: camera,
                                            enabled: !_sameCamera(
                                              camera,
                                              _controller.selectedCamera,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _cameraIcon(
                                                    camera.lensDirection,
                                                  ),
                                                  color: colorScheme.onSurface,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _cameraLabel(camera, l10n),
                                                    style: TextStyle(
                                                      color:
                                                          colorScheme.onSurface,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (_sameCamera(
                                                  camera,
                                                  _controller.selectedCamera,
                                                ))
                                                  Icon(
                                                    Icons.check_rounded,
                                                    color: colorScheme.primary,
                                                    size: 20,
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ];
                                    },
                                    icon: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: const BoxDecoration(
                                        color: Color(0x66000000),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.tune_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    enabled: !_controller.switchingCamera,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: cardHeight + 12,
                  child: Center(
                    child: _WorkoutCoachBar(
                      key: const ValueKey('workout-coach-bar'),
                      label: status,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: _WorkoutCountPanel(
                    count: _controller.count,
                    accent: accent,
                    onStop: canStop ? _onStopPressed : null,
                    stopLabel: _pendingSession == null
                        ? l10n.workoutEnd
                        : l10n.workoutRetrySave,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _switchCamera(CameraDescription camera) {
    return _controller.switchCamera(camera);
  }

  Future<void> _onStopPressed() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      var session = _pendingSession;
      if (session == null) {
        final ownerAppUserId = widget.syncController?.currentOwnerAppUserId;
        await _controller.stop();
        final endedAt = DateTime.now();
        final startedAt = _controller.startedAt ?? endedAt;
        final localStartedAt = startedAt.toLocal();
        session = WorkoutSession(
          id: endedAt.microsecondsSinceEpoch.toString(),
          startedAt: startedAt.toUtc(),
          endedAt: endedAt.toUtc(),
          count: _controller.count,
          exerciseType: _controller.exerciseType.storageValue,
          localDate: DateTime(
            localStartedAt.year,
            localStartedAt.month,
            localStartedAt.day,
          ),
          timezoneOffsetMinutes: localStartedAt.timeZoneOffset.inMinutes,
          ownerAppUserId: ownerAppUserId,
        );
        _pendingSession = session;
      }
      await widget.store.append(session);
      try {
        await widget.syncController?.queueAfterLocalSave(session.id);
      } catch (_) {
        // Cloud sync must not block local workout completion.
      }
      _pendingSession = null;
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  IconData _cameraIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.front:
        return Icons.camera_front_rounded;
      case CameraLensDirection.back:
        return Icons.camera_rear_rounded;
      case CameraLensDirection.external:
        return Icons.videocam_rounded;
    }
  }

  String _cameraLabel(CameraDescription camera, AppLocalizations l10n) {
    final direction = switch (camera.lensDirection) {
      CameraLensDirection.front => l10n.workoutCameraFront,
      CameraLensDirection.back => l10n.workoutCameraRear,
      CameraLensDirection.external => l10n.workoutCameraExternal,
    };
    final firstSameDirection = _controller.cameras.firstWhere(
      (item) => item.lensDirection == camera.lensDirection,
      orElse: () => camera,
    );
    final type = _looksWide(camera)
        ? l10n.workoutCameraWide
        : _sameCamera(firstSameDirection, camera)
        ? l10n.workoutCameraNormal
        : l10n.workoutCameraBackup(camera.name);
    return l10n.workoutCameraLabel(direction, type);
  }

  bool _looksWide(CameraDescription camera) {
    final name = camera.name.toLowerCase();
    return name.contains('wide') ||
        name.contains('ultra') ||
        name.contains('0.5') ||
        name.contains('uw');
  }

  bool _sameCamera(CameraDescription camera, CameraDescription? other) {
    return other != null &&
        camera.name == other.name &&
        camera.lensDirection == other.lensDirection;
  }

  @override
  void dispose() {
    _coachStatusTimer?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }
}

class _WorkoutCoachBar extends StatelessWidget {
  const _WorkoutCoachBar({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? darkRaisedSurface : lightRaisedSurface;
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 16,
      height: 1.25,
    );
    final reservedTextHeight =
        MediaQuery.textScalerOf(context).scale(textStyle?.fontSize ?? 16) *
        (textStyle?.height ?? 1) *
        2;
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 48,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: isDark ? 0.94 : 0.96),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [isDark ? darkSurfaceShadow : lightSurfaceShadow],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: reservedTextHeight),
                  child: Align(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutCountPanel extends StatelessWidget {
  const _WorkoutCountPanel({
    required this.count,
    required this.accent,
    required this.onStop,
    required this.stopLabel,
  });

  final int count;
  final Color accent;
  final VoidCallback? onStop;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? darkPanel : lightRaisedSurface;
    final tintedSurface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.18 : 0.12),
      surface,
    );
    return Container(
      key: const ValueKey('workout-count-panel'),
      padding: EdgeInsets.fromLTRB(24, 18, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surface, tintedSurface],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [isDark ? darkSurfaceShadow : lightSurfaceShadow],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final haloSize = (constraints.maxHeight * 0.62)
              .clamp(128.0, 170.0)
              .toDouble();
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Semantics(
                    key: const ValueKey('workout-count-semantics'),
                    label: '$count ${l10n.workoutCountUnit}',
                    child: ExcludeSemantics(
                      child: Container(
                        key: const ValueKey('workout-count-halo'),
                        width: haloSize,
                        height: haloSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: isDark ? 0.22 : 0.16),
                              accent.withValues(alpha: 0.02),
                            ],
                          ),
                          border: Border.all(
                            color: accent.withValues(
                              alpha: isDark ? 0.72 : 0.42,
                            ),
                            width: 5,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: haloSize * 0.72,
                                height: haloSize * 0.48,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$count',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 88,
                                      fontWeight: FontWeight.w900,
                                      height: 0.86,
                                      letterSpacing: -3,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                width: haloSize * 0.72,
                                height: haloSize * 0.18,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    l10n.workoutCountUnit,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 22),
                label: Text(stopLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: coral.withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                  elevation: 0,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CameraBackButton extends StatelessWidget {
  const _CameraBackButton();

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).maybePop();
    final tooltip = MaterialLocalizations.of(context).closeButtonTooltip;
    return Semantics(
      key: const ValueKey('workout-close-semantics'),
      button: true,
      label: tooltip,
      onTap: close,
      child: ExcludeSemantics(
        child: IconButton(
          key: const ValueKey('workout-close-control'),
          onPressed: close,
          tooltip: tooltip,
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x66000000),
            foregroundColor: Colors.white,
            fixedSize: const Size(48, 48),
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}
