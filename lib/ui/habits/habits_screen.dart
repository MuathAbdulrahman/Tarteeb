import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/habit_logic.dart';
import '../../domain/habit_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../icons.dart';
import '../theme.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final active = app.habits.where((h) => !h.habit.archived).toList();
    final archived = app.habits.where((h) => h.habit.archived).toList();
    final p = Palette.of(context);
    final today = Day.today();
    final scheduledToday = active.where((h) => isScheduledOn(h, today)).toList();
    final doneToday = scheduledToday.where((h) => h.completions.contains(today)).length;

    return Scaffold(
      appBar: AppBar(title: Text(tr.tabHabits)),
      floatingActionButton: FloatingActionButton(
        tooltip: tr.addHabit,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HabitEditorScreen())),
        child: const Icon(Icons.add),
      ),
      body: active.isEmpty && archived.isEmpty
          ? ListView(children: [
              EmptyState(icon: Icons.repeat, title: tr.noHabitsTitle, body: tr.noHabitsBody),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (scheduledToday.isNotEmpty)
                  AppCard(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: doneToday / scheduledToday.length,
                            strokeWidth: 5,
                            backgroundColor: p.chip,
                            color: p.success,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tr.habitsTodayProgress(doneToday, scheduledToday.length),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final h in active) _HabitTile(h: h),
                if (archived.isNotEmpty)
                  SectionLabel(
                    tr.archivedCount(archived.length),
                    trailing: IconButton(
                      tooltip: _showArchived ? tr.collapse : tr.expand,
                      icon: Icon(_showArchived ? Icons.expand_less : Icons.expand_more),
                      onPressed: () => setState(() => _showArchived = !_showArchived),
                    ),
                  ),
                if (_showArchived) for (final h in archived) _HabitTile(h: h),
              ],
            ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final HabitWithData h;
  const _HabitTile({required this.h});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final today = Day.today();
    final stats = computeHabitStats(h, today);
    final color = Color(h.habit.color);
    final last7 = [for (var i = 6; i >= 0; i--) today.addDays(-i)];

    Future<void> toggle(Day d) async {
      final err = await app.toggleHabitDay(h, d);
      if (err != null && context.mounted) showInfoSnack(context, tr.completionError(err));
    }

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.habit.id!))),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 10),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(habitIcon(h.habit.icon), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.habit.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.text)),
                    const SizedBox(height: 2),
                    Text(
                      stats.currentStreak > 0 ? tr.streakDays(stats.currentStreak) : tr.noStreakYet,
                      style: TextStyle(fontSize: 13, color: stats.currentStreak > 0 ? p.warning : p.textMuted),
                    ),
                  ],
                ),
              ),
              if (h.habit.archived)
                Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.archive_outlined, color: p.textMuted))
              else if (stats.scheduledToday)
                CompletionCircle(
                  done: stats.doneToday,
                  size: 28,
                  color: stats.doneToday ? p.success : color,
                  semanticLabel: stats.doneToday ? tr.markNotDone : tr.markDone,
                  onTap: () => toggle(today),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(tr.notScheduledToday, style: TextStyle(fontSize: 12, color: p.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in last7)
                Expanded(
                  child: Builder(builder: (ctx) {
                    final scheduled = isScheduledOn(h, d);
                    final done = h.completions.contains(d);
                    return Semantics(
                      button: scheduled,
                      checked: done,
                      label: formatDayLong(d),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: scheduled && !h.habit.archived ? () => toggle(d) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Text(weekdayInitial(d.weekdayIndex),
                                  style: TextStyle(fontSize: 11, color: d == today ? p.accent : p.textMuted)),
                              const SizedBox(height: 4),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? p.success : Colors.transparent,
                                  border: Border.all(
                                    color: done ? p.success : (scheduled ? color.withValues(alpha: 0.6) : p.cardBorder),
                                    width: 1.6,
                                  ),
                                ),
                                child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
