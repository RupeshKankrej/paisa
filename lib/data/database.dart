import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/period.dart';
import '../domain/categories.dart';
import '../domain/models.dart';

part 'database.g.dart';

class TrackedSenders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get matchPattern => text()();
  TextColumn get bank => textEnum<Bank>()();
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()(); // ARGB
  TextColumn get emoji => text().withDefault(const Constant('🎯'))();
  TextColumn get type =>
      textEnum<CategoryType>().withDefault(const Constant('expense'))();
  IntColumn get sortOrder => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

// COALESCE because SQLite treats NULLs as distinct: allows one default row only.
@TableIndex.sql(
  "CREATE UNIQUE INDEX budgets_category_month ON budgets (category_id, COALESCE(month, ''))",
)
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get month => text().nullable()();
  IntColumn get amountPaise => integer()();
}

@DataClassName('SalaryRow')
@TableIndex.sql(
  "CREATE UNIQUE INDEX salary_month ON salary (COALESCE(month, ''))",
)
class Salary extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get month => text().nullable()();
  IntColumn get amountPaise => integer()();
}

@DataClassName('TransactionRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => textEnum<TransactionType>()();
  IntColumn get amountPaise => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get counterparty => text().nullable()();
  TextColumn get accountLast4 => text().nullable()();
  TextColumn get bank => textEnum<Bank>().nullable()();
  TextColumn get refNo => text().nullable()();
  TextColumn get source => textEnum<TransactionSource>()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  TextColumn get rawText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('IngestLogRow')
class IngestLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text().unique()();
  DateTimeColumn get ingestedAt => dateTime()();
  TextColumn get status => textEnum<IngestStatus>()();
  TextColumn get refNo => text().nullable()();
  // Failed messages have no transaction, and SPEC 5.1 must still show their text.
  TextColumn get rawText => text().nullable()();
}

