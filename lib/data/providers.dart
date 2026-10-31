import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/period.dart';
import '../domain/models.dart';
import '../features/ingest/inbox_reader.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).watchCategories(),
);

final trackedSendersProvider = StreamProvider<List<TrackedSender>>(
  (ref) => ref.watch(databaseProvider).watchTrackedSenders(),
);

final importedCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchImportedCount(),
);

final failedMessagesProvider = StreamProvider<List<IngestLogRow>>(
  (ref) => ref.watch(databaseProvider).watchFailedMessages(),
);

final transactionsProvider = StreamProvider.autoDispose
    .family<List<TransactionRow>, String>(
      (ref, month) => ref
          .watch(databaseProvider)
          .watchTransactions(
            Period.forMonthKey(month, ref.watch(salaryDayProvider).value),
          ),
    );

final allTransactionsProvider = StreamProvider<List<TransactionRow>>(
  (ref) => ref.watch(databaseProvider).watchAllTransactions(),
);

final salaryDayProvider = StreamProvider<int?>(
  (ref) => ref.watch(databaseProvider).watchSalaryDay(),
);

final salaryAmountsProvider = StreamProvider<Map<String?, int>>(
  (ref) => ref.watch(databaseProvider).watchSalaryAmounts(),
);

final budgetAmountsProvider = StreamProvider<Map<int, Map<String?, int>>>(
  (ref) => ref.watch(databaseProvider).watchBudgetAmounts(),
);

/// Null until a month is chosen, which means the current one.
final pickedMonthProvider = StateProvider<String?>((ref) => null);

final selectedMonthProvider = Provider<String>(
  (ref) =>
      ref.watch(pickedMonthProvider) ??
      Period.containing(DateTime.now(), ref.watch(salaryDayProvider).value).key,
);

final expenseFilterProvider = StateProvider<ExpenseFilter>(
  (ref) => ExpenseFilter.all,
);

final transactionBoundsProvider = StreamProvider<(DateTime?, DateTime?)>(
  (ref) => ref.watch(databaseProvider).watchTransactionBounds(),
);

/// Launch and resume can overlap, and two drains must not share one claimed file.
final inboxDrainProvider = Provider<Future<void> Function()>((ref) {
  Future<void>? running;
  return () =>
      running ??= drainInbox(ref.read(databaseProvider))
          .whenComplete(() => running = null);
});
