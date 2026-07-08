import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'control/camera_calibration.dart';
import 'control/replay_control.dart';
import 'inference/keypoint_log.dart';
import 'inference/pose_estimator.dart';
import 'perf/performance_meter.dart';
import 'pipeline/frame_pipeline.dart';
import 'pipeline/yuv420.dart';
import 'platform/camera_service.dart';
import 'platform/ffmpeg_kit_runner.dart';
import 'platform/report_directory.dart';
import 'platform/video_replay_service.dart';
import 'product/ready_pose_gate.dart';
import 'product/voice_prompt_player.dart';
import 'product/workout_session_store.dart';
import 'pushup_domain.dart';
import 'report/performance_report.dart';
import 'ui/overlay_renderer.dart';
import 'ui/perf_panel.dart';

const _modelPath = 'assets/models/movenet_singlepose_lightning_int8_4.tflite';
const _replayVideoName = '俯卧撑.mp4';
const _ink = Color(0xFF17261F);
const _muted = Color(0xFF6D7D72);
const _canvas = Color(0xFFF3FAF2);
const _panel = Color(0xFFFFFFFF);
const _line = Color(0xFFDCEBDF);
const _green = Color(0xFF42C96B);
const _greenDark = Color(0xFF118C4F);
const _lime = Color(0xFFB7EA4C);
const _sky = Color(0xFF43B7FF);
const _coral = Color(0xFFFF4F55);
const _yellow = Color(0xFFFFD84D);

void main() {
  runApp(const UgkExerciseApp());
}

class UgkExerciseApp extends StatelessWidget {
  const UgkExerciseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '俯卧撑检测',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _greenDark,
          secondary: _sky,
          surface: _panel,
        ),
        scaffoldBackgroundColor: _canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: _canvas,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: _ink,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
          headlineSmall: TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
          titleLarge: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          titleMedium: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
          bodyMedium: TextStyle(color: _muted, fontSize: 15, height: 1.35),
          labelLarge: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = WorkoutSessionStore();
  var _todayTotal = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshTodayTotal());
  }

  Future<void> _refreshTodayTotal() async {
    final total = await _store.totalForLocalDate(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() => _todayTotal = total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FCF3), Color(0xFFEAF5ED)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIconButton(
                      icon: Icons.person_rounded,
                      tooltip: '个人信息',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfilePlaceholderPage(),
                          ),
                        );
                      },
                    ),
                    _TodayButton(
                      count: _todayTotal,
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RecordsPage(store: _store),
                          ),
                        );
                        await _refreshTodayTotal();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _ExerciseCard(
                  todayCount: _todayTotal,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutPage(store: _store),
                      ),
                    );
                    await _refreshTodayTotal();
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TestModePage(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xB3FFFFFF),
                      foregroundColor: _ink,
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.science_rounded),
                    label: const Text('测试模式'),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: _panel,
        foregroundColor: _ink,
        fixedSize: const Size(54, 54),
        side: const BorderSide(color: _line),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: const Icon(Icons.calendar_month_rounded, size: 20),
      label: Text('今日 $count'),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.todayCount, required this.onPressed});

  final int todayCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3317261F),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16261F), Color(0xFF244736)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -54,
              top: -46,
              child: Container(
                width: 184,
                height: 184,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2242C96B),
                ),
              ),
            ),
            Positioned(
              left: -36,
              bottom: -46,
              child: Container(
                width: 148,
                height: 148,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1A43B7FF),
                ),
              ),
            ),
            Positioned(
              right: 26,
              top: 60,
              child: Transform.rotate(
                angle: -0.18,
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xCC43B7FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 124,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xCCB7EA4C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _HeroBadge(
                        icon: Icons.auto_awesome_rounded,
                        label: 'AI 姿态识别',
                      ),
                      const Spacer(),
                      Text(
                        '目标 100',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 58),
                  const Text(
                    '俯卧撑训练',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI 姿态识别 · 自动计数 · 中文播报\n今日已完成 $todayCount 次',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('开始训练'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: _ink,
                      minimumSize: const Size.fromHeight(58),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: _lime),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePlaceholderPage extends StatelessWidget {
  const ProfilePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _yellow,
                    child: Icon(Icons.person_rounded, size: 40, color: _ink),
                  ),
                  SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '训练者',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '本机训练数据',
                          style: TextStyle(color: Color(0xFFCFE6D7)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _line),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: _greenDark),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '个人信息同步会在后续版本开放。当前版本只在本机保存训练次数。',
                      style: TextStyle(color: _muted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.store});

  final WorkoutSessionStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final leadingEmptyCells = firstDay.weekday % 7;
    return Scaffold(
      appBar: AppBar(title: const Text('训练记录')),
      body: FutureBuilder<Map<DateTime, int>>(
        future: store.totalsByLocalDate(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _greenDark),
            );
          }
          final totals = snapshot.data!;
          final monthEntries = totals.entries.where(
            (entry) =>
                entry.key.year == now.year && entry.key.month == now.month,
          );
          final monthTotal = monthEntries.fold<int>(
            0,
            (total, entry) => total + entry.value,
          );
          final activeDays = monthEntries
              .where((entry) => entry.value > 0)
              .length;
          final bestDay = monthEntries.fold<int>(
            0,
            (best, entry) => entry.value > best ? entry.value : best,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _CalendarModePill()),
                const SizedBox(height: 18),
                Text(
                  '${now.year}年${now.month}月',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    _WeekdayLabel('日'),
                    _WeekdayLabel('一'),
                    _WeekdayLabel('二'),
                    _WeekdayLabel('三'),
                    _WeekdayLabel('四'),
                    _WeekdayLabel('五'),
                    _WeekdayLabel('六'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 420,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leadingEmptyCells + daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) {
                      if (index < leadingEmptyCells) {
                        return const SizedBox.shrink();
                      }
                      final dayNumber = index - leadingEmptyCells + 1;
                      final day = DateTime(now.year, now.month, dayNumber);
                      return _RecordDayCell(
                        day: dayNumber,
                        total: totals[day] ?? 0,
                        isToday: dayNumber == now.day,
                      );
                    },
                  ),
                ),
                const _CalendarLegend(),
                const SizedBox(height: 18),
                _MonthSummaryCard(
                  activeDays: activeDays,
                  monthTotal: monthTotal,
                  bestDay: bestDay,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalendarModePill extends StatelessWidget {
  const _CalendarModePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarModeText('周'),
          _CalendarModeText('月', selected: true),
          _CalendarModeText('年'),
        ],
      ),
    );
  }
}

