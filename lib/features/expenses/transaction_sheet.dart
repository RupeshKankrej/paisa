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
  // SPEC 5.18 timing: one controller drives the field width, its outline,
  // the sibling chips' opacity and the recent-values row; closing also
  // decelerates, so it mirrors opening.
  late final _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _t = CurvedAnimation(
    parent: _morph,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic.flipped,
  );
  final _focus = {_Field.name: FocusNode(), _Field.note: FocusNode()};
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
    for (final node in _focus.values) {
      node.dispose();
    }
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
    if (_editing == field) return;
    // Another field still closing snaps shut, so only one row moves.
    if (_shown != field) _morph.value = 0;
    setState(() => _editing = _shown = field);
    // Same frame as the animation starts; the field attaches on this build.
    _focus[field]!.requestFocus();
    context.reduceMotion ? _morph.value = 1 : _morph.forward();
  }

  void _collapse() {
    final field = _editing;
    if (field == null) return;
    _focus[field]!.unfocus();
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
    final hero = Column(
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
            maxLines: 4, // scrolls inside, never under the chips
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
    final chips = AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        double t(_Field f) => _shown == f ? _t.value : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _withRecents(_Field.name, t(_Field.name), [
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
              if (rawText != null)
                ActionChip(
                  avatar: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('from SMS'),
                  onPressed: () => setState(() => _showRawText = !_showRawText),
                ),
            ]),
            _withRecents(_Field.note, t(_Field.note), [
              _morphRow(_Field.name, t(_Field.name), [
                if (last4 != null)
                  Chip(
                    avatar: const Icon(Icons.account_balance, size: 18),
                    label: Text('A/c $last4'),
                  ),
              ]),
            ]),
            _morphRow(_Field.note, t(_Field.note), const []),
          ],
        );
      },
    );
    final keypad = ExcludeSemantics(
      excluding: _editing != null,
      child: AmountKeypad(
        onKey: (key) => _setAmount(Money.keypadPress(_amount, key)),
        onSubmit: _save,
      ),
    );
    // The body's bottom stays put (maintainBottomViewPadding), so this is the
    // keyboard's top edge measured from it. The engine already moves the inset
    // with the keyboard frame by frame; it is used as is, not animated again.
    final keyboard = math.max(
      0.0,
      MediaQuery.viewInsetsOf(context).bottom -
          math.max(MediaQuery.viewPaddingOf(context).bottom, 16),
    );
    final block = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [chips, _categoryStrip()],
    );
    return FractionallySizedBox(
      heightFactor: 0.97, // leaves a sliver of scrim to tap away on
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: true,
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
                child: LayoutBuilder(
                  builder: (context, box) {
                    // shortcut: an iPhone SE or landscape cannot fit the fixed
                    // layout, so it keeps the older scrolling one; revisit if
                    // small screens matter.
                    if (box.maxHeight < _minStackHeight) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 8,
                                children: [hero, block],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: math.max(
                                0,
                                keyboard - AmountKeypad.height,
                              ),
                            ),
                            child: keypad,
                          ),
                        ],
                      );
                    }
                    // SPEC 5.18: the amount is pinned from the top and the
                    // keypad from the bottom, so neither moves; the chips sit
                    // on the keypad, or on the keyboard's edge once it is
                    // higher, and ride with it 1:1.
                    return Stack(
                      children: [
                        Positioned(
                          top: _heroTop,
                          left: 0,
                          right: 0,
                          child: hero,
                        ),
                        Positioned(left: 0, right: 0, bottom: 0, child: keypad),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: math.max(AmountKeypad.height, keyboard) + 8,
                          child: block,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where the amount sits below the header; clear of the chips with the
  /// keyboard up on an iPhone 15.
  static const _heroTop = 40.0;

  /// Below this the fixed layout would overlap; see the shortcut above.
  static const _minStackHeight = 560.0;

  /// Chips in a row; while [field] opens, its recent values fade in over them.
  /// The chips stay in the tree, so nothing around them moves.
  Widget _withRecents(_Field field, double t, List<Widget> chips) {
    // Recents start 20 ms of the 220 behind the field.
    final shown = ((t - 20 / 220) / (200 / 220)).clamp(0.0, 1.0);
    return Stack(
      children: [
        Opacity(
          opacity: _siblingOpacity(t),
          child: IgnorePointer(
            ignoring: t > 0,
            child: Wrap(spacing: 8, runSpacing: 4, children: chips),
          ),
        ),
        if (t > 0)
          Positioned.fill(
            child: Opacity(
              opacity: shown,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - shown)),
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
          ),
      ],
    );
  }

  /// Faded out by 150 ms of the 220.
  static double _siblingOpacity(double t) =>
      1 - (t * 220 / 150).clamp(0.0, 1.0);

  /// The [field] chip grows from its own place to the full row, over
  /// [siblings], which stay where they are and fade (SPEC 5.18 timing).
  Widget _morphRow(_Field field, double t, List<Widget> siblings) {
    final controller = field == _Field.name ? _title : _note;
    final label = field == _Field.name ? 'Name' : 'Note';
    final icon = field == _Field.name ? Icons.edit_note : Icons.notes;
    final palette = context.palette;
    // The field stays up while closing, so its outline can fade with the rest.
    final pill = _shown == field
        ? ConstrainedBox(
            // At least the chip's 48, so the rows do not move as it opens.
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                child: TextField(
                  controller: controller,
                  focusNode: _focus[field],
                  groupId: _fieldGroup,
                  minLines: 1,
                  // One line while it moves, so nothing wraps mid-animation.
                  maxLines: field == _Field.note && t == 1 ? 4 : 1,
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
                    hintMaxLines: 1,
                    hintStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.textSecondary,
                      overflow: TextOverflow.clip,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: palette.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: Icon(icon, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    enabledBorder: _fieldBorder(context, t),
                    focusedBorder: _fieldBorder(context, t),
                  ),
                  onTap: () => _open(field),
                  onSubmitted: (_) => _collapse(),
                  onTapOutside: (_) {
                    if (_editing == field) _collapse();
                  },
                ),
              ),
            ),
          )
        : _TextChip(
            icon,
            label,
            controller.text,
            onPressed: () => _open(field),
            onClear: () => setState(controller.clear),
          );
    return _MorphRow(
      t: t,
      siblings: Opacity(
        opacity: _siblingOpacity(t),
        child: IgnorePointer(
          ignoring: t > 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: siblings,
          ),
        ),
      ),
      rest: _TextChip(
        icon,
        label,
        controller.text,
        tooltip: false,
        onPressed: () {},
        onClear: () {},
      ),
      pill: pill,
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

