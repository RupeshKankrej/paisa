import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _TransactionSheetState extends ConsumerState<_TransactionSheet>
    with SingleTickerProviderStateMixin {
  final _strip = ScrollController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  // Taps here keep the field open: the field and its recent-values row.
  final _fieldGroup = Object();
  _Field? _editing;
  // The field drawn open or closing; stays set until the close animation ends.
  _Field? _shown;
  // Timings read off reference 28: a quick open, a slower ease back.
  late final _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 300),
  );
  late final _t = CurvedAnimation(
    parent: _morph,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeInOut,
  );
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
    _editing = _shown = null;
    _morph.value = 0;
    _type = existing?.type ?? widget.startType ?? TransactionType.debit;
    _categoryId = _stripFirst = existing?.categoryId ?? widget.startCategory;
    _date = existing?.occurredAt ?? DateTime.now();
    _error = null;
  }

  @override
  void dispose() {
    _strip.dispose();
    _t.dispose();
    _morph.dispose();
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
  void _setCategory(int id) {
    _collapse();
    setState(() {
      _categoryId = id;
      _error = null;
    });
  }

  void _open(_Field field) {
    // Another field still closing snaps shut, so only one row moves.
    if (_shown != field) _morph.value = 0;
    setState(() => _editing = _shown = field);
    context.reduceMotion ? _morph.value = 1 : _morph.forward();
  }

  void _collapse() {
    if (_editing == null) return;
    setState(() => _editing = null);
    void done() {
      if (mounted && _editing == null) setState(() => _shown = null);
    }

    if (context.reduceMotion) {
      _morph.value = 0;
      done();
    } else {
      _morph.reverse().then((_) => done());
    }
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
              // Amount and chips scroll together only when the sheet is too
              // short for them, as in landscape; otherwise the amount centres.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox.shrink(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 8,
                            children: [
                              KeypadAmount(_amount, onChanged: _setAmount),
                              if (_error case final error?)
                                Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.debit,
                                  ),
                                ),
                              if (_showRawText && rawText != null)
                                SelectableText(
                                  rawText,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                          AnimatedBuilder(
                            animation: _t,
                            builder: (context, _) {
                              double t(_Field f) => _shown == f ? _t.value : 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 4,
                                children: [
                                  _withRecents(_Field.name, t(_Field.name), [
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
                                      avatar: const Icon(
                                        Icons.swap_vert,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _type == TransactionType.debit
                                            ? 'Expense'
                                            : 'Income',
                                      ),
                                      onPressed: _toggleType,
                                    ),
                                    if (rawText != null)
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.sms_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('from SMS'),
                                        onPressed: () => setState(
                                          () => _showRawText = !_showRawText,
                                        ),
                                      ),
                                  ]),
                                  _withRecents(_Field.note, t(_Field.note), [
                                    _morphRow(_Field.name, t(_Field.name), [
                                      if (last4 != null)
                                        Chip(
                                          avatar: const Icon(
                                            Icons.account_balance,
                                            size: 18,
                                          ),
                                          label: Text('A/c $last4'),
                                        ),
                                    ]),
                                  ]),
                                  _morphRow(
                                    _Field.note,
                                    t(_Field.note),
                                    const [],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _categoryStrip(),
              // As in reference 28 the keyboard slides over the keypad, which
              // stays put; only a taller keyboard lifts the strip above it.
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    0,
                    MediaQuery.viewInsetsOf(context).bottom -
                        math.max(MediaQuery.paddingOf(context).bottom, 16),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ExcludeSemantics(
                    excluding: _editing != null,
                    child: AmountKeypad(
                      onKey: (key) =>
                          _setAmount(Money.keypadPress(_amount, key)),
                      onSubmit: _save,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chips in a row; while [field] opens, its recent values fade in over them.
  Widget _withRecents(_Field field, double t, List<Widget> chips) {
    final row = Wrap(spacing: 8, runSpacing: 4, children: chips);
    if (t == 0) return row;
    return Stack(
      children: [
        Opacity(
          opacity: 1 - t,
          child: IgnorePointer(child: row),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: t,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _RecentValues(
                controller: field == _Field.name ? _title : _note,
                groupId: _fieldGroup,
                values:
                    ref
                        .watch(
                          recentTextsProvider((
                            type: _type,
                            notes: field == _Field.note,
                          )),
                        )
                        .value ??
                    const [],
                onPicked: _collapse,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reference 28: the [field] chip widens leftwards to the full row while
  /// [siblings] slide out to the left and fade; closing runs it backwards.
  Widget _morphRow(_Field field, double t, List<Widget> siblings) {
    final controller = field == _Field.name ? _title : _note;
    final label = field == _Field.name ? 'Name' : 'Note';
    final icon = field == _Field.name ? Icons.edit_note : Icons.notes;
    Widget chip({VoidCallback? onPressed, VoidCallback? onClear}) => _TextChip(
      icon,
      label,
      controller.text,
      tooltip: onPressed != null,
      onPressed: onPressed ?? () {},
      onClear: onClear ?? () {},
    );
    final pill = _editing == field
        // At least the chip's 48 so the rows do not jump as it opens.
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: controller,
                autofocus: true,
                groupId: _fieldGroup,
                minLines: 1,
                maxLines: field == _Field.note ? 4 : 1,
                keyboardType: field == _Field.note
                    ? TextInputType.multiline
                    : TextInputType.text,
                textInputAction: field == _Field.note
                    ? TextInputAction.newline
                    : TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                // Chip-label size, so the text does not jump as it opens.
                style: Theme.of(context).textTheme.labelLarge,
                decoration: InputDecoration(
                  hintText: label,
                  isDense: true,
                  filled: true,
                  fillColor: context.palette.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: Icon(icon, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  enabledBorder: _fieldBorder(context),
                  focusedBorder: _fieldBorder(context),
                ),
                onSubmitted: (_) => _collapse(),
                onTapOutside: (_) => _collapse(),
              ),
            ),
          )
        : chip(
            onPressed: () => _open(field),
            onClear: () => setState(controller.clear),
          );
    return LayoutBuilder(
      builder: (context, box) {
        return Row(
          children: [
            if (siblings.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                widthFactor: 1 - t,
                child: Opacity(
                  opacity: 1 - t,
                  child: IgnorePointer(
                    ignoring: t > 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: siblings,
                      ),
                    ),
                  ),
                ),
              ),
            _GrowToWidth(t: t, full: box.maxWidth, rest: chip(), child: pill),
          ],
        );
      },
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
    this.tooltip = true,
  });

  final bool tooltip;

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;
  final VoidCallback onClear;

  // Drawn by hand, not an ActionChip, so the pill stretches to the width the
  // close animation gives it (reference 28); sized to match the other chips.
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chip = Theme.of(context).chipTheme;
    final pill = Semantics(
      button: true,
      onLongPressHint: value.isEmpty ? null : 'Clear',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: chip.backgroundColor,
          shape: chip.shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            onLongPress: value.isEmpty ? null : onClear,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(icon, size: 18, color: palette.textSecondary),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        value.isEmpty ? label : value.split('\n').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: value.isEmpty
                              ? palette.textSecondary
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip
        ? Tooltip(
            message: label,
            triggerMode: TooltipTriggerMode.manual,
            child: pill,
          )
        : pill;
  }
}

OutlineInputBorder _fieldBorder(BuildContext context) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadii.chip),
  borderSide: BorderSide(color: context.palette.textSecondary),
);

/// SPEC 5.18: past values for the open field, filtered by what is typed.
class _RecentValues extends StatelessWidget {
  const _RecentValues({
    required this.controller,
    required this.groupId,
    required this.values,
    required this.onPicked,
  });

  final TextEditingController controller;
  final Object groupId;
  final List<String> values;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final typed = value.text.trim().toLowerCase();
      final matches = values
          .where(
            (v) =>
                v.toLowerCase() != typed && v.toLowerCase().startsWith(typed),
          )
          .take(10)
          .toList();
      if (matches.isEmpty) return const SizedBox.shrink();
      return TapRegion(
        groupId: groupId,
        child: SingleChildScrollView(
          key: const Key('recent-values'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (final v in matches)
                ActionChip(
                  // Outlined and see-through, as in reference 28.
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: context.palette.surfaceRaised),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: context.palette.textSecondary),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      v.split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () {
                    controller.text = v;
                    onPicked();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Lays [child] out at a width from [rest]'s natural width (t = 0) to [full]
/// (t = 1). [rest] is the closed chip: laid out to be measured, never shown.
class _GrowToWidth extends MultiChildRenderObjectWidget {
  _GrowToWidth({
    required this.t,
    required this.full,
    required Widget rest,
    required Widget child,
  }) : super(children: [rest, child]);

  final double t;
  final double full;

  @override
  _RenderGrowToWidth createRenderObject(BuildContext context) =>
      _RenderGrowToWidth(t, full);

  @override
  void updateRenderObject(BuildContext context, _RenderGrowToWidth render) =>
      render
        ..t = t
        ..full = full;
}

class _GrowData extends ContainerBoxParentData<RenderBox> {}

class _RenderGrowToWidth extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GrowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GrowData> {
  _RenderGrowToWidth(this._t, this._full);

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  double _full;
  set full(double value) {
    if (value == _full) return;
    _full = value;
    markNeedsLayout();
  }

  RenderBox get _shown => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GrowData) child.parentData = _GrowData();
  }

  @override
  void performLayout() {
    final rest = firstChild!
      ..layout(const BoxConstraints(), parentUsesSize: true);
    final width = rest.size.width + (_full - rest.size.width) * _t;
    _shown.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    size = constraints.constrain(_shown.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(_shown, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _shown.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(_shown);
}