class _CalendarModeText extends StatelessWidget {
  const _CalendarModeText(this.text, {this.selected = false});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: selected ? _green : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x332ACF7A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : _muted,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RecordDayCell extends StatelessWidget {
  const _RecordDayCell({
    required this.day,
    required this.total,
    required this.isToday,
  });

  final int day;
  final int total;
  final bool isToday;

  Color get _color {
    if (total >= 100) {
      return const Color(0xFFFF922E);
    }
    if (total >= 50) {
      return _yellow;
    }
    return const Color(0xFFDDF4C9);
  }

  @override
  Widget build(BuildContext context) {
    final hasTotal = total > 0;
    return Container(
      decoration: BoxDecoration(
        color: hasTotal ? _color : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: _greenDark, width: 3) : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: hasTotal ? _ink : _muted,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (hasTotal)
              Text(
                '$total',
                style: const TextStyle(
                  color: _greenDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Color(0xFFDDF4C9), label: '1-49'),
        SizedBox(width: 18),
        _LegendItem(color: _yellow, label: '50-99'),
        SizedBox(width: 18),
        _LegendItem(color: Color(0xFFFF922E), label: '100+'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.activeDays,
    required this.monthTotal,
    required this.bestDay,
  });

  final int activeDays;
  final int monthTotal;
  final int bestDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          _SummaryValue(label: '训练天数', value: '$activeDays 天'),
          const _SummaryDivider(),
          _SummaryValue(label: '总个数', value: '$monthTotal 个'),
          const _SummaryDivider(),
          _SummaryValue(label: '最高单日', value: '$bestDay 个'),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: _line);
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
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
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
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
  });