/// The focus outline fades in with the field's width ([t]).
OutlineInputBorder _fieldBorder(BuildContext context, double t) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.chip),
      borderSide: BorderSide(
        color: context.palette.textSecondary.withValues(alpha: t),
      ),
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

/// Lays out [siblings] at the start, then [pill]: at t = 0 the pill sits after
/// the siblings at [rest]'s natural width; at t = 1 it covers the whole row.
/// The siblings never move, so the row's layout does not shift. [rest] is the
/// closed chip, laid out only to be measured and never shown.
class _MorphRow extends MultiChildRenderObjectWidget {
  _MorphRow({
    required this.t,
    required Widget siblings,
    required Widget rest,
    required Widget pill,
  }) : super(children: [siblings, rest, pill]);

  final double t;

  @override
  _RenderMorphRow createRenderObject(BuildContext context) =>
      _RenderMorphRow(t);

  @override
  void updateRenderObject(BuildContext context, _RenderMorphRow render) =>
      render.t = t;
}

class _MorphData extends ContainerBoxParentData<RenderBox> {}

class _RenderMorphRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphData> {
  _RenderMorphRow(this._t);

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  RenderBox get _siblings => firstChild!;
  RenderBox get _rest => childAfter(_siblings)!;
  RenderBox get _pill => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphData) child.parentData = _MorphData();
  }

  @override
  void performLayout() {
    final full = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: full);
    _siblings.layout(loose, parentUsesSize: true);
    _rest.layout(loose, parentUsesSize: true);
    final start = _siblings.size.width == 0 ? 0.0 : _siblings.size.width + 8;
    final rest = math.min(_rest.size.width, full - start);
    _pill.layout(
      BoxConstraints.tightFor(width: rest + (full - rest) * _t),
      parentUsesSize: true,
    );
    final height = math.max(_siblings.size.height, _pill.size.height);
    size = constraints.constrain(Size(full, height));
    (_siblings.parentData! as _MorphData).offset = Offset(
      0,
      (height - _siblings.size.height) / 2,
    );
    (_pill.parentData! as _MorphData).offset = Offset(
      start * (1 - _t),
      (height - _pill.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in [_siblings, _pill]) {
      context.paintChild(
        child,
        offset + (child.parentData! as _MorphData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [_pill, _siblings]) {
      final at = (child.parentData! as _MorphData).offset;
      final hit = result.addWithPaintOffset(
        offset: at,
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_siblings);
    visitor(_pill);
  }
}
