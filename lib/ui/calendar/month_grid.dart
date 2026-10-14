import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../theme.dart';

/// Month grid starting on [weekStart] (0 = Sunday). Cells are drawn by
/// [cellBuilder]; days outside [month] are passed with inMonth = false.
class MonthGrid extends StatelessWidget {
  final Day month; // any day in the month
  final int weekStart;
  final Widget Function(BuildContext context, Day day, bool inMonth) cellBuilder;

  const MonthGrid({super.key, required this.month, required this.weekStart, required this.cellBuilder});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final first = month.firstOfMonth;
    final gridStart = startOfWeek(first, weekStart);
    final last = Day(first.year, first.month, first.daysInMonth);
    final gridEnd = startOfWeek(last, weekStart).addDays(6);
    final weeks = (gridEnd.differenceInDays(gridStart) + 1) ~/ 7;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      weekdayInitial((weekStart + i) % 7),
                      style: TextStyle(fontSize: 12, color: p.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(builder: (ctx) {
                    final d = gridStart.addDays(w * 7 + i);
                    return cellBuilder(ctx, d, d.month == first.month && d.year == first.year);
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

/// Header with month name, previous/next buttons and an optional Today button.
class MonthHeader extends StatelessWidget {
  final Day month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;
  final String? todayLabel;
  final String prevTooltip;
  final String nextTooltip;

  const MonthHeader({
    super.key,
    required this.month,
    required this.onPrev,
    required this.onNext,
    this.onToday,
    this.todayLabel,
    required this.prevTooltip,
    required this.nextTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        // Chevrons follow reading direction: in RTL "previous" points right.
        IconButton(tooltip: prevTooltip, onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(
            monthYear(month),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.text),
          ),
        ),
        IconButton(tooltip: nextTooltip, onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        if (onToday != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: OutlinedButton(onPressed: onToday, child: Text(todayLabel ?? '')),
          ),
      ],
    );
  }
}
