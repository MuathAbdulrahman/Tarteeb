import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/task_logic.dart';
import '../app_scope.dart';
import '../common.dart';
import '../habits/habit_detail_screen.dart';
import '../icons.dart';
import '../tasks/task_card.dart';
import '../tasks/task_editor_screen.dart';
import '../theme.dart';
import 'month_grid.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Day _month = Day.today().firstOfMonth;
  Day _selected = Day.today();
  int? _categoryId;
  final Set<int> _expanded = {};

  void _goToday() => setState(() {
        _selected = Day.today();
        _month = _selected.firstOfMonth;
      });

  void _shift(int months) => setState(() => _month = _month.addMonths(months).firstOfMonth);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final today = Day.today();
    final weekStart = app.settings.weekStart;
    final gridStart = startOfWeek(_month, weekStart);
    final markers = markersForRange(
      DayRange(gridStart, gridStart.addDays(41)),
      app.tasks,
      app.habits,
      categoryId: _categoryId,
    );
    final entries = entriesForDay(_selected, app.tasks, app.habits, categoryId: _categoryId);

    return Scaffold(
      appBar: AppBar(title: Text(tr.tabCalendar)),
      floatingActionButton: FloatingActionButton(
        tooltip: tr.addTaskOnDay,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskEditorScreen(initialDueDate: _selected, initialCategoryId: _categoryId),
        )),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SizedBox(
            height: 16 + 32 * MediaQuery.textScalerOf(context).scale(1),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(tr.allCategories),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                ),
                for (final c in app.taskCategories)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: Color(c.color), radius: 6),
                      label: Text(tr.categoryName(c)),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                  ),
              ],
            ),
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 250) return;
                final rtl = Directionality.of(context) == TextDirection.rtl;
                // Swiping toward the reading direction's end moves forward in time.
                final forward = rtl ? v > 0 : v < 0;
                _shift(forward ? 1 : -1);
              },
              child: Column(
                children: [
                  MonthHeader(
                    month: _month,
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                    onToday: _goToday,
                    todayLabel: tr.today,
                    prevTooltip: tr.previousMonth,
                    nextTooltip: tr.nextMonth,
                  ),
                  MonthGrid(
                    month: _month,
                    weekStart: weekStart,
                    cellBuilder: (ctx, d, inMonth) {
                      final m = markers[d];
                      final isToday = d == today;
                      final isSel = d == _selected;
                      return Semantics(
                        button: true,
                        selected: isSel,
                        label: formatDayLong(d),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _selected = d;
                            if (!inMonth) _month = d.firstOfMonth;
                          }),
                          child: SizedBox(
                            height: 14 + 34 * MediaQuery.textScalerOf(ctx).scale(1),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32 * MediaQuery.textScalerOf(ctx).scale(1),
                                  height: 32 * MediaQuery.textScalerOf(ctx).scale(1),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSel ? p.accent : Colors.transparent,
                                    border: isToday && !isSel ? Border.all(color: p.accent, width: 1.6) : null,
                                  ),
                                  child: Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isToday || isSel ? FontWeight.w700 : FontWeight.w400,
                                      color: isSel
                                          ? Theme.of(ctx).colorScheme.onPrimary
                                          : (inMonth ? (isToday ? p.accent : p.text) : p.textMuted.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 6,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (m != null && m.due) _dot(p.accent),
                                      if (m != null && m.followUp) _dot(p.followUp),
                                      if (m != null && m.habitDone) _dot(p.success),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 14,
                      alignment: WrapAlignment.center,
                      children: [
                        _legend(p.accent, tr.labelDue, p),
                        _legend(p.followUp, tr.labelFollowUp, p),
                        _legend(p.success, tr.labelHabitDone, p),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionLabel(formatDayLong(_selected)),
          if (entries.isEmpty)
            EmptyState(icon: Icons.event_available, title: tr.nothingScheduled),
          for (final e in entries.tasks)
            TaskCard(
              task: e.task,
              expanded: _expanded.contains(e.task.id),
              onToggleExpand: () => setState(() {
                _expanded.contains(e.task.id) ? _expanded.remove(e.task.id) : _expanded.add(e.task.id!);
              }),
              extraPills: [
                if (e.isDue) Pill(text: tr.labelDue, fg: Colors.white, bg: p.accent, icon: Icons.event),
                if (e.isFollowUp) Pill(text: tr.labelFollowUp, fg: Colors.white, bg: p.followUp, icon: Icons.reply),
              ],
            ),
          if (entries.habits.isNotEmpty) SectionLabel(tr.habitsForDay),
          for (final h in entries.habits)
            AppCard(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.habit.habit.id!))),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(h.habit.habit.color).withValues(alpha: 0.15),
                    child: Icon(habitIcon(h.habit.habit.icon), color: Color(h.habit.habit.color), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.habit.habit.name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                        const SizedBox(height: 4),
                        Pill(text: tr.labelHabit, fg: p.success, bg: p.successSoft, icon: Icons.repeat),
                      ],
                    ),
                  ),
                  if (!_selected.isAfter(today))
                    CompletionCircle(
                      done: h.done,
                      color: h.done ? p.success : Color(h.habit.habit.color),
                      semanticLabel: h.done ? tr.markNotDone : tr.markDone,
                      onTap: () async {
                        final err = await app.toggleHabitDay(h.habit, _selected);
                        if (err != null && context.mounted) showInfoSnack(context, tr.completionError(err));
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.schedule, color: p.textMuted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _legend(Color c, String label, Palette p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
        ],
      );
}
