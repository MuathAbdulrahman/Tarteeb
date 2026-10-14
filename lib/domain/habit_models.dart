import '../core/day.dart';

const int kAllWeekdaysMask = 0x7F; // Sunday..Saturday

class Habit {
  int? id;
  String name;
  String icon;
  int color;
  Day startDate;

  /// Reminder time in minutes after midnight, or null for no reminder.
  int? reminderMinutes;
  int sortOrder;
  bool archived;
  int createdAt;
  bool isDemo;

  Habit({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.startDate,
    this.reminderMinutes,
    this.sortOrder = 0,
    this.archived = false,
    required this.createdAt,
    this.isDemo = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'start_date': startDate.toIso(),
        'reminder_minutes': reminderMinutes,
        'sort_order': sortOrder,
        'archived': archived ? 1 : 0,
        'created_at': createdAt,
        'is_demo': isDemo ? 1 : 0,
      };

  factory Habit.fromMap(Map<String, Object?> m) => Habit(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: (m['icon'] as String?) ?? 'check',
        color: m['color'] as int,
        startDate: Day.parse(m['start_date'] as String),
        reminderMinutes: m['reminder_minutes'] as int?,
        sortOrder: (m['sort_order'] as int?) ?? 0,
        archived: ((m['archived'] as int?) ?? 0) == 1,
        createdAt: m['created_at'] as int,
        isDemo: ((m['is_demo'] as int?) ?? 0) == 1,
      );
}

/// A schedule version. The schedule that applies to a day is the version with
/// the latest [effectiveFrom] that is on or before that day. Editing a schedule
/// adds a new version starting today, so history is never rewritten.
class HabitSchedule {
  int? id;
  int habitId;
  Day effectiveFrom;

  /// Bit i set => scheduled on weekday i (0 = Sunday ... 6 = Saturday).
  int weekdayMask;

  HabitSchedule({this.id, required this.habitId, required this.effectiveFrom, required this.weekdayMask});

  bool get isDaily => weekdayMask & kAllWeekdaysMask == kAllWeekdaysMask;
  bool includes(Day d) => (weekdayMask >> d.weekdayIndex) & 1 == 1;

  Map<String, Object?> toMap() => {
        'id': id,
        'habit_id': habitId,
        'effective_from': effectiveFrom.toIso(),
        'weekday_mask': weekdayMask,
      };

  factory HabitSchedule.fromMap(Map<String, Object?> m) => HabitSchedule(
        id: m['id'] as int?,
        habitId: m['habit_id'] as int,
        effectiveFrom: Day.parse(m['effective_from'] as String),
        weekdayMask: m['weekday_mask'] as int,
      );
}

/// Aggregate used by UI: habit plus its schedule history and completion days.
class HabitWithData {
  final Habit habit;
  final List<HabitSchedule> schedules; // sorted by effectiveFrom ascending
  final Set<Day> completions;

  HabitWithData(this.habit, this.schedules, this.completions);
}
