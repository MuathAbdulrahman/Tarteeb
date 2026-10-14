import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../domain/finance_logic.dart';
import '../../domain/finance_models.dart';
import '../app_scope.dart';
import '../theme.dart';
import 'txn_widgets.dart';

class TxnListScreen extends StatefulWidget {
  final bool reviewOnly;
  const TxnListScreen({super.key, required this.reviewOnly});

  @override
  State<TxnListScreen> createState() => _TxnListScreenState();
}

class _TxnListScreenState extends State<TxnListScreen> {
  final _search = TextEditingController();
  TxnType? _type;
  int? _categoryId;
  bool _uncategorizedOnly = false;
  String? _account;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final q = normalizeMerchant(_search.text);
    final accounts = app.txns.map((t) => t.accountLast4).where((a) => a.isNotEmpty).toSet().toList()..sort();
    final list = app.txns.where((t) {
      if (widget.reviewOnly && t.status != TxnStatus.needsReview) return false;
      if (_type != null && t.type != _type) return false;
      if (_uncategorizedOnly && t.categoryId != null) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_account != null && t.accountLast4 != _account) return false;
      if (q.isNotEmpty) {
        final hay = normalizeMerchant('${t.merchant} ${t.note} ${t.sender}');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    final groups = <Day, List<FinTxn>>{};
    for (final t in list) {
      groups.putIfAbsent(Day.fromDateTime(DateTime.fromMillisecondsSinceEpoch(t.txnAt)), () => []).add(t);
    }

    Widget dropdownChip<T>({
      required String label,
      required T? value,
      required List<(T, String)> options,
      required ValueChanged<T?> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PopupMenuButton<int>(
          tooltip: label,
          onSelected: (i) => onChanged(i < 0 ? null : options[i].$1),
          itemBuilder: (_) => [
            PopupMenuItem(value: -1, child: Text(tr.all)),
            for (var i = 0; i < options.length; i++) PopupMenuItem(value: i, child: Text(options[i].$2)),
          ],
          child: Chip(
            label: Text(value == null ? label : options.firstWhere((o) => o.$1 == value).$2),
            avatar: Icon(Icons.arrow_drop_down, size: 18, color: p.textMuted),
            backgroundColor: value == null ? p.card : p.accentSoft,
            side: BorderSide(color: p.cardBorder),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.reviewOnly ? tr.needsReview : tr.allTransactions)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr.searchMerchant,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          SizedBox(
            height: 18 + 32 * MediaQuery.textScalerOf(context).scale(1),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                dropdownChip<TxnType>(
                  label: tr.type,
                  value: _type,
                  options: [for (final t in TxnType.values) (t, tr.txnTypeLabel(t))],
                  onChanged: (v) => setState(() => _type = v),
                ),
                dropdownChip<int>(
                  label: tr.category,
                  value: _uncategorizedOnly ? -2 : _categoryId,
                  options: [
                    (-2, tr.uncategorized),
                    for (final c in app.expenseCategories) (c.id!, tr.expenseCategoryName(c)),
                  ],
                  onChanged: (v) => setState(() {
                    _uncategorizedOnly = v == -2;
                    _categoryId = v == -2 ? null : v;
                  }),
                ),
                if (accounts.isNotEmpty)
                  dropdownChip<String>(
                    label: tr.account,
                    value: _account,
                    options: [for (final a in accounts) (a, maskAccount(a))],
                    onChanged: (v) => setState(() => _account = v),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(children: [
                    EmptyState(
                      icon: widget.reviewOnly ? Icons.task_alt : Icons.receipt_long_outlined,
                      title: widget.reviewOnly ? tr.reviewEmpty : tr.noMatchingTransactions,
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      if (widget.reviewOnly)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                          child: Text(tr.reviewExplainer, style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4)),
                        ),
                      for (final e in groups.entries) ...[
                        SectionLabel(formatDayLong(e.key)),
                        for (final t in e.value) TxnTile(t: t),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
