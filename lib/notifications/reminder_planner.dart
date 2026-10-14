import '../core/day.dart';
import '../domain/habit_logic.dart';
import '../domain/habit_models.dart';
import '../domain/task_models.dart';
import '../platform/native_bridge.dart';

int taskReminderId(int taskId) => taskId * 10 + 1;
int habitReminderId(int habitId) => habitId * 10 + 2;

/// Computes the complete set of reminders that should be scheduled. The native
/// side replaces everything it had with this list, so cancelling (task done,
/// deleted, reminder cleared) and rescheduling (time edited) are the same
/// operation.
List<ReminderSpec> planReminders({
  required List<TaskItem> tasks,
  required List<HabitWithData> habits,
  required bool taskReminders,
  required bool habitReminders,
  required DateTime now,
  required String Function(TaskItem) taskBody,
  required String Function(Habit) habitBody,
}) {
  final out = <ReminderSpec>[];
  final nowMs = now.millisecondsSinceEpoch;
  if (taskReminders) {
    for (final t in tasks) {
      final at = t.reminderAt;
      if (t.id == null || at == null || t.isCompleted || at <= nowMs) continue;
      out.add(ReminderSpec(id: taskReminderId(t.id!), title: t.title, body: taskBody(t), kind: 'once', at: at));
    }
  }
  if (habitReminders) {
    final today = Day.fromDateTime(now);
    for (final h in habits) {
      final m = h.habit.reminderMinutes;
      if (h.habit.id == null || m == null || h.habit.archived) continue;
      var skipUntil = 0;
      if (h.habit.startDate.isAfter(today)) {
        skipUntil = h.habit.startDate.startLocal.millisecondsSinceEpoch;
      } else if (h.completions.contains(today)) {
        skipUntil = today.addDays(1).startLocal.millisecondsSinceEpoch;
      }
      out.add(ReminderSpec(
        id: habitReminderId(h.habit.id!),
        title: h.habit.name,
        body: habitBody(h.habit),
        kind: 'weekly',
        minutes: m,
        weekdayMask: currentMask(h),
        skipUntil: skipUntil,
      ));
    }
  }
  return out;
}
