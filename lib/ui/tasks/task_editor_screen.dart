import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/task_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';

class _SubDraft {
  final Subtask sub;
  final TextEditingController ctrl;
  _SubDraft(this.sub) : ctrl = TextEditingController(text: sub.title);
}

/// Create or edit a task. Pass [task] to edit.
class TaskEditorScreen extends StatefulWidget {
  final TaskItem? task;
  final int? initialCategoryId;
  final Day? initialDueDate;
  const TaskEditorScreen({super.key, this.task, this.initialCategoryId, this.initialDueDate});

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TaskItem _draft;
  late final TaskItem? _before;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _waiting;
  final _newSub = TextEditingController();
  final List<_SubDraft> _subs = [];
  bool _saving = false;

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().millisecondsSinceEpoch;
    _before = widget.task?.copy();
    _draft = widget.task?.copy() ??
        TaskItem(
          title: '',
          categoryId: widget.initialCategoryId,
          dueDate: widget.initialDueDate,
          createdAt: now,
          updatedAt: now,
        );
    _title = TextEditingController(text: _draft.title);
    _notes = TextEditingController(text: _draft.notes);
    _waiting = TextEditingController(text: _draft.waitingOn);
    for (final s in _draft.subtasks) {
      _subs.add(_SubDraft(s));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _waiting.dispose();
    _newSub.dispose();
    for (final d in _subs) {
      d.ctrl.dispose();
    }
    super.dispose();
  }

  void _addSub() {
    final text = _newSub.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subs.add(_SubDraft(Subtask(taskId: _draft.id ?? 0, title: text, sortOrder: _subs.length)));
      _newSub.clear();
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showInfoSnack(context, tr.titleRequired);
      return;
    }
    if (_draft.reminderAt != null && _draft.reminderAt! <= DateTime.now().millisecondsSinceEpoch && _draft.reminderAt != _before?.reminderAt) {
      showInfoSnack(context, tr.reminderInPast);
      return;
    }
    setState(() => _saving = true);
    _draft.title = title;
    _draft.notes = _notes.text.trim();
    _draft.waitingOn = _waiting.text.trim();
    _draft.subtasks = [
      for (final d in _subs)
        if (d.ctrl.text.trim().isNotEmpty) (d.sub..title = d.ctrl.text.trim()),
    ];
    if (_draft.dueDate == null) _draft.dueMinutes = null;
    final app = AppScope.read(context);
    if (_isNew) {
      await app.addTask(_draft);
    } else {
      await app.saveTask(_draft, _before!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickReminder() async {
    final baseDay = _draft.dueDate ?? Day.today();
    final existing = _draft.reminderAt == null ? null : DateTime.fromMillisecondsSinceEpoch(_draft.reminderAt!);
    final day = await pickDay(context,
        initial: existing == null ? baseDay : Day.fromDateTime(existing), first: Day.today());
    if (day == null || !mounted) return;
    final minutes = await pickMinutes(context,
        initial: existing != null ? existing.hour * 60 + existing.minute : (_draft.dueMinutes ?? 9 * 60));
    if (minutes == null) return;
    setState(() => _draft.reminderAt = day.atMinutes(minutes).millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr.newTask : tr.editTask),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(onPressed: _saving ? null : _save, child: Text(tr.save)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            TextField(
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(labelText: tr.taskTitle, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text(tr.category, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text(tr.noCategory),
                selected: _draft.categoryId == null,
                onSelected: (_) => setState(() => _draft.categoryId = null),
              ),
              for (final c in app.taskCategories)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: Color(c.color), radius: 6),
                  label: Text(tr.categoryName(c)),
                  selected: _draft.categoryId == c.id,
                  onSelected: (_) => setState(() => _draft.categoryId = c.id),
                ),
            ]),
            const SizedBox(height: 16),
            Text(tr.priority, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            SegmentedButton<TaskPriority>(
              segments: [
                for (final pr in TaskPriority.values) ButtonSegment(value: pr, label: Text(tr.priorityLabel(pr))),
              ],
              selected: {_draft.priority},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _draft.priority = s.first),
            ),
            const SizedBox(height: 16),
            Text(tr.status, style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in TaskStatus.values)
                ChoiceChip(
                  label: Text(tr.statusLabel(s)),
                  selected: _draft.status == s,
                  onSelected: (_) => setState(() => _draft.status = s),
                ),
            ]),
            const SizedBox(height: 8),
            const Divider(),
            FormRow(
              icon: Icons.event_outlined,
              label: tr.dueDate,
              value: _draft.dueDate == null ? null : formatDayLong(_draft.dueDate!),
              onTap: () async {
                final d = await pickDay(context, initial: _draft.dueDate);
                if (d != null) setState(() => _draft.dueDate = d);
              },
              onClear: () => setState(() {
                _draft.dueDate = null;
                _draft.dueMinutes = null;
              }),
            ),
            if (_draft.dueDate != null)
              FormRow(
                icon: Icons.schedule,
                label: tr.dueTime,
                value: _draft.dueMinutes == null ? null : formatMinutes(_draft.dueMinutes!),
                onTap: () async {
                  final m = await pickMinutes(context, initial: _draft.dueMinutes);
                  if (m != null) setState(() => _draft.dueMinutes = m);
                },
                onClear: () => setState(() => _draft.dueMinutes = null),
              ),
            FormRow(
              icon: Icons.notifications_none,
              label: tr.reminder,
              value: _draft.reminderAt == null ? null : formatDateTimeMs(_draft.reminderAt!),
              onTap: _pickReminder,
              onClear: () => setState(() => _draft.reminderAt = null),
            ),
            FormRow(
              icon: Icons.reply_outlined,
              label: tr.followUpDate,
              value: _draft.followUpDate == null ? null : formatDayLong(_draft.followUpDate!),
              onTap: () async {
                final d = await pickDay(context, initial: _draft.followUpDate ?? _draft.dueDate);
                if (d != null) setState(() => _draft.followUpDate = d);
              },
              onClear: () => setState(() => _draft.followUpDate = null),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _waiting,
              decoration: InputDecoration(
                labelText: tr.waitingOn,
                hintText: tr.waitingOnHint,
                prefixIcon: const Icon(Icons.hourglass_empty),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: tr.notes, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            Text(tr.subtasks, style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 15)),
            const SizedBox(height: 4),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldI, newI) => setState(() {
                if (newI > oldI) newI -= 1;
                final item = _subs.removeAt(oldI);
                _subs.insert(newI, item);
              }),
              children: [
                for (var i = 0; i < _subs.length; i++)
                  Row(
                    key: ObjectKey(_subs[i]),
                    children: [
                      Checkbox(
                        value: _subs[i].sub.done,
                        onChanged: (v) => setState(() => _subs[i].sub.done = v ?? false),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _subs[i].ctrl,
                          decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                        ),
                      ),
                      IconButton(
                        tooltip: tr.delete,
                        icon: Icon(Icons.close, color: p.textMuted, size: 20),
                        onPressed: () => setState(() => _subs.removeAt(i)),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator, color: p.textMuted),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.add, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newSub,
                    decoration: InputDecoration(hintText: tr.addSubtask, border: InputBorder.none),
                    onSubmitted: (_) => _addSub(),
                  ),
                ),
                TextButton(onPressed: _addSub, child: Text(tr.add)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
