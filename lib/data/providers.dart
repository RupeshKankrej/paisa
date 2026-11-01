import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/period.dart';
import '../domain/budget.dart';
import '../domain/dashboards.dart';
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

/// Archived ones included, as old rows still need their name and colour.
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).watchCategories(),
);

/// What a picker offers: not archived, of one type.
List<Category> pickableCategories(List<Category> all, CategoryType type) => [
  for (final c in all)
    if (c.type == type && !c.isArchived) c,
];

/// Spend per category for rows of any type; credits are left out.
Map<int?, int> spendOf(List<TransactionRow> rows) => spendByCategory(
  rows
      .where((r) => r.type == TransactionType.debit)
      .map((r) => (r.categoryId, r.amountPaise)),
);

/// The month's resolved limit of each expense category that has one, in order.
Map<int, int> expenseLimits(
  List<Category> categories,
  Map<int, Map<String?, int>> budgets,
  String month,
) => {
  for (final c in pickableCategories(categories, CategoryType.expense))
    c.id: ?resolveAmount(budgets[c.id] ?? const {}, month),
};

const appearanceKey = 'appearance';
const incomeLeftPercentKey = 'income_left_percent';

final themeModeProvider = StreamProvider<ThemeMode>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting(appearanceKey)
      .map((name) => ThemeMode.values.asNameMap()[name] ?? ThemeMode.system),
);

final incomeLeftPercentProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting(incomeLeftPercentKey)
      .map((value) => value != null),
);

final categoryFilterProvider = StreamProvider<Set<int>?>(
  (ref) => ref.watch(databaseProvider).watchCategoryFilter(),
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

/// Each Analytics card's own month, independent of the app-wide one and of the
/// other cards. Null means the current period.
final cardMonthProvider = StateProvider.family<String?, String>(
  (ref, card) => null,
);

final selectedMonthProvider = Provider<String>(
  (ref) =>
      ref.watch(pickedMonthProvider) ??
      Period.containing(DateTime.now(), ref.watch(salaryDayProvider).value).key,
);

final expenseFilterProvider = StateProvider<ExpenseFilter>(
  (ref) => ExpenseFilter.all,
);

/// A second add link or FAB tap must not stack a sheet on one left open.
final transactionSheetOpenProvider = StateProvider<bool>((ref) => false);

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
  final debits = rows.where((r) => r.type == TransactionType.debit);
  final period = Period.forMonthKey(month, salaryDay.value);
  return widgetSummaryJson(
    month: month,
    spend: spendByCategory(debits.map((r) => (r.categoryId, r.amountPaise))),
    dailySpent: [
      for (final day in dailySpend(
        debits.map((r) => (r.occurredAt, r.amountPaise)),
        period.start,
        period.end,
      ))
        day.paise,
    ],
    quickCategories: [
      for (final c in pickableCategories(
        categories,
        CategoryType.expense,
      ).take(4))
        (id: c.id, name: c.name, emoji: c.emoji),
    ],
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
