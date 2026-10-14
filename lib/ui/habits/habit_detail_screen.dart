import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/habit_logic.dart';
import '../app_scope.dart';
import '../calendar/month_grid.dart';
import '../common.dart';
import '../icons.dart';
import '../theme.dart';
import 'habit_editor_screen.dart';

class HabitDetailScreen extends StatefulWidget {
  final int habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  Day _month = Day.today().firstOfMonth;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final h = app.habitById(widget.habitId);
    if (h == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.search_off, title: tr.habitNotFound));
    }
    final today = Day.today();
    final stats = computeHabitStats(h, today);
    final color = Color(h.habit.color);
    final monthDone = h.completions.where((d) => d.year == _month.year && d.month == _month.month).length;
    var monthScheduled = 0;
    for (var d = _month.firstOfMonth; d.month == _month.month; d = d.addDays(1)) {
      if (!d.isAfter(today) && isScheduledOn(h, d)) monthScheduled++;
    }

    Widget stat(String label, String value, IconData icon, Color c) => Expanded(
          child: AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: c),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.text)),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.textMuted)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(h.habit.name),
        actions: [
          IconButton(
            tooltip: tr.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitEditorScreen(habit: h))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'archive') {
                await app.setHabitArchived(h.habit.id!, !h.habit.archived);
              } else if (v == 'delete') {
                final ok = await confirmDialog(context,
                    title: tr.deleteHabitQ, body: tr.deleteHabitBody, confirmLabel: tr.delete, destructive: true);
                if (!ok) return;
                await app.deleteHabit(h.habit.id!);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'archive', child: Text(h.habit.archived ? tr.unarchive : tr.archive)),
              PopupMenuItem(value: 'delete', child: Text(tr.delete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(habitIcon(h.habit.icon), color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scheduleText(currentMask(h)), style: TextStyle(fontSize: 14, color: p.text)),
                      Text(tr.startedOn(formatDayShort(h.habit.startDate)),
                          style: TextStyle(fontSize: 13, color: p.textMuted)),
                      if (h.habit.reminderMinutes != null)
                        Text(tr.reminderAt(formatMinutes(h.habit.reminderMinutes!)),
                            style: TextStyle(fontSize: 13, color: p.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                stat(tr.totalCompleted, '${stats.totalCompleted}', Icons.check_circle_outline, p.success),
                stat(tr.currentStreak, '${stats.currentStreak}', Icons.local_fire_department_outlined, p.warning),
                stat(tr.longestStreak, '${stats.longestStreak}', Icons.emoji_events_outlined, p.accent),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Column(
              children: [
                MonthHeader(
                  month: _month,
                  onPrev: () => setState(() => _month = _month.addMonths(-1).firstOfMonth),
                  onNext: () => setState(() => _month = _month.addMonths(1).firstOfMonth),
                  prevTooltip: tr.previousMonth,
                  nextTooltip: tr.nextMonth,
                ),
                MonthGrid(
                  month: _month,
                  weekStart: app.settings.weekStart,
                  cellBuilder: (ctx, d, inMonth) {
                    final cellH = 10 + 34 * MediaQuery.textScalerOf(ctx).scale(1);
                    if (!inMonth) return SizedBox(height: cellH);
                    final scheduled = isScheduledOn(h, d);
                    final done = h.completions.contains(d);
                    final future = d.isAfter(today);
                    final missed = scheduled && !done && d.isBefore(today);
                    return Semantics(
                      label: formatDayLong(d),
                      checked: done,
                      button: scheduled && !future,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: (!scheduled || future)
                            ? null
                            : () async {
                                final err = await app.toggleHabitDay(h, d);
                                if (err != null && context.mounted) showInfoSnack(context, tr.completionError(err));
                              },
                        child: SizedBox(
                          height: cellH,
                          child: Center(
                            child: Container(
                              width: cellH - 10,
                              height: cellH - 10,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done ? p.success : Colors.transparent,
                                border: done
                                    ? null
                                    : Border.all(
                                        color: d == today
                                            ? p.accent
                                            : (scheduled ? (missed ? p.danger.withValues(alpha: 0.5) : color.withValues(alpha: 0.5)) : Colors.transparent),
                                        width: d == today ? 2 : 1.4,
                                      ),
                              ),
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: d == today ? FontWeight.w700 : FontWeight.w400,
                                  color: done ? Colors.white : (scheduled && !future ? p.text : p.textMuted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(tr.monthCompletion(monthDone, monthScheduled), style: TextStyle(fontSize: 13, color: p.textMuted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(tr.habitRulesNote, style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String scheduleText(int mask) {
    if (mask == 0x7F) return tr.daily;
    final ws = AppScope.read(context).settings.weekStart;
    final days = [
      for (var i = 0; i < 7; i++)
        if ((mask >> ((ws + i) % 7)) & 1 == 1) weekdayName((ws + i) % 7, short: true)
    ];
    return days.join(tr.listSeparator);
  }
}
