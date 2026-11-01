import 'package:excel/excel.dart';

import '../../core/period.dart';
import '../../data/database.dart';
import '../../domain/budget.dart';
import '../../domain/models.dart';

/// What a workbook is made from; every list is the whole table.
typedef WorkbookData = ({
  List<TransactionRow> rows,
  List<Category> categories,
  Map<int, Map<String?, int>> budgets,
  Map<String?, int> salaries,
  int? salaryDay,
});

// Indian grouping (SPEC 4.1): Excel formats have no lakh mode, so it goes by size.
final _indian = CustomNumericNumFormat(
  formatCode:
      r'[>=10000000]##\,##\,##\,##0.00;[>=100000]##\,##\,##0.00;##,##0.00',
);
const _bold = true;

/// `Paisa_2026-10.xlsx`, or its real dates in salary-day mode (SPEC 5.10).
String workbookFileName(String month, int? salaryDay) {
  if (salaryDay == null || salaryDay == 1) return 'Paisa_$month.xlsx';
  final period = Period.forMonthKey(month, salaryDay);
  final last = period.end.subtract(const Duration(hours: 12));
  return 'Paisa_${_isoDate(period.start)}_${_isoDate(last)}.xlsx';
}

/// The Expenses, Income and Summary sheets of SPEC 5.10 for one period.
List<int> monthWorkbook(WorkbookData data, String month) {
  final excel = Excel.createExcel();
  final rows = _rowsIn(data, month);
  final first = excel.getDefaultSheet()!;
  excel.rename(first, 'Expenses');
  _writeRows(excel['Expenses'], data, rows, TransactionType.debit);
  _writeRows(excel['Income'], data, rows, TransactionType.credit);
  _writeSummary(excel['Summary'], data, month, rows);
  return excel.encode()!;
}

/// One sheet per period with data, oldest first, stacking the same three parts.
List<int> allMonthsWorkbook(WorkbookData data) {
  final excel = Excel.createExcel();
  final first = excel.getDefaultSheet()!;
  final months = {
    for (final r in data.rows)
      Period.containing(r.occurredAt, data.salaryDay).key,
  }.toList()..sort();
  if (months.isEmpty) {
    excel[first].appendRow([TextCellValue('No transactions')]);
    return excel.encode()!;
  }
  excel.rename(first, months.first);
  for (final month in months) {
    final sheet = excel[month];
    final rows = _rowsIn(data, month);
    sheet.appendRow([TextCellValue('Expenses')]);
    _writeRows(sheet, data, rows, TransactionType.debit);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Income')]);
    _writeRows(sheet, data, rows, TransactionType.credit);
    sheet.appendRow([TextCellValue('')]);
    _writeSummary(sheet, data, month, rows);
  }
  return excel.encode()!;
}

List<TransactionRow> _rowsIn(WorkbookData data, String month) {
  final period = Period.forMonthKey(month, data.salaryDay);
  return [
    for (final r in data.rows)
      if (!r.occurredAt.isBefore(period.start) &&
          r.occurredAt.isBefore(period.end))
        r,
  ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
}

void _writeRows(
  Sheet sheet,
  WorkbookData data,
  List<TransactionRow> rows,
  TransactionType type,
) {
  final names = {for (final c in data.categories) c.id: c.name};
  final picked = rows.where((r) => r.type == type).toList();
  _appendBold(sheet, [
    TextCellValue('Date'),
    TextCellValue('Time'),
    TextCellValue('Counterparty'),
    TextCellValue('Category'),
    TextCellValue('Amount'),
    TextCellValue('Source'),
    TextCellValue('Note'),
    TextCellValue('Ref no'),
  ]);
  for (final r in picked) {
    final at = r.occurredAt;
    sheet.appendRow([
      DateCellValue(year: at.year, month: at.month, day: at.day),
      TimeCellValue(hour: at.hour, minute: at.minute),
      TextCellValue(r.counterparty ?? ''),
      TextCellValue(names[r.categoryId] ?? 'Uncategorised'),
      DoubleCellValue(r.amountPaise / 100),
      TextCellValue(switch (r.source) {
        TransactionSource.sms => 'SMS',
        TransactionSource.manual => 'Manual',
        TransactionSource.share => 'Share',
      }),
      TextCellValue(r.note ?? ''),
      TextCellValue(r.refNo ?? ''),
    ]);
    _formatAmountCell(sheet, sheet.maxRows - 1, 4);
  }
  _appendBold(sheet, [
    TextCellValue('Total'),
    null,
    null,
    null,
    DoubleCellValue(sumPaise(picked.map((r) => r.amountPaise)) / 100),
  ]);
  _formatAmountCell(sheet, sheet.maxRows - 1, 4, bold: true);
  sheet.setColumnWidth(2, 36);
  sheet.setColumnWidth(3, 18);
}

void _writeSummary(
  Sheet sheet,
  WorkbookData data,
  String month,
  List<TransactionRow> rows,
) {
  final debits = rows.where((r) => r.type == TransactionType.debit);
  final spend = spendByCategory(
    debits.map((r) => (r.categoryId, r.amountPaise)),
  );
  final spent = sumPaise(spend.values);
  final salary = resolveAmount(data.salaries, month);

  void amountRow(String label, int? paise) {
    sheet.appendRow([
      TextCellValue(label),
      if (paise != null) DoubleCellValue(paise / 100),
    ]);
    if (paise != null) _formatAmountCell(sheet, sheet.maxRows - 1, 1);
  }

  amountRow('Salary', salary);
  amountRow('Total spent', spent);
  amountRow('Remaining', salary == null ? null : salary - spent);
  sheet.appendRow([TextCellValue('')]);
  _appendBold(sheet, [
    TextCellValue('Category'),
    TextCellValue('Limit'),
    TextCellValue('Spent'),
    TextCellValue('Remaining'),
    TextCellValue('% used'),
  ]);

  void categoryRow(String name, int? limit, int spent) {
    sheet.appendRow([
      TextCellValue(name),
      if (limit == null) null else DoubleCellValue(limit / 100),
      DoubleCellValue(spent / 100),
      if (limit == null) null else DoubleCellValue((limit - spent) / 100),
      if (limit != null && limit > 0) DoubleCellValue(spent / limit),
    ]);
    final row = sheet.maxRows - 1;
    if (limit != null) {
      _formatAmountCell(sheet, row, 1);
      _formatAmountCell(sheet, row, 3);
      if (limit > 0) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .cellStyle = CellStyle(
          numberFormat: NumFormat.standard_10,
        );
      }
    }
    _formatAmountCell(sheet, row, 2);
  }

  if ((spend[null] ?? 0) > 0) categoryRow('Uncategorised', null, spend[null]!);
  for (final c in data.categories) {
    final spentHere = spend[c.id];
    final listed = c.type == CategoryType.expense && !c.isArchived;
    if (!listed && spentHere == null) continue;
    final limit = resolveAmount(data.budgets[c.id] ?? const {}, month);
    categoryRow(c.name, limit, spentHere ?? 0);
  }
}

void _appendBold(Sheet sheet, List<CellValue?> cells) {
  sheet.appendRow(cells);
  final row = sheet.maxRows - 1;
  for (var col = 0; col < cells.length; col++) {
    if (cells[col] == null) continue;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .cellStyle = CellStyle(
      bold: _bold,
    );
  }
}

void _formatAmountCell(Sheet sheet, int row, int col, {bool bold = false}) {
  sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .cellStyle = CellStyle(
    bold: bold,
    numberFormat: _indian,
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