@DriftDatabase(
  tables: [
    TrackedSenders,
    Categories,
    Budgets,
    Salary,
    Transactions,
    IngestLog,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'paisa'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch(
        (b) => b.insertAll(categories, [
          ..._seeds(_expenseSeeds, CategoryType.expense),
          ..._seeds(_incomeSeeds, CategoryType.income),
        ]),
      );
      await into(trackedSenders).insert(_seedSender);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(settings);
        await into(trackedSenders).insert(_seedSender);
      }
      if (from < 3) {
        // Matches on colour, so categories added by the user move with the seed.
        for (final (i, old) in _phase1Colors.indexed) {
          await customStatement(
            'UPDATE categories SET color = ? WHERE color = ?',
            [categoryColors[i], old],
          );
        }
      }
      if (from < 4) {
        // Ids stay, so transactions and budgets keep their links. The expense
        // seed changed too, but renaming someone's categories is not ours to do.
        await m.addColumn(categories, categories.emoji);
        await m.addColumn(categories, categories.type);
        await customStatement('''
          UPDATE categories SET emoji = CASE icon
            WHEN 'restaurant' THEN '🍽️'
            WHEN 'directions_car' THEN '🚗'
            WHEN 'home' THEN '🏠'
            WHEN 'receipt_long' THEN '🧾'
            WHEN 'shopping_bag' THEN '🛍️'
            WHEN 'favorite' THEN '🩺'
            WHEN 'movie' THEN '🎬'
            ELSE '📦' END
        ''');
        await customStatement('ALTER TABLE categories DROP COLUMN icon');
        await batch(
          (b) => b.insertAll(
            categories,
            _seeds(_incomeSeeds, CategoryType.income),
          ),
        );
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  /// Archived ones too, as old rows still need their name and colour.
  Stream<List<Category>> watchCategories() => (select(
    categories,
  )..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).watch();

  Stream<List<TrackedSender>> watchTrackedSenders() =>
      select(trackedSenders).watch();

  Stream<int> watchImportedCount() => ingestLog
      .count(where: (l) => l.status.equalsValue(IngestStatus.parsed))
      .watchSingle();

  Stream<List<IngestLogRow>> watchFailedMessages() =>
      (select(ingestLog)
            ..where((l) => l.status.equalsValue(IngestStatus.failed))
            ..orderBy([
              (l) => OrderingTerm.desc(l.ingestedAt),
              (l) => OrderingTerm.desc(l.id),
            ]))
          .watch();

  /// Newest first.
  Stream<List<TransactionRow>> watchTransactions(Period period) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.occurredAt.isBiggerOrEqualValue(period.start) &
                  t.occurredAt.isSmallerThanValue(period.end),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.occurredAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .watch();

  // shortcut: charts total every row in Dart, fine for one person's messages;
  // move to SQL aggregates if the Dashboards tab ever feels slow.
  Stream<List<TransactionRow>> watchAllTransactions() =>
      select(transactions).watch();

  /// Oldest and newest transaction dates; both null when there are none.
  Stream<(DateTime?, DateTime?)> watchTransactionBounds() {
    final first = transactions.occurredAt.min();
    final last = transactions.occurredAt.max();
    return (selectOnly(transactions)..addColumns([first, last]))
        .map((row) => (row.read(first), row.read(last)))
        .watchSingle();
  }

  Future<void> addTransaction(TransactionsCompanion row) =>
      into(transactions).insert(row);

  Future<void> updateTransaction(int id, TransactionsCompanion changes) =>
      (update(transactions)..where((t) => t.id.equals(id))).write(
        changes.copyWith(updatedAt: Value(DateTime.now())),
      );

  /// ingest_log is left alone, so a deleted SMS is not imported again.
  Future<void> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> restoreTransaction(TransactionRow row) =>
      into(transactions).insert(row);

  /// Null means calendar months (SPEC 5.11).
  Stream<int?> watchSalaryDay() =>
      (select(settings)..where((s) => s.key.equals(_salaryDayKey)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : int.tryParse(row.value));

  Future<void> setSalaryDay(int? day) => day == null
      ? (delete(settings)..where((s) => s.key.equals(_salaryDayKey))).go()
      : into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: _salaryDayKey, value: '$day'),
        );

  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  /// A null [value] removes the row.
  Future<void> setSetting(String key, String? value) => value == null
      ? (delete(settings)..where((s) => s.key.equals(key))).go()
      : into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );

  /// Amounts by month; the null key is the default.
  Stream<Map<String?, int>> watchSalaryAmounts() =>
      select(salary)
          .watch()
          .map((rows) => {for (final row in rows) row.month: row.amountPaise});

  /// A null [month] is the default; null [paise] removes the row.
  Future<void> setSalary(String? month, int? paise) => transaction(() async {
    await (delete(salary)..where(
          (s) => month == null ? s.month.isNull() : s.month.equals(month),
        ))
        .go();
    if (paise != null) {
      await into(
        salary,
      ).insert(SalaryCompanion.insert(month: Value(month), amountPaise: paise));
    }
  });

  /// Amounts by month for each category id; the null key is the default.
  Stream<Map<int, Map<String?, int>>> watchBudgetAmounts() =>
      select(budgets).watch().map((rows) {
        final amounts = <int, Map<String?, int>>{};
        for (final row in rows) {
          (amounts[row.categoryId] ??= {})[row.month] = row.amountPaise;
        }
        return amounts;
      });

  /// A null [month] is the default; null [paise] removes the row.
  Future<void> setBudget(int categoryId, String? month, int? paise) =>
      transaction(() async {
        await (delete(budgets)..where(
              (b) =>
                  b.categoryId.equals(categoryId) &
                  (month == null ? b.month.isNull() : b.month.equals(month)),
            ))
            .go();
        if (paise != null) {
          await into(budgets).insert(
            BudgetsCompanion.insert(
              categoryId: categoryId,
              month: Value(month),
              amountPaise: paise,
            ),
          );
        }
      });

  /// Returns the existing category if the name is taken for that type, so a
  /// double tap on a quick add cannot create two.
  Future<Category> addCategory({
    required String name,
    required CategoryType type,
    required String emoji,
    required int color,
  }) => transaction(() async {
    final all = await select(categories).get();
    for (final c in all) {
      if (c.type == type && nameTaken([c.name], name)) return c;
    }
    final last = all.fold(-1, (a, c) => a > c.sortOrder ? a : c.sortOrder);
    return into(categories).insertReturning(
      CategoriesCompanion.insert(
        name: name.trim(),
        color: color,
        emoji: Value(emoji),
        type: Value(type),
        sortOrder: last + 1,
      ),
    );
  });

  Future<void> updateCategory(
    int id, {
    required String name,
    required String emoji,
    required int color,
  }) => (update(categories)..where((c) => c.id.equals(id))).write(
    CategoriesCompanion(
      name: Value(name.trim()),
      emoji: Value(emoji),
      color: Value(color),
    ),
  );

  Future<void> setCategoryArchived(int id, bool archived) =>
      transaction(() async {
        await (update(categories)..where((c) => c.id.equals(id))).write(
          CategoriesCompanion(isArchived: Value(archived)),
        );
        if (archived) await _dropFromFilter(id);
      });

  Future<int> countCategoryTransactions(int id) =>
      transactions.count(where: (t) => t.categoryId.equals(id)).getSingle();

  /// Its transactions become uncategorised; its budgets go with it.
  Future<void> deleteCategory(int id) => transaction(() async {
    await (update(transactions)..where((t) => t.categoryId.equals(id))).write(
      TransactionsCompanion(
        categoryId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (delete(budgets)..where((b) => b.categoryId.equals(id))).go();
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    await _dropFromFilter(id);
  });

  /// [ids] in their new order.
  Future<void> reorderCategories(List<int> ids) => transaction(() async {
    for (final (i, id) in ids.indexed) {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(sortOrder: Value(i)),
      );
    }
  });

  /// Null means all categories. Kept across launches until cleared (SPEC 5.14).
  Stream<Set<int>?> watchCategoryFilter() =>
      (select(settings)..where((s) => s.key.equals(_categoryFilterKey)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : decodeFilter(row.value));

  Future<void> setCategoryFilter(Set<int>? filter) => filter == null
      ? (delete(settings)..where((s) => s.key.equals(_categoryFilterKey))).go()
      : into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _categoryFilterKey,
            value: encodeFilter(filter),
          ),
        );

  // A filter left holding only a removed category would hide everything.
  Future<void> _dropFromFilter(int id) async {
    final row = await (select(
      settings,
    )..where((s) => s.key.equals(_categoryFilterKey))).getSingleOrNull();
    final filter = row == null ? null : decodeFilter(row.value);
    if (filter == null || !filter.remove(id)) return;
    await setCategoryFilter(filter.isEmpty ? null : filter);
  }
}

