import '../../core/money.dart';
import '../../core/period.dart';
import '../../domain/budget.dart';
import '../../domain/models.dart';
import '../../domain/quanto_csv.dart';
import 'workbook.dart';

const _prompt = '''
# Paisa: my spending data

You are helping me understand my personal finances. Use only the data below, and
say so when it cannot answer something. Please give me:

1. A short summary of where my money goes and how that has changed over time.
2. The categories and months that stand out, with the figures behind them.
3. Recurring payments and habits you can see in the transactions.
4. How I am doing against my salary and category limits.
5. Three specific changes that would save the most, each with an estimated
   monthly amount in rupees.

Ask me anything you need to know before drawing a conclusion you are unsure of.

## How to read this data

- Amounts are Indian rupees, as plain numbers.
- `expense` is money out and `income` is money in.
- "Salary setting" is the monthly salary I entered. "Income received" is what was
  recorded as coming in, so it can include that same salary; do not add them.
- Uncategorised rows are real spending that I have not tagged yet.
- Transfers between my own accounts may appear as expenses or income.
''';

String _rupees(int paise) =>
    '${paise < 0 ? '-' : ''}${Money.keypadText(paise.abs())}';

/// Everything an AI needs to analyse the finances, as one Markdown file to paste
/// or attach. Raw message text, ref and account numbers add nothing to an
/// analysis, so they stay out of a file that leaves for another company.
String aiReport(WorkbookData data, DateTime now) {
  final names = {for (final c in data.categories) c.id: c.name};
  final rows = data.rows.toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final byMonth = <String, List<int>>{};
  for (final (i, r) in rows.indexed) {
    (byMonth[Period.containing(r.occurredAt, data.salaryDay).key] ??= []).add(
      i,
    );
  }
  final months = byMonth.keys.toList()..sort();

  final out = StringBuffer(_prompt)
    ..writeln()
    ..writeln('## Overview')
    ..writeln()
    ..writeln('- Exported: ${_date(now)}')
    ..writeln('- Transactions: ${rows.length}')
    ..writeln(
      '- Months run ${data.salaryDay == null ? 'by calendar' : 'from salary day '
                '${data.salaryDay}, named after the month they end in'}',
    )
    ..writeln()
    ..writeln('## Months')
    ..writeln()
    ..writeln(
      '| Month | Salary setting | Income received | Spent | Transactions |',
    )
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final month in months) {
    final inMonth = byMonth[month]!.map((i) => rows[i]);
    int total(TransactionType type) => sumPaise(
      inMonth.where((r) => r.type == type).map((r) => r.amountPaise),
    );
    final salary = resolveAmount(data.salaries, month);
    out.writeln(
      '| $month | ${salary == null ? 'not set' : _rupees(salary)} '
      '| ${_rupees(total(TransactionType.credit))} '
      '| ${_rupees(total(TransactionType.debit))} | ${inMonth.length} |',
    );
  }

  out
    ..writeln()
    ..writeln('## Spending by category and month')
    ..writeln()
    ..writeln('| Month | Category | Spent | Limit |')
    ..writeln('| --- | --- | --- | --- |');
  for (final month in months) {
    final spend = spendByCategory(
      byMonth[month]!
          .map((i) => rows[i])
          .where((r) => r.type == TransactionType.debit)
          .map((r) => (r.categoryId, r.amountPaise)),
    );
    final sorted = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final MapEntry(key: id, value: paise) in sorted) {
      final limit = id == null
          ? null
          : resolveAmount(data.budgets[id] ?? const {}, month);
      out.writeln(
        '| $month | ${_cell(names[id] ?? 'Uncategorised')} | ${_rupees(paise)} '
        '| ${limit == null ? 'none' : _rupees(limit)} |',
      );
    }
  }

  out
    ..writeln()
    ..writeln('## All transactions')
    ..writeln()
    ..writeln('```csv')
    ..writeln('date,type,amount,category,name,note');
  for (final r in rows) {
    out.writeln(
      [
        _date(r.occurredAt),
        r.type == TransactionType.debit ? 'expense' : 'income',
        _rupees(r.amountPaise),
        names[r.categoryId] ?? 'Uncategorised',
        r.counterparty ?? '',
        r.note ?? '',
      ].map(csvField).join(','),
    );
  }
  out.writeln('```');
  return out.toString();
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// A category name is user text, and a pipe would break the table's columns.
String _cell(String text) => text.replaceAll('|', r'\|');
