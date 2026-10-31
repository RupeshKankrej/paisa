import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/money.dart';

void main() {
  group('format', () {
    for (final (paise, expected) in [
      (0, '₹0.00'),
      (5, '₹0.05'),
      (12000, '₹120.00'),
      (99999, '₹999.99'),
      (100000, '₹1,000.00'),
      (9999900, '₹99,999.00'),
      (15545300, '₹1,55,453.00'),
      (1234567890, '₹1,23,45,678.90'),
      (-15545300, '-₹1,55,453.00'),
    ]) {
      test('$paise', () => expect(Money.format(paise), expected));
    }
  });

  group('tryParse', () {
    for (final (text, expected) in [
      ('120', 12000),
      ('120.', 12000),
      ('120.5', 12050),
      ('120.05', 12005),
      ('.5', 50),
      ('1,55,453.00', 15545300),
      (' 0.07 ', 7),
      // 19.99 * 100 is 1998.9999999999998 as a double.
      ('19.99', 1999),
      ('', null),
      ('.', null),
      (',', null),
      ('1.234', null),
      ('-5', null),
      ('abc', null),
      ('1.2.3', null),
    ]) {
      test('"$text"', () => expect(Money.tryParse(text), expected));
    }

    test('an amount too large for int paise is rejected, not thrown', () {
      expect(Money.tryParse('9' * 30), isNull);
      expect(Money.tryParse('9' * 15), 99999999999999900);
    });
  });

  group('keypad', () {
    String typed(String keys) => keys.split('').fold('', Money.keypadPress);

    test('builds amounts Money can parse', () {
      expect(typed('1250.5'), '1250.5');
      expect(Money.tryParse(typed('1250.5')), 125050);
      expect(typed('.5'), '0.5');
    });

    test('ignores presses that would make the amount invalid', () {
      expect(typed('1.234'), '1.23');
      expect(typed('1..2'), '1.2');
      expect(typed('0005'), '5');
      expect(typed('1' * 20), '1' * 15);
    });

    test('edits start without a zero fraction', () {
      expect(Money.keypadText(12000), '120');
      expect(Money.keypadText(12050), '120.50');
      expect(Money.keypadText(15545300), '155453');
    });

    test('displays as typed with Indian grouping', () {
      expect(Money.keypadDisplay(''), '₹0');
      expect(Money.keypadDisplay('155453'), '₹1,55,453');
      expect(Money.keypadDisplay('1250.'), '₹1,250.');
      expect(Money.keypadDisplay('1250.5'), '₹1,250.5');
    });
  });
}
