import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

// A map rather than a name lookup, because Flutter tree-shakes unused icons.
const _icons = {
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'home': Icons.home,
  'receipt_long': Icons.receipt_long,
  'shopping_bag': Icons.shopping_bag,
  'favorite': Icons.favorite,
  'movie': Icons.movie,
  'category': Icons.category,
};

/// The category's icon and colour, or a grey placeholder when there is none.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final category = this.category;
    if (category == null) {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        foregroundColor: Colors.white,
        child: Icon(Icons.help_outline),
      );
    }
    return CircleAvatar(
      backgroundColor: Color(category.color),
      foregroundColor: Colors.black87,
      child: Icon(_icons[category.icon] ?? Icons.category),
    );
  }
}

/// Asks for a category and saves it on [row] straight away.
Future<void> categoriseTransaction(
  BuildContext context,
  WidgetRef ref,
  TransactionRow row,
) async {
  final id = await showCategoryPicker(context);
  if (id == null) return;
  await ref
      .read(databaseProvider)
      .updateTransaction(row.id, TransactionsCompanion(categoryId: Value(id)));
}

/// Returns the chosen category's id, or null if dismissed.
Future<int?> showCategoryPicker(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CategoryPicker(),
    );

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker();

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  var _search = '';

  Future<void> _newCategory(List<Category> categories) async {
    final id = await showDialog<int>(
      context: context,
      builder: (_) => _NewCategoryDialog(
        ref.read(databaseProvider),
        categories,
        _search.trim(),
      ),
    );
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final query = _search.trim().toLowerCase();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search categories',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (text) => setState(() => _search = text),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.extent(
                shrinkWrap: true,
                maxCrossAxisExtent: 88,
                childAspectRatio: 0.85,
                children: [
                  for (final category in categories)
                    if (category.name.toLowerCase().contains(query))
                      _GridItem(
                        avatar: CategoryAvatar(category),
                        label: category.name,
                        onTap: () => Navigator.of(context).pop(category.id),
                      ),
                  _GridItem(
                    avatar: const CircleAvatar(child: Icon(Icons.add)),
                    label: 'New category',
                    onTap: () => _newCategory(categories),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.avatar,
    required this.label,
    required this.onTap,
  });

  final Widget avatar;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          avatar,
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog(this.db, this.existing, this.initialName);

  final AppDatabase db;
  final List<Category> existing;
  final String initialName;

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final name = value?.trim().toLowerCase() ?? '';
    if (name.isEmpty) return 'Required';
    return widget.existing.any((c) => c.name.toLowerCase() == name)
        ? 'Already exists'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final id = await widget.db.addCategory(_name.text.trim());
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: _validate,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
