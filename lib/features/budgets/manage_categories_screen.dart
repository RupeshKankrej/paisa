import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_widgets.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import 'category_edit_sheet.dart';
import 'category_picker.dart';

/// The Categories screen (SPEC 5.14), behind the pencils and Settings.
class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key, this.type = CategoryType.expense});

  final CategoryType type;

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  late var _type = widget.type;
  // Holds a dropped row in place until the database stream catches up.
  List<int>? _order;
  // A dismissed row must leave the tree at once, before the database stream
  // catches up, or Dismissible throws.
  final _dismissed = <int>{};

  void _edit(Category category) =>
      showCategoryEditSheet(context, type: _type, existing: category);

  Future<bool> confirmDismissCategory(Category category) =>
      confirmDeleteCategory(context, ref.read(databaseProvider), category);

  void _reorder(List<Category> rows, int from, int to) {
    final ids = [for (final c in rows) c.id];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    setState(() => _order = ids);
    ref.read(databaseProvider).reorderCategories(ids);
  }

  void _addSuggestion(QuickAdd add, int index) => ref
      .read(databaseProvider)
      .addCategory(
        name: add.name,
        type: _type,
        emoji: add.emoji,
        color: categoryColors[index % categoryColors.length],
      );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final order = _order;
    final rows = pickableCategories(
      all,
      _type,
    ).where((c) => !_dismissed.contains(c.id)).toList();
    if (order != null) {
      int rank(Category c) {
        final i = order.indexOf(c.id);
        return i < 0 ? order.length : i;
      }

      rows.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    final archived = [
      for (final c in all)
        if (c.type == _type && c.isArchived) c,
    ];
    final names = [
      for (final c in all)
        if (c.type == _type) c.name,
    ];
    final suggestions = _type == CategoryType.expense
        ? expenseQuickAdds
        : incomeQuickAdds;
    final caption = Theme.of(context).textTheme.bodySmall;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: caption),
    );
    return Scaffold(
      appBar: AppBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(180, 52)),
        onPressed: () => showCategoryEditSheet(context, type: _type),
        child: const Text('New category'),
      ),
      body: ListView(
        padding: listClearance(context),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Categories',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CategoryTypeSegment(
              value: _type,
              onChanged: (type) => setState(() {
                _type = type;
                _order = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: true, // long-press anywhere on a row
                onReorderItem: (from, to) => _reorder(rows, from, to),
                children: [
                  for (final (i, c) in rows.indexed)
                    Column(
                      key: ValueKey(c.id),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0) const Divider(),
                        Dismissible(
                          key: ValueKey('dismiss-${c.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: AppColors.delete,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(
                              Icons.delete_outline,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          confirmDismiss: (_) => confirmDismissCategory(c),
                          onDismissed: (_) {
                            setState(() => _dismissed.add(c.id));
                            ref.read(databaseProvider).deleteCategory(c.id);
                          },
                          child: ListTile(
                            leading: CategoryAvatar(c),
                            title: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: context.palette.textSecondary,
                                  semanticLabel: 'Reorder ${c.name}',
                                ),
                              ),
                            ),
                            onTap: () => _edit(c),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (suggestions.any((s) => !nameTaken(names, s.name))) ...[
            heading('Quick adds'),
            GroupedCard(
              children: [
                for (final (i, s) in suggestions.indexed)
                  if (!nameTaken(names, s.name))
                    ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.palette.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        child: Text(
                          s.emoji,
                          style: const TextStyle(fontSize: 22),
                          semanticsLabel: '',
                        ),
                      ),
                      title: Text(s.name),
                      trailing: IconButton(
                        tooltip: 'Add ${s.name}',
                        style: IconButton.styleFrom(
                          backgroundColor: context.palette.surfaceRaised,
                        ),
                        icon: const Icon(Icons.add),
                        onPressed: () => _addSuggestion(s, i),
                      ),
                    ),
              ],
            ),
          ],
          // Only for categories archived before SPEC 5.14 dropped archiving: they
          // could not come back otherwise, and their names would stay taken.
          if (archived.isNotEmpty) ...[
            heading('Archived'),
            GroupedCard(
              children: [
                for (final c in archived)
                  ListTile(
                    leading: CategoryAvatar(c),
                    title: Text(c.name),
                    onTap: () => _edit(c),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
