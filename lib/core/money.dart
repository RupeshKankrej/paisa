/// Formats and parses integer paise. All UI amounts go through this.
abstract final class Money {
  static final _amount = RegExp(r'^(\d[\d,]*)?(?:\.(\d{0,2}))?$');
  static final _lakhGroups = RegExp(r'(\d)(?=(\d\d)+\d$)');

  /// 15545300 -> ₹1,55,453.00 (Indian grouping).
  static String format(int paise) {
    final abs = paise.abs();
    final rupees = (abs ~/ 100).toString();
    final grouped = rupees.replaceAllMapped(_lakhGroups, (m) => '${m[1]},');
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '${paise < 0 ? '-' : ''}₹$grouped.$fraction';
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
