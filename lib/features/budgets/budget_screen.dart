import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/amount_dialog.dart';
import '../../app/month_picker.dart';
import '../../app/shell_widgets.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/models.dart';
import 'category_picker.dart';
import 'limit_sheet.dart';

/// The Budget tab: what is left of the salary, and each category's limit
/// (SPEC 5.16).
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  // The pencil and Add category both lead here (SPEC 5.16).
  void _openAllocate(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AllocateSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: tabAppBar(
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Allocate budget',
              style: IconButton.styleFrom(
                backgroundColor: context.palette.textPrimary.withValues(
                  alpha: 0.12,
                ),
              ),
              icon: Icon(Icons.edit, color: context.palette.textPrimary),
              onPressed: () => _openAllocate(context),
            ),
          ),
        ],
      ),
      floatingActionButton: const AddFab(),
      body: ref
          .watch(transactionsProvider(month))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Could not load transactions: $error')),
            data: (rows) => _list(context, ref, month, rows),
          ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    String month,
    List<TransactionRow> rows,
  ) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final budgets = ref.watch(budgetAmountsProvider).value ?? const {};
    final limits = expenseLimits(categories, budgets, month);
    final spend = spendOf(rows);
    final uncategorised = rows.where((r) => r.categoryId == null).length;
    final byId = {for (final c in categories) c.id: c};
    return ListView(
      padding: listClearance(context),
      children: [
        MonthSwipe(child: _SalaryRing(spent: sumPaise(spend.values))),
        const SizedBox(height: 24),
        if (limits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 120,
              child: AddNewTile(
                label: 'Add category',
                onTap: () => _openAllocate(context),
              ),
            ),
          )
        else
          GroupedCard(
            children: [
              for (final MapEntry(key: id, value: limit) in limits.entries)
                _LimitTile(
                  category: byId[id]!,
                  limit: limit,
                  spent: spend[id] ?? 0,
                ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.palette.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: const Icon(Icons.add),
                ),
                title: Text(
                  'Add category',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
                onTap: () => _openAllocate(context),
              ),
            ],
          ),
        if (uncategorised > 0)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GroupedCard(
              children: [
                ListTile(
                  leading: const CategoryAvatar(null),
                  title: Text('$uncategorised uncategorised'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(expenseFilterProvider.notifier).state =
                        ExpenseFilter.uncategorised;
                    context.go('/expenses');
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The ring is the part of the salary left. Tapping the salary sets that
/// period's override (SPEC 5.5).
class _SalaryRing extends ConsumerWidget {
  const _SalaryRing({required this.spent});

  static const _size = 280.0;

  final int spent;

  Future<void> _editSalary(
    BuildContext context,
    WidgetRef ref,
    String month,
    Map<String?, int> amounts,
  ) async {
    final fallback = amounts[null];
    final result = await showAmountDialog(
      context,
      title: 'Salary for ${MonthKey.label(month)}',
      fields: [
        (
          label: 'This month only',
          initial: amounts[month],
          helper: fallback == null
              ? 'No default set. Add one in Settings.'
              : 'Blank uses the default, ${Money.format(fallback)}',
        ),
      ],
    );
    if (result != null) {
      await ref.read(databaseProvider).setSalary(month, result.single);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final amounts = ref.watch(salaryAmountsProvider).value ?? const {};
    final salary = resolveAmount(amounts, month);
    final remaining = salary == null ? null : salary - spent;
    final over = remaining != null && remaining < 0;
    final caption = Theme.of(context).textTheme.bodySmall;
    return Center(
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: _size,
              child: CircularProgressIndicator(
                key: const Key('salary-left-ring'),
                value: remaining == null || salary == 0
                    ? 0
                    : (remaining / salary!).clamp(0.0, 1.0),
                strokeWidth: 24,
                strokeCap: StrokeCap.round,
                color: context.palette.textSecondary,
                backgroundColor: over
                    ? AppColors.delete
                    : context.palette.surfaceRaised,
              ),
            ),
            SizedBox(
              width: _size - 88,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MonthPicker(prefix: 'Left'),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      remaining == null ? '—' : Money.format(remaining),
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(color: over ? AppColors.debit : null),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    onTap: () => _editSalary(context, ref, month, amounts),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Flexible(
                            child: Text(
                              salary == null
                                  ? 'Set salary'
                                  : 'of ${Money.format(salary)}',
                              style: caption,
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: context.palette.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (over)
                    Text(
                      'Over salary by ${Money.format(-remaining)}',
                      textAlign: TextAlign.center,
                      style: caption?.copyWith(color: AppColors.debit),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitTile extends ConsumerWidget {
  const _LimitTile({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final Category category;
  final int limit;
  final int spent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = limit - spent;
    return ListTile(
      leading: SizedBox.square(
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 48,
              child: CircularProgressIndicator(
                value: spentFraction(spent, limit),
                strokeWidth: 4,
                color: Color(category.color),
                backgroundColor: Color(category.color).withValues(alpha: 0.25),
              ),
            ),
            Text(
              category.emoji,
              style: const TextStyle(fontSize: 20),
              semanticsLabel: '',
            ),
          ],
        ),
      ),
      title: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2,
        children: [
          Text(
            '${Money.format(left)} left',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: left < 0 ? AppColors.debit : context.palette.textPrimary,
            ),
          ),
          Text(
            'of ${Money.format(limit)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => editCategoryLimit(context, ref, category),
    );
  }
}

/// Holds edits until Confirm; dismissing the sheet drops them (SPEC 5.16).
class _AllocateSheet extends ConsumerStatefulWidget {
  const _AllocateSheet();

  @override
  ConsumerState<_AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends ConsumerState<_AllocateSheet> {
  final _edits = <int, LimitEdit>{};

  Future<void> _edit(
    Category category,
    String month,
    int? salary,
    Map<int, int?> limits,
    Map<String?, int> amounts,
  ) async {
    final edit = await showLimitKeypad(
      context,
      category: category,
      month: month,
      salary: salary,
      otherLimits: sumPaise(
        limits.entries
            .where((e) => e.key != category.id)
            .map((e) => e.value ?? 0),
      ),
      amounts: amounts,
      initial: _edits[category.id],
    );
    if (edit != null) setState(() => _edits[category.id] = edit);
  }

  Future<void> _confirm(String month) async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      for (final MapEntry(key: id, value: edit) in _edits.entries) {
        await saveLimit(db, id, month, edit);
      }
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final budgets = ref.watch(budgetAmountsProvider).value ?? const {};
    final salary = resolveAmount(
      ref.watch(salaryAmountsProvider).value ?? const {},
      month,
    );
    final categories = pickableCategories(all, CategoryType.expense);
    final limits = <int, int?>{
      for (final c in categories)
        c.id: _edits[c.id] == null
            ? resolveAmount(budgets[c.id] ?? const {}, month)
            : limitAfterEdit(budgets[c.id] ?? const {}, _edits[c.id]!),
    };
    final allocated = sumPaise(limits.values.map((l) => l ?? 0));
    final total = salary ?? 0;
    final caption = Theme.of(context).textTheme.bodySmall;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const Text(
            'Allocate your budget',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    Text('${wholePercentLabel(allocated, total)} set'),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            salary == null
                                ? Money.format(allocated)
                                : '${Money.format(allocated)} / '
                                      '${Money.format(salary)}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                LinearProgressIndicator(
                  value: spentFraction(allocated, total),
                  color: AppColors.income,
                  backgroundColor: palette.surface,
                ),
                Text(
                  salary == null
                      ? 'No salary set'
                      : '${Money.format(salary - allocated)} left to allocate',
                  key: const Key('left-to-allocate'),
                  style: caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                GroupedCard(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final c in categories)
                      ListTile(
                        leading: CategoryAvatar(c),
                        title: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          spacing: 2,
                          children: [
                            Text(Money.format(limits[c.id] ?? 0)),
                            Pill(wholePercentLabel(limits[c.id] ?? 0, total)),
                          ],
                        ),
                        onTap: () => _edit(
                          c,
                          month,
                          salary,
                          limits,
                          budgets[c.id] ?? const {},
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => _confirm(month),
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}
