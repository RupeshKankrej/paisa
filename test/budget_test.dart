import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/domain/budget.dart';

void main() {
  test('an override wins, including zero, then the default, then nothing', () {
    const amounts = {null: 100, '2026-10': 50, '2026-11': 0};
    expect(resolveAmount(amounts, '2026-10'), 50);
    expect(resolveAmount(amounts, '2026-11'), 0);
    expect(resolveAmount(amounts, '2026-12'), 100);
    expect(resolveAmount(const {'2026-10': 50}, '2026-12'), isNull);
  });

  test('spend adds up per category, with null as uncategorised', () {
    final spend = spendByCategory(const [(1, 100), (null, 30), (1, 20)]);
    expect(spend, {1: 120, null: 30});
    expect(sumPaise(spend.values), 150);
  });

  test('levels change at exactly 70% and above 100%', () {
    expect(budgetLevel(6999, 10000), BudgetLevel.under);
    expect(budgetLevel(7000, 10000), BudgetLevel.near);
    expect(budgetLevel(10000, 10000), BudgetLevel.near);
    expect(budgetLevel(10001, 10000), BudgetLevel.over);
    expect(budgetLevel(0, 0), BudgetLevel.under);
    expect(budgetLevel(1, 0), BudgetLevel.over);
  });

  test('the bar is capped at full', () {
    expect(spentFraction(50, 100), 0.5);
    expect(spentFraction(300, 100), 1);
    expect(spentFraction(0, 0), 0);
    expect(spentFraction(1, 0), 1);
  });

  test('totals count entries per category, including uncategorised', () {
    expect(totalsByCategory(const [(1, 100), (null, 50), (1, 25)]), {
      1: (count: 2, paise: 125),
      null: (count: 1, paise: 50),
    });
  });

  test('percent labels round to two decimals in integers', () {
    expect(percentLabel(5272200, 13512200), '39.02%');
    expect(percentLabel(1, 3), '33.33%');
    expect(percentLabel(2, 3), '66.67%');
    expect(percentLabel(5, 5), '100.00%');
    expect(percentLabel(0, 0), '0.00%');
  });

  group('limit edits', () {
    const amounts = {null: 5000, '2026-11': 3000};
    test('an override falls back to the default when blank', () {
      expect(limitAfterEdit(amounts, (paise: 100, everyMonth: false)), 100);
      expect(limitAfterEdit(amounts, (paise: null, everyMonth: false)), 5000);
    });
    test('every month replaces both, blank removes the limit', () {
      expect(limitAfterEdit(amounts, (paise: 100, everyMonth: true)), 100);
      expect(limitAfterEdit(amounts, (paise: null, everyMonth: true)), isNull);
    });
    test('exactly the salary saves, one paisa more does not', () {
      bool can(int paise) =>
          canSaveLimit(10000, 4000, paise, (paise: paise, everyMonth: true));
      expect(can(6000), isTrue);
      expect(can(6001), isFalse);
      expect(budgetLeft(10000, 4000, 7000), -1000);
    });
    test('blank can always save, so an overspent limit can be removed', () {
      expect(
        canSaveLimit(1000, 4000, null, (paise: null, everyMonth: true)),
        isTrue,
      );
    });
    test('no salary means no cap', () {
      expect(
        canSaveLimit(null, 4000, 9000, (paise: 9000, everyMonth: true)),
        isTrue,
      );
    });
  });

  test('wholePercentLabel rounds and survives no salary', () {
    expect(wholePercentLabel(10000, 100000), '10%');
    expect(wholePercentLabel(1, 3), '33%');
    expect(wholePercentLabel(5, 0), '0%');
  });
}
