import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';

// shortcut: iOS only, until Android needs its own emoji input (SPEC section 7).
const _emojiInput = MethodChannel('paisa/emoji');

Future<void> _emojiCall(String method) async {
  try {
    await _emojiInput.invokeMethod<void>(method);
  } on MissingPluginException {
    // No native side on this platform: the default emoji stays.
  }
}

/// The delete confirmation (reference 25, SPEC 5.14). True means delete.
Future<bool> confirmDeleteCategory(
  BuildContext context,
  AppDatabase db,
  Category category,
) async {
  final count = await db.countCategoryTransactions(category.id);
  if (!context.mounted) return false;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Icon(Icons.delete_outline, size: 40),
            const Text(
              'Are you sure you want to delete this category?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              deleteCategoryMessage(count),
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.delete,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(sheet).pop(true),
              child: const Text('Delete category'),
            ),
            _SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.surfaceRaised,
      foregroundColor: AppColors.textPrimary,
      minimumSize: const Size.fromHeight(52),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// New category, or edit when [existing] is set (SPEC 5.14). Returns the
/// category when one was added.
Future<Category?> showCategoryEditSheet(
  BuildContext context, {
  required CategoryType type,
  Category? existing,
}) => showModalBottomSheet<Category>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => _CategoryEditSheet(type, existing),
);

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet(this.type, this.existing);

  final CategoryType type;
  final Category? existing;

  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late var _emoji = widget.existing?.emoji ?? defaultCategoryEmoji;
  late var _color = widget.existing?.color ?? defaultCategoryColor;
  var _showPalette = false;
  var _saving = false; // a second tap during the pop would close the page below

  @override
  void initState() {
    super.initState();
    _emojiInput.setMethodCallHandler((call) async {
      final emoji = lastEmoji(call.arguments as String);
      if (call.method == 'typed' && emoji != null && mounted) {
        setState(() => _emoji = emoji);
      }
    });
  }

  @override
  void dispose() {
    _emojiInput.setMethodCallHandler(null);
    _emojiCall('close');
    _name.dispose();
    super.dispose();
  }

  void _openEmojiKeyboard() {
    FocusScope.of(context).unfocus();
    setState(() => _showPalette = false);
    _emojiCall('open');
  }

  bool get _taken {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    return nameTaken([
      for (final c in all)
        if (c.type == widget.type && c.id != widget.existing?.id) c.name,
    ], _name.text);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final existing = widget.existing;
    if (existing != null) {
      await db.updateCategory(
        existing.id,
        name: _name.text,
        emoji: _emoji,
        color: _color,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final added = await db.addCategory(
      name: _name.text,
      type: widget.type,
      emoji: _emoji,
      color: _color,
    );
    if (mounted) Navigator.of(context).pop(added);
  }

  // Archiving is out of SPEC 5.14, but a category archived earlier needs a way back.
  Future<void> _unarchive(Category category) async {
    await ref.read(databaseProvider).setCategoryArchived(category.id, false);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(Category category) async {
    FocusScope.of(context).unfocus();
    _emojiCall('close');
    final db = ref.read(databaseProvider);
    if (!await confirmDeleteCategory(context, db, category)) return;
    await db.deleteCategory(category.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final typeName = widget.type == CategoryType.expense ? 'expense' : 'income';
    final taken = _taken;
    final canSave = _name.text.trim().isNotEmpty && !taken && !_saving;
    final fieldShape = BoxDecoration(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                existing == null
                    ? 'New $typeName category'
                    : widget.type == CategoryType.expense
                    ? 'Expense category'
                    : 'Income category',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('category-name'),
                      controller: _name,
                      autofocus: existing == null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Category name',
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                          borderSide: const BorderSide(
                            color: AppColors.textPrimary,
                            width: 2,
                          ),
                        ),
                        errorText: taken ? 'Already exists' : null,
                      ),
                      onTap: () {
                        _emojiCall('close');
                        setState(() => _showPalette = false);
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Emoji',
                    child: InkWell(
                      key: const Key('category-emoji'),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      onTap: _openEmojiKeyboard,
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: fieldShape,
                        child: Text(
                          _emoji,
                          semanticsLabel: '',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Colour',
                    child: InkWell(
                      key: const Key('category-colour'),
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _emojiCall('close');
                        setState(() => _showPalette = !_showPalette);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: fieldShape,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(_color),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 8,
                children: [
                  if (existing != null)
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Delete',
                        onPressed: () => _delete(existing),
                      ),
                    ),
                  Expanded(
                    child: FilledButton(
                      onPressed: canSave ? _save : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(existing == null ? 'Add' : 'Save'),
                    ),
                  ),
                ],
              ),
              if (_showPalette)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final (i, color) in categoryPalette.indexed)
                      Semantics(
                        button: true,
                        selected: color == _color,
                        label: 'Colour ${i + 1}',
                        child: InkWell(
                          key: Key('swatch-$i'),
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _color = color),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(color),
                              border: color == _color
                                  ? Border.all(
                                      color: AppColors.textPrimary,
                                      width: 3,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (existing != null && existing.isArchived)
                TextButton(
                  onPressed: () => _unarchive(existing),
                  child: const Text('Unarchive'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
