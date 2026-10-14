import 'package:sqflite/sqflite.dart';

import '../core/day.dart';
import '../domain/task_models.dart';

/// Default categories. Names come from [nameKey] until the user renames them.
List<TaskCategory> defaultTaskCategories() => [
      TaskCategory(nameKey: 'work', color: 0xFF3B7DD8, sortOrder: 0),
      TaskCategory(nameKey: 'personal', color: 0xFF2E9E8F, sortOrder: 1),
      TaskCategory(nameKey: 'wishlist', color: 0xFFC77D2E, sortOrder: 2),
    ];

class TaskRepo {
  final Database db;
  TaskRepo(this.db);

  int _now() => AppClock.now().millisecondsSinceEpoch;

  // ---- categories ----

  Future<void> seedCategoriesIfEmpty() async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM task_categories')) ?? 0;
    if (count > 0) return;
    final b = db.batch();
    for (final c in defaultTaskCategories()) {
      final m = c.toMap()..remove('id');
      b.insert('task_categories', m);
    }
    await b.commit(noResult: true);
  }

  Future<List<TaskCategory>> categories() async {
    final rows = await db.query('task_categories', orderBy: 'sort_order, id');
    return rows.map(TaskCategory.fromMap).toList();
  }

  Future<int> insertCategory(TaskCategory c) async {
    final maxOrder =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM task_categories')) ?? -1;
    c.sortOrder = maxOrder + 1;
    final m = c.toMap()..remove('id');
    c.id = await db.insert('task_categories', m);
    return c.id!;
  }

  Future<void> updateCategory(TaskCategory c) async {
    await db.update('task_categories', c.toMap()..remove('id'), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCategory(int id) async {
    await db.delete('task_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderCategories(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('task_categories', {'sort_order': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
  }

  // ---- tasks ----

  Future<List<TaskItem>> allTasks() async {
    final rows = await db.query('tasks', where: 'deleted_at IS NULL', orderBy: 'sort_order, id');
    final tasks = rows.map(TaskItem.fromMap).toList();
    final subRows = await db.rawQuery(
        'SELECT s.* FROM subtasks s JOIN tasks t ON t.id = s.task_id WHERE t.deleted_at IS NULL ORDER BY s.sort_order, s.id');
    final byTask = <int, List<Subtask>>{};
    for (final r in subRows) {
      final s = Subtask.fromMap(r);
      byTask.putIfAbsent(s.taskId, () => []).add(s);
    }
    for (final t in tasks) {
      t.subtasks = byTask[t.id] ?? [];
    }
    return tasks;
  }

  Future<TaskItem?> getTask(int id) async {
    final rows = await db.query('tasks', where: 'id = ? AND deleted_at IS NULL', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final t = TaskItem.fromMap(rows.first);
    final subs = await db.query('subtasks', where: 'task_id = ?', whereArgs: [id], orderBy: 'sort_order, id');
    t.subtasks = subs.map(Subtask.fromMap).toList();
    return t;
  }

  Future<int> _nextSortOrder(DatabaseExecutor ex) async =>
      (Sqflite.firstIntValue(await ex.rawQuery('SELECT COALESCE(MAX(sort_order), -1) FROM tasks')) ?? -1) + 1;

  Future<TaskItem> insertTask(TaskItem t) async {
    await db.transaction((tx) async {
      final now = _now();
      t.createdAt = t.createdAt == 0 ? now : t.createdAt;
      t.updatedAt = now;
      t.sortOrder = await _nextSortOrder(tx);
      if (t.isCompleted) {
        t.completedAt ??= now;
      }
      t.id = await tx.insert('tasks', t.toMap()..remove('id'));
      for (var i = 0; i < t.subtasks.length; i++) {
        final s = t.subtasks[i];
        s.taskId = t.id!;
        s.sortOrder = i;
        s.id = await tx.insert('subtasks', s.toMap()..remove('id'));
      }
      await _log(tx, t.id!, ActivityKind.created, '');
    });
    return t;
  }

  /// Saves edits made in the editor, syncing subtasks and logging what changed.
  Future<void> updateTask(TaskItem t, TaskItem before) async {
    await db.transaction((tx) async {
      final now = _now();
      t.updatedAt = now;
      if (t.isCompleted && !before.isCompleted) {
        t.completedAt = now;
        t.statusBeforeComplete = before.status;
      } else if (!t.isCompleted) {
        t.completedAt = null;
      }
      await tx.update('tasks', t.toMap()..remove('id'), where: 'id = ?', whereArgs: [t.id]);
      await _syncSubtasks(tx, t, before);
      if (t.status != before.status) {
        final kind = t.isCompleted
            ? ActivityKind.completed
            : (before.isCompleted ? ActivityKind.reopened : ActivityKind.statusChanged);
        await _log(tx, t.id!, kind, '${before.status.name}|${t.status.name}');
      }
      if (t.dueDate != before.dueDate || t.dueMinutes != before.dueMinutes) {
        await _log(tx, t.id!, ActivityKind.dueChanged, '${before.dueDate?.toIso() ?? ''}|${t.dueDate?.toIso() ?? ''}');
      }
      if (t.followUpDate != before.followUpDate) {
        await _log(tx, t.id!, ActivityKind.followUpChanged,
            '${before.followUpDate?.toIso() ?? ''}|${t.followUpDate?.toIso() ?? ''}');
      }
      final otherChanged = t.title != before.title ||
          t.notes != before.notes ||
          t.priority != before.priority ||
          t.categoryId != before.categoryId ||
          t.waitingOn != before.waitingOn ||
          t.reminderAt != before.reminderAt;
      if (otherChanged) await _log(tx, t.id!, ActivityKind.edited, '');
    });
  }

  Future<void> _syncSubtasks(Transaction tx, TaskItem t, TaskItem before) async {
    final keepIds = t.subtasks.where((s) => s.id != null).map((s) => s.id!).toSet();
    for (final old in before.subtasks) {
      if (old.id != null && !keepIds.contains(old.id)) {
        await tx.delete('subtasks', where: 'id = ?', whereArgs: [old.id]);
      }
    }
    final oldById = {for (final s in before.subtasks) s.id: s};
    for (var i = 0; i < t.subtasks.length; i++) {
      final s = t.subtasks[i];
      s.taskId = t.id!;
      s.sortOrder = i;
      if (s.id == null) {
        s.id = await tx.insert('subtasks', s.toMap()..remove('id'));
        await _log(tx, t.id!, ActivityKind.subtaskAdded, s.title);
      } else {
        await tx.update('subtasks', s.toMap()..remove('id'), where: 'id = ?', whereArgs: [s.id]);
        final old = oldById[s.id];
        if (old != null && old.done != s.done) {
          await _log(tx, t.id!, s.done ? ActivityKind.subtaskDone : ActivityKind.subtaskUndone, s.title);
        }
      }
    }
  }

  /// Marks a task complete or reopens it. When [completeSubtasks] is true all
  /// subtasks are completed too.
  Future<void> setCompleted(TaskItem t, bool done, {bool completeSubtasks = false}) async {
    await db.transaction((tx) async {
      final now = _now();
      if (done) {
        if (!t.isCompleted) t.statusBeforeComplete = t.status;
        t.status = TaskStatus.completed;
        t.completedAt = now;
      } else {
        final restore = t.statusBeforeComplete;
        t.status = (restore == null || restore == TaskStatus.completed) ? TaskStatus.notStarted : restore;
        t.completedAt = null;
      }
      t.updatedAt = now;
      await tx.update(
          'tasks',
          {
            'status': t.status.name,
            'status_before_complete': t.statusBeforeComplete?.name,
            'completed_at': t.completedAt,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [t.id]);
      if (done && completeSubtasks) {
        for (final s in t.subtasks.where((s) => !s.done)) {
          s.done = true;
          await tx.update('subtasks', {'done': 1}, where: 'id = ?', whereArgs: [s.id]);
          await _log(tx, t.id!, ActivityKind.subtaskDone, s.title);
        }
      }
      await _log(tx, t.id!, done ? ActivityKind.completed : ActivityKind.reopened, '');
    });
  }

  Future<void> setSubtaskDone(TaskItem t, Subtask s, bool done) async {
    await db.transaction((tx) async {
      s.done = done;
      await tx.update('subtasks', {'done': done ? 1 : 0}, where: 'id = ?', whereArgs: [s.id]);
      await tx.update('tasks', {'updated_at': _now()}, where: 'id = ?', whereArgs: [t.id]);
      await _log(tx, t.id!, done ? ActivityKind.subtaskDone : ActivityKind.subtaskUndone, s.title);
    });
  }

  Future<void> addSubtask(TaskItem t, String title) async {
    await db.transaction((tx) async {
      final order = t.subtasks.isEmpty ? 0 : t.subtasks.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      final s = Subtask(taskId: t.id!, title: title, sortOrder: order);
      s.id = await tx.insert('subtasks', s.toMap()..remove('id'));
      t.subtasks.add(s);
      await _log(tx, t.id!, ActivityKind.subtaskAdded, title);
    });
  }

  Future<void> reorderSubtasks(List<Subtask> ordered) async {
    final b = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      ordered[i].sortOrder = i;
      b.update('subtasks', {'sort_order': i}, where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await b.commit(noResult: true);
  }

  Future<void> reorderTasks(List<int> ids) async {
    final b = db.batch();
    for (var i = 0; i < ids.length; i++) {
      b.update('tasks', {'sort_order': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await b.commit(noResult: true);
  }

  Future<void> softDelete(int id) async {
    await db.update('tasks', {'deleted_at': _now()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restore(int id) async {
    await db.update('tasks', {'deleted_at': null}, where: 'id = ?', whereArgs: [id]);
  }

  /// Permanently removes soft-deleted tasks (called at startup, after the undo window).
  Future<void> purgeDeleted() async {
    await db.delete('tasks', where: 'deleted_at IS NOT NULL');
  }

  Future<void> deleteDemoTasks() async {
    await db.delete('tasks', where: 'is_demo = 1');
  }

  // ---- follow-up updates & activity ----

  Future<List<TaskUpdate>> updates(int taskId) async {
    final rows =
        await db.query('task_updates', where: 'task_id = ?', whereArgs: [taskId], orderBy: 'created_at DESC, id DESC');
    return rows.map(TaskUpdate.fromMap).toList();
  }

  Future<void> addUpdate(int taskId, String body) async {
    await db.transaction((tx) async {
      final now = _now();
      await tx.insert('task_updates', {'task_id': taskId, 'body': body, 'created_at': now});
      await tx.update('tasks', {'updated_at': now}, where: 'id = ?', whereArgs: [taskId]);
      await _log(tx, taskId, ActivityKind.updateAdded, '');
    });
  }

  Future<List<TaskActivity>> activity(int taskId) async {
    final rows =
        await db.query('task_activity', where: 'task_id = ?', whereArgs: [taskId], orderBy: 'created_at DESC, id DESC');
    return rows.map(TaskActivity.fromMap).toList();
  }

  Future<void> _log(DatabaseExecutor ex, int taskId, String kind, String detail) async {
    await ex.insert('task_activity', {'task_id': taskId, 'kind': kind, 'detail': detail, 'created_at': _now()});
  }
}
