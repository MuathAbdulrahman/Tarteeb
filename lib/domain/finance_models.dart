import '../core/money.dart';

enum TxnType {
  cardPurchase,
  onlinePurchase,
  billPayment,
  refund,
  reversal,
  transferOut,
  transferIn,
  atmWithdrawal,
  bankFee,
  cardPayment,
  income,
  unknown,
}

enum TxnStatus { confirmed, needsReview }

enum TxnSource { sms, manual }

/// Where the transaction timestamp came from.
enum TimestampSource {
  /// Date and time printed in the message.
  message,

  /// Date printed in the message; time of day taken from the SMS.
  messageDateOnly,

  /// No reliable date in the message; SMS received time used as a fallback.
  smsFallback,

  /// Entered by the user.
  manual,
}

TxnType txnTypeFromName(String? s) =>
    TxnType.values.firstWhere((e) => e.name == s, orElse: () => TxnType.unknown);
TxnStatus txnStatusFromName(String? s) =>
    TxnStatus.values.firstWhere((e) => e.name == s, orElse: () => TxnStatus.needsReview);
TxnSource txnSourceFromName(String? s) =>
    TxnSource.values.firstWhere((e) => e.name == s, orElse: () => TxnSource.manual);
TimestampSource tsSourceFromName(String? s) =>
    TimestampSource.values.firstWhere((e) => e.name == s, orElse: () => TimestampSource.smsFallback);

/// Default accounting rule: does a type count as spending?
/// Purchases, bill payments and standalone fees do. Transfers, ATM
/// withdrawals, card bill payments (which would double-count purchases),
/// income, refunds and unknown items do not.
bool typeCountsAsExpense(TxnType t) {
  switch (t) {
    case TxnType.cardPurchase:
    case TxnType.onlinePurchase:
    case TxnType.billPayment:
    case TxnType.bankFee:
      return true;
    default:
      return false;
  }
}

bool typeIsRefundLike(TxnType t) => t == TxnType.refund || t == TxnType.reversal;

bool typeIsPurchaseLike(TxnType t) =>
    t == TxnType.cardPurchase || t == TxnType.onlinePurchase || t == TxnType.billPayment;

class FinTxn {
  int? id;
  TxnSource source;
  TxnStatus status;
  TxnType type;

  /// Amount in minor units of [currency]; null only for items needing review.
  int? amountMinor;
  String currency;

  /// Reliable SAR equivalent printed in the message for foreign-currency items.
  int? sarAmountMinor;

  /// A fee mentioned separately inside the same message (informational,
  /// not added to spending, to avoid double counting with fee alerts).
  int? feeMinor;
  String merchant;
  int? categoryId;
  String note;

  /// Transaction time in epoch ms.
  int txnAt;
  TimestampSource tsSource;

  /// SMS received time in epoch ms (sms source only).
  int? smsAt;

  /// SMS sender id (bank name), never a full personal number.
  String sender;

  /// Last 4 digits of the card/account only.
  String accountLast4;
  String reference;

  /// 0..100
  int confidence;
  String parserVersion;

  /// Stable id of the source message (hash). Empty for manual entries.
  String sourceKey;

  /// Hash of sender + body, used to recognise the same message delivered twice.
  String bodyKey;

  /// Normalized fingerprint used for cross-message duplicate detection.
  String fingerprint;
  int? duplicateOfId;
  int? linkedTxnId;
  bool userEdited;

  /// null = use type default; true/false = user override of "counts as spending".
  bool? countOverride;
  String reviewReason;

  /// Redacted message excerpt, kept only while the item needs review.
  String excerpt;

  /// Comma-separated candidate amounts (minor units) when ambiguous.
  String candidates;
  int createdAt;
  int updatedAt;

