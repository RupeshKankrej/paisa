import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';

void main() {
  test('of pads the month', () {
    expect(MonthKey.of(DateTime(2026, 3, 31)), '2026-03');
    expect(MonthKey.of(DateTime(2026, 10)), '2026-10');
  });

  test('shift crosses year boundaries', () {
    expect(MonthKey.shift('2026-10', 1), '2026-11');
    expect(MonthKey.shift('2026-12', 1), '2027-01');
    expect(MonthKey.shift('2026-01', -1), '2025-12');
    expect(MonthKey.shift('2026-10', -22), '2024-12');
    expect(MonthKey.shift('2026-10', 0), '2026-10');
  });

  test('label', () {
    expect(MonthKey.label('2026-10'), 'October 2026');
    expect(MonthKey.label('2027-01'), 'January 2027');
  });

  test('rejects bad keys', () {
    for (final key in ['2026-13', '2026-00', '2026-1', '26-10', '']) {
      expect(() => MonthKey.label(key), throwsFormatException, reason: key);
    }
  });

  test('start is the first local instant of the month', () {
    expect(MonthKey.start('2026-02'), DateTime(2026, 2));
  });

  test('range is inclusive and crosses years', () {
    expect(MonthKey.range('2026-11', '2027-01'), [
      '2026-11',
      '2026-12',
      '2027-01',
    ]);
    expect(MonthKey.range('2026-10', '2026-10'), ['2026-10']);
  });

  test('picker years: at least 5, stretched to the oldest and newest keys', () {
    expect(MonthKey.pickerYears('2026-10', const []), [
      2026,
      2025,
      2024,
      2023,
      2022,
    ]);
    expect(MonthKey.pickerYears('2026-10', const ['2020-03']).last, 2020);
    expect(MonthKey.pickerYears('2026-10', const ['2027-01']).first, 2027);
  });
}
