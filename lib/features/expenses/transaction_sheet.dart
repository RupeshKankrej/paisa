import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_keypad.dart';
import '../../core/money.dart';
import '../../core/period.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../budgets/category_picker.dart';
import '../../app/glass.dart';

typedef SavedTransaction = ({
  DateTime occurredAt,
  TransactionType type,
  int? categoryId,
});

/// Add when [existing] is null, otherwise edit (SPEC 5.3, 5.4). Returns what
/// was saved, or null if dismissed.
Future<SavedTransaction?> showTransactionSheet(
  BuildContext context, {
  TransactionRow? existing,
  VoidCallback? onDelete,
}) => showAppSheet<SavedTransaction>(
  context,
  useSafeArea: true,
  color: context.palette.bg, // so the keys and chips stand out on it
  builder: (_) => _TransactionSheet(existing, onDelete),
);

/// Opens the sheet unless one is already up, then shows the saved row, which may
/// be in another month or filtered out. [onDelete] adds a delete button.
Future<void> openTransactionSheet(
  BuildContext context,
  WidgetRef ref, [
  TransactionRow? row,
  VoidCallback? onDelete,
]) async {
  final open = ref.read(transactionSheetOpenProvider.notifier);
  if (open.state) return;
  open.state = true;
  final saved = await showTransactionSheet(
    context,
    existing: row,
    onDelete: onDelete,
  ).whenComplete(() => open.state = false);
  if (saved == null || !context.mounted) return;
  ref.read(pickedMonthProvider.notifier).state = Period.containing(
    saved.occurredAt,
    ref.read(salaryDayProvider).value,
  ).key;
  if (!ref.read(expenseFilterProvider).matches(saved.type, saved.categoryId)) {
    ref.read(expenseFilterProvider.notifier).state = ExpenseFilter.all;
  }
  if (!filterMatches(
    ref.read(categoryFilterProvider).value,
    saved.categoryId,
  )) {
    await ref.read(databaseProvider).setCategoryFilter(null);
  }
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet(this.existing, this.onDelete);

  final TransactionRow? existing;
  final VoidCallback? onDelete;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _strip = ScrollController();
  late String _amount;
  late String _title;
  late String _note;
  late TransactionType _type;
  late int? _categoryId;
  // Shown first in the strip. Not moved by a tap on the strip, so rows don't jump.
  late int? _stripFirst;
  // Holds the time of day too: kept on edit, and "now" for a new row.
  late DateTime _date;
  var _showRawText = false;
  String? _error;

  // An SMS row can stay uncategorised; SPEC 5.3 requires a category for manual.
  bool get _categoryRequired =>
      widget.existing?.source != TransactionSource.sms;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final existing = widget.existing;
    _amount = existing == null ? '' : Money.keypadText(existing.amountPaise);
    _title = existing?.counterparty ?? '';
    _note = existing?.note ?? '';
    _type = existing?.type ?? TransactionType.debit;
    _categoryId = _stripFirst = existing?.categoryId;
    _date = existing?.occurredAt ?? DateTime.now();
    _error = null;
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  CategoryType get _categoryType => _type == TransactionType.debit
      ? CategoryType.expense
      : CategoryType.income;

  // The strip now lists the other type, so its selection would be invisible.
  void _toggleType() => setState(() {
    _type = _type == TransactionType.debit
        ? TransactionType.credit
        : TransactionType.debit;
    _categoryId = _stripFirst = null;
  });

  void _setAmount(String amount) => setState(() {
    _amount = amount;
    _error = null;
  });

  void _setCategory(int id) => setState(() {
    _categoryId = id;
    _error = null;
  });

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

  Future<void> _pickFromGrid() async {
    final category = await showCategoryPicker(context, _categoryType);
    if (category == null || !mounted) return;
    _stripFirst = category.id;
    // The grid has its own Expense/Income toggle; the row follows it.
    _type = category.type == CategoryType.income
        ? TransactionType.credit
        : TransactionType.debit;
    _setCategory(category.id);
    if (_strip.hasClients) _strip.jumpTo(0);
  }

  Future<void> _editText(
    String label,
    String value,
    ValueChanged<String> onSaved,
  ) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(label, value),
    );
    if (text != null) setState(() => onSaved(text));
  }

  void _delete() {
    Navigator.of(context).pop();
    widget.onDelete!();
  }

  Future<void> _save() async {
    final paise = Money.tryParse(_amount);
    if (paise == null || paise == 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_categoryId == null && _categoryRequired) {
      setState(() => _error = 'Pick a category');
      return;
    }
    final db = ref.read(databaseProvider);
    final row = TransactionsCompanion(
      type: Value(_type),
      amountPaise: Value(paise),
      occurredAt: Value(_date),
      counterparty: Value(_title.isEmpty ? null : _title),
      categoryId: Value(_categoryId),
      note: Value(_note.isEmpty ? null : _note),
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
      Navigator.of(context)
          .pop((occurredAt: _date, type: _type, categoryId: _categoryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final rawText = existing?.source == TransactionSource.sms
        ? existing?.rawText
        : null;
    final last4 = existing?.accountLast4;
    final date = Period.shortDate(_date);
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
              Semantics(
                label: existing == null
                    ? 'Add transaction'
                    : 'Edit transaction',
                container: true,
                child: Row(
                  spacing: 8,
                  children: [
                    _RoundIcon(Icons.refresh, 'Reset', () => setState(_load)),
                    const Spacer(),
                    if (widget.onDelete != null)
                      _RoundIcon(Icons.delete_outline, 'Delete', _delete),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        KeypadAmount(_amount, onChanged: _setAmount),
                        if (_error case final error?)
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.debit),
                          ),
                        if (_showRawText && rawText != null)
                          SelectableText(
                            rawText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _date.year == DateTime.now().year
                          ? date
                          : '$date ${_date.year}',
                    ),
                    onPressed: _pickDate,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.swap_vert, size: 18),
                    label: Text(
                      _type == TransactionType.debit ? 'Expense' : 'Income',
                    ),
                    onPressed: _toggleType,
                  ),
                  if (last4 != null)
                    Chip(
                      avatar: const Icon(Icons.account_balance, size: 18),
                      label: Text('A/c $last4'),
                    ),
                  _TextChip(
                    Icons.edit_note,
                    'Name',
                    _title,
                    () => _editText('Name', _title, (t) => _title = t),
                  ),
                  _TextChip(
                    Icons.notes,
                    'Note',
                    _note,
                    () => _editText('Note', _note, (t) => _note = t),
                  ),
                  if (rawText != null)
                    ActionChip(
                      avatar: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('from SMS'),
                      onPressed: () =>
                          setState(() => _showRawText = !_showRawText),
                    ),
                ],
              ),
              _categoryStrip(),
              AmountKeypad(
                onKey: (key) => _setAmount(Money.keypadPress(_amount, key)),
                onSubmit: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryStrip() {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final categories = pickableCategories(all, _categoryType);
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.surfaceRaised),
              borderRadius: BorderRadius.circular(AppRadii.round),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.round),
              child: SingleChildScrollView(
                controller: _strip,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in [
                      // First also when archived or of the other type: an older
                      // row may hold such a category.
                      ...all.where((c) => c.id == _stripFirst),
                      ...categories.where((c) => c.id != _stripFirst),
                    ])
                      _StripItem(
                        category: c,
                        selected: c.id == _categoryId,
                        onTap: () => _setCategory(c.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _RoundIcon(Icons.grid_view, 'All categories', _pickFromGrid),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.tooltip, this.onPressed);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    style: IconButton.styleFrom(backgroundColor: context.palette.surface),
    icon: Icon(icon, color: context.palette.textSecondary),
    onPressed: onPressed,
  );
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? context.palette.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.round),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            '${category.emoji}  ${category.name}',
            style: TextStyle(
              color: selected
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

/// Shows [value], or [label] when empty; long values are cut to keep it a chip.
class _TextChip extends StatelessWidget {
  const _TextChip(this.icon, this.label, this.value, this.onPressed);

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: Icon(icon, size: 18),
    tooltip: label,
    label: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Text(
        value.isEmpty ? label : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: value.isEmpty
            ? TextStyle(color: context.palette.textSecondary)
            : null,
      ),
    ),
    onPressed: onPressed,
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog(this.label, this.initial);

  final String label;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: TextField(
      controller: _text,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_text.text.trim()),
        child: const Text('Done'),
      ),
    ],
  );
}
