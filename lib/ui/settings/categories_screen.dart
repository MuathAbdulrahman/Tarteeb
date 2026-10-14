import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';

enum CategoryKind { task, expense }

/// Create, rename, recolor, reorder and delete categories.
class CategoriesScreen extends StatelessWidget {
  final CategoryKind kind;
  const CategoriesScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final isTask = kind == CategoryKind.task;
    final items = isTask
        ? [for (final c in app.taskCategories) (c.id!, tr.categoryName(c), c.color)]
        : [for (final c in app.expenseCategories) (c.id!, tr.expenseCategoryName(c), c.color)];

    Future<void> add() async {
      final r = await categoryDialog(context, title: tr.newCategory);
      if (r == null) return;
      if (isTask) {
        await app.addTaskCategory(r.$1, r.$2);
      } else {
        await app.addExpenseCategory(r.$1, r.$2);
      }
    }

    Future<void> edit(int id) async {
      if (isTask) {
        final c = app.taskCategories.firstWhere((x) => x.id == id);
        final r = await categoryDialog(context, title: tr.editCategory, name: tr.categoryName(c), color: c.color);
        if (r == null) return;
        c.name = r.$1;
        c.color = r.$2;
        await app.updateTaskCategory(c);
      } else {
        final c = app.expenseCategories.firstWhere((x) => x.id == id);
        final r =
            await categoryDialog(context, title: tr.editCategory, name: tr.expenseCategoryName(c), color: c.color);
        if (r == null) return;
        c.name = r.$1;
        c.color = r.$2;
        await app.updateExpenseCategory(c);
      }
    }

    Future<void> delete(int id, String name) async {
      final ok = await confirmDialog(context,
          title: tr.deleteCategoryQ(name),
          body: isTask ? tr.deleteTaskCategoryBody : tr.deleteExpenseCategoryBody,
          confirmLabel: tr.delete,
          destructive: true);
      if (!ok) return;
      if (isTask) {
        await app.deleteTaskCategory(id);
      } else {
        await app.deleteExpenseCategory(id);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(isTask ? tr.taskCategories : tr.expenseCategories)),
      floatingActionButton: FloatingActionButton(tooltip: tr.newCategory, onPressed: add, child: const Icon(Icons.add)),
      body: ReorderableListView(
        padding: const EdgeInsets.only(bottom: 96, top: 8),
        buildDefaultDragHandles: false,
        onReorder: (oldI, newI) {
          if (newI > oldI) newI -= 1;
          final ids = items.map((e) => e.$1).toList();
          final moved = ids.removeAt(oldI);
          ids.insert(newI, moved);
          if (isTask) {
            app.reorderTaskCategories(ids);
          } else {
            app.reorderExpenseCategories(ids);
          }
        },
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(tr.categoriesHint, style: TextStyle(fontSize: 13, color: p.textMuted)),
        ),
        children: [
          for (var i = 0; i < items.length; i++)
            ListTile(
              key: ValueKey('cat-${items[i].$1}'),
              leading: CircleAvatar(backgroundColor: Color(items[i].$3), radius: 10),
              title: Text(items[i].$2),
              onTap: () => edit(items[i].$1),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: tr.delete,
                    icon: Icon(Icons.delete_outline, color: p.textMuted),
                    onPressed: () => delete(items[i].$1, items[i].$2),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_indicator, color: p.textMuted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
