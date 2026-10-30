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
  });
}
