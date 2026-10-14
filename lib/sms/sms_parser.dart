import '../core/day.dart';
import '../core/money.dart';
import '../domain/finance_models.dart';
import 'keywords.dart';
import 'normalizer.dart';

/// A message handed to the parser. Never logged.
class RawSms {
  final String sender;
  final String body;

  /// Time the device received the message (epoch ms).
  final int receivedAt;

  /// Time the message was sent per the SMS service centre (epoch ms, 0 if unknown).
  final int sentAt;

  const RawSms({required this.sender, required this.body, required this.receivedAt, this.sentAt = 0});
}

enum IgnoreReason { otp, declined, promo, reminder, notFinancial, balanceOnly }

/// Review reason codes (localized in the UI).
class ReviewReason {
  static const ambiguousAmount = 'ambiguous_amount';
  static const noAmount = 'no_amount';
  static const unknownType = 'unknown_type';
  static const weakType = 'weak_type';
  static const lowConfidence = 'low_confidence';
  static const possibleDuplicate = 'possible_duplicate';
  static const unlinkedReversal = 'unlinked_reversal';
}

class ParsedTxn {
  final TxnType type;
  final int? amountMinor;
  final String currency;
  final bool currencyAssumed;
  final int? sarAmountMinor;
  final int? feeMinor;
  final String merchant;
  final String accountLast4;
  final String reference;
  final int txnAt;
  final TimestampSource tsSource;
  final int confidence;
  final List<String> reviewReasons;
  final List<int> candidates;
  final String parserVersion;
  final String excerpt;

  const ParsedTxn({
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.currencyAssumed,
    required this.sarAmountMinor,
    required this.feeMinor,
    required this.merchant,
    required this.accountLast4,
    required this.reference,
    required this.txnAt,
    required this.tsSource,
    required this.confidence,
    required this.reviewReasons,
    required this.candidates,
    required this.parserVersion,
    required this.excerpt,
  });

  bool get needsReview => reviewReasons.isNotEmpty;
}

class ParseOutcome {
  final ParsedTxn? txn;
  final IgnoreReason? ignored;
  const ParseOutcome.parsed(ParsedTxn this.txn) : ignored = null;
  const ParseOutcome.ignored(IgnoreReason this.ignored) : txn = null;
  bool get isTransaction => txn != null;
}

/// Extension point: bank-specific adapters can be registered ahead of the
/// generic one. An adapter must only claim messages it has fixtures for.
abstract class SmsParserAdapter {
  String get id;
  bool canHandle(RawSms sms, NormalizedSms norm);
  ParseOutcome parse(RawSms sms, NormalizedSms norm);
}

class SmsParser {
  final List<SmsParserAdapter> adapters;

  SmsParser({List<SmsParserAdapter>? bankAdapters})
      : adapters = [...?bankAdapters, GenericFinancialAdapter()];

  ParseOutcome parse(RawSms sms) {
    final norm = normalizeSms(sms.body);
    for (final a in adapters) {
      if (a.canHandle(sms, norm)) return a.parse(sms, norm);
    }
    return const ParseOutcome.ignored(IgnoreReason.notFinancial);
  }
}

/// Cheap pre-filter mirroring the native one: could this be a financial message?
bool looksFinancial(String body) {
  final n = normalizeSms(body);
  if (!RegExp(r'\d').hasMatch(n.match)) return false;
  return _currencyHits(n.match).isNotEmpty || Kw.lblTxn.any(n.match);
}

// ---------------------------------------------------------------------------
// Currency tokens

class _CurrencyHit {
  final int start;
  final int end;
  final String code;
  final bool arabicWord;
  _CurrencyHit(this.start, this.end, this.code, this.arabicWord);
}

