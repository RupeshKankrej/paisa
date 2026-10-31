import 'dart:math';

import '../core/month_key.dart';
import '../core/period.dart';
import 'budget.dart';
import 'models.dart';

typedef MonthTotal = ({String key, int spent, int income});
typedef Bucket = ({DateTime start, int paise});

/// One total per period, oldest first: at least the last 12 up to [now],
/// stretched to cover every (date, type, paise) entry (SPEC 5.8, 5.11).
List<MonthTotal> monthTotals(
  Iterable<(DateTime, TransactionType, int)> entries,
  int? salaryDay,
  DateTime now,
) {
  final current = Period.containing(now, salaryDay).key;
  final spent = <String, int>{};
  final income = <String, int>{};
  for (final (date, type, paise) in entries) {
    final totals = type == TransactionType.debit ? spent : income;
    final key = Period.containing(date, salaryDay).key;
    totals[key] = (totals[key] ?? 0) + paise;
  }
  final keys = [
    current,
    MonthKey.shift(current, -11),
    ...spent.keys,
    ...income.keys,
  ]..sort();
  return [
    for (final key in MonthKey.range(keys.first, keys.last))
      (key: key, spent: spent[key] ?? 0, income: income[key] ?? 0),
  ];
}

/// One bucket per day from [start] up to the exclusive [end], zero when there
/// was no spend. (date, paise) debits outside that span are left out.
List<Bucket> dailySpend(
  Iterable<(DateTime, int)> debits,
  DateTime start,
  DateTime end,
) {
  final spend = <DateTime, int>{};
  for (final (date, paise) in debits) {
    final day = DateTime(date.year, date.month, date.day);
    spend[day] = (spend[day] ?? 0) + paise;
  }
  return [
    // Built from day numbers, not by adding 24 hours, to be safe across DST.
    for (
      var day = DateTime(start.year, start.month, start.day);
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      (start: day, paise: spend[day] ?? 0),
  ];
}

/// Sums [days] in sevens from the first; the last week may be short.
List<Bucket> weeklySpend(List<Bucket> days) => [
  for (var i = 0; i < days.length; i += 7)
    (
      start: days[i].start,
      paise: sumPaise(days.skip(i).take(7).map((d) => d.paise)),
    ),
];

/// Ranges longer than this are drawn by week (SPEC 5.8).
const maxDailyRange = 90;

/// Spend per day, ignoring days after [now] so a month in progress is not
/// understated. A period wholly in the future counts all its days.
int dailyAverage(List<Bucket> days, DateTime now) {
  if (days.isEmpty) return 0;
  final elapsed = days.where((d) => !d.start.isAfter(now)).length;
  final total = sumPaise(days.map((d) => d.paise));
  return (total / (elapsed == 0 ? days.length : elapsed)).round();
}

enum SliceKind { category, unallocated, uncategorised }

class PieSlice {
  const PieSlice(this.kind, this.size, this.spent, {this.categoryId});

  final SliceKind kind;
  final int? categoryId;

  /// The slice's share of the pie: the limit, for a category.
  final int size;
  final int spent;

  /// The part drawn at dark opacity; the rest of [size] is light.
  int get dark => min(spent, size);
  int get light => size - dark;
  bool get over => spent > size;
}

class BudgetPie {
  const BudgetPie(this.slices, this.overSalaryBy, this.salaryRing);

  final List<PieSlice> slices;

  /// Zero unless total spend exceeds the salary.
  final int overSalaryBy;

  /// Radius of the salary ring as a fraction of the pie's; null without a ring.
  /// The pie's area stands for total spend, so this is a square root.
  final double? salaryRing;

  bool get isEmpty => slices.every((s) => s.size == 0);
}

/// SPEC 5.8. [limits] holds the resolved limit of each category that has one,
/// in display order. [spend] includes categories with no limit, which have no
/// slice but do count towards the total.
BudgetPie budgetPie(Map<int, int> limits, Map<int?, int> spend, int? salary) {
  final unallocated = salary == null ? 0 : salary - sumPaise(limits.values);
  final uncategorised = spend[null] ?? 0;
  final total = sumPaise(spend.values);
  final over = salary != null && total > salary;
  return BudgetPie(
    [
      for (final MapEntry(key: id, value: limit) in limits.entries)
        PieSlice(SliceKind.category, limit, spend[id] ?? 0, categoryId: id),
      if (unallocated > 0) PieSlice(SliceKind.unallocated, unallocated, 0),
      if (uncategorised > 0)
        PieSlice(SliceKind.uncategorised, uncategorised, uncategorised),
    ],
    over ? total - salary : 0,
    over && salary > 0 ? sqrt(salary / total) : null,
  );
}

const analyticsWindow = 6;

/// The 6 periods shown around [selected], oldest first. Windows count back from
/// [current], so one always ends on it and shifting by 6 moves exactly one
/// window while keeping the selected slot (SPEC 5.17).
List<String> periodWindow(String selected, String current) {
  final back = selected.compareTo(current) >= 0
      ? 0
      : MonthKey.range(selected, current).length - 1;
  final end = MonthKey.shift(
    current,
    -(back ~/ analyticsWindow) * analyticsWindow,
  );
  return MonthKey.range(MonthKey.shift(end, 1 - analyticsWindow), end);
}

/// 'Jan', with the year on the first label of a window crossing one: "Dec '25".
String windowLabel(List<String> keys, int index) {
  final key = keys[index];
  final name = MonthKey.label(key).substring(0, 3);
  final crosses = keys.first.substring(0, 4) != keys.last.substring(0, 4);
  return index == 0 && crosses ? "$name '${key.substring(2, 4)}" : name;
}

/// Share of the period's income left after spending, as a percentage; null when
/// there was no income, where a share has no meaning.
double? incomeLeftPercent(MonthTotal t) =>
    t.income == 0 ? null : (t.income - t.spent) * 100 / t.income;

/// Calendar cell opacity. A square root, so one huge day leaves the others
/// visible; any spend at all is clearly different from a grey zero cell.
double heatLevel(int paise, int most) =>
    most <= 0 ? 0 : 0.3 + 0.7 * sqrt(paise / most);
