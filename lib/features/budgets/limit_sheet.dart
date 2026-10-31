import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_keypad.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';

/// Opens the keypad for [category] in the selected period and saves the result.
Future<void> editCategoryLimit(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  final month = ref.read(selectedMonthProvider);
  final budgets = ref.read(budgetAmountsProvider).value ?? const {};
  final limits = expenseLimits(
    ref.read(categoriesProvider).value ?? const [],
    budgets,
    month,
  );
  final db = ref.read(databaseProvider);
  final edit = await showLimitKeypad(
    context,
    category: category,
    month: month,
    salary: resolveAmount(
      ref.read(salaryAmountsProvider).value ?? const {},
      month,
    ),
    otherLimits: sumPaise(
      limits.entries.where((e) => e.key != category.id).map((e) => e.value),
    ),
    amounts: budgets[category.id] ?? const {},
  );
  if (edit != null) await saveLimit(db, category.id, month, edit);
}

Future<void> saveLimit(
  AppDatabase db,
  int categoryId,
  String month,
  LimitEdit edit,
) => db.transaction(() async {
  if (edit.everyMonth) {
    await db.setBudget(categoryId, null, edit.paise);
    await db.setBudget(categoryId, month, null);
  } else {
    await db.setBudget(categoryId, month, edit.paise);
  }
});

/// The per-category keypad sheet (SPEC 5.16). Returns the edit without saving
/// it, or null on back. [initial] is an edit not yet saved, from Allocate.
Future<LimitEdit?> showLimitKeypad(
  BuildContext context, {
  required Category category,
  required String month,
  required int? salary,
  required int otherLimits,
  required Map<String?, int> amounts,
  LimitEdit? initial,
}) => showModalBottomSheet<LimitEdit>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.palette.bg,
  builder: (_) => _LimitSheet(
    category: category,
    month: month,
    salary: salary,
    otherLimits: otherLimits,
    amounts: amounts,
    initial: initial,
  ),
);

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({
    required this.category,
    required this.month,
    required this.salary,
    required this.otherLimits,
    required this.amounts,
    required this.initial,
  });

  final Category category;
  final String month;
  final int? salary;
  final int otherLimits;
  final Map<String?, int> amounts;
  final LimitEdit? initial;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  late var _everyMonth =
      widget.initial?.everyMonth ?? !widget.amounts.containsKey(widget.month);
  late var _amount = () {
    final paise = widget.initial == null
        ? resolveAmount(widget.amounts, widget.month)
        : widget.initial!.paise;
    return paise == null ? '' : Money.keypadText(paise);
  }();

  @override
  Widget build(BuildContext context) {
    final edit = (paise: Money.tryParse(_amount), everyMonth: _everyMonth);
    final limit = limitAfterEdit(widget.amounts, edit);
    final salary = widget.salary;
    final left = salary == null
        ? null
        : budgetLeft(salary, widget.otherLimits, limit);
    final canSave = canSaveLimit(salary, widget.otherLimits, limit, edit);
    void submit() => Navigator.of(context).pop(edit);
    final caption = Theme.of(context).textTheme.bodySmall;
    return FractionallySizedBox(
      heightFactor: 0.97, // leaves a sliver of scrim to tap away on
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.surface,
                    ),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      spacing: 2,
                      children: [
                        Text(
                          '${widget.category.emoji} ${widget.category.name} '
                          'monthly budget',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          left == null
                              ? 'No salary set'
                              : '${Money.format(left)} budget left',
                          key: const Key('budget-left'),
                          textAlign: TextAlign.center,
                          style: left != null && left < 0
                              ? caption?.copyWith(color: AppColors.debit)
                              : caption,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: canSave ? submit : null,
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: KeypadAmount(
                    _amount,
                    onChanged: (amount) => setState(() => _amount = amount),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Every month'),
                    selected: _everyMonth,
                    onSelected: (_) => setState(() => _everyMonth = true),
                  ),
                  ChoiceChip(
                    label: Text(
                      '${MonthKey.label(widget.month).split(' ').first} only',
                    ),
                    selected: !_everyMonth,
                    onSelected: (_) => setState(() => _everyMonth = false),
                  ),
                ],
              ),
              AmountKeypad(
                onKey: (key) =>
                    setState(() => _amount = Money.keypadPress(_amount, key)),
                onSubmit: canSave ? submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
