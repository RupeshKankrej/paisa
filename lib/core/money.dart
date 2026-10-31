/// Formats and parses integer paise. All UI amounts go through this.
abstract final class Money {
  static final _amount = RegExp(r'^(\d[\d,]*)?(?:\.(\d{0,2}))?$');
  static final _lakhGroups = RegExp(r'(\d)(?=(\d\d)+\d$)');

  /// 15545300 -> ₹1,55,453.00 (Indian grouping).
  static String format(int paise) {
    final abs = paise.abs();
    final grouped = _group((abs ~/ 100).toString());
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '${paise < 0 ? '-' : ''}₹$grouped.$fraction';
  }

  static String _group(String rupees) =>
      rupees.replaceAllMapped(_lakhGroups, (m) => '${m[1]},');

  /// Keypad input for an amount: 12050 -> '120.50', 12000 -> '120'.
  static String keypadText(int paise) =>
      format(paise)
          .replaceAll(RegExp(r'[₹,]'), '')
          .replaceFirst(RegExp(r'\.00$'), '');

  /// Keypad input after pressing a digit or '.'; a press that would make it
  /// invalid (third decimal, second point, too long) leaves it unchanged.
  static String keypadPress(String text, String key) {
    final next = key == '.' && text.isEmpty
        ? '0.'
        : text == '0' && key != '.'
        ? key
        : text + key;
    return tryParse(next) == null ? text : next;
  }

  /// Keypad input for display, as typed: '1250.5' -> ₹1,250.5.
  static String keypadDisplay(String text) {
    final point = text.indexOf('.');
    final rupees = point < 0 ? text : text.substring(0, point);
    final rest = point < 0 ? '' : text.substring(point);
    return '₹${_group(rupees.isEmpty ? '0' : rupees)}$rest';
  }

  /// A short form for chart axes: ₹500, ₹1.5k, ₹1.5L, ₹1.5Cr.
  static String compact(int paise) {
    if (paise < 0) return '-${compact(-paise)}';
    final rupees = paise / 100;
    String short(double value, String unit) =>
        '₹${value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}$unit';
    if (rupees < 1000) return '₹${rupees.round()}';
    if (rupees < 100000) return short(rupees / 1000, 'k');
    if (rupees < 10000000) return short(rupees / 100000, 'L');
    return short(rupees / 10000000, 'Cr');
  }

  /// '1,55,453.00' -> 15545300, without going through a double.
  /// Returns null for anything that is not a non-negative amount with at most
  /// two decimals.
  static int? tryParse(String text) {
    final match = _amount.firstMatch(text.trim());
    final rupees = match?[1]?.replaceAll(',', '') ?? '';
    final fraction = match?[2] ?? '';
    if (match == null || (rupees.isEmpty && fraction.isEmpty)) return null;
    if (rupees.length > 15) return null; // would overflow int paise
    return int.parse(rupees.isEmpty ? '0' : rupees) * 100 +
        int.parse(fraction.padRight(2, '0'));
  }
}
