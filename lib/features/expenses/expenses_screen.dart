import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/month_picker.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../budgets/category_picker.dart';
import 'transaction_sheet.dart';

const _filters = [
  ('All', null),
  ('Expenses', TransactionType.debit),
  ('Income', TransactionType.credit),
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _month = MonthKey.of(DateTime.now());
  TransactionType? _filter;

  // A dismissed row must leave the tree at once, before the database stream
  // catches up, or Dismissible throws.
  final _dismissed = <int>{};

  Future<void> _delete(TransactionRow row) async {
    setState(() => _dismissed.add(row.id));
    final db = ref.read(databaseProvider);
    await db.deleteTransaction(row.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Deleted'),
          duration: const Duration(seconds: 5),
          persist: false, // an action otherwise keeps it up indefinitely
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await db.restoreTransaction(row);
              if (mounted) setState(() => _dismissed.remove(row.id));
            },
          ),
        ),
      );
  }

  Future<void> _categorise(TransactionRow row) async {
    final id = await showCategoryPicker(context);
    if (id == null) return;
    await ref
        .read(databaseProvider)
        .updateTransaction(
          row.id,
          TransactionsCompanion(categoryId: Value(id)),
        );
  }

  // Shows the saved row, which may be in another month or filtered out.
  Future<void> _openSheet([TransactionRow? row]) async {
    final saved = await showTransactionSheet(context, existing: row);
    if (saved == null || !mounted) return;
    setState(() {
      _month = MonthKey.of(saved.occurredAt);
      if (_filter != saved.type) _filter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          MonthPicker(
            value: _month,
            onChanged: (month) => setState(() => _month = month),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add transaction',
        onPressed: _openSheet,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (label, type) in _filters)
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter == type,
                    onSelected: (_) => setState(() => _filter = type),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ref
                .watch(transactionsProvider(_month))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Could not load transactions: $error'),
                  ),
                  data: (rows) => _list(rows, categories),
                ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<TransactionRow> rows, Map<int, Category> categories) {
    final visible = rows.where(
      (r) =>
          !_dismissed.contains(r.id) && (_filter == null || r.type == _filter),
    );
    if (visible.isEmpty) {
      return const Center(child: Text('Nothing here for this month'));
    }
    final localizations = MaterialLocalizations.of(context);
    DateTime? day;
    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // clears the FAB
      children: [
        for (final row in visible) ...[
          if (!DateUtils.isSameDay(day, row.occurredAt))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                localizations.formatFullDate(day = row.occurredAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Dismissible(
            key: ValueKey(row.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _delete(row),
            child: _TransactionTile(
              row: row,
              category: categories[row.categoryId],
              onTap: () => _categorise(row),
              onLongPress: () => _openSheet(row),
            ),
          ),
        ],
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.row,
    required this.category,
    required this.onTap,
    required this.onLongPress,
  });

  final TransactionRow row;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  // Credits keep the whole NEFT descriptor; SPEC 5.1 shows the first 40 characters.
  String get _title {
    final party = row.counterparty;
    if (party == null) {
      return category?.name ??
          (row.type == TransactionType.debit ? 'Expense' : 'Income');
    }
    return party.length > 40 ? party.substring(0, 40) : party;
  }

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(row.occurredAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final uncategorised = row.categoryId == null;
    final credit = row.type == TransactionType.credit;
    final tile = ListTile(
      leading: CategoryAvatar(category),
      title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(uncategorised ? '$time · Tap to categorise' : time),
      trailing: Text(
        '${credit ? '+' : ''}${Money.format(row.amountPaise)}',
        style: TextStyle(
          color: credit ? Colors.green.shade600 : Colors.red.shade400,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
    return uncategorised ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}
