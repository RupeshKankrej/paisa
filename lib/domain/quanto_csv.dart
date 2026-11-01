import 'models.dart';

/// One row of the Quanto transactions CSV: Date, Amount, Category, Name, Account,
/// Type. It carries only a date, so a note, time or ref no does not survive it.
class QuantoRow {
  const QuantoRow({
    required this.date,
    required this.paise,
    required this.type,
    this.category = '',
    this.name = '',
    this.account = '',
  });

  final DateTime date;
  final int paise;
  final TransactionType type;
  final String category;
  final String name;
  final String account;
}

const defaultQuantoAccount = 'Main account';
const _header = ['Date', 'Amount', 'Category', 'Name', 'Account', 'Type'];
final _dateRow = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
final _amountRow = RegExp(r'^(\d[\d,]*)(?:\.(\d{1,2}))?$');
final _thousands = RegExp(r'(\d)(?=(\d{3})+$)');
const _formulaStarts = {'=', '+', '-', '@'};

/// The file's rows, and the line of each row that could not be read.
typedef QuantoParse = ({List<QuantoRow> rows, List<int> badLines});

/// Throws [FormatException] when the header is not a Quanto one. A bad row does
/// not stop the rest; it is reported, so nothing is dropped without saying.
QuantoParse parseQuantoCsv(String text) {
  final records = _records(text.replaceFirst('﻿', ''));
  if (records.isEmpty) throw const FormatException('The file is empty.');
  final header = records.first.fields.map((f) => f.trim()).toList();
  final missing = _header.where((h) => !header.contains(h)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('Missing columns: ${missing.join(', ')}.');
  }
  final rows = <QuantoRow>[];
  final badLines = <int>[];
  for (final record in records.skip(1)) {
    String field(String name) {
      final i = header.indexOf(name);
      return i < record.fields.length ? record.fields[i].trim() : '';
    }

    if (record.fields.every((f) => f.trim().isEmpty)) continue;
    final date = _parseDate(field('Date'));
    final paise = _parseAmount(field('Amount'));
    final type = switch (field('Type').toLowerCase()) {
      'expense' => TransactionType.debit,
      'income' => TransactionType.credit,
      _ => null,
    };
    if (date == null || paise == null || paise == 0 || type == null) {
      badLines.add(record.line);
      continue;
    }
    rows.add(
      QuantoRow(
        date: date,
        paise: paise,
        type: type,
        category: _unguard(field('Category')),
        name: _unguard(field('Name')),
        account: _unguard(field('Account')),
      ),
    );
  }
  return (rows: rows, badLines: badLines);
}

/// The same columns, formats and ordering as a Quanto export.
String quantoCsv(Iterable<QuantoRow> rows) {
  final sorted = rows.toList()..sort((a, b) => a.date.compareTo(b.date));
  final out = StringBuffer('${_header.join(',')}\n');
  for (final r in sorted) {
    out.writeln(
      [
        _formatDate(r.date),
        _formatAmount(r.paise),
        _guard(r.category),
        _guard(r.name),
        _guard(r.account.isEmpty ? defaultQuantoAccount : r.account),
        r.type == TransactionType.debit ? 'Expense' : 'Income',
      ].map(csvField).join(','),
    );
  }
  return out.toString();
}

/// Same day, amount, type and name. The category is left out, so a row that was
/// recategorised after an import still matches on the next one.
String quantoKey(
  DateTime date,
  int paise,
  TransactionType type,
  String? name,
) =>
    '${date.year}-${date.month}-${date.day}|$paise|${type.name}|'
    '${(name ?? '').trim().toLowerCase()}';

/// The rows of [file] not yet in the app. Counted, not set-based: two identical
/// rows in a file are two real purchases, and importing it twice adds nothing.
List<QuantoRow> rowsNotIn(List<QuantoRow> file, Iterable<String> existingKeys) {
  final existing = <String, int>{};
  for (final key in existingKeys) {
    existing[key] = (existing[key] ?? 0) + 1;
  }
  return [
    for (final row in file)
      if (!_consume(
        existing,
        quantoKey(row.date, row.paise, row.type, row.name),
      ))
        row,
  ];
}

bool _consume(Map<String, int> counts, String key) {
  final left = counts[key] ?? 0;
  if (left == 0) return false;
  counts[key] = left - 1;
  return true;
}

DateTime? _parseDate(String text) {
  final match = _dateRow.firstMatch(text);
  if (match == null) return null;
  final (day, month, year) = (
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
  final date = DateTime(year, month, day);
  // DateTime rolls 31/02 over into March, which would be a wrong date.
  return date.month == month && date.day == day ? date : null;
}

String _formatDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year.toString().padLeft(4, '0')}';

String _two(int n) => n.toString().padLeft(2, '0');

int? _parseAmount(String text) {
  final match = _amountRow.firstMatch(text);
  if (match == null) return null;
  final rupees = match[1]!.replaceAll(',', '');
  if (rupees.length > 15) return null; // would overflow int paise
  return int.parse(rupees) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
}

// Quanto groups in thousands (120,000.00), not lakhs, so this is not Money.format.
String _formatAmount(int paise) {
  final rupees = (paise ~/ 100).toString().replaceAllMapped(
    _thousands,
    (m) => '${m[1]},',
  );
  return '$rupees.${_two(paise % 100)}';
}

// A bank message's name opened in a spreadsheet must not run as a formula.
String _guard(String text) =>
    text.isNotEmpty && _formulaStarts.contains(text[0]) ? "'$text" : text;

String _unguard(String text) =>
    text.length > 1 && text[0] == "'" && _formulaStarts.contains(text[1])
    ? text.substring(1)
    : text;

/// A CSV field, quoted only when it has to be.
String csvField(String field) => field.contains(RegExp(r'[",\r\n]'))
    ? '"${field.replaceAll('"', '""')}"'
    : field;

/// RFC 4180 records with the line each starts on; quotes may hold newlines.
List<({List<String> fields, int line})> _records(String text) {
  final records = <({List<String> fields, int line})>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var line = 1;
  var start = 1;

  void endRecord() {
    fields.add(field.toString());
    field.clear();
    records.add((fields: fields, line: start));
    fields = [];
    start = line;
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        if (c == '\n') line++;
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      fields.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      line++;
      endRecord();
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || fields.isNotEmpty) endRecord();
  return records;
}
