import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/strings.dart';
import '../../domain/task_logic.dart';
import '../../domain/task_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../settings/categories_screen.dart';
import '../theme.dart';
import 'task_card.dart';
import 'task_editor_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _filter = const TaskFilter();
  TaskSort _sort = TaskSort.manual;
  final Set<TaskSection> _collapsed = {TaskSection.completed};
  final Set<int> _expanded = {};
  final Set<int> _hidden = {}; // dismissed, awaiting reload
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _sectionTitle(TaskSection s) => switch (s) {
        TaskSection.overdue => tr.sectionOverdue,
        TaskSection.today => tr.sectionToday,
        TaskSection.upcoming => tr.sectionUpcoming,
        TaskSection.noDate => tr.sectionNoDate,
        TaskSection.completed => tr.sectionCompleted,
      };

  Future<void> _openFilters() async {
    final p = Palette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          void update(TaskFilter f) {
            setSt(() {});
            setState(() => _filter = f);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.sortBy, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in TaskSort.values)
                      ChoiceChip(
                        label: Text(tr.sortLabel(s)),
                        selected: _sort == s,
                        onSelected: (_) {
                          setSt(() {});
                          setState(() => _sort = s);
                        },
                      ),
                  ]),
                  const SizedBox(height: 18),
                  Text(tr.status, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in TaskStatus.values)
                      FilterChip(
                        label: Text(tr.statusLabel(s)),
                        selected: _filter.statuses.contains(s),
                        onSelected: (on) {
                          final next = {..._filter.statuses};
                          on ? next.add(s) : next.remove(s);
                          update(_filter.copyWith(statuses: next));
                        },
                      ),
                  ]),
                  const SizedBox(height: 18),
                  Text(tr.priority, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final pr in TaskPriority.values)
                      FilterChip(
                        label: Text(tr.priorityLabel(pr)),
                        selected: _filter.priorities.contains(pr),
                        onSelected: (on) {
                          final next = {..._filter.priorities};
                          on ? next.add(pr) : next.remove(pr);
                          update(_filter.copyWith(priorities: next));
                        },
                      ),
                  ]),
                  const SizedBox(height: 18),
                  if (_filter.hasExtraFilters)
                    TextButton.icon(
                      onPressed: () => update(_filter.copyWith(statuses: {}, priorities: {})),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: Text(tr.clearFilters),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(TaskItem t) async {
    final app = AppScope.read(context);
    setState(() => _hidden.add(t.id!));
    await app.deleteTask(t);
    if (!mounted) return;
    setState(() => _hidden.remove(t.id));
    final id = t.id!;
    showUndoSnack(context, tr.taskDeleted, () => app.undoDeleteTask(id));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final today = Day.today();
    final visible = app.tasks.where((t) => !_hidden.contains(t.id)).toList();
    final groups = groupTasks(visible, today, _filter, _sort);
    final total = groups.values.fold<int>(0, (a, b) => a + b.length);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(hintText: tr.searchTasks, border: InputBorder.none),
                onChanged: (v) => setState(() => _filter = _filter.copyWith(query: v)),
              )
            : Text(tr.tabTasks),
        actions: [
          IconButton(
            tooltip: _searching ? tr.close : tr.search,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchCtrl.clear();
                _filter = _filter.copyWith(query: '');
              }
            }),
          ),
          IconButton(
            tooltip: tr.filterAndSort,
            icon: Badge(
              isLabelVisible: _filter.hasExtraFilters || _sort != TaskSort.manual,
              smallSize: 8,
              child: const Icon(Icons.tune),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr.addTask,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskEditorScreen(initialCategoryId: _filter.categoryId),
        )),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 20 + 32 * MediaQuery.textScalerOf(context).scale(1),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _CategoryChip(
                  label: tr.allCategories,
                  selected: _filter.categoryId == null,
                  color: p.accent,
                  onTap: () => setState(() => _filter = _filter.copyWith(clearCategory: true)),
                ),
                for (final c in app.taskCategories)
                  _CategoryChip(
                    label: tr.categoryName(c),
                    selected: _filter.categoryId == c.id,
                    color: Color(c.color),
                    onTap: () => setState(() => _filter = _filter.copyWith(categoryId: c.id)),
                    onLongPress: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const CategoriesScreen(kind: CategoryKind.task))),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IconButton(
                    tooltip: tr.manageCategories,
                    icon: Icon(Icons.edit_outlined, color: p.textMuted, size: 20),
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const CategoriesScreen(kind: CategoryKind.task))),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: total == 0
                ? ListView(children: [
                    EmptyState(
                      icon: Icons.task_alt,
                      title: _filter.query.isNotEmpty || _filter.hasExtraFilters ? tr.noMatchingTasks : tr.noTasksTitle,
                      body: _filter.query.isNotEmpty || _filter.hasExtraFilters ? null : tr.noTasksBody,
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      for (final section in TaskSection.values)
                        if (groups[section]!.isNotEmpty) ...[
                          _SectionHeader(
                            title: _sectionTitle(section),
                            count: groups[section]!.length,
                            collapsed: _collapsed.contains(section),
                            color: section == TaskSection.overdue ? p.danger : p.textMuted,
                            onTap: () => setState(() {
                              _collapsed.contains(section) ? _collapsed.remove(section) : _collapsed.add(section);
                            }),
                          ),
                          if (!_collapsed.contains(section))
                            for (final t in groups[section]!)
                              Dismissible(
                                key: ValueKey('task-${t.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: AlignmentDirectional.centerEnd,
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  color: p.dangerSoft,
                                  child: Icon(Icons.delete_outline, color: p.danger),
                                ),
                                onDismissed: (_) => _delete(t),
                                child: TaskCard(
                                  task: t,
                                  showCategory: _filter.categoryId == null,
                                  expanded: _expanded.contains(t.id),
                                  onToggleExpand: () => setState(() {
                                    _expanded.contains(t.id) ? _expanded.remove(t.id) : _expanded.add(t.id!);
                                  }),
                                ),
                              ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _CategoryChip({required this.label, required this.selected, required this.color, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Material(
            color: selected ? color : p.card,
            shape: StadiumBorder(side: BorderSide(color: selected ? color : p.cardBorder)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool collapsed;
  final Color color;
  final VoidCallback onTap;
  const _SectionHeader({required this.title, required this.count, required this.collapsed, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: !collapsed,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 16, 6),
          child: Row(
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 6),
              Text('($count)', style: TextStyle(fontSize: 13, color: color)),
              const Spacer(),
              AnimatedRotation(
                turns: collapsed ? 0.0 : 0.5,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.expand_more, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
