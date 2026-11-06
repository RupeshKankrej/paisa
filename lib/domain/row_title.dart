import 'models.dart';

/// SPEC 5.18: name, else note, else category, else the type. One line, 40 chars.
String rowTitle({
  String? name,
  String? note,
  String? categoryName,
  required TransactionType type,
}) {
  final title = [name, note, categoryName]
      .map((s) => s?.trim().split('\n').first.trim() ?? '')
      .firstWhere(
        (s) => s.isNotEmpty,
        orElse: () => type == TransactionType.debit ? 'Expense' : 'Income',
      );
  return title.length > 40 ? title.substring(0, 40) : title;
}
