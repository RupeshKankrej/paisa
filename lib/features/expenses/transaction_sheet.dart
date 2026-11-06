import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_keypad.dart';
import '../../core/money.dart';
import '../../core/period.dart';
import '../../core/theme/motion.dart';
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
  TransactionType? startType,
  int? startCategory,
}) => showAppSheet<SavedTransaction>(
  context,
  useSafeArea: true,
  color: context.palette.bg, // so the keys and chips stand out on it
  builder: (_) =>
      _TransactionSheet(existing, onDelete, startType, startCategory),
);

/// Opens the sheet unless one is already up, then shows the saved row, which may
/// be in another month or filtered out. [onDelete] adds a delete button.
Future<void> openTransactionSheet(
  BuildContext context,
  WidgetRef ref, [
  TransactionRow? row,
  VoidCallback? onDelete,
  TransactionType? startType,
  int? startCategory,
]) async {
  final open = ref.read(transactionSheetOpenProvider.notifier);
  if (open.state) return;
  open.state = true;
  final saved = await showTransactionSheet(
    context,
    existing: row,
    onDelete: onDelete,
    startType: startType,
    startCategory: startCategory,
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
  const _TransactionSheet(
    this.existing,
    this.onDelete,
    this.startType,
    this.startCategory,
  );

  final TransactionRow? existing;
  final VoidCallback? onDelete;
  final TransactionType? startType;
  final int? startCategory;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

enum _Field { name, note }

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _strip = ScrollController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  // Taps here keep the field open: the field and its recent-values row.
  final _fieldGroup = Object();
  _Field? _editing;
  late String _amount;
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
    _title.text = existing?.counterparty ?? '';
    _note.text = existing?.note ?? '';
    _editing = null;
    _type = existing?.type ?? widget.startType ?? TransactionType.debit;
    _categoryId = _stripFirst = existing?.categoryId ?? widget.startCategory;
    _date = existing?.occurredAt ?? DateTime.now();
    _error = null;
  }

  @override
  void dispose() {
    _strip.dispose();
    _title.dispose();
    _note.dispose();
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

  // Picking a category also confirms an open Name or Note (SPEC 5.18).
  void _setCategory(int id) => setState(() {
    _categoryId = id;
    _error = null;
    _editing = null;
  });

  void _collapse() {
    if (_editing == null) return;
    setState(() => _editing = null);
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
      counterparty: Value(
        _title.text.trim().isEmpty ? null : _title.text.trim(),
      ),
      categoryId: Value(_categoryId),
      note: Value(_note.text.trim().isEmpty ? null : _note.text.trim()),
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
              AnimatedSize(
                duration: context.motion(const Duration(milliseconds: 180)),
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    _row(_Field.name, [
                      ActionChip(
                        avatar: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
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
                    ]),
                    _row(_Field.note, [
                      if (rawText != null)
                        ActionChip(
                          avatar: const Icon(Icons.sms_outlined, size: 18),
                          label: const Text('from SMS'),
                          onPressed: () =>
                              setState(() => _showRawText = !_showRawText),
                        ),
                    ]),
                  ],
                ),
              ),
              _categoryStrip(),
              // The system keyboard is up while a field is open.
              if (_editing == null)
                AmountKeypad(
                  onKey: (key) => _setAmount(Money.keypadPress(_amount, key)),
                  onSubmit: _save,
                )
              else
                SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }

  /// A chip row ending in the [field] chip, or that field expanded in its place.
  Widget _row(_Field field, List<Widget> others) {
    final controller = field == _Field.name ? _title : _note;
    final label = field == _Field.name ? 'Name' : 'Note';
    final icon = field == _Field.name ? Icons.edit_note : Icons.notes;
    return AnimatedSwitcher(
      duration: context.motion(const Duration(milliseconds: 180)),
      child: _editing == field
          ? _ExpandedField(
              key: ValueKey(field),
              icon: icon,
              label: label,
              controller: controller,
              multiline: field == _Field.note,
              groupId: _fieldGroup,
              recent:
                  ref
                      .watch(
                        recentTextsProvider((
                          type: _type,
                          notes: field == _Field.note,
                        )),
                      )
                      .value ??
                  const [],
              onDone: _collapse,
            )
          : Wrap(
              key: ValueKey('$field chips'),
              spacing: 8,
              runSpacing: 4,
              children: [
                ...others,
                _TextChip(
                  icon,
                  label,
                  controller.text,
                  onPressed: () => setState(() => _editing = field),
                  onClear: () => setState(controller.clear),
                ),
              ],
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

/// Shows [value]'s first line, or [label] when empty. Long-press clears it.
class _TextChip extends StatelessWidget {
  const _TextChip(
    this.icon,
    this.label,
    this.value, {
    required this.onPressed,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Semantics(
    onLongPressHint: value.isEmpty ? null : 'Clear',
    child: GestureDetector(
      onLongPress: value.isEmpty ? null : onClear,
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        tooltip: label,
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            value.isEmpty ? label : value.split('\n').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: value.isEmpty
                ? TextStyle(color: context.palette.textSecondary)
                : null,
          ),
        ),
        onPressed: onPressed,
      ),
    ),
  );
}

/// SPEC 5.18 (ref 28): the open field, with recent values above it.
class _ExpandedField extends StatefulWidget {
  const _ExpandedField({
    super.key,
    required this.icon,
    required this.label,
    required this.controller,
    required this.multiline,
    required this.groupId,
    required this.recent,
    required this.onDone,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool multiline;
  final Object groupId;
  final List<String> recent;
  final VoidCallback onDone;

  @override
  State<_ExpandedField> createState() => _ExpandedFieldState();
}

class _ExpandedFieldState extends State<_ExpandedField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final typed = widget.controller.text.trim().toLowerCase();
    final matches = widget.recent
        .where(
          (v) => v.toLowerCase() != typed && v.toLowerCase().startsWith(typed),
        )
        .take(10)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        if (matches.isNotEmpty)
          TapRegion(
            groupId: widget.groupId,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: [
                  for (final value in matches)
                    ActionChip(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          value.split('\n').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () {
                        widget.controller.text = value;
                        widget.onDone();
                      },
                    ),
                ],
              ),
            ),
          ),
        TextField(
          controller: widget.controller,
          autofocus: true,
          groupId: widget.groupId,
          minLines: 1,
          maxLines: widget.multiline ? 4 : 1,
          keyboardType: widget.multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction: widget.multiline
              ? TextInputAction.newline
              : TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon, size: 18),
            hintText: widget.label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.round),
            ),
            isDense: true,
          ),
          onSubmitted: (_) => widget.onDone(),
          onTapOutside: (_) => widget.onDone(),
        ),
      ],
    );
  }
}
