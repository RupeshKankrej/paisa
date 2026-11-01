import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../core/month_key.dart';
import '../core/period.dart';
import '../core/theme/tokens.dart';
import '../data/providers.dart';
import 'glass.dart';
import '../core/theme/motion.dart';

String _currentKey(WidgetRef ref) =>
    Period.containing(DateTime.now(), ref.read(salaryDayProvider).value).key;

/// Opens the Select date sheet (SPEC 5.13). The choice is app-wide; it is also
/// returned, or null if the sheet was dismissed.
Future<String?> showMonthSheet(BuildContext context) =>
    showAppSheet<String>(context, builder: (_) => const _MonthSheet());

/// The caption that shows the month shared by every screen and opens the
/// picker sheet (SPEC 5.13).
class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key, this.prefix});

  /// Turns the caption into 'Left this month' or 'Left in September'.
  final String? prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    final value = ref.watch(selectedMonthProvider);
    final current = Period.containing(DateTime.now(), salaryDay).key;
    final label = MonthKey.label(value);
    final name = value.substring(0, 4) == current.substring(0, 4)
        ? label.split(' ').first
        : label;
    final caption = Theme.of(context).textTheme.bodySmall;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      onTap: () => showMonthSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(switch ((prefix, value == current)) {
                  (null, true) => 'This month',
                  (final p?, true) => '$p this month',
                  (null, false) => name,
                  (final p?, false) => '$p in $name',
                }, style: caption?.copyWith(fontSize: 15)),
                Icon(
                  Icons.expand_more,
                  color: context.palette.textSecondary,
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
            Navigator.of(context).pop(key);
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
            ? context.palette.surfaceRaised
            : context.palette.surfaceRaised.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: selected
              ? BorderSide(color: context.palette.textPrimary, width: 2)
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
                    ? context.palette.textPrimary
                    : context.palette.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal swipe on [child] changes the shared month by [months]: right goes
/// back, left goes forward and stops at the current period (SPEC 5.13, 5.17).
class MonthSwipe extends ConsumerStatefulWidget {
  const MonthSwipe({
    super.key,
    this.months = 1,
    this.picked,
    required this.child,
  });

  final int months;

  /// Where the month is kept, for a card with its own; the shared one otherwise.
  final StateProvider<String?>? picked;
  final Widget child;

  @override
  ConsumerState<MonthSwipe> createState() => _MonthSwipeState();
}

class _MonthSwipeState extends ConsumerState<MonthSwipe>
    with SingleTickerProviderStateMixin {
  static const _minDistance = 32.0;
  static const _flick = 300.0;

  var _distance = 0.0;
  var _leaving = false;

  // Where the content is, in points: it stays under the finger, then carries on
  // off the side while the next month comes in from the other (reference 27).
  late final _shift = AnimationController.unbounded(vsync: this);

  @override
  void dispose() {
    _shift.dispose();
    super.dispose();
  }

  void _settle() => _shift.animateTo(
    0,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  String _next(double direction) => MonthKey.shift(
    ref.read(widget.picked ?? pickedMonthProvider) ?? _currentKey(ref),
    direction > 0 ? -widget.months : widget.months,
  );

  bool _blocked(double direction) =>
      direction < 0 && _next(direction).compareTo(_currentKey(ref)) > 0;

  void _update(DragUpdateDetails details) {
    if (_leaving) return;
    _distance += details.delta.dx;
    if (context.reduceMotion) return;
    // There is nothing past the current period, so it only gives a little.
    _shift.value = _blocked(_distance) ? _distance * 0.25 : _distance;
  }

  Future<void> _end(DragEndDetails details) async {
    if (_leaving) return;
    final velocity = details.primaryVelocity ?? 0;
    final moved = _distance.abs() >= _minDistance || velocity.abs() >= _flick;
    final direction = _distance != 0 ? _distance : velocity;
    if (!moved || direction == 0 || _blocked(direction)) {
      _settle();
      return;
    }
    final picked = widget.picked ?? pickedMonthProvider;
    final next = _next(direction);
    if (context.reduceMotion) {
      ref.read(picked.notifier).state = next;
      return;
    }
    final side = direction.sign * MediaQuery.sizeOf(context).width;
    _leaving = true;
    await _shift.animateTo(
      side,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeIn,
    );
    if (!mounted) return;
    _leaving = false;
    ref.read(picked.notifier).state = next;
    _shift.value = -side;
    _settle();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) {
      if (!_leaving) _distance = 0;
    },
    onHorizontalDragUpdate: _update,
    onHorizontalDragEnd: _end,
    onHorizontalDragCancel: () {
      if (!_leaving) _settle();
    },
    child: AnimatedBuilder(
      animation: _shift,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_shift.value, 0), child: child),
      child: widget.child,
    ),
  );
}
