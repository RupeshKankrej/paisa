import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/period.dart';
import '../domain/budget.dart';
import '../domain/models.dart';
import '../domain/widget_summary.dart';
import '../features/ingest/inbox_reader.dart';
import '../widget/widget_bridge.dart';
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

/// The current period's widget_summary.json, null until the data has loaded.
/// Rebuilds on any change to what it reads; the app also refreshes it on resume,
/// when the period may have rolled over.
final widgetSummaryProvider = Provider<String?>((ref) {
  final salaryDay = ref.watch(salaryDayProvider);
  if (!salaryDay.hasValue) return null;
  final now = DateTime.now();
  final month = Period.containing(now, salaryDay.value).key;
  final rows = ref.watch(transactionsProvider(month)).value;
  final salaries = ref.watch(salaryAmountsProvider).value;
  final categories = ref.watch(categoriesProvider).value;
  if (rows == null || salaries == null || categories == null) return null;
  return widgetSummaryJson(
    month: month,
    spend: spendByCategory(
      rows
          .where((r) => r.type == TransactionType.debit)
          .map((r) => (r.categoryId, r.amountPaise)),
    ),
    salary: resolveAmount(salaries, month),
    categories: {
      for (final c in categories) c.id: (name: c.name, color: c.color),
    },
    now: now,
  );
});

final widgetPublisherProvider = Provider<Future<void> Function(String)>(
  (ref) => publishWidgetSummary,
);
