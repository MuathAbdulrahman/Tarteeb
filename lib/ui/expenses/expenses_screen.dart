import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../domain/finance_logic.dart';
import '../../domain/finance_models.dart';
import '../../platform/native_bridge.dart';
import '../app_scope.dart';
import '../common.dart';
import '../settings/categories_screen.dart';
import '../settings/merchant_rules_screen.dart';
import '../theme.dart';
import 'sms_import_screen.dart';
import 'txn_detail_screen.dart';
import 'txn_list_screen.dart';
import 'txn_widgets.dart';

enum Period { today, week, month, custom }

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Period _period = Period.month;
  DayRange? _custom;
  bool _refreshing = false;

  DayRange _range(int weekStart) {
    final today = Day.today();
    switch (_period) {
      case Period.today:
        return DayRange(today, today);
      case Period.week:
        final s = startOfWeek(today, weekStart);
        return DayRange(s, s.addDays(6));
      case Period.month:
        return DayRange(today.firstOfMonth, Day(today.year, today.month, today.daysInMonth));
      case Period.custom:
        return _custom ?? DayRange(today.firstOfMonth, today);
    }
  }

  List<Day> _chartDays(DayRange r, int weekStart) {
    if (_period == Period.today) {
      final s = startOfWeek(Day.today(), weekStart);
      return DayRange(s, s.addDays(6)).days.toList();
    }
    final days = r.days.toList();
    return days.length > 62 ? days.sublist(days.length - 62) : days;
  }

  Future<void> _pickCustom() async {
    final today = Day.today();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today.addDays(365).startLocal,
      initialDateRange: _custom == null
          ? DateTimeRange(start: today.firstOfMonth.startLocal, end: today.startLocal)
          : DateTimeRange(start: _custom!.start.startLocal, end: _custom!.end.startLocal),
    );
    if (r == null) return;
    setState(() {
      _period = Period.custom;
      _custom = DayRange(Day.fromDateTime(r.start), Day.fromDateTime(r.end));
    });
  }

  Future<void> _refresh() async {
    final app = AppScope.read(context);
    setState(() => _refreshing = true);
    await app.processSmsQueue();
    final report = await app.catchUpInbox();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (report != null) {
      showInfoSnack(context, report.saved == 0 ? tr.noNewTransactions : tr.newTransactionsSaved(report.saved));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final range = _range(app.settings.weekStart);
    final summary = summarize(app.txns, range);
    final hasAnyData = app.txns.isNotEmpty;
    final inRange = app.txns.where((t) => t.txnAt >= range.startMillis && t.txnAt < range.endMillisExclusive).toList();
    final review = app.reviewQueue;

    String amountOrDash(int minor) => hasAnyData ? money(minor, kDefaultCurrency) : '—';

    Widget flowRow(String label, CurrencyTotals totals, IconData icon) {
      final sar = totals.of(kDefaultCurrency);
      final foreign = totals.foreign();
      if (sar == 0 && foreign.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 18, color: p.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: p.text, fontSize: 14))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (sar != 0) Text(money(sar, kDefaultCurrency), style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                for (final e in foreign.entries)
                  Text(money(e.value, e.key), style: TextStyle(color: p.textMuted, fontSize: 13)),
              ],
            ),
          ],
        ),
      );
    }

    final hasFlows = [summary.atm, summary.transfersOut, summary.transfersIn, summary.income, summary.cardPayments]
        .any((t) => !t.isEmpty);

    // Category breakdown (SAR gross spending).
    final catEntries = summary.categoryGrossSar.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catMax = catEntries.isEmpty ? 0 : catEntries.first.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.tabExpenses),
        actions: [
          IconButton(
            tooltip: tr.allTransactions,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TxnListScreen(reviewOnly: false))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              final nav = Navigator.of(context);
              switch (v) {
                case 'import':
                  nav.push(MaterialPageRoute(builder: (_) => const SmsImportScreen()));
                  break;
                case 'categories':
                  nav.push(MaterialPageRoute(builder: (_) => const CategoriesScreen(kind: CategoryKind.expense)));
                  break;
                case 'rules':
                  nav.push(MaterialPageRoute(builder: (_) => const MerchantRulesScreen()));
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'import', child: Text(tr.importSmsHistory)),
              PopupMenuItem(value: 'categories', child: Text(tr.expenseCategories)),
              PopupMenuItem(value: 'rules', child: Text(tr.merchantRules)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr.addExpense,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TxnDetailScreen(txnId: null))),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const _SmsStatusCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: SegmentedButton<Period>(
                segments: [
                  ButtonSegment(value: Period.today, label: Text(tr.periodToday)),
                  ButtonSegment(value: Period.week, label: Text(tr.periodWeek)),
                  ButtonSegment(value: Period.month, label: Text(tr.periodMonth)),
                  ButtonSegment(value: Period.custom, label: Text(tr.periodCustom)),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  if (s.first == Period.custom) {
                    _pickCustom();
                  } else {
                    setState(() => _period = s.first);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _pickCustom,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${formatDayShort(range.start)} – ${formatDayShort(range.end)}',
                    style: TextStyle(fontSize: 13, color: p.textMuted),
                  ),
                ),
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.netSpending, style: TextStyle(color: p.textMuted, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    amountOrDash(summary.netOf(kDefaultCurrency)),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: p.text),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(label: tr.grossSpending, value: amountOrDash(summary.gross.of(kDefaultCurrency))),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: tr.refunds,
                          value: amountOrDash(summary.refunds.of(kDefaultCurrency)),
                          color: p.success,
                        ),
                      ),
                    ],
                  ),
                  if (summary.foreignCurrencies.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(tr.foreignCurrencyTotals, style: TextStyle(color: p.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    for (final c in summary.foreignCurrencies)
                      Text(
                        tr.foreignLine(money(summary.gross.of(c), c), money(summary.refunds.of(c), c)),
                        style: TextStyle(color: p.text, fontSize: 14),
                      ),
                    Text(tr.foreignNote, style: TextStyle(color: p.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    hasAnyData ? tr.totalsDisclaimer : tr.noDataYetDisclaimer,
                    style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            if (review.isNotEmpty)
              AppCard(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const TxnListScreen(reviewOnly: true))),
                child: Row(
                  children: [
                    Icon(Icons.rule, color: p.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tr.reviewBanner(review.length),
                          style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, color: p.textMuted),
                  ],
                ),
              ),
            if (hasFlows)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr.notCountedAsSpending, style: TextStyle(color: p.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    flowRow(tr.txnTypeLabel(TxnType.atmWithdrawal), summary.atm, Icons.local_atm),
                    flowRow(tr.txnTypeLabel(TxnType.transferOut), summary.transfersOut, Icons.north_east),
                    flowRow(tr.txnTypeLabel(TxnType.transferIn), summary.transfersIn, Icons.south_west),
                    flowRow(tr.txnTypeLabel(TxnType.income), summary.income, Icons.savings_outlined),
                    flowRow(tr.txnTypeLabel(TxnType.cardPayment), summary.cardPayments, Icons.credit_score_outlined),
                  ],
                ),
              ),
            if (hasAnyData) ...[
              SectionLabel(tr.dailySpending),
              AppCard(
                child: DailyBarChart(
                  days: _chartDays(range, app.settings.weekStart),
                  values: _period == Period.today
                      ? summarize(app.txns, DayRange(startOfWeek(Day.today(), app.settings.weekStart),
                              startOfWeek(Day.today(), app.settings.weekStart).addDays(6)))
                          .dailyGrossSar
                      : summary.dailyGrossSar,
                ),
              ),
              SectionLabel(tr.byCategory),
              AppCard(
                child: catEntries.isEmpty
                    ? Text(tr.noSpendingInPeriod, style: TextStyle(color: p.textMuted))
                    : Column(
                        children: [
                          for (final e in catEntries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Builder(builder: (_) {
                                final cat = app.expenseCategoryById(e.key);
                                final color = cat == null ? p.textMuted : Color(cat.color);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(cat == null ? tr.uncategorized : tr.expenseCategoryName(cat),
                                              style: TextStyle(color: p.text, fontSize: 14)),
                                        ),
                                        Text(money(e.value, kDefaultCurrency),
                                            style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: catMax == 0 ? 0.0 : e.value / catMax,
                                        minHeight: 6,
                                        backgroundColor: p.chip,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                        ],
                      ),
              ),
            ],
            SectionLabel(
              tr.recentTransactions,
              trailing: inRange.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const TxnListScreen(reviewOnly: false))),
                      child: Text(tr.viewAll),
                    ),
            ),
            if (inRange.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(hasAnyData ? tr.noTransactionsInPeriod : tr.noTransactionsYet,
                    style: TextStyle(color: p.textMuted)),
              ),
            for (final t in inRange.take(10)) TxnTile(t: t),
            if (_refreshing) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: p.textMuted, fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? p.text, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// SMS onboarding / permission / status card.
class _SmsStatusCard extends StatelessWidget {
  const _SmsStatusCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final perms = app.smsPerms;
    final enabled = app.settings.smsNewMessages;

    if (perms.read == PermState.unavailable && perms.receive == PermState.unavailable) {
      return AppCard(
        child: Text(tr.smsUnavailable, style: TextStyle(color: p.textMuted)),
      );
    }

    if (enabled && perms.canReceive) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.sms_outlined, color: p.success),
            const SizedBox(width: 10),
            Expanded(child: Text(tr.smsActive, style: TextStyle(color: p.text, fontSize: 14))),
          ],
        ),
      );
    }

    final revoked = enabled && !perms.canReceive;
    final denied = perms.receive == PermState.permanentlyDenied || perms.read == PermState.permanentlyDenied;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(revoked || denied ? Icons.sms_failed_outlined : Icons.sms_outlined, color: p.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  revoked ? tr.smsRevokedTitle : tr.smsOnboardTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            revoked ? tr.smsRevokedBody : (denied ? tr.smsDeniedBody : tr.smsOnboardBody),
            style: TextStyle(fontSize: 14, color: p.textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (denied || revoked)
                FilledButton.icon(
                  onPressed: () => app.native.openAppSettings(),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(tr.openAppSettings),
                ),
              if (!denied && !revoked)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SmsImportScreen())),
                  icon: const Icon(Icons.history),
                  label: Text(tr.importSmsHistory),
                ),
              if (!denied && !revoked)
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: tr.enableNewSmsTitle, body: tr.enableNewSmsBody, confirmLabel: tr.enable);
                    if (!ok) return;
                    final granted = await app.setNewMessageProcessing(true);
                    if (!granted && context.mounted) showInfoSnack(context, tr.permissionDenied);
                  },
                  icon: const Icon(Icons.bolt_outlined),
                  label: Text(tr.processNewSms),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
