import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_dialog.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/models.dart';

Map<int?, int> spendOf(List<TransactionRow> rows) => spendByCategory(
  rows
      .where((r) => r.type == TransactionType.debit)
      .map((r) => (r.categoryId, r.amountPaise)),
);

/// Spent, salary and remaining for the selected month (SPEC 5.6). Tapping the
/// salary sets that month's override.
class MonthSummaryCard extends ConsumerWidget {
  const MonthSummaryCard({super.key, required this.rows});

  /// The selected month's transactions.
  final List<TransactionRow> rows;

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
    final spent = sumPaise(spendOf(rows).values);
    final remaining = salary == null ? null : salary - spent;
    final over = remaining != null && remaining < 0;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                _Figure('Spent', Money.format(spent)),
                _Figure(
                  'Salary',
                  salary == null ? 'Set salary' : Money.format(salary),
                  icon: Icons.edit_outlined,
                  onTap: () => _editSalary(context, ref, month, amounts),
                ),
                _Figure(
                  'Remaining',
                  remaining == null ? '—' : Money.format(remaining),
                  color: over ? Colors.red : null,
                ),
              ],
            ),
            if (salary != null)
              LinearProgressIndicator(
                value: spentFraction(spent, salary),
                color: over ? Colors.red : null,
              ),
            if (over)
              Row(
                spacing: 4,
                children: [
                  const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                  Expanded(
                    child: Text(
                      'Over salary by ${Money.format(-remaining)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.color, this.icon, this.onTap});

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 4,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: theme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null) Icon(icon, size: 12),
              ],
            ),
            // Large amounts shrink rather than wrap in a third of the width.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.titleMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
