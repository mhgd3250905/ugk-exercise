// Extracted from main.dart during architecture refactor.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../control/workout_controller.dart';
import '../../control/workout_sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../product/workout_session_store.dart';
import '../app_theme.dart';
import '../overlay_renderer.dart';

String _localizedWorkoutStatus(AppLocalizations l10n, String status) {
  return switch (status) {
    '加载中' => l10n.workoutStatusLoading,
    '加载模型' => l10n.workoutStatusLoadingModel,
    '启动相机' => l10n.workoutStatusStartingCamera,
    '请按提示摆放手机并保持姿势' => l10n.workoutStatusPositionGuide,
    '已准备好，请开始训练' => l10n.workoutStatusReady,
    '请保持俯卧撑姿势并稳定入镜' => l10n.workoutStatusHoldPose,
    '请保持俯卧撑姿势并完整入镜' => l10n.workoutStatusFullPose,
    '训练中' => l10n.workoutStatusTraining,
    '切换相机' => l10n.workoutStatusSwitchingCamera,
    '保存中' => l10n.workoutStatusSaving,
    _ when status.startsWith('保存失败：') => l10n.workoutStatusSaveFailed,
    _ => l10n.workoutStatusError,
  };
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({
    super.key,
    required this.store,
    this.controller,
    this.syncController,
  });

  final WorkoutSessionStore store;
  final WorkoutController? controller;
  final WorkoutSyncController? syncController;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  late final WorkoutController _controller;
  WorkoutSession? _pendingSession;
  String? _saveError;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? WorkoutController();
    _controller.addListener(_onChanged);
    unawaited(_controller.start());
  }

  void _onChanged() {
    setState(() {});
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
    final status = _localizedWorkoutStatus(
      l10n,
      _saveError ?? (_saving ? '保存中' : _controller.status),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        backgroundColor: ink,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = (constraints.maxHeight * 0.4)
                .clamp(330.0, 370.0)
                .toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  bottom: cardHeight - 28,
                  child: Container(
                    color: ink,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showPreview) CameraPreview(controller),
                        if (showPreview)
                          CustomPaint(
                            painter: OverlayRenderer(
                              keypoints: _controller.keypoints,
                              sourceSize: _controller.sourceSize,
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
                                top: 18,
                                child: _CameraBackButton(),
                              ),
                              Positioned(
                                top: 22,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _WorkoutChip(
                                    label: _controller.ready
                                        ? l10n.workoutReady
                                        : l10n.workoutPreparing,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 26,
                                top: 28,
                                child: PopupMenuButton<CameraDescription>(
                                  tooltip: l10n.workoutSelectCamera,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
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
                                      for (final camera in _controller.cameras)
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
                                                color: ink,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _cameraLabel(camera, l10n),
                                                  style: const TextStyle(
                                                    color: ink,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (_sameCamera(
                                                camera,
                                                _controller.selectedCamera,
                                              ))
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: greenDark,
                                                  size: 20,
                                                ),
                                            ],
                                          ),
                                        ),
                                    ];
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    color: Colors.white,
                                    size: 28,
                                    shadows: [
                                      Shadow(
                                        color: Color(0x88000000),
                                        blurRadius: 8,
                                      ),
                                    ],
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: _WorkoutCountPanel(
                    count: _controller.count,
                    status: status,
                    ready: _controller.ready,
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
      _saveError = null;
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
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = '保存失败：$error';
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
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }
}

class _WorkoutChip extends StatelessWidget {
  const _WorkoutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xDFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCountPanel extends StatelessWidget {
  const _WorkoutCountPanel({
    required this.count,
    required this.status,
    required this.ready,
    required this.onStop,
    required this.stopLabel,
  });

  final int count;
  final String status;
  final bool ready;
  final VoidCallback? onStop;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = (count > 30 ? 30 : count) / 30;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 34 + bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A17261F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _WorkoutStat(
                    label: l10n.workoutTodayGoal,
                    value: l10n.workoutGoalValue(100),
                    valueColor: green,
                  ),
                ),
                SizedBox.square(
                  dimension: 154,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFFFF8C9),
                          color: green,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 66,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 4),
                            child: Text(
                              l10n.workoutCountUnit,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _WorkoutStat(
                    label: l10n.workoutBurned,
                    value: l10n.workoutCaloriesValue(32),
                    icon: Icons.local_fire_department_rounded,
                    valueColor: const Color(0xFFFF7A21),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: Text(stopLabel),
            style: FilledButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutStat extends StatelessWidget {
  const _WorkoutStat({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor = ink,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 20, color: valueColor),
            if (icon != null) const SizedBox(width: 2),
            Flexible(
              child: Text(
                value,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: valueColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraBackButton extends StatelessWidget {
  const _CameraBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(
        Icons.close_rounded,
        shadows: [Shadow(color: Color(0x88000000), blurRadius: 8)],
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        fixedSize: const Size(46, 46),
        shape: const CircleBorder(),
      ),
    );
  }
}
