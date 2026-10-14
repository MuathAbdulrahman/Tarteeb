import 'package:sqflite/sqflite.dart';

import '../core/day.dart';
import '../domain/habit_models.dart';

class HabitRepo {
  final Database db;
  HabitRepo(this.db);

  int _now() => AppClock.now().millisecondsSinceEpoch;

  Future<List<HabitWithData>> all() async {
    final habits = (await db.query('habits', orderBy: 'sort_order, id')).map(Habit.fromMap).toList();
    final schedRows = await db.query('habit_schedules', orderBy: 'effective_from');
    final compRows = await db.query('habit_completions');
    final sched = <int, List<HabitSchedule>>{};
    for (final r in schedRows) {
      final s = HabitSchedule.fromMap(r);
      sched.putIfAbsent(s.habitId, () => []).add(s);
    }
    final comps = <int, Set<Day>>{};
    for (final r in compRows) {
      final d = Day.tryParse(r['day'] as String?);
      if (d != null) comps.putIfAbsent(r['habit_id'] as int, () => <Day>{}).add(d);
    }
    return [
      for (final h in habits) HabitWithData(h, sched[h.id] ?? [], comps[h.id] ?? <Day>{}),
    ];
  }

  Future<Habit> insert(Habit h, int weekdayMask) async {
    await db.transaction((tx) async {
      final maxOrder =
          Sqflite.firstIntValue(await tx.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM habits')) ?? -1;
      h.sortOrder = maxOrder + 1;
      h.createdAt = h.createdAt == 0 ? _now() : h.createdAt;
      h.id = await tx.insert('habits', h.toMap()..remove('id'));
      await tx.insert('habit_schedules', {
        'habit_id': h.id,
        'effective_from': h.startDate.toIso(),
        'weekday_mask': weekdayMask,
      });
    });
    return h;
  }

  /// Updates habit fields. A changed schedule takes effect from today (or the
  /// start date if that is later); earlier schedule versions are untouched.
  Future<void> update(Habit h, int newMask, {required Day today}) async {
    await db.transaction((tx) async {
      await tx.update('habits', h.toMap()..remove('id'), where: 'id = ?', whereArgs: [h.id]);
      final rows = await tx.query('habit_schedules',
          where: 'habit_id = ?', whereArgs: [h.id], orderBy: 'effective_from');
      var schedules = rows.map(HabitSchedule.fromMap).toList();

      // Align the first schedule version with the (possibly edited) start date.
      if (schedules.isNotEmpty) {
        HabitSchedule anchor = schedules.first;
        for (final s in schedules) {
          if (s.effectiveFrom.isSameOrBefore(h.startDate)) anchor = s;
        }
        for (final s in schedules) {
          if (s.effectiveFrom.isBefore(anchor.effectiveFrom)) {
            await tx.delete('habit_schedules', where: 'id = ?', whereArgs: [s.id]);
          }
        }
        if (anchor.effectiveFrom != h.startDate) {
          await tx.update('habit_schedules', {'effective_from': h.startDate.toIso()},
              where: 'id = ?', whereArgs: [anchor.id]);
        }
        final reread = await tx.query('habit_schedules',
            where: 'habit_id = ?', whereArgs: [h.id], orderBy: 'effective_from');
        schedules = reread.map(HabitSchedule.fromMap).toList();
      }

      final effective = today.isBefore(h.startDate) ? h.startDate : today;
      HabitSchedule? current;
      for (final s in schedules) {
        if (s.effectiveFrom.isSameOrBefore(effective)) current = s;
      }
      // Remove any versions scheduled after the new effective date.
      for (final s in schedules) {
        if (s.effectiveFrom.isAfter(effective)) {
          await tx.delete('habit_schedules', where: 'id = ?', whereArgs: [s.id]);
        }
      }
      if (current != null && current.weekdayMask == newMask) return;
      if (current != null && current.effectiveFrom == effective) {
        await tx.update('habit_schedules', {'weekday_mask': newMask}, where: 'id = ?', whereArgs: [current.id]);
      } else {
        await tx.insert('habit_schedules', {
          'habit_id': h.id,
          'effective_from': effective.toIso(),
          'weekday_mask': newMask,
        });
      }
    });
  }

  /// Inserts a completion. Duplicates are prevented by the primary key.
  Future<bool> addCompletion(int habitId, Day day) async {
    final existing = await db.query('habit_completions',
        where: 'habit_id = ? AND day = ?', whereArgs: [habitId, day.toIso()], limit: 1);
    if (existing.isNotEmpty) return false;
    await db.insert(
      'habit_completions',
      {'habit_id': habitId, 'day': day.toIso(), 'created_at': _now()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return true;
  }

  Future<void> removeCompletion(int habitId, Day day) async {
    await db.delete('habit_completions', where: 'habit_id = ? AND day = ?', whereArgs: [habitId, day.toIso()]);
  }

  Future<void> delete(int id) async {
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setArchived(int id, bool archived) async {
    await db.update('habits', {'archived': archived ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorder(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('habits', {'sort_order': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
  }

  Future<void> deleteDemo() async {
    await db.delete('habits', where: 'is_demo = 1');
  }
}
