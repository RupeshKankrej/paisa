import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/domain/quanto_csv.dart';
import 'package:paisa/features/settings/ai_export.dart';
import 'package:paisa/features/settings/data_transfer.dart';
import 'package:paisa/features/settings/settings_screen.dart' show appVersion;
import 'package:paisa/features/settings/workbook.dart';

const _quantoFile =
    'docs/design/reference/Quanto_Transactions_20261101_111245.csv';

// The decoder reads a whole number back as an int; either way it is a number.
num _number(Data? cell) => switch (cell?.value) {
  DoubleCellValue(:final value) => value,
  IntCellValue(:final value) => value,
  final other => throw StateError('Not a number: $other'),
};

// Real financial data, kept out of git: these run only where the file exists.
final _noQuantoFile = File(_quantoFile).existsSync()
    ? null
    : 'no local Quanto file';

void main() {
  // prepareRestore opens a second database on purpose, on its own file.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('paisa_data');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<int> count() => db.transactions.count().getSingle();

  Future<void> import(String csv) async {
    final plan = await planImport(db, parseQuantoCsv(csv));
    await applyImport(db, plan.newRows);
  }

  group('Quanto CSV', () {
    test('reads the real export, keeping its same-day twins', () {
      final parsed = parseQuantoCsv(File(_quantoFile).readAsStringSync());
      expect(parsed.rows, hasLength(155));
      expect(parsed.badLines, isEmpty);
      final salary = parsed.rows[2];
      expect(salary.date, DateTime(2026, 5, 30));
      expect(salary.paise, greaterThan(0));
      expect(salary.type, TransactionType.credit);
      expect(salary.category, 'Salary');
      expect(parsed.rows.last.name, isEmpty);
    }, skip: _noQuantoFile);

    test('writes the real export back byte for byte, order aside', () {
      final text = File(_quantoFile).readAsStringSync();
      List<String> sorted(String s) => const LineSplitter().convert(s)..sort();
      expect(sorted(quantoCsv(parseQuantoCsv(text).rows)), sorted(text));
    }, skip: _noQuantoFile);

    test('handles quotes, a BOM, CRLF and reordered columns', () {
      final parsed = parseQuantoCsv(
        '﻿Type,Date,Amount,Category,Name,Account\r\n'
        'Expense,01/02/2026,"1,00,000.50",Food,"Lunch, ""big""\nday",Main\r\n',
      );
      expect(parsed.rows.single.paise, 10000050);
      expect(parsed.rows.single.name, 'Lunch, "big"\nday');
    });

    test('reports bad rows by line and reads the rest', () {
      final parsed = parseQuantoCsv(
        'Date,Amount,Category,Name,Account,Type\n'
        '31/02/2026,10.00,Food,,Main,Expense\n'
        '01/01/2026,-5.00,Food,,Main,Expense\n'
        '01/01/2026,0.00,Food,,Main,Expense\n'
        '01/01/2026,5.123,Food,,Main,Expense\n'
        '01/01/2026,5.00,Food,,Main,Transfer\n'
        '2026-01-01,5.00,Food,,Main,Expense\n'
        '01/01/2026,5.00,Food,,Main,Expense\n',
      );
      expect(parsed.badLines, [2, 3, 4, 5, 6, 7]);
      expect(parsed.rows, hasLength(1));
    });

    test('refuses a file without the columns', () {
      expect(
        () => parseQuantoCsv('Date,Amount\n01/01/2026,5\n'),
        throwsFormatException,
      );
      expect(() => parseQuantoCsv(''), throwsFormatException);
    });

    test('a formula in a name is defused on export and restored on import', () {
      final out = quantoCsv([
        QuantoRow(
          date: DateTime(2026),
          paise: 100,
          type: TransactionType.debit,
          name: '=HYPERLINK("x")',
        ),
      ]);
      expect(out, contains('"\'=HYPERLINK(""x"")"'));
      expect(parseQuantoCsv(out).rows.single.name, '=HYPERLINK("x")');
    });
  });

  group('import', () {
    const twins =
        'Date,Amount,Category,Name,Account,Type\n'
        '05/06/2026,"3,500.00",Food,,Main account,Expense\n'
        '05/06/2026,"3,500.00",Food,,Main account,Expense\n'
        '06/06/2026,10.00,Parents,Mum,Main account,Expense\n'
        '30/05/2026,"1,30,000.00",Salary,,Main account,Income\n';

    test('twins stay, and a second import adds nothing', () async {
      await import(twins);
      expect(await count(), 4);
      await import(twins);
      expect(await count(), 4);
    });

    test('the whole real file imports once', () async {
      final text = File(_quantoFile).readAsStringSync();
      await import(text);
      expect(await count(), 155);
      final plan = await planImport(db, parseQuantoCsv(text));
      expect(plan.newRows, isEmpty);
      expect(plan.alreadyThere, 155);
    }, skip: _noQuantoFile);

    test('a later file adds only what is new', () async {
      await import(twins);
      await import(
        '$twins'
        '05/06/2026,"3,500.00",Food,,Main account,Expense\n',
      );
      expect(await count(), 5);
    });

    test('matches categories by type and any case, creates the rest', () async {
      final plan = await planImport(db, parseQuantoCsv(twins));
      expect(plan.newCategories, ['Parents']);
      await applyImport(db, plan.newRows);

      final categories = await db.select(db.categories).get();
      final rows = await db.select(db.transactions).get();
      Category named(String n, CategoryType t) =>
          categories.singleWhere((c) => c.name == n && c.type == t);
      final salaryRow = rows.singleWhere(
        (r) => r.type == TransactionType.credit,
      );
      expect(salaryRow.categoryId, named('Salary', CategoryType.income).id);
      expect(salaryRow.source, TransactionSource.manual);
      expect(salaryRow.occurredAt, DateTime(2026, 5, 30, 12));
      expect(
        rows.firstWhere((r) => r.counterparty == 'Mum').categoryId,
        named('Parents', CategoryType.expense).id,
      );
    });

    test('recategorising a row does not make it import again', () async {
      await import(twins);
      final row = (await db.select(db.transactions).get()).first;
      await db.updateTransaction(
        row.id,
        const TransactionsCompanion(categoryId: Value(null)),
      );
      await import(twins);
      expect(await count(), 4);
    });

    test('an export imports into an empty app with the same rows', () async {
      await import(twins);
      final csv = await exportCsv(db);
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final plan = await planImport(other, parseQuantoCsv(csv));
      expect(plan.newRows, hasLength(4));
    });
  });

  test('JSON holds every table a user owns, and no ingest log', () async {
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.debit,
        amountPaise: 12050,
        occurredAt: DateTime(2026, 10, 30, 9),
        source: TransactionSource.sms,
        rawText: const Value('raw'),
      ),
    );
    await db.setSalary(null, 100);
    final json = jsonDecode(
      await exportJson(db, DateTime.utc(2026, 11)),
    ) as Map<String, dynamic>;
    final row = (json['transactions'] as List).single as Map<String, dynamic>;
    expect(row['amountPaise'], 12050);
    expect(row['rawText'], 'raw');
    expect(row['type'], 'debit');
    expect(row['occurredAt'], startsWith('2026-10-30T09:00'));
    expect(json['salary'], hasLength(1));
    expect(json['categories'], isNotEmpty);
    expect(json.keys, isNot(contains('ingest_log')));
  });

  group('workbook', () {
    Future<WorkbookData> data({int? salaryDay}) async => (
      rows: await db.select(db.transactions).get(),
      categories: await db.watchCategories().first,
      budgets: await db.watchBudgetAmounts().first,
      salaries: await db.watchSalaryAmounts().first,
      salaryDay: salaryDay,
    );

    Future<int> seed() async {
      final food = (await db.select(db.categories).get()).firstWhere(
        (c) => c.name == 'Food',
      );
      Future<void> add(
        int paise,
        DateTime at,
        TransactionType type, [
        int? category,
      ]) => db.addTransaction(
        TransactionsCompanion.insert(
          type: type,
          amountPaise: paise,
          occurredAt: at,
          source: TransactionSource.manual,
          categoryId: Value(category),
          note: const Value('n'),
          refNo: const Value('r1'),
        ),
      );
      await add(
        15545350,
        DateTime(2026, 10, 2, 9, 30),
        TransactionType.debit,
        food.id,
      );
      await add(5000, DateTime(2026, 10, 1, 8), TransactionType.debit);
      await add(100, DateTime(2026, 9, 1), TransactionType.debit);
      await add(30000000, DateTime(2026, 10, 28), TransactionType.credit);
      await db.setSalary(null, 50000000);
      await db.setBudget(food.id, null, 20000000);
      return food.id;
    }

    test('month sheets: numbers, totals, sorting, summary', () async {
      await seed();
      final book = Excel.decodeBytes(monthWorkbook(await data(), '2026-10'));
      expect(book.tables.keys, containsAll(['Expenses', 'Income', 'Summary']));
      expect(book.tables.keys, hasLength(3));

      final expenses = book['Expenses'].rows;
      expect(expenses[0][0]!.value.toString(), 'Date');
      expect(expenses[1][3]!.value.toString(), 'Uncategorised');
      expect(expenses[2][3]!.value.toString(), 'Food');
      expect(_number(expenses[2][4]), 155453.5);
      expect(expenses[2][5]!.value.toString(), 'Manual');
      expect(expenses[2][6]!.value.toString(), 'n');
      expect(expenses[2][7]!.value.toString(), 'r1');
      expect(expenses[3][0]!.value.toString(), 'Total');
      expect(_number(expenses[3][4]), 155503.5);
      expect(expenses[3][4]!.cellStyle?.isBold, isTrue);
      expect(
        expenses[2][0]!.value,
        const DateCellValue(year: 2026, month: 10, day: 2),
      );
      expect(
        expenses[2][4]!.cellStyle?.numberFormat.formatCode,
        contains('[>=100000]'),
      );
      expect(expenses, hasLength(4));

      expect(_number(book['Income'].rows[1][4]), 300000);

      final summary = book['Summary'].rows;
      expect(_number(summary[0][1]), 500000);
      expect(_number(summary[1][1]), 155503.5);
      expect(_number(summary[2][1]), 344496.5);
      final food = summary.firstWhere((r) => r[0]?.value.toString() == 'Food');
      expect(_number(food[1]), 200000);
      expect(_number(food[3]), 44546.5);
      expect((food[4]!.value! as DoubleCellValue).value, closeTo(0.777, 0.001));
    });

    test(
      'salary-day mode follows the period and names the file by dates',
      () async {
        await seed();
        expect(workbookFileName('2026-10', null), 'Paisa_2026-10.xlsx');
        expect(workbookFileName('2026-10', 1), 'Paisa_2026-10.xlsx');
        expect(
          workbookFileName('2026-11', 28),
          'Paisa_2026-10-28_2026-11-27.xlsx',
        );
        final book = Excel.decodeBytes(
          monthWorkbook(await data(salaryDay: 28), '2026-11'),
        );
        expect(_number(book['Income'].rows[1][4]), 300000);
        expect(book['Expenses'].rows, hasLength(2)); // header and total only
      },
    );

    test('all months: one sheet per period with data', () async {
      await seed();
      final book = Excel.decodeBytes(allMonthsWorkbook(await data()));
      expect(book.tables.keys.toSet(), {'2026-09', '2026-10'});
      expect(book['2026-09'].rows[0][0]!.value.toString(), 'Expenses');
    });

    test('all months with no rows is still a file', () async {
      final book = Excel.decodeBytes(allMonthsWorkbook(await data()));
      expect(book.tables, hasLength(1));
    });
  });

  group('backup and restore', () {
    late AppDatabase source;
    late String backup;
    String work() => '${dir.path}/work.sqlite';

    setUp(() async {
      source = AppDatabase(NativeDatabase.memory());
      await source.addCategory(
        name: 'Parents',
        type: CategoryType.expense,
        emoji: '👪',
        color: 1,
      );
      final parents = (await source.select(source.categories).get()).last;
      await source.addTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.debit,
          amountPaise: 777,
          occurredAt: DateTime(2026, 1, 1),
          source: TransactionSource.manual,
          categoryId: Value(parents.id),
        ),
      );
      await source.setBudget(parents.id, null, 5000);
      await source.setSalaryDay(28);
      await source
          .into(source.ingestLog)
          .insert(
            IngestLogCompanion.insert(
              fingerprint: 'fp',
              ingestedAt: DateTime(2026),
              status: IngestStatus.parsed,
            ),
          );
      backup = '${dir.path}/backup.sqlite';
      await writeBackup(source, backup);
      await source.close();
    });

    test('replaces every table and notifies open streams', () async {
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.debit,
          amountPaise: 1,
          occurredAt: DateTime(2020),
          source: TransactionSource.manual,
        ),
      );
      final seen = <int>[];
      final sub = db.watchAllTransactions().listen(
        (rows) => seen.add(rows.single.amountPaise),
      );
      await pumpEventQueue();

      expect(await prepareRestore(backup, work(), db.schemaVersion), 1);
      await applyRestore(db, work());
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.last, 777);
      expect(await db.watchSalaryDay().first, 28);
      expect(await db.ingestLog.count().getSingle(), 1);
      final parents = (await db.select(db.categories).get()).singleWhere(
        (c) => c.name == 'Parents',
      );
      expect(parents.emoji, '👪');
      expect((await db.watchBudgetAmounts().first)[parents.id]?[null], 5000);
      // The attachment is gone, so a second restore can attach again.
      await applyRestore(db, work());
      expect(await count(), 1);
    });

    test('a failure mid-way leaves live data untouched', () async {
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.debit,
          amountPaise: 1,
          occurredAt: DateTime(2020),
          source: TransactionSource.manual,
        ),
      );
      final broken = File('${dir.path}/empty.sqlite');
      final empty = AppDatabase(NativeDatabase(broken));
      await empty.customStatement('DROP TABLE settings');
      await empty.close();
      await expectLater(applyRestore(db, broken.path), throwsA(anything));
      final rows = await db.select(db.transactions).get();
      expect(rows.single.amountPaise, 1);
    });

    test('refuses what is not a backup, before touching anything', () async {
      final text = File('${dir.path}/notes.txt')..writeAsStringSync('hello');
      await expectLater(
        prepareRestore(text.path, work(), db.schemaVersion),
        throwsA(isA<RestoreException>()),
      );

      final truncated = File('${dir.path}/cut.sqlite')
        ..writeAsBytesSync(File(backup).readAsBytesSync().sublist(0, 2048));
      await expectLater(
        prepareRestore(truncated.path, work(), db.schemaVersion),
        throwsA(isA<RestoreException>()),
      );

      final bytes = File(backup).readAsBytesSync();
      bytes[63] = 99; // user_version
      final newer = File('${dir.path}/newer.sqlite')..writeAsBytesSync(bytes);
      await expectLater(
        prepareRestore(newer.path, work(), db.schemaVersion),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('newer'),
          ),
        ),
      );
    });
  });

  test('AI report: figures add up, and private fields stay out', () async {
    final food = (await db.select(db.categories).get()).firstWhere(
      (c) => c.name == 'Food',
    );
    Future<void> add(
      int paise,
      DateTime at,
      TransactionType type, {
      int? category,
      String? name,
    }) => db.addTransaction(
      TransactionsCompanion.insert(
        type: type,
        amountPaise: paise,
        occurredAt: at,
        source: TransactionSource.sms,
        categoryId: Value(category),
        counterparty: Value(name),
        rawText: const Value('RAW SMS TEXT'),
        refNo: const Value('630329677868'),
        accountLast4: const Value('2703'),
      ),
    );
    await add(
      12050,
      DateTime(2026, 10, 2),
      TransactionType.debit,
      category: food.id,
      name: 'Lunch, big',
    );
    await add(5000, DateTime(2026, 10, 3), TransactionType.debit);
    await add(10000000, DateTime(2026, 9, 28), TransactionType.credit);
    await db.setSalary(null, 10000000);
    await db.setBudget(food.id, null, 500000);

    final report = aiReport((
      rows: await db.select(db.transactions).get(),
      categories: await db.watchCategories().first,
      budgets: await db.watchBudgetAmounts().first,
      salaries: await db.watchSalaryAmounts().first,
      salaryDay: null,
    ), DateTime(2026, 11, 1));

    expect(report, contains('| 2026-10 | 100000 | 0 | 170.50 | 2 |'));
    expect(report, contains('| 2026-09 | 100000 | 100000 | 0 | 1 |'));
    expect(report, contains('| 2026-10 | Food | 120.50 | 5000 |'));
    expect(report, contains('| 2026-10 | Uncategorised | 50 | none |'));
    expect(report, contains('2026-10-02,expense,120.50,Food,"Lunch, big",'));
    expect(
      report.indexOf('2026-09-28,income'),
      lessThan(report.indexOf('2026-10-02,expense')),
    );
    for (final secret in ['RAW SMS', '630329677868', '2703']) {
      expect(report, isNot(contains(secret)));
    }
  });

  test('appVersion matches pubspec.yaml', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: $appVersion+'),
    );
  });
}
