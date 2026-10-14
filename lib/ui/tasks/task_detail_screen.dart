import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/task_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';
import 'task_card.dart';
import 'task_editor_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _updateCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  List<TaskUpdate> _updates = [];
  List<TaskActivity> _activity = [];
  int _loadedFor = -1;
  bool _showAllActivity = false;

  @override
  void dispose() {
    _updateCtrl.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(TaskItem t) async {
    final app = AppScope.read(context);
    final u = await app.taskRepo.updates(t.id!);
    final a = await app.taskRepo.activity(t.id!);
    if (!mounted) return;
    setState(() {
      _updates = u;
      _activity = a;
    });
  }

  Future<void> _setStatus(TaskItem t, TaskStatus s) async {
    if (s == t.status) return;
    if (s == TaskStatus.completed || t.isCompleted) {
      await toggleTaskCompletion(context, t);
      return;
    }
    final before = t.copy();
    final edited = t.copy()..status = s;
    await AppScope.read(context).saveTask(edited, before);
  }

  Future<void> _delete(TaskItem t) async {
    final app = AppScope.read(context);
    final ok = await confirmDialog(context, title: tr.deleteTaskQ, body: t.title, confirmLabel: tr.delete, destructive: true);
    if (!ok || !mounted) return;
    final id = t.id!;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await app.deleteTask(t);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(tr.taskDeleted),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: tr.undo, onPressed: () => app.undoDeleteTask(id)),
    ));
  }

  String _activityText(TaskActivity a) {
    String parts(int i) {
      final ps = a.detail.split('|');
      return i < ps.length ? ps[i] : '';
    }

    String dayOrNone(String iso) {
      final d = Day.tryParse(iso);
      return d == null ? tr.none : formatDayShort(d);
    }

    switch (a.kind) {
      case ActivityKind.created:
        return tr.actCreated;
      case ActivityKind.edited:
        return tr.actEdited;
      case ActivityKind.statusChanged:
        return tr.actStatus(tr.statusLabel(statusFromName(parts(0))), tr.statusLabel(statusFromName(parts(1))));
      case ActivityKind.completed:
        return tr.actCompleted;
      case ActivityKind.reopened:
        return tr.actReopened;
      case ActivityKind.dueChanged:
        return tr.actDue(dayOrNone(parts(0)), dayOrNone(parts(1)));
      case ActivityKind.followUpChanged:
        return tr.actFollowUp(dayOrNone(parts(0)), dayOrNone(parts(1)));
      case ActivityKind.subtaskAdded:
        return tr.actSubAdded(a.detail);
      case ActivityKind.subtaskDone:
        return tr.actSubDone(a.detail);
      case ActivityKind.subtaskUndone:
        return tr.actSubUndone(a.detail);
      case ActivityKind.updateAdded:
        return tr.actUpdate;
    }
    return a.kind;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final t = app.taskById(widget.taskId);
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.search_off, title: tr.taskNotFound));
    }
    if (_loadedFor != t.updatedAt) {
      _loadedFor = t.updatedAt;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory(t));
    }
    final cat = app.categoryById(t.categoryId);
    final activity = _showAllActivity ? _activity : _activity.take(8).toList();

    Widget infoRow(IconData icon, String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color ?? p.textMuted),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 14))),
              Expanded(
                child: Text(value,
                    style: TextStyle(color: color ?? p.text, fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );

    final today = Day.today();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.taskDetails),
        actions: [
          IconButton(
            tooltip: tr.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: t))),
          ),
          IconButton(tooltip: tr.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(t)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.only(bottom: 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompletionCircle(
                        done: t.isCompleted,
                        color: t.isCompleted ? p.success : p.accent,
                        semanticLabel: t.isCompleted ? tr.markNotDone : tr.markDone,
                        size: 28,
                        onTap: () => toggleTaskCompletion(context, t),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: p.text,
                              decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (cat != null)
                      Pill(
                          text: tr.categoryName(cat),
                          fg: Color(cat.color),
                          bg: Color(cat.color).withValues(alpha: 0.12)),
                    Pill(
                      text: tr.priorityLabel(t.priority),
                      fg: priorityColor(p, t.priority),
                      bg: priorityColor(p, t.priority).withValues(alpha: 0.12),
                      icon: Icons.flag_outlined,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(tr.status, style: TextStyle(color: p.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final s in TaskStatus.values)
                      ChoiceChip(
                        label: Text(tr.statusLabel(s)),
                        selected: t.status == s,
                        onSelected: (_) => _setStatus(t, s),
                      ),
                  ]),
                ],
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  infoRow(
                    Icons.event_outlined,
                    tr.dueDate,
                    t.dueDate == null
                        ? tr.noDueDate
                        : (t.dueMinutes == null
                            ? formatDayLong(t.dueDate!)
                            : '${formatDayLong(t.dueDate!)} · ${formatMinutes(t.dueMinutes!)}'),
                    color: (!t.isCompleted && t.dueDate != null && t.dueDate!.isBefore(today)) ? p.danger : null,
                  ),
                  infoRow(Icons.reply_outlined, tr.followUpDate,
                      t.followUpDate == null ? tr.none : formatDayLong(t.followUpDate!),
                      color: t.followUpDate == null ? null : p.followUp),
                  infoRow(Icons.notifications_none, tr.reminder,
                      t.reminderAt == null ? tr.none : formatDateTimeMs(t.reminderAt!)),
                  infoRow(Icons.hourglass_empty, tr.waitingOn, t.waitingOn.isEmpty ? tr.none : t.waitingOn),
                  if (t.notes.isNotEmpty) infoRow(Icons.notes, tr.notes, t.notes),
                ],
              ),
            ),
            SectionLabel(tr.subtasksProgress(t.doneSubtasks, t.subtasks.length)),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldI, newI) {
                      if (newI > oldI) newI -= 1;
                      final list = [...t.subtasks];
                      final item = list.removeAt(oldI);
                      list.insert(newI, item);
                      app.reorderSubtasks(t, list);
                    },
                    children: [
                      for (var i = 0; i < t.subtasks.length; i++)
                        Row(
                          key: ValueKey('st-${t.subtasks[i].id}'),
                          children: [
                            CompletionCircle(
                              done: t.subtasks[i].done,
                              size: 22,
                              color: t.subtasks[i].done ? p.success : p.textMuted,
                              semanticLabel: t.subtasks[i].done ? tr.markNotDone : tr.markDone,
                              onTap: () => app.setSubtaskDone(t, t.subtasks[i], !t.subtasks[i].done),
                            ),
                            Expanded(
                              child: Text(
                                t.subtasks[i].title,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: t.subtasks[i].done ? p.textMuted : p.text,
                                  decoration: t.subtasks[i].done ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(Icons.drag_indicator, color: p.textMuted),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.add, color: p.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _subCtrl,
                          decoration: InputDecoration(hintText: tr.addSubtask, border: InputBorder.none),
                          onSubmitted: (v) async {
                            if (v.trim().isEmpty) return;
                            await app.addSubtask(t, v.trim());
                            _subCtrl.clear();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionLabel(tr.followUpUpdates),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _updateCtrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(hintText: tr.writeUpdate, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final body = _updateCtrl.text.trim();
                        if (body.isEmpty) return;
                        await app.addTaskUpdate(t.id!, body);
                        _updateCtrl.clear();
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(tr.addUpdate),
                    ),
                  ),
                  if (_updates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(tr.noUpdates, style: TextStyle(color: p.textMuted)),
                    ),
                  for (final u in _updates)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDateTimeMs(u.createdAt), style: TextStyle(fontSize: 12, color: p.textMuted)),
                          const SizedBox(height: 4),
                          Text(u.body, style: TextStyle(fontSize: 15, color: p.text, height: 1.4)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SectionLabel(tr.activityHistory),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in activity)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle, size: 7, color: p.accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_activityText(a), style: TextStyle(fontSize: 14, color: p.text)),
                                Text(formatDateTimeMs(a.createdAt), style: TextStyle(fontSize: 12, color: p.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_activity.length > 8 && !_showAllActivity)
                    TextButton(onPressed: () => setState(() => _showAllActivity = true), child: Text(tr.showAll)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
