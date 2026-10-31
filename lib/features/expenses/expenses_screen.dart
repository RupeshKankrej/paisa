import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/month_picker.dart';
import '../../core/money.dart';
import '../../core/period.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../budgets/category_picker.dart';
import 'transaction_sheet.dart';

const _filters = [
  ('All', ExpenseFilter.all),
  ('Expenses', ExpenseFilter.expenses),
  ('Income', ExpenseFilter.income),
  ('Uncategorised', ExpenseFilter.uncategorised),
];

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key, this.addRequest});

  /// A new value opens the add sheet (the widget's add link).
  final String? addRequest;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  // A dismissed row must leave the tree at once, before the database stream
  // catches up, or Dismissible throws.
  final _dismissed = <int>{};

  // Its own messenger, because the tab shell's outer Scaffold would otherwise
  // show the snackbar over this Scaffold's FAB instead of lifting it.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.addRequest != null) _openSheetAfterFrame();
  }

  @override
  void didUpdateWidget(ExpensesScreen old) {
    super.didUpdateWidget(old);
    if (widget.addRequest != null && widget.addRequest != old.addRequest) {
      _openSheetAfterFrame();
    }
  }

  void _openSheetAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A second widget tap must not stack a sheet on one left open.
        if (mounted && !_sheetOpen) _openSheet();
      });

  Future<void> _delete(TransactionRow row) async {
    setState(() => _dismissed.add(row.id));
    final db = ref.read(databaseProvider);
    await db.deleteTransaction(row.id);
    if (!mounted) return;
    _messenger.currentState!
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

  // Shows the saved row, which may be in another month or filtered out.
  Future<void> _openSheet([TransactionRow? row]) async {
    _sheetOpen = true;
    final saved = await showTransactionSheet(
      context,
      existing: row,
    ).whenComplete(() => _sheetOpen = false);
    if (saved == null || !mounted) return;
    ref.read(pickedMonthProvider.notifier).state = Period.containing(
      saved.occurredAt,
      ref.read(salaryDayProvider).value,
    ).key;
    if (!ref
        .read(expenseFilterProvider)
        .matches(saved.type, saved.categoryId)) {
      ref.read(expenseFilterProvider.notifier).state = ExpenseFilter.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final selected = ref.watch(expenseFilterProvider);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expenses'),
          actions: const [MonthPicker(), SizedBox(width: 8)],
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
                  for (final (label, filter) in _filters)
                    ChoiceChip(
                      label: Text(label),
                      selected: selected == filter,
                      onSelected: (_) =>
                          ref.read(expenseFilterProvider.notifier).state =
                              filter,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ref
                  .watch(transactionsProvider(ref.watch(selectedMonthProvider)))
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text('Could not load transactions: $error'),
                    ),
                    data: (rows) => _list(rows, categories, selected),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(
    List<TransactionRow> rows,
    Map<int, Category> categories,
    ExpenseFilter filter,
  ) {
    final visible = rows.where(
      (r) => !_dismissed.contains(r.id) && filter.matches(r.type, r.categoryId),
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
            child: TransactionTile(
              row: row,
              category: categories[row.categoryId],
              onTap: () => categoriseTransaction(context, ref, row),
              onLongPress: () => _openSheet(row),
            ),
          ),
        ],
      ],
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
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