  final int count;
  final String status;
  final bool ready;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final progress = (count > 30 ? 30 : count) / 30;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 34 + bottomPadding),
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A17261F),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: _WorkoutStat(
                  label: '今日目标',
                  value: '100 个',
                  valueColor: _green,
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
                        color: _green,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 66,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 4),
                          child: Text(
                            '个',
                            style: TextStyle(
                              color: _muted,
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
              const Expanded(
                child: _WorkoutStat(
                  label: '消耗',
                  value: '32 千卡',
                  icon: Icons.local_fire_department_rounded,
                  valueColor: Color(0xFFFF7A21),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: _greenDark),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _greenDark,
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
            label: const Text('结束训练'),
            style: FilledButton.styleFrom(
              backgroundColor: _coral,
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
    this.valueColor = _ink,
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

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.store});

  final WorkoutSessionStore store;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final _camera = CameraService();
  final _pose = PoseEstimator();
  final _counter = PushupCounter(
    config: const CounterConfig(frameHeight: 1280, fps: 30),
  );
  final _filter = SignalFilter(window: 5);
  final _extractor = const SignalExtractor();
  final _calibration = CameraCalibration();
  final _readyGate = ReadyPoseGate();
  final _voice = VoicePromptPlayer();

  StreamSubscription<CameraImage>? _subscription;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  DateTime? _startedAt;
  var _session = 0;
  var _running = false;
  var _stopping = false;
  var _switchingCamera = false;
  var _busy = false;
  var _ready = false;
  var _count = 0;
  var _status = '加载中';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    final showPreview =
        !_stopping &&
        !_switchingCamera &&
        controller != null &&
        controller.value.isInitialized;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _ink,
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
                    color: _ink,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showPreview) CameraPreview(controller),
                        if (showPreview)
                          CustomPaint(
                            painter: OverlayRenderer(
                              keypoints: _keypoints,
                              sourceSize: _sourceSize,
                            ),
                          ),
                        if (!showPreview)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: _lime),
                                const SizedBox(height: 18),
                                Text(
                                  _stopping ? '正在保存训练' : '正在启动相机',
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
                                    label: _ready ? '已准备' : '准备中',
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 26,
                                top: 28,
                                child: PopupMenuButton<CameraDescription>(
                                  tooltip: '选择摄像头',
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  onSelected: _switchCamera,
                                  itemBuilder: (context) {
                                    if (_cameras.isEmpty) {
                                      return const [
                                        PopupMenuItem<CameraDescription>(
                                          enabled: false,
                                          child: Text('相机加载中'),
                                        ),
                                      ];
                                    }
                                    return [
                                      for (final camera in _cameras)
                                        PopupMenuItem<CameraDescription>(
                                          value: camera,
                                          enabled: !_sameCamera(
                                            camera,
                                            _selectedCamera,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _cameraIcon(
                                                  camera.lensDirection,
                                                ),
                                                color: _ink,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _cameraLabel(camera),
                                                  style: const TextStyle(
                                                    color: _ink,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (_sameCamera(
                                                camera,
                                                _selectedCamera,
                                              ))
                                                const Icon(
                                                  Icons.check_rounded,
                                                  color: _greenDark,
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
                                  enabled: !_switchingCamera,
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
                    count: _count,
                    status: _status,
                    ready: _ready,
                    onStop: _running ? _stopAndSave : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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

  String _cameraLabel(CameraDescription camera) {
    final direction = switch (camera.lensDirection) {
      CameraLensDirection.front => '前置',
      CameraLensDirection.back => '后置',
      CameraLensDirection.external => '外接',
    };
    final firstSameDirection = _cameras.firstWhere(
      (item) => item.lensDirection == camera.lensDirection,
      orElse: () => camera,
    );
    final type = _looksWide(camera)
        ? '广角摄像头'
        : _sameCamera(firstSameDirection, camera)
        ? '正常摄像头'
        : '备用摄像头 ${camera.name}';
    return '$direction$type';
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

  CameraDescription _selectedOrDefaultCamera(List<CameraDescription> cameras) {
    final selected = _selectedCamera;
    if (selected != null) {
      for (final camera in cameras) {
        if (_sameCamera(camera, selected)) {
          return camera;
        }
      }
    }
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  Future<void> _start() async {
    final session = ++_session;
    _startedAt = DateTime.now();
    _running = true;
    _stopping = false;
    _switchingCamera = false;
    _busy = false;
    _ready = false;
    _count = 0;
    _counter.reset();
    _filter.reset();
    _readyGate.reset();
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '加载模型';
      });
    }
    try {
      await _pose.load(assetPath: _modelPath, mode: DelegateMode.nnapi);
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      if (mounted) {
        setState(() => _status = '启动相机');
      }
      final cameras = await _camera.listCameras();
      if (session != _session) {
        await _pose.dispose();
        return;
      }
      await _camera.initialize(camera: _selectedOrDefaultCamera(cameras));
      if (session != _session) {
        await _camera.dispose();
        await _pose.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      unawaited(_voice.playGuide());
      if (mounted) {
        setState(() {
          _cameras = cameras;
          _selectedCamera = _camera.description;
          _status = '请按提示摆放手机并保持姿势';
        });
      }
    } catch (error) {
      if (session != _session) {
        return;
      }
      _running = false;
      _stopping = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      if (mounted) {
        setState(() => _status = '错误：$error');
      }
    }
  }

  Future<void> _switchCamera(CameraDescription camera) async {
    if (!_running || _switchingCamera || _sameCamera(camera, _selectedCamera)) {
      return;
    }
    final session = ++_session;
    _switchingCamera = true;
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '切换相机';
      });
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _waitForFramePipelineToIdle();
      await _camera.dispose();
      if (session != _session) {
        return;
      }
      await _camera.initialize(camera: camera);
      if (session != _session) {
        await _camera.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      if (mounted) {
        setState(() {
          _selectedCamera = _camera.description;
          _switchingCamera = false;
          _status = '请按提示摆放手机并保持姿势';
        });
      } else {
        _switchingCamera = false;
      }
    } catch (error) {
      if (session != _session) {
        return;
      }
      _running = false;
      _switchingCamera = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      if (mounted) {
        setState(() => _status = '相机错误：$error');
      }
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _switchingCamera || _busy || image.planes.length < 3) {
      return;
    }
    _busy = true;
    final session = _session;
    try {
      final rawRgb = yuv420ToRgb(
        width: image.width,
        height: image.height,
        yPlane: image.planes[0].bytes,
        uPlane: image.planes[1].bytes,
        vPlane: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      );
      final rgb = orientRgbFrame(
        rawRgb,
        rotationDegrees: _calibration.rotationFor(_camera.sensorOrientation),
        mirrorX: _calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing),
      );
      final input = _pose.pipeline.preprocess(rgb, target: _pose.target);
      final keypoints = await _pose.infer(input);
      if (session != _session) {
        return;
      }

      final frameWidth = rgb.width.toDouble();
      final frameHeight = rgb.height.toDouble();
      var status = _status;
      var count = _count;
      if (!_ready) {
        final ready = _readyGate.update(
          keypoints: keypoints,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          at: DateTime.now(),
        );
        if (ready) {
          _ready = true;
          _counter.reset();
          _filter.reset();
          count = 0;
          status = '已准备好，请开始训练';
          unawaited(_voice.playReady());
        } else {
          status = '请保持俯卧撑姿势并稳定入镜';
        }
      } else {
        final signals = _filter.smooth(_extractor.toSignals(keypoints));
        final oldCount = _count;
        final state = _counter.update(signals);
        count = state.count;
        if (count > oldCount && count <= 30) {
          unawaited(_voice.playCount(count));
        }
        status = '训练中';
      }

      if (mounted && _running) {
        setState(() {
          _keypoints = keypoints;
          _sourceSize = Size(frameWidth, frameHeight);
          _count = count;
          _status = status;
        });
      }
    } catch (error) {
      if (session != _session) {
        return;
      }
      if (mounted) {
        setState(() => _status = '错误：$error');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _waitForFramePipelineToIdle() async {
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _disposeCameraAndPoseWhenIdle() async {
    await _waitForFramePipelineToIdle();
    await _camera.dispose();
    await _pose.dispose();
  }

  Future<void> _stopAndSave() async {
    if (!_running || _stopping) {
      return;
    }
    final endedAt = DateTime.now();
    final startedAt = _startedAt ?? endedAt;
    _stopping = true;
    _session++;
    _running = false;
    if (mounted) {
      setState(() => _status = '保存中');
      await WidgetsBinding.instance.endOfFrame;
    }
    await _voice.stop();
    await _subscription?.cancel();
    _subscription = null;
    await _waitForFramePipelineToIdle();
    await _camera.dispose();
    await _pose.dispose();
    await widget.store.append(
      WorkoutSession(
        id: endedAt.microsecondsSinceEpoch.toString(),
        startedAt: startedAt,
        endedAt: endedAt,
        count: _count,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _session++;
    _running = false;
    unawaited(_subscription?.cancel());
    unawaited(_disposeCameraAndPoseWhenIdle());
    unawaited(_voice.dispose());
    super.dispose();
  }
}

class TestModePage extends StatelessWidget {
  const TestModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('测试模式'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.movie), text: '离线回放'),
              Tab(icon: Icon(Icons.videocam), text: '实时相机'),
            ],
          ),
        ),
        body: const TabBarView(children: [OfflineReplayTab(), LiveCameraTab()]),
      ),
    );
  }
}

class OfflineReplayTab extends StatefulWidget {
  const OfflineReplayTab({super.key});

  @override
  State<OfflineReplayTab> createState() => _OfflineReplayTabState();
}

class _OfflineReplayTabState extends State<OfflineReplayTab> {
  final _replay = VideoReplayService(ffmpegRunner: runFfmpegKit);
  final _pose = PoseEstimator();
  final _meter = PerformanceMeter();
  final _control = ReplayControl();
  final _counter = PushupCounter(
    config: const CounterConfig(frameHeight: 1280, fps: 30),
  );
  final _filter = SignalFilter(window: 5);
  final _extractor = const SignalExtractor();

  ui.Image? _image;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  String? _selectedVideoPath;
  String? _lastLogPath;
  String? _lastPerfPath;
  var _count = 0;
  var _status = '待开始';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FrameOverlay(
              image: _image,
              keypoints: _keypoints,
              sourceSize: _sourceSize,
              emptyText: '等待离线回放',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '计数：$_count',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 16),
              Expanded(child: Text('状态：$_status')),
            ],
          ),
          const SizedBox(height: 8),
          PerfPanel(snapshot: _meter.snapshot),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _control.running ? null : _onPickVideo,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择视频'),
              ),
              FilledButton.icon(
                onPressed: _control.running ? null : _onStartReplay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始回放'),
              ),
              OutlinedButton.icon(
                onPressed: _control.running ? _onTogglePause : null,
                icon: Icon(_control.paused ? Icons.play_arrow : Icons.pause),
                label: Text(_control.paused ? '继续' : '暂停'),
              ),
              OutlinedButton(onPressed: _onReset, child: const Text('重置')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '视频：${_selectedVideoPath == null ? _replayVideoName : p.basename(_selectedVideoPath!)}；验收计数应为 5',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_lastLogPath != null)
            Text(
              '关键点日志：$_lastLogPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_lastPerfPath != null)
            Text(
              '性能报告：$_lastPerfPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _onStartReplay() async {
    setState(() {
      _control.start();
      _status = '加载模型';
    });
    _counter.reset();
    _filter.reset();
    _meter.reset();

    try {
      await _pose.load(assetPath: _modelPath);
      final videoPath = await _resolveReplayVideo(_selectedVideoPath);
      setState(() => _status = '抽帧');
      await _replay.prepare(videoPath);
      final logFile = await _openKeypointLog();
      final logSink = logFile.openWrite();
      final perfSamples = <PerformanceSample>[];
      var memoryPeakMb = _currentRssMb();
      logSink.writeln(keypointCsvHeader());

      try {
        while (mounted && _control.running) {
          while (mounted && _control.paused) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (!mounted || !_control.running) {
            break;
          }
          final frame = await _replay.nextFrame();
          if (frame == null) {
            break;
          }

          final preprocess = Stopwatch()..start();
          final input = _pose.pipeline.preprocess(
            frame.rgb,
            target: _pose.target,
          );
          preprocess.stop();
          final preprocessMs = preprocess.elapsedMilliseconds;
          _meter.recordPreprocess(preprocessMs);

          final infer = Stopwatch()..start();
          final keypoints = await _pose.infer(input);
          infer.stop();
          if (!mounted || !_control.running || _control.resetRequested) {
            break;
          }
          final inferMs = infer.elapsedMilliseconds;
          _meter.recordInfer(inferMs);
          perfSamples.add(
            PerformanceSample(
              preprocessMs: preprocessMs,
              inferMs: inferMs,
              keypoints: keypoints,
            ),
          );
          memoryPeakMb = _max(memoryPeakMb, _currentRssMb());
          logSink.writeln(
            keypointCsvRow(frame: frame.index, keypoints: keypoints),
          );

          final signals = _filter.smooth(_extractor.toSignals(keypoints));
          final state = _counter.update(signals);
          final image = await _rgbFrameToImage(frame.rgb);
          final oldImage = _image;

          _meter.recordUiFrame();
          setState(() {
            _image = image;
            _keypoints = keypoints;
            _sourceSize = Size(frame.width.toDouble(), frame.height.toDouble());
            _count = state.count;
            _status = '${frame.index + 1}/${_replay.totalFrames}';
          });
          oldImage?.dispose();
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        await logSink.close();
      }

      if (_control.resetRequested) {
        await _replay.dispose();
        _control.reset();
        return;
      }

      final perfFile = await _writePerformanceReport(
        samples: perfSamples,
        finalCount: _count,
        memoryPeakMb: memoryPeakMb,
      );
      if (mounted) {
        setState(() {
          _control.reset();
          _status = '完成：$_count';
          _lastLogPath = logFile.path;
          _lastPerfPath = perfFile.path;
        });
      }
    } catch (error) {
      if (mounted) {
        final wasReset = _control.resetRequested;
        setState(() {
          _control.reset();
          _status = wasReset ? '待开始' : '错误：$error';
        });
      }
    }
  }

  Future<void> _onPickVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    setState(() {
      _selectedVideoPath = path;
      _status = '已选择：${p.basename(path)}';
    });
  }

  void _onTogglePause() {
    setState(() {
      if (_control.paused) {
        _control.resume();
        _status = '继续';
      } else {
        _control.pause();
        _status = '暂停';
      }
    });
  }

  void _onReset() {
    final wasRunning = _control.running;
    if (wasRunning) {
      _control.requestReset();
    } else {
      _control.reset();
      unawaited(_replay.dispose());
    }
    _counter.reset();
    _filter.reset();
    _meter.reset();
    final oldImage = _image;
    setState(() {
      _image = null;
      _keypoints = const [];
      _sourceSize = Size.zero;
      _count = 0;
      _status = '待开始';
      _lastLogPath = null;
      _lastPerfPath = null;
    });
    oldImage?.dispose();
  }

  @override
  void dispose() {
    _image?.dispose();
    unawaited(_replay.dispose());
    unawaited(_pose.dispose());
    super.dispose();
  }
}

class LiveCameraTab extends StatefulWidget {
  const LiveCameraTab({super.key});

  @override
  State<LiveCameraTab> createState() => _LiveCameraTabState();
}

class _LiveCameraTabState extends State<LiveCameraTab> {
  final _camera = CameraService();
  final _pose = PoseEstimator();
  final _meter = PerformanceMeter();
  final _calibration = CameraCalibration();
  final _liveSamples = <DelegateMode, List<PerformanceSample>>{};
  final _liveMemoryPeakMb = <DelegateMode, double>{};

  StreamSubscription<CameraImage>? _subscription;
  List<KeyPoint> _keypoints = const [];
  Size _sourceSize = Size.zero;
  String? _lastPerfPath;
  var _running = false;
  var _busy = false;
  // 默认 NNAPI: 真机实测 20-28 FPS, 明显优于 CPU(14-16)/GPU(16-18)。
  var _mode = DelegateMode.nnapi;
  var _status = '待开始';
  // 会话版本号: 每次启动递增。异步操作完成后须校验版本号,
  // 不匹配说明期间发生过停止/重启, 丢弃过期结果(修复竞态 Bug)。
  var _session = 0;

  @override
  Widget build(BuildContext context) {
    final controller = _camera.controller;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: controller == null || !controller.value.isInitialized
                  ? const Center(
                      child: Text(
                        '等待相机',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        CustomPaint(
                          painter: OverlayRenderer(
                            keypoints: _keypoints,
                            sourceSize: _sourceSize,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '状态：$_status | delegate：${_mode.name} | rot+${_calibration.rotationOffsetDegrees} | mirror ${_calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing) ? 'on' : 'off'}',
          ),
          const SizedBox(height: 8),
          PerfPanel(snapshot: _meter.snapshot),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _onToggleCamera,
                icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                label: Text(_running ? '停止' : '启动相机'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _onCycleDelegate,
                child: const Text('切换 delegate'),
              ),
              OutlinedButton(
                onPressed: _onRotateCamera,
                child: const Text('旋转90'),
              ),
              OutlinedButton(
                onPressed: _onToggleMirror,
                child: const Text('镜像'),
              ),
            ],
          ),
          if (_lastPerfPath != null)
            Text(
              '性能报告：$_lastPerfPath',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _onToggleCamera() async {
    if (_running) {
      await _stopCamera();
      return;
    }

    // 启动新会话: 递增版本号, 后续异步操作凭此校验是否仍有效。
    final session = ++_session;
    setState(() {
      _running = true;
      _status = '加载模型';
      _lastPerfPath = null;
    });
    _liveSamples.clear();
    _liveMemoryPeakMb.clear();
    _meter.reset();
    try {
      await _pose.load(assetPath: _modelPath, mode: _mode);
      // 模型加载较慢(尤其 NNAPI), 期间用户可能已点停止 → 校验版本号。
      if (session != _session) {
        return;
      }
      await _camera.initialize();
      if (session != _session) {
        await _camera.dispose();
        return;
      }
      _subscription = _camera.imageStream.listen(_onCameraImage);
      if (mounted) {
        setState(() => _status = '运行中');
      }
    } catch (error) {
      if (session != _session) {
        // 期间已重启/停止, 此错误属于过期会话, 静默丢弃。
        return;
      }
      _running = false;
      await _subscription?.cancel();
      _subscription = null;
      await _camera.dispose();
      await _pose.dispose();
      if (mounted) {
        setState(() {
          _status = '错误：$error';
        });
      }
    }
  }

  Future<void> _stopCamera() async {
    // 递增版本号, 使任何进行中的启动序列立即失效(修复竞态 Bug)。
    _session++;
    _running = false;
    _busy = false;
    await _subscription?.cancel();
    _subscription = null;
    await _camera.dispose();
    final perfFile = await _writeLivePerformanceReport(
      _liveSamples,
      _liveMemoryPeakMb,
    );
    if (mounted) {
      setState(() {
        _keypoints = const [];
        _sourceSize = Size.zero;
        _status = '已停止';
        _lastPerfPath = perfFile?.path;
      });
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (!_running || _busy || image.planes.length < 3) {
      return;
    }
    _busy = true;
    final mode = _mode;
    // 记录本帧所属会话, 推理异步完成后校验, 防止停止后仍画骨架(红屏)。
    final session = _session;
    try {
      final rawRgb = yuv420ToRgb(
        width: image.width,
        height: image.height,
        yPlane: image.planes[0].bytes,
        uPlane: image.planes[1].bytes,
        vPlane: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      );
      final rgb = orientRgbFrame(
        rawRgb,
        rotationDegrees: _calibration.rotationFor(_camera.sensorOrientation),
        mirrorX: _calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing),
      );

      final preprocess = Stopwatch()..start();
      final input = _pose.pipeline.preprocess(rgb, target: _pose.target);
      preprocess.stop();
      final preprocessMs = preprocess.elapsedMilliseconds;
      _meter.recordPreprocess(preprocessMs);

      final infer = Stopwatch()..start();
      final keypoints = await _pose.infer(input);
      infer.stop();
      // 推理异步期间用户可能已停止 → 会话失效, 丢弃结果(修复红屏)。
      if (session != _session) {
        return;
      }
      final inferMs = infer.elapsedMilliseconds;
      _meter.recordInfer(inferMs);
      (_liveSamples[mode] ??= <PerformanceSample>[]).add(
        PerformanceSample(
          preprocessMs: preprocessMs,
          inferMs: inferMs,
          keypoints: keypoints,
        ),
      );
      _liveMemoryPeakMb[mode] = _max(
        _liveMemoryPeakMb[mode] ?? 0,
        _currentRssMb(),
      );

      if (mounted && _running) {
        _meter.recordUiFrame();
        setState(() {
          _keypoints = keypoints;
          _sourceSize = Size(rgb.width.toDouble(), rgb.height.toDouble());
        });
      }
    } catch (error) {
      // 会话已失效(用户点了停止导致 interpreter 关闭等) → 静默, 不报红屏。
      if (session != _session) {
        return;
      }
      if (mounted) {
        setState(() => _status = '错误：$error');
      }
    } finally {
      _busy = false;
    }
  }

  void _onRotateCamera() {
    setState(() {
      _calibration.rotateClockwise();
      _status = '校准旋转：${_calibration.rotationOffsetDegrees}';
    });
  }

  void _onToggleMirror() {
    setState(() {
      _calibration.toggleMirror(isFrontFacing: _camera.isFrontFacing);
      _status =
          '校准镜像：${_calibration.mirrorFor(isFrontFacing: _camera.isFrontFacing) ? 'on' : 'off'}';
    });
  }

  Future<void> _onCycleDelegate() async {
    if (_busy) {
      setState(() => _status = '推理中，稍后切换 delegate');
      return;
    }
    final nextMode = nextDelegateMode(_mode);
    if (!_running) {
      setState(() {
        _mode = nextMode;
        _status = 'delegate：${_mode.name}';
      });
      return;
    }

    _busy = true;
    try {
      await _pose.switchDelegate(nextMode);
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = nextMode;
        _status = 'delegate：${_mode.name}';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'delegate 错误：$error');
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _session++; // 使任何进行中的异步操作失效
    _running = false;
    unawaited(_subscription?.cancel());
    unawaited(_camera.dispose());
    unawaited(_pose.dispose());
    super.dispose();
  }
}

class _FrameOverlay extends StatelessWidget {
  const _FrameOverlay({
    required this.image,
    required this.keypoints,
    required this.sourceSize,
    required this.emptyText,
  });

  final ui.Image? image;
  final List<KeyPoint> keypoints;
  final Size sourceSize;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final currentImage = image;
    if (currentImage == null ||
        sourceSize.width <= 0 ||
        sourceSize.height <= 0) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(emptyText, style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: sourceSize.width,
          height: sourceSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RawImage(image: currentImage, fit: BoxFit.fill),
              CustomPaint(
                painter: OverlayRenderer(
                  keypoints: keypoints,
                  sourceSize: sourceSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String> _resolveReplayVideo(String? selectedPath) async {
  if (selectedPath != null && await File(selectedPath).exists()) {
    return selectedPath;
  }

  final local = File(_replayVideoName);
  if (await local.exists()) {
    return local.path;
  }

  final bytes = await rootBundle.load(_replayVideoName);
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, _replayVideoName));
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return file.path;
}

Future<File> _openKeypointLog() async {
  final dir = await _reportDirectory();
  return File(p.join(dir.path, 'app_keypoints.csv'));
}

Future<File> _writePerformanceReport({
  required List<PerformanceSample> samples,
  required int finalCount,
  required double memoryPeakMb,
}) async {
  final totalElapsedMs = samples.fold<int>(
    0,
    (total, sample) => total + sample.e2eMs,
  );
  final report = buildPerformanceReport(
    mode: 'offline_replay',
    delegate: DelegateMode.cpu.name,
    finalCount: finalCount,
    totalElapsedMs: totalElapsedMs,
    samples: samples,
    memoryPeakMb: memoryPeakMb,
  );
  return _writeJsonReport('performance_report.json', report);
}

Future<File?> _writeLivePerformanceReport(
  Map<DelegateMode, List<PerformanceSample>> samplesByMode,
  Map<DelegateMode, double> memoryPeakByMode,
) async {
  final reports = [
    for (final entry in samplesByMode.entries)
      if (entry.value.isNotEmpty)
        buildPerformanceReport(
          mode: 'live_camera',
          delegate: entry.key.name,
          finalCount: 0,
          totalElapsedMs: entry.value.fold<int>(
            0,
            (total, sample) => total + sample.e2eMs,
          ),
          samples: entry.value,
          memoryPeakMb: memoryPeakByMode[entry.key] ?? 0,
        ),
  ];
  if (reports.isEmpty) {
    return null;
  }

  return _writeJsonReport('live_performance_report.json', {
    'mode': 'live_camera',
    'reports': reports,
    'delegate_comparison': buildDelegateComparison(reports),
  });
}

Future<File> _writeJsonReport(String name, Map<String, Object> report) async {
  final dir = await _reportDirectory();
  final file = File(p.join(dir.path, name));
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(report), flush: true);
  return file;
}

Future<Directory> _reportDirectory() async {
  final dir = selectReportDirectory(
    external: await getExternalStorageDirectory(),
    documents: await getApplicationDocumentsDirectory(),
  );
  await dir.create(recursive: true);
  return dir;
}

double _currentRssMb() {
  return ProcessInfo.currentRss / 1024 / 1024;
}

double _max(double a, double b) {
  return a > b ? a : b;
}

Future<ui.Image> _rgbFrameToImage(RgbFrame frame) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    _rgbToRgba(frame.rgb),
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Uint8List _rgbToRgba(Uint8List rgb) {
  final rgba = Uint8List(rgb.length ~/ 3 * 4);
  for (var i = 0, j = 0; i < rgb.length; i += 3, j += 4) {
    rgba[j] = rgb[i];
    rgba[j + 1] = rgb[i + 1];
    rgba[j + 2] = rgb[i + 2];
    rgba[j + 3] = 255;
  }
  return rgba;
}
