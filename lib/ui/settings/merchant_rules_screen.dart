import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';

/// "Merchant contains X -> category Y" rules applied to future imports.
class MerchantRulesScreen extends StatelessWidget {
  const MerchantRulesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final app = AppScope.read(context);
    if (app.expenseCategories.isEmpty) return;
    final ctrl = TextEditingController();
    var cat = app.expenseCategories.first.id!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(tr.newRule),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(labelText: tr.merchantContains),
              ),
              const SizedBox(height: 12),
              DropdownButton<int>(
                value: cat,
                isExpanded: true,
                items: [
                  for (final c in app.expenseCategories)
                    DropdownMenuItem(value: c.id!, child: Text(tr.expenseCategoryName(c))),
                ],
                onChanged: (v) => setSt(() => cat = v ?? cat),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr.save)),
          ],
        ),
      ),
    );
    final pattern = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true && pattern.isNotEmpty) await app.addMerchantRule(pattern, cat);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.merchantRules)),
      floatingActionButton:
          FloatingActionButton(tooltip: tr.newRule, onPressed: () => _add(context), child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(tr.merchantRulesHint, style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4)),
          ),
          if (app.merchantRules.isEmpty) EmptyState(icon: Icons.rule_folder_outlined, title: tr.noRules),
          for (final r in app.merchantRules)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(r.pattern),
              subtitle: Text(() {
                final c = app.expenseCategoryById(r.categoryId);
                return c == null ? tr.uncategorized : tr.expenseCategoryName(c);
              }()),
              trailing: IconButton(
                tooltip: tr.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(context, title: tr.deleteRuleQ, confirmLabel: tr.delete, destructive: true);
                  if (ok) await app.deleteMerchantRule(r.id!);
                },
              ),
            ),
        ],
      ),
    );
  }
}
