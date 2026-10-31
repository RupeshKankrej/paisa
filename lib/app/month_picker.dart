import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/month_key.dart';
import '../data/providers.dart';

/// Offers every month from the oldest transaction to the newest, always
/// including the current month and [value].
class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (first, last) =
        ref.watch(transactionBoundsProvider).value ?? (null, null);
    final keys = [
      value,
      MonthKey.of(DateTime.now()),
      if (first != null) MonthKey.of(first),
      if (last != null) MonthKey.of(last),
    ]..sort();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        items: [
          for (final key in MonthKey.range(keys.first, keys.last).reversed)
            DropdownMenuItem(value: key, child: Text(MonthKey.label(key))),
        ],
        onChanged: (key) => onChanged(key!),
      ),
    );
  }
}
