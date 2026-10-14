import 'package:flutter/material.dart';

import '../../core/day.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/strings.dart';
import '../../domain/finance_models.dart';
import '../app_scope.dart';
import '../icons.dart';
import '../theme.dart';
import 'txn_detail_screen.dart';

IconData txnTypeIcon(TxnType t) => switch (t) {
      TxnType.cardPurchase => Icons.credit_card,
      TxnType.onlinePurchase => Icons.language,
      TxnType.billPayment => Icons.receipt_long_outlined,
      TxnType.refund => Icons.undo,
      TxnType.reversal => Icons.settings_backup_restore,
      TxnType.transferOut => Icons.north_east,
      TxnType.transferIn => Icons.south_west,
      TxnType.atmWithdrawal => Icons.local_atm,
      TxnType.bankFee => Icons.account_balance_outlined,
      TxnType.cardPayment => Icons.credit_score_outlined,
      TxnType.income => Icons.savings_outlined,
      TxnType.unknown => Icons.help_outline,
    };

bool get isAr => S.current.isArabic;

String money(int minor, String currency) => formatMoney(minor, currency, arabic: isAr);

class TxnTile extends StatelessWidget {
  final FinTxn t;
  const TxnTile({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final cat = app.expenseCategoryById(t.categoryId);
    final review = t.status == TxnStatus.needsReview;
    final incoming = typeIsRefundLike(t.type) || t.type == TxnType.transferIn || t.type == TxnType.income;
    final color = review ? p.warning : (t.countsAsExpense ? p.text : (incoming ? p.success : p.textMuted));
    final title = t.merchant.isNotEmpty ? t.merchant : tr.txnTypeLabel(t.type);
    final sub = <String>[
      formatDateTimeMs(t.txnAt),
      if (t.merchant.isNotEmpty) tr.txnTypeLabel(t.type),
      if (t.accountLast4.isNotEmpty) maskAccount(t.accountLast4),
    ].join(' · ');
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TxnDetailScreen(txnId: t.id))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: cat != null ? Color(cat.color).withValues(alpha: 0.15) : p.chip,
            child: Icon(
              cat != null && t.countsAsExpense ? expenseIcon(cat.icon) : txnTypeIcon(t.type),
              size: 19,
              color: cat != null ? Color(cat.color) : p.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isolate(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.text)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.textMuted)),
                if (review || t.source == TxnSource.manual) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, children: [
                    if (review) Pill(text: tr.needsReview, fg: p.warning, bg: p.warningSoft, icon: Icons.rule),
                    if (t.source == TxnSource.manual) Pill(text: tr.manualEntry, fg: p.textMuted, bg: p.chip),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.amountMinor == null ? '—' : '${incoming ? '+' : ''}${money(t.amountMinor!, t.currency)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
              ),
              if (t.sarAmountMinor != null && t.currency != kDefaultCurrency)
                Text(money(t.sarAmountMinor!, kDefaultCurrency), style: TextStyle(fontSize: 11, color: p.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple daily bar chart (SAR). Bars run in reading direction.
class DailyBarChart extends StatelessWidget {
  final List<Day> days;
  final Map<Day, int> values;
  const DailyBarChart({super.key, required this.days, required this.values});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final maxV = days.fold<int>(0, (m, d) => (values[d] ?? 0) > m ? (values[d] ?? 0) : m);
    final today = Day.today();
    final total = days.fold<int>(0, (a, d) => a + (values[d] ?? 0));
    return Semantics(
      label: tr.chartSemantics(money(total, kDefaultCurrency), days.length),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarPainter(
                days: days,
                values: values,
                maxV: maxV,
                rtl: rtl,
                bar: p.accent,
                todayBar: p.followUp,
                grid: p.cardBorder,
                today: today,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(formatDayShort(days.first), style: TextStyle(fontSize: 11, color: p.textMuted)),
              const Spacer(),
              if (maxV > 0)
                Text(tr.maxPerDay(money(maxV, kDefaultCurrency)), style: TextStyle(fontSize: 11, color: p.textMuted)),
              const Spacer(),
              Text(formatDayShort(days.last), style: TextStyle(fontSize: 11, color: p.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<Day> days;
  final Map<Day, int> values;
  final int maxV;
  final bool rtl;
  final Color bar;
  final Color todayBar;
  final Color grid;
  final Day today;

  _BarPainter({
    required this.days,
    required this.values,
    required this.maxV,
    required this.rtl,
    required this.bar,
    required this.todayBar,
    required this.grid,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), gridPaint);
    if (days.isEmpty) return;
    final slot = size.width / days.length;
    final w = (slot * 0.62).clamp(2.0, 22.0).toDouble();
    for (var i = 0; i < days.length; i++) {
      final v = values[days[i]] ?? 0;
      if (v <= 0 || maxV <= 0) continue;
      final h = (v / maxV) * (size.height - 6);
      final cx = rtl ? size.width - (i + 0.5) * slot : (i + 0.5) * slot;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w / 2, size.height - h, w, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = days[i] == today ? todayBar : bar);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values || old.days != days || old.maxV != maxV || old.rtl != rtl || old.bar != bar;
}
