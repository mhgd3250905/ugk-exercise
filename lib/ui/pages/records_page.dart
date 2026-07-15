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

enum _RecordsPeriod { week, month, year }

class _RecordsContent extends StatefulWidget {
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
  State<_RecordsContent> createState() => _RecordsContentState();
}

class _RecordsContentState extends State<_RecordsContent> {
  var _period = _RecordsPeriod.month;
  var _slideDirection = 0.0;
  final _periodOffsets = List<int>.filled(_RecordsPeriod.values.length, 0);

  int get _periodOffset => _periodOffsets[_period.index];

  void _selectPeriod(_RecordsPeriod period) {
    if (period == _period) {
      return;
    }
    setState(() {
      _slideDirection = period.index > _period.index ? 1 : -1;
      _period = period;
    });
  }

  void _shiftPeriod(int delta) {
    final next = _periodOffset + delta;
    if (next > 0) {
      return;
    }
    setState(() {
      _slideDirection = delta.isNegative ? -1 : 1;
      _periodOffsets[_period.index] = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now;
    final l10n = AppLocalizations.of(context);
    final totals = _totalsByLocalDate(widget.sessions);
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: now.weekday % 7));
    final weekStart = currentWeekStart.add(
      Duration(days: _periodOffsets[_RecordsPeriod.week.index] * 7),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    final nextWeek = weekStart.add(const Duration(days: 7));
    final selectedMonth = DateTime(
      now.year,
      now.month + _periodOffsets[_RecordsPeriod.month.index],
    );
    final firstDay = DateTime(selectedMonth.year, selectedMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      selectedMonth.year,
      selectedMonth.month,
    );
    final leadingEmptyCells = firstDay.weekday % 7;
    final selectedYear = now.year + _periodOffsets[_RecordsPeriod.year.index];
    final periodEntries = totals.entries.where((entry) {
      return switch (_period) {
        _RecordsPeriod.week =>
          !entry.key.isBefore(weekStart) && entry.key.isBefore(nextWeek),
        _RecordsPeriod.month =>
          entry.key.year == selectedMonth.year &&
              entry.key.month == selectedMonth.month,
        _RecordsPeriod.year => entry.key.year == selectedYear,
      };
    }).toList();
    final totalCount = periodEntries.fold<int>(
      0,
      (total, entry) => total + entry.value,
    );
    final activeDays = periodEntries.where((entry) => entry.value > 0).length;
    final bestDay = periodEntries.fold<int>(
      0,
      (best, entry) => entry.value > best ? entry.value : best,
    );
    final hasStatus =
        widget.cloudStatus != null || widget.pendingSyncCountFuture != null;
    final title = switch (_period) {
      _RecordsPeriod.week => l10n.recordsWeekTitle(
        weekStart.month,
        weekStart.day,
        weekEnd.month,
        weekEnd.day,
      ),
      _RecordsPeriod.month => l10n.recordsMonthTitle(
        selectedMonth.year,
        selectedMonth.month,
      ),
      _RecordsPeriod.year => l10n.recordsYearTitle(selectedYear),
    };
    final baseContentKey = 'records-period-content-${_period.name}';
    final contentKey = ValueKey(
      _periodOffset == 0
          ? baseContentKey
          : '$baseContentKey-history${-_periodOffset}',
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _CalendarModePill(
                period: _period,
                onSelected: _selectPeriod,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    switchInCurve: Curves.linear,
                    switchOutCurve: Curves.linear,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0.65, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: animation,
                          child: child,
                          builder: (context, child) {
                            final isIncoming = child?.key == contentKey;
                            final progress = Curves.easeOutQuart.transform(
                              isIncoming
                                  ? animation.value
                                  : 1 - animation.value,
                            );
                            return FractionalTranslation(
                              translation: Offset(
                                isIncoming
                                    ? _slideDirection * (1 - progress)
                                    : -_slideDirection * progress,
                                0,
                              ),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: Column(
                      key: contentKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              IconButton(
                                key: const ValueKey('records-period-previous'),
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).previousPageTooltip,
                                onPressed: () => _shiftPeriod(-1),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('records-period-next'),
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).nextPageTooltip,
                                onPressed: _periodOffset < 0
                                    ? () => _shiftPeriod(1)
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_period != _RecordsPeriod.year) ...[
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
                        ],
                        if (_period == _RecordsPeriod.month)
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
                                final day = DateTime(
                                  selectedMonth.year,
                                  selectedMonth.month,
                                  dayNumber,
                                );
                                return _RecordDayCell(
                                  day: dayNumber,
                                  total: totals[day] ?? 0,
                                  isToday: day == today,
                                );
                              },
                            ),
                          )
                        else if (_period == _RecordsPeriod.week)
                          SizedBox(
                            height: 64,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 7,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                              itemBuilder: (context, index) {
                                final day = weekStart.add(
                                  Duration(days: index),
                                );
                                return _RecordDayCell(
                                  day: day.day,
                                  total: totals[day] ?? 0,
                                  isToday: day == today,
                                );
                              },
                            ),
                          )
                        else
                          SizedBox(
                            height: 270,
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 12,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                              itemBuilder: (context, index) {
                                final month = index + 1;
                                final total = totals.entries
                                    .where(
                                      (entry) =>
                                          entry.key.year == selectedYear &&
                                          entry.key.month == month,
                                    )
                                    .fold<int>(
                                      0,
                                      (sum, entry) => sum + entry.value,
                                    );
                                return _RecordDayCell(
                                  day: month,
                                  total: total,
                                  isToday:
                                      selectedYear == now.year &&
                                      month == now.month,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (hasStatus) ...[
              _StatusMessages(
                cloudStatus: widget.cloudStatus,
                pendingSyncCountFuture: widget.pendingSyncCountFuture,
              ),
              const SizedBox(height: 14),
            ],
            const _CalendarLegend(),
            const SizedBox(height: 18),
            _PeriodSummaryCard(
              activeDays: activeDays,
              totalCount: totalCount,
              bestDay: bestDay,
            ),
          ],
        ),
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
  const _CalendarModePill({required this.period, required this.onSelected});

  final _RecordsPeriod period;
  final ValueChanged<_RecordsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        width: 210,
        height: 38,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: duration,
              curve: Curves.easeOutQuart,
              alignment: switch (period) {
                _RecordsPeriod.week => Alignment.centerLeft,
                _RecordsPeriod.month => Alignment.center,
                _RecordsPeriod.year => Alignment.centerRight,
              },
              child: Container(
                key: const ValueKey('records-period-indicator'),
                width: 70,
                height: 38,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332ACF7A),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _CalendarModeText(
                  l10n.recordsModeWeek,
                  selected: period == _RecordsPeriod.week,
                  duration: duration,
                  onTap: () => onSelected(_RecordsPeriod.week),
                ),
                _CalendarModeText(
                  l10n.recordsModeMonth,
                  selected: period == _RecordsPeriod.month,
                  duration: duration,
                  onTap: () => onSelected(_RecordsPeriod.month),
                ),
                _CalendarModeText(
                  l10n.recordsModeYear,
                  selected: period == _RecordsPeriod.year,
                  duration: duration,
                  onTap: () => onSelected(_RecordsPeriod.year),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarModeText extends StatelessWidget {
  const _CalendarModeText(
    this.text, {
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 70,
        height: 38,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeOutQuart,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w900,
            ),
            child: Text(text),
          ),
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
      key: ValueKey('records-calendar-legend'),
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

class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.activeDays,
    required this.totalCount,
    required this.bestDay,
  });

  final int activeDays;
  final int totalCount;
  final int bestDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('records-period-summary'),
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
            value: l10n.recordsRepsValue(totalCount),
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
