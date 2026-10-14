// Synthetic SMS fixtures only. No real banking data.
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteeb/domain/finance_models.dart';
import 'package:tarteeb/sms/normalizer.dart';
import 'package:tarteeb/sms/sms_parser.dart';

final parser = SmsParser();
final smsTime = DateTime(2024, 10, 12, 14, 31).millisecondsSinceEpoch;

ParseOutcome p(String body, {String sender = 'TestBank', int? at}) =>
    parser.parse(RawSms(sender: sender, body: body, receivedAt: at ?? smsTime, sentAt: at ?? smsTime));

ParsedTxn txn(String body) {
  final o = p(body);
  expect(o.isTransaction, isTrue, reason: 'expected a transaction, got ${o.ignored}');
  return o.txn!;
}

void main() {
  group('normalizer', () {
    test('Arabic-Indic digits and separators become Western, lengths stay aligned', () {
      final n = normalizeSms('مبلغ ١٬٢٥٠٫٧٥ ر.س');
      expect(n.text, 'مبلغ 1,250.75 ر.س');
      expect(n.match.length, n.text.length);
    });

    test('Persian digits, tatweel, diacritics and bidi marks', () {
      final n = normalizeSms('شـــراء \u200fبمبلغٍ ۴۵ ريالاً');
      expect(n.text, 'شراء بمبلغ 45 ريالا');
    });

    test('folding for matching', () {
      expect(foldString('إيداع أموال مدى ة'), 'ايداع اموال مدي ه');
    });
  });

  group('purchases', () {
    test('Arabic point-of-sale purchase with card, merchant, date and time', () {
      final t = txn('شراء عبر نقاط البيع\nبطاقة: 1234;مدى-أبل باي\nمبلغ: 45.50 SAR\nلدى: مقهى الورد\nفي: 24-10-12 14:30');
      expect(t.type, TxnType.cardPurchase);
      expect(t.amountMinor, 4550);
      expect(t.currency, 'SAR');
      expect(t.merchant, 'مقهى الورد');
      expect(t.accountLast4, '1234');
      expect(t.tsSource, TimestampSource.message);
      expect(t.txnAt, DateTime(2024, 10, 12, 14, 30).millisecondsSinceEpoch);
      expect(t.needsReview, isFalse);
    });

    test('English purchase ignores the available balance', () {
      final t = txn('Purchase of SAR 120.00 at STARBUCKS RIYADH using card **4321 on 12/10/2024 09:15. '
          'Available balance: SAR 3,450.75');
      expect(t.type, TxnType.cardPurchase);
      expect(t.amountMinor, 12000);
      expect(t.merchant, 'STARBUCKS RIYADH');
      expect(t.accountLast4, '4321');
      expect(t.txnAt, DateTime(2024, 10, 12, 9, 15).millisecondsSinceEpoch);
    });

    test('does not take the first number when it is a balance', () {
      final t = txn('Balance SAR 5,000.00 after purchase of SAR 200.00 at JARIR');
      expect(t.amountMinor, 20000);
    });

    test('Arabic-Indic amount with Arabic separators', () {
      final t = txn('شراء بقيمة ١٬٢٥٠٫٧٥ ر.س لدى مكتبة جرير');
      expect(t.amountMinor, 125075);
      expect(t.currency, 'SAR');
      expect(t.merchant, 'مكتبة جرير');
    });

    test('amount without currency is assumed SAR and flagged', () {
      final t = txn('شراء بطاقة مدى\nالمبلغ: 35.00\nالتاجر: صيدلية النهدي');
      expect(t.amountMinor, 3500);
      expect(t.currency, 'SAR');
      expect(t.currencyAssumed, isTrue);
      expect(t.merchant, 'صيدلية النهدي');
      expect(t.confidence, lessThan(100));
    });

    test('online purchase in foreign currency keeps the SAR equivalent separately', () {
      final t = txn('Online purchase: USD 25.99 at NETFLIX.COM (SAR 97.46) card *1111 on 2024-10-11 22:10');
      expect(t.type, TxnType.onlinePurchase);
      expect(t.currency, 'USD');
      expect(t.amountMinor, 2599);
      expect(t.sarAmountMinor, 9746);
      expect(t.merchant, 'NETFLIX.COM');
      expect(t.accountLast4, '1111');
    });

    test('Arabic international purchase with "equivalent" line', () {
      final t = txn('عملية شراء دولية\nبطاقة ائتمانية: **2468\nمن: AMAZON.COM\nمبلغ: 59.99 USD\n'
          'بما يعادل: 225.10 SAR\nفي: 2024/10/11 18:45');
      expect(t.type, TxnType.cardPurchase);
      expect(t.currency, 'USD');
      expect(t.amountMinor, 5999);
      expect(t.sarAmountMinor, 22510);
      expect(t.merchant, 'AMAZON.COM');
      expect(t.accountLast4, '2468');
    });

    test('several transaction amounts -> needs review with candidates', () {
      final t = txn('Purchase amount SAR 30.00, amount SAR 45.00 at STORE');
      expect(t.amountMinor, isNull);
      expect(t.needsReview, isTrue);
      expect(t.reviewReasons, contains(ReviewReason.ambiguousAmount));
      expect(t.candidates, containsAll([3000, 4500]));
    });

    test('three-decimal currency', () {
      final t = txn('Purchase of KWD 12.250 at AVENUES');
      expect(t.currency, 'KWD');
      expect(t.amountMinor, 12250);
    });
  });

  group('other transaction types', () {
    test('refund (Arabic)', () {
      final t = txn('تم استرداد مبلغ ٧٥٫٠٠ ريال من متجر نون إلى بطاقتك المنتهية ب 9876');
      expect(t.type, TxnType.refund);
      expect(t.amountMinor, 7500);
      expect(t.merchant, 'نون');
      expect(t.accountLast4, '9876');
    });

    test('reversal', () {
      final t = txn('Reversal: SAR 120.00 at STARBUCKS RIYADH has been credited to your card **4321');
      expect(t.type, TxnType.reversal);
      expect(t.amountMinor, 12000);
    });

    test('outgoing transfer with a separately stated fee', () {
      final t = txn('Outgoing transfer of SAR 500.00 to AHMED ALI. Fee SAR 0.58. Balance SAR 2,000.00');
      expect(t.type, TxnType.transferOut);
      expect(t.amountMinor, 50000);
      expect(t.feeMinor, 58);
      expect(t.merchant, 'AHMED ALI');
    });

    test('incoming transfer (Arabic)', () {
      final t = txn('حوالة واردة من محمد بمبلغ 1,000.00 ريال إلى حسابك ***321');
      expect(t.type, TxnType.transferIn);
      expect(t.amountMinor, 100000);
      expect(t.merchant, 'محمد');
      expect(t.accountLast4, '321');
    });

    test('ATM withdrawal ignores balance', () {
      final t = txn('سحب نقدي من الصراف بمبلغ 300 ريال بطاقة مدى ****5555 الرصيد 1200 ريال');
      expect(t.type, TxnType.atmWithdrawal);
      expect(t.amountMinor, 30000);
      expect(t.accountLast4, '5555');
    });

    test('credit card bill payment', () {
      final t = txn('Payment of SAR 2,500.00 received for your credit card ending 7788. Thank you.');
      expect(t.type, TxnType.cardPayment);
      expect(t.amountMinor, 250000);
      expect(t.accountLast4, '7788');
    });

    test('standalone bank fee', () {
      final t = txn('تم خصم رسوم إصدار بطاقة بمبلغ 23 ريال من حسابك');
      expect(t.type, TxnType.bankFee);
      expect(t.amountMinor, 2300);
    });

    test('salary is income', () {
      final t = txn('Salary of SAR 15,000.00 has been credited to your account 1234567890');
      expect(t.type, TxnType.income);
      expect(t.amountMinor, 1500000);
    });

    test('bill payment', () {
      final t = txn('تم سداد فاتورة الكهرباء بمبلغ 230.40 ريال');
      expect(t.type, TxnType.billPayment);
      expect(t.amountMinor, 23040);
    });

    test('generic debit is not assumed to be a purchase', () {
      final t = txn('SAR 75.00 debited from your account');
      expect(t.type, TxnType.unknown);
      expect(t.needsReview, isTrue);
    });
  });

  group('ignored messages', () {
    test('OTP with an amount is ignored', () {
      expect(p('رمز التحقق 482913 لعملية شراء بمبلغ 120 ريال لدى أمازون. لا تشارك الرمز').ignored, IgnoreReason.otp);
      expect(p('Your OTP for SAR 50.00 purchase at X is 123456').ignored, IgnoreReason.otp);
    });

    test('declined transaction is ignored', () {
      expect(p('Your card transaction of SAR 89.00 at IKEA was declined due to insufficient funds.').ignored,
          IgnoreReason.declined);
    });

    test('promotion is ignored', () {
      expect(p('استمتع بخصم 20% على مشترياتك من متجر الأزياء حتى 30 ريال').ignored, IgnoreReason.promo);
    });

    test('bill reminder is ignored', () {
      expect(p('تذكير: فاتورة الاتصالات بمبلغ 199 ريال مستحقة السداد بتاريخ 2024-10-20').ignored,
          IgnoreReason.reminder);
    });

    test('balance-only message is ignored', () {
      expect(p('Your account balance is SAR 4,200.00 as of 12/10/2024').ignored, IgnoreReason.balanceOnly);
    });

    test('personal message is ignored', () {
      expect(p('See you at 7, bring 2 chairs').isTransaction, isFalse);
      expect(p('مرحبا، كيف حالك؟').isTransaction, isFalse);
    });
  });

  group('timestamps', () {
    test('no date in message -> SMS time used and marked as fallback', () {
      final t = txn('Purchase of SAR 10.00 at KIOSK');
      expect(t.tsSource, TimestampSource.smsFallback);
      expect(t.txnAt, smsTime);
    });

    test('time only -> SMS day with message time', () {
      final t = txn('Purchase of SAR 10.00 at KIOSK at 13:05');
      expect(t.tsSource, TimestampSource.message);
      expect(t.txnAt, DateTime(2024, 10, 12, 13, 5).millisecondsSinceEpoch);
    });

    test('implausible future date falls back', () {
      final t = txn('Purchase of SAR 10.00 at KIOSK on 2030-01-01');
      expect(t.tsSource, TimestampSource.smsFallback);
    });

    test('12-hour Arabic time suffix', () {
      final t = txn('شراء بمبلغ 10 ريال لدى بقالة الحي 2024-10-12 02:15 م');
      expect(t.txnAt, DateTime(2024, 10, 12, 14, 15).millisecondsSinceEpoch);
    });
  });

  group('privacy helpers', () {
    test('redaction hides long digit runs and card digits but keeps amounts', () {
      final r = redactExcerpt('Card 4321 acct 1234567890 SAR 50.00', last4: '4321');
      expect(r.contains('4321'), isFalse);
      expect(r.contains('1234567890'), isFalse);
      expect(r.contains('50'), isTrue);
    });

    test('phone-number senders are masked', () {
      expect(displaySender('+966501234567'), '•••567');
      expect(displaySender('AlRajhiBank'), 'AlRajhiBank');
    });
  });
}
