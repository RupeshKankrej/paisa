import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((b) => b.insertAll(categories, _seedCategories));
      await into(trackedSenders).insert(_seedSender);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(settings);
        await into(trackedSenders).insert(_seedSender);
      }
    },
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Stream<List<Category>> watchCategories() =>
      (select(categories)
            ..where((c) => c.isArchived.equals(false))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .watch();

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
}

final _seedSender = TrackedSendersCompanion.insert(
  label: 'HDFC Bank',
  matchPattern: 'HDFC Bank',
  bank: Bank.hdfc,
);

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