const Map<String, String> _currencyTokens = {
  'ريال سعودي': 'SAR',
  'ر.س': 'SAR',
  'رس': 'SAR',
  'ريالات': 'SAR',
  'ريالا': 'SAR',
  'ريال': 'SAR',
  'sar': 'SAR',
  'sr': 'SAR',
  'ريال قطري': 'QAR',
  'qar': 'QAR',
  'ريال عماني': 'OMR',
  'omr': 'OMR',
  'usd': 'USD',
  'us\$': 'USD',
  '\$': 'USD',
  'دولار امريكي': 'USD',
  'دولار': 'USD',
  'eur': 'EUR',
  '€': 'EUR',
  'يورو': 'EUR',
  'gbp': 'GBP',
  '£': 'GBP',
  'جنيه استرليني': 'GBP',
  'aed': 'AED',
  'درهم اماراتي': 'AED',
  'درهم': 'AED',
  'kwd': 'KWD',
  'دينار كويتي': 'KWD',
  'bhd': 'BHD',
  'دينار بحريني': 'BHD',
  'jod': 'JOD',
  'دينار اردني': 'JOD',
  'egp': 'EGP',
  'جنيه مصري': 'EGP',
  'inr': 'INR',
  'jpy': 'JPY',
  'cny': 'CNY',
  'cad': 'CAD',
  'aud': 'AUD',
  'chf': 'CHF',
  'try': 'TRY',
};

final List<MapEntry<RegExp, String>> _currencyRegexes = () {
  final keys = _currencyTokens.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  return keys.map((k) {
    final esc = RegExp.escape(k);
    final isArabic = k.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
    final isLatin = RegExp(r'^[a-z$]+$').hasMatch(k) && k != r'$';
    String pattern;
    if (isArabic) {
      pattern = '(?<![\u0621-\u064a])$esc(?![\u0621-\u064a])';
    } else if (isLatin) {
      pattern = '(?<![a-z])$esc(?![a-z])';
    } else {
      pattern = esc;
    }
    return MapEntry(RegExp(pattern), _currencyTokens[k]!);
  }).toList();
}();

