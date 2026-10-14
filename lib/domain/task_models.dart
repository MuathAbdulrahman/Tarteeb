import '../core/day.dart';

enum TaskPriority { normal, medium, high }

enum TaskStatus { notStarted, inProgress, waiting, completed }

TaskPriority priorityFromName(String? s) =>
    TaskPriority.values.firstWhere((e) => e.name == s, orElse: () => TaskPriority.normal);

TaskStatus statusFromName(String? s) =>
    TaskStatus.values.firstWhere((e) => e.name == s, orElse: () => TaskStatus.notStarted);

class TaskCategory {
  int? id;

  /// Key of a built-in category ('work', 'personal', 'wishlist'); null for user categories.
  String? nameKey;

  /// User-provided name. When null, the localized name of [nameKey] is shown.
  String? name;
  int color;
  int sortOrder;

  TaskCategory({
    this.id,
    this.nameKey,
    this.name,
    required this.color,
    required this.sortOrder,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name_key': nameKey,
        'name': name,
        'color': color,
        'sort_order': sortOrder,
      };

  factory TaskCategory.fromMap(Map<String, Object?> m) => TaskCategory(
        id: m['id'] as int?,
        nameKey: m['name_key'] as String?,
        name: m['name'] as String?,
        color: m['color'] as int,
        sortOrder: m['sort_order'] as int,
      );
}

class Subtask {
  int? id;
  int taskId;
  String title;
  bool done;
  int sortOrder;

  Subtask({this.id, required this.taskId, required this.title, this.done = false, required this.sortOrder});

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'title': title,
        'done': done ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Subtask.fromMap(Map<String, Object?> m) => Subtask(
        id: m['id'] as int?,
        taskId: m['task_id'] as int,
        title: m['title'] as String,
        done: (m['done'] as int) == 1,
        sortOrder: m['sort_order'] as int,
      );

  Subtask copy() => Subtask(id: id, taskId: taskId, title: title, done: done, sortOrder: sortOrder);
}

class TaskItem {
  int? id;
  String title;
  int? categoryId;
  String notes;
  TaskPriority priority;
  TaskStatus status;

  /// Status to restore when a completed task is reopened.
  TaskStatus? statusBeforeComplete;
  Day? dueDate;

  /// Minutes after midnight; only meaningful when [dueDate] is set.
  int? dueMinutes;

  /// Absolute reminder time in epoch milliseconds.
  int? reminderAt;
  Day? followUpDate;
  String waitingOn;
  int sortOrder;
  int createdAt;
  int updatedAt;
  int? completedAt;
  bool isDemo;
  List<Subtask> subtasks;

  TaskItem({
    this.id,
    required this.title,
    this.categoryId,
    this.notes = '',
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.notStarted,
    this.statusBeforeComplete,
    this.dueDate,
    this.dueMinutes,
    this.reminderAt,
    this.followUpDate,
    this.waitingOn = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.isDemo = false,
    List<Subtask>? subtasks,
  }) : subtasks = subtasks ?? [];

  bool get isCompleted => status == TaskStatus.completed;
  int get doneSubtasks => subtasks.where((s) => s.done).length;
  bool get hasUnfinishedSubtasks => subtasks.any((s) => !s.done);

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'category_id': categoryId,
        'notes': notes,
        'priority': priority.name,
        'status': status.name,
        'status_before_complete': statusBeforeComplete?.name,
        'due_date': dueDate?.toIso(),
        'due_minutes': dueMinutes,
        'reminder_at': reminderAt,
        'follow_up_date': followUpDate?.toIso(),
        'waiting_on': waitingOn,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'completed_at': completedAt,
        'is_demo': isDemo ? 1 : 0,
      };

  factory TaskItem.fromMap(Map<String, Object?> m) => TaskItem(
        id: m['id'] as int?,
        title: m['title'] as String,
        categoryId: m['category_id'] as int?,
        notes: (m['notes'] as String?) ?? '',
        priority: priorityFromName(m['priority'] as String?),
        status: statusFromName(m['status'] as String?),
        statusBeforeComplete:
            m['status_before_complete'] == null ? null : statusFromName(m['status_before_complete'] as String?),
        dueDate: Day.tryParse(m['due_date'] as String?),
        dueMinutes: m['due_minutes'] as int?,
        reminderAt: m['reminder_at'] as int?,
        followUpDate: Day.tryParse(m['follow_up_date'] as String?),
        waitingOn: (m['waiting_on'] as String?) ?? '',
        sortOrder: (m['sort_order'] as int?) ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        completedAt: m['completed_at'] as int?,
        isDemo: ((m['is_demo'] as int?) ?? 0) == 1,
      );

  TaskItem copy() => TaskItem(
        id: id,
        title: title,
        categoryId: categoryId,
        notes: notes,
        priority: priority,
        status: status,
        statusBeforeComplete: statusBeforeComplete,
        dueDate: dueDate,
        dueMinutes: dueMinutes,
        reminderAt: reminderAt,
        followUpDate: followUpDate,
        waitingOn: waitingOn,
        sortOrder: sortOrder,
        createdAt: createdAt,
        updatedAt: updatedAt,
        completedAt: completedAt,
        isDemo: isDemo,
        subtasks: subtasks.map((s) => s.copy()).toList(),
      );
}

/// Timestamped follow-up update. Append-only: new updates never overwrite older ones.
class TaskUpdate {
  int? id;
  int taskId;
  String body;
  int createdAt;

  TaskUpdate({this.id, required this.taskId, required this.body, required this.createdAt});

  Map<String, Object?> toMap() => {'id': id, 'task_id': taskId, 'body': body, 'created_at': createdAt};

  factory TaskUpdate.fromMap(Map<String, Object?> m) => TaskUpdate(
        id: m['id'] as int?,
        taskId: m['task_id'] as int,
        body: m['body'] as String,
        createdAt: m['created_at'] as int,
      );
}

/// Kinds of task activity entries.
class ActivityKind {
  static const created = 'created';
  static const edited = 'edited';
  static const statusChanged = 'status';
  static const completed = 'completed';
  static const reopened = 'reopened';
  static const dueChanged = 'due';
  static const followUpChanged = 'followup';
  static const subtaskAdded = 'subtask_added';
  static const subtaskDone = 'subtask_done';
  static const subtaskUndone = 'subtask_undone';
  static const updateAdded = 'update_added';
}

class TaskActivity {
  int? id;
  int taskId;
  String kind;
  String detail;
  int createdAt;

  TaskActivity({this.id, required this.taskId, required this.kind, this.detail = '', required this.createdAt});

  Map<String, Object?> toMap() =>
      {'id': id, 'task_id': taskId, 'kind': kind, 'detail': detail, 'created_at': createdAt};

  factory TaskActivity.fromMap(Map<String, Object?> m) => TaskActivity(
        id: m['id'] as int?,
        taskId: m['task_id'] as int,
        kind: m['kind'] as String,
        detail: (m['detail'] as String?) ?? '',
        createdAt: m['created_at'] as int,
      );
}
