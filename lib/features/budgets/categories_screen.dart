import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_dialog.dart';
import '../../app/month_picker.dart';
import '../../app/shell_widgets.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import 'category_picker.dart';
import 'month_summary_card.dart';

const _levelColors = {
  BudgetLevel.under: Colors.green,
  BudgetLevel.near: Colors.amber,
  BudgetLevel.over: Colors.red,
};

/// The Summary tab: a donut of the month's spend or income, and its categories.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  var _type = TransactionType.debit;

  void _openFilter() => showCategoryFilter(
    context,
    _type == TransactionType.debit ? CategoryType.expense : CategoryType.income,
  );

  Future<void> _editLimit(
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
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final categories = ref.watch(categoriesProvider);
    final transactions = ref.watch(transactionsProvider(month));
    return Scaffold(
      appBar: floatingTabAppBar(),
      extendBodyBehindAppBar: true,
      floatingActionButton: const AddFab(),
      body: switch ((categories, transactions)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('Could not load categories: $error')),
        (AsyncData(value: final categories), AsyncData(value: final rows)) =>
          _list(month, categories, rows),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(
    String month,
    List<Category> categories,
    List<TransactionRow> rows,
  ) {
    final expenses = _type == TransactionType.debit;
    final budgets = ref.watch(budgetAmountsProvider).value ?? const {};
    final salary = resolveAmount(
      ref.watch(salaryAmountsProvider).value ?? const {},
      month,
    );
    final filter = ref.watch(categoryFilterProvider).value;
    final totals = totalsByCategory(
      rows
          .where((r) => r.type == _type && filterMatches(filter, r.categoryId))
          .map((r) => (r.categoryId, r.amountPaise)),
    );
    final total = sumPaise(totals.values.map((t) => t.paise));
    // Salary compares with all spend, whatever the filter narrows the donut to.
    final spent = sumPaise(spendOf(rows).values);
    final limits = sumPaise(
      categories
          .where((c) => !c.isArchived)
          .map((c) => resolveAmount(budgets[c.id] ?? const {}, month) ?? 0),
    );
    int paiseOf(Category c) => totals[c.id]?.paise ?? 0;
    final shown =
        [
          // SPEC 5.7 wants a row per category, so a limit can be set before spending.
          for (final c in categories)
            if (paiseOf(c) > 0 ||
                (expenses &&
                    c.type == CategoryType.expense &&
                    !c.isArchived &&
                    filterMatches(filter, c.id)))
              c,
        ]..sort((a, b) {
          final byAmount = paiseOf(b).compareTo(paiseOf(a));
          return byAmount != 0 ? byAmount : a.sortOrder.compareTo(b.sortOrder);
        });
    final uncategorised = totals[null];
    final over = expenses && salary != null && spent > salary;
    final captionStyle = Theme.of(context).textTheme.bodySmall;
    return ListView(
      padding: listClearance(context),
      children: [
        SizedBox(height: belowFloatingBar(context)),
        MonthSwipe(
          child: _Donut(
            slices: [
              if (uncategorised != null) (Colors.grey, uncategorised.paise),
              for (final c in shown)
                if (paiseOf(c) > 0) (Color(c.color), paiseOf(c)),
            ],
            total: total,
            salary: over && filter == null ? salary : null,
          ),
        ),
        if (expenses && salary != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              over
                  ? 'Over salary by ${Money.format(spent - salary)}'
                  : '${Money.format(salary - spent)} left of '
                        '${Money.format(salary)}',
              textAlign: TextAlign.center,
              style: over
                  ? captionStyle?.copyWith(color: Colors.red)
                  : captionStyle,
            ),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final (label, type) in const [
                        ('Expenses', TransactionType.debit),
                        ('Income', TransactionType.credit),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _type == type,
                          onSelected: (_) => setState(() => _type = type),
                        ),
                      if (filter != null)
                        ChoiceChip(
                          label: Text(filterLabel(filter)),
                          selected: true,
                          onSelected: (_) => _openFilter(),
                        ),
                    ],
                  ),
                ),
              ),
              // Outside the scroll, so it stays reachable when chips are added.
              IconButton(
                tooltip: 'Filter categories',
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                icon: const Icon(Icons.edit, size: 18),
                onPressed: _openFilter,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (expenses && salary != null && limits > salary)
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
        if (uncategorised == null && shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: Text('Nothing here for this month')),
          )
        else
          GroupedCard(
            children: [
              if (uncategorised != null)
                _CategoryTile(
                  avatar: const CategoryAvatar(null),
                  name: 'Uncategorised',
                  count: uncategorised.count,
                  amount: uncategorised.paise,
                  total: total,
                ),
              for (final category in shown)
                _CategoryTile(
                  avatar: CategoryAvatar(category),
                  name: category.name,
                  count: totals[category.id]?.count ?? 0,
                  amount: paiseOf(category),
                  total: total,
                  limit: expenses
                      ? resolveAmount(budgets[category.id] ?? const {}, month)
                      : null,
                  onTap: expenses
                      ? () => _editLimit(
                          category,
                          month,
                          budgets[category.id] ?? const {},
                        )
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

/// Spend share by category with the month and total in the centre. [salary] is
/// set only when spend is past it: a red outline, and a thin inner ring whose
/// sweep is the salary's share of the spend (SPEC 5.8, 5.12).
class _Donut extends StatelessWidget {
  const _Donut({required this.slices, required this.total, this.salary});

  static const _hole = 120.0;
  static const _band = 24.0;
  static const _size = (_hole + _band) * 2;

  final List<(Color, int)> slices;
  final int total;
  final int? salary;

  @override
  Widget build(BuildContext context) {
    final salary = this.salary;
    PieChartSectionData section(Color color, double value) =>
        PieChartSectionData(
          value: value,
          color: color,
          radius: _band,
          showTitle: false,
          cornerRadius: 6,
        );
    return SizedBox(
      height: _size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: _size,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: _hole,
                sectionsSpace: slices.length > 1 ? 6 : 0,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(enabled: false),
                sections: slices.isEmpty
                    ? [section(AppColors.surfaceRaised, 1)]
                    : [
                        for (final (color, paise) in slices)
                          section(color, paise.toDouble()),
                      ],
              ),
            ),
          ),
          if (salary != null) ...[
            IgnorePointer(
              child: Container(
                key: const Key('over-salary-outline'),
                width: _size + 8,
                height: _size + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
              ),
            ),
            SizedBox.square(
              key: const Key('salary-ring'),
              dimension: _hole * 2 - 12,
              child: CircularProgressIndicator(
                value: salary / total,
                strokeWidth: 2,
                color: AppColors.textPrimary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
          SizedBox(
            width: _hole * 2 - 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(fit: BoxFit.scaleDown, child: MonthPicker()),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Money.format(total),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.avatar,
    required this.name,
    required this.count,
    required this.amount,
    required this.total,
    this.limit,
    this.onTap,
  });

  final Widget avatar;
  final String name;
  final int count;
  final int amount;
  final int total;
  final int? limit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final limit = this.limit;
    return ListTile(
      leading: avatar,
      title: Row(
        spacing: 8,
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          _Pill('$count'),
        ],
      ),
      subtitle: limit == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: spentFraction(amount, limit),
                  color: _levelColors[budgetLevel(amount, limit)],
                ),
                Text('of ${Money.format(limit)}'),
              ],
            ),
      // Stacked, as paise-precise amounts leave a name too little room in one line.
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 4,
        children: [
          Text(
            Money.format(amount),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          _Pill(percentLabel(amount, total)),
        ],
      ),
      onTap: onTap,
    );
  }
}
