import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/domain/models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('seeds the default categories per type, in order', () async {
    final categories = await db.watchCategories().first;
    Iterable<String> names(CategoryType type) =>
        categories.where((c) => c.type == type).map((c) => c.name);
    expect(names(CategoryType.expense), [
      'Housing',
      'Food',
      'Groceries',
      'Utilities',
      'Transportation',
      'Shopping',
      'Clothes',
      'Going out',
      'Entertainment',
      'Subscriptions',
      'Extras',
      'Medicines',
      'Investments',
    ]);
    expect(names(CategoryType.income), ['Salary', 'Investments']);
    expect(categories.first.emoji, '🏠');
  });

  test(
    'a new category goes last and a taken name returns the old one',
    () async {
      Future<Category> add(String name) => db.addCategory(
        name: name,
        type: CategoryType.income,
        emoji: '🪙',
        color: 1,
      );
      final tips = await add(' Tips ');
      expect(tips.name, 'Tips');
      expect((await add('tips')).id, tips.id);
      final income = (await db.watchCategories().first).where(
        (c) => c.type == CategoryType.income,
      );
      expect(income.map((c) => c.name), ['Salary', 'Investments', 'Tips']);
      // Unique per type only.
      final expense = await db.addCategory(
        name: 'Tips',
        type: CategoryType.expense,
        emoji: '🪙',
        color: 1,
      );
      expect(expense.id, isNot(tips.id));
    },
  );

  test('reorder persists and only touches the given type', () async {
    final before = await db.watchCategories().first;
    final ids = [
      for (final c in before)
        if (c.type == CategoryType.income) c.id,
    ];
    await db.reorderCategories(ids.reversed.toList());
    final after = await db.watchCategories().first;
    expect(
      after.where((c) => c.type == CategoryType.income).map((c) => c.name),
      ['Investments', 'Salary'],
    );
    expect(
      after.where((c) => c.type == CategoryType.expense).first.name,
      'Housing',
    );
  });

  test(
    'delete uncategorises rows, drops budgets and clears the filter',
    () async {
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.debit,
          amountPaise: 100,
          occurredAt: DateTime(2026, 10, 30),
          source: TransactionSource.manual,
          categoryId: const Value(1),
        ),
      );
      await db.setBudget(1, null, 500);
      await db.setCategoryFilter({1});

      await db.deleteCategory(1);

      expect((await db.select(db.transactions).getSingle()).categoryId, isNull);
      expect(await db.select(db.budgets).get(), isEmpty);
      expect(await db.watchCategoryFilter().first, isNull);
      expect(
        (await db.watchCategories().first).map((c) => c.id),
        isNot(contains(1)),
      );
    },
  );

  test('archiving keeps the row and leaves a wider filter narrowed', () async {
    await db.setCategoryFilter({1, 2});
    await db.setCategoryArchived(1, true);
    expect(
      (await db.watchCategories().first)
          .firstWhere((c) => c.id == 1)
          .isArchived,
      isTrue,
    );
    expect(await db.watchCategoryFilter().first, {2});
    await db.setCategoryArchived(1, false);
    expect(await db.watchCategoryFilter().first, {2});
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
