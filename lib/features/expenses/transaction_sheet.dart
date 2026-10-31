import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';

typedef SavedTransaction = ({DateTime occurredAt, TransactionType type});

/// Add when [existing] is null, otherwise edit (SPEC 5.3, 5.4). Returns what
/// was saved, or null if dismissed.
Future<SavedTransaction?> showTransactionSheet(
  BuildContext context, {
  TransactionRow? existing,
}) => showModalBottomSheet<SavedTransaction>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TransactionSheet(existing),
);

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet(this.existing);

  final TransactionRow? existing;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.format(widget.existing!.amountPaise).replaceFirst('₹', ''),
  );
  late final _title = TextEditingController(
    text: widget.existing?.counterparty,
  );
  late final _note = TextEditingController(text: widget.existing?.note);
  late var _type = widget.existing?.type ?? TransactionType.debit;
  late var _categoryId = widget.existing?.categoryId;
  // Holds the time of day too: kept on edit, and "now" for a new row.
  late var _date = widget.existing?.occurredAt ?? DateTime.now();

  // An SMS row can stay uncategorised; SPEC 5.3 requires a category for manual.
  bool get _categoryRequired =>
      widget.existing?.source != TransactionSource.sms;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _validateAmount(String? text) {
    final paise = Money.tryParse(text ?? '');
    return paise == null || paise == 0 ? 'Enter an amount' : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _date = _date.copyWith(
          year: picked.year,
          month: picked.month,
          day: picked.day,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final db = ref.read(databaseProvider);
    final title = _title.text.trim();
    final note = _note.text.trim();
    final row = TransactionsCompanion(
      type: Value(_type),
      amountPaise: Value(Money.tryParse(_amount.text)!),
      occurredAt: Value(_date),
      counterparty: Value(title.isEmpty ? null : title),
      categoryId: Value(_categoryId),
      note: Value(note.isEmpty ? null : note),
    );
    final existing = widget.existing;
    if (existing == null) {
      await db.addTransaction(
        row.copyWith(source: const Value(TransactionSource.manual)),
      );
    } else {
      await db.updateTransaction(existing.id, row);
    }
    if (mounted) {
      Navigator.of(context).pop((occurredAt: _date, type: _type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final existing = widget.existing;
    final rawText = existing?.source == TransactionSource.sms
        ? existing?.rawText
        : null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(
                  existing == null ? 'Add transaction' : 'Edit transaction',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextFormField(
                  controller: _amount,
                  autofocus: existing == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹',
                  ),
                  validator: _validateAmount,
                ),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.debit,
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.credit,
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (types) =>
                      setState(() => _type = types.single),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (id) => setState(() => _categoryId = id),
                  validator: (id) =>
                      id == null && _categoryRequired ? 'Required' : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    MaterialLocalizations.of(context).formatMediumDate(_date),
                  ),
                  onTap: _pickDate,
                ),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Counterparty or title (optional)',
                  ),
                ),
                TextFormField(
                  controller: _note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                if (rawText != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('from SMS'),
                    children: [SelectableText(rawText)],
                  ),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
