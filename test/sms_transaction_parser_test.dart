import 'package:flutter_test/flutter_test.dart';
import 'package:paysense/shared/utils/sms_transaction_parser.dart';

void main() {
  final now = DateTime(2026, 8, 12, 10, 30);

  group('SmsTransactionParser.parse', () {
    test('1. debit SMS is parsed as a debit with the correct amount', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 500 debited from A/c XX1234 at AMAZON on 12-08-26',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.direction, SmsTransactionDirection.debit);
      expect(result.amount, 500);
      expect(result.isHighConfidence, isTrue);
    });

    test('2. credit SMS is parsed as a credit with the correct amount', () {
      final result = SmsTransactionParser.parse(
        sender: 'ICICIB',
        body: 'Rs. 50,000 credited to your account',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.direction, SmsTransactionDirection.credit);
      expect(result.amount, 50000);
    });

    test('3. UPI payment SMS is parsed as a debit', () {
      final result = SmsTransactionParser.parse(
        sender: 'PAYTM',
        body: 'You have paid Rs.250 to XYZ Store via UPI',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.direction, SmsTransactionDirection.debit);
      expect(result.amount, 250);
    });

    test('4. ATM withdrawal SMS is parsed as a debit', () {
      final result = SmsTransactionParser.parse(
        sender: 'SBIBNK',
        body: 'Rs. 2,000 withdrawn from ATM XX99',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.direction, SmsTransactionDirection.debit);
      expect(result.amount, 2000);
    });

    test('5. an unknown/non-financial SMS is ignored', () {
      final result = SmsTransactionParser.parse(
        sender: 'AX-PROMO',
        body: 'Your OTP for login is 482910. Do not share this with anyone.',
        timestamp: now,
      );

      expect(result, isNull);
    });

    test('6. a malformed SMS with no actual amount is ignored, not crashed on', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs debited from account',
        timestamp: now,
      );

      expect(result, isNull);
    });

    test('7. different currency formatting (INR) is parsed', () {
      final result = SmsTransactionParser.parse(
        sender: 'AXISBK',
        body: 'INR 1500.00 debited from your account',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 1500.0);
    });

    test('8. comma-separated (Indian-style) amounts are parsed', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 1,25,000 credited to A/c XX1234',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 125000);
    });

    test('9. decimal amounts are parsed precisely', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 499.99 debited at STARBUCKS',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 499.99);
    });

    test('10. the same SMS parsed twice produces the same fingerprint', () {
      const sender = 'HDFCBK';
      const body = 'Rs. 500 debited from A/c XX1234 at AMAZON';
      final first = SmsTransactionParser.parse(sender: sender, body: body, timestamp: now);
      final second = SmsTransactionParser.parse(sender: sender, body: body, timestamp: now);

      expect(first!.fingerprint, second!.fingerprint);
    });

    test('11. the same message with a different timestamp produces a different fingerprint', () {
      const sender = 'HDFCBK';
      const body = 'Rs. 500 debited from A/c XX1234 at AMAZON';
      final first = SmsTransactionParser.parse(sender: sender, body: body, timestamp: now);
      final second = SmsTransactionParser.parse(
        sender: sender,
        body: body,
        timestamp: now.add(const Duration(days: 1)),
      );

      expect(first!.fingerprint, isNot(second!.fingerprint));
    });

    test('12. the sender is preserved on the parsed result', () {
      final result = SmsTransactionParser.parse(
        sender: '  HDFCBK  ',
        body: 'Rs. 500 debited from A/c XX1234',
        timestamp: now,
      );

      expect(result!.sender, 'HDFCBK');
    });

    test('13a. merchant is extracted where available', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 500 debited from A/c XX1234 at AMAZON on 12-08-26',
        timestamp: now,
      );

      expect(result!.merchant, 'AMAZON');
    });

    test('13b. merchant is null (not fabricated) when none is identifiable', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 500 debited from A/c XX1234',
        timestamp: now,
      );

      expect(result!.merchant, isNull);
    });

    test('14. a transfer-like SMS is flagged, not auto-classified confidently', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 5000 transferred to your own account XX5678',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.isLikelyTransfer, isTrue);
      expect(result.isHighConfidence, isFalse);
    });

    test('15. a low-confidence SMS is surfaced but not high-confidence', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 500 on your account. Reply STOP to opt out.',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.isHighConfidence, isFalse);
    });

    test('16. an empty SMS body is ignored, not crashed on', () {
      final result = SmsTransactionParser.parse(sender: 'HDFCBK', body: '', timestamp: now);

      expect(result, isNull);
    });

    test('17. a non-financial promotional SMS mentioning a price is ignored', () {
      final result = SmsTransactionParser.parse(
        sender: 'AX-PROMO',
        body: 'Flat Rs.500 OFF on your next order! Shop now.',
        timestamp: now,
      );

      expect(result, isNull);
    });

    test('18. a card-usage SMS ("used") is parsed as a debit', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Card ending 1234 used for Rs. 1,500 at BIGBAZAAR',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.direction, SmsTransactionDirection.debit);
      expect(result.amount, 1500);
      expect(result.isHighConfidence, isTrue);
    });

    test('19. a loosely-worded UPI SMS with no explicit direction verb is still surfaced', () {
      final result = SmsTransactionParser.parse(
        sender: 'UPI-PAYTM',
        body: 'UPI transaction of Rs. 250 on your account',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.amount, 250);
      // No clear debit/credit verb — surfaced for review, never auto-added.
      expect(result.isHighConfidence, isFalse);
    });

    test('an ambiguous SMS with both debit and credit keywords scores low confidence', () {
      final result = SmsTransactionParser.parse(
        sender: 'HDFCBK',
        body: 'Rs. 500 debited for a refund that was credited earlier',
        timestamp: now,
      );

      expect(result, isNotNull);
      expect(result!.isHighConfidence, isFalse);
    });
  });

  group('SmsTransactionParser.buildFingerprint', () {
    test('never depends on message text alone — different sender changes it', () {
      const body = 'rs. 500 debited from a/c xx1234';
      final a = SmsTransactionParser.buildFingerprint(
        sender: 'HDFCBK',
        timestamp: now,
        normalizedBody: body,
      );
      final b = SmsTransactionParser.buildFingerprint(
        sender: 'ICICIB',
        timestamp: now,
        normalizedBody: body,
      );

      expect(a, isNot(b));
    });
  });
}
