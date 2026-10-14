import 'normalizer.dart';

/// Keyword packs used by the generic adapter. Entries are written naturally
/// and folded with [foldString] at load time so they match
/// [NormalizedSms.match]. Latin entries are matched on word boundaries;
/// Arabic entries are matched as substrings (Arabic attaches prefixes such as
/// و / ب / ال to words, which makes strict boundaries unreliable).
class KeywordSet {
  final List<String> _latin;
  final List<String> _arabic;
  late final RegExp? _latinRe;

  KeywordSet(List<String> words)
      : _latin = words.where((w) => !_hasArabic(w)).map(foldString).toList(),
        _arabic = words.where(_hasArabic).map(foldString).toList() {
    if (_latin.isEmpty) {
      _latinRe = null;
    } else {
      final sorted = [..._latin]..sort((a, b) => b.length.compareTo(a.length));
      final alt = sorted.map(RegExp.escape).join('|');
      _latinRe = RegExp('(?<![a-z0-9])(?:$alt)(?![a-z])');
    }
  }

  static bool _hasArabic(String s) => s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

  bool any(String match) {
    final re = _latinRe;
    if (re != null && re.hasMatch(match)) return true;
    for (final a in _arabic) {
      if (match.contains(a)) return true;
    }
    return false;
  }

  /// End index of the last occurrence inside [match] between [from] and [to],
  /// or -1.
  int lastEndIn(String match, int from, int to) {
    if (to <= from) return -1;
    final seg = match.substring(from, to);
    var best = -1;
    final re = _latinRe;
    if (re != null) {
      for (final m in re.allMatches(seg)) {
        if (m.end > best) best = m.end;
      }
    }
    for (final a in _arabic) {
      final i = seg.lastIndexOf(a);
      if (i >= 0 && i + a.length > best) best = i + a.length;
    }
    return best < 0 ? -1 : from + best;
  }
}

class Kw {
  static final otp = KeywordSet([
    'otp', 'one time password', 'one-time password', 'verification code', 'activation code',
    'authentication code', 'passcode', 'security code',
    'رمز التحقق', 'رمز التفعيل', 'رمز التأكيد', 'رمز المصادقة', 'كود التحقق', 'كود التفعيل',
    'كلمة المرور المؤقتة', 'كلمة المرور لمرة واحدة', 'رمز الدخول', 'الرمز المؤقت', 'رمز لمرة واحدة',
  ]);

  static final declined = KeywordSet([
    'declined', 'rejected', 'unsuccessful', 'not successful', 'insufficient', 'failed',
    'مرفوضة', 'مرفوض', 'تم رفض', 'لم تتم', 'غير ناجحة', 'فشلت', 'فشل', 'رصيد غير كاف', 'غير كافي',
  ]);

  static final promo = KeywordSet([
    'offer', 'promo', 'promotion', 'win', 'enjoy', 'exclusive', 'apply now', 'shop now', 'cashback offer',
    'عرض', 'عروض', 'اربح', 'استمتع', 'مسابقة', 'تخفيض', 'حصري', 'سارع', 'قدم الآن', 'تسوق الآن',
  ]);

  static final reminder = KeywordSet([
    'is due', 'due date', 'due on', 'reminder', 'minimum payment', 'statement balance', 'please pay',
    'تذكير', 'مستحقة', 'يرجى السداد', 'الرجاء السداد', 'آخر موعد', 'الحد الأدنى للسداد', 'تاريخ الاستحقاق',
  ]);

  static final completedMarker = KeywordSet([
    'has been', 'have been', 'was', 'successful', 'successfully', 'received', 'debited', 'credited', 'paid',
    'approved', 'completed', 'purchase', 'spent', 'withdrawn',
    'تم ', 'بنجاح', 'استلام', 'شراء', 'عملية', 'إيداع', 'ايداع',
  ]);

  static final reversal = KeywordSet([
    'reversal', 'reversed', 'transaction cancelled', 'cancelled transaction', 'transaction canceled', 'void',
    'عكس', 'إلغاء عملية', 'الغاء عملية', 'إلغاء العملية', 'الغاء العملية', 'إلغاء الحركة', 'تم إلغاء',
  ]);

  static final refund = KeywordSet([
    'refund', 'refunded', 'credited back', 'credit back', 'return of',
    'استرداد', 'مسترد', 'مسترجع', 'استرجاع', 'إرجاع مبلغ', 'ارجاع مبلغ', 'إرجاع',
  ]);

  static final cardPayment = KeywordSet([
    'credit card payment', 'card payment received', 'payment to your credit card', 'payment towards your card',
    'payment for your credit card', 'card repayment',
    'سداد بطاقة', 'سداد البطاقة', 'سداد بطاقتك', 'سداد مستحقات البطاقة', 'تسديد بطاقة', 'تسديد البطاقة',
    'دفعة لبطاقة', 'دفعة لبطاقتك', 'سداد البطاقة الائتمانية',
  ]);

