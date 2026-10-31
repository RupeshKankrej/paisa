import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/month_key.dart';
import '../core/period.dart';
import '../core/theme/tokens.dart';
import '../data/providers.dart';

/// Picks the month shared by Home, Expenses and Categories. Offers at least the
/// last 12 months, stretched to cover the oldest and newest transactions.
class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    final value = ref.watch(selectedMonthProvider);
    final (first, last) =
        ref.watch(transactionBoundsProvider).value ?? (null, null);
    final current = Period.containing(DateTime.now(), salaryDay).key;
    final keys = [
      value,
      current,
      MonthKey.shift(current, -11),
      if (first != null) Period.containing(first, salaryDay).key,
      if (last != null) Period.containing(last, salaryDay).key,
    ]..sort();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
        style: Theme.of(context).textTheme.bodySmall,
        itemHeight: null, // the date range needs a second line
        items: [
          for (final key in MonthKey.range(keys.first, keys.last).reversed)
            DropdownMenuItem(
              value: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MonthKey.label(key),
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (salaryDay != null)
                    Text(
                      Period.forMonthKey(key, salaryDay).rangeLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
        onChanged: (key) => ref.read(pickedMonthProvider.notifier).state = key,
      ),
    );
  }
}
