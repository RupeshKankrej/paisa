import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../data/database.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../domain/quanto_csv.dart';

/// Every transaction, in the Quanto columns.
Future<String> exportCsv(AppDatabase db) async {
  final names = {
    for (final c in await db.select(db.categories).get()) c.id: c.name,
  };
  final rows = await db.select(db.transactions).get();
  return quantoCsv([
    for (final r in rows)
      QuantoRow(
        date: r.occurredAt,
        paise: r.amountPaise,
        type: r.type,
        category: names[r.categoryId] ?? '',
        name: r.counterparty ?? '',
        account: r.accountLast4 ?? '',
      ),
  ]);
}

/// All user data, with nothing lost, unlike the CSV. The ingest log stays out:
/// it is only a dedup store, and can hold the text of unrelated messages.
Future<String> exportJson(AppDatabase db, DateTime now) async {
  const serializer = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );
  List<Map<String, dynamic>> json<D extends DataClass>(List<D> rows) => [
    for (final r in rows) r.toJson(serializer: serializer),
  ];
  return const JsonEncoder.withIndent('  ').convert({
    'schema_version': db.schemaVersion,
    'exported_at': now.toUtc().toIso8601String(),
    'categories': json(await db.select(db.categories).get()),
    'budgets': json(await db.select(db.budgets).get()),
    'salary': json(await db.select(db.salary).get()),
    'tracked_senders': json(await db.select(db.trackedSenders).get()),
    'transactions': json(await db.select(db.transactions).get()),
  });
}

/// What an import would do; nothing is written yet.
typedef ImportPlan = ({
  List<QuantoRow> newRows,
  int alreadyThere,
  List<int> badLines,
  List<String> newCategories,
});

Future<ImportPlan> planImport(AppDatabase db, QuantoParse parsed) async {
  final existing = await db.select(db.transactions).get();
  final newRows = rowsNotIn(parsed.rows, [
    for (final t in existing)
      quantoKey(t.occurredAt, t.amountPaise, t.type, t.counterparty),
  ]);
  final categories = await db.select(db.categories).get();
  final newCategories = <String>{};
  for (final r in newRows) {
    if (r.category.isEmpty) continue;
    final type = _categoryType(r.type);
    final taken = categories.where((c) => c.type == type).map((c) => c.name);
    if (!nameTaken(taken, r.category) &&
        !nameTaken(newCategories, r.category)) {
      newCategories.add(r.category);
    }
  }
  return (
    newRows: newRows,
    alreadyThere: parsed.rows.length - newRows.length,
    badLines: parsed.badLines,
    newCategories: newCategories.toList(),
  );
}

/// All or nothing, so a failure cannot leave half a file to dedup against.
Future<void> applyImport(
  AppDatabase db,
  List<QuantoRow> rows,
) => db.transaction(() async {
  final ids = <String, int>{};
  var nextColor = 0;
  for (final r in rows) {
    int? categoryId;
    if (r.category.isNotEmpty) {
      final type = _categoryType(r.type);
      final cacheKey = '${type.name}|${r.category.toLowerCase()}';
      categoryId = ids[cacheKey] ??= (await db.addCategory(
        name: r.category,
        type: type,
        emoji: defaultCategoryEmoji,
        color: categoryColors[nextColor++ % categoryColors.length],
      )).id;
    }
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: r.type,
        amountPaise: r.paise,
        // The file has only a date; midday keeps it on that day in any zone.
        occurredAt: r.date.copyWith(hour: 12),
        counterparty: Value(r.name.isEmpty ? null : r.name),
        source: TransactionSource.manual,
        categoryId: Value(categoryId),
      ),
    );
  }
});

CategoryType _categoryType(TransactionType type) =>
    type == TransactionType.debit ? CategoryType.expense : CategoryType.income;

/// A consistent copy of the live database, even mid-write. [path] is replaced.
Future<void> writeBackup(AppDatabase db, String path) async {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  await db.customStatement('VACUUM INTO ?', [path]);
}

/// Thrown with a message fit to show when a file cannot be restored.
class RestoreException implements Exception {
  const RestoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Copies [source] to [workPath], upgrades that copy to this schema and checks
/// it, without touching live data. Returns its transaction count, to confirm.
Future<int> prepareRestore(
  String source,
  String workPath,
  int schemaVersion,
) async {
  final file = File(source);
  final Uint8List head;
  final raf = await file.open();
  try {
    head = await raf.read(64);
  } finally {
    await raf.close();
  }
  const notABackup = RestoreException('This file is not a Paisa backup.');
  if (head.length < 64 ||
      ascii.decode(head.sublist(0, 15), allowInvalid: true) !=
          'SQLite format 3') {
    throw notABackup;
  }
  final version = ByteData.sublistView(head).getUint32(60);
  // Zero would look like a new database, and be seeded instead of refused.
  if (version == 0) throw notABackup;
  if (version > schemaVersion) {
    throw const RestoreException(
      'This backup is from a newer version of Paisa. Update the app first.',
    );
  }

  await file.copy(workPath);
  final copy = AppDatabase(NativeDatabase(File(workPath)));
  try {
    final check = await copy.customSelect('PRAGMA integrity_check').getSingle();
    if (check.read<String>('integrity_check') != 'ok') throw notABackup;
    for (final table in copy.allTables) {
      await copy.select(table).get(); // every column of every table must exist
    }
    return await copy.transactions.count().getSingle();
  } on RestoreException {
    rethrow;
  } on Exception {
    throw notABackup;
  } finally {
    await copy.close();
  }
}

/// Replaces all data with the prepared copy at [path], in one transaction, so a
/// failure leaves the live data as it was. Columns are named because migrated
/// databases keep them in a different order from new ones.
Future<void> applyRestore(AppDatabase db, String path) async {
  await db.customStatement('ATTACH DATABASE ? AS restored', [path]);
  try {
    await db.transaction(() async {
      // allTables lists parents first, so foreign keys hold both ways.
      for (final table in db.allTables.toList().reversed) {
        await db.customStatement('DELETE FROM "${table.actualTableName}"');
      }
      for (final table in db.allTables) {
        final columns = table.$columns.map((c) => '"${c.name}"').join(', ');
        await db.customStatement(
          'INSERT INTO main."${table.actualTableName}" ($columns) '
          'SELECT $columns FROM restored."${table.actualTableName}"',
        );
      }
    });
  } finally {
    await db.customStatement('DETACH DATABASE restored');
  }
  db.markTablesUpdated(db.allTables);
}