  static final paymentReceived = KeywordSet(['payment received', 'payment of', 'تم استلام دفعة', 'استلام سداد']);
  static final creditCardMention = KeywordSet(['credit card', 'البطاقة الائتمانية', 'بطاقتك الائتمانية', 'بطاقة ائتمانية']);

  static final atm = KeywordSet([
    'atm', 'cash withdrawal', 'cash wdl', 'cash withdraw',
    'صراف', 'سحب نقدي', 'سحب نقد', 'سحب من الصراف', 'سحب صراف',
  ]);

  static final transferIn = KeywordSet([
    'incoming transfer', 'transfer received', 'received transfer', 'inward transfer', 'received a transfer',
    'credited to your account from', 'you have received',
    'حوالة واردة', 'تحويل وارد', 'استلام حوالة', 'إيداع حوالة', 'ايداع حوالة', 'وارد من', 'حوالة داخلية واردة',
  ]);

  static final transferOut = KeywordSet([
    'outgoing transfer', 'transfer to', 'transferred to', 'outward transfer', 'sent to', 'transfer of',
    'local transfer', 'international transfer', 'sarie',
    'حوالة صادرة', 'تحويل صادر', 'حوالة إلى', 'حوالة الى', 'تحويل إلى', 'تحويل الى', 'تحويل مبلغ',
    'حوالة محلية', 'حوالة دولية', 'تحويل من حسابك', 'حوالة سريعة', 'حوالة فورية',
  ]);

  static final billPayment = KeywordSet([
    'sadad', 'bill payment', 'paid bill', 'utility payment',
    'سداد فاتورة', 'سداد الفاتورة', 'دفع فاتورة', 'سداد فواتير', 'المفوتر',
  ]);

  static final online = KeywordSet([
    'online', 'e-commerce', 'ecommerce', 'internet purchase', 'web purchase', 'e-com',
    'عبر الإنترنت', 'عبر الانترنت', 'انترنت', 'إنترنت', 'شراء إلكتروني', 'شراء الكتروني', 'التجارة الإلكترونية',
  ]);

  static final purchase = KeywordSet([
    'purchase', 'pos', 'point of sale', 'spent', 'paid at', 'payment at', 'apple pay', 'mada pay', 'google pay',
    'samsung pay', 'card transaction',
    'شراء', 'مشتريات', 'نقاط البيع', 'نقطة البيع', 'عملية شراء', 'مدى', 'دفع لدى', 'أبل باي', 'ابل باي',
  ]);

  static final fee = KeywordSet([
    'fee', 'fees', 'commission', 'service charge',
    'رسوم', 'عمولة', 'رسم',
  ]);

  static final income = KeywordSet([
    'salary', 'payroll', 'deposit', 'deposited', 'cash deposit',
    'راتب', 'رواتب', 'مكافأة', 'إيداع', 'ايداع', 'إيداع نقدي',
  ]);

  static final debit = KeywordSet([
    'debited', 'debit', 'deducted', 'withdrawn', 'charged', 'paid',
    'خصم', 'مدين', 'سحب', 'مدفوع',
  ]);

  static final credit = KeywordSet([
    'credited', 'credit', 'added to your account',
    'دائن', 'أضيف', 'اضافة', 'إضافة',
  ]);

  // ---- amount context labels ----
  static final lblBalance = KeywordSet([
    'balance', 'bal', 'avl bal', 'available balance', 'current balance', 'remaining', 'ledger',
    'الرصيد', 'رصيد', 'رصيدك', 'المتبقي', 'متبقي', 'المتوفر',
  ]);

  static final lblAvailableCredit = KeywordSet([
    'available credit', 'available limit', 'avl limit', 'avail limit', 'avl lmt', 'avl credit',
    'الحد المتاح', 'الحد المتوفر', 'المبلغ المتاح', 'متاح', 'المتاح',
  ]);

  static final lblLimit = KeywordSet([
    'credit limit', 'limit', 'الحد الائتماني', 'حد البطاقة', 'الحد',
  ]);

  static final lblFee = KeywordSet([
    'fee', 'fees', 'commission', 'vat', 'رسوم', 'عمولة', 'ضريبة', 'رسم',
  ]);

  static final lblEquivalent = KeywordSet([
    'equivalent', 'equiv', 'in sar', 'local amount', 'billing amount', 'billed amount',
    'ما يعادل', 'يعادل', 'بالريال', 'المبلغ بالريال', 'المعادل',
  ]);

  static final lblTxn = KeywordSet([
    'amount', 'amt', 'purchase', 'paid', 'spent', 'debited', 'credited', 'withdrawn', 'withdrawal', 'refund',
    'transfer', 'deposit', 'payment', 'value', 'charged', 'reversal',
    'مبلغ', 'بمبلغ', 'المبلغ', 'قيمة', 'بقيمة', 'شراء', 'استرداد', 'حوالة', 'تحويل', 'خصم', 'سحب', 'إيداع',
    'ايداع', 'سداد', 'دفع', 'عكس',
  ]);
}
