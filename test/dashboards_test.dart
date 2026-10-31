import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/money.dart';
import 'package:paisa/domain/dashboards.dart';
import 'package:paisa/domain/models.dart';

void main() {
  group('monthTotals', () {
    final now = DateTime(2026, 10, 31);

    test('splits debits and credits, covering the last 12 months', () {
      final totals = monthTotals(
        [
          (DateTime(2026, 10, 5), TransactionType.debit, 100),
          (DateTime(2026, 10, 6), TransactionType.debit, 50),
          (DateTime(2026, 10, 7), TransactionType.credit, 900),
        ],
        null,
        now,
      );
      expect(totals.length, 12);
      expect(totals.first.key, '2025-11');
      expect(totals.last, (key: '2026-10', spent: 150, income: 900));
    });

    test('stretches back to the oldest entry', () {
      final totals = monthTotals(
        [(DateTime(2024, 1, 1), TransactionType.debit, 1)],
        null,
        now,
      );
      expect(totals.first.key, '2024-01');
      expect(totals.last.key, '2026-10');
    });

    test('uses period totals in salary-day mode', () {
      final totals = monthTotals(
        [
          (DateTime(2026, 10, 27), TransactionType.debit, 1),
          (DateTime(2026, 10, 28), TransactionType.debit, 2),
        ],
        28,
        now,
      );
      expect(totals.last, (key: '2026-11', spent: 2, income: 0));
      expect(totals[totals.length - 2].spent, 1);
    });
  });

  group('dailySpend', () {
    test('has a zero bucket for quiet days and drops outside dates', () {
      final days = dailySpend(
        [
          (DateTime(2026, 2, 1, 9), 100),
          (DateTime(2026, 2, 1, 18), 50),
          (DateTime(2026, 2, 3), 7),
          (DateTime(2026, 3, 1), 999),
        ],
        DateTime(2026, 2),
        DateTime(2026, 3),
      );
      expect(days.length, 28);
      expect(days[0].paise, 150);
      expect(days[1].paise, 0);
      expect(days[2].paise, 7);
    });

    test('spans months in a salary-day period', () {
      final days = dailySpend(
        const [],
        DateTime(2026, 10, 28),
        DateTime(2026, 11, 28),
      );
      expect(days.length, 31);
      expect(days.first.start, DateTime(2026, 10, 28));
      expect(days.last.start, DateTime(2026, 11, 27));
    });
  });

  test('weeklySpend sums sevens and keeps a short last week', () {
    final days = dailySpend(
      [for (var d = 1; d <= 10; d++) (DateTime(2026, 1, d), 100)],
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 11),
    );
    final weeks = weeklySpend(days);
    expect(weeks.map((w) => w.paise), [700, 300]);
    expect(weeks.last.start, DateTime(2026, 1, 8));
  });

  group('dailyAverage', () {
    final days = dailySpend(
      [(DateTime(2026, 10, 1), 1000)],
      DateTime(2026, 10),
      DateTime(2026, 11),
    );

    test('a finished month divides by all its days', () {
      expect(dailyAverage(days, DateTime(2026, 12)), 32); // 1000 / 31, rounded
    });

    test('a month in progress divides by the days so far', () {
      expect(dailyAverage(days, DateTime(2026, 10, 4, 12)), 250);
    });

    test('a future month divides by all its days', () {
      expect(dailyAverage(days, DateTime(2026, 9)), 32);
    });
  });

  group('budgetPie', () {
    const food = 1, rent = 2;

    test('a half-spent limit is half dark, the rest is unallocated', () {
      final pie = budgetPie({food: 1000, rent: 3000}, {food: 500}, 10000);
      final slice = pie.slices.first;
      expect((slice.dark, slice.light, slice.over), (500, 500, false));
      expect(pie.slices[2].kind, SliceKind.unallocated);
      expect(pie.slices[2].size, 6000);
      expect(pie.overSalaryBy, 0);
      expect(pie.salaryRing, isNull);
    });

    test('spend past a limit fills the slice and marks it, size unchanged', () {
      final slice = budgetPie({food: 1000}, {food: 1500}, 10000).slices.first;
      expect(
        (slice.size, slice.dark, slice.light, slice.over),
        (1000, 1000, 0, true),
      );
    });

    test('no unallocated slice when limits reach the salary', () {
      final pie = budgetPie({food: 1000}, const {}, 1000);
      expect(pie.slices.map((s) => s.kind), [SliceKind.category]);
    });

    test('uncategorised spend is a fully dark slice of its own', () {
      final pie = budgetPie(const {}, {null: 300}, null);
      final slice = pie.slices.single;
      expect(slice.kind, SliceKind.uncategorised);
      expect((slice.dark, slice.light, slice.over), (300, 0, false));
    });

    test('over salary, counting spend with no limit or category', () {
      // Worked by hand: 2,000 + 500 + 1,500 = 4,000 against 1,000.
      final pie = budgetPie(
        {food: 500},
        {food: 2000, rent: 500, null: 1500},
        1000,
      );
      expect(pie.overSalaryBy, 3000);
      expect(pie.salaryRing, closeTo(sqrt(0.25), 1e-9));
    });

    test('spend exactly equal to salary is not over', () {
      final pie = budgetPie(const {}, {food: 1000}, 1000);
      expect(pie.overSalaryBy, 0);
      expect(pie.salaryRing, isNull);
    });

    test('a zero salary has no ring to draw but is still over', () {
      final pie = budgetPie(const {}, {food: 100}, 0);
      expect(pie.overSalaryBy, 100);
      expect(pie.salaryRing, isNull);
    });

    test('empty with nothing to draw', () {
      expect(budgetPie(const {}, const {}, null).isEmpty, isTrue);
      expect(budgetPie(const {}, {food: 100}, null).isEmpty, isTrue);
      expect(budgetPie(const {}, const {}, 100).isEmpty, isFalse);
    });
  });

  test('Money.compact shortens axis labels', () {
    expect(Money.compact(0), '₹0');
    expect(Money.compact(50000), '₹500');
    expect(Money.compact(150000), '₹1.5k');
    expect(Money.compact(1000000), '₹10k');
    expect(Money.compact(15545300), '₹1.6L');
    expect(Money.compact(1500000000), '₹1.5Cr');
  });
}
