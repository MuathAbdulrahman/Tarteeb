import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../domain/finance_models.dart';
import '../app_scope.dart';
import '../common.dart';
import '../theme.dart';
import 'txn_widgets.dart';

/// View/edit a transaction, or create a manual one when [txnId] is null.
class TxnDetailScreen extends StatefulWidget {
  final int? txnId;
  const TxnDetailScreen({super.key, required this.txnId});

  @override
  State<TxnDetailScreen> createState() => _TxnDetailScreenState();
}

class _TxnDetailScreenState extends State<TxnDetailScreen> {
  FinTxn? _t;
  late TextEditingController _amount;
  late TextEditingController _merchant;
  late TextEditingController _note;
  bool _ruleForMerchant = false;
  bool _initialized = false;
  bool _missing = false;

  bool get _isNew => widget.txnId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.read(context);
    FinTxn? source;
    if (widget.txnId != null) {
      for (final x in app.txns) {
        if (x.id == widget.txnId) source = x;
      }
    }
    _missing = widget.txnId != null && source == null;
    final now = DateTime.now().millisecondsSinceEpoch;
    _t = source?.copy() ??
        FinTxn(
          source: TxnSource.manual,
          status: TxnStatus.confirmed,
          type: TxnType.cardPurchase,
          txnAt: now,
          tsSource: TimestampSource.manual,
          createdAt: now,
          updatedAt: now,
        );
    _amount = TextEditingController(
        text: _t!.amountMinor == null ? '' : minorToEditable(_t!.amountMinor!, _t!.currency));
    _merchant = TextEditingController(text: _t!.merchant);
    _note = TextEditingController(text: _t!.note);
  }

  @override
  void dispose() {
    if (_initialized) {
      _amount.dispose();
      _merchant.dispose();
      _note.dispose();
    }
    super.dispose();
  }

  String _toWestern(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x30 + r - 0x0660);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x30 + r - 0x06F0);
      } else if (r == 0x066B) {
        b.write('.');
      } else if (r == 0x066C) {
        b.write(',');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  /// Applies form fields to the draft. Returns false when the amount is invalid.
  bool _apply() {
    final t = _t!;
    final text = _toWestern(_amount.text.trim());
    final minor = parseAmountToMinor(text, t.currency);
    if (minor == null || minor <= 0) {
      showInfoSnack(context, tr.invalidAmount);
      return false;
    }
    t.amountMinor = minor;
    t.merchant = _merchant.text.trim();
    t.note = _note.text.trim();
    t.candidates = '';
    return true;
  }

  Future<void> _save({bool confirm = false}) async {
    if (!_apply()) return;
    final app = AppScope.read(context);
    final t = _t!;
    if (_ruleForMerchant && t.categoryId != null && t.merchant.isNotEmpty) {
      await app.addMerchantRule(t.merchant, t.categoryId!);
    }
    if (_isNew) {
      await app.addManualTxn(t);
    } else if (confirm) {
      await app.confirmTxn(t);
    } else {
      await app.saveTxn(t);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final t = _t!;
    final ok = await confirmDialog(
      context,
      title: t.source == TxnSource.sms ? tr.ignoreTxnQ : tr.deleteTxnQ,
      body: t.source == TxnSource.sms ? tr.ignoreTxnBody : null,
      confirmLabel: t.source == TxnSource.sms ? tr.ignore : tr.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await AppScope.read(context).deleteTxn(t);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    if (_missing) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.search_off, title: tr.txnNotFound));
    }
    final t = _t!;
    final review = t.status == TxnStatus.needsReview;
    final dt = DateTime.fromMillisecondsSinceEpoch(t.txnAt);
    final reasons = t.reviewReason.isEmpty ? <String>[] : t.reviewReason.split(',');

    Widget infoLine(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 13))),
              Expanded(child: Text(value, style: TextStyle(color: p.text, fontSize: 13))),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr.addExpense : tr.transaction),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: t.source == TxnSource.sms ? tr.ignore : tr.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            if (review)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: p.warningSoft, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.needsReview, style: TextStyle(color: p.warning, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    for (final r in reasons)
                      Text('• ${tr.reviewReasonLabel(r)}', style: TextStyle(color: p.text, fontSize: 13)),
                    if (t.candidateAmounts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(tr.pickCorrectAmount, style: TextStyle(color: p.text, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in t.candidateAmounts)
                          ActionChip(
                            label: Text(money(c, t.currency)),
                            onPressed: () => setState(() => _amount.text = minorToEditable(c, t.currency)),
                          ),
                      ]),
                    ],
                    if (t.duplicateOfId != null) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => TxnDetailScreen(txnId: t.duplicateOfId))),
                        child: Text(tr.viewPossibleOriginal),
                      ),
                    ],
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(labelText: tr.amount, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: tr.currency, border: const OutlineInputBorder()),
                      child: DropdownButton<String>(
                        value: knownCurrencies.contains(t.currency) ? t.currency : kDefaultCurrency,
                        isDense: true,
                        isExpanded: true,
                        items: [
                          for (final c in knownCurrencies) DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() {
                          final text = _toWestern(_amount.text.trim());
                          final old = parseAmountToMinor(text, t.currency);
                          t.currency = v ?? kDefaultCurrency;
                          if (old != null) {
                            _amount.text = text;
                          }
                          if (t.currency == kDefaultCurrency) t.sarAmountMinor = null;
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _merchant,
              decoration: InputDecoration(labelText: tr.merchant, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr.type, border: const OutlineInputBorder()),
                child: DropdownButton<TxnType>(
                  value: t.type,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    for (final ty in TxnType.values)
                      DropdownMenuItem(
                        value: ty,
                        child: Row(children: [
                          Icon(txnTypeIcon(ty), size: 18, color: p.textMuted),
                          const SizedBox(width: 8),
                          Flexible(child: Text(tr.txnTypeLabel(ty), overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setState(() => t.type = v ?? t.type),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: InputDecorator(
                decoration: InputDecoration(labelText: tr.category, border: const OutlineInputBorder()),
                child: DropdownButton<int>(
                  value: t.categoryId ?? -1,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: -1, child: Text(tr.uncategorized)),
                    for (final c in app.expenseCategories)
                      DropdownMenuItem(value: c.id!, child: Text(tr.expenseCategoryName(c))),
                  ],
                  onChanged: (v) => setState(() => t.categoryId = (v == null || v == -1) ? null : v),
                ),
              ),
            ),
            if (t.categoryId != null && _merchant.text.trim().isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _ruleForMerchant,
                onChanged: (v) => setState(() => _ruleForMerchant = v ?? false),
                title: Text(tr.rememberCategoryForMerchant, style: const TextStyle(fontSize: 14)),
              ),
            const SizedBox(height: 4),
            FormRow(
              icon: Icons.event_outlined,
              label: tr.date,
              value: formatDayLong(Day.fromDateTime(dt)),
              onTap: () async {
                final d = await pickDay(context, initial: Day.fromDateTime(dt));
                if (d == null) return;
                setState(() {
                  t.txnAt = d.atMinutes(dt.hour * 60 + dt.minute).millisecondsSinceEpoch;
                  t.tsSource = TimestampSource.manual;
                });
              },
            ),
            FormRow(
              icon: Icons.schedule,
              label: tr.time,
              value: formatTimeOf(dt),
              onTap: () async {
                final m = await pickMinutes(context, initial: dt.hour * 60 + dt.minute);
                if (m == null) return;
                setState(() {
                  t.txnAt = Day.fromDateTime(dt).atMinutes(m).millisecondsSinceEpoch;
                  t.tsSource = TimestampSource.manual;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr.countAsSpending),
              subtitle: Text(
                t.countOverride == null ? tr.countDefaultForType : tr.countOverridden,
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              value: t.countsAsExpense,
              onChanged: (v) => setState(() => t.countOverride = v == typeCountsAsExpense(t.type) ? null : v),
            ),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr.note, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (review)
              FilledButton.icon(
                onPressed: () => _save(confirm: true),
                icon: const Icon(Icons.check),
                label: Text(tr.confirmTransaction),
              ),
            const SizedBox(height: 8),
            review
                ? OutlinedButton(onPressed: () => _save(), child: Text(tr.saveKeepInReview))
                : FilledButton(onPressed: () => _save(), child: Text(tr.save)),
            if (!_isNew) ...[
              const SizedBox(height: 20),
              Text(tr.parsingDetails, style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              infoLine(tr.source, t.source == TxnSource.sms ? tr.sourceSms : tr.sourceManual),
              if (t.sender.isNotEmpty) infoLine(tr.sender, isolate(t.sender)),
              if (t.accountLast4.isNotEmpty) infoLine(tr.account, maskAccount(t.accountLast4)),
              if (t.reference.isNotEmpty) infoLine(tr.reference, isolate(t.reference)),
              if (t.feeMinor != null) infoLine(tr.feeInMessage, money(t.feeMinor!, t.currency)),
              if (t.sarAmountMinor != null) infoLine(tr.sarEquivalent, money(t.sarAmountMinor!, kDefaultCurrency)),
              infoLine(tr.timeSource, tr.tsSourceLabel(t.tsSource)),
              if (t.smsAt != null) infoLine(tr.smsReceived, formatDateTimeMs(t.smsAt!)),
              if (t.source == TxnSource.sms) infoLine(tr.confidence, '${t.confidence}%'),
              if (t.parserVersion.isNotEmpty) infoLine(tr.parserVersion, isolate(t.parserVersion)),
              if (t.userEdited) infoLine(tr.edited, tr.yes),
              if (t.linkedTxnId != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => TxnDetailScreen(txnId: t.linkedTxnId))),
                    child: Text(tr.viewLinkedPurchase),
                  ),
                ),
              if (t.excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tr.redactedExcerpt, style: TextStyle(color: p.textMuted, fontSize: 12)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(10)),
                  child: Text(t.excerpt, style: TextStyle(color: p.text, fontSize: 13, height: 1.4)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
