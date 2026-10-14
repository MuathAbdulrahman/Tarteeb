import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/task_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';
import 'task_detail_screen.dart';

Color priorityColor(Palette p, TaskPriority pr) => switch (pr) {
      TaskPriority.high => p.danger,
      TaskPriority.medium => p.warning,
      TaskPriority.normal => p.textMuted,
    };

/// Completes or reopens a task. Asks first when unfinished subtasks exist and
/// offers undo afterwards.
Future<void> toggleTaskCompletion(BuildContext context, TaskItem t) async {
  final app = AppScope.read(context);
  final completing = !t.isCompleted;
  var completeSubs = false;
  if (completing && t.hasUnfinishedSubtasks) {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr.unfinishedSubtasksTitle),
        content: Text(tr.unfinishedSubtasksBody(t.subtasks.length - t.doneSubtasks)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0), child: Text(tr.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 1), child: Text(tr.completeTaskOnly)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 2), child: Text(tr.completeAll)),
        ],
      ),
    );
    if (choice == null || choice == 0) return;
    completeSubs = choice == 2;
  }
  final openSubIds = t.subtasks.where((x) => !x.done).map((x) => x.id).toSet();
  await app.setTaskCompleted(t, completing, completeSubtasks: completeSubs);
  if (!context.mounted) return;
  if (completing) {
    final id = t.id!;
    showUndoSnack(context, tr.taskCompleted, () async {
      final current = app.taskById(id);
      if (current == null) return;
      await app.setTaskCompleted(current, false);
      if (completeSubs) {
        final again = app.taskById(id);
        if (again == null) return;
        for (final st in again.subtasks) {
          if (openSubIds.contains(st.id) && st.done) await app.setSubtaskDone(again, st, false);
        }
      }
    });
  }
}

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final bool showCategory;
  final List<Widget> extraPills;

  const TaskCard({
    super.key,
    required this.task,
    required this.expanded,
    required this.onToggleExpand,
    this.showCategory = true,
    this.extraPills = const [],
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final app = AppScope.of(context);
    final t = task;
    final today = Day.today();
    final cat = app.categoryById(t.categoryId);
    final pills = <Widget>[...extraPills];

    if (t.priority != TaskPriority.normal) {
      final c = priorityColor(p, t.priority);
      pills.add(Pill(text: tr.priorityLabel(t.priority), fg: c, bg: c.withValues(alpha: 0.12), icon: Icons.flag_outlined));
    }
    if (t.status == TaskStatus.inProgress) {
      pills.add(Pill(text: tr.statusLabel(t.status), fg: p.accent, bg: p.accentSoft));
    } else if (t.status == TaskStatus.waiting) {
      pills.add(Pill(
        text: t.waitingOn.isEmpty ? tr.statusLabel(t.status) : tr.waitingOnName(t.waitingOn),
        fg: p.followUp,
        bg: p.followUpSoft,
        icon: Icons.hourglass_empty,
      ));
    }
    final due = t.dueDate;
    if (due != null) {
      final overdue = !t.isCompleted && due.isBefore(today);
      final text = t.dueMinutes == null
          ? formatDayRelative(due, today: today)
          : '${formatDayRelative(due, today: today)} ${formatMinutes(t.dueMinutes!)}';
      pills.add(Pill(
        text: text,
        fg: overdue ? p.danger : p.textMuted,
        bg: overdue ? p.dangerSoft : p.chip,
        icon: Icons.event_outlined,
      ));
    }
    final f = t.followUpDate;
    if (f != null && !t.isCompleted) {
      pills.add(Pill(
        text: tr.followUpOn(formatDayRelative(f, today: today)),
        fg: p.followUp,
        bg: p.followUpSoft,
        icon: Icons.reply_outlined,
      ));
    }
    if (t.reminderAt != null && !t.isCompleted && t.reminderAt! > DateTime.now().millisecondsSinceEpoch) {
      pills.add(Pill(text: formatDateTimeMs(t.reminderAt!), fg: p.textMuted, bg: p.chip, icon: Icons.notifications_none));
    }
    if (showCategory && cat != null) {
      pills.add(Pill(text: tr.categoryName(cat), fg: Color(cat.color), bg: Color(cat.color).withValues(alpha: 0.12)));
    }

    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 10, 8),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompletionCircle(
                done: t.isCompleted,
                color: t.isCompleted ? p.success : priorityColor(p, t.priority) == p.textMuted ? p.accent : priorityColor(p, t.priority),
                semanticLabel: t.isCompleted ? tr.markNotDone : tr.markDone,
                onTap: () => toggleTaskCompletion(context, t),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.isCompleted ? p.textMuted : p.text,
                          decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                          height: 1.3,
                        ),
                      ),
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: pills),
                      ],
                    ],
                  ),
                ),
              ),
              if (t.subtasks.isNotEmpty)
                Semantics(
                  button: true,
                  label: expanded ? tr.collapseSubtasks : tr.expandSubtasks,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onToggleExpand,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⁦${t.doneSubtasks}/${t.subtasks.length}⁩',
                              style: TextStyle(fontSize: 13, color: p.textMuted, fontWeight: FontWeight.w600)),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(Icons.expand_more, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (t.subtasks.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44, end: 4, top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: t.subtasks.isEmpty ? 0.0 : t.doneSubtasks / t.subtasks.length,
                  minHeight: 4,
                  backgroundColor: p.chip,
                  color: p.success,
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 32, top: 4),
                    child: Column(
                      children: [
                        for (final st in t.subtasks)
                          Row(
                            children: [
                              CompletionCircle(
                                done: st.done,
                                size: 20,
                                color: st.done ? p.success : p.textMuted,
                                semanticLabel: st.done ? tr.markNotDone : tr.markDone,
                                onTap: () => app.setSubtaskDone(t, st, !st.done),
                              ),
                              Expanded(
                                child: Text(
                                  st.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: st.done ? p.textMuted : p.text,
                                    decoration: st.done ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