List<_CurrencyHit> _currencyHits(String match) {
  final hits = <_CurrencyHit>[];
  for (final e in _currencyRegexes) {
    for (final m in e.key.allMatches(match)) {
      final arabic = match.codeUnitAt(m.start) >= 0x0600 && match.codeUnitAt(m.start) <= 0x06FF;
      hits.add(_CurrencyHit(m.start, m.end, e.value, arabic));
    }
  }
  hits.sort((a, b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : (b.end - b.start).compareTo(a.end - a.start);
  });
  final result = <_CurrencyHit>[];
  var lastEnd = -1;
  for (final h in hits) {
    if (h.start >= lastEnd) {
      result.add(h);
      lastEnd = h.end;
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Amount mentions

enum AmountLabel { txn, balance, availableCredit, limit, fee, equivalent, none }

class _Mention {
  final int start;
  final int end;
  final String numText;
  String? currency;
  bool explicitCurrency = false;
  AmountLabel label = AmountLabel.none;
  bool paren = false;
  int? minor;
  _Mention(this.start, this.end, this.numText);

  String get key => '${currency ?? '?'}:$minor';
}

final RegExp _numberRe = RegExp(r'\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?');

bool _isDigitAt(String s, int i) => i >= 0 && i < s.length && s.codeUnitAt(i) >= 0x30 && s.codeUnitAt(i) <= 0x39;

List<_Mention> _numbers(String match) {
  final out = <_Mention>[];
  for (final m in _numberRe.allMatches(match)) {
    final s = m.start;
    final e = m.end;
    final prev = s > 0 ? match[s - 1] : '';
    final next = e < match.length ? match[e] : '';
    // Date / time fragments.
    if ((prev == '/' || prev == ':' || prev == '-') && _isDigitAt(match, s - 2)) continue;
    if ((next == '/' || next == ':' || next == '-') && _isDigitAt(match, e + 1)) continue;
    // Masked card / account digits.
    if (prev == '*' || prev == 'x' || prev == '•' || prev == '#') continue;
    // Percentages.
    if (next == '%' || (next == ' ' && e + 1 < match.length && match[e + 1] == '%')) continue;
    final text = m.group(0)!;
    final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!text.contains(RegExp(r'[.,]')) && digitsOnly.length > 9) continue; // references, phone numbers
    out.add(_Mention(s, e, text));
  }
  return out;
}

bool _gapOk(String match, int from, int to) {
  if (to < from || to - from > 3) return false;
  return RegExp(r'^[\s:=]*$').hasMatch(match.substring(from, to));
}

void _attachCurrencies(String match, List<_Mention> nums, List<_CurrencyHit> hits) {
  for (final h in hits) {
    _Mention? before;
    _Mention? after;
    for (final n in nums) {
      if (n.end <= h.start && _gapOk(match, n.end, h.start)) before = n;
      if (n.start >= h.end && _gapOk(match, h.end, n.start)) {
        after ??= n;
      }
    }
    _Mention? pick;
    if (before != null && after != null) {
      if (before.currency != null) {
        pick = after;
      } else {
        pick = h.arabicWord ? before : after;
      }
    } else {
      pick = before ?? after;
    }
    if (pick != null && pick.currency == null) {
      pick.currency = h.code;
      pick.explicitCurrency = true;
    }
  }
}

AmountLabel _labelFor(String match, int segStart, int segEnd) {
  final candidates = <AmountLabel, int>{
    AmountLabel.equivalent: Kw.lblEquivalent.lastEndIn(match, segStart, segEnd),
    AmountLabel.availableCredit: Kw.lblAvailableCredit.lastEndIn(match, segStart, segEnd),
    AmountLabel.limit: Kw.lblLimit.lastEndIn(match, segStart, segEnd),
    AmountLabel.balance: Kw.lblBalance.lastEndIn(match, segStart, segEnd),
    AmountLabel.fee: Kw.lblFee.lastEndIn(match, segStart, segEnd),
    AmountLabel.txn: Kw.lblTxn.lastEndIn(match, segStart, segEnd),
  };
  var best = AmountLabel.none;
  var bestEnd = -1;
  for (final e in candidates.entries) {
    // Strictly greater keeps the priority order above on ties.
    if (e.value > bestEnd) {
      bestEnd = e.value;
      best = e.key;
    }
  }
  return best;
}

int _lineStart(String s, int i) {
  final idx = s.lastIndexOf('\n', i > 0 ? i - 1 : 0);
  return idx < 0 ? 0 : idx + 1;
}

/// Finds money mentions and labels each one from the nearest preceding keyword.
List<_Mention> _mentions(String match) {
  final nums = _numbers(match);
  _attachCurrencies(match, nums, _currencyHits(match));
  final out = <_Mention>[];
  var prevEnd = 0;
  for (final n in nums) {
    final segStart = [prevEnd, _lineStart(match, n.start)].reduce((a, b) => a > b ? a : b);
    n.label = _labelFor(match, segStart, n.start);
    final seg = match.substring(segStart, n.start);
    n.paren = seg.trimRight().endsWith('(') || seg.trimRight().endsWith('(sar') || seg.contains('(');
    if (n.currency == null) {
      // A bare number counts only right after an amount/fee keyword ("Amount: 50.00").
      if (n.label == AmountLabel.txn || n.label == AmountLabel.fee) {
        final kwEnd = n.label == AmountLabel.txn
            ? Kw.lblTxn.lastEndIn(match, segStart, n.start)
            : Kw.lblFee.lastEndIn(match, segStart, n.start);
        if (kwEnd < 0 || n.start - kwEnd > 14) {
          prevEnd = n.end;
          continue;
        }
      } else {
        prevEnd = n.end;
        continue;
      }
    }
    n.minor = parseAmountToMinor(n.numText, n.currency ?? kDefaultCurrency);
    if (n.minor != null && n.minor! > 0) out.add(n);
    prevEnd = n.end;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Classification

class _TypeGuess {
  final TxnType? type;
  final int strength; // 2 specific, 1 weak, 0 none
  const _TypeGuess(this.type, this.strength);
}

final KeywordSet _transferGeneric = KeywordSet(['transfer', 'حوالة', 'تحويل']);

_TypeGuess _classify(String m) {
  if (Kw.reversal.any(m)) return const _TypeGuess(TxnType.reversal, 2);
  if (Kw.refund.any(m)) return const _TypeGuess(TxnType.refund, 2);
  if (Kw.cardPayment.any(m) || (Kw.paymentReceived.any(m) && Kw.creditCardMention.any(m))) {
    return const _TypeGuess(TxnType.cardPayment, 2);
  }
  if (Kw.atm.any(m)) return const _TypeGuess(TxnType.atmWithdrawal, 2);
  if (Kw.transferIn.any(m)) return const _TypeGuess(TxnType.transferIn, 2);
  if (Kw.transferOut.any(m)) return const _TypeGuess(TxnType.transferOut, 2);
  if (Kw.billPayment.any(m)) return const _TypeGuess(TxnType.billPayment, 2);
  final purchase = Kw.purchase.any(m);
  if (Kw.online.any(m) && (purchase || Kw.debit.any(m))) return const _TypeGuess(TxnType.onlinePurchase, 2);
  if (purchase) return const _TypeGuess(TxnType.cardPurchase, 2);
  if (Kw.fee.any(m)) {
    return Kw.debit.any(m) || Kw.completedMarker.any(m)
        ? const _TypeGuess(TxnType.bankFee, 2)
        : const _TypeGuess(TxnType.bankFee, 1);
  }
  if (Kw.income.any(m)) return const _TypeGuess(TxnType.income, 2);
  if (_transferGeneric.any(m)) return const _TypeGuess(TxnType.transferOut, 1);
  if (Kw.debit.any(m)) return const _TypeGuess(TxnType.unknown, 1);
  if (Kw.credit.any(m)) return const _TypeGuess(TxnType.unknown, 1);
  return const _TypeGuess(null, 0);
}

// ---------------------------------------------------------------------------
// Field extraction

final RegExp _purchaseMarker = RegExp(
    '(?:(?<![a-z])(?:merchant name|merchant|mer|at|from)(?![a-z])|@|(?<![\u0621-\u064a])(?:لدي|عند|اسم التاجر|التاجر|المتجر|نقطه البيع|من متجر|في متجر)(?![\u0621-\u064a])|(?<![\u0621-\u064a])من(?=\\s*:))\\s*[:\\-]?\\s*');
final RegExp _transferOutMarker = RegExp(
    '(?:(?<![a-z])(?:beneficiary|to)(?![a-z])|(?<![\u0621-\u064a])(?:المستفيد|اسم المستفيد|لصالح|الي|للمستفيد)(?![\u0621-\u064a]))\\s*[:\\-]?\\s*');
final RegExp _transferInMarker = RegExp(
    '(?:(?<![a-z])(?:from|sender|remitter)(?![a-z])|(?<![\u0621-\u064a])(?:المرسل|المحول|من)(?![\u0621-\u064a]))\\s*[:\\-]?\\s*');

const List<String> _merchantStops = [
  ' on ', ' via ', ' with ', ' using ', ' card', ' date', ' ref', ' amount', ' amt', ' bal', ' for ', ' at ',
  ' sar', ' (', ' avl', ' time', ' your ', ' from ', ' to ', ' acc', ' trx', ' txn',
  ' في ', ' بتاريخ', ' بمبلغ', ' مبلغ', ' رصيد', ' الرصيد', ' بطاقه', ' عبر', ' تاريخ', ' الساعه', ' رقم',
  ' من حساب', ' من بطاق', ' بقيمه', ' ريال', ' يوم', ' الي ', ' بطاقت', ' لبطاق', ' حساب', ' لحساب',
  '. ', ', ', ' - ', ';', '|',
];

String _extractMerchant(NormalizedSms n, TxnType type) {
  final m = n.match;
  final RegExp marker;
  switch (type) {
    case TxnType.transferOut:
    case TxnType.cardPayment:
      marker = _transferOutMarker;
      break;
    case TxnType.transferIn:
    case TxnType.income:
      marker = _transferInMarker;
      break;
    default:
      marker = _purchaseMarker;
  }
  for (final mk in marker.allMatches(m)) {
    final start = mk.end;
    if (start >= m.length) continue;
    var end = m.indexOf('\n', start);
    if (end < 0) end = m.length;
    final windowLower = m.substring(start, end);
    var cut = windowLower.length;
    for (final stop in _merchantStops) {
      final i = windowLower.indexOf(stop);
      if (i >= 0 && i < cut) cut = i;
    }
    final dateIdx = RegExp(r'\d{1,4}[-/:]\d').firstMatch(windowLower);
    if (dateIdx != null && dateIdx.start < cut) cut = dateIdx.start;
    var candidate = n.text.substring(start, start + cut);
    candidate = candidate.replaceAll(RegExp(r'^[\s:\-.,*]+|[\s:\-.,*]+$'), '');
    if (candidate.length > 48) candidate = candidate.substring(0, 48).trimRight();
    final letters = RegExp(r'[A-Za-z\u0621-\u064A]').allMatches(candidate).length;
    if (letters < 2) continue;
    if (RegExp(r'^\d').hasMatch(candidate)) continue;
    final lc = foldString(candidate.toLowerCase());
    const reject = ['sar', 'ريال', 'account', 'card'];
    const rejectPrefix = ['your', 'you ', 'حساب', 'بطاق', 'the account', 'account', 'card', 'رصيد', 'الرصيد'];
    if (reject.contains(lc) || rejectPrefix.any(lc.startsWith)) continue;
    return candidate;
  }
  return '';
}

final List<RegExp> _accountRes = [
  RegExp(
      r'(?:card|بطاقه|البطاقه|بطاقتك|account|acc|a/c|حساب|الحساب|حسابك)\s*(?:no\.?|number|num|رقم|ending(?: with| in)?|المنتهيه ب|المنتهي ب|ينتهي ب)?\s*[:#]?\s*[*x•]*\s?(\d{4})(?!\d)'),
  RegExp(r'[*x•]{2,}\s?(\d{3,4})(?!\d)'),
  RegExp(r'(?:ending|ends)(?: with| in)?\s*[:#]?\s*(\d{4})(?!\d)'),
  RegExp(r'(?:account|acc|حساب|الحساب|حسابك)\s*(?:no\.?|رقم)?\s*[:#]?\s*(\d{5,})'),
];

String _extractAccount(String m) {
  for (final re in _accountRes) {
    final mm = re.firstMatch(m);
    if (mm != null) {
      final d = mm.group(1)!;
      return d.length > 4 ? d.substring(d.length - 4) : d;
    }
  }
  return '';
}

final RegExp _refRe = RegExp(
    r'(?:ref(?:erence)?(?:\s*(?:no|number|num))?\.?|rrn|auth(?:orization)? code|approval code|txn id|transaction id|trx id|رقم المرجع|الرقم المرجعي|المرجع|رقم العمليه|رقم الحواله|رقم الحركه|رقم التفويض)\s*[:#.]?\s*([a-z0-9][a-z0-9-]{4,})');

String _extractReference(NormalizedSms n) {
  final mm = _refRe.firstMatch(n.match);
  if (mm == null) return '';
  return n.text.substring(mm.start(1), mm.end(1));
}

// ---------------------------------------------------------------------------
// Timestamp

const List<String> _enMonths = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const List<String> _arMonths = [
  'يناير', 'فبراير', 'مارس', 'ابريل', 'مايو', 'يونيو', 'يوليو', 'اغسطس', 'سبتمبر', 'اكتوبر', 'نوفمبر', 'ديسمبر'
];

final RegExp _ymdRe = RegExp(r'(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)');
final RegExp _dmyRe = RegExp(r'(?<![\d.])(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?![\d])');
final RegExp _enMonRe = RegExp(r'(?<!\d)(\d{1,2})[\s-]?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?[\s,-]*(\d{4}|\d{2})?(?!\d)');
final RegExp _arMonRe = RegExp('(?<!\\d)(\\d{1,2})\\s*(${_arMonths.join('|')})\\s*(\\d{4})?(?!\\d)');
final RegExp _timeRe = RegExp(
    '(?<![\\d:])(\\d{1,2}):(\\d{2})(?::(\\d{2}))?(?:\\s*(am|pm|a\\.m\\.|p\\.m\\.|صباحا|صباح|مساء|ص|م)(?![a-z\u0621-\u064a]))?');

Day? _mkDay(int y, int m, int d) {
  if (y < 100) y += 2000;
  if (m < 1 || m > 12 || d < 1 || d > Day.daysInMonthOf(y, m)) return null;
  return Day(y, m, d);
}

Day? _bestDate(String m, Day smsDay) {
  final cands = <Day>[];
  for (final mm in _ymdRe.allMatches(m)) {
    final d = _mkDay(int.parse(mm.group(1)!), int.parse(mm.group(2)!), int.parse(mm.group(3)!));
    if (d != null) cands.add(d);
  }
  for (final mm in _dmyRe.allMatches(m)) {
    final a = int.parse(mm.group(1)!);
    final b = int.parse(mm.group(2)!);
    final cText = mm.group(3)!;
    final c = int.parse(cText);
    for (final d in [
      _mkDay(c, b, a), // dd-mm-yy(yy)
      if (cText.length == 2) _mkDay(a, b, c), // yy-mm-dd
      _mkDay(c, a, b), // mm-dd-yy(yy)
    ]) {
      if (d != null) cands.add(d);
    }
  }
  for (final mm in _enMonRe.allMatches(m)) {
    final mon = _enMonths.indexOf(mm.group(2)!) + 1;
    final y = mm.group(3) != null ? int.parse(mm.group(3)!) : smsDay.year;
    final d = _mkDay(y, mon, int.parse(mm.group(1)!));
    if (d != null) cands.add(d);
  }
  for (final mm in _arMonRe.allMatches(m)) {
    final mon = _arMonths.indexOf(mm.group(2)!) + 1;
    final y = mm.group(3) != null ? int.parse(mm.group(3)!) : smsDay.year;
    final d = _mkDay(y, mon, int.parse(mm.group(1)!));
    if (d != null) cands.add(d);
  }
  Day? best;
  var bestDist = 1 << 30;
  for (final d in cands) {
    final diff = d.differenceInDays(smsDay);
    if (diff > 1 || diff < -400) continue; // implausible
    final dist = diff.abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = d;
    }
  }
  return best;
}

int? _bestTimeMinutes(String m) {
  for (final mm in _timeRe.allMatches(m)) {
    var h = int.parse(mm.group(1)!);
    final mi = int.parse(mm.group(2)!);
    final ap = mm.group(4);
    if (ap != null) {
      final pm = ap == 'pm' || ap == 'p.m.' || ap == 'م' || ap == 'مساء';
      final am = ap == 'am' || ap == 'a.m.' || ap == 'ص' || ap == 'صباح' || ap == 'صباحا';
      if (h > 12) continue;
      if (pm && h < 12) h += 12;
      if (am && h == 12) h = 0;
    }
    if (h > 23 || mi > 59) continue;
    return h * 60 + mi;
  }
  return null;
}

class _Ts {
  final int at;
  final TimestampSource src;
  const _Ts(this.at, this.src);
}

_Ts _extractTimestamp(String m, int smsTime) {
  final smsDt = DateTime.fromMillisecondsSinceEpoch(smsTime);
  final smsDay = Day.fromDateTime(smsDt);
  final date = _bestDate(m, smsDay);
  final minutes = _bestTimeMinutes(m);
  const slack = 10 * 60 * 1000;
  if (date != null && minutes != null) {
    final at = date.atMinutes(minutes).millisecondsSinceEpoch;
    if (at <= smsTime + const Duration(days: 1).inMilliseconds) return _Ts(at, TimestampSource.message);
  }
  if (date != null) {
    if (date == smsDay) return _Ts(smsTime, TimestampSource.messageDateOnly);
    return _Ts(date.atMinutes(12 * 60).millisecondsSinceEpoch, TimestampSource.messageDateOnly);
  }
  if (minutes != null) {
    var at = smsDay.atMinutes(minutes).millisecondsSinceEpoch;
    if (at > smsTime + slack) at = smsDay.addDays(-1).atMinutes(minutes).millisecondsSinceEpoch;
    return _Ts(at, TimestampSource.message);
  }
  return _Ts(smsTime, TimestampSource.smsFallback);
}

// ---------------------------------------------------------------------------
// Redaction

/// Redacts identifiers from a message for the review screen: long digit runs
/// (account numbers, references, phone numbers) and card/account last-4 digits.
/// Amount mentions are kept so the user can verify them.
String redactExcerpt(String text, {String last4 = '', List<List<int>> keep = const []}) {
  bool kept(int s, int e) => keep.any((r) => s >= r[0] && e <= r[1]);
  final b = StringBuffer();
  var i = 0;
  for (final m in RegExp(r'\d+').allMatches(text)) {
    b.write(text.substring(i, m.start));
    final run = m.group(0)!;
    final mask = !kept(m.start, m.end) && (run.length >= 5 || (last4.isNotEmpty && run.endsWith(last4) && run.length >= 4));
    b.write(mask ? '•' * (run.length > 4 ? 4 : run.length) : run);
    i = m.end;
  }
  b.write(text.substring(i));
  var s = b.toString();
  if (s.length > 280) s = '${s.substring(0, 280)}…';
  return s;
}

/// Masks a sender that looks like a personal phone number.
String displaySender(String sender) {
  final digits = sender.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length >= 7 && RegExp(r'^[+0-9\s-]+$').hasMatch(sender)) {
    return '•••${digits.substring(digits.length - 3)}';
  }
  return sender.trim();
}

// ---------------------------------------------------------------------------
// Generic adapter

class GenericFinancialAdapter implements SmsParserAdapter {
  static const version = 'generic-1.0';

  @override
  String get id => 'generic';

  @override
  bool canHandle(RawSms sms, NormalizedSms norm) => true;

  @override
  ParseOutcome parse(RawSms sms, NormalizedSms norm) {
    final m = norm.match;
    if (!RegExp(r'\d').hasMatch(m)) return const ParseOutcome.ignored(IgnoreReason.notFinancial);
    if (Kw.otp.any(m)) return const ParseOutcome.ignored(IgnoreReason.otp);
    if (Kw.declined.any(m)) return const ParseOutcome.ignored(IgnoreReason.declined);

    final mentions = _mentions(m);
    final guess = _classify(m);

    if (mentions.isEmpty) return const ParseOutcome.ignored(IgnoreReason.notFinancial);
    final hasCompleted = Kw.completedMarker.any(m);
    if (Kw.reminder.any(m) && !hasCompleted) return const ParseOutcome.ignored(IgnoreReason.reminder);
    // Marketing text: ignored unless it also reads like a completed
    // transaction, in which case it is kept but always sent to review.
    final promo = Kw.promo.any(m);
    if (promo && !hasCompleted) return const ParseOutcome.ignored(IgnoreReason.promo);
    if (guess.type == null) {
      final onlyBalances = mentions.every((x) =>
          x.label == AmountLabel.balance || x.label == AmountLabel.availableCredit || x.label == AmountLabel.limit);
      return ParseOutcome.ignored(onlyBalances ? IgnoreReason.balanceOnly : IgnoreReason.notFinancial);
    }

    final type = guess.type!;
    final reasons = <String>[];
    var confidence = 100;

    // ---- amount selection ----
    final txnLabeled = mentions.where((x) => x.label == AmountLabel.txn).toList();
    final unlabeled = mentions.where((x) => x.label == AmountLabel.none && x.explicitCurrency).toList();
    final fees = mentions.where((x) => x.label == AmountLabel.fee).toList();
    final equivalents = mentions.where((x) => x.label == AmountLabel.equivalent || x.paren).toList();

    var pool = txnLabeled;
    var fromUnlabeled = false;
    var feeAsAmount = false;
    if (pool.isEmpty) {
      pool = unlabeled;
      fromUnlabeled = true;
      // A parenthesised amount is a conversion, not a second transaction.
      if (pool.length > 1) {
        final nonParen = pool.where((x) => !x.paren).toList();
        if (nonParen.isNotEmpty) pool = nonParen;
      }
    }
    if (pool.isEmpty && type == TxnType.bankFee && fees.isNotEmpty) {
      pool = fees;
      feeAsAmount = true;
      fromUnlabeled = false;
    }

    final distinct = <String, _Mention>{};
    for (final x in pool) {
      distinct.putIfAbsent(x.key, () => x);
    }

    _Mention? chosen;
    int? sarEquivalent;
    var candidates = <int>[];
    if (distinct.length == 1) {
      chosen = distinct.values.first;
    } else if (distinct.length == 2) {
      // Foreign amount with its SAR equivalent, e.g. "USD 20.00 (SAR 75.10)".
      final vals = distinct.values.toList();
      final foreign = vals.where((x) => x.currency != null && x.currency != kDefaultCurrency).toList();
      final sar = vals.where((x) => x.currency == kDefaultCurrency).toList();
      if (foreign.length == 1 && sar.length == 1 && sar.first.start > foreign.first.start &&
          (sar.first.paren || sar.first.label == AmountLabel.equivalent)) {
        chosen = foreign.first;
        sarEquivalent = sar.first.minor;
      }
    }
    if (chosen == null && distinct.length > 1) {
      candidates = distinct.values.map((x) => x.minor!).toList();
      reasons.add(ReviewReason.ambiguousAmount);
    }
    if (chosen == null && distinct.isEmpty) {
      reasons.add(ReviewReason.noAmount);
    }
    if (chosen != null && chosen.currency != null && chosen.currency != kDefaultCurrency && sarEquivalent == null) {
      for (final eq in equivalents) {
        if (eq.currency == kDefaultCurrency && eq.start > chosen.start) {
          sarEquivalent = eq.minor;
          break;
        }
      }
    }

    final currencyAssumed = chosen != null && chosen.currency == null;
    final currency = chosen?.currency ?? kDefaultCurrency;
    if (currencyAssumed) confidence -= 20;
    if (fromUnlabeled && chosen != null) confidence -= 10;

    int? feeMinor;
    if (!feeAsAmount) {
      for (final f in fees) {
        if ((f.currency ?? currency) == currency && f.minor != chosen?.minor) {
          feeMinor = f.minor;
          break;
        }
      }
    }

    // ---- type confidence ----
    if (guess.strength < 2) {
      confidence -= 30;
      reasons.add(ReviewReason.weakType);
    }
    if (type == TxnType.unknown) reasons.add(ReviewReason.unknownType);

    final merchant = _extractMerchant(norm, type);
    if (typeIsPurchaseLike(type) && merchant.isEmpty) confidence -= 10;
    if (promo) confidence -= 40;
    if (confidence < 70 && reasons.isEmpty) reasons.add(ReviewReason.lowConfidence);

    final ts = _extractTimestamp(m, sms.receivedAt);
    final last4 = _extractAccount(m);
    final keep = [for (final x in mentions) <int>[x.start, x.end]];
    final excerpt = reasons.isEmpty ? '' : redactExcerpt(norm.text, last4: last4, keep: keep);

    return ParseOutcome.parsed(ParsedTxn(
      type: type,
      amountMinor: chosen?.minor,
      currency: currency,
      currencyAssumed: currencyAssumed,
      sarAmountMinor: sarEquivalent,
      feeMinor: feeMinor,
      merchant: merchant,
      accountLast4: last4,
      reference: _extractReference(norm),
      txnAt: ts.at,
      tsSource: ts.src,
      confidence: confidence < 0 ? 0 : (confidence > 100 ? 100 : confidence),
      reviewReasons: reasons,
      candidates: candidates,
      parserVersion: version,
      excerpt: excerpt,
    ));
  }
}
