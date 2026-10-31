import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/month_picker.dart';
import '../../app/shell_widgets.dart';
import '../../core/money.dart';
import '../../core/period.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../budgets/category_picker.dart';
import 'day_bar_chart.dart';
import 'transaction_sheet.dart';
import '../../app/glass.dart';
import '../../core/theme/motion.dart';

import 'package:flutter/services.dart';

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
        if (mounted) openTransactionSheet(context, ref);
      });

  Future<void> _delete(TransactionRow row) async {
    setState(() => _dismissed.add(row.id));
    final db = ref.read(databaseProvider);
    await db.deleteTransaction(row.id);
    if (!mounted) return;
    showDeletedSnackBar(_messenger.currentState!, db, row, () {
      if (mounted) setState(() => _dismissed.remove(row.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final selected = ref.watch(expenseFilterProvider);
    final month = ref.watch(selectedMonthProvider);
    final transactions = ref.watch(transactionsProvider(month));
    final categoryFilter = ref.watch(categoryFilterProvider).value;
    List<TransactionRow> narrowed(List<TransactionRow> rows) => [
      for (final r in rows)
        if (filterMatches(categoryFilter, r.categoryId)) r,
    ];
    final rows = narrowed(transactions.value ?? const []);
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: floatingTabAppBar(),
        extendBodyBehindAppBar: true,
        floatingActionButton: const AddFab(),
        body: ListView(
          padding: listClearance(context),
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Fills the gap above the header when iOS bounces the list.
                Positioned(
                  key: Key('header-overscroll-fill'),
                  left: 0,
                  right: 0,
                  top: -2000,
                  height: 2000,
                  child: ColoredBox(color: context.palette.heroTop),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [context.palette.heroTop, context.palette.bg],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(top: belowFloatingBar(context)),
                    // Inside the gradient, so only the figures follow a swipe.
                    child: MonthSwipe(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: MonthPicker()),
                          Center(
                            child: HeroAmount(sumPaise(spendOf(rows).values)),
                          ),
                          const SizedBox(height: 16),
                          DayBarChart(
                            rows: rows,
                            period: Period.forMonthKey(
                              month,
                              ref.watch(salaryDayProvider).value,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                spacing: 8,
                children: [
                  // First, so an active filter is never scrolled out of sight.
                  GlassChip(
                    child: ChoiceChip(
                      label: Text(filterLabel(categoryFilter)),
                      selected: categoryFilter != null,
                      onSelected: (_) =>
                          showCategoryFilter(context, CategoryType.expense),
                    ),
                  ),
                  for (final (label, filter) in _filters)
                    GlassChip(
                      child: ChoiceChip(
                        label: Text(label),
                        selected: selected == filter,
                        onSelected: (_) =>
                            ref.read(expenseFilterProvider.notifier).state =
                                filter,
                      ),
                    ),
                ],
              ),
            ),
            // Spread into the ListView, so only days near the screen are built.
            ...transactions.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(
                    child: Text('Could not load transactions: $error'),
                  ),
                ),
              ],
              data: (rows) => _list(narrowed(rows), categories, selected),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(
    List<TransactionRow> rows,
    Map<int, Category> categories,
    ExpenseFilter filter,
  ) {
    final visible = rows.where(
      (r) => !_dismissed.contains(r.id) && filter.matches(r.type, r.categoryId),
    );
    if (visible.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: Text('Nothing here for this month')),
        ),
      ];
    }
    final days = <List<TransactionRow>>[];
    for (final row in visible) {
      if (days.isEmpty ||
          !DateUtils.isSameDay(days.last.first.occurredAt, row.occurredAt)) {
        days.add([]);
      }
      days.last.add(row);
    }
    final caption = Theme.of(context).textTheme.bodySmall;
    var index = 0;
    return [
      for (final day in days) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(dayLabel(day.first.occurredAt), style: caption),
              ),
              Text(dayTotal(day), style: caption),
            ],
          ),
        ),
        GroupedCard(
          children: [
            for (final row in day)
              FadeSlideIn(
                key: ValueKey(row.id),
                index: index++,
                child: SwipeToDelete(
                  key: ValueKey(row.id),
                  onDismissed: () => _delete(row),
                  child: TransactionTile(
                    row: row,
                    category: categories[row.categoryId],
                    onTap: () => openTransactionSheet(
                      context,
                      ref,
                      row,
                      () => _delete(row),
                    ),
                    onLongPress: () => openTransactionSheet(
                      context,
                      ref,
                      row,
                      () => _delete(row),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}

/// The red swipe-left delete on a transaction row. The caller must drop the row
/// from its list at once, before the database stream catches up, or Dismissible
/// throws.
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required super.key,
    required this.onDismissed,
    required this.child,
  });

  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: key!,
    direction: DismissDirection.endToStart,
    movementDuration: context.motion(),
    // Null removes the row without the collapse animation.
    resizeDuration: context.reduceMotion
        ? null
        : const Duration(milliseconds: 300),
    background: Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete, color: Colors.white),
    ),
    onDismissed: (_) {
      HapticFeedback.mediumImpact();
      onDismissed();
    },
    child: child,
  );
}

void showDeletedSnackBar(
  ScaffoldMessengerState messenger,
  AppDatabase db,
  TransactionRow row,
  VoidCallback onRestored,
) => messenger
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
          onRestored();
        },
      ),
    ),
  );

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// 'Monday, 28 Sep'.
String dayLabel(DateTime day) =>
    '${_weekdays[day.weekday - 1]}, ${Period.shortDate(day)}';

/// A day's spend, or its income with a plus when nothing was spent.
String dayTotal(List<TransactionRow> rows) {
  final spent = sumPaise(spendOf(rows).values);
  if (spent > 0) return Money.format(spent);
  return '+${Money.format(sumPaise(rows.map((r) => r.amountPaise)))}';
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
          color: credit ? AppColors.income : AppColors.debit,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
    return uncategorised ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}
