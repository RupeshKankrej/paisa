import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/domain/row_title.dart';

void main() {
  const debit = TransactionType.debit;

  test('name wins over note and category', () {
    expect(
      rowTitle(name: 'Lunch', note: 'SHOP', categoryName: 'Food', type: debit),
      'Lunch',
    );
  });

  test('blank name falls back to note, then category, then type', () {
    expect(rowTitle(name: '  ', note: 'SHOP', type: debit), 'SHOP');
    expect(rowTitle(note: '', categoryName: 'Food', type: debit), 'Food');
    expect(rowTitle(type: debit), 'Expense');
    expect(rowTitle(type: TransactionType.credit), 'Income');
  });

  test('one line, first 40 characters', () {
    expect(rowTitle(note: 'first\nsecond', type: debit), 'first');
    expect(rowTitle(note: 'x' * 50, type: debit), 'x' * 40);
  });
}
