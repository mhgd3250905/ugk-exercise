// Extracted from main.dart during architecture refactor.

import 'package:flutter/material.dart';

import '../../product/workout_session_store.dart';
import '../app_theme.dart';

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
              child: CircularProgressIndicator(color: greenDark),
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
        color: Theme.of(context).colorScheme.surface,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
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
