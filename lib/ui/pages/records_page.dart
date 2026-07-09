// Extracted from main.dart during architecture refactor.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../product/workout_session_store.dart';
import '../app_theme.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({
    super.key,
    required this.store,
    this.cloudSessionsFuture,
    this.pendingSyncCountFuture,
  });

  final WorkoutSessionStore store;
  final Future<List<WorkoutSession>>? cloudSessionsFuture;
  final Future<int>? pendingSyncCountFuture;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordsTitle)),
      body: FutureBuilder<List<WorkoutSession>>(
        future: store.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: greenDark),
            );
          }
          final localSessions = snapshot.data!;
          final cloudFuture = cloudSessionsFuture;
          if (cloudFuture == null) {
            return _RecordsContent(
              now: now,
              sessions: localSessions,
              pendingSyncCountFuture: pendingSyncCountFuture,
            );
          }
          return FutureBuilder<List<WorkoutSession>>(
            future: cloudFuture,
            builder: (context, cloudSnapshot) {
              final hasCloud = cloudSnapshot.hasData;
              final cloudSessions = hasCloud
                  ? cloudSnapshot.data!
                  : const <WorkoutSession>[];
              return _RecordsContent(
                now: now,
                sessions: mergeWorkoutSessions(
                  local: localSessions,
                  cloud: cloudSessions,
                ),
                cloudStatus: cloudSnapshot.hasError
                    ? _CloudRecordsStatus.unavailable
                    : hasCloud
                    ? _CloudRecordsStatus.merged
                    : _CloudRecordsStatus.loading,
                pendingSyncCountFuture: pendingSyncCountFuture,
              );
            },
          );
        },
      ),
    );
  }
}

enum _CloudRecordsStatus { loading, merged, unavailable }

class _RecordsContent extends StatelessWidget {
  const _RecordsContent({
    required this.now,
    required this.sessions,
    this.cloudStatus,
    this.pendingSyncCountFuture,
  });

  final DateTime now;
  final List<WorkoutSession> sessions;
  final _CloudRecordsStatus? cloudStatus;
  final Future<int>? pendingSyncCountFuture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final leadingEmptyCells = firstDay.weekday % 7;
    final totals = _totalsByLocalDate(sessions);
    final monthEntries = totals.entries.where(
      (entry) => entry.key.year == now.year && entry.key.month == now.month,
    );
    final monthTotal = monthEntries.fold<int>(
      0,
      (total, entry) => total + entry.value,
    );
    final activeDays = monthEntries.where((entry) => entry.value > 0).length;
    final bestDay = monthEntries.fold<int>(
      0,
      (best, entry) => entry.value > best ? entry.value : best,
    );
    final hasStatus = cloudStatus != null || pendingSyncCountFuture != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: _CalendarModePill()),
          const SizedBox(height: 18),
          Text(
            l10n.recordsMonthTitle(now.year, now.month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (hasStatus) ...[
            const SizedBox(height: 12),
            _StatusMessages(
              cloudStatus: cloudStatus,
              pendingSyncCountFuture: pendingSyncCountFuture,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _WeekdayLabel(l10n.recordsWeekdaySun),
              _WeekdayLabel(l10n.recordsWeekdayMon),
              _WeekdayLabel(l10n.recordsWeekdayTue),
              _WeekdayLabel(l10n.recordsWeekdayWed),
              _WeekdayLabel(l10n.recordsWeekdayThu),
              _WeekdayLabel(l10n.recordsWeekdayFri),
              _WeekdayLabel(l10n.recordsWeekdaySat),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leadingEmptyCells + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
  }
}

class _StatusMessages extends StatelessWidget {
  const _StatusMessages({this.cloudStatus, this.pendingSyncCountFuture});

  final _CloudRecordsStatus? cloudStatus;
  final Future<int>? pendingSyncCountFuture;

  @override
  Widget build(BuildContext context) {
    final pendingFuture = pendingSyncCountFuture;
    if (pendingFuture == null) {
      return _StatusWrap(chips: _cloudChips(context));
    }
    return FutureBuilder<int>(
      future: pendingFuture,
      builder: (context, snapshot) {
        final chips = _cloudChips(context);
        final pendingCount = snapshot.data ?? 0;
        if (pendingCount > 0) {
          chips.add(
            _StatusChip(
              icon: Icons.sync_rounded,
              text: AppLocalizations.of(
                context,
              ).recordsPendingSyncCount(pendingCount),
            ),
          );
        }
        return _StatusWrap(chips: chips);
      },
    );
  }

  List<Widget> _cloudChips(BuildContext context) {
    final status = cloudStatus;
    if (status == null) {
      return <Widget>[];
    }
    final l10n = AppLocalizations.of(context);
    return [
      _StatusChip(
        icon: _cloudStatusIcon(status),
        text: _cloudStatusText(l10n, status),
      ),
    ];
  }
}

IconData _cloudStatusIcon(_CloudRecordsStatus status) {
  switch (status) {
    case _CloudRecordsStatus.loading:
      return Icons.cloud_sync_rounded;
    case _CloudRecordsStatus.merged:
      return Icons.cloud_done_rounded;
    case _CloudRecordsStatus.unavailable:
      return Icons.cloud_off_rounded;
  }
}

String _cloudStatusText(AppLocalizations l10n, _CloudRecordsStatus status) {
  switch (status) {
    case _CloudRecordsStatus.loading:
      return l10n.recordsCloudLoading;
    case _CloudRecordsStatus.merged:
      return l10n.recordsCloudMerged;
    case _CloudRecordsStatus.unavailable:
      return l10n.recordsCloudUnavailable;
  }
}

class _StatusWrap extends StatelessWidget {
  const _StatusWrap({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: greenDark),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Map<DateTime, int> _totalsByLocalDate(List<WorkoutSession> sessions) {
  final totals = <DateTime, int>{};
  for (final session in sessions) {
    final local = session.localDate ?? session.startedAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    totals[day] = (totals[day] ?? 0) + session.count;
  }
  return totals;
}

class _CalendarModePill extends StatelessWidget {
  const _CalendarModePill();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarModeText(l10n.recordsModeWeek),
          _CalendarModeText(l10n.recordsModeMonth, selected: true),
          _CalendarModeText(l10n.recordsModeYear),
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
        color: selected ? green : Colors.transparent,
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
          color: selected
              ? Colors.white
              : Theme.of(context).textTheme.bodyMedium?.color,
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
      return yellow;
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
        border: isToday
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: hasTotal
                    ? ink
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (hasTotal)
              Text(
                '$total',
                style: const TextStyle(
                  color: greenDark,
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
        _LegendItem(color: yellow, label: '50-99'),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          _SummaryValue(
            label: l10n.recordsTrainingDays,
            value: l10n.recordsDaysValue(activeDays),
          ),
          const _SummaryDivider(),
          _SummaryValue(
            label: l10n.recordsTotalCount,
            value: l10n.recordsRepsValue(monthTotal),
          ),
          const _SummaryDivider(),
          _SummaryValue(
            label: l10n.recordsBestDay,
            value: l10n.recordsRepsValue(bestDay),
          ),
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
    return Container(
      width: 1,
      height: 42,
      color: Theme.of(context).colorScheme.outline,
    );
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
