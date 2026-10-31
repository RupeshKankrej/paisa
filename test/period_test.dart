import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/period.dart';

void main() {
  test('calendar mode is the calendar month', () {
    for (final day in [null, 1]) {
      final period = Period.forMonthKey('2026-02', day);
      expect(period.start, DateTime(2026, 2));
      expect(period.end, DateTime(2026, 3));
      expect(Period.containing(DateTime(2026, 2, 28, 23), day).key, '2026-02');
    }
  });

  test('salary day 28: labelled by the month it ends in', () {
    final period = Period.forMonthKey('2026-11', 28);
    expect(period.start, DateTime(2026, 10, 28));
    expect(period.end, DateTime(2026, 11, 28));
    expect(period.rangeLabel, '28 Oct – 27 Nov');
    expect(
      Period.containing(DateTime(2026, 10, 27, 23, 59), 28).key,
      '2026-10',
    );
    expect(Period.containing(DateTime(2026, 10, 28), 28).key, '2026-11');
    expect(Period.containing(DateTime(2026, 12, 28), 28).key, '2027-01');
  });

  test('salary day 31 starts on the last day of a shorter month', () {
    final december = Period.forMonthKey('2026-12', 31);
    expect(december.start, DateTime(2026, 11, 30));
    expect(december.end, DateTime(2026, 12, 31));
    expect(Period.containing(DateTime(2026, 11, 29), 31).key, '2026-11');
    expect(Period.containing(DateTime(2026, 11, 30), 31).key, '2026-12');
  });

  test('February, in normal and leap years', () {
    expect(Period.forMonthKey('2027-03', 30).start, DateTime(2027, 2, 28));
    expect(Period.forMonthKey('2028-03', 30).start, DateTime(2028, 2, 29));
    expect(Period.forMonthKey('2027-02', 30).end, DateTime(2027, 2, 28));
    expect(Period.forMonthKey('2027-03', 30).rangeLabel, '28 Feb – 29 Mar');
  });

  test(
    'every day of 4 years falls in exactly one correctly labelled period',
    () {
      for (var salaryDay = 1; salaryDay <= 31; salaryDay++) {
        for (var i = 0; i < 1461; i++) {
          final date = DateTime(2026, 1, 1 + i, 12);
          final period = Period.containing(date, salaryDay);
          expect(date.isBefore(period.start), isFalse);
          expect(date.isBefore(period.end), isTrue);
          final last = DateTime(
            period.end.year,
            period.end.month,
            period.end.day - 1,
          );
          expect(
            MonthKey.of(last),
            period.key,
            reason: 'day $salaryDay, $date',
          );
          final next = Period.forMonthKey(
            MonthKey.shift(period.key, 1),
            salaryDay,
          );
          expect(next.start, period.end, reason: 'no gap or overlap');
        }
      }
    },
  );
}
