import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_widgets.dart';
import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/models.dart';
import '../expenses/expenses_screen.dart';
import '../expenses/transaction_sheet.dart';
import '../../app/glass.dart';

/// One day's expenses, from a tap on the Analytics calendar. Rows edit and
/// swipe-delete as on Activity.
Future<void> showDaySheet(BuildContext context, DateTime day) =>
    showAppSheet<void>(
      context,
      useSafeArea: true,
      color: context.palette.bg, // so the card stands out on it
      builder: (_) => _DaySheet(day),
    );

class _DaySheet extends ConsumerStatefulWidget {
  const _DaySheet(this.day);

  final DateTime day;

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  final _dismissed = <int>{};

  // Its own, as the app's messenger would show the Undo behind this sheet.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

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
    final rows = [
      for (final r in ref.watch(allTransactionsProvider).value ?? const [])
        if (r.type == TransactionType.debit &&
            !_dismissed.contains(r.id) &&
            DateUtils.isSameDay(r.occurredAt, widget.day))
          r as TransactionRow,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final caption = Theme.of(context).textTheme.bodySmall;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: context.palette.surface,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dayLabel(widget.day),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Text('Total amount', style: caption)),
                  Text(
                    Money.format(-sumPaise(rows.map((r) => r.amountPaise))),
                    key: const Key('day-total'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Text(
                    'No expenses on this day',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                GroupedCard(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final row in rows)
                      SwipeToDelete(
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
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
