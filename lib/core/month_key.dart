/// `YYYY-MM` keys, the text form of `month` in the database.
abstract final class MonthKey {
  static final _key = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$');
  static const _names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String of(DateTime date) => _format(date.year, date.month);

  /// The key [months] after [key]; negative goes back.
  static String shift(String key, int months) {
    final (year, month) = _parse(key);
    final shifted = DateTime(year, month + months);
    return _format(shifted.year, shifted.month);
  }

  /// '2026-10' -> 'October 2026'.
  static String label(String key) {
    final (year, month) = _parse(key);
    return '${_names[month - 1]} $year';
  }

  static (int, int) _parse(String key) {
    final match = _key.firstMatch(key);
    if (match == null) throw FormatException('Bad month key', key);
    return (int.parse(match[1]!), int.parse(match[2]!));
  }

  static String _format(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
