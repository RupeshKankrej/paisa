import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/month_key.dart';
import '../core/period.dart';
import '../core/theme/tokens.dart';
import '../data/providers.dart';

String _currentKey(WidgetRef ref) =>
    Period.containing(DateTime.now(), ref.read(salaryDayProvider).value).key;

/// The caption that shows the month shared by every screen and opens the
/// picker sheet (SPEC 5.13).
class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    final value = ref.watch(selectedMonthProvider);
    final current = Period.containing(DateTime.now(), salaryDay).key;
    final label = MonthKey.label(value);
    final caption = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => const _MonthSheet(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  value == current
                      ? 'This month'
                      : value.substring(0, 4) == current.substring(0, 4)
                      ? label.split(' ').first
                      : label,
                  style: caption?.copyWith(fontSize: 15),
                ),
                const Icon(
                  Icons.expand_more,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            if (salaryDay != null)
              Text(
                Period.forMonthKey(value, salaryDay).rangeLabel,
                style: caption,
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthSheet extends ConsumerStatefulWidget {
  const _MonthSheet();

  @override
  ConsumerState<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends ConsumerState<_MonthSheet> {
  late var _year = ref.read(selectedMonthProvider).substring(0, 4);

  @override
  Widget build(BuildContext context) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    final value = ref.watch(selectedMonthProvider);
    final current = _currentKey(ref);
    final (first, _) =
        ref.watch(transactionBoundsProvider).value ?? (null, null);
    final years = MonthKey.pickerYears(current, [
      value,
      if (first != null) Period.containing(first, salaryDay).key,
    ]);
    final caption = Theme.of(context).textTheme.bodySmall;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select date',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                for (final year in years)
                  _SheetChip(
                    '$year',
                    selected: '$year' == _year,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onTap: () => setState(() => _year = '$year'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              spacing: 8,
              children: [
                for (var row = 0; row < 4; row++)
                  Row(
                    spacing: 8,
                    children: [
                      for (var col = 1; col <= 3; col++)
                        Expanded(
                          child: _monthChip(
                            '$_year-${(row * 3 + col).toString().padLeft(2, '0')}',
                            value,
                            current,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (salaryDay != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                Period.forMonthKey(value, salaryDay).rangeLabel,
                textAlign: TextAlign.center,
                style: caption,
              ),
            ),
          Text(
            'Swipe on any chart to change months',
            textAlign: TextAlign.center,
            style: caption,
          ),
        ],
      ),
    );
  }

  Widget _monthChip(String key, String value, String current) => _SheetChip(
    MonthKey.label(key).substring(0, 3),
    selected: key == value,
    height: 52,
    onTap: key.compareTo(current) > 0
        ? null
        : () {
            ref.read(pickedMonthProvider.notifier).state = key;
            Navigator.of(context).pop();
          },
  );
}

class _SheetChip extends StatelessWidget {
  const _SheetChip(
    this.label, {
    required this.selected,
    required this.onTap,
    this.height = 44,
    this.padding = EdgeInsets.zero,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: enabled
            ? AppColors.surfaceRaised
            : AppColors.surfaceRaised.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: selected
              ? const BorderSide(color: AppColors.textPrimary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal swipe on [child] changes the shared month: left goes back, right
/// goes forward and stops at the current period (SPEC 5.13, 5.17).
class MonthSwipe extends ConsumerStatefulWidget {
  const MonthSwipe({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MonthSwipe> createState() => _MonthSwipeState();
}

class _MonthSwipeState extends ConsumerState<MonthSwipe> {
  static const _minDistance = 32.0;
  var _distance = 0.0;

  void _end() {
    if (_distance.abs() < _minDistance) return;
    final next = MonthKey.shift(
      ref.read(selectedMonthProvider),
      _distance < 0 ? -1 : 1,
    );
    if (_distance > 0 && next.compareTo(_currentKey(ref)) > 0) return;
    ref.read(pickedMonthProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _distance = 0,
    onHorizontalDragUpdate: (details) => _distance += details.delta.dx,
    onHorizontalDragEnd: (_) => _end(),
    child: widget.child,
  );
}
