import '../core/day.dart';
import 'habit_models.dart';

/// Returns the schedule version effective on [d], or null if [d] precedes all versions.
HabitSchedule? scheduleFor(List<HabitSchedule> sortedSchedules, Day d) {
  HabitSchedule? result;
  for (final s in sortedSchedules) {
    if (s.effectiveFrom.isSameOrBefore(d)) {
      result = s;
    } else {
      break;
    }
  }
  return result;
}

bool isScheduledOn(HabitWithData h, Day d) {
  if (d.isBefore(h.habit.startDate)) return false;
  final s = scheduleFor(h.schedules, d);
  return s != null && s.includes(d);
}

enum CompletionError { future, beforeStart, notScheduled, duplicate }

/// Validates whether [d] may be marked complete. Returns null when allowed.
CompletionError? validateCompletion(HabitWithData h, Day d, Day today) {
  if (d.isAfter(today)) return CompletionError.future;
  if (d.isBefore(h.habit.startDate)) return CompletionError.beforeStart;
  if (!isScheduledOn(h, d)) return CompletionError.notScheduled;
  if (h.completions.contains(d)) return CompletionError.duplicate;
  return null;
}

class HabitStats {
  final int totalCompleted;
  final int currentStreak;
  final int longestStreak;
  final bool doneToday;
  final bool scheduledToday;

  const HabitStats({
    required this.totalCompleted,
    required this.currentStreak,
    required this.longestStreak,
    required this.doneToday,
    required this.scheduledToday,
  });
}

/// Streak rules:
/// * Only scheduled days count; unscheduled days neither extend nor break a streak.
/// * A missed scheduled day before today breaks the streak.
/// * Today, if not yet completed, does not break the streak.
HabitStats computeHabitStats(HabitWithData h, Day today) {
  var run = 0;
  var longest = 0;
  final schedules = h.schedules;
  var idx = -1; // index of the schedule in effect
  var d = h.habit.startDate;
  while (d.isSameOrBefore(today)) {
    while (idx + 1 < schedules.length && schedules[idx + 1].effectiveFrom.isSameOrBefore(d)) {
      idx++;
    }
    final scheduled = idx >= 0 && schedules[idx].includes(d);
    if (scheduled) {
      if (h.completions.contains(d)) {
        run++;
        if (run > longest) longest = run;
      } else if (d != today) {
        run = 0;
      }
    }
    d = d.addDays(1);
  }
  final total = h.completions.where((c) => c.isSameOrBefore(today)).length;
  return HabitStats(
    totalCompleted: total,
    currentStreak: run,
    longestStreak: longest,
    doneToday: h.completions.contains(today),
    scheduledToday: isScheduledOn(h, today),
  );
}

/// The schedule mask in effect from [today] onward (latest version).
int currentMask(HabitWithData h) =>
    h.schedules.isEmpty ? kAllWeekdaysMask : h.schedules.last.weekdayMask;
