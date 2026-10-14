import '../core/day.dart';
import '../core/money.dart';
import 'finance_models.dart';

/// Lowercased merchant name with punctuation and spaces removed, used for
/// matching refunds and duplicates.
String normalizeMerchant(String m) {
  final b = StringBuffer();
  for (final r in m.toLowerCase().runes) {
    final isDigit = r >= 0x30 && r <= 0x39;
    final isLatin = r >= 0x61 && r <= 0x7A;
    final isArabic = r >= 0x0621 && r <= 0x064A;
    if (isDigit || isLatin || isArabic) {
      var c = r;
      if (c == 0x0623 || c == 0x0625 || c == 0x0622) c = 0x0627; // alef forms
      if (c == 0x0629) c = 0x0647; // taa marbuta
      if (c == 0x0649) c = 0x064A; // alef maqsura
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

String _typeClass(TxnType t) {
  if (typeIsPurchaseLike(t)) return 'purchase';
  return t.name;
}

/// Fingerprint for duplicate detection. Includes the minute only when the
/// time came from the message itself (SMS arrival times are not reliable enough).
String fingerprintOf(FinTxn t) {
  final minute = t.tsSource == TimestampSource.message ? (t.txnAt ~/ 60000).toString() : '';
  return [
    _typeClass(t.type),
    t.amountMinor?.toString() ?? '',
    t.currency,
    t.accountLast4,
    normalizeMerchant(t.merchant),
    minute,
  ].join('|');
}

enum DuplicateKind { none, exact, possible }

class DuplicateCheck {
  final DuplicateKind kind;
  final int? matchId;
  const DuplicateCheck(this.kind, [this.matchId]);
}

/// Decides whether [c] duplicates one of [existing].
///
/// * exact: same source message, or same bank reference with the same amount.
///   The new copy is skipped.
/// * possible: looks like the same transaction reported twice, but could be two
///   legitimate purchases. The new item is kept in "Needs review" and excluded
///   from totals; it is never merged automatically.
DuplicateCheck checkDuplicate(FinTxn c, Iterable<FinTxn> existing) {
  for (final e in existing) {
    if (c.sourceKey.isNotEmpty && e.sourceKey == c.sourceKey) {
      return DuplicateCheck(DuplicateKind.exact, e.id);
    }
  }
  // Same message text from the same sender. Source keys prefixed 'r:' were
  // derived from the device receive time because the send time was unknown,
  // so a receiver copy and an inbox copy of one message can differ by seconds.
  if (c.bodyKey.isNotEmpty) {
    for (final e in existing) {
      if (e.bodyKey != c.bodyKey) continue;
      final dt = ((e.smsAt ?? e.txnAt) - (c.smsAt ?? c.txnAt)).abs();
      final unknownSendTime = e.sourceKey.startsWith('r:') || c.sourceKey.startsWith('r:');
      if (unknownSendTime && dt <= 2 * 60 * 1000) return DuplicateCheck(DuplicateKind.exact, e.id);
      if (dt <= 10 * 60 * 1000) return DuplicateCheck(DuplicateKind.possible, e.id);
    }
  }
  if (c.reference.isNotEmpty) {
    for (final e in existing) {
      if (e.reference.isNotEmpty &&
          e.reference.toLowerCase() == c.reference.toLowerCase() &&
          e.amountMinor == c.amountMinor &&
          e.currency == c.currency) {
        return DuplicateCheck(DuplicateKind.exact, e.id);
      }
    }
  }
  if (c.amountMinor == null) return const DuplicateCheck(DuplicateKind.none);
  final cm = normalizeMerchant(c.merchant);
  for (final e in existing) {
    if (e.id == null || e.source != TxnSource.sms) continue;
    if (e.amountMinor != c.amountMinor || e.currency != c.currency) continue;
    if (_typeClass(e.type) != _typeClass(c.type)) continue;
    if (e.accountLast4.isNotEmpty && c.accountLast4.isNotEmpty && e.accountLast4 != c.accountLast4) continue;
    final em = normalizeMerchant(e.merchant);
    if (em.isNotEmpty && cm.isNotEmpty && em != cm) continue;
    // Both carry a time printed by the bank: different minutes => distinct purchases.
    if (e.tsSource == TimestampSource.message && c.tsSource == TimestampSource.message) {
      if (e.txnAt ~/ 60000 != c.txnAt ~/ 60000) continue;
      // Different references prove they are distinct.
      if (e.reference.isNotEmpty && c.reference.isNotEmpty && e.reference != c.reference) continue;
      return DuplicateCheck(DuplicateKind.possible, e.id);
    }
    final ea = e.smsAt ?? e.txnAt;
    final ca = c.smsAt ?? c.txnAt;
    if ((ea - ca).abs() <= 3 * 60 * 1000) {
      if (e.reference.isNotEmpty && c.reference.isNotEmpty && e.reference != c.reference) continue;
      return DuplicateCheck(DuplicateKind.possible, e.id);
    }
  }
  return const DuplicateCheck(DuplicateKind.none);
}

/// Links a refund/reversal to an original purchase only when exactly one
/// confirmed purchase matches on merchant, currency and exact amount within
/// 120 days before it. Returns null when evidence is insufficient.
int? findRefundOriginal(FinTxn refund, Iterable<FinTxn> txns) {
  if (!typeIsRefundLike(refund.type) || refund.amountMinor == null) return null;
  final rm = normalizeMerchant(refund.merchant);
  if (rm.isEmpty) return null;
  final alreadyLinked = txns.where((t) => t.linkedTxnId != null && t.id != refund.id).map((t) => t.linkedTxnId).toSet();
  final matches = txns.where((t) {
    if (t.id == null || t.id == refund.id) return false;
    if (!typeIsPurchaseLike(t.type) || t.status != TxnStatus.confirmed) return false;
    if (t.currency != refund.currency || t.amountMinor != refund.amountMinor) return false;
    if (normalizeMerchant(t.merchant) != rm) return false;
    if (t.txnAt > refund.txnAt) return false;
    if (refund.txnAt - t.txnAt > const Duration(days: 120).inMilliseconds) return false;
    if (alreadyLinked.contains(t.id)) return false;
    return true;
  }).toList();
  return matches.length == 1 ? matches.first.id : null;
}

class FinanceSummary {
  final CurrencyTotals gross = CurrencyTotals();
  final CurrencyTotals refunds = CurrencyTotals();
  final CurrencyTotals atm = CurrencyTotals();
  final CurrencyTotals transfersOut = CurrencyTotals();
  final CurrencyTotals transfersIn = CurrencyTotals();
  final CurrencyTotals income = CurrencyTotals();
  final CurrencyTotals cardPayments = CurrencyTotals();
  final Map<Day, int> dailyGrossSar = {};
  final Map<int?, int> categoryGrossSar = {};
  int confirmedCount = 0;
  int reviewCount = 0;

  int netOf(String currency) => gross.of(currency) - refunds.of(currency);

  /// Currencies (other than SAR) that have spending or refunds.
  Set<String> get foreignCurrencies => {...gross.foreign().keys, ...refunds.foreign().keys};

  bool get hasAnyConfirmed => confirmedCount > 0;
}

/// Computes totals for [range]. Only confirmed items count; items needing
/// review (including possible duplicates) are excluded. Currencies are never
/// mixed: foreign amounts are only added to SAR when the message carried a
/// SAR equivalent.
FinanceSummary summarize(Iterable<FinTxn> txns, DayRange range) {
  final s = FinanceSummary();
  final start = range.startMillis;
  final end = range.endMillisExclusive;
  for (final t in txns) {
    if (t.txnAt < start || t.txnAt >= end) continue;
    if (t.status == TxnStatus.needsReview) {
      s.reviewCount++;
      continue;
    }
    final amount = t.effectiveAmount;
    if (amount == null || t.duplicateOfId != null) continue;
    s.confirmedCount++;
    final cur = t.effectiveCurrency;
    if (t.countsAsExpense) {
      s.gross.add(cur, amount);
      if (cur == kDefaultCurrency) {
        final day = Day.fromDateTime(DateTime.fromMillisecondsSinceEpoch(t.txnAt));
        s.dailyGrossSar[day] = (s.dailyGrossSar[day] ?? 0) + amount;
        s.categoryGrossSar[t.categoryId] = (s.categoryGrossSar[t.categoryId] ?? 0) + amount;
      }
      continue;
    }
    switch (t.type) {
      case TxnType.refund:
      case TxnType.reversal:
        if (t.countOverride != false) s.refunds.add(cur, amount);
        break;
      case TxnType.atmWithdrawal:
        s.atm.add(cur, amount);
        break;
      case TxnType.transferOut:
        s.transfersOut.add(cur, amount);
        break;
      case TxnType.transferIn:
        s.transfersIn.add(cur, amount);
        break;
      case TxnType.income:
        s.income.add(cur, amount);
        break;
      case TxnType.cardPayment:
        s.cardPayments.add(cur, amount);
        break;
      default:
        break;
    }
  }
  return s;
}
