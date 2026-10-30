import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/domain/models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds the default categories in order', () async {
    final categories = await db.watchCategories().first;
    expect(categories.map((c) => c.name), [
      'Food',
      'Travel',
      'Rent',
      'Bills',
      'Shopping',
      'Health',
      'Entertainment',
      'Other',
    ]);
  });

  test('archived categories are hidden', () async {
    await (db.update(db.categories)..where((c) => c.name.equals('Rent'))).write(
      const CategoriesCompanion(isArchived: Value(true)),
    );
    final categories = await db.watchCategories().first;
    expect(categories.map((c) => c.name), isNot(contains('Rent')));
  });

  test('one salary default and one override per month', () async {
    Future<int> add(String? month) => db
        .into(db.salary)
        .insert(SalaryCompanion.insert(month: Value(month), amountPaise: 100));
    await add(null);
    await add('2026-10');
    await expectLater(add(null), throwsA(isA<SqliteException>()));
    await expectLater(add('2026-10'), throwsA(isA<SqliteException>()));
  });

  test('one budget default and one override per category and month', () async {
    Future<int> add(int category, String? month) => db
        .into(db.budgets)
        .insert(
          BudgetsCompanion.insert(
            categoryId: category,
            month: Value(month),
            amountPaise: 100,
          ),
        );
    await add(1, null);
    await add(2, null);
    await add(1, '2026-10');
    await expectLater(add(1, null), throwsA(isA<SqliteException>()));
    await expectLater(add(1, '2026-10'), throwsA(isA<SqliteException>()));
    await expectLater(add(999, null), throwsA(isA<SqliteException>()));
  });

  test('a transaction round-trips, uncategorised by default', () async {
    final id = await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            type: TransactionType.debit,
            amountPaise: 12000,
            occurredAt: DateTime(2026, 10, 30),
            source: TransactionSource.sms,
          ),
        );
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.type, TransactionType.debit);
    expect(row.source, TransactionSource.sms);
    expect(row.amountPaise, 12000);
    expect(row.categoryId, isNull);
  });

  test('ingest fingerprints are unique', () async {
    Future<int> add() => db
        .into(db.ingestLog)
        .insert(
          IngestLogCompanion.insert(
            fingerprint: 'abc',
            ingestedAt: DateTime(2026, 10, 30),
            status: IngestStatus.parsed,
          ),
        );
    await add();
    await expectLater(add(), throwsA(isA<SqliteException>()));
  });
}
