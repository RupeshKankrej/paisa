import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/month_picker.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../budgets/category_picker.dart';
import '../budgets/month_summary_card.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/transaction_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [MonthPicker(), SizedBox(width: 8)],
      ),
      body: ref
          .watch(transactionsProvider(month))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load transactions: $error')),
            data: (rows) => _list(context, ref, rows),
          ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<TransactionRow> rows) {
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final uncategorised = rows.where((r) => r.categoryId == null).length;
    return ListView(
      children: [
        MonthSummaryCard(rows: rows),
        if (uncategorised > 0)
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text('$uncategorised uncategorised'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ref.read(expenseFilterProvider.notifier).state =
                  ExpenseFilter.uncategorised;
              context.go('/expenses');
            },
          ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Nothing here for this month',
              textAlign: TextAlign.center,
            ),
          ),
        for (final row in rows.take(5))
          TransactionTile(
            row: row,
            category: categories[row.categoryId],
            onTap: () => categoriseTransaction(context, ref, row),
            onLongPress: () => showTransactionSheet(context, existing: row),
          ),
      ],
    );
  }
}
