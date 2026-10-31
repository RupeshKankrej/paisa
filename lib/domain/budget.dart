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

/// Entry count and total per category, from (category id, paise) entries.
Map<int?, ({int count, int paise})> totalsByCategory(
  Iterable<(int?, int)> entries,
) {
  final totals = <int?, ({int count, int paise})>{};
  for (final (category, paise) in entries) {
    final total = totals[category];
    totals[category] = (
      count: (total?.count ?? 0) + 1,
      paise: (total?.paise ?? 0) + paise,
    );
  }
  return totals;
}

/// '39.02%'. Rounded from integers, so it cannot pick up float noise.
String percentLabel(int part, int total) {
  final hundredths = total <= 0 ? 0 : (part * 10000 + total ~/ 2) ~/ total;
  final fraction = (hundredths % 100).toString().padLeft(2, '0');
  return '${hundredths ~/ 100}.$fraction%';
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

/// One typed limit: [paise] null is a blank amount, and [everyMonth] picks the
/// default rather than the selected period's override (SPEC 5.5).
typedef LimitEdit = ({int? paise, bool everyMonth});

/// What the period's limit becomes. Saving for every month also clears that
/// period's override, and a blank override falls back to the default.
int? limitAfterEdit(Map<String?, int> amounts, LimitEdit edit) =>
    edit.everyMonth ? edit.paise : edit.paise ?? amounts[null];

/// Salary less every limit, including this one as typed (SPEC 5.16).
int budgetLeft(int salary, int otherLimits, int? limit) =>
    salary - otherLimits - (limit ?? 0);

/// A negative amount left blocks saving. Blank stays allowed, so limits already
/// past a lowered salary can still be removed. No salary means no cap.
bool canSaveLimit(int? salary, int otherLimits, int? limit, LimitEdit edit) =>
    edit.paise == null ||
    salary == null ||
    budgetLeft(salary, otherLimits, limit) >= 0;

/// '10%' for the Allocate sheet. Zero when there is no total to share.
String wholePercentLabel(int part, int total) =>
    total <= 0 ? '0%' : '${(part * 100 + total ~/ 2) ~/ total}%';