const _salaryDayKey = 'salary_day';
const _categoryFilterKey = 'category_filter';

final _seedSender = TrackedSendersCompanion.insert(
  label: 'HDFC Bank',
  matchPattern: 'HDFC Bank',
  bank: Bank.hdfc,
);

const _phase1Colors = [
  0xFFE57373,
  0xFF64B5F6,
  0xFF8D6E63,
  0xFFFFB74D,
  0xFFBA68C8,
  0xFF81C784,
  0xFF4DB6AC,
  0xFF90A4AE,
];

const _expenseSeeds = [
  ('Housing', '🏠'),
  ('Food', '🍽️'),
  ('Groceries', '🛒'),
  ('Utilities', '💡'),
  ('Transportation', '🚗'),
  ('Shopping', '🛍️'),
  ('Clothes', '👕'),
  ('Going out', '🍻'),
  ('Entertainment', '🍿'),
  ('Subscriptions', '📅'),
  ('Extras', '🤷'),
  ('Medicines', '💊'),
  ('Investments', '📈'),
];

const _incomeSeeds = [('Salary', '💰'), ('Investments', '📊')];

List<CategoriesCompanion> _seeds(
  List<(String, String)> seeds,
  CategoryType type,
) => [
  for (final (i, (name, emoji)) in seeds.indexed)
    CategoriesCompanion.insert(
      name: name,
      color: categoryColors[i % categoryColors.length],
      emoji: Value(emoji),
      type: Value(type),
      sortOrder: i,
    ),
];
