import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_dialog.dart';
import '../../app/month_picker.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import 'category_picker.dart';
import 'month_summary_card.dart';

const _levelColors = {
  BudgetLevel.under: Colors.green,
  BudgetLevel.near: Colors.amber,
  BudgetLevel.over: Colors.red,
};

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _editLimit(
    BuildContext context,
    WidgetRef ref,
    Category category,
    String month,
    Map<String?, int> amounts,
  ) async {
    final result = await showAmountDialog(
      context,
      title: '${category.name} limit',
      fields: [
        (
          label: 'Every month',
          initial: amounts[null],
          helper: 'Blank means no limit',
        ),
        (
          label: '${MonthKey.label(month)} only',
          initial: amounts[month],
          helper: 'Blank uses the monthly limit',
        ),
      ],
    );
    if (result == null) return;
    final db = ref.read(databaseProvider);
    await db.setBudget(category.id, null, result[0]);
    await db.setBudget(category.id, month, result[1]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final categories = ref.watch(categoriesProvider);
    final transactions = ref.watch(transactionsProvider(month));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: const [MonthPicker(), SizedBox(width: 8)],
      ),
      body: switch ((categories, transactions)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('Could not load categories: $error')),
        (AsyncData(value: final categories), AsyncData(value: final rows)) =>
          _list(context, ref, month, categories, rows),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    String month,
    List<Category> categories,
    List<TransactionRow> rows,
  ) {
    final budgets = ref.watch(budgetAmountsProvider).value ?? const {};
    final salary = resolveAmount(
      ref.watch(salaryAmountsProvider).value ?? const {},
      month,
    );
    final spend = spendOf(rows);
    final uncategorised = spend[null] ?? 0;
    final limits = sumPaise(
      categories.map(
        (c) => resolveAmount(budgets[c.id] ?? const {}, month) ?? 0,
      ),
    );
    return ListView(
      children: [
        MonthSummaryCard(rows: rows),
        if (salary != null && limits > salary)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Category limits add up to ${Money.format(limits)}, '
              'more than the salary by ${Money.format(limits - salary)}.',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        if (uncategorised > 0)
          ListTile(
            leading: const CategoryAvatar(null),
            title: const Text('Uncategorised'),
            subtitle: Text(Money.format(uncategorised)),
          ),
        for (final category in categories)
          _CategoryTile(
            category: category,
            spent: spend[category.id] ?? 0,
            limit: resolveAmount(budgets[category.id] ?? const {}, month),
            onTap: () => _editLimit(
              context,
              ref,
              category,
              month,
              budgets[category.id] ?? const {},
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.spent,
    required this.limit,
    required this.onTap,
  });

  final Category category;
  final int spent;
  final int? limit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limit = this.limit;
    return ListTile(
      leading: CategoryAvatar(category),
      title: Text(category.name),
      subtitle: limit == null
          ? Text(Money.format(spent))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                Text('${Money.format(spent)} / ${Money.format(limit)}'),
                LinearProgressIndicator(
                  value: spentFraction(spent, limit),
                  color: _levelColors[budgetLevel(spent, limit)],
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}
