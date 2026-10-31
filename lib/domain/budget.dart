import 'dart:math';

enum BudgetLevel { under, near, over }

/// override(month) ?? default (SPEC 5.5). The null key holds the default.
int? resolveAmount(Map<String?, int> amounts, String month) =>
    amounts[month] ?? amounts[null];

/// Sums (category id, paise) debits per category; null is uncategorised.
Map<int?, int> spendByCategory(Iterable<(int?, int)> debits) {
  final spend = <int?, int>{};
  for (final (category, paise) in debits) {
    spend[category] = (spend[category] ?? 0) + paise;
  }
  return spend;
}

int sumPaise(Iterable<int> amounts) => amounts.fold(0, (a, b) => a + b);

/// Green below 70%, amber from 70% to 100%, red above (SPEC 5.7). In integers,
/// so an amount exactly on a boundary cannot land on the wrong side.
BudgetLevel budgetLevel(int spent, int limit) {
  if (spent > limit) return BudgetLevel.over;
  return spent * 100 < limit * 70 || spent == 0
      ? BudgetLevel.under
      : BudgetLevel.near;
}

/// How full to draw a bar, from 0 to 1. Spending against a zero limit is full.
double spentFraction(int spent, int limit) {
  if (limit <= 0) return spent > 0 ? 1 : 0;
  return min(spent / limit, 1);
}
