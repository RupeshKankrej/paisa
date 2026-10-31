import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import 'category_edit_sheet.dart';
import 'manage_categories_screen.dart';

/// Icon tile: an emoji on surface with a border in the category's colour, or a
/// grey placeholder when there is no category.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.round),
        border: Border.all(
          color: category == null ? Colors.grey : Color(category.color),
          width: 2,
        ),
      ),
      child: category == null
          ? const Icon(Icons.help_outline, color: Colors.grey)
          : Text(
              category.emoji,
              style: const TextStyle(fontSize: 20),
              semanticsLabel: '',
            ),
    );
  }
}

/// The Expense/Income control. Takes the width its parent gives it.
class CategoryTypeSegment extends StatelessWidget {
  const CategoryTypeSegment({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CategoryType value;
  final ValueChanged<CategoryType> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.palette.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.round),
    ),
    child: Row(
      children: [
        for (final (label, type) in const [
          ('Expense', CategoryType.expense),
          ('Income', CategoryType.income),
        ])
          Expanded(
            child: Semantics(
              button: true,
              selected: type == value,
              child: Material(
                color: type == value ? context.palette.bg : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.round),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: type == value
                            ? context.palette.textPrimary
                            : context.palette.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The category grid sheet (SPEC 5.14). Returns the choice, or null if dismissed.
/// With [hide], only that type is offered, without those categories.
Future<Category?> showCategoryPicker(
  BuildContext context,
  CategoryType type, {
  Set<int>? hide,
}) => showModalBottomSheet<Category>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) =>
      _CategoryGridSheet(type: type, multiSelect: false, hide: hide),
);

/// The same grid with multi-select. Each tap applies at once.
Future<void> showCategoryFilter(BuildContext context, CategoryType type) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _CategoryGridSheet(type: type, multiSelect: true),
    );

class _CategoryGridSheet extends ConsumerStatefulWidget {
  const _CategoryGridSheet({
    required this.type,
    required this.multiSelect,
    this.hide,
  });

  final CategoryType type;
  final bool multiSelect;
  final Set<int>? hide;

  @override
  ConsumerState<_CategoryGridSheet> createState() => _CategoryGridSheetState();
}

class _CategoryGridSheetState extends ConsumerState<_CategoryGridSheet> {
  late var _type = widget.type;

  Future<void> _addNew(Set<int>? filter) async {
    final category = await showCategoryEditSheet(context, type: _type);
    if (category == null || !mounted) return;
    if (!widget.multiSelect) {
      Navigator.of(context).pop(category);
    } else if (filter != null) {
      await ref.read(databaseProvider).setCategoryFilter({
        ...filter,
        category.id,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final filter = ref.watch(categoryFilterProvider).value;
    final db = ref.read(databaseProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Row(
              children: [
                const SizedBox(width: 48), // balances the pencil
                Expanded(
                  child: Center(
                    child: widget.hide != null
                        ? null
                        : SizedBox(
                            width: 220,
                            child: CategoryTypeSegment(
                              value: _type,
                              onChanged: (type) => setState(() => _type = type),
                            ),
                          ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit categories',
                  style: IconButton.styleFrom(
                    backgroundColor: context.palette.surfaceRaised,
                  ),
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ManageCategoriesScreen(type: _type),
                        ),
                      ),
                ),
              ],
            ),
            if (widget.multiSelect)
              Row(
                spacing: 8,
                children: [
                  ActionChip(
                    backgroundColor: context.palette.surfaceRaised,
                    label: const Text('All'),
                    onPressed: () => db.setCategoryFilter(null),
                  ),
                  ActionChip(
                    backgroundColor: context.palette.surfaceRaised,
                    label: const Text('None'),
                    onPressed: () => db.setCategoryFilter(const {}),
                  ),
                ],
              ),
            Flexible(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  for (final c in pickableCategories(all, _type))
                    if (!(widget.hide?.contains(c.id) ?? false))
                      _Tile(
                        emoji: c.emoji,
                        name: c.name,
                        outline:
                            widget.multiSelect && filterMatches(filter, c.id)
                            ? Color(c.color)
                            : null,
                        selected: widget.multiSelect
                            ? filterMatches(filter, c.id)
                            : null,
                        onTap: widget.multiSelect
                            ? () => db.setCategoryFilter(
                                toggleFilter(filter, c.id, [
                                  for (final a in all)
                                    if (!a.isArchived) a.id,
                                ]),
                              )
                            : () => Navigator.of(context).pop(c),
                      ),
                  AddNewTile(onTap: () => _addNew(filter)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.emoji,
    required this.name,
    required this.onTap,
    this.outline,
    this.selected,
  });

  final String emoji;
  final String name;
  final VoidCallback onTap;
  final Color? outline;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final outline = this.outline;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: context.palette.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          side: outline == null
              ? BorderSide.none
              : BorderSide(color: outline, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 26),
                  semanticsLabel: '',
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed tile with a plus and a label.
class AddNewTile extends StatelessWidget {
  const AddNewTile({super.key, required this.onTap, this.label = 'Add new'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorder(context.palette.textSecondary),
    child: Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            Icon(Icons.add, color: context.palette.textSecondary),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);

  final Color color;

  static const _dash = 8.0;
  static const _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadii.chip),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}
