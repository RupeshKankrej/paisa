import 'dart:math';

import 'month_key.dart';

/// The dates a month key stands for (SPEC 5.11). A null [salaryDay] means
/// calendar months, and so does 1: the period then ends in the month it starts.
class Period {
  const Period._(this.key, this.start, this.end);

  final String key;

  /// Local midnight of the first day.
  final DateTime start;

  /// Local midnight after the last day, so exclusive.
  final DateTime end;

  static Period forMonthKey(String key, int? salaryDay) {
    if (salaryDay == null || salaryDay == 1) {
      return Period._(
        key,
        MonthKey.start(key),
        MonthKey.start(MonthKey.shift(key, 1)),
      );
    }
    return Period._(
      key,
      _startIn(MonthKey.shift(key, -1), salaryDay),
      _startIn(key, salaryDay),
    );
  }

  static Period containing(DateTime date, int? salaryDay) {
    final key = MonthKey.of(date);
    if (salaryDay == null || salaryDay == 1) {
      return forMonthKey(key, salaryDay);
    }
    // Labelled by the month it ends in, so from the salary day on it is the next.
    final startedHere = !date.isBefore(_startIn(key, salaryDay));
    return forMonthKey(startedHere ? MonthKey.shift(key, 1) : key, salaryDay);
  }

  /// '28 Oct – 27 Nov'.
  String get rangeLabel {
    final last = end.subtract(const Duration(hours: 12));
    return '${_short(start)} – ${_short(last)}';
  }

  static String _short(DateTime date) =>
      '${date.day} ${MonthKey.label(MonthKey.of(date)).substring(0, 3)}';

  /// The salary day in that month, or its last day if the month is shorter.
  static DateTime _startIn(String key, int salaryDay) {
    final first = MonthKey.start(key);
    final length = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, min(salaryDay, length));
  }
}
