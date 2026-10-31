import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/domain/parser/parser.dart';

const debitSample =
    'Sent Rs.120.00 From HDFC Bank A/C *2703 To MAHESHWARI ENTERPRISES '
    'On 30/10/26 Ref 630329677868';
const creditSample =
    'Update! INR 1,55,453.00 deposited in HDFC Bank A/c XX2703 on 28-OCT-26 '
    'for NEFT Cr-HSBC0560002-DEEL EOR PRIVATE LIMITED-RUPESH KANKREJ-'
    'HSBCN30100693396.Avl bal INR 2,44,485.78.';

void main() {
  group('golden messages', () {
    test('HDFC UPI debit', () {
      final parsed = parseMessage(debitSample, Bank.hdfc)!;
      expect(parsed.type, TransactionType.debit);
      expect(parsed.amountPaise, 12000);
      expect(parsed.accountLast4, '2703');
      expect(parsed.counterparty, 'MAHESHWARI ENTERPRISES');
      expect(parsed.date, DateTime(2026, 10, 30));
      expect(parsed.refNo, '630329677868');
    });

    test('HDFC credit keeps the whole descriptor and has no ref', () {
      final parsed = parseMessage(creditSample, Bank.hdfc)!;
      expect(parsed.type, TransactionType.credit);
      expect(parsed.amountPaise, 15545300);
      expect(parsed.accountLast4, '2703');
      expect(
        parsed.counterparty,
        'NEFT Cr-HSBC0560002-DEEL EOR PRIVATE LIMITED-RUPESH KANKREJ-'
        'HSBCN30100693396',
      );
      expect(parsed.date, DateTime(2026, 10, 28));
      expect(parsed.refNo, isNull);
    });
  });

  test('the debit as it arrives on several lines parses once normalised', () {
    final message = normaliseMessage(
      'Sent Rs.120.00\nFrom HDFC Bank A/C *2703\nTo ON THE GO\n'
      'On 30/10/26\nRef 630329677868\nNot You?\nCall 18002586161',
    );
    final parsed = parseMessage(message, Bank.hdfc)!;
    expect(parsed.counterparty, 'ON THE GO');
    expect(parsed.refNo, '630329677868');
  });

  test('other text, and impossible amounts or dates, do not parse', () {
    expect(parseMessage('Your HDFC Bank OTP is 123456', Bank.hdfc), isNull);
    expect(
      parseMessage(debitSample.replaceFirst('30/10/26', '31/02/26'), Bank.hdfc),
      isNull,
    );
    expect(
      parseMessage(debitSample.replaceFirst('120.00', '120.001'), Bank.hdfc),
      isNull,
    );
  });

  group('parseMessageDate', () {
    test('all three formats, two-digit years as 20YY', () {
      expect(parseMessageDate('30/10/26'), DateTime(2026, 10, 30));
      expect(parseMessageDate('28-OCT-26'), DateTime(2026, 10, 28));
      expect(parseMessageDate('28-oct-26'), DateTime(2026, 10, 28));
      expect(parseMessageDate('05-01-27'), DateTime(2027, 1, 5));
    });

    test('dates that do not exist are null', () {
      for (final bad in ['31/02/26', '00/10/26', '10/13/26', '10-XXX-26']) {
        expect(parseMessageDate(bad), isNull, reason: bad);
      }
    });
  });

  test('fingerprint ignores whitespace differences only', () {
    final fingerprint = fingerprintOf(normaliseMessage(' a \n  b\t'));
    expect(fingerprint, fingerprintOf(normaliseMessage('a b')));
    expect(fingerprint, isNot(fingerprintOf(normaliseMessage('a c'))));
    // SHA-256 of "abc", so the fingerprint stays stable across releases.
    expect(
      fingerprintOf('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
