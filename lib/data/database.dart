import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/models.dart';

part 'database.g.dart';

class TrackedSenders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get matchPattern => text()();
  TextColumn get bank => text()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()(); // ARGB
  TextColumn get icon => text()();
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
  TextColumn get bank => text().nullable()();
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'paisa'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((b) => b.insertAll(categories, _seedCategories));
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Stream<List<Category>> watchCategories() =>
      (select(categories)
            ..where((c) => c.isArchived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();
}

final _seedCategories =
    [
      ('Food', 0xFFE57373, 'restaurant'),
      ('Travel', 0xFF64B5F6, 'directions_car'),
      ('Rent', 0xFF8D6E63, 'home'),
      ('Bills', 0xFFFFB74D, 'receipt_long'),
      ('Shopping', 0xFFBA68C8, 'shopping_bag'),
      ('Health', 0xFF81C784, 'favorite'),
      ('Entertainment', 0xFF4DB6AC, 'movie'),
      ('Other', 0xFF90A4AE, 'category'),
    ].indexed.map(
      (e) => CategoriesCompanion.insert(
        name: e.$2.$1,
        color: e.$2.$2,
        icon: e.$2.$3,
        sortOrder: e.$1,
      ),
    );
