import '../core/day.dart';
import 'habit_logic.dart';
import 'habit_models.dart';
import 'task_models.dart';

enum TaskSection { overdue, today, upcoming, noDate, completed }

/// Section for a task relative to [today].
/// Only the due date decides overdue/today/upcoming; follow-up dates never
/// make a task overdue, and undated tasks are never overdue.
TaskSection sectionOf(TaskItem t, Day today) {
  if (t.isCompleted) return TaskSection.completed;
  final due = t.dueDate;
  if (due == null) return TaskSection.noDate;
  if (due.isBefore(today)) return TaskSection.overdue;
  if (due == today) return TaskSection.today;
  return TaskSection.upcoming;
}

enum TaskSort { manual, dueDate, priority, created }

class TaskFilter {
  final int? categoryId; // null = all
  final String query;
  final Set<TaskStatus> statuses; // empty = all
  final Set<TaskPriority> priorities; // empty = all

  const TaskFilter({this.categoryId, this.query = '', this.statuses = const {}, this.priorities = const {}});

  bool get hasExtraFilters => statuses.isNotEmpty || priorities.isNotEmpty;

  bool matches(TaskItem t) {
    if (categoryId != null && t.categoryId != categoryId) return false;
    if (statuses.isNotEmpty && !statuses.contains(t.status)) return false;
    if (priorities.isNotEmpty && !priorities.contains(t.priority)) return false;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [t.title, t.notes, t.waitingOn, ...t.subtasks.map((s) => s.title)].join('\n').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  TaskFilter copyWith({
    int? categoryId,
    bool clearCategory = false,
    String? query,
    Set<TaskStatus>? statuses,
    Set<TaskPriority>? priorities,
  }) =>
      TaskFilter(
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        query: query ?? this.query,
        statuses: statuses ?? this.statuses,
        priorities: priorities ?? this.priorities,
      );
}

int _dueKey(TaskItem t) {
  final d = t.dueDate;
  if (d == null) return 1 << 50;
  return d.year * 100000000 + d.month * 1000000 + d.day * 10000 + (t.dueMinutes ?? 1439);
}

int compareTasks(TaskItem a, TaskItem b, TaskSort sort) {
  int c;
  switch (sort) {
    case TaskSort.manual:
      c = a.sortOrder.compareTo(b.sortOrder);
      break;
    case TaskSort.dueDate:
      c = _dueKey(a).compareTo(_dueKey(b));
      break;
    case TaskSort.priority:
      c = b.priority.index.compareTo(a.priority.index);
      if (c == 0) c = _dueKey(a).compareTo(_dueKey(b));
      break;
    case TaskSort.created:
      c = b.createdAt.compareTo(a.createdAt);
      break;
  }
  if (c != 0) return c;
  return (a.id ?? 0).compareTo(b.id ?? 0);
}

/// Groups tasks into sections, applying [filter] and [sort].
Map<TaskSection, List<TaskItem>> groupTasks(List<TaskItem> tasks, Day today, TaskFilter filter, TaskSort sort) {
  final result = {for (final s in TaskSection.values) s: <TaskItem>[]};
  for (final t in tasks) {
    if (!filter.matches(t)) continue;
    result[sectionOf(t, today)]!.add(t);
  }
  for (final entry in result.entries) {
    if (entry.key == TaskSection.completed) {
      entry.value.sort((a, b) => (b.completedAt ?? 0).compareTo(a.completedAt ?? 0));
    } else {
      entry.value.sort((a, b) => compareTasks(a, b, sort));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Calendar

class CalendarTaskEntry {
  final TaskItem task;
  final bool isDue;
  final bool isFollowUp;
  CalendarTaskEntry(this.task, {required this.isDue, required this.isFollowUp});
}

class CalendarHabitEntry {
  final HabitWithData habit;
  final bool done;
  CalendarHabitEntry(this.habit, this.done);
}

class DayEntries {
  final List<CalendarTaskEntry> tasks;
  final List<CalendarHabitEntry> habits;
  DayEntries(this.tasks, this.habits);
  bool get isEmpty => tasks.isEmpty && habits.isEmpty;
}

/// Items for one calendar day. A task whose due and follow-up dates differ
/// appears on both days; when they coincide it appears once with both labels.
DayEntries entriesForDay(Day day, List<TaskItem> tasks, List<HabitWithData> habits, {int? categoryId}) {
  final taskEntries = <CalendarTaskEntry>[];
  for (final t in tasks) {
    if (categoryId != null && t.categoryId != categoryId) continue;
    final isDue = t.dueDate == day;
    final isFollow = t.followUpDate == day;
    if (isDue || isFollow) {
      taskEntries.add(CalendarTaskEntry(t, isDue: isDue, isFollowUp: isFollow));
    }
  }
  taskEntries.sort((a, b) {
    final c = (a.task.isCompleted ? 1 : 0).compareTo(b.task.isCompleted ? 1 : 0);
    if (c != 0) return c;
    return (a.task.dueMinutes ?? 2000).compareTo(b.task.dueMinutes ?? 2000);
  });
  final habitEntries = <CalendarHabitEntry>[];
  for (final h in habits) {
    if (h.habit.archived) continue;
    if (isScheduledOn(h, day)) {
      habitEntries.add(CalendarHabitEntry(h, h.completions.contains(day)));
    }
  }
  return DayEntries(taskEntries, habitEntries);
}

class DayMarkers {
  bool due = false;
  bool followUp = false;
  bool habitDone = false;
}

Map<Day, DayMarkers> markersForRange(DayRange range, List<TaskItem> tasks, List<HabitWithData> habits,
    {int? categoryId}) {
  final m = <Day, DayMarkers>{};
  for (final t in tasks) {
    if (categoryId != null && t.categoryId != categoryId) continue;
    final due = t.dueDate;
    if (due != null && range.contains(due)) {
      m.putIfAbsent(due, () => DayMarkers()).due = true;
    }
    final f = t.followUpDate;
    if (f != null && range.contains(f)) {
      m.putIfAbsent(f, () => DayMarkers()).followUp = true;
    }
  }
  for (final h in habits) {
    if (h.habit.archived) continue;
    for (final c in h.completions) {
      if (range.contains(c)) m.putIfAbsent(c, () => DayMarkers()).habitDone = true;
    }
  }
  return m;
}