  FinTxn({
    this.id,
    required this.source,
    required this.status,
    required this.type,
    this.amountMinor,
    this.currency = kDefaultCurrency,
    this.sarAmountMinor,
    this.feeMinor,
    this.merchant = '',
    this.categoryId,
    this.note = '',
    required this.txnAt,
    required this.tsSource,
    this.smsAt,
    this.sender = '',
    this.accountLast4 = '',
    this.reference = '',
    this.confidence = 100,
    this.parserVersion = '',
    this.sourceKey = '',
    this.bodyKey = '',
    this.fingerprint = '',
    this.duplicateOfId,
    this.linkedTxnId,
    this.userEdited = false,
    this.countOverride,
    this.reviewReason = '',
    this.excerpt = '',
    this.candidates = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get countsAsExpense => countOverride ?? typeCountsAsExpense(type);

  /// Currency + amount used for totals: the SAR equivalent when available.
  String get effectiveCurrency =>
      (currency != kDefaultCurrency && sarAmountMinor != null) ? kDefaultCurrency : currency;
  int? get effectiveAmount =>
      (currency != kDefaultCurrency && sarAmountMinor != null) ? sarAmountMinor : amountMinor;

  List<int> get candidateAmounts => candidates.isEmpty
      ? const []
      : candidates.split(',').map((e) => int.tryParse(e)).whereType<int>().toList();

  Map<String, Object?> toMap() => {
        'id': id,
        'source': source.name,
        'status': status.name,
        'type': type.name,
        'amount_minor': amountMinor,
        'currency': currency,
        'sar_amount_minor': sarAmountMinor,
        'fee_minor': feeMinor,
        'merchant': merchant,
        'category_id': categoryId,
        'note': note,
        'txn_at': txnAt,
        'ts_source': tsSource.name,
        'sms_at': smsAt,
        'sender': sender,
        'account_last4': accountLast4,
        'reference': reference,
        'confidence': confidence,
        'parser_version': parserVersion,
        'source_key': sourceKey,
        'body_key': bodyKey,
        'fingerprint': fingerprint,
        'duplicate_of_id': duplicateOfId,
        'linked_txn_id': linkedTxnId,
        'user_edited': userEdited ? 1 : 0,
        'count_override': countOverride == null ? null : (countOverride! ? 1 : 0),
        'review_reason': reviewReason,
        'excerpt': excerpt,
        'candidates': candidates,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory FinTxn.fromMap(Map<String, Object?> m) => FinTxn(
        id: m['id'] as int?,
        source: txnSourceFromName(m['source'] as String?),
        status: txnStatusFromName(m['status'] as String?),
        type: txnTypeFromName(m['type'] as String?),
        amountMinor: m['amount_minor'] as int?,
        currency: (m['currency'] as String?) ?? kDefaultCurrency,
        sarAmountMinor: m['sar_amount_minor'] as int?,
        feeMinor: m['fee_minor'] as int?,
        merchant: (m['merchant'] as String?) ?? '',
        categoryId: m['category_id'] as int?,
        note: (m['note'] as String?) ?? '',
        txnAt: m['txn_at'] as int,
        tsSource: tsSourceFromName(m['ts_source'] as String?),
        smsAt: m['sms_at'] as int?,
        sender: (m['sender'] as String?) ?? '',
        accountLast4: (m['account_last4'] as String?) ?? '',
        reference: (m['reference'] as String?) ?? '',
        confidence: (m['confidence'] as int?) ?? 100,
        parserVersion: (m['parser_version'] as String?) ?? '',
        sourceKey: (m['source_key'] as String?) ?? '',
        bodyKey: (m['body_key'] as String?) ?? '',
        fingerprint: (m['fingerprint'] as String?) ?? '',
        duplicateOfId: m['duplicate_of_id'] as int?,
        linkedTxnId: m['linked_txn_id'] as int?,
        userEdited: ((m['user_edited'] as int?) ?? 0) == 1,
        countOverride: m['count_override'] == null ? null : (m['count_override'] as int) == 1,
        reviewReason: (m['review_reason'] as String?) ?? '',
        excerpt: (m['excerpt'] as String?) ?? '',
        candidates: (m['candidates'] as String?) ?? '',
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  FinTxn copy() => FinTxn.fromMap(toMap());
}

class ExpenseCategory {
  int? id;
  String? nameKey;
  String? name;
  String icon;
  int color;
  int sortOrder;

  ExpenseCategory({this.id, this.nameKey, this.name, required this.icon, required this.color, required this.sortOrder});

  Map<String, Object?> toMap() =>
      {'id': id, 'name_key': nameKey, 'name': name, 'icon': icon, 'color': color, 'sort_order': sortOrder};

  factory ExpenseCategory.fromMap(Map<String, Object?> m) => ExpenseCategory(
        id: m['id'] as int?,
        nameKey: m['name_key'] as String?,
        name: m['name'] as String?,
        icon: (m['icon'] as String?) ?? 'other',
        color: m['color'] as int,
        sortOrder: (m['sort_order'] as int?) ?? 0,
      );
}

/// "When the merchant contains [pattern], use [categoryId]".
class MerchantRule {
  int? id;
  String pattern;
  int categoryId;

  MerchantRule({this.id, required this.pattern, required this.categoryId});

  Map<String, Object?> toMap() => {'id': id, 'pattern': pattern, 'category_id': categoryId};

  factory MerchantRule.fromMap(Map<String, Object?> m) =>
      MerchantRule(id: m['id'] as int?, pattern: m['pattern'] as String, categoryId: m['category_id'] as int);
}
